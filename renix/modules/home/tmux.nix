{ pkgs, lib, config, username, ... }:

{
  # tmux Configuration
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    historyLimit = 10000;
    keyMode = "vi";
    mouse = true;
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [ resurrect ];
    extraConfig = ''
      # Vim Keybindings
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-selection
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      bind -r H resize-pane -L 2
      bind -r J resize-pane -D 2
      bind -r K resize-pane -U 2
      bind -r L resize-pane -R 2

      # Pane Splitting
      bind - split-window -hbf -c "#{pane_current_path}"
      bind \\ split-window -hf -c "#{pane_current_path}"
      bind '"' split-window -v -c "#{pane_current_path}"

      # Mouse Behavior
      bind -n MouseDown1Pane select-pane -t= \; send-keys -M

      # Theme
      set-option -g status-style bg=colour0,fg=colour205
      set-window-option -g window-status-style fg=colour123,bg=default,dim
      set-window-option -g window-status-current-style fg=colour84,bg=default,bright
      set-option -g pane-border-style fg=colour81
      set-option -g pane-active-border-style fg=colour84
      set-option -g message-style bg=colour81,fg=colour17
      set-option -g display-panes-active-colour colour203
      set-option -g display-panes-colour colour84
      set-window-option -g clock-mode-colour colour205
      set -g status-right '%H:%M %d-%b-%y'

      # Session Options
      set -s set-clipboard on
      set -g mouse on
      set -g allow-passthrough on
      set -g extended-keys on
      set -g extended-keys-format csi-u
      set -g terminal-overrides "xterm-256color:RGB"
      set -a terminal-features "xterm*:strikethrough"
      set -g pane-base-index 1
      set -g repeat-time 1000
      set -g display-panes-time 3000
      set -g detach-on-destroy off
    '';
  };

}
