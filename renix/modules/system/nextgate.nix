{ config, lib, pkgs, ... }:

let
  swaySession = import ./sway-session.nix { inherit config lib pkgs; };
in
{
  networking.hostName = "nextgate";

  boot.kernelPackages = pkgs.linuxPackages;
  boot.blacklistedKernelModules = [ "nouveau" "nova_core" "nvidiafb" "ath12k_pci" "ath12k" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.nvidiaPackages.latest.open ];
  boot.kernelModules = [ "nvidia" "nvidia_uvm" "nvidia_modeset" "nvidia_drm" ];
  boot.extraModprobeConfig = ''
    softdep nvidia post: nvidia-uvm
  '';

  services.udev.extraRules = ''
    KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidiactl c 195 255'"
    KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'for i in $$(cat /proc/driver/nvidia/gpus/*/information | grep Minor | cut -d \  -f 4); do mknod -m 666 /dev/nvidia$${i} c 195 $${i}; done'"
    KERNEL=="nvidia_modeset", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-modeset c 195 254'"
    KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 0'"
    KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm-tools c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 1'"

    ACTION=="add|change", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", TAG+="uaccess"

    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="0489", ATTR{idProduct}=="e10a", TEST=="power/control", RUN+="${pkgs.runtimeShell} -c 'echo on > /sys$devpath/power/control'"
  '';

  environment.systemPackages = [
    config.boot.kernelPackages.nvidiaPackages.latest.bin
    pkgs.xorg.xauth
    pkgs.xorg.xhost
  ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    open = true;
    gsp.enable = true;
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  programs.sway.extraOptions = [ "--unsupported-gpu" ];

  # nextgate has no disk encryption, so require an interactive login before
  # starting Sway instead of using the shared greetd autologin initial_session.
  services.greetd = {
    restart = lib.mkForce true;
    settings = lib.mkForce {
      terminal.vt = 1;
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions --cmd ${swaySession}";
        user = "greeter";
      };
    };
  };
  hardware.firmware = [ config.boot.kernelPackages.nvidiaPackages.latest.firmware ];
  hardware.graphics.enable32Bit = true;

  services.pipewire.extraConfig.pipewire."10-audio-stability" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 4096;
      "default.clock.min-quantum" = 2048;
      "default.clock.max-quantum" = 4096;
    };
  };

  # Prefer the RODE microphone plugged into the motherboard USB audio interface
  # over the BRIO webcam microphone.
  services.pipewire.wireplumber.extraConfig."10-nextgate-rode-microphone" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          { "node.name" = "alsa_input.usb-Generic_USB_Audio-00.HiFi__Mic1__source"; }
        ];
        actions.update-props = {
          "node.description" = "RODE Microphone";
          "priority.session" = 3000;
        };
      }
    ];
  };

  services.openssh.settings = {
    X11Forwarding = true;
    X11UseLocalhost = true;
  };

  services.printing = {
    enable = true;
    drivers = [ pkgs.hplip ];
  };
  hardware.printers = {
    ensureDefaultPrinter = "32C-HP-CLJ-M477";
    ensurePrinters = [
      {
        name = "32C-HP-CLJ-M477";
        description = "HP Color LaserJet MFP M477fnw";
        deviceUri = "ipp://10.32.0.106:631/ipp/print";
        # Use HPLIP's M477 PostScript PPD instead of IPP Everywhere/PWG Raster.
        # Helium/Chromium PDF print jobs can get stuck when passed through the
        # generic driver path for this printer.
        model = "HP/hp-color_laserjet_pro_mfp_m477-ps.ppd.gz";
        ppdOptions = {
          PageSize = "Letter";
          InputSlot = "Tray2";
          MediaType = "Plain";
          HPPJLColorAsGray = "off";
        };
      }
    ];
  };
  programs.mosh.enable = true;

  hardware.nvidia-container-toolkit = {
    enable = true;
    suppressNvidiaDriverAssertion = true;
  };

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
}
