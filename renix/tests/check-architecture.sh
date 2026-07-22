#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"

mime_json=$(nix eval --impure --json .#nixosConfigurations.nixnode.config.home-manager.users.doug.xdg.mimeApps.defaultApplications)
MIME_JSON="$mime_json" python3 - <<'PY'
import json
import os
mime = json.loads(os.environ["MIME_JSON"])
assert mime["text/html"] == ["firefox.desktop"]
assert mime["inode/directory"] == ["yazi-browser.desktop"]
PY

decoration=$(nix eval --impure --raw .#nixosConfigurations.nixnode.config.home-manager.users.doug.gtk.gtk3.extraConfig.gtk-decoration-layout)
[ "$decoration" = ":" ]

timer_unit=$(nix eval --impure --raw .#nixosConfigurations.nixnode.config.home-manager.users.doug.systemd.user.timers.battery-warning.Timer.Unit)
[ "$timer_unit" = "battery-warning.service" ]

ucm=$(nix eval --impure --raw .#nixosConfigurations.nixnode.config.systemd.user.services.pipewire.environment.ALSA_CONFIG_UCM2)
ucm_store=${ucm%%/share/*}
nix-store -r "$ucm_store" >/dev/null
grep -q 'SectionDevice."Headphones"' "$ucm/sof-soundwire/cs42l45.conf"
grep -q "cs42l45 IT 11 Switch" "$ucm/sof-soundwire/cs42l45-dmic.conf"
