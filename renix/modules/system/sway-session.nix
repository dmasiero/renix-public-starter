{ config, lib, pkgs }:

pkgs.writeShellScript "renix-sway-session" ''
  export DOTFILES="$HOME/dotfiles"
  exec ${pkgs.sway}/bin/sway ${lib.escapeShellArgs config.programs.sway.extraOptions} "$@"
''
