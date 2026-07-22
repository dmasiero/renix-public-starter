{ pkgs, lib, config, ... }:
let
  dotfilesDir = "${config.home.homeDirectory}/dotfiles";
in
{
  home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isLinux [ pkgs.kitty ];

  xdg.configFile."kitty" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    force = true;
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/kitty";
  };
}
