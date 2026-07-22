{ lib, pkgs, dotfilesCerts ? null, username ? "doug", ... }:

{
  imports = [
    ./overlays.nix
    ./smb-tnas01.nix
    ./bluetooth.nix
    ./sway-greetd.nix
    ../../pkgs/renix.nix
  ];

  system.stateVersion = "25.11";

  security.pki.certificateFiles = lib.mkIf (dotfilesCerts != null) [
    (dotfilesCerts + /renix-demo-ca.crt)
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      # bitwarden-desktop 2026.2.1 is still pinned to Electron 39 in nixpkgs.
      "electron-39.8.10"
    ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "plugdev" ];
    shell = pkgs.fish;
    ignoreShellProgramCheck = true;
    linger = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID5JsZ+238uECRpuih8sVUR/2zJ/U+382qarCru6Rqzl doug@stargate"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  networking = {
    domain = "masiero.internal";
    nameservers = [ "127.0.0.1" ];

    firewall = {
      allowedUDPPortRanges = [
        { from = 61001; to = 61999; }
      ];
      allowedTCPPorts = [ 5229 9001 9090 19432 ];

      # Block Master PDF Editor's registration/activation endpoint. The app
      # can connect to the resolved IP directly, so DNS blocking alone is not
      # enough.
      extraCommands = ''
        ${pkgs.iptables}/bin/iptables -w -C OUTPUT -p tcp -d 185.179.191.196 --dport 8085 -j REJECT 2>/dev/null \
          || ${pkgs.iptables}/bin/iptables -w -I OUTPUT -p tcp -d 185.179.191.196 --dport 8085 -j REJECT
      '';
      extraStopCommands = ''
        ${pkgs.iptables}/bin/iptables -w -D OUTPUT -p tcp -d 185.179.191.196 --dport 8085 -j REJECT 2>/dev/null || true
      '';
    };
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      no-resolv = true;
      strict-order = true;
      server = [ "/masiero.internal/10.10.0.12" "8.8.8.8" "8.8.4.4" ];
      cache-size = 1000;
      no-negcache = true;
      address = [
        "/reg.code-industry.net/0.0.0.0"
        "/reg.code-industry.net/::"
      ];
      domain-needed = true;
      bogus-priv = true;
      listen-address = [ "127.0.0.1" "::1" ];
      bind-interfaces = true;
    };
  };

  fonts.packages = [
    pkgs.font-awesome
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.symbols-only
    pkgs.noto-fonts-color-emoji
  ];

  users.groups.plugdev = { };

  services.envfs.enable = true;
  services.fwupd.enable = true;
  programs.dconf.enable = true;
  programs.virt-manager.enable = true;

  # ZSA Voyager Keymapp flashing and Oryx live-training access.
  services.udev.extraRules = ''
    KERNEL=="hidraw*", ATTRS{idVendor}=="3297", MODE="0664", GROUP="plugdev"
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu", GROUP="plugdev"
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE="0666", GROUP="plugdev"
  '';

  # Chromium-family browsers (including Helium) rely on xdg-desktop-portal for
  # file chooser/save dialogs in non-DE sessions like sway. Firefox's GTK-native
  # dialogs can work without this, so Helium is the canary when portals are absent.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-wlr ];
    config = {
      common.default = [ "gtk" ];
      sway = {
        default = lib.mkForce [ "wlr" "gtk" ];
        "org.freedesktop.impl.portal.Inhibit" = lib.mkForce [ "gtk" ];
      };
    };
  };

  security.rtkit.enable = true;
  security.chromiumSuidSandbox.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    wireplumber.enable = true;
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  programs.ssh.knownHosts.gitea-masiero-internal = {
    hostNames = [
      "[gitea.masiero.internal]:2222"
      "[10.10.0.22]:2222"
    ];
    publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5qODClX4diCjQqrPkoqXqgeQjsElN/r8D2ZhXCltCcK9UJw+e7f69ni4daxxRyPQh5nHDTvRfxtfLsoWITiOyCEPkZ8f9rgTWZq/IOENd1Wmvimx2inU51BSE/tW8WeMegPZKzXzj4xuUtNmB/FQwMLUnbXC9KE3oZoJlDZkkKEkAb66plX6ARLfvqNYutZGYiDD45FavZJOBR/priudlb2BY3ryaf9ODsuAjLGRtLmtF48ClNtRxpPQ5GkQslqftGderjN2UyP9xNeOrrs3ci6Vv/mCKbWRBKDwwNro8UzCkFFHv/Ee+gqaUj1A8+1cx0fUlaWiL5kvccNnlNvbqb8oVVoCKNiMfzvlILIKT0mf3Ar2aZEk6pIhcpWNmiIYceEC4LJ6REpuICRVm5li1ljzdAxg88JaUQJNHpDYK983HZbVOy9TP3wbg9oNee3YLaaofqE1RZxaH6gNYguVAwAVKHEVSMjKzls8+1GwpJVYAt2CfHIj5RDLs8JU+/igXkH+SQ36wxBnxLEaNRjcsbIyrQf0mmZ0W+Pr9JgYlY6vaEOswVyR6RRwiKpBBkXqzII16XChKaaJNkEhZ4JdmLylbKWZrSNQhHDkkoVgc1LjdnoSYLwOCwVPiS+Aux+CyYhzzbSdwRPz5PA3eTsPmnY1p4G0NtkJWuKIm0R4NfQ==";
  };

  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29;
  };

  environment.systemPackages = [
    pkgs.speedtest-cli
    pkgs.iputils
  ];

  programs.ssh.startAgent = true;
}
