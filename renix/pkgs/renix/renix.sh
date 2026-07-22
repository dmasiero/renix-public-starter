set -e

if [ "$(uname -s)" = "Darwin" ]; then
  FLAKE_DIR="${RENIX_FLAKE_DIR:-/Users/doug/renix}"
else
  FLAKE_DIR="${RENIX_FLAKE_DIR:-/home/doug/renix}"
fi
CONFIG_NAME="${RENIX_HOST:-$(hostname -s)}"
FLAKE_REF="$FLAKE_DIR#$CONFIG_NAME"
if [ "$(uname -s)" = "Darwin" ]; then
  REBUILD_TOOL="darwin-rebuild"
  REBUILD_DRY_ACTION="check"
  REBUILD_LABEL="nix-darwin"
else
  REBUILD_TOOL="nixos-rebuild"
  REBUILD_DRY_ACTION="dry-run"
  REBUILD_LABEL="NixOS"
fi

CUSTOM_BUILD_DISPLAY_LIST=""
CUSTOM_BUILD_ATTR_NAMES_JSON="[]"
export CUSTOM_BUILD_ATTR_NAMES_JSON
CUSTOM_BUILDS_JSON="[]"

# Colors
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
MAGENTA="\033[35m"
BLUE="\033[34m"
WHITE="\033[97m"

load_custom_build_manifest() {
  local manifest_file="$FLAKE_DIR/pkgs/custom-builds.nix"
  local manifest_json
  local manifest_env

  if [ ! -f "$manifest_file" ]; then
    echo -e "${RED}renix: custom build manifest not found:${RESET} $manifest_file" >&2
    exit 1
  fi

  manifest_json=$(RENIX_CUSTOM_BUILDS_FILE="$manifest_file" RENIX_CUSTOM_BUILDS_NORMALIZER="$FLAKE_DIR/pkgs/custom-builds-normalized.nix" nix eval --impure --json --expr '
    import (builtins.toPath (builtins.getEnv "RENIX_CUSTOM_BUILDS_NORMALIZER")) {
      customBuildsFile = builtins.toPath (builtins.getEnv "RENIX_CUSTOM_BUILDS_FILE");
    }
  ') || {
    echo -e "${RED}renix: failed to evaluate custom build manifest.${RESET}" >&2
    exit 1
  }

  manifest_env=$(python3 -c '
import json, shlex, sys
manifest = json.load(sys.stdin)
print("CUSTOM_BUILD_DISPLAY_LIST=" + shlex.quote(manifest.get("displayList", "")))
print("CUSTOM_BUILD_ATTR_NAMES_JSON=" + shlex.quote(json.dumps(manifest.get("attrNames", []))))
print("CUSTOM_BUILDS_JSON=" + shlex.quote(json.dumps(manifest.get("builds", []))))

' <<< "$manifest_json")
  eval "$manifest_env"
  export CUSTOM_BUILD_ATTR_NAMES_JSON
}

source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"

# --- Parse args ---
SKIP_BUILD_UPDATES=true
DO_FLAKE_UPDATE_CHECK=false
FLAKE_CHECK_ONLY=false
ROLLBACK_MODE=false
SYNC_MODE=false
SUMMARY_MODE=false
CLEAN_MODE=false
FULL_MODE=false
SKILLS_MODE=false
SKILLS_ACTION=""

if [ "${1:-}" = "skills" ]; then
  SKILLS_MODE=true
  SKILLS_ACTION="${2:-}"
  if [ "$#" -gt 2 ]; then
    echo -e "${RED}Unknown skills option:${RESET} $3"
    show_skills_help
    exit 1
  fi
  set --
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      show_help
      exit 0
      ;;
    upgrade|-ug)
      DO_FLAKE_UPDATE_CHECK=true
      FLAKE_CHECK_ONLY=true
      SKIP_BUILD_UPDATES=true
      ;;
    update|-u)
      SKIP_BUILD_UPDATES=false
      ;;
    sync|-s)
      SYNC_MODE=true
      ;;
    overview|-o)
      SUMMARY_MODE=true
      ;;
    clean|-c)
      CLEAN_MODE=true
      ;;
    full|-f)
      FULL_MODE=true
      DO_FLAKE_UPDATE_CHECK=true
      FLAKE_CHECK_ONLY=false
      SKIP_BUILD_UPDATES=false
      ;;
    rollback|-r)
      ROLLBACK_MODE=true
      SKIP_BUILD_UPDATES=true
      DO_FLAKE_UPDATE_CHECK=false
      ;;
    *)
      echo -e "${RED}Unknown option:${RESET} $1"
      show_help
      exit 1
      ;;
  esac
  shift
done

cd "$FLAKE_DIR"

if [ "$SKILLS_MODE" = true ]; then
  case "$SKILLS_ACTION" in
    check)
      show_mattpocock_skills_status
      ;;
    update)
      run_mattpocock_skills_update
      ;;
    ""|help|--help|-h)
      show_skills_help
      ;;
    *)
      echo -e "${RED}Unknown skills command:${RESET} $SKILLS_ACTION"
      show_skills_help
      exit 1
      ;;
  esac
  exit 0
fi

if [ "$SYNC_MODE" = true ]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}renix: $FLAKE_DIR is not a git work tree.${RESET}" >&2
    exit 1
  fi

  echo -e "${BLUE}══════════════════════════════════════════${RESET}"
  echo -e "  ${BOLD}${WHITE}Updating Renix Config${RESET}"
  echo -e "${BLUE}══════════════════════════════════════════${RESET}"
  echo -e "${DIM}Pulling latest config from git...${RESET}"
  if ! git pull --ff-only; then
    echo -e "${RED}renix: git pull failed.${RESET} Resolve local changes and rerun renix sync." >&2
    exit 1
  fi
  exit 0
fi

sudo -v
(
  while true; do
    sleep 60
    sudo -n -v >/dev/null 2>&1 || exit
  done
) </dev/null >/dev/null 2>&1 &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true; wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

if [ "$ROLLBACK_MODE" = true ]; then
  run_rollback
  exit 0
fi

if [ "$SUMMARY_MODE" = true ]; then
  load_custom_build_manifest
  show_store_header
  show_store_info
  exit 0
fi

if [ "$CLEAN_MODE" = true ]; then
  run_clean_prompt
  exit 0
fi

if [ "$DO_FLAKE_UPDATE_CHECK" = true ]; then
  show_flake_update_check
  if [ "$FLAKE_CHECK_ONLY" = true ]; then
    exit 0
  fi
fi

if ! nix eval --impure --expr "let flake = builtins.getFlake \"$FLAKE_DIR\"; in (flake ? nixosConfigurations && flake.nixosConfigurations ? \"$CONFIG_NAME\") || (flake ? darwinConfigurations && flake.darwinConfigurations ? \"$CONFIG_NAME\")" 2>/dev/null | grep -qx true; then
  echo "renix: no nixosConfigurations.$CONFIG_NAME or darwinConfigurations.$CONFIG_NAME in $FLAKE_DIR/flake.nix" >&2
  echo "renix: hostname must match a flake host, or add hosts/<arch>/$CONFIG_NAME/default.nix and expose it in flake.nix" >&2
  exit 1
fi

# --- Package update checks ---
UPDATES_APPLIED=false
UPDATED_ITEMS=()

if [ "$SKIP_BUILD_UPDATES" != true ]; then
  load_custom_build_manifest

  echo -e "${BLUE}══════════════════════════════════════════${RESET}"
  echo -e "  ${BOLD}${WHITE}Checking Custom Builds${RESET}"
  echo -e "${BLUE}══════════════════════════════════════════${RESET}"

  VERSION_FILE=$(mktemp)
  (
    printf '%s\n' "$CUSTOM_BUILDS_JSON" \
      | python3 "$(dirname "${BASH_SOURCE[0]}")/custom_builds.py" --flake-dir "$FLAKE_DIR" --host "$CONFIG_NAME" --workers "${RENIX_CHECK_WORKERS:-4}" \
      | python3 -c '
import json, shlex, sys
for result in json.load(sys.stdin):
    build = result["build"]
    source = build.get("source", {})
    update = build.get("update", {})
    fields = {
        "id": build["id"], "display_name": build.get("displayName", build["id"]),
        "attr_name": build["attrName"], "update_type": update.get("type", "manual"),
        "update_target": update.get("target", ""), "source_url": source.get("url", ""),
        "package": source.get("package", ""), "update_derivation_file": update.get("derivationFile", ""),
        "update_lockfile": update.get("lockfile", ""), "update_url_template": update.get("urlTemplate", ""),
        "update_owner": update.get("owner", source.get("owner", "")),
        "update_repo": update.get("repo", source.get("repo", "")),
        "update_rev_prefix": update.get("revPrefix", "v"),
        "configured": result["configured"], "latest": result["latest"],
    }
    print(" ".join(f"{key}={shlex.quote(str(value))}" for key, value in fields.items()))
' > "$VERSION_FILE"
  ) &
  VERSION_PID=$!
  spin "$VERSION_PID" "Checking custom build versions..."
  if ! wait "$VERSION_PID"; then
    echo -e "${RED}renix: custom build discovery failed.${RESET}" >&2
    rm -f "$VERSION_FILE"
    exit 1
  fi

  UPDATES_APPLIED=false
  UPDATED_ITEMS=()
  AVAILABLE_UPDATE_COUNT=0
  CUSTOM_BUILD_SKIP_INDEXES=""
  APPLY_CUSTOM_BUILD_UPDATES=true

  if [ -n "$VERSION_FILE" ] && [ -s "$VERSION_FILE" ]; then
    while IFS= read -r result_env; do
      [ -z "$result_env" ] && continue
      eval "$result_env"
      [ -z "$id" ] && continue
      update_type=$(custom_build_update_handler "$update_type") || exit 1

      if [ "$configured" = "$latest" ] && [ "$configured" != "unknown" ] && [ -n "$configured" ]; then
        echo -e "${GREEN}✓${RESET} $display_name: current (${CYAN}$configured${RESET})"
        continue
      fi

      if [ "$latest" = "unknown" ] || [ -z "$latest" ] || [ "$configured" = "unknown" ] || [ -z "$configured" ]; then
        echo -e "${YELLOW}⚠${RESET} $display_name: unable to determine version status (current: ${CYAN}$configured${RESET}, latest: ${MAGENTA}$latest${RESET})"
        continue
      fi

      if [ "$update_type" = "manual" ]; then
        echo -e "${YELLOW}⚠${RESET} $display_name upgrade available: ${GREEN}$latest${RESET} ${DIM}(current: ${RESET}${CYAN}$configured${RESET}${DIM}; manual update required in $update_target)${RESET}"
        continue
      fi

      AVAILABLE_UPDATE_COUNT=$((AVAILABLE_UPDATE_COUNT + 1))
      echo -e "  ${YELLOW}$AVAILABLE_UPDATE_COUNT.${RESET} $display_name: ${CYAN}$configured${RESET} → ${GREEN}$latest${RESET}"
    done < "$VERSION_FILE"

    if [ "$AVAILABLE_UPDATE_COUNT" -gt 0 ]; then
      if ! prompt_custom_build_updates "$AVAILABLE_UPDATE_COUNT"; then
        APPLY_CUSTOM_BUILD_UPDATES=false
        echo -e "${DIM}Skipping all custom build updates.${RESET}"
      fi
    fi

    UPDATE_INDEX=0
    while [ "$APPLY_CUSTOM_BUILD_UPDATES" = true ] && IFS= read -r result_env; do
      [ -z "$result_env" ] && continue
      eval "$result_env"
      [ -z "$id" ] && continue
      update_type=$(custom_build_update_handler "$update_type") || exit 1

      if [ "$configured" = "$latest" ] || [ "$latest" = "unknown" ] || [ -z "$latest" ] || [ "$configured" = "unknown" ] || [ -z "$configured" ] || [ "$update_type" = "manual" ]; then
        continue
      fi

      UPDATE_INDEX=$((UPDATE_INDEX + 1))
      if should_skip_custom_build_update "$UPDATE_INDEX"; then
        echo -e "${DIM}Skipping $display_name upgrade.${RESET}"
        continue
      fi

      case "$update_type" in
        flake-input)
          echo -e "${DIM}Updating $display_name flake input...${RESET}"
          NIX_CONFIG="warn-dirty = false" nix flake update "$update_target" --flake "$FLAKE_DIR" --option warn-dirty false
          mark_update_applied "$display_name"
          ;;
        npm-package)
          if [ -z "$package" ] || [ -z "$update_derivation_file" ] || [ -z "$update_lockfile" ]; then
            echo -e "${RED}✗${RESET} Missing npm-package metadata for $display_name in custom-builds.nix"
          else
            update_npm_package "$display_name" "$package" "$update_derivation_file" "$update_lockfile" "$latest"
            mark_update_applied "$display_name"
          fi
          ;;
        pypi)
          if [ -z "$package" ] || [ -z "$update_target" ]; then
            echo -e "${RED}✗${RESET} Missing pypi metadata for $display_name in custom-builds.nix"
          else
            update_pypi_package "$display_name" "$package" "$update_target" "$latest"
            mark_update_applied "$display_name"
          fi
          ;;
        fetchurl-static-url)
          if [ -z "$source_url" ] || [ -z "$update_target" ]; then
            echo -e "${RED}✗${RESET} Missing fetchurl-static-url metadata for $display_name in custom-builds.nix"
          else
            update_fetchurl_static_url_package "$display_name" "$update_target" "$source_url" "$latest"
            mark_update_applied "$display_name"
          fi
          ;;
        fetchurl-template)
          if [ -z "$update_url_template" ] || [ -z "$update_target" ]; then
            echo -e "${RED}✗${RESET} Missing fetchurl-template metadata for $display_name in custom-builds.nix"
          else
            update_fetchurl_template_package "$display_name" "$update_target" "$update_url_template" "$latest"
            mark_update_applied "$display_name"
          fi
          ;;
        fetchurl-template-arch-hashes)
          if [ -z "$update_url_template" ] || [ -z "$update_target" ]; then
            echo -e "${RED}✗${RESET} Missing fetchurl-template-arch-hashes metadata for $display_name in custom-builds.nix"
          else
            update_fetchurl_template_arch_hashes_package "$display_name" "$update_target" "$update_url_template" "$latest"
            mark_update_applied "$display_name"
          fi
          ;;
        github-release-system-assets)
          if [ -z "$update_url_template" ] || [ -z "$update_target" ]; then
            echo -e "${RED}✗${RESET} Missing github-release-system-assets metadata for $display_name in custom-builds.nix"
          else
            update_github_release_system_assets_package "$display_name" "$update_target" "$update_url_template" "$latest"
            mark_update_applied "$display_name"
          fi
          ;;
        fetchurl-template-system-assets)
          if [ -z "$update_url_template" ] || [ -z "$update_target" ]; then
            echo -e "${RED}✗${RESET} Missing fetchurl-template-system-assets metadata for $display_name in custom-builds.nix"
          else
            update_fetchurl_template_system_assets_package "$display_name" "$id" "$update_target" "$update_url_template" "$latest"
            mark_update_applied "$display_name"
          fi
          ;;
        github-go-module)
          if [ -z "$update_owner" ] || [ -z "$update_repo" ] || [ -z "$update_target" ]; then
            echo -e "${RED}✗${RESET} Missing github-go-module metadata for $display_name in custom-builds.nix"
          else
            update_github_go_module_package "$display_name" "$update_target" "$attr_name" "$update_owner" "$update_repo" "$update_rev_prefix" "$latest"
            mark_update_applied "$display_name"
          fi
          ;;
        github-rust-package)
          if [ -z "$update_owner" ] || [ -z "$update_repo" ] || [ -z "$update_target" ]; then
            echo -e "${RED}✗${RESET} Missing github-rust-package metadata for $display_name in custom-builds.nix"
          else
            update_github_rust_package "$display_name" "$update_target" "$attr_name" "$update_owner" "$update_repo" "$update_rev_prefix" "$latest"
            mark_update_applied "$display_name"
          fi
          ;;
      esac
    done < "$VERSION_FILE"
  fi
  [ -n "$VERSION_FILE" ] && rm -f "$VERSION_FILE"
fi

if [ "$SKIP_BUILD_UPDATES" != true ] && [ "$FULL_MODE" != true ]; then
  if mattpocock_skills_update_available; then
    show_mattpocock_skills_status
    echo -e "${DIM}Run ${CYAN}renix skills update${RESET}${DIM} to apply Pi skills updates without tying them to the normal rebuild path.${RESET}"
  fi
fi

# --- Rebuild ---
echo -e "${BLUE}══════════════════════════════════════════${RESET}"
echo -e "  ${BOLD}${WHITE}Renixing System${RESET}"
echo -e "${BLUE}══════════════════════════════════════════${RESET}"

REBUILD_ACTION="switch"

ARCH="$(nix eval --impure --raw --expr '
  let
    flake = builtins.getFlake "'"$FLAKE_DIR"'";
    cfg =
      if flake ? nixosConfigurations && flake.nixosConfigurations ? "'"$CONFIG_NAME"'" then
        flake.nixosConfigurations."'"$CONFIG_NAME"'".config
      else
        flake.darwinConfigurations."'"$CONFIG_NAME"'".config;
  in cfg.nixpkgs.hostPlatform.system
' 2>/dev/null || uname -m)"

echo -e "${DIM}Host:${RESET} ${CYAN}$CONFIG_NAME${RESET}"
echo -e "${DIM}Arch:${RESET} ${CYAN}$ARCH${RESET}"
echo -e "${DIM}Running:${RESET} ${BOLD}sudo $REBUILD_TOOL $REBUILD_ACTION${RESET} ${DIM}--flake${RESET} ${CYAN}$FLAKE_REF${RESET} ${DIM}--option warn-dirty false${RESET}"
echo ""

REBUILD_OUT_PIPE=$(mktemp -u)
mkfifo "$REBUILD_OUT_PIPE"

(
  sudo env NIX_CONFIG="warn-dirty = false" "$REBUILD_TOOL" "$REBUILD_ACTION" --flake "$FLAKE_REF" --option warn-dirty false >"$REBUILD_OUT_PIPE" 2>&1
) &
REBUILD_PID=$!
spin "$REBUILD_PID" "Renixing system..." &
SPIN_PID=$!

while IFS= read -r line || [ -n "$line" ]; do
  if should_suppress_output_line "$line"; then
    continue
  fi
  printf "\r\033[2K\033[1A\r\033[2K%s\n" "$line"
done < "$REBUILD_OUT_PIPE"

if wait "$REBUILD_PID"; then
  REBUILD_STATUS=0
else
  REBUILD_STATUS=$?
fi
wait "$SPIN_PID" 2>/dev/null || true
rm -f "$REBUILD_OUT_PIPE"

if [ "$REBUILD_STATUS" -ne 0 ]; then
  exit "$REBUILD_STATUS"
fi

if [ "$FULL_MODE" = true ]; then
  run_mattpocock_skills_update
fi

run_pi_extension_update

if [ "$FULL_MODE" = true ]; then
  show_store_header
  show_store_info
  run_clean_prompt
fi
