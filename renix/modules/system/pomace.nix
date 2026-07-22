{ lib, pkgs, username, ... }:

let
  homeDir = "/home/${username}";
in

{
  networking = {
    hostName = "pomace";
    useDHCP = true;
    networkmanager.enable = false;
  };

  services.openssh.enable = lib.mkForce false;
  programs.mosh.enable = false;

  services.qemuGuest.enable = true;
  # Tart's host clipboard integration speaks the SPICE vdagent protocol directly
  # over the virtio serial channel. The standard spice-vdagentd also opens that
  # channel, so leave it off and run tart-guest-agent from the graphical user
  # session instead.
  services.spice-vdagentd.enable = false;
  services.timesyncd.enable = true;

  hardware.graphics.enable = true;

  # The virtio-snd card exposes playback as ALSA hw:0,1, but WirePlumber only
  # auto-detects the capture side on this VM. Create an explicit PipeWire sink
  # so desktop apps like Firefox route to the working VirtIO speakers.
  services.pipewire.extraConfig.pipewire."10-pomace-virtio-speakers" = {
    "context.objects" = [
      {
        factory = "adapter";
        args = {
          "factory.name" = "api.alsa.pcm.sink";
          "node.name" = "virtio-alsa-sink";
          "node.description" = "VirtIO Speakers";
          "media.class" = "Audio/Sink";
          "api.alsa.path" = "hw:0,1";
          "audio.format" = "S16LE";
          "audio.rate" = 48000;
          "audio.channels" = 2;
          "audio.position" = [ "FL" "FR" ];
        };
      }
    ];
  };

  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true;
      naturalScrolling = true;
    };
  };

  environment.systemPackages = [
    pkgs.tart-guest-agent
    pkgs.xorg.xauth
    pkgs.xorg.xhost
  ];

  services.udev.extraRules = ''
    KERNEL=="vport*", ATTR{name}=="com.redhat.spice.0", GROUP="users", MODE="0660"
  '';

  systemd.tmpfiles.rules = [
    "d ${homeDir}/shared_with_mac 0755 ${username} users -"
  ];

  fileSystems."${homeDir}/shared_with_mac" = {
    device = "shared_with_vm";
    fsType = "virtiofs";
    options = [
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
    ];
  };
}
