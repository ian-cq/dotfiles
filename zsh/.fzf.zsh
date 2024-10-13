zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
export FZF_ALT_C_COMMAND="$FZF_DEFAULT_COMMAND --type directory" # --type from fd
export FZF_DEFAULT_OPTS='--height 40% --tmux bottom,40% --layout reverse --border top'
