{ pkgs, username, ... }:
{
  imports = [
    ../../../modules/system/overlays.nix
    ../../../pkgs/renix.nix
  ];

  system.stateVersion = "25.11";
  networking.hostName = "demo";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [ "electron-39.8.10" ];
  };

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    ignoreShellProgramCheck = true;
  };

  # Generic boot settings make the starter evaluable. Replace these with the
  # generated hardware configuration before installing on a real machine.
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };
  boot.loader.grub.devices = [ "nodev" ];

  programs.fish.enable = true;
  environment.systemPackages = with pkgs; [ git vim ];
}
