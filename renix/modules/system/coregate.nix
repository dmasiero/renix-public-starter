{ pkgs, username, ... }:

{
  networking = {
    hostName = "coregate";
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

  boot.kernelParams = [ "snd_intel_dspcfg.dsp_driver=3" ];

  hardware.graphics.enable = true;

  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
  '';

  # Prefer the ThinkPad headphone jack over the internal speakers when present.
  # This card exposes speakers/headphones as separate WirePlumber profiles, so
  # restoring the old speaker profile can block automatic jack switching.
  services.pipewire.wireplumber.extraConfig."10-coregate-headphone-jack" = {
    "wireplumber.settings" = {
      "device.restore-profile" = false;
      "device.restore-routes" = false;
    };
    "device.profile.priority.rules" = [
      {
        matches = [
          { "device.name" = "alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic"; }
        ];
        actions.update-props.priorities = [
          "HiFi (HDMI1, HDMI2, HDMI3, Headphones, Mic1, Mic2)"
          "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)"
        ];
      }
    ];
  };

  environment.systemPackages = [
    pkgs.xorg.xauth
    pkgs.xorg.xhost
  ];

  services.openssh.extraConfig = ''
    Match User ${username}
      PasswordAuthentication yes
  '';

  programs.mosh.enable = false;
  services.libinput.enable = true;
}
