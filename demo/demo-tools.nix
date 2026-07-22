let
  flakeDir = builtins.getEnv "RENIX_FLAKE_DIR";
  flake = builtins.getFlake flakeDir;
  host = flake.nixosConfigurations.demo;
  pkgs = host.pkgs;
  home = host.config.home-manager.users.doug;
  editor = (import (flakeDir + "/modules/home/editor.nix") { inherit pkgs; }).programs.neovim;
  neovim = pkgs.wrapNeovim pkgs.neovim-unwrapped {
    configure = {
      customLuaRC = editor.extraLuaConfig;
      packages.renix.start = editor.plugins;
    };
  };

  # Keep the container useful without pulling in the complete multi-gigabyte
  # desktop and workstation package closure from modules/home/base.nix.
  practicalCliTools = with pkgs; [
    bind.dnsutils
    fd
    fping
    fzf
    git
    htop
    jq
    lazygit
    mtr
    ouch
    pwgen
    ripgrep
    tea
    unzip
    wget
    whois
    yazi
    zip
  ];
in
pkgs.buildEnv {
  name = "renix-demo-tools";
  paths = practicalCliTools ++ [
    home.programs.fish.package
    neovim
    pkgs.herdr
    pkgs.pi-coding-agent
  ];
  ignoreCollisions = true;
}
