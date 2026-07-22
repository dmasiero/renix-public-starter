Home Manager shared config is split into importable modules here.

Module map:
- `base.nix`: shared user identity, common packages, session variables, dotfile symlinks, and activation hooks.
- `linux-desktop.nix`: Linux desktop packages, MIME defaults, GTK/Qt/dconf settings, desktop entries, and user services.
- `shell.nix`: fish shell configuration and prompt.
- `editor.nix`: Neovim configuration.
- `kitty.nix`: Kitty terminal emulator package and configuration symlink.
- `tmux.nix`: tmux configuration.
- `ssh.nix`: SSH client configuration.
- `git.nix`: Git configuration.
- `github.nix`: GitHub CLI configuration and shared auth-state symlink.

Root `home.nix` imports this directory via `./modules/home`.
Host-specific additions remain in `hosts/<system>/<hostname>/home.nix`.
