#!/usr/bin/env bash
#
# Runs the two-step onboarding INSIDE the container and verifies that the
# resulting environment is functional. Executed by test/run.sh; can also be
# run by hand from ~/dotfiles inside the container.
#
# It exercises the real onboarding path with SKIP_BREW=1 so the run is fast and
# hermetic (no Homebrew, no package downloads) while still proving that every
# symlink is created and the zsh config loads cleanly.
set -uo pipefail

export SKIP_BREW=1            # skip Homebrew / brew bundle
export FORCE_SOURCE_BUILD=1   # build setup_quanianitis from the local tree

fail=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fail=1; }

hr() { printf '\n=== %s ===\n' "$*"; }

hr "RUN 1: scripts/prereqs.sh"
./scripts/prereqs.sh || { echo "prereqs.sh failed"; exit 1; }

hr "RUN 2: ./install"
./install || { echo "install failed"; exit 1; }

# ---------------------------------------------------------------------------
# Verify symlinks point back into ~/dotfiles
# ---------------------------------------------------------------------------
hr "VERIFY: symlinks"
# Portable: check the link value contains "dotfiles/" (stow uses relative links)
# and that the target exists ([ -e ] follows the symlink). Avoids `readlink -f`,
# which BSD/macOS lacks.
check_link() {
  local link="$HOME/$1"
  if [[ -L "$link" && -e "$link" ]]; then
    local tgt; tgt="$(readlink "$link")"
    case "$tgt" in
      *dotfiles/*) pass "~/$1 -> $tgt" ;;
      *)           bad "~/$1 -> $tgt (not into dotfiles)" ;;
    esac
  else
    bad "~/$1 is missing or a dangling symlink"
  fi
}

check_link .zshrc
check_link .aliases
check_link .zsh_functions
check_link .fzf.zsh
check_link .zsh-vi-mode.zsh
check_link .gitconfig
check_link .config/helix/config.toml
check_link .config/ghostty/config
check_link .config/zellij/config.kdl
check_link .config/gh/config.yml
check_link .ssh/config
check_link .steampipe/config/config.spc

# ---------------------------------------------------------------------------
# ~/.ssh must be 0700
# ---------------------------------------------------------------------------
hr "VERIFY: ~/.ssh permissions"
# GNU stat uses -c %a; BSD/macOS stat uses -f %A.
mode="$(stat -c '%a' "$HOME/.ssh" 2>/dev/null || stat -f '%A' "$HOME/.ssh" 2>/dev/null || echo '???')"
[[ "$mode" == "700" ]] && pass "~/.ssh is 0700" || bad "~/.ssh mode is $mode (want 700)"

# ---------------------------------------------------------------------------
# Oh My Zsh + plugins present
# ---------------------------------------------------------------------------
hr "VERIFY: Oh My Zsh + plugins"
[[ -d "$HOME/.oh-my-zsh" ]] && pass "oh-my-zsh installed" || bad "oh-my-zsh missing"
for p in zsh-autosuggestions zsh-syntax-highlighting fzf-tab zsh-vi-mode; do
  [[ -d "$HOME/.oh-my-zsh/custom/plugins/$p" ]] && pass "plugin $p" || bad "plugin $p missing"
done

# ---------------------------------------------------------------------------
# The zsh config must load without a fatal error.
# (Plugins that call brew-installed tools may warn; we only require a clean exit
#  of a non-interactive parse + source of the rc file.)
# ---------------------------------------------------------------------------
hr "VERIFY: zsh config parses & sources"
if zsh -n "$HOME/.zshrc" 2>/tmp/zsh_syntax.log; then
  pass "zsh -n ~/.zshrc (syntax OK)"
else
  bad "zsh -n ~/.zshrc failed:"; sed 's/^/      /' /tmp/zsh_syntax.log
fi

if zsh -ic 'echo __ZSH_OK__' 2>/tmp/zsh_load.log | grep -q __ZSH_OK__; then
  pass "interactive zsh sourced ~/.zshrc and ran a command"
else
  bad "interactive zsh failed to reach prompt:"; sed 's/^/      /' /tmp/zsh_load.log
fi

hr "RESULT"
if [[ $fail -eq 0 ]]; then
  printf '\033[32mAll onboarding checks passed.\033[0m\n'
else
  printf '\033[31mOne or more onboarding checks FAILED.\033[0m\n'
fi
exit $fail
