# fzf integration & helpers

# fkill — interactively pick a process and kill it
fkill() {
  local pid
  if [[ "$UID" != "0" ]]; then
    pid=$(ps -f -u "$UID" | sed 1d | fzf -m | awk '{print $2}')
  else
    pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
  fi
  [[ -n "$pid" ]] && echo "$pid" | xargs kill -${1:-9}
}

zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

export FZF_DEFAULT_COMMAND='fd --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --tmux bottom,40% --layout reverse --border top'
export FZF_ALT_C_COMMAND="$FZF_DEFAULT_COMMAND --type directory"

# Use fd (not find) for the CTRL-D / CTRL-F reload bindings — consistent and faster.
export FZF_ALT_C_OPTS="--prompt 'All> ' \
--header 'CTRL-D: Directories / CTRL-F: Files' \
--bind 'ctrl-d:change-prompt(Directories> )+reload(fd --type d --hidden --follow --exclude .git)' \
--bind 'ctrl-f:change-prompt(Files> )+reload(fd --type f --hidden --follow --exclude .git)'"
