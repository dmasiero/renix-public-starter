# --- Pi extensions ---
run_pi_extension_update() {
  if ! command -v pi >/dev/null 2>&1; then
    echo -e "${DIM}Skipping Pi extension update: pi not found in PATH.${RESET}"
    return 0
  fi

  echo -e "${BLUE}══════════════════════════════════════════${RESET}"
  echo -e "  ${BOLD}${WHITE}Updating Pi Extensions${RESET}"
  echo -e "${BLUE}══════════════════════════════════════════${RESET}"

  if pi update --extensions; then
    echo -e "${GREEN}✓${RESET} Pi extensions updated"
  else
    echo -e "${YELLOW}⚠${RESET} Pi extension update failed"
    return 0
  fi
}

# --- Pi skills: Matt Pocock skills ---
mattpocock_skills_pi_dir() {
  if [ -n "${RENIX_PI_DIR:-}" ]; then
    printf '%s\n' "$RENIX_PI_DIR"
  elif [ "$(uname -s)" = "Darwin" ]; then
    printf '%s\n' "$HOME/dotfiles/pi"
  else
    printf '%s\n' "$HOME/dotfiles/pi"
  fi
}

mattpocock_skills_manifest_file() {
  printf '%s/agent/metadata/mattpocock-skills.json\n' "$(mattpocock_skills_pi_dir)"
}

get_json_field() {
  local file=$1
  local field=$2

  python3 - "$file" "$field" <<'PY' 2>/dev/null || true
import json
import sys
path, field = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
value = data
for part in field.split('.'):
    value = value[part]
print(value)
PY
}

get_mattpocock_skills_current_version() {
  local manifest
  manifest=$(mattpocock_skills_manifest_file)
  if [ ! -f "$manifest" ]; then
    echo "unknown"
    return 0
  fi
  get_json_field "$manifest" version
}

get_latest_github_tag_version() {
  local owner=$1
  local repo=$2
  local strip_v=${3:-true}

  GITHUB_OWNER="$owner" GITHUB_REPO="$repo" STRIP_V="$strip_v" python3 <<'PY' 2>/dev/null || echo "unknown"
import json
import os
import re
import urllib.request

owner = os.environ["GITHUB_OWNER"]
repo = os.environ["GITHUB_REPO"]
strip_v = os.environ.get("STRIP_V", "true") == "true"
url = f"https://api.github.com/repos/{owner}/{repo}/git/matching-refs/tags"
req = urllib.request.Request(url, headers={"User-Agent": "renix"})
with urllib.request.urlopen(req, timeout=20) as response:
    refs = json.load(response)
versions = []
for ref in refs:
    name = ref.get("ref", "").rsplit("/", 1)[-1]
    candidate = name[1:] if name.startswith("v") else name
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", candidate):
        continue
    versions.append((tuple(int(part) for part in candidate.split(".")), candidate, name))
if not versions:
    print("unknown")
else:
    versions.sort()
    latest = versions[-1][1 if strip_v else 2]
    print(latest)
PY
}

get_mattpocock_skills_latest_version() {
  get_latest_github_tag_version mattpocock skills true
}

show_skills_help() {
  echo -e "${BOLD}Usage:${RESET} ${CYAN}renix skills${RESET} ${DIM}<check|update>${RESET}"
  echo ""
  echo -e "  ${CYAN}check${RESET}"
  echo -e "      ${DIM}Report current vs latest Matt Pocock skills version without changing files.${RESET}"
  echo -e "  ${CYAN}update${RESET}"
  echo -e "      ${DIM}Prompt to update Matt Pocock skills, then refresh the pinned checkout, symlinks, and manifests.${RESET}"
}

mattpocock_skills_update_available() {
  local current latest
  current=$(get_mattpocock_skills_current_version)
  latest=$(get_mattpocock_skills_latest_version)

  [ "$current" != "unknown" ] && [ -n "$current" ] && [ "$latest" != "unknown" ] && [ -n "$latest" ] && [ "$current" != "$latest" ]
}

show_mattpocock_skills_status() {
  local current latest
  current=$(get_mattpocock_skills_current_version)
  latest=$(get_mattpocock_skills_latest_version)

  echo -e "${BLUE}══════════════════════════════════════════${RESET}"
  echo -e "  ${BOLD}${WHITE}Checking Pi Skills${RESET}"
  echo -e "${BLUE}══════════════════════════════════════════${RESET}"

  if [ "$current" = "$latest" ] && [ "$current" != "unknown" ] && [ -n "$current" ]; then
    echo -e "${GREEN}✓${RESET} mattpocock-skills: current (${CYAN}$current${RESET})"
    return 0
  fi

  if [ "$current" = "unknown" ] || [ -z "$current" ] || [ "$latest" = "unknown" ] || [ -z "$latest" ]; then
    echo -e "${YELLOW}⚠${RESET} mattpocock-skills: unable to determine version status (current: ${CYAN}$current${RESET}, latest: ${MAGENTA}$latest${RESET})"
    return 0
  fi

  echo -e "${YELLOW}⚠${RESET} mattpocock-skills update available: ${GREEN}$latest${RESET} ${DIM}(current: ${RESET}${CYAN}$current${RESET}${DIM})${RESET}"
}

write_mattpocock_skills_manifests() {
  local pi_dir=$1
  local version=$2
  local tag=$3
  local commit=$4
  local vendor_rel="agent/vendor/mattpocock-skills"

  PI_DIR="$pi_dir" VERSION="$version" TAG="$tag" COMMIT="$commit" python3 <<'PY'
import json
import os
import pathlib

pi = pathlib.Path(os.environ["PI_DIR"])
version = os.environ["VERSION"]
tag = os.environ["TAG"]
commit = os.environ["COMMIT"]
vendor = pi / "agent/vendor/mattpocock-skills"
plugin = json.loads((vendor / ".claude-plugin/plugin.json").read_text())
skills = [
    {"name": pathlib.PurePosixPath(rel).name, "upstreamPath": rel}
    for rel in plugin["skills"]
]
manifest = {
    "name": "mattpocock-skills",
    "repoUrl": "https://github.com/mattpocock/skills",
    "version": version,
    "tag": tag,
    "commit": commit,
    "vendorPath": "agent/vendor/mattpocock-skills",
    "pluginManifestPath": "agent/vendor/mattpocock-skills/.claude-plugin/plugin.json",
    "installMethod": "git clone pinned to tag with flat symlinks from agent/skills/<skill-name> to upstream skill directories",
    "installedSkills": skills,
    "skippedCategories": ["deprecated", "in-progress", "misc", "personal"],
    "notes": [
        "Do not run /setup-matt-pocock-skills globally; run it per project when ready.",
        "Renix reads this file to determine the currently installed Matt Pocock skills version.",
    ],
}
(pi / "agent/metadata").mkdir(parents=True, exist_ok=True)
(pi / "agent/metadata/mattpocock-skills.json").write_text(json.dumps(manifest, indent=2) + "\n")
old_manifest = pi / "agent/skills/mattpocock-skills.json"
if old_manifest.exists():
    old_manifest.unlink()
lines = [
    "# Matt Pocock Skills",
    "",
    "Installed from <https://github.com/mattpocock/skills>.",
    "",
    f"- Version: `{version}`",
    f"- Tag: `{tag}`",
    "- Vendor checkout: `agent/vendor/mattpocock-skills`",
    "- Machine-readable manifest: `agent/metadata/mattpocock-skills.json`",
    "- Install style: upstream repo clone pinned to a tag, with flat per-skill symlinks in `agent/skills/`",
    "",
    "## Installed skills",
    "",
    "The installed set is the official non-deprecated skill list from upstream `.claude-plugin/plugin.json`:",
    "",
]
lines.extend(f"- `{skill['name']}`" for skill in skills)
lines.extend([
    "",
    "Skipped upstream categories: `deprecated`, `in-progress`, `misc`, and `personal`.",
    "",
    "## Updating",
    "",
    "Use Renix:",
    "",
    "```sh",
    "renix skills check",
    "renix skills update",
    "```",
    "",
    "`renix full` includes the skills update step. `renix update` reports availability, but normal rebuild-oriented updates do not apply skills updates directly.",
    "",
    "## Setup skill note",
    "",
    "`/setup-matt-pocock-skills` is not an installer. It is a per-project configuration skill. Run it inside a project repo when you want the Matt Pocock engineering skills to write/read project-local issue tracker, triage label, and domain-doc configuration.",
])
(pi / "agent/metadata").mkdir(parents=True, exist_ok=True)
(pi / "agent/metadata/MATT-POCOCK-SKILLS.md").write_text("\n".join(lines) + "\n")
old_notes = pi / "agent/skills/MATT-POCOCK-SKILLS.md"
if old_notes.exists():
    old_notes.unlink()
PY
}

refresh_mattpocock_skills_links() {
  local pi_dir=$1
  local vendor_dir="$pi_dir/agent/vendor/mattpocock-skills"
  local skills_dir="$pi_dir/agent/skills"

  PI_DIR="$pi_dir" python3 <<'PY'
import json
import pathlib
import sys

pi = pathlib.Path(__import__('os').environ['PI_DIR'])
vendor = pi / 'agent/vendor/mattpocock-skills'
skills_dir = pi / 'agent/skills'
plugin = json.loads((vendor / '.claude-plugin/plugin.json').read_text())
new_names = {pathlib.PurePosixPath(rel).name for rel in plugin['skills']}
old_manifest = pi / 'agent/metadata/mattpocock-skills.json'
old_names = set()
if old_manifest.exists():
    try:
        old_names = {item['name'] for item in json.loads(old_manifest.read_text()).get('installedSkills', [])}
    except Exception:
        old_names = set()
for name in sorted(old_names - new_names):
    dst = skills_dir / name
    if dst.is_symlink():
        dst.unlink()
for rel in plugin['skills']:
    src = vendor / rel
    name = pathlib.PurePosixPath(rel).name
    dst = skills_dir / name
    if not src.is_dir() or not (src / 'SKILL.md').is_file():
        raise SystemExit(f'missing upstream skill dir/SKILL.md: {rel}')
    if dst.exists() or dst.is_symlink():
        if dst.is_symlink():
            dst.unlink()
        else:
            raise SystemExit(f'refusing to overwrite non-symlink skill directory: {dst}')
    dst.symlink_to(pathlib.Path('../vendor/mattpocock-skills') / rel, target_is_directory=True)
PY
}

update_mattpocock_skills() {
  local latest=$1
  local pi_dir vendor_dir temp_parent temp_vendor backup_dir tag commit

  pi_dir=$(mattpocock_skills_pi_dir)
  vendor_dir="$pi_dir/agent/vendor/mattpocock-skills"
  tag="v$latest"

  if [ ! -d "$pi_dir/agent/skills" ]; then
    echo -e "${RED}✗${RESET} Pi skills directory not found: $pi_dir/agent/skills" >&2
    return 1
  fi

  if [ -d "$vendor_dir/.git" ]; then
    git -C "$vendor_dir" fetch --tags --force origin
  fi

  temp_parent=$(mktemp -d)
  temp_vendor="$temp_parent/mattpocock-skills"
  backup_dir="$temp_parent/mattpocock-skills.backup"

  git clone --quiet https://github.com/mattpocock/skills "$temp_vendor"
  git -C "$temp_vendor" checkout --quiet --detach "$tag"
  commit=$(git -C "$temp_vendor" rev-parse HEAD)
  rm -rf "$temp_vendor/.git"

  PI_DIR="$pi_dir" TEMP_VENDOR="$temp_vendor" python3 <<'PY'
import json
import os
import pathlib
import sys

pi = pathlib.Path(os.environ['PI_DIR'])
vendor = pathlib.Path(os.environ['TEMP_VENDOR'])
plugin = json.loads((vendor / '.claude-plugin/plugin.json').read_text())
for rel in plugin['skills']:
    src = vendor / rel
    if not src.is_dir() or not (src / 'SKILL.md').is_file():
        raise SystemExit(f'missing upstream skill dir/SKILL.md: {rel}')
    dst = pi / 'agent/skills' / pathlib.PurePosixPath(rel).name
    if dst.exists() and not dst.is_symlink():
        raise SystemExit(f'refusing to overwrite non-symlink skill directory: {dst}')
PY

  if [ -d "$vendor_dir" ]; then
    mv "$vendor_dir" "$backup_dir"
  fi
  mkdir -p "$(dirname "$vendor_dir")"
  mv "$temp_vendor" "$vendor_dir"

  if ! refresh_mattpocock_skills_links "$pi_dir"; then
    echo -e "${YELLOW}⚠${RESET} Link refresh failed; restoring previous vendor checkout." >&2
    rm -rf "$vendor_dir"
    if [ -d "$backup_dir" ]; then
      mv "$backup_dir" "$vendor_dir"
      refresh_mattpocock_skills_links "$pi_dir" >/dev/null 2>&1 || true
    fi
    rm -rf "$temp_parent"
    return 1
  fi

  write_mattpocock_skills_manifests "$pi_dir" "$latest" "$tag" "$commit"
  rm -rf "$temp_parent"
  echo -e "${GREEN}✓${RESET} Updated mattpocock-skills to ${GREEN}$latest${RESET}."
}

run_mattpocock_skills_update() {
  local current latest
  current=$(get_mattpocock_skills_current_version)
  latest=$(get_mattpocock_skills_latest_version)

  show_mattpocock_skills_status

  if [ "$current" = "$latest" ] && [ "$current" != "unknown" ] && [ -n "$current" ]; then
    return 0
  fi
  if [ "$latest" = "unknown" ] || [ -z "$latest" ]; then
    return 0
  fi
  if [ "$current" = "unknown" ] || [ -z "$current" ]; then
    if [ "${RENIX_DEMO:-0}" = "1" ]; then
      update_mattpocock_skills "$latest"
    fi
    return 0
  fi
  if prompt_upgrade "mattpocock-skills"; then
    update_mattpocock_skills "$latest"
  fi
}

# --- Help ---
show_help() {
  echo -e "${BOLD}Usage:${RESET} ${CYAN}renix${RESET} ${DIM}[COMMAND|OPTION]...${RESET}"
  echo ""
  echo -e "${DIM}A unified command layer for NixOS and nix-darwin rebuilds, flake updates, and system maintenance.${RESET}"
  echo ""
  echo -e "${BOLD}${WHITE}Commands:${RESET}"
  echo -e "  ${CYAN}update${RESET}, ${YELLOW}-u${RESET}"
  echo -e "      ${DIM}Check custom build updates, then run rebuild switch.${RESET}"
  echo -e "  ${CYAN}upgrade${RESET}, ${YELLOW}-ug${RESET}"
  echo -e "      ${DIM}Check flake inputs and dry-run rebuild package changes.${RESET}"
  echo -e "  ${CYAN}full${RESET}, ${YELLOW}-f${RESET}"
  echo -e "      ${DIM}Run upgrade, update, skills update, overview, and clean in order.${RESET}"
  echo -e "  ${CYAN}skills${RESET} ${DIM}<check|update>${RESET}"
  echo -e "      ${DIM}Check or update Matt Pocock skills for Pi without rebuilding.${RESET}"
  echo -e "  ${CYAN}sync${RESET}, ${YELLOW}-s${RESET}"
  echo -e "      ${DIM}Pull latest config from git and exit.${RESET}"
  echo -e "  ${CYAN}clean${RESET}, ${YELLOW}-c${RESET}"
  echo -e "      ${DIM}Show cleanup status, then automatically clean unless skipped.${RESET}"
  echo -e "  ${CYAN}overview${RESET}, ${YELLOW}-o${RESET}"
  echo -e "      ${DIM}Show package count, generations, store paths, and disk usage.${RESET}"
  echo -e "  ${CYAN}rollback${RESET}, ${YELLOW}-r${RESET}"
  echo -e "      ${DIM}Switch back to the previous system generation.${RESET}"
  echo ""
  echo -e "${BOLD}${WHITE}Options:${RESET}"
  echo -e "  ${YELLOW}-h${RESET}, ${YELLOW}--help${RESET}"
  echo -e "      ${DIM}Display this help and exit.${RESET}"
}

# --- Spinner ---
spin() {
  local pid=$1
  local msg=$2
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r${CYAN}%s${RESET} ${DIM}%s${RESET}" "${frames[$i]}" "$msg"
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.08
  done
  printf "\r\033[2K"
}

# --- Store & Generations Info ---
human_size() {
  local bytes="${1:-0}"
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec-i --suffix=B "$bytes"
  else
    awk -v bytes="$bytes" '
      BEGIN {
        split("B KiB MiB GiB TiB PiB", units, " ")
        size = bytes + 0
        unit = 1
        while (size >= 1024 && unit < 6) {
          size = size / 1024
          unit++
        }
        if (unit == 1) {
          printf "%.0f %s\n", size, units[unit]
        } else if (size >= 10) {
          printf "%.1f %s\n", size, units[unit]
        } else {
          printf "%.2f %s\n", size, units[unit]
        }
      }
    '
  fi
}

disk_usage_bytes() {
  if du -sb "$@" >/dev/null 2>&1; then
    du -sb "$@" 2>/dev/null | awk '{sum += $1} END {printf "%.0f\n", sum + 0}'
  else
    du -sk "$@" 2>/dev/null | awk '{sum += $1 * 1024} END {printf "%.0f\n", sum + 0}'
  fi
}

show_store_header() {
  echo -e "${BLUE}══════════════════════════════════════════${RESET}"
  echo -e "  ${BOLD}${WHITE}System Overview${RESET}"
  echo -e "${BLUE}══════════════════════════════════════════${RESET}"
}

show_store_info() {

  # Gather data in background with spinner
  local tmpfile
  tmpfile=$(mktemp)

  (
    GEN_TOTAL=$(sudo -H nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | wc -l)
    GEN_OLD=$((GEN_TOTAL - 1))

    TOTAL_PATHS=$(ls /nix/store 2>/dev/null | wc -l)
    TOTAL_SIZE=$(disk_usage_bytes /nix/store)
    TOTAL_SIZE=${TOTAL_SIZE:-0}

    DEAD_LIST=$(nix-store --gc --print-dead 2>/dev/null || true)
    if [ -n "$DEAD_LIST" ]; then
      DEAD_PATHS=$(printf "%s\n" "$DEAD_LIST" | wc -l)
      DEAD_SIZE=$(printf "%s\n" "$DEAD_LIST" | xargs du -sk 2>/dev/null | awk '{sum += $1 * 1024} END {printf "%.0f\n", sum + 0}')
    else
      DEAD_PATHS=0
      DEAD_SIZE=0
    fi

    LIVE_PATHS=$((TOTAL_PATHS - DEAD_PATHS))
    [ "$LIVE_PATHS" -lt 0 ] && LIVE_PATHS=0
    LIVE_SIZE=$((TOTAL_SIZE - DEAD_SIZE))
    [ "$LIVE_SIZE" -lt 0 ] && LIVE_SIZE=0

    OLD_GEN_SIZE=$(find /nix/var/nix/profiles -maxdepth 1 -type l -name 'system-*-link' ! -samefile /nix/var/nix/profiles/system 2>/dev/null \
      | xargs -r readlink -f \
      | sort -u \
      | xargs -r nix path-info --closure-size 2>/dev/null \
      | awk '{sum += $2} END {print sum + 0}')

    PKG_COUNTS=$(nix eval --impure --raw --expr "
      let
        flake = builtins.getFlake \"$FLAKE_DIR\";
        cfg =
          if flake ? nixosConfigurations && flake.nixosConfigurations ? "$CONFIG_NAME" then
            flake.nixosConfigurations."$CONFIG_NAME".config
          else
            flake.darwinConfigurations."$CONFIG_NAME".config;
        customNames = builtins.fromJSON (builtins.getEnv \"CUSTOM_BUILD_ATTR_NAMES_JSON\");
        nameOf = p: (p.pname or p.name or \"\");
        sys = builtins.map nameOf cfg.environment.systemPackages;
        homeUsers = builtins.attrValues (cfg.\"home-manager\".users or {});
        home = builtins.concatLists (map (user: builtins.map nameOf (user.home.packages or [])) homeUsers);
        all = sys ++ home;
        customCount = builtins.length (builtins.filter (n: builtins.elem n customNames) all);
        totalCount = builtins.length all;
        nixpkgsCount = if totalCount > customCount then totalCount - customCount else 0;
      in toString totalCount + \" \" + toString nixpkgsCount + \" \" + toString (builtins.length sys) + \" \" + toString (builtins.length home) + \" \" + toString customCount
    " 2>/dev/null || echo "0 0 0 0 0")

    read -r PKG_TOTAL PKG_NIXPKGS PKG_SYSTEM PKG_HOME PKG_CUSTOM <<< "$PKG_COUNTS"

    echo "$GEN_TOTAL $GEN_OLD $TOTAL_PATHS $LIVE_PATHS $DEAD_PATHS $TOTAL_SIZE $LIVE_SIZE $DEAD_SIZE ${OLD_GEN_SIZE:-0} ${PKG_TOTAL:-0} ${PKG_NIXPKGS:-0} ${PKG_SYSTEM:-0} ${PKG_HOME:-0} ${PKG_CUSTOM:-0}" > "$tmpfile"
  ) &
  spin $! "Preparing system summary..."

  read -r GEN_TOTAL GEN_OLD TOTAL_PATHS LIVE_PATHS DEAD_PATHS TOTAL_SIZE LIVE_SIZE DEAD_SIZE OLD_GEN_SIZE PKG_TOTAL PKG_NIXPKGS PKG_SYSTEM PKG_HOME PKG_CUSTOM < "$tmpfile"
  rm -f "$tmpfile"

  TOTAL_SIZE_HR=$(human_size "$TOTAL_SIZE")
  LIVE_SIZE_HR=$(human_size "$LIVE_SIZE")
  DEAD_SIZE_HR=$(human_size "$DEAD_SIZE")
  OLD_GEN_SIZE_HR=$(human_size "$OLD_GEN_SIZE")

  echo -e "Packages: ${CYAN}$PKG_TOTAL${RESET} total ${DIM}(${RESET}${GREEN}$PKG_NIXPKGS${RESET} ${DIM}nixpkgs: system ${RESET}$PKG_SYSTEM${DIM}, home ${RESET}$PKG_HOME${DIM}; custom ${RESET}$PKG_CUSTOM${DIM})${RESET}"
  echo -e "Generations: ${CYAN}$GEN_TOTAL${RESET} total ${DIM}($GEN_OLD old)${RESET}"
  echo -e "Previous gens: ${CYAN}$GEN_OLD${RESET} ${DIM}old, closure size ${RESET}${MAGENTA}$OLD_GEN_SIZE_HR${RESET}"
  echo -e "Store paths: ${CYAN}$TOTAL_PATHS${RESET} total ${DIM}(${RESET}${GREEN}$LIVE_PATHS${RESET} ${DIM}live /${RESET} ${YELLOW}$DEAD_PATHS${RESET} ${DIM}reclaimable)${RESET}"
  echo -e "Disk usage: ${MAGENTA}$TOTAL_SIZE_HR${RESET} ${DIM}total (${RESET}${GREEN}$LIVE_SIZE_HR${RESET} ${DIM}live /${RESET} ${YELLOW}$DEAD_SIZE_HR${RESET} ${DIM}reclaimable)${RESET}"
}

# --- Rollback ---
run_rollback() {
  local profile="/nix/var/nix/profiles/system"
  local generations current_line previous_line current_gen previous_gen current_path previous_path

  generations="$(sudo -H nix-env --list-generations --profile "$profile" 2>/dev/null || true)"
  current_line="$(printf '%s\n' "$generations" | awk '/current/ { line=$0 } END { print line }')"

  if [ -z "$current_line" ]; then
    current_gen="$(readlink -f "$profile" 2>/dev/null | sed -n 's/.*system-\([0-9][0-9]*\)-link.*/\1/p')"
  else
    current_gen="$(printf '%s\n' "$current_line" | awk '{ print $1 }')"
  fi

  if [ -z "$current_gen" ]; then
    echo -e "${RED}renix: unable to determine current system generation.${RESET}" >&2
    exit 1
  fi

  previous_line="$(printf '%s\n' "$generations" | awk -v current="$current_gen" '$1 < current { line=$0 } END { print line }')"
  previous_gen="$(printf '%s\n' "$previous_line" | awk '{ print $1 }')"

  if [ -z "$previous_gen" ]; then
    echo -e "${RED}renix: no previous system generation found to roll back to.${RESET}" >&2
    exit 1
  fi

  current_path="$(readlink -f "$profile" 2>/dev/null || true)"
  previous_path="$(readlink -f "$profile-$previous_gen-link" 2>/dev/null || true)"

  echo -e "${BLUE}══════════════════════════════════════════${RESET}"
  echo -e "  ${BOLD}${WHITE}Rollback System${RESET}"
  echo -e "${BLUE}══════════════════════════════════════════${RESET}"
  echo -e "${DIM}Host:${RESET} ${CYAN}$CONFIG_NAME${RESET}"
  echo -e "${DIM}Current generation:${RESET} ${CYAN}$current_gen${RESET} ${DIM}$current_line${RESET}"
  echo -e "${DIM}Previous generation:${RESET} ${GREEN}$previous_gen${RESET} ${DIM}$previous_line${RESET}"
  [ -n "$current_path" ] && echo -e "${DIM}Current path:${RESET} ${CYAN}$current_path${RESET}"
  [ -n "$previous_path" ] && echo -e "${DIM}Rollback path:${RESET} ${GREEN}$previous_path${RESET}"
  echo ""

  if [ -n "$current_path" ] && [ -n "$previous_path" ]; then
    echo -e "${DIM}Closure diff (previous → current):${RESET}"
    nix store diff-closures "$previous_path" "$current_path" 2>/dev/null || true
    echo ""
  fi

  if ! prompt_yes "Switch back to generation ${GREEN}$previous_gen${RESET}? [${GREEN}y${RESET}/${RED}N${RESET}] "; then
    echo ""
    echo -e "${DIM}Rollback cancelled.${RESET}"
    echo ""
    exit 0
  fi

  echo ""
  echo -e "${DIM}Running:${RESET} ${BOLD}sudo $REBUILD_TOOL switch --rollback${RESET}"
  echo ""
  sudo "$REBUILD_TOOL" switch --rollback
}

# --- Clean ---
show_clean_header() {
  echo -e "${BLUE}══════════════════════════════════════════${RESET}"
  echo -e "  ${BOLD}${WHITE}System Cleanup${RESET}"
  echo -e "${BLUE}══════════════════════════════════════════${RESET}"
}

run_clean_prompt() {
  local answer=""
  local second=""

  show_clean_header
  echo -e "${CYAN}Automatically cleaning up old generations${RESET} in ${YELLOW}3s${RESET}."
  echo -e "Keeping the last ${CYAN}5${RESET} generations. Press ${RED}s${RESET} to skip, ${GREEN}Enter${RESET} to clean now."

  printf "${DIM}Cleaning in${RESET} "
  for second in 3 2 1; do
    case "$second" in
      3) printf "${GREEN}%s${RESET}" "$second" ;;
      2) printf "${YELLOW}%s${RESET}" "$second" ;;
      1) printf "${RED}%s${RESET}" "$second" ;;
    esac

    if [ "$second" != "1" ]; then
      printf "... "
    else
      printf "..."
    fi

    if IFS= read -r -s -n 1 -t 1 answer; then
      if [[ "$answer" =~ ^[Ss]$ ]]; then
        echo ""
        echo -e "${DIM}Skipping cleanup.${RESET}"
        return 0
      fi

      echo ""
      echo -e "${GREEN}Cleaning now...${RESET}"
      run_clean true
      return 0
    fi
  done

  echo ""
  echo -e "${GREEN}Cleaning now...${RESET}"
  run_clean true
}

run_clean() {
  local skip_initial_info="${1:-false}"

  if [ "$skip_initial_info" != "true" ]; then
    show_store_header
    show_store_info
  else
    show_store_info >/dev/null 2>&1
  fi

  local before_gen_total=$GEN_TOTAL
  local before_gen_old=$GEN_OLD
  local before_total_paths=$TOTAL_PATHS
  local before_dead_paths=$DEAD_PATHS
  local before_total_size=$TOTAL_SIZE
  local before_dead_size=$DEAD_SIZE
  local before_old_gen_size=$OLD_GEN_SIZE

  local keep=5

  echo -e "${DIM}Removing all but last${RESET} ${CYAN}$keep${RESET} ${DIM}generations...${RESET}"
  sudo -H nix-env --delete-generations +${keep} --profile /nix/var/nix/profiles/system

  echo -e "${DIM}Running garbage collection...${RESET}"
  nix-collect-garbage -d 2>/dev/null

  echo -e "${DIM}Optimizing store...${RESET}"
  nix store optimise 2>/dev/null

  echo -e "${GREEN}✓${RESET} Optimize complete."

  show_store_info >/dev/null 2>&1

  local reclaimed_paths=$((before_total_paths - TOTAL_PATHS))
  local reclaimed_dead_paths=$((before_dead_paths - DEAD_PATHS))
  local reclaimed_size=$((before_total_size - TOTAL_SIZE))
  local reclaimed_dead_size=$((before_dead_size - DEAD_SIZE))
  local removed_generations=$((before_gen_total - GEN_TOTAL))
  local reduced_old_gen_size=$((before_old_gen_size - OLD_GEN_SIZE))

  [ "$reclaimed_paths" -lt 0 ] && reclaimed_paths=0
  [ "$reclaimed_dead_paths" -lt 0 ] && reclaimed_dead_paths=0
  [ "$reclaimed_size" -lt 0 ] && reclaimed_size=0
  [ "$reclaimed_dead_size" -lt 0 ] && reclaimed_dead_size=0
  [ "$removed_generations" -lt 0 ] && removed_generations=0
  [ "$reduced_old_gen_size" -lt 0 ] && reduced_old_gen_size=0

  echo -e "Generations removed: ${CYAN}$removed_generations${RESET} ${DIM}(old: $before_gen_old → $GEN_OLD)${RESET}"
  echo -e "Store paths removed: ${CYAN}$reclaimed_paths${RESET} ${DIM}(reclaimable paths removed: $reclaimed_dead_paths)${RESET}"
  echo -e "Disk reclaimed: ${GREEN}$(human_size "$reclaimed_size")${RESET} ${DIM}(reclaimable reduced by $(human_size "$reclaimed_dead_size"), old-gen closure reduced by $(human_size "$reduced_old_gen_size"))${RESET}"
}

get_configured_build_version() {
  local attr_name=$1

  nix eval --impure --raw --expr \
    "let flake = builtins.getFlake \"$FLAKE_DIR\"; cfg = if flake ? nixosConfigurations && flake.nixosConfigurations ? \"$CONFIG_NAME\" then flake.nixosConfigurations.\"$CONFIG_NAME\" else flake.darwinConfigurations.\"$CONFIG_NAME\"; in cfg.pkgs.\"$attr_name\".version" \
    2>/dev/null || echo "unknown"
}

get_latest_build_version() {
  local source_type=$1
  local owner=$2
  local repo=$3
  local package=$4
  local dist_tag=$5
  local strip_v=$6
  local flake=$7
  local version_path=$8
  local source_url=$9
  local source_regex=${10}

  case "$source_type" in
    flake-input)
      nix eval --impure --raw --expr "(builtins.getFlake \"$flake\").$version_path" 2>/dev/null || echo "unknown"
      ;;
    npm)
      local tag="$dist_tag"
      [ -z "$tag" ] && tag="latest"
      nix eval --impure --raw --expr \
        "let p = builtins.fromJSON (builtins.readFile (builtins.fetchurl \"https://registry.npmjs.org/$package\")); in p.\"dist-tags\".\"$tag\" or \"unknown\"" \
        2>/dev/null || echo "unknown"
      ;;
    github-release)
      if [ "$strip_v" = "1" ]; then
        nix eval --impure --raw --expr \
          "let r = builtins.fromJSON (builtins.readFile (builtins.fetchurl \"https://api.github.com/repos/$owner/$repo/releases/latest\")); t = r.tag_name or \"\"; len = builtins.stringLength t; in if len > 1 && builtins.substring 0 1 t == \"v\" then builtins.substring 1 (len - 1) t else t" \
          2>/dev/null || echo "unknown"
      else
        nix eval --impure --raw --expr \
          "let r = builtins.fromJSON (builtins.readFile (builtins.fetchurl \"https://api.github.com/repos/$owner/$repo/releases/latest\")); in r.tag_name or \"unknown\"" \
          2>/dev/null || echo "unknown"
      fi
      ;;
    crates)
      nix eval --impure --raw --expr \
        "let r = builtins.fromJSON (builtins.readFile (builtins.fetchurl \"https://crates.io/api/v1/crates/$package\")); in r.crate.newest_version or \"unknown\"" \
        2>/dev/null || echo "unknown"
      ;;
    pypi)
      nix eval --impure --raw --expr \
        "let r = builtins.fromJSON (builtins.readFile (builtins.fetchurl \"https://pypi.org/pypi/$package/json\")); in r.info.version or \"unknown\"" \
        2>/dev/null || echo "unknown"
      ;;
    http-redirect-regex)
      if [ -z "$source_url" ] || [ -z "$source_regex" ]; then
        echo "unknown"
      else
        redirect_location=$(curl -fsSIL -A 'Mozilla/5.0' "$source_url" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="location:" {print $2; exit}')
        if [ -n "$redirect_location" ]; then
          printf '%s\n' "$redirect_location" | sed -nE "s|$source_regex|\\1|p" | head -n1
        else
          echo "unknown"
        fi
      fi
      ;;
    http-header-last-modified)
      if [ -z "$source_url" ]; then
        echo "unknown"
      else
        last_modified=$(curl -fsSIL -A 'Mozilla/5.0' "$source_url" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="last-modified:" {sub(/^[^:]+:[[:space:]]*/, ""); print; exit}')
        if [ -n "$last_modified" ]; then
          LAST_MODIFIED="$last_modified" python3 - <<'PY' 2>/dev/null || echo "unknown"
import email.utils
import os

parsed = email.utils.parsedate_to_datetime(os.environ["LAST_MODIFIED"])
print(parsed.date().isoformat())
PY
        else
          echo "unknown"
        fi
      fi
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

prompt_yes_no() {
  local prompt=$1
  local default_answer=${2:-none}
  local answer=""

  while true; do
    printf "%b" "$prompt"

    if ! { read -r answer < /dev/tty; } 2>/dev/null; then
      return 1
    fi

    case "$answer" in
      [Yy])
        return 0
        ;;
      [Nn])
        return 1
        ;;
      "")
        case "$default_answer" in
          yes)
            return 0
            ;;
          no)
            return 1
            ;;
        esac
        ;;
      *)
        ;;
    esac

    echo -e "${YELLOW}Please answer ${GREEN}y${YELLOW} or ${RED}n${YELLOW}.${RESET}"
  done
}

prompt_yes() {
  local prompt=$1

  prompt_yes_no "$prompt" no
}

prompt_upgrade() {
  local display_name=$1

  if prompt_yes "Upgrade $display_name? [${GREEN}y${RESET}/${RED}N${RESET}] "; then
    return 0
  fi

  echo -e "${DIM}Skipping $display_name upgrade.${RESET}"
  return 1
}

prompt_custom_build_updates() {
  local update_count=$1
  local answer=""
  local normalized
  local index
  local skipped=" "

  while true; do
    printf "Apply all updates? [${GREEN}Y${RESET}/${RED}n${RESET}, or numbers to skip] "

    if ! { read -r answer < /dev/tty; } 2>/dev/null; then
      return 1
    fi

    case "$answer" in
      ""|[Yy]|[Aa]|all)
        CUSTOM_BUILD_SKIP_INDEXES=""
        return 0
        ;;
      [Nn]|none)
        return 1
        ;;
    esac

    normalized=${answer//,/ }
    skipped=" "
    for index in $normalized; do
      if ! [[ "$index" =~ ^[0-9]+$ ]] || [ "$index" -lt 1 ] || [ "$index" -gt "$update_count" ]; then
        echo -e "${YELLOW}Enter update numbers from 1 to $update_count, ${GREEN}Enter${YELLOW} for all, or ${RED}n${YELLOW} for none.${RESET}"
        skipped=""
        break
      fi
      case "$skipped" in
        *" $index "*) ;;
        *) skipped="${skipped}${index} " ;;
      esac
    done

    if [ -n "$skipped" ] && [ "$skipped" != " " ]; then
      CUSTOM_BUILD_SKIP_INDEXES="$skipped"
      return 0
    fi
  done
}

should_skip_custom_build_update() {
  local index=$1
  case "${CUSTOM_BUILD_SKIP_INDEXES:-}" in
    *" $index "*) return 0 ;;
    *) return 1 ;;
  esac
}

mark_update_applied() {
  UPDATES_APPLIED=true
  UPDATED_ITEMS+=("$1")
}

show_flake_update_check() {
  local state_dir
  local state_file
  local last_check="never"
  local metadata_file
  local behind_count=0
  local now

  state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/renix"
  state_file="$state_dir/flake-update-check-last-run"
  mkdir -p "$state_dir"

  if [ -f "$state_file" ]; then
    last_check=$(cat "$state_file" 2>/dev/null || echo "never")
  fi

  echo -e "${BLUE}══════════════════════════════════════════${RESET}"
  echo -e "  ${BOLD}${WHITE}Checking Flake Inputs${RESET}"
  echo -e "${BLUE}══════════════════════════════════════════${RESET}"

  metadata_file=$(mktemp)
  python3 - "$FLAKE_DIR/flake.lock" > "$metadata_file" <<'PY'
import datetime
import json
import sys

lock_path = sys.argv[1]
with open(lock_path, "r", encoding="utf-8") as f:
    lock = json.load(f)

nodes = lock.get("nodes", {})
root = nodes.get(lock.get("root", "root"), {})
inputs = root.get("inputs", {})

for name, node_name in inputs.items():
    node = nodes.get(node_name, {})
    locked = node.get("locked", {})
    original = node.get("original", {})
    if locked.get("type") != "github":
        continue

    owner = locked.get("owner") or original.get("owner") or ""
    repo = locked.get("repo") or original.get("repo") or ""
    rev = locked.get("rev") or ""
    ref = original.get("ref") or locked.get("ref") or "HEAD"
    ts = locked.get("lastModified")
    if ts:
        locked_date = datetime.datetime.fromtimestamp(ts).strftime("%Y-%m-%d")
    else:
        locked_date = "unknown"

    if owner and repo and rev:
        print("|".join([name, owner, repo, ref, rev, locked_date]))
PY

  while IFS='|' read -r name owner repo ref current_rev locked_date; do
    [ -z "$name" ] && continue
    latest_rev=$(git ls-remote "https://github.com/$owner/$repo" "$ref" 2>/dev/null | awk '{print $1; exit}' || true)
    if [ -z "$latest_rev" ]; then
      echo -e "${YELLOW}⚠${RESET} $name: unable to check upstream (current: ${CYAN}${current_rev:0:8}${RESET}, locked: ${CYAN}$locked_date${RESET})"
    elif [ "$latest_rev" = "$current_rev" ]; then
      echo -e "${GREEN}✓${RESET} $name: current (${CYAN}${current_rev:0:8}${RESET}, locked: ${CYAN}$locked_date${RESET})"
    else
      behind_count=$((behind_count + 1))
      echo -e "${YELLOW}⚠${RESET} $name: update available (current: ${CYAN}${current_rev:0:8}${RESET}, latest: ${MAGENTA}${latest_rev:0:8}${RESET}, locked: ${CYAN}$locked_date${RESET})"
    fi
  done < "$metadata_file"
  rm -f "$metadata_file"

  now=$(date '+%Y-%m-%d %H:%M:%S %Z')
  printf '%s\n' "$now" > "$state_file"

  if [ "$behind_count" -gt 0 ]; then
    local preview_parent
    local preview_dir
    local preview_flake_ref
    preview_parent=$(mktemp -d)
    preview_dir="$preview_parent/flake"
    mkdir -p "$preview_dir"
    cp -a "$FLAKE_DIR"/. "$preview_dir"/
    preview_flake_ref="$preview_dir#$CONFIG_NAME"

    echo ""
    echo -e "${YELLOW}$behind_count${RESET} flake input(s) are behind. Updating may rebuild many packages."
    echo -e "${DIM}Updating a temporary flake copy for dry-run preview...${RESET}"
    if ! NIX_CONFIG="warn-dirty = false" nix flake update --flake "$preview_dir" --option warn-dirty false; then
      rm -rf "$preview_parent"
      exit 1
    fi
    echo ""

    echo -e "${BLUE}══════════════════════════════════════════${RESET}"
    echo -e "  ${BOLD}${WHITE}Flake Update Rebuild Preview${RESET}"
    echo -e "${BLUE}══════════════════════════════════════════${RESET}"
    echo -e "${DIM}Running:${RESET} ${BOLD}sudo $REBUILD_TOOL $REBUILD_DRY_ACTION${RESET} ${DIM}--flake${RESET} ${CYAN}$preview_flake_ref${RESET} ${DIM}--option warn-dirty false${RESET}"
    echo ""

    local dry_output
    dry_output=$(mktemp)
    if sudo env NIX_CONFIG="warn-dirty = false" "$REBUILD_TOOL" "$REBUILD_DRY_ACTION" --flake "$preview_flake_ref" --option warn-dirty false >"$dry_output" 2>&1; then
      while IFS= read -r line || [ -n "$line" ]; do
        if should_suppress_output_line "$line"; then
          continue
        fi
        printf '%s\n' "$line"
      done < "$dry_output"
    else
      cat "$dry_output" >&2
      rm -f "$dry_output"
      rm -rf "$preview_parent"
      exit 1
    fi
    rm -f "$dry_output"
    echo ""

    if [ "$FLAKE_CHECK_ONLY" = true ]; then
      rm -rf "$preview_parent"
      echo -e "${DIM}Discarded temporary flake.lock after check.${RESET}"
      exit 0
    fi

    if prompt_yes "Proceed with rebuild using updated flake inputs? [${GREEN}y${RESET}/${RED}N${RESET}] "; then
      cp "$preview_dir/flake.lock" "$FLAKE_DIR/flake.lock"
      rm -rf "$preview_parent"
      echo ""
    else
      rm -rf "$preview_parent"
      echo ""
      echo -e "${DIM}Discarded temporary flake.lock and skipped rebuild.${RESET}"
      exit 0
    fi
  fi
}

update_npm_package() {
  local display_name=$1
  local npm_package=$2
  local derivation_file_rel=$3
  local lockfile_rel=$4
  local new_version=$5

  local pkg_base
  local tarball_url
  local derivation_file
  local lockfile
  local tmpdir
  local src_hash_nix32
  local src_hash
  local npm_deps_hash

  pkg_base="${npm_package##*/}"
  tarball_url="https://registry.npmjs.org/$npm_package/-/$pkg_base-$new_version.tgz"
  derivation_file="$FLAKE_DIR/$derivation_file_rel"
  lockfile="$FLAKE_DIR/$lockfile_rel"

  tmpdir=$(mktemp -d)
  echo -e "${DIM}Updating $display_name package files...${RESET}"

  curl -fsSL -o "$tmpdir/package.tgz" "$tarball_url"

  src_hash_nix32=$(nix-prefetch-url --type sha256 "$tarball_url" 2>/dev/null | tail -n1)
  src_hash=$(nix hash convert --hash-algo sha256 --from nix32 --to sri "$src_hash_nix32")

  tar -xzf "$tmpdir/package.tgz" -C "$tmpdir"
  (
    cd "$tmpdir/package"
    nix shell nixpkgs#nodejs --command \
      npm install --package-lock-only --ignore-scripts --no-audit --no-fund >/dev/null
  )

  cp "$tmpdir/package/package-lock.json" "$lockfile"
  npm_deps_hash=$(nix run nixpkgs#prefetch-npm-deps -- "$lockfile" 2>/dev/null | tail -n1)

  perl -0pi -e 's|version = ".*?";|version = "'$new_version'";|' "$derivation_file"
  TARBALL_URL="$tarball_url" perl -0pi -e 's|url = "https://registry\.npmjs\.org/[^"]+\.tgz";|url = "$ENV{TARBALL_URL}";|' "$derivation_file"
  perl -0pi -e 's|hash = "sha256-[^"]+";|hash = "'$src_hash'";|' "$derivation_file"
  perl -0pi -e 's|npmDepsHash = "sha256-[^"]+";|npmDepsHash = "'$npm_deps_hash'";|' "$derivation_file"

  rm -rf "$tmpdir"
  echo -e "${GREEN}✓${RESET} Updated $display_name package to ${GREEN}$new_version${RESET}."
}

update_pypi_package() {
  local display_name=$1
  local pypi_package=$2
  local derivation_file_rel=$3
  local new_version=$4

  local derivation_file
  local pypi_json
  local artifact_metadata
  local src_hash
  local download_url

  derivation_file="$FLAKE_DIR/$derivation_file_rel"

  echo -e "${DIM}Updating $display_name package files...${RESET}"

  pypi_json=$(curl -fsSL "https://pypi.org/pypi/$pypi_package/$new_version/json")
  artifact_metadata=$(python3 -c '
import base64, json, sys
package = json.load(sys.stdin)
urls = package.get("urls", [])
preferred = None
for item in urls:
    filename = item.get("filename", "")
    if item.get("packagetype") == "bdist_wheel" and filename.endswith("-py3-none-any.whl"):
        preferred = item
        break
if preferred is None:
    for item in urls:
        if item.get("packagetype") == "sdist":
            preferred = item
            break
if preferred is None:
    raise SystemExit("no usable PyPI artifact found")
hex_hash = preferred.get("digests", {}).get("sha256")
url = preferred.get("url")
if not hex_hash:
    raise SystemExit("no sha256 digest found")
if not url:
    raise SystemExit("no artifact URL found")
print(url)
print("sha256-" + base64.b64encode(bytes.fromhex(hex_hash)).decode())
' <<< "$pypi_json")
  download_url=$(printf '%s\n' "$artifact_metadata" | sed -n '1p')
  src_hash=$(printf '%s\n' "$artifact_metadata" | sed -n '2p')

  perl -0pi -e 's|version = ".*?";|version = "'$new_version'";|' "$derivation_file"
  DOWNLOAD_URL="$download_url" perl -0pi -e 's|url = "https://files\.pythonhosted\.org/[^"]+";|url = "$ENV{DOWNLOAD_URL}";|' "$derivation_file"
  perl -0pi -e 's|hash = "sha256-[^"]+";|hash = "'$src_hash'";|' "$derivation_file"

  echo -e "${GREEN}✓${RESET} Updated $display_name package to ${GREEN}$new_version${RESET}."
}

update_fetchurl_static_url_package() {
  local display_name=$1
  local derivation_file_rel=$2
  local download_url=$3
  local new_version=$4

  local derivation_file
  local src_hash_nix32
  local src_hash

  derivation_file="$FLAKE_DIR/$derivation_file_rel"

  echo -e "${DIM}Updating $display_name package files...${RESET}"

  src_hash_nix32=$(nix-prefetch-url --type sha256 "$download_url" 2>/dev/null | tail -n1)
  src_hash=$(nix hash convert --hash-algo sha256 --from nix32 --to sri "$src_hash_nix32")

  perl -0pi -e 's|version = ".*?";|version = "'$new_version'";|' "$derivation_file"
  perl -0pi -e 's|hash = "sha256-[^"]+";|hash = "'$src_hash'";|' "$derivation_file"

  echo -e "${GREEN}✓${RESET} Updated $display_name package to ${GREEN}$new_version${RESET}."
}

render_url_template() {
  local template=$1
  local version=$2
  template="${template//\{version\}/$version}"
  printf '%s\n' "$template"
}

update_fetchurl_template_package() {
  local display_name=$1
  local derivation_file_rel=$2
  local url_template=$3
  local new_version=$4
  local download_url

  download_url=$(render_url_template "$url_template" "$new_version")
  update_fetchurl_static_url_package "$display_name" "$derivation_file_rel" "$download_url" "$new_version"
}

render_arch_url_template() {
  local template=$1
  local version=$2
  local arch=$3
  template=$(render_url_template "$template" "$version")
  template="${template//\{arch\}/$arch}"
  printf '%s\n' "$template"
}

update_fetchurl_template_arch_hashes_package() {
  local display_name=$1
  local derivation_file_rel=$2
  local url_template=$3
  local new_version=$4
  local derivation_file="$FLAKE_DIR/$derivation_file_rel"
  local arch
  local download_url
  local src_hash_nix32
  local src_hash

  echo -e "${DIM}Updating $display_name package files...${RESET}"
  perl -0pi -e 's|version = ".*?";|version = "'$new_version'";|' "$derivation_file"

  for arch in x86_64 arm64; do
    download_url=$(render_arch_url_template "$url_template" "$new_version" "$arch")
    src_hash_nix32=$(nix-prefetch-url --type sha256 "$download_url" 2>/dev/null | tail -n1)
    src_hash=$(nix hash convert --hash-algo sha256 --from nix32 --to sri "$src_hash_nix32")
    ARCH="$arch" HASH="$src_hash" perl -0pi -e 's|(\Q$ENV{ARCH}\E\s*=\s*")[^"]+(";)|$1$ENV{HASH}$2|s' "$derivation_file"
  done

  echo -e "${GREEN}✓${RESET} Updated $display_name package to ${GREEN}$new_version${RESET}."
}

get_update_system_assets_json() {
  local id=$1

  RENIX_CUSTOM_BUILDS_FILE="$FLAKE_DIR/pkgs/custom-builds.nix" nix eval --impure --json --expr '
let
  customBuildsFile = builtins.getEnv "RENIX_CUSTOM_BUILDS_FILE";
  builds = import customBuildsFile;
  matches = builtins.filter (build: build.id == "'"$id"'") builds;
in
  if matches == [] then {} else ((builtins.head matches).update.systemAssets or {})
' 2>/dev/null || echo "{}"
}

update_fetchurl_template_system_assets_package() {
  local display_name=$1
  local id=$2
  local derivation_file_rel=$3
  local url_template=$4
  local new_version=$5
  local derivation_file="$FLAKE_DIR/$derivation_file_rel"
  local system_assets_json
  local system
  local asset
  local download_url
  local src_hash_nix32
  local src_hash

  system_assets_json=$(get_update_system_assets_json "$id")
  if [ -z "$system_assets_json" ] || [ "$system_assets_json" = "{}" ]; then
    echo -e "${RED}✗${RESET} Missing fetchurl-template-system-assets systemAssets for $display_name in custom-builds.nix"
    return 1
  fi

  echo -e "${DIM}Updating $display_name package files...${RESET}"
  perl -0pi -e 's|version = ".*?";|version = "'$new_version'";|' "$derivation_file"

  while IFS=$'\037' read -r system asset; do
    [ -z "$system" ] && continue
    download_url=$(render_asset_url_template "$url_template" "$new_version" "$asset")
    src_hash_nix32=$(nix-prefetch-url --type sha256 "$download_url" 2>/dev/null | tail -n1)
    src_hash=$(nix hash convert --hash-algo sha256 --from nix32 --to sri "$src_hash_nix32")
    SYSTEM="$system" HASH="$src_hash" perl -0pi -e 's|(hash\s*=\s*\{.*?\Q$ENV{SYSTEM}\E\s*=\s*")[^"]+(";.*?\}\.\$\{stdenv\.hostPlatform\.system\};)|$1$ENV{HASH}$2|s' "$derivation_file"
  done < <(python3 -c '
import json, sys
assets = json.loads(sys.argv[1])
for system, asset in sorted(assets.items()):
    print(f"{system}\x1f{asset}")
' "$system_assets_json")

  echo -e "${GREEN}✓${RESET} Updated $display_name package to ${GREEN}$new_version${RESET}."
}

render_asset_url_template() {
  local template=$1
  local version=$2
  local asset=$3
  template=$(render_url_template "$template" "$version")
  template="${template//\{asset\}/$asset}"
  printf '%s\n' "$template"
}

update_github_release_system_assets_package() {
  local display_name=$1
  local derivation_file_rel=$2
  local url_template=$3
  local new_version=$4
  local derivation_file="$FLAKE_DIR/$derivation_file_rel"
  local asset
  local download_url
  local src_hash_nix32
  local src_hash

  echo -e "${DIM}Updating $display_name package files...${RESET}"
  perl -0pi -e 's|version = ".*?";|version = "'$new_version'";|' "$derivation_file"

  for asset in linux-x64 linux-arm64 darwin-x64 darwin-arm64; do
    download_url=$(render_asset_url_template "$url_template" "$new_version" "$asset")
    src_hash_nix32=$(nix-prefetch-url --type sha256 "$download_url" 2>/dev/null | tail -n1)
    src_hash=$(nix hash convert --hash-algo sha256 --from nix32 --to sri "$src_hash_nix32")
    ASSET="$asset" HASH="$src_hash" perl -0pi -e 's|(asset = "\Q$ENV{ASSET}\E";\s*hash = ")[^"]+(";)|$1$ENV{HASH}$2|s' "$derivation_file"
  done

  echo -e "${GREEN}✓${RESET} Updated $display_name package to ${GREEN}$new_version${RESET}."
}

prefetch_github_source_hash() {
  local owner=$1
  local repo=$2
  local rev=$3
  local tarball_url="https://github.com/$owner/$repo/archive/refs/tags/$rev.tar.gz"
  local src_hash_nix32

  src_hash_nix32=$(nix-prefetch-url --unpack --type sha256 "$tarball_url" 2>/dev/null | tail -n1)
  nix hash convert --hash-algo sha256 --from nix32 --to sri "$src_hash_nix32"
}

extract_got_hash() {
  grep -Eo 'got:[[:space:]]+sha256-[A-Za-z0-9+/=]+' | awk '{print $2}' | tail -n1
}

update_github_go_module_package() {
  local display_name=$1
  local derivation_file_rel=$2
  local attr_name=$3
  local owner=$4
  local repo=$5
  local rev_prefix=$6
  local new_version=$7
  local derivation_file="$FLAKE_DIR/$derivation_file_rel"
  local rev="${rev_prefix}${new_version}"
  local src_hash
  local fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  local build_output
  local vendor_hash

  echo -e "${DIM}Updating $display_name package files...${RESET}"
  src_hash=$(prefetch_github_source_hash "$owner" "$repo" "$rev")

  perl -0pi -e 's|version = ".*?";|version = "'$new_version'";|' "$derivation_file"
  perl -0pi -e 's|hash = "sha256-[^"]+";|hash = "'$src_hash'";|' "$derivation_file"
  perl -0pi -e 's|vendorHash = "sha256-[^"]+";|vendorHash = "'$fake_hash'";|' "$derivation_file"

  set +e
  build_output=$(NIX_CONFIG="warn-dirty = false" nix build --impure --no-link --expr "let flake = builtins.getFlake \"$FLAKE_DIR\"; cfg = if flake ? nixosConfigurations && flake.nixosConfigurations ? \"$CONFIG_NAME\" then flake.nixosConfigurations.\"$CONFIG_NAME\" else flake.darwinConfigurations.\"$CONFIG_NAME\"; in cfg.pkgs.\"$attr_name\"" 2>&1)
  set -e
  vendor_hash=$(printf '%s\n' "$build_output" | extract_got_hash)
  if [ -z "$vendor_hash" ]; then
    printf '%s\n' "$build_output" >&2
    echo -e "${RED}✗${RESET} Unable to determine vendorHash for $display_name" >&2
    exit 1
  fi
  perl -0pi -e 's|vendorHash = "sha256-[^"]+";|vendorHash = "'$vendor_hash'";|' "$derivation_file"
  echo -e "${GREEN}✓${RESET} Updated $display_name package to ${GREEN}$new_version${RESET}."
}

update_github_rust_package() {
  local display_name=$1
  local derivation_file_rel=$2
  local attr_name=$3
  local owner=$4
  local repo=$5
  local rev_prefix=$6
  local new_version=$7
  local derivation_file="$FLAKE_DIR/$derivation_file_rel"
  local rev="${rev_prefix}${new_version}"
  local src_hash
  local fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  local build_output
  local cargo_hash

  echo -e "${DIM}Updating $display_name package files...${RESET}"
  src_hash=$(prefetch_github_source_hash "$owner" "$repo" "$rev")

  perl -0pi -e 's|version = ".*?";|version = "'$new_version'";|' "$derivation_file"
  perl -0pi -e 's|hash = "sha256-[^"]+";|hash = "'$src_hash'";|' "$derivation_file"
  perl -0pi -e 's|cargoHash = "sha256-[^"]+";|cargoHash = "'$fake_hash'";|' "$derivation_file"

  set +e
  build_output=$(NIX_CONFIG="warn-dirty = false" nix build --impure --no-link --expr "let flake = builtins.getFlake \"$FLAKE_DIR\"; cfg = if flake ? nixosConfigurations && flake.nixosConfigurations ? \"$CONFIG_NAME\" then flake.nixosConfigurations.\"$CONFIG_NAME\" else flake.darwinConfigurations.\"$CONFIG_NAME\"; in cfg.pkgs.\"$attr_name\"" 2>&1)
  set -e
  cargo_hash=$(printf '%s\n' "$build_output" | extract_got_hash)
  if [ -z "$cargo_hash" ]; then
    printf '%s\n' "$build_output" >&2
    echo -e "${RED}✗${RESET} Unable to determine cargoHash for $display_name" >&2
    exit 1
  fi
  perl -0pi -e 's|cargoHash = "sha256-[^"]+";|cargoHash = "'$cargo_hash'";|' "$derivation_file"
  echo -e "${GREEN}✓${RESET} Updated $display_name package to ${GREEN}$new_version${RESET}."
}

custom_build_update_handler() {
  case "$1" in
    flake-input|npm-package|pypi|fetchurl-static-url|fetchurl-template|fetchurl-template-arch-hashes|github-release-system-assets|fetchurl-template-system-assets|github-go-module|github-rust-package|manual)
      printf '%s\n' "$1"
      ;;
    *)
      echo "renix: unsupported custom build update type: $1" >&2
      return 1
      ;;
  esac
}

should_suppress_output_line() {
  local line="$1"
  case "$line" in
    *"warning: Using 'builtins.derivation' to create a derivation named 'options.json'"*) return 0 ;;
    *"The resulting derivation will not have a correct store reference"*) return 0 ;;
    *) return 1 ;;
  esac
}
