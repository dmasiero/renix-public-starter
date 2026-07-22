{ pkgs, username, lib, ... }:
let
  homeDir = "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
in
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    home.activation.initSwayWallpaperState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      state_dir="${homeDir}/.local/state"
      current_file="$state_dir/wallpaper-rotate-current"
      sway_config="$state_dir/sway-wallpaper.conf"
      default_wallpaper="${dotfilesDir}/wallpapers/wp9132916-rainy-day-4k-wallpapers.jpg"

      if [ ! -e "$sway_config" ]; then
        mkdir -p "$state_dir"
        wallpaper="$default_wallpaper"
        if [ -s "$current_file" ]; then
          current_wallpaper="$(cat "$current_file")"
          if [ -f "$current_wallpaper" ]; then
            wallpaper="$current_wallpaper"
          fi
        fi
        escaped_wallpaper="$(printf '%s' "$wallpaper" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        printf 'output * bg "%s" fill\n' "$escaped_wallpaper" > "$sway_config"
      fi
    '';

    systemd.user.services.battery-warning = {
      Unit = {
        Description = "Battery warning notifications";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${dotfilesDir}/bin/battery-warning";
      };
    };

    systemd.user.timers.battery-warning = {
      Unit.Description = "Check battery level for warning notifications";
      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = "1min";
        Unit = "battery-warning.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    systemd.user.services.night-shift = {
      Unit = {
        Description = "Apply DP-1 night-shift tint on schedule";
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.bash}/bin/bash ${dotfilesDir}/bin/night-shift-refresh --loop";
        Environment = "PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gawk pkgs.wlsunset pkgs.xorg.xrandr ]}";
        Restart = "always";
        RestartSec = 10;
      };
      Install.WantedBy = [ "default.target" ];
    };
}
