{ lib, pkgs, username, config, ... }:
let
  homeDir = "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
in
{
  imports = [ ../../../home.nix ];

  home.sessionPath = [ "${dotfilesDir}/bin/host-specific/pomace" ];

  home.packages = [ pkgs.xclip ];

  systemd.user.services = {
    tart-guest-agent = {
      Unit = {
        Description = "Tart guest agent clipboard bridge";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
        ExecStart = "${lib.getExe pkgs.tart-guest-agent} --debug --run-vdagent";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    clipboard-x11-wayland-bridge = {
      Unit = {
        Description = "Bridge X11 and Wayland clipboards for Tart";
        After = [ "graphical-session.target" "tart-guest-agent.service" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Environment = "PATH=${lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.wl-clipboard pkgs.xclip ]}";
        ExecStart = "${dotfilesDir}/bin/host-specific/pomace/clipboard-x11-wayland-bridge";
        Restart = "always";
        RestartSec = 1;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };

  home.file = {
    ".xbindkeysrc" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/xbindkeys/host-specific/pomace/xbindkeysrc";
    };
    ".config/sway/config" = {
      force = true;
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/sway/host-specific/pomace/config";
    };
  };
}
