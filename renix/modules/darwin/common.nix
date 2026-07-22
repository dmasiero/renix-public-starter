{ self, config, lib, pkgs, username, ... }:
let
  homeDir = "/Users/${username}";
  disabledHotkeysSettings = import ./disable-apple-default-hotkeys.nix { inherit lib; };
in
{
  imports = [
    ./dock.nix
    ../system/overlays.nix
    ../../pkgs/renix.nix
  ];

  nixpkgs.config.allowUnfree = true;

  nix = {
    enable = false;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  system = {
    configurationRevision = self.rev or self.dirtyRev or null;
    stateVersion = 6;
    primaryUser = username;

    defaults = {
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleInterfaceStyleSwitchesAutomatically = false;
      };
      WindowManager = {
        StandardHideWidgets = true;
        StageManagerHideWidgets = true;
        EnableStandardClickToShowDesktop = false;
        HideDesktop = true;
      };
      finder.FXPreferredViewStyle = "Nlsv";
      CustomUserPreferences = disabledHotkeysSettings;
    };

    activationScripts.postActivation.text = ''
      managed_user=${lib.escapeShellArg username}
      managed_home=${lib.escapeShellArg homeDir}

      sudo -u "$managed_user" /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

      user_uid="$(/usr/bin/id -u "$managed_user")"
      /bin/launchctl asuser "$user_uid" sudo -u "$managed_user" /usr/bin/osascript \
        -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' \
        2>/dev/null || true

      # Remove Finder's default colored tags. FavoriteTagNames only controls the
      # sidebar favorites; FinderTagDict is where Finder stores the tag list, and
      # "All Tags" is repopulated from files with kMDItemUserTags metadata.
      sudo -u "$managed_user" /usr/bin/defaults write com.apple.finder FavoriteTagNames -array 2>/dev/null || true
      sudo -u "$managed_user" /usr/bin/defaults write com.apple.finder ShowRecentTags -bool false 2>/dev/null || true
      finder_synced_prefs="$managed_home/Library/SyncedPreferences/com.apple.finder.plist"
      if [ -e "$finder_synced_prefs" ]; then
        sudo -u "$managed_user" /usr/libexec/PlistBuddy -c "Delete :values:FinderTagDict:value:FinderTags" "$finder_synced_prefs" 2>/dev/null || true
        sudo -u "$managed_user" /usr/libexec/PlistBuddy -c "Add :values:FinderTagDict:value:FinderTags array" "$finder_synced_prefs" 2>/dev/null || true
      fi
      sudo -u "$managed_user" /usr/bin/mdfind -0 -onlyin "$managed_home" 'kMDItemUserTags == "*"' 2>/dev/null \
        | /usr/bin/xargs -0 -n 1 /usr/bin/xattr -d 'com.apple.metadata:_kMDItemUserTags' 2>/dev/null || true
      /usr/bin/killall cfprefsd 2>/dev/null || true
      /usr/bin/killall sharedfilelistd 2>/dev/null || true
      /usr/bin/killall Finder 2>/dev/null || true

      fish_shell="${pkgs.fish}/bin/fish"
      current_shell="$(/usr/bin/dscl . -read "$managed_home" UserShell 2>/dev/null | /usr/bin/awk '{print $2}')"
      if [ "$current_shell" != "$fish_shell" ]; then
        /usr/bin/dscl . -create "$managed_home" UserShell "$fish_shell"
      fi

      /bin/launchctl bootout "gui/$user_uid" /System/Library/LaunchAgents/com.apple.tipsd.plist 2>/dev/null || true
      /bin/launchctl disable "gui/$user_uid/com.apple.tipsd" 2>/dev/null || true
      sudo -u "$managed_user" /usr/bin/defaults write com.apple.tipsd TipsAppLaunchCount -int 999 2>/dev/null || true
      sudo -u "$managed_user" /usr/bin/defaults write com.apple.tipsd TipsAppLastRunVersion -string "9999" 2>/dev/null || true
    '';
  };

  # Avoid nix-darwin's options.json documentation derivation warning.
  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
  };
  programs.man.enable = false;
  programs.info.enable = false;

  time.timeZone = "America/New_York";

  users.users.${username} = {
    name = username;
    home = homeDir;
    shell = pkgs.fish;
  };

  programs.fish.enable = true;
  environment = {
    shells = [ pkgs.fish ];
    variables = {
      # Adobe's cask CDN occasionally drops large downloads during bootstrap.
      HOMEBREW_CURL_RETRIES = "10";
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.monaspace
    font-awesome
  ];

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
    };
    taps = [ "cirruslabs/cli" ];
    brews = [ "cirruslabs/cli/tart" ];
    casks = [
      "ghostty"
      "raycast"
      "discord"
      "telegram"
      "orbstack"
      "vlc"
      "libreoffice"
      "bitwarden"
      "viscosity"
      "balenaetcher"
      "homebrew/cask/transmission"
      "adobe-creative-cloud"
      "wireshark-app"
      "xquartz"
    ];
  };
}
