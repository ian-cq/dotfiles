# ~/.zshrc — Ian's zsh config
# Loaded for interactive shells. Keep startup fast: avoid forks where possible.

# ---------------------------------------------------------------------------
# PATH (consolidated; prepended in priority order)
# ---------------------------------------------------------------------------
typeset -U path PATH                                  # de-duplicate entries
path=(
  /opt/homebrew/bin
  /opt/homebrew/sbin
  $HOME/.cargo/bin
  $HOME/go/bin
  $path
)

# ---------------------------------------------------------------------------
# Oh My Zsh
# ---------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="cloud"
ENABLE_CORRECTION="false"
COMPLETION_WAITING_DOTS="true"
zstyle ':omz:update' mode auto
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu no

plugins=(
  aws
  git
  kubectl
  helm
  gh
  kube-ps1
  zsh-syntax-highlighting
  zsh-autosuggestions
  fzf-tab
  fzf
  zoxide
  docker
  argocd
  zsh-vi-mode
)

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=5000
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory hist_ignore_all_dups hist_save_no_dups \
       hist_ignore_dups hist_find_no_dups sharehistory

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
export GPG_TTY=$TTY                                   # zsh built-in; no fork

if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='hx'
  export BROWSER='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
fi

# Add zsh-completions to fpath BEFORE compinit
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

# ---------------------------------------------------------------------------
# Completions
# Note: oh-my-zsh.sh runs `compinit` itself, so we don't run it here.
# bashcompinit is needed for tools shipping bash-style completions (e.g. aliyun).
# ---------------------------------------------------------------------------
source $ZSH/oh-my-zsh.sh
autoload -U +X bashcompinit && bashcompinit -i
[[ -x /opt/homebrew/bin/aliyun ]] && complete -o nospace -F /opt/homebrew/bin/aliyun aliyun

# ---------------------------------------------------------------------------
# Per-tool integrations
# ---------------------------------------------------------------------------
source $HOME/.fzf.zsh

# Source local config files if present (only the ones actually used)
for file in ~/.aliases ~/.zsh_functions; do
  [[ -r "$file" ]] && source "$file"
done

# pyenv (lazy-loaded — saves ~200ms on shell startup)
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && path=($PYENV_ROOT/bin $path)
pyenv() {
  unset -f pyenv
  eval "$(command pyenv init -)"
  pyenv "$@"
}

# direnv must hook eagerly to wrap chpwd
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# ---------------------------------------------------------------------------
# zsh-vi-mode keybindings (must be set after the plugin loads)
# ---------------------------------------------------------------------------
source ~/.zsh-vi-mode.zsh
zvm_bindkey vicmd '^F' fzf_cd_widget
zvm_bindkey viins '\e\x7f' backward_delete_word
zvm_bindkey viins '\e[1;3D' backward-word
zvm_bindkey viins '\ef' forward-word
zvm_bindkey viins '\\' self-insert
