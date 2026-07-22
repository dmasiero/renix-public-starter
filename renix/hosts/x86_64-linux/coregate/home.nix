{ pkgs, username, config, lib, ... }:
let
  homeDir = "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
  kittyExe = lib.getExe pkgs.kitty;
  streamdeckPython = pkgs.python3.withPackages (ps: with ps; [ streamdeck pillow cairosvg ]);
in
{
  imports = [ ../../../home.nix ];

  home.sessionPath = [ "${dotfilesDir}/bin/host-specific/coregate" ];

  home.packages = with pkgs; [
    impala
    zoom-us
    brightnessctl
    alsa-utils
  ];

  # Host-specific files and scripts
  home.file = {
    ".xbindkeysrc" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/xbindkeys/host-specific/coregate/xbindkeysrc";
    };
    ".config/renix/scripts/streamdeck-controls" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        export STREAMDECK_KITTY=${lib.escapeShellArg kittyExe}
        export STREAMDECK_TUX_SVG=${lib.escapeShellArg (dotfilesDir + "/streamdeck/images/tux.svg")}
        exec ${streamdeckPython}/bin/python3 ${lib.escapeShellArg (dotfilesDir + "/bin/host-specific/coregate/streamdeck-controls")}
      '';
    };
    ".config/sway/config" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/sway/host-specific/coregate/config";
    };
  };
}
