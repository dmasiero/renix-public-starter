{ config, lib, pkgs, username, ... }:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  homeDir = if isDarwin then "/Users/${username}" else "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
in
{
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
      editor = "nvim";
    };
    gitCredentialHelper.enable = true;
  };

  # Keep GitHub CLI auth state in dotfiles so one login is reused on every host.
  xdg.configFile."gh/hosts.yml" = {
    force = true;
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/gh/hosts.yml";
  };

  home.activation = {
    ensureDotfilesGhAuth = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      mkdir -p "${dotfilesDir}/gh"

      if [ -f "${homeDir}/.config/gh/hosts.yml" ] && [ ! -e "${dotfilesDir}/gh/hosts.yml" ]; then
        cp "${homeDir}/.config/gh/hosts.yml" "${dotfilesDir}/gh/hosts.yml"
      fi
    '';

    fixGhAuthPerms = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -e "${dotfilesDir}/gh/hosts.yml" ]; then
        chmod 600 "${dotfilesDir}/gh/hosts.yml" || true
      fi
    '';
  };
}
