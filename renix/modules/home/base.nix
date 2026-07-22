{ pkgs, username, config, lib, ... }:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  homeDir = if isDarwin then "/Users/${username}" else "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
  optionalPackage = name:
    lib.optionals (
      builtins.hasAttr name pkgs
      && lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.${name}
    ) [ pkgs.${name} ];
in
{
    home.username = username;
    home.homeDirectory = homeDir;
    home.stateVersion = "25.11";

    # Let Home Manager manage itself
    programs.home-manager.enable = true;

    xdg.enable = true;
    home.sessionPath = [
      "$HOME/dotfiles/bin"
    ];
    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      XCURSOR_THEME = "Adwaita";
      XCURSOR_SIZE = "24";
      DOTFILES = "${dotfilesDir}";
    };
    home.packages = with pkgs; [
      ansible
      awscli2
      bind.dnsutils
      fping
      graylog
      mtr
      wget
      zip
      unzip
      whois
      git
      pwgen
      lazygit
      tea
      yazi
      ouch
      ripgrep
      yt-dlp
      ffmpeg
      keychain
      qmk
      jq
      fd
      fzf
      htop
      freerdp
      uv
      python3
      nodejs_24
      gnumake
      gcc
      weechat
      font-awesome
      bitwarden-cli
    ]
    ++ optionalPackage "discord"
    ++ lib.optionals isLinux [ tigervnc dragon-drop dunst ]
    ++ optionalPackage "pi-coding-agent"
    ++ optionalPackage "herdr"
    ++ optionalPackage "trzsz-ssh"
    ++ optionalPackage "tsshd"
    ++ optionalPackage "ngrok"
    ++ optionalPackage "google-cloud-sdk";

    fonts.fontconfig.enable = true;

    # Shared files and scripts
    home.file = {
      ".config/lazygit" = {
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/lazygit";
      };
      ".config/tea" = {
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/tea";
      };
      ".pi" = {
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/pi";
      };
      ".config/weechat" = {
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/weechat";
      };
      ".config/Bitwarden CLI" = {
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/Bitwarden CLI";
      };
      ".aws" = {
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/aws";
      };
      ".config/ngrok" = {
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/ngrok";
      };
      ".config/herdr" = {
        force = true;
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/herdr";
      };
      ".config/dunst/dunstrc" = lib.mkIf isLinux {
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/dunst/common/dunstrc";
      };
    };

    home.activation = {
      ensureDotfilesPiDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${dotfilesDir}/pi"
      '';

      ensureDotfilesTeaDir = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        mkdir -p "${dotfilesDir}/tea"
      '';

      linkDotfilesSsh = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        DOTFILES_SSH="${dotfilesDir}/ssh"
        HOME_SSH="${homeDir}/.ssh"

        if [ -d "$DOTFILES_SSH" ]; then
          if [ -e "$HOME_SSH" ] && [ ! -L "$HOME_SSH" ]; then
            mv "$HOME_SSH" "$HOME_SSH.before-dotfiles-link"
          fi
          ln -sfn "$DOTFILES_SSH" "$HOME_SSH"
        fi
      '';

      fixSshPerms = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        HOME_SSH="${homeDir}/.ssh"

        if [ -e "$HOME_SSH" ]; then
          SSH_DIR="$(readlink "$HOME_SSH" 2>/dev/null || printf "%s" "$HOME_SSH")"

          chmod 700 "$SSH_DIR" || true
          find "$SSH_DIR" -type d -exec chmod 700 {} \; || true
          # Do not chmod symlinks (e.g. Home Manager generated ~/.ssh/config in /nix/store)
          find "$SSH_DIR" -type f ! -name "*.pub" -exec chmod 600 {} \; || true
          find "$SSH_DIR" -type f -name "*.pub" -exec chmod 644 {} \; || true
        fi
      '';
    };
}
