{ config, ... }:

let
  dotfilesDir = "${config.home.homeDirectory}/dotfiles";
in
{
  imports = [
    ../../../home.nix
  ];

  manual.manpages.enable = false;

  xdg.configFile."ghostty" = {
    force = true;
    recursive = true;
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/ghostty";
  };
}
