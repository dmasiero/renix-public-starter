#!/usr/bin/env bash
set -euo pipefail

sudo -n -v
[ "$(sudo -H sh -c 'printf sudo-ok')" = "sudo-ok" ]

system_generations=$(sudo -H nix-env --list-generations --profile /nix/var/nix/profiles/system)
grep -q '(current)' <<< "$system_generations"

cleanup_output=$(sudo -H nix-env --delete-generations +5 --profile /nix/var/nix/profiles/system)
grep -q 'preserving the five simulated system generations' <<< "$cleanup_output"

nix-collect-garbage -d | grep -q 'garbage collection completed'
nix store optimise | grep -q 'store optimisation completed'

transition_fixture=$(mktemp -d)
trap 'rm -rf "$transition_fixture"' EXIT
mkdir -p "$transition_fixture/flake/pkgs/renix" "$transition_fixture/bin"
printf '#!/usr/bin/env bash\nprintf "full workflow completed\\n"\n' > "$transition_fixture/flake/pkgs/renix/renix.sh"
printf '#!/usr/bin/env bash\nprintf "fish shell started\\n"\n' > "$transition_fixture/bin/fish"
chmod +x "$transition_fixture/bin/fish"
transition_output=$(
  PATH="$transition_fixture/bin:$PATH" \
  RENIX_FLAKE_DIR="$transition_fixture/flake" \
  RENIX_DEMO=1 \
  RENIX_FORCE_FISH=1 \
    "$RENIX_SEED/demo/bin/renix" full
)
grep -q 'full workflow completed' <<< "$transition_output"
grep -q 'fish shell started' <<< "$transition_output"

printf 'Demo system adapters passed.\n'
