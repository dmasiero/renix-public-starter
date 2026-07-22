{ config, lib, pkgs, username ? "doug", ... }:

let
  swaySession = import ./sway-session.nix { inherit config lib pkgs; };
in
{
  programs.sway = {
    enable = true;
    xwayland.enable = true;
  };

  services.greetd = {
    enable = true;
    restart = false;
    settings = {
      initial_session = {
        command = "${swaySession}";
        user = username;
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions --cmd ${swaySession}";
        user = "greeter";
      };
    };
  };
}
