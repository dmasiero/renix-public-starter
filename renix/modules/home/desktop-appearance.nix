{ pkgs, username, lib, ... }:
let
  homeDir = "/home/${username}";
in
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    gtk = {
      enable = true;
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
      iconTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };
      colorScheme = "dark";
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = true;
        gtk-recent-files-enabled = false;
        # Hide client-side window controls (minimize/maximize/close) in apps that
        # paint their own GTK/Chromium titlebars; sway already owns window mgmt.
        gtk-decoration-layout = ":";
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = true;
        gtk-recent-files-enabled = false;
        gtk-decoration-layout = ":";
      };
    };

    qt = {
      enable = true;
      platformTheme.name = "gtk3";
    };

    dconf.settings = {
      "org/gnome/nautilus/preferences".show-hidden-files = false;
      "org/gnome/desktop/privacy".remember-recent-files = false;
      "org/gtk/settings/file-chooser" = {
        show-hidden = false;
        startup-mode = "cwd";
        last-folder-uri = "file://${homeDir}/downloads";
      };
      "org/gtk/gtk4/settings/file-chooser" = {
        show-hidden = false;
        startup-mode = "cwd";
      };
    };


}
