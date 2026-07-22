#!/usr/bin/env bash
set -euo pipefail

HOST_NAME="${RENIX_HOST:-macvm}"
NIX_DIR="${RENIX_NIX_DIR:-${RENIX_FLAKE_DIR:-/Users/doug/renix}}"
DOTFILES_DIR="${RENIX_DOTFILES_DIR:-/Users/doug/dotfiles}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This bootstrap is macOS-only."
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "This config is Apple Silicon only; expected arm64, got $(uname -m)."
  exit 1
fi

if [[ "$(id -un)" != "doug" ]]; then
  echo "Run this as the doug user."
  exit 1
fi

cat <<EOF
Doug's nix-darwin bootstrap

This will:
  1. Install Determinate Nix if Nix is missing.
  2. Install Homebrew if brew is missing.
  3. Create ${DOTFILES_DIR}/wallpapers/darwin/solid-1C1C1E.ppm and apply it.
  4. Activate nix-darwin host ${HOST_NAME} from the existing ${NIX_DIR} checkout.

Before continuing, make sure SSH/network access for the repo is ready.
EOF

read -r -p "Continue? [y/N] " choice
case "$choice" in
  [Yy]*) ;;
  *) echo "Aborted."; exit 0 ;;
esac

sudo -v
(
  while true; do
    sleep 60
    sudo -n -v >/dev/null 2>&1 || exit
  done
) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

if [[ ! -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  echo "Installing Determinate Nix..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
fi

# shellcheck disable=SC1091
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(/opt/homebrew/bin/brew shellenv)"
export HOMEBREW_CURL_RETRIES="${HOMEBREW_CURL_RETRIES:-10}"
# Clear any partial Adobe cask download before the initial nix-darwin activation.
rm -f /Users/doug/Library/Caches/Homebrew/downloads/*adobe* /Users/doug/Library/Caches/Homebrew/downloads/*ACCC* 2>/dev/null || true

if [[ -d "${DOTFILES_DIR}/ssh" && ! -e /Users/doug/.ssh ]]; then
  echo "Linking SSH keys from ${DOTFILES_DIR}/ssh..."
  ln -s "${DOTFILES_DIR}/ssh" /Users/doug/.ssh
  chmod 700 "${DOTFILES_DIR}/ssh" || true
fi

WALLPAPER_FILE="${DOTFILES_DIR}/wallpapers/darwin/solid-1C1C1E.ppm"
echo "Creating wallpaper at ${WALLPAPER_FILE}..."
mkdir -p "$(dirname "$WALLPAPER_FILE")"
cat > "$WALLPAPER_FILE" <<'EOF'
P3
1 1
255
28 28 30
EOF

echo "Applying wallpaper..."
osascript <<EOF || true
tell application "System Events"
  tell every desktop
    set picture to "${WALLPAPER_FILE}"
  end tell
end tell
EOF

if [[ ! -f "$NIX_DIR/flake.nix" ]]; then
  echo "Expected an existing nix checkout at ${NIX_DIR}."
  echo "Side-load the latest master checkout to ${NIX_DIR}, then rerun this script."
  exit 1
fi

cd "$NIX_DIR"

suppress_options_json_warning() {
  awk '
    /warning: Using '\''builtins.derivation'\'' to create a derivation named '\''options.json'\''/ { skip = 1; next }
    skip && /The resulting derivation will not have a correct store reference/ { skip = 0; next }
    { print }
  '
}

echo "Activating nix-darwin for ${HOST_NAME}..."
set +e
sudo -H nix run github:nix-darwin/nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch \
  --flake "$NIX_DIR#$HOST_NAME" \
  --option warn-dirty false 2>&1 | suppress_options_json_warning
rebuild_status=${PIPESTATUS[0]}
set -e
if [[ "$rebuild_status" -ne 0 ]]; then
  exit "$rebuild_status"
fi

echo "Restarting Dock so managed icons are visible and usable..."
killall Dock 2>/dev/null || true

DEV_PARENT="/Users/doug/dev/masiero"
GITEA_KEY="${DOTFILES_DIR}/ssh/gitea_masiero_doug"

clone_gitea_repo() {
  local name="$1"
  local repo="ssh://git@gitea.masiero.internal:2222/masiero/${name}.git"
  local dir="$DEV_PARENT/$name"

  if [[ -d "$dir/.git" ]]; then
    echo "$name already exists at ${dir}; skipping clone."
  else
    echo "Cloning $name to ${dir}..."
    (
      cd "$DEV_PARENT"
      GIT_SSH_COMMAND="ssh -i $GITEA_KEY -o IdentitiesOnly=yes" \
        nix shell nixpkgs#git --command git clone "$repo"
    )
  fi
}

mkdir -p "$DEV_PARENT"
clone_gitea_repo smanager
clone_gitea_repo minus1password

echo "Bootstrap complete. Future updates can use: renix"
