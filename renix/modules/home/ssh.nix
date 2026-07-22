{ pkgs, lib, config, username, ... }:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  sshAskpassFromFile = pkgs.writeShellScript "ssh-askpass-from-file" ''
    set -eu

    passphrase_file="''${SSH_PASSPHRASE_FILE:-$HOME/dotfiles/ssh-agent/passphrases}"
    prompt="''${1:-}"

    [ -r "$passphrase_file" ] || exit 1

    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        ""|\#*) continue ;;
      esac

      key="''${line%%=*}"
      passphrase="''${line#*=}"
      expanded_key="$key"
      case "$expanded_key" in
        '~/'*) expanded_key="$HOME/''${expanded_key#~/}" ;;
      esac

      case "$prompt" in
        *"$key"*|*"$expanded_key"*)
          printf '%s\n' "$passphrase"
          exit 0
          ;;
      esac
    done < "$passphrase_file"

    exit 1
  '';
  sshAddLoginKeys = pkgs.writeShellScript "ssh-add-login-keys" ''
    set -eu

    runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"
    export SSH_AUTH_SOCK="''${SSH_AUTH_SOCK:-$runtime_dir/ssh-agent}"
    export SSH_ASKPASS="${sshAskpassFromFile}"
    export SSH_ASKPASS_REQUIRE=force
    export SSH_PASSPHRASE_FILE="''${SSH_PASSPHRASE_FILE:-$HOME/dotfiles/ssh-agent/passphrases}"

    if [ -S "$SSH_AUTH_SOCK" ]; then
      :
    else
      echo "SSH agent socket is not ready: $SSH_AUTH_SOCK" >&2
      exit 1
    fi

    add_key() {
      key="$1"
      pub="$key.pub"
      [ -r "$key" ] || return 0

      if [ -r "$pub" ]; then
        fingerprint="$(${pkgs.openssh}/bin/ssh-keygen -lf "$pub" | ${pkgs.gawk}/bin/awk '{ print $2 }')"
        if ${pkgs.openssh}/bin/ssh-add -l 2>/dev/null | ${pkgs.gnugrep}/bin/grep -Fq "$fingerprint"; then
          return 0
        fi
      fi

      ${pkgs.openssh}/bin/ssh-add -q "$key"
    }

    add_key "$HOME/.ssh/DM-20260211"
    add_key "$HOME/.ssh/DMMF-20211104"
    add_key "$HOME/.ssh/id_DAM_20191006"
    add_key "$HOME/.ssh/github-dmasiero"
    add_key "$HOME/.ssh/batman_rsa"
  '';
in
{
  # SSH Configuration
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "hf.co" = {
        identityFile = [ "~/.ssh/hf-bruari-20231209" ];
      };
      "github.com" = {
        extraOptions = {
          AddKeysToAgent = "yes";
          HostkeyAlgorithms = "+ssh-rsa";
          PubkeyAcceptedAlgorithms = "+ssh-rsa";
        };
        identityFile = [ "~/.ssh/github-dmasiero" ];
      };
      "gitea.masiero.internal-mgmt" = lib.hm.dag.entryBefore [ "gitea.masiero.internal" ] {
        match = "originalhost gitea.masiero.internal user mtg";
        port = 22;
        extraOptions = {
          IdentitiesOnly = "yes";
        };
        identityFile = [ "~/.ssh/DM-20260211" ];
      };
      "gitea.masiero.internal" = {
        user = "git";
        port = 2222;
        extraOptions = {
          IdentitiesOnly = "yes";
        };
        identityFile = [ "~/.ssh/gitea_masiero_doug" ];
      };
      "nextgate" = {
        hostname = "nextgate.masiero.internal";
        # tssh only consults ssh-agent when IdentitiesOnly is not "yes".
        # OpenSSH still tries the configured IdentityFile first.
        extraOptions = {
          IdentitiesOnly = "no";
        };
        identityFile = [ "~/.ssh/DM-20260211" ];
      };
      "nextgate.masiero.internal" = {
        # tssh only consults ssh-agent when IdentitiesOnly is not "yes".
        # OpenSSH still tries the configured IdentityFile first.
        extraOptions = {
          IdentitiesOnly = "no";
        };
        identityFile = [ "~/.ssh/DM-20260211" ];
      };
      "*" = {
        extraOptions = {
          HostkeyAlgorithms = "+ssh-rsa";
          PubkeyAcceptedAlgorithms = "+ssh-rsa";
          AddKeysToAgent = "yes";
          IdentitiesOnly = "yes";
          LogLevel = "ERROR";
        } // lib.optionalAttrs isDarwin {
          UseKeychain = "yes";
        };
        identityFile = [
          "~/.ssh/DM-20260211"
          "~/.ssh/DMMF-20211104"
          "~/.ssh/id_DAM_20191006"
          "~/.ssh/batman_rsa"
        ];
      };
    };
  };

  home.activation.ensureSshPassphraseFile = lib.mkIf isLinux (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    passphrase_dir="$HOME/dotfiles/ssh-agent"
    passphrase_file="$passphrase_dir/passphrases"

    mkdir -p "$passphrase_dir"
    chmod 700 "$passphrase_dir" || true

    if [ ! -e "$passphrase_file" ]; then
      cat > "$passphrase_file" <<'EOF'
# One key per line: /absolute/path/to/private/key=passphrase
# This file is local secret material; do not commit it.
# Lines beginning with # are ignored.
# Example:
# /home/doug/.ssh/github-dmasiero=CHANGEME
EOF
    fi
    chmod 600 "$passphrase_file" || true

    if [ -d "$HOME/dotfiles/.git" ]; then
      git_exclude="$HOME/dotfiles/.git/info/exclude"
      mkdir -p "$(dirname "$git_exclude")"
      touch "$git_exclude"
      grep -qxF '/ssh-agent/passphrases' "$git_exclude" || printf '\n/ssh-agent/passphrases\n' >> "$git_exclude"
    fi
  '');

  systemd.user.services.ssh-add-login-keys = lib.mkIf isLinux {
    Unit = {
      Description = "Add SSH keys to the login SSH agent";
      After = [ "ssh-agent.service" ];
      Wants = [ "ssh-agent.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      ExecStart = sshAddLoginKeys;
      Environment = [
        "SSH_AUTH_SOCK=%t/ssh-agent"
        "SSH_ASKPASS=${sshAskpassFromFile}"
        "SSH_ASKPASS_REQUIRE=force"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };

}
