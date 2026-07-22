# AGENTS.md

## Scope
This repo is Doug's multi-host NixOS and nix-darwin flake with Home Manager integrated through the system configs.

Current hosts:
- `nextgate`: `hosts/x86_64-linux/nextgate`
- `coregate`: `hosts/x86_64-linux/coregate`
- `nixnode`: `hosts/x86_64-linux/nixnode`
- `pomace`: `hosts/aarch64-linux/pomace`
- `macvm`: `hosts/aarch64-darwin/macvm`

## Architecture map
- `flake.nix`: entrypoint, input pins, `nixosConfigurations.<host>`, and `darwinConfigurations.<host>`.
- `home.nix`: thin shared Home Manager entrypoint for `doug`; keep it as an import of `modules/home`.
- `hosts/<system>/<host>/default.nix`: host system imports and host-level NixOS or nix-darwin settings.
- `hosts/<system>/<host>/home.nix`: host-specific Home Manager additions and overrides.
- `hosts/<system>/<host>/hardware-configuration.nix`: machine-generated NixOS hardware config. Do not hand-edit unless explicitly requested.
- `modules/home/`: shared Home Manager modules, split by concern.
  - `base.nix`: cross-platform identity, session variables, common packages, and common dotfile links.
  - `linux-desktop.nix`: Linux desktop packages, MIME defaults, GTK/Qt/dconf settings, desktop entries, and user services.
  - `shell.nix`, `editor.nix`, `kitty.nix`, `tmux.nix`, `ssh.nix`, `git.nix`, `github.nix`: focused user modules.
- `modules/system/`: shared and host-specific system modules.
  - `common.nix`: true shared NixOS base only.
  - `smb-tnas01.nix`, `bluetooth.nix`, `sway-greetd.nix`: focused opt-in shared services imported by `common.nix`.
  - `overlays.nix`: custom package overlay wiring.
  - `<host>.nix`: host-specific system config.
- `modules/darwin/`: shared nix-darwin modules.
- `pkgs/`: custom packages and helper scripts.
  - `renix.nix`: small wrapper that packages `pkgs/renix/`.
  - `pkgs/renix/renix.sh`: main `renix` command flow.
  - `pkgs/renix/functions.sh`: `renix` helper functions.
  - `custom-builds.nix`: manifest for `renix update` custom build checks.
  - `custom-builds-normalized.nix`: Nix normalizer for the custom build manifest.
  - `*.nix` plus adjacent source files: custom derivations and packaged helper scripts.
- `bootstrap/`: one-off bootstrap scripts.

## Design standards
- Keep `system.stateVersion` and `home.stateVersion` at `25.11` unless intentionally migrating.
- Prefer small, focused modules. Do not let files grow past 1000 lines. If a change is pushing a file toward that boundary, split by ownership first.
- Avoid spaghetti growth. Do not bolt host-specific or feature-specific branches into shared flows when a focused module, package, or helper can own the behavior.
- Keep shared system concerns in `modules/system/common.nix` only if they are genuinely common. Otherwise create or use a focused module under `modules/system/` and import it where appropriate.
- Keep shared user concerns in `modules/home/`. Host-specific user config belongs in `hosts/<system>/<host>/home.nix`.
- Keep root `home.nix` thin. It should only import `modules/home`.
- Keep hardware configs only under `hosts/<system>/<host>/hardware-configuration.nix`.
- Prefer direct, boring Nix over clever indirection. Abstractions must delete complexity or make ownership clearer.
- When adding data-driven behavior, make the data boundary explicit. Avoid positional field protocols unless there is a strong reason.
- For repeated conditionals, look for a missing model, helper, or module boundary.

## Dotfiles and scripts
- Dotfiles are symlinked out-of-store from `$DOTFILES/...`, with `$DOTFILES` set to `$HOME/dotfiles`.
- User-maintained config files such as sway, i3blocks, dunst, waycorner, rofi, and app configs should live in `$DOTFILES/...` and be symlinked by Home Manager.
- For Sway config changes, edit the included files under `$DOTFILES/sway/...` unless explicitly asked to change Nix ownership. Do not replace a Home Manager symlink to Sway config with inline `home.file.*.text` just to add a setting.
- User scripts should live in `$DOTFILES/bin` and be called directly as `$DOTFILES/bin/...` from configs.
- Host-specific scripts should live in `$DOTFILES/bin/host-specific/<host>/` and be called directly from host-specific configs.
- Do not rely on `~/.local/bin` being in `PATH` for window-manager launched commands.
- Dotfile scripts should avoid embedded `/nix/store/...` paths. Add runtime tools to `home.packages` or system packages and call them through `PATH`.
- User-maintained assets used by scripts or configs, for example Stream Deck icons, belong under `$DOTFILES/...` unless they are Nix build inputs.
- Do not define substantial scripts inline in Nix `home.file.*.text`. Prefer:
  - a dotfiles script with a tiny Nix wrapper, or
  - a small packaged helper under `pkgs/` when Nix-provided runtime dependencies are the point.

## Package and overlay conventions
- Add new custom package derivations under `pkgs/<name>.nix`.
- Wire custom packages through `modules/system/overlays.nix`.
- Gate binary overrides by platform and architecture. Do not apply an x86_64 binary override on aarch64.
- If a custom package should be checked by `renix update`, add it to `pkgs/custom-builds.nix`.
- Keep `pkgs/custom-builds.nix` entries sorted alphabetically by `displayName` or `id`.
- Prefer extending `pkgs/custom-builds.nix` over adding per-package logic to `renix`.
- If new discovery behavior is needed, add a reusable source adapter in `pkgs/renix/custom_builds.py`. If new mutation behavior is needed, add a reusable `update.type` handler in `pkgs/renix/functions.sh`. Keep the manifest as the package-specific layer.

## UI and desktop preferences
- Doug prefers tiling-WM and system-owned window management with no app-drawn minimize, maximize, or close buttons.
- Preserve global GTK `gtk-decoration-layout = ":"`.
- Prefer app-native settings such as system title bar or system window frame when available.
- For Electron or custom-titlebar apps, hide app-rendered window controls through targeted package patches when practical.

## Common operations for Doug
- Preferred apply path: `renix`.
  - Auto-detects host with `hostname -s`.
  - Runs the matching flake config without custom build checks.
  - Override host with `RENIX_HOST=<host> renix`.
- Pull latest repo changes: `renix sync` or `renix -s`.
- Check custom builds before rebuilding: `renix update` or `renix -u`.
- Check flake inputs and preview rebuild: `renix upgrade` or `renix -ug`.
- Full maintenance flow: `renix full` or `renix -f`.
- Direct NixOS apply path: `sudo nixos-rebuild switch --flake /home/doug/renix#$(hostname -s) --option warn-dirty false`.
- Update one input manually: `nix flake update <input-name>`.

## Agent rules
- Make minimal, targeted edits unless the user explicitly asks for a structural cleanup.
- When doing structural cleanup, move code to clearer ownership boundaries. Do not just spread the same complexity across more files.
- Do not run `renix` or `./result/bin/renix` unless Doug explicitly tells you to run it. Leave actual apply and rebuild operations to Doug.
- If asked to apply changes, do not apply them yourself. Tell Doug the appropriate command, usually `renix`.
- If `pkgs/renix.nix` or files under `pkgs/renix/` were edited in the current session, suggest the freshly built local script instead: `./result/bin/renix`.
- Do not hand-edit hardware configuration files unless explicitly requested.
- Use bash for repo inspection and file operations, even though the local interactive shell is fish.
- Use `read` to inspect files and `edit` for precise replacements when practical.
- Use `write` for new files or intentional full rewrites.
- Add new files referenced by Nix evaluation to git before evaluation or rebuild checks, so flakes can see them.

## Validation guidance
Do not validate automatically after every small edit. Validation can be slow and interrupt iteration.

Skip validation for routine edits unless:
- the user explicitly asks for validation, check, build, or apply,
- the edit is structurally risky or likely to break Nix evaluation,
- adding, removing, or renaming files referenced by Nix,
- changing flake inputs, outputs, or module wiring,
- changing `pkgs/renix.nix` or files under `pkgs/renix/`.

Fast validation options:
- Parse Nix files after structural moves: `find modules pkgs hosts -name '*.nix' -print0 | xargs -0 -n1 nix-instantiate --parse >/dev/null`.
- Evaluate the current NixOS host: `nix eval --impure --raw .#nixosConfigurations.$(hostname -s).config.system.build.toplevel.drvPath`.
- Evaluate all hosts when module wiring changes:
  - `nix eval --impure --raw .#nixosConfigurations.nextgate.config.system.build.toplevel.drvPath`
  - `nix eval --impure --raw .#nixosConfigurations.coregate.config.system.build.toplevel.drvPath`
  - `nix eval --impure --raw .#nixosConfigurations.nixnode.config.system.build.toplevel.drvPath`
  - `nix eval --impure --raw .#nixosConfigurations.pomace.config.system.build.toplevel.drvPath`
  - `nix eval --impure --raw .#darwinConfigurations.macvm.system`
- Build a focused package when editing a package derivation: `nix-build -E 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage ./pkgs/<name>.nix {}' --no-out-link`.

Run `nix flake check` only for broad changes such as flake structure changes, host additions/removals, broad module refactors, or when explicitly requested.

## Renix validation
After changing `pkgs/renix.nix` or files under `pkgs/renix/`, automatically build the `renix` package:

```sh
nix-build -E 'let pkgs = import <nixpkgs> {}; in builtins.elemAt (import ./pkgs/renix.nix { inherit pkgs; }).environment.systemPackages 0'
```

Then smoke-test non-mutating behavior when relevant, for example:

```sh
./result/bin/renix --help
```

The build creates or updates `./result`. Treat it as a local build artifact and do not commit it.
