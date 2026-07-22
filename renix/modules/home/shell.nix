{ pkgs, lib, config, username, ... }:

{
  # Fish shell configuration
  programs.fish = {
    enable = true;

    loginShellInit = lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      ssh-add --apple-load-keychain >/dev/null 2>&1
    '';

    plugins = [
      # bass: lets fish source bash/POSIX scripts (used for smanager)
      { name = "bass"; src = pkgs.fishPlugins.bass.src; }
    ];

    shellAliases = {
      vi  = "nvim";
      vim = "nvim";
      lg = "lazygit";
      fpg = "fping -l 8.8.8.8";
      tpi = "set PRETPICWD $PWD;cd /tmp;pi;cd $PRETPICWD";
      tpir = "set PRETPICWD $PWD;cd /tmp;pi -r;cd $PRETPICWD";
    };

    interactiveShellInit = ''
      set fish_greeting ""

      # Prefer the systemd-managed NixOS ssh-agent socket over any stale inherited
      # agent environment (for example old keychain sockets under ~/.ssh/agent).
      if test -S "$XDG_RUNTIME_DIR/ssh-agent"
          set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent"
      end

      # Source smanager when the checkout is present. It is a bash script, so
      # fish loads it through bass.
      if test -r ~/dev/masiero/smanager/smanager
          bass source ~/dev/masiero/smanager/smanager
      end
    '';
    functions = {
      # Run a command while preventing idle display blanking and system sleep.
      caffeinate = if pkgs.stdenv.hostPlatform.isDarwin then ''
        if test (count $argv) -eq 0
            echo "usage: caffeinate COMMAND [ARG ...]" >&2
            return 2
        end

        /usr/bin/caffeinate -di $argv
      '' else ''
        if test (count $argv) -eq 0
            echo "usage: caffeinate COMMAND [ARG ...]" >&2
            return 2
        end

        set -l wayland_inhibitor_pid
        if set -q WAYLAND_DISPLAY
            wlinhibit >/dev/null 2>&1 &
            set wayland_inhibitor_pid $last_pid
        end

        systemd-inhibit \
            --what=idle:sleep \
            --who=caffeinate \
            --why="Command requested an active session" \
            --mode=block \
            $argv
        set -l command_status $status

        if test -n "$wayland_inhibitor_pid"
            kill $wayland_inhibitor_pid 2>/dev/null
            wait $wayland_inhibitor_pid 2>/dev/null
        end

        return $command_status
      '';

      # Mirror p10k's "d h m s" duration format, no fractional seconds
      _prompt_duration = ''
        set -l ms $argv[1]
        set -l s (math --scale=0 $ms / 1000)
        if test $s -lt 60
            echo -n $s"s"
        else if test $s -lt 3600
            set -l m (math --scale=0 "$s / 60")
            set -l r (math --scale=0 "$s % 60")
            if test $r -gt 0
                echo -n $m"m "$r"s"
            else
                echo -n $m"m"
            end
        else if test $s -lt 86400
            set -l h (math --scale=0 "$s / 3600")
            set -l m (math --scale=0 "$s % 3600 / 60")
            if test $m -gt 0
                echo -n $h"h "$m"m"
            else
                echo -n $h"h"
            end
        else
            set -l d (math --scale=0 "$s / 86400")
            set -l h (math --scale=0 "$s % 86400 / 3600")
            if test $h -gt 0
                echo -n $d"d "$h"h"
            else
                echo -n $d"d"
            end
        end
      '';

      # Git status matching p10k VCS segment:
      _git_info = ''
        # Bail silently when not in a repo
        set -l branch (git symbolic-ref --short HEAD 2>/dev/null)
        if test $status -ne 0
            set -l sha (git rev-parse --short HEAD 2>/dev/null)
            test $status -ne 0; and return
            set branch '@'$sha
        end

        # '*' for any staged, unstaged, or untracked changes (matches p10k DIRTY_ICON)
        set -l dirty ""
        if not git diff --quiet 2>/dev/null
            set dirty "*"
        else if not git diff --cached --quiet 2>/dev/null
            set dirty "*"
        else
            set -l untracked (git ls-files --others --exclude-standard 2>/dev/null | head -1)
            if test -n "$untracked"
                set dirty "*"
            end
        end

        # Branch + dirty in grey (matches p10k POWERLEVEL9K_VCS_FOREGROUND)
        set_color '#585858'
        printf ' %s%s' $branch $dirty
        set_color normal

        # Ahead/behind in cyan (matches p10k VCS_{INCOMING,OUTGOING}_CHANGESFORMAT_FOREGROUND=cyan)
        set -l upstream (git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
        if test -n "$upstream"
            set -l ahead (git rev-list --count '@{upstream}..HEAD' 2>/dev/null)
            set -l behind (git rev-list --count 'HEAD..@{upstream}' 2>/dev/null)
            if test "$ahead" -gt 0; and test "$behind" -gt 0
                # Diverged: p10k collapses ':⇣ :⇡' to '⇣⇡'
                set_color cyan
                printf '⇣⇡'
                set_color normal
            else if test "$behind" -gt 0
                set_color '#585858'
                printf ':'
                set_color cyan
                printf '⇣'
                set_color normal
            else if test "$ahead" -gt 0
                set_color '#585858'
                printf ':'
                set_color cyan
                printf '⇡'
                set_color normal
            end
        end
      '';

      fish_prompt = ''
        set -l last_status $status

        # user@host: #585858 (matches p10k POWERLEVEL9K_CONTEXT_TEMPLATE)
        set_color '#585858'
        printf '%s@%s' (whoami) (hostname -s)
        set_color normal

        # directory: blue (matches p10k POWERLEVEL9K_DIR_FOREGROUND)
        printf ' '
        set_color blue
        printf '%s' (prompt_pwd)
        set_color normal

        # git status: grey branch/dirty, cyan ahead/behind (matches p10k VCS segment)
        _git_info

        # command execution time: yellow, show when >= 1s (p10k uses 5s; lowered for visibility)
        if test $CMD_DURATION -ge 1000
            printf ' '
            set_color yellow
            printf '%s' (_prompt_duration $CMD_DURATION)
            set_color normal
        end

        # prompt char: magenta on success, red on error (matches p10k PROMPT_CHAR)
        printf ' '
        if test $last_status -eq 0
            set_color magenta
        else
            set_color red
        end
        printf '❯'
        set_color normal
        printf ' '
      '';
    };
  };

}
