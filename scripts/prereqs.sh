#!/usr/bin/env bash
# prereqs.sh — base toolchain + Homebrew for ian-cq/dotfiles (run #1 of 2).
# Safe to re-run. Copy-pasteable: raw URL is in README.md.
set -euo pipefail

SUDO=""; [[ $(id -u) -ne 0 ]] && command -v sudo >/dev/null && SUDO="sudo"
PKGS="build-essential procps curl file git ca-certificates stow zsh"

case "$(uname -s)" in
  Linux)
    if   command -v apt-get >/dev/null; then $SUDO apt-get update -y && $SUDO apt-get install -y --no-install-recommends $PKGS
    elif command -v dnf     >/dev/null; then $SUDO dnf install -y @development-tools procps-ng curl file git ca-certificates stow zsh
    elif command -v pacman  >/dev/null; then $SUDO pacman -Sy --needed --noconfirm base-devel procps-ng curl file git stow zsh
    else echo "unsupported linux distro" >&2; exit 1
    fi
    ;;
  Darwin) xcode-select -p >/dev/null 2>&1 || xcode-select --install || true ;;
esac

if [[ "${SKIP_BREW:-0}" != "1" ]] && ! command -v brew >/dev/null; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
for p in /opt/homebrew /home/linuxbrew/.linuxbrew /usr/local; do
  [[ -x "$p/bin/brew" ]] && eval "$("$p/bin/brew" shellenv)" && break
done

# On macOS the Darwin branch above only ran xcode-select; stow/zsh come from
# Homebrew. On Linux they came from apt/dnf/pacman, so these are no-ops.
if [[ "${SKIP_BREW:-0}" != "1" ]] && command -v brew >/dev/null; then
  command -v stow >/dev/null || brew install stow
  command -v zsh  >/dev/null || brew install zsh
fi

echo "[prereqs] done — next: ./install (or curl the one-liner in README)"
