{ pkgs, username, config, lib, ... }:
let
  homeDir = "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
  yaziFileManager = pkgs.callPackage ../../pkgs/yazi-filemanager.nix {
    inherit homeDir dotfilesDir;
  };
  pdfApplication =
    if pkgs.stdenv.hostPlatform.isx86_64 then
      [ "net.code-industry.masterpdfeditor5.desktop" ]
    else
      [ "org.gnome.Evince.desktop" ];
  associatedMimeApplications = {
    "text/html" = [ "firefox.desktop" ];
    "x-scheme-handler/http" = [ "firefox.desktop" ];
    "x-scheme-handler/https" = [ "firefox.desktop" ];
    "inode/directory" = [ "yazi-browser.desktop" ];
    "image/bmp" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/gif" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/jpeg" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/png" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/tiff" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/webp" = [ "org.nomacs.ImageLounge.desktop" ];
    "application/pdf" = pdfApplication;
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = [ "org.gnumeric.gnumeric.desktop" ];
    "application/vnd.ms-excel" = [ "org.gnumeric.gnumeric.desktop" ];
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = [ "abiword.desktop" ];
    "application/msword" = [ "abiword.desktop" ];
    "text/csv" = [ "org.gnumeric.gnumeric.desktop" ];
    "text/x-csv" = [ "org.gnumeric.gnumeric.desktop" ];
    "application/csv" = [ "org.gnumeric.gnumeric.desktop" ];
    "x-scheme-handler/tg" = [ "org.telegram.desktop.desktop" ];
    "x-scheme-handler/tonsite" = [ "org.telegram.desktop.desktop" ];
  };
  defaultMimeApplications = associatedMimeApplications // {
    "x-scheme-handler/about" = [ "firefox.desktop" ];
    "x-scheme-handler/unknown" = [ "firefox.desktop" ];
    "video/mp4" = [ "vlc.desktop" ];
    "video/x-matroska" = [ "vlc.desktop" ];
    "video/x-msvideo" = [ "vlc.desktop" ];
    "video/quicktime" = [ "vlc.desktop" ];
    "video/webm" = [ "vlc.desktop" ];
    "application/zip" = [ "xarchiver.desktop" ];
    "application/x-zip-compressed" = [ "xarchiver.desktop" ];
    "application/x-7z-compressed" = [ "xarchiver.desktop" ];
    "application/vnd.rar" = [ "xarchiver.desktop" ];
    "application/x-rar" = [ "xarchiver.desktop" ];
    "application/x-tar" = [ "xarchiver.desktop" ];
    "application/x-compressed-tar" = [ "xarchiver.desktop" ];
    "application/gzip" = [ "xarchiver.desktop" ];
  };
in
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    xdg.configFile."user-dirs.dirs" = {
      force = true;
      text = ''
        XDG_DESKTOP_DIR="$HOME"
        XDG_DOWNLOAD_DIR="$HOME/downloads"
        XDG_TEMPLATES_DIR="$HOME/templates"
        XDG_PUBLICSHARE_DIR="$HOME/public"
        XDG_DOCUMENTS_DIR="$HOME/documents"
        XDG_MUSIC_DIR="$HOME/music"
        XDG_PICTURES_DIR="$HOME/pictures"
        XDG_VIDEOS_DIR="$HOME/videos"
      '';
    };
    xdg.configFile."gtk-3.0/bookmarks" = {
      force = true;
      text = ''
        file://${homeDir}/dev dev
        file://${homeDir}/screenshots screenshots
      '';
    };
    xdg.configFile."gtk-4.0/bookmarks" = {
      force = true;
      text = ''
        file://${homeDir}/dev dev
        file://${homeDir}/screenshots screenshots
      '';
    };
    xdg.configFile."Code Industry" = {
      force = true;
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/Code Industry";
    };
    xdg.configFile."flameshot/flameshot.ini" = {
      force = true;
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/flameshot/flameshot.ini";
    };
    xdg.configFile."yazi/yazi.toml" = {
      force = true;
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/yazi/yazi.toml";
    };
    xdg.configFile."yazi/keymap.toml" = {
      force = true;
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/yazi/keymap.toml";
    };
    xdg.configFile."yazi/plugins/ouch.yazi" = {
      force = true;
      source = pkgs.yaziPlugins.ouch;
    };
    xdg.configFile."nomacs" = {
      force = true;
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/nomacs/config";
    };
    xdg.configFile."galculator/galculator.conf" = {
      force = true;
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/galculator/galculator.conf";
    };
    # Keep the per-user systemd manager bootable even if an old Home Manager
    # generation that provided default.target is garbage collected. Without
    # this, user services such as PipeWire fail to start and i3blocks volume
    # shows n/a.
    xdg.configFile."systemd/user/default.target" = {
      force = true;
      source = "${pkgs.systemd}/example/systemd/user/default.target";
    };
    xdg.dataFile."nomacs" = {
      force = true;
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/nomacs/share";
    };

    home.packages = with pkgs; [
      firefox
      telegram-desktop
      bitwarden-desktop
      i3blocks
      lm_sensors
      swaylock
      swayidle
      wlinhibit
      waycorner
      wl-clipboard
      wtype
      grim
      slurp
      wf-recorder
      wlr-randr
      wlsunset
      wev
      cliphist
      fuzzel
      xss-lock
      feh
      xorg.xrandr
      xorg.xset
      xorg.xkill
      curl
      usbutils
      v4l-utils
      xarchiver
      nomacs-with-gsettings
      evince
      gimp
      libreoffice-fresh
      gnumeric
      abiword
      gsimplecal
      galculator
      xbindkeys
      xclip
      xdotool
      flameshot
      vlc
      obs-studio
      rbw
      (pass.withExtensions (exts: [ exts.pass-otp ]))
      gnupg
      rofi
      rofimoji
      bemoji
      baresip
      netcat-openbsd
      iproute2
      bluez
      haskellPackages.greenclip
      libnotify
      pinentry-gnome3
      pavucontrol
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
      cliamp
      masterpdf
      zoiper5
    ];

    xdg.mimeApps = {
      enable = true;
      defaultApplications = defaultMimeApplications;
      associations.added = associatedMimeApplications;
    };
    xdg.configFile."mimeapps.list".force = true;
    xdg.dataFile."applications/mimeapps.list".force = true;
    xdg.dataFile."applications/greta-tv-10b.desktop" = {
      force = true;
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Greta TV (10B)
        Comment=Open Greta TV camera stream
        Exec=${dotfilesDir}/bin/unifi-camera
        Terminal=false
        Categories=AudioVideo;Video;
        StartupNotify=false
      '';
    };
    xdg.dataFile."applications/org.telegram.desktop.desktop" = {
      force = true;
      text = ''
        [Desktop Entry]
        Name=Telegram Desktop
        Comment=Official desktop version of Telegram messaging app
        TryExec=${dotfilesDir}/bin/telegram-with-browser
        Exec=${dotfilesDir}/bin/telegram-with-browser -- %U
        Icon=org.telegram.desktop
        Terminal=false
        Type=Application
        Categories=Chat;Network;InstantMessaging;Qt;
        MimeType=x-scheme-handler/tg;x-scheme-handler/tonsite;
        StartupWMClass=TelegramDesktop
        DBusActivatable=false
        Actions=Quit;

        [Desktop Action Quit]
        Exec=${dotfilesDir}/bin/telegram-with-browser -quit
        Name=Quit Telegram
      '';
    };
    xdg.dataFile."dbus-1/services/org.telegram.desktop.service" = {
      force = true;
      text = ''
        [D-BUS Service]
        Name=org.telegram.desktop
        Exec=${dotfilesDir}/bin/telegram-with-browser
      '';
    };
    # Chromium-family browsers use the FileManager1 D-Bus interface for
    # download "show/open in folder" actions. Route that to the same Yazi
    # wrapper as the inode/directory MIME default.
    xdg.dataFile."dbus-1/services/org.freedesktop.FileManager1.service" = {
      force = true;
      text = ''
        [D-BUS Service]
        Name=org.freedesktop.FileManager1
        Exec=${yaziFileManager}/bin/yazi-filemanager
      '';
    };
    xdg.dataFile."applications/yazi-browser.desktop" = {
      force = true;
      text = ''
        [Desktop Entry]
        Name=Yazi
        Comment=Open folder in Yazi
        Type=Application
        Exec=${dotfilesDir}/bin/xdg-yazi %U
        Terminal=false
        MimeType=inode/directory;
        Categories=Utility;Core;System;FileTools;FileManager;
        NoDisplay=true
      '';
    };

    home.file = {
      ".config/waycorner/config.toml" = lib.mkDefault {
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/waycorner/config.toml";
      };
      ".config/cliamp" = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
        force = true;
        recursive = true;
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/cliamp";
      };
      ".themes/GalculatorPaper".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/themes/GalculatorPaper";
      ".config/baresip" = {
        force = true;
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/baresip";
      };
      ".config/sippy" = {
        force = true;
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/sippy";
      };
      ".Zoiper5" = {
        force = true;
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/zoiper5";
      };
      ".config/Zoiper5" = {
        force = true;
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/zoiper5";
      };
      ".config/rofi" = {
        force = true;
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/rofi";
      };
      ".config/greenclip.toml" = {
        force = true;
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/greenclip/config.toml";
      };
    };


}
