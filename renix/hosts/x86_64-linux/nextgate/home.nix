{ pkgs, username, config, lib, ... }:
let
  homeDir = "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
  kittyExe = lib.getExe pkgs.kitty;
  xkill = "${pkgs.xorg.xkill}/bin/xkill";
  streamdeckPython = pkgs.python3.withPackages (ps: with ps; [ streamdeck pillow cairosvg ]);
in
{
  imports = [ ../../../home.nix ];

  home.sessionPath = [ "${dotfilesDir}/bin/host-specific/nextgate" ];

  # Host-specific files and scripts
  home.file = {
    ".xbindkeysrc" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/xbindkeys/host-specific/nextgate/xbindkeysrc";
    };
    ".config/renix/scripts/streamdeck-controls" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        export STREAMDECK_KITTY=${lib.escapeShellArg kittyExe}
        export STREAMDECK_XKILL=${lib.escapeShellArg xkill}
        export STREAMDECK_KASA=${lib.escapeShellArg (dotfilesDir + "/bin/host-specific/nextgate/kasa")}
        export STREAMDECK_TUX_SVG=${lib.escapeShellArg (dotfilesDir + "/streamdeck/images/tux.svg")}
        export STREAMDECK_SKULL_PNG=${lib.escapeShellArg (dotfilesDir + "/streamdeck/images/skull.png")}
        exec ${streamdeckPython}/bin/python3 ${lib.escapeShellArg (dotfilesDir + "/bin/host-specific/nextgate/streamdeck-controls")}
      '';
    };
    ".config/sway/config" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/sway/host-specific/nextgate/config";
    };
  };

  systemd.user.services.streamdeck-controls = {
    Unit = {
      Description = "Stream Deck controls";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${homeDir}/.config/renix/scripts/streamdeck-controls";
      Restart = "always";
      RestartSec = "5s";
      Environment = [
        "DOTFILES=${dotfilesDir}"
        "SSH_AUTH_SOCK=%t/ssh-agent"
        "PATH=${lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.openssh ]}"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
