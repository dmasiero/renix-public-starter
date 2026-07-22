{ pkgs, lib, config, username, ... }:

{
  # Git Configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Doug Masiero";
        email = "doug@masie.ro";
      };
      init.defaultBranch = "main";
      pull.rebase = false;
      color.ui = "auto";
      core.editor = "nvim";
      credential.helper = "store";
    };
  };
}
