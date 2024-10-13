fkill() {
    local pid 
    if [ "$UID" != "0" ]; then
        pid=$(ps -f -u $UID | sed 1d | fzf -m | awk '{print $2}')
    else
        pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
    fi  

    if [ "x$pid" != "x" ]
    then
        echo $pid | xargs kill -${1:-9}
    fi  
}
zle -N fkill

zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
export FZF_DEFAULT_COMMAND='fd --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --tmux bottom,40% --layout reverse --border top'
export FZF_ALT_C_COMMAND="$FZF_DEFAULT_COMMAND --type directory "

export FZF_ALT_C_OPTS="--prompt 'All> ' \
--header 'CTRL-D: Directories / CTRL-F: Files' \
--bind 'ctrl-d:change-prompt(Directories> )+reload(find * -type d)' \
--bind 'ctrl-f:change-prompt(Files> )+reload(find * -type f)' \
--bind 'enter:become(nvim {})'" 

