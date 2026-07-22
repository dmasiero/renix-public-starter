#!/usr/bin/env bash
set -euo pipefail

SEED_ROOT=${RENIX_SEED:-/opt/renix-public-starter}
PROJECT_ROOT=${RENIX_WORKSPACE:-/workspace/renix-public-starter}

heading() {
  printf '\n\033[1;36m%s\033[0m\n' "$1"
  printf '%s\n' '============================================================'
}

validate_project() {
  local root=${1:?project root is required}
  [[ -f "$root/renix/flake.nix" && -f "$root/demo/entrypoint.sh" ]] || {
    printf 'Not a Renix public starter repository: %s\n' "$root" >&2
    return 1
  }
}

install_seed() {
  local destination=${1:?destination is required}
  mkdir -p "$(dirname "$destination")"
  cp -a "$SEED_ROOT" "$destination"
}

clone_repository() {
  local repository=${1:?repository URL is required}
  local temporary="${PROJECT_ROOT}.clone.$$"

  rm -rf "$temporary"
  heading "Cloning $repository"
  git clone "$repository" "$temporary"
  validate_project "$temporary"
  rm -rf "$PROJECT_ROOT"
  mv "$temporary" "$PROJECT_ROOT"
}

initialize_workspace() {
  if [[ ! -d "$PROJECT_ROOT" ]]; then
    if [[ -n "${RENIX_REPO:-}" ]]; then
      clone_repository "$RENIX_REPO"
    else
      install_seed "$PROJECT_ROOT"
    fi
  fi

  validate_project "$PROJECT_ROOT"
  local seed_version workspace_version=""
  seed_version=$(<"$SEED_ROOT/demo/IMAGE_VERSION")
  if [[ -f "$PROJECT_ROOT/demo/IMAGE_VERSION" ]]; then
    workspace_version=$(<"$PROJECT_ROOT/demo/IMAGE_VERSION")
  fi
  if [[ ! -d "$PROJECT_ROOT/.git" && "$seed_version" != "$workspace_version" ]]; then
    printf '\n\033[1;33mWorkspace notice:\033[0m this volume contains an older image seed.\n'
    printf 'Run \033[1mrenix-lab reset\033[0m to replace it, or keep it if you want to preserve edits.\n'
  fi

  mkdir -p /home/doug /workspace/.pi/agent/skills
  ln -sfn "$PROJECT_ROOT/dotfiles" /home/doug/dotfiles
  rm -rf /home/doug/.pi
  ln -s /workspace/.pi /home/doug/.pi

  export RENIX_PI_DIR=/workspace/.pi
  export RENIX_FLAKE_DIR="$PROJECT_ROOT/renix"
  export RENIX_SCRIPT="$RENIX_FLAKE_DIR/pkgs/renix/renix.sh"
  # Container safety adapters belong to the image, not the persistent fork.
  # Keeping them first also lets image updates repair an existing workspace.
  export PATH="$SEED_ROOT/demo/bin:$PROJECT_ROOT/demo/bin:$PATH"
  cd "$PROJECT_ROOT"
}

host_system() {
  local host=${1:?host is required}
  local host_path
  host_path=$(find "$RENIX_FLAKE_DIR/hosts" -mindepth 2 -maxdepth 2 -type d -name "$host" -print -quit)
  [[ -n "$host_path" ]] || {
    printf 'Unknown host: %s\n' "$host" >&2
    list_hosts >&2
    return 1
  }
  basename "$(dirname "$host_path")"
}

list_hosts() {
  heading 'Available configurations'
  while IFS= read -r path; do
    printf '  %-16s %s\n' "$(basename "$path")" "$(basename "$(dirname "$path")")"
  done < <(find "$RENIX_FLAKE_DIR/hosts" -mindepth 2 -maxdepth 2 -type d | sort)
}

run_tests() {
  heading 'Running the real Renix test suite'
  cd "$RENIX_FLAKE_DIR/pkgs/renix"
  python3 -m unittest -v test_custom_builds.py
  bash test_dispatch.sh
  cd "$PROJECT_ROOT"
  bash "$SEED_ROOT/demo/test_adapters.sh"
  printf '\033[32mAll Renix tests passed.\033[0m\n'
}

run_verify() {
  local host=${1:-${RENIX_HOST:-demo}}
  local system
  system=$(host_system "$host")

  run_tests
  heading "Real Nix evaluation: $host ($system)"
  printf '%s\n' 'The complete configuration is evaluated without building or activating it.'

  cd "$RENIX_FLAKE_DIR"
  if [[ "$system" == *-darwin ]]; then
    /root/.nix-profile/bin/nix eval --impure --raw ".#darwinConfigurations.${host}.system"
  else
    /root/.nix-profile/bin/nix eval --impure --raw ".#nixosConfigurations.${host}.config.system.build.toplevel.drvPath"
  fi
  cd "$PROJECT_ROOT"
  printf '\n\033[32mConfiguration evaluation succeeded.\033[0m\n'
}

run_tour() {
  cat <<'EOF'

Renix Nix Container Lab

Everything in this demo happens inside the container. The image creates a
writable, persistent workspace containing the flake and sanitized dotfiles.
Edit the configuration, run tests, evaluate hosts, and exercise Renix without
installing Nix or cloning the repository onto the Docker host.

Only final operating-system activation is adapted because a Docker container
cannot replace its host. The adapter is visible and prints the exact rebuild
command that a real machine would execute.
EOF

  run_tests
  list_hosts

  heading 'Repository model'
  printf 'Workspace: %s\n' "$PROJECT_ROOT"
  printf 'Shared system modules: '
  find "$RENIX_FLAKE_DIR/modules/system" -maxdepth 1 -name '*.nix' | wc -l
  printf 'Shared Home Manager modules: '
  find "$RENIX_FLAKE_DIR/modules/home" -maxdepth 1 -name '*.nix' | wc -l
  printf 'Sanitized dotfile files: '
  find "$PROJECT_ROOT/dotfiles" -type f | wc -l

  heading 'The real Renix interface'
  bash "$RENIX_SCRIPT" --help

  heading "Safe end-to-end workflow for ${RENIX_HOST:-demo}"
  bash "$RENIX_SCRIPT"

  heading 'Continue inside the container'
  cat <<EOF
Start an interactive workspace:
  docker run --rm -it -v renix-workspace:/workspace -v renix-nix:/nix ${RENIX_IMAGE:-ghcr.io/dmasiero/renix-public-starter:latest} shell

Run Renix directly:
  renix --help
  renix update
  renix upgrade

Container-only helpers remain available for editing and evaluation:
  renix-lab edit
  renix-lab verify demo
  renix-lab reset
EOF
}

run_edit() {
  local path=${1:-renix/hosts/x86_64-linux/demo/default.nix}
  exec "${EDITOR:-nano}" "$PROJECT_ROOT/$path"
}

reset_workspace() {
  heading 'Resetting the container workspace'
  rm -rf "$PROJECT_ROOT"
  install_seed "$PROJECT_ROOT"
  printf 'Workspace restored from the image seed.\n'
}

initialize_workspace

case "${1:-tour}" in
  tour)
    run_tour
    ;;
  hosts)
    list_hosts
    ;;
  test)
    run_tests
    ;;
  verify)
    shift
    run_verify "${1:-${RENIX_HOST:-demo}}"
    ;;
  edit)
    shift
    run_edit "${1:-renix/hosts/x86_64-linux/demo/default.nix}"
    ;;
  clone)
    shift
    clone_repository "${1:?Usage: renix-lab clone REPOSITORY_URL}"
    printf 'Fork cloned into %s. Restart the shell to use it.\n' "$PROJECT_ROOT"
    ;;
  reset)
    reset_workspace
    ;;
  renix)
    shift
    if [[ $# -gt 0 ]] && find "$RENIX_FLAKE_DIR/hosts" -mindepth 2 -maxdepth 2 -type d -name "$1" | grep -q .; then
      export RENIX_HOST=$1
      shift
    fi
    exec bash "$RENIX_SCRIPT" "$@"
    ;;
  shell)
    cat <<'EOF'

Welcome to the Renix container workspace.

Start by running:
  renix full

This exercises the complete maintenance workflow and then automatically moves
into Fish with Herdr, Pi, and the configured Neovim available.
EOF
    export PS1='[renix \W]$ '
    bash --noprofile --norc
    ;;
  help|-h|--help)
    cat <<'EOF'
Usage: renix-lab COMMAND [ARGS]

Commands:
  tour                  Run the guided demonstration
  hosts                 List available configurations
  test                  Run Python and shell tests
  verify [HOST]         Evaluate a complete host with real Nix
  edit [PATH]           Edit a workspace file with nano
  clone URL             Replace the workspace with a compatible fork
  renix [HOST] [ARGS]   Exercise Renix safely from Docker arguments
  shell                 Open an interactive container shell
  reset                 Restore the workspace from the image
EOF
    ;;
  *)
    exec "$@"
    ;;
esac
