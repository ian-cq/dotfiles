# ~/.zshrc — Ian's zsh config
# Loaded for interactive shells. Keep startup fast: avoid forks where possible.

# ---------------------------------------------------------------------------
# PATH (consolidated; prepended in priority order)
# ---------------------------------------------------------------------------
typeset -U path PATH                                  # de-duplicate entries
path=(
  $HOME/.local/bin                                    # user scripts
  /opt/homebrew/bin                                   # Homebrew (Apple Silicon)
  /opt/homebrew/sbin
  /home/linuxbrew/.linuxbrew/bin                      # Homebrew (Linux)
  /home/linuxbrew/.linuxbrew/sbin
  /usr/local/bin                                      # Homebrew (Intel macOS)
  $HOME/.cargo/bin
  $HOME/go/bin
  $HOME/.krew/bin                                     # kubectl krew plugins
  $path
)
# Non-existent entries above are harmless; typeset -U keeps PATH de-duplicated.

# Load full Homebrew environment (HOMEBREW_PREFIX, MANPATH, etc.) if present.
for _brew in /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew /usr/local/bin/brew; do
  [[ -x $_brew ]] && { eval "$("$_brew" shellenv)"; break; }
done
unset _brew

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
HISTSIZE=1000000
SAVEHIST=1000000
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
  # macOS-only browser hint; harmless when the app/path is absent.
  [[ "$OSTYPE" == darwin* ]] && \
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
command -v aliyun >/dev/null && complete -o nospace -F "$(command -v aliyun)" aliyun

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

# Flutter/FVM/Dart
export PATH="$HOME/fvm/default/bin:$HOME/.pub-cache/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
export PATH="/Users/ianqchan/.agents/skills/twingate-cli/.venv/bin:$PATH"
export PATH="/opt/homebrew/opt/mysql-client@8.4/bin:$PATH"
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

KUBE_PS1_SYMBOL_ENABLE=false
PROMPT='$(kube_ps1)'$PROMPT

# ---------------------------------------------------------------------------
# Keep the zcompdump mtime newer than plugin completion caches.
# OMZ plugins (argocd, docker, gh, helm, kubectl) refresh their completion
# files asynchronously on every startup; without this, compinit sees newer
# fpath files on the next launch and rebuilds the full dump (~350ms + 1000
# compdef calls). Touching the dump after everything is loaded breaks that
# loop so subsequent startups skip the rebuild.
# ---------------------------------------------------------------------------
{ command touch -- "${ZSH_COMPDUMP:-$HOME/.zcompdump-${HOST/.*/}-${ZSH_VERSION}}" 2>/dev/null } &|
