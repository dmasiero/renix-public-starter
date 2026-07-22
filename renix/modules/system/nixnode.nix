{ lib, pkgs, username, ... }:

let
  swaySession = pkgs.writeShellScript "renix-sway-session" ''
    export DOTFILES="$HOME/dotfiles"
    exec ${pkgs.sway}/bin/sway "$@"
  '';


in
{
  imports = [ ./nixnode-audio.nix ];

  networking = {
    hostName = "nixnode";
    networkmanager = {
      enable = true;
      unmanaged = [ "type:wifi" ];
    };
    wireless.iwd = {
      enable = true;
      settings = {
        General.EnableNetworkConfiguration = true;
        Settings.AutoConnect = true;
        Network.EnableIPv6 = true;
      };
    };
  };

  users.users.${username}.extraGroups = [ "networkmanager" ];


  hardware.graphics.enable = true;

  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
    ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="platform::mute", RUN+="${pkgs.coreutils}/bin/chgrp users /sys/class/leds/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod 0664 /sys/class/leds/%k/brightness"
    ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="platform::micmute", RUN+="${pkgs.coreutils}/bin/chgrp users /sys/class/leds/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod 0664 /sys/class/leds/%k/brightness"
  '';

  # ThinkPad speaker/mic mute LEDs are exposed through sysfs, but Sway key
  # handlers run as the desktop user. Make those two LED brightness files writable so the
  # host-specific OSD scripts can keep the keyboard LEDs in sync with PipeWire.
  systemd.services = {
    thinkpad-mute-led-permissions = {
      description = "Allow user control of ThinkPad mute LEDs";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        for led in /sys/class/leds/platform::mute/brightness /sys/class/leds/platform::micmute/brightness; do
          if [ -e "$led" ]; then
            chgrp users "$led" || true
            chmod 0664 "$led" || true
          fi
        done
      '';
    };


    nixnode-ucsi-reload = {
      description = "Recover ThinkPad USB-C controller when UCSI initialization races firmware";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      serviceConfig.Type = "oneshot";
      path = [ pkgs.coreutils pkgs.kmod ];
      script = ''
        if [ ! -e /sys/class/typec/port0 ]; then
          modprobe -r ucsi_acpi typec_ucsi || true
          sleep 1
          modprobe ucsi_acpi || true
        fi
      '';
    };
  };

  environment.systemPackages = [
    pkgs.xorg.xauth
    pkgs.xorg.xhost
  ];

  services.openssh.extraConfig = ''
    Match User ${username}
      PasswordAuthentication yes
  '';

  # LightDM is unreliable for autologin into Sway on this Panther Lake
  # laptop: it reaches graphical.target but logs
  # "session_run: assertion 'priv->display_server != NULL' failed" and
  # leaves the machine at a TTY. Use greetd for native Wayland autologin.
  services.xserver.displayManager.lightdm.enable = lib.mkForce false;
  services.displayManager.autoLogin.enable = lib.mkForce false;
  services.greetd = {
    enable = true;
    restart = false;
    settings = {
      initial_session = {
        command = lib.mkForce "${swaySession}";
        user = username;
      };
      default_session = {
        command = lib.mkForce "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions:/run/current-system/sw/share/xsessions --cmd ${swaySession}";
        user = "greeter";
      };
    };
  };

  services.printing.enable = true;
  hardware.printers = {
    ensureDefaultPrinter = "32C-HP-CLJ-M477";
    ensurePrinters = [
      {
        name = "32C-HP-CLJ-M477";
        description = "HP Color LaserJet MFP M477fnw";
        deviceUri = "ipp://10.32.0.106:631/ipp/print";
        # Use the static generic IPP Everywhere/PWG Raster driver rather than
        # `model = "everywhere"`. The latter probes the printer while creating
        # the queue, so ensure-printers can fail and leave no printer configured
        # when the M477 is asleep/offline at boot.
        model = "drv:///cupsfilters.drv/pwgrast.ppd";
        ppdOptions = {
          PageSize = "Letter";
          PwgRasterDocumentType = "Rgb_8";
          ColorModel = "DeviceRGB";
          "print-color-mode-default" = "color";
        };
      }
    ];
  };

  programs.mosh.enable = false;
  programs.virt-manager.enable = true;
  services.libinput.enable = true;
  services.xserver.inputClassSections = [
    ''
      Identifier "Disable touchpad"
      MatchIsTouchpad "on"
      Option "Ignore" "true"
    ''
  ];
}
