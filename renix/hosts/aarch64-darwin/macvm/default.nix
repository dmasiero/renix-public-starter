{ pkgs, ... }:

{
  imports = [
    ../../../modules/darwin/common.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  networking.hostName = "macvm";
}
