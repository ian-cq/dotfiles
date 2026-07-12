#!/usr/bin/env bash
#
# prereqs.sh — Standalone pre-dependency fetch (run #1 of 2).
#
# Installs the minimal toolchain the main installer needs before it can run:
#   git, curl, stow, zsh, a C toolchain (for Homebrew/compiled formulae) and
#   Homebrew itself. It is deliberately separate from `install` so a fresh
#   machine can be brought up in two clear, idempotent steps:
#
#     1. scripts/prereqs.sh     # this file — base deps + Homebrew
#     2. ./install              # download + run setup_quanianitis (symlinks etc.)
#
# Safe to re-run: every step is guarded / idempotent.
#
# Usage:
#   ./scripts/prereqs.sh
#
set -euo pipefail

log()  { printf '[prereqs] %s\n' "$*"; }
warn() { printf '[prereqs][WARN] %s\n' "$*" >&2; }
die()  { printf '[prereqs][ERROR] %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

os="$(uname -s | tr '[:upper:]' '[:lower:]')"

# ---------------------------------------------------------------------------
# sudo helper — only use sudo when not already root and sudo exists.
# ---------------------------------------------------------------------------
SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if have sudo; then
    SUDO="sudo"
  else
    warn "Not root and 'sudo' not found; system package installs may fail."
  fi
fi

# ---------------------------------------------------------------------------
# 1. OS base packages
# ---------------------------------------------------------------------------
install_linux_deps() {
  if have apt-get; then
    log "Debian/Ubuntu detected — refreshing apt and installing base packages…"
    # apt-get update is REQUIRED on a fresh image; without it apt-get install
    # fails because the package lists are empty.
    $SUDO apt-get update -y
    $SUDO apt-get install -y --no-install-recommends \
      build-essential procps curl file git ca-certificates \
      stow zsh
  elif have dnf; then
    log "Fedora/RHEL detected — installing base packages via dnf…"
    $SUDO dnf install -y @development-tools procps-ng curl file git ca-certificates stow zsh
  elif have pacman; then
    log "Arch detected — installing base packages via pacman…"
    $SUDO pacman -Sy --needed --noconfirm base-devel procps-ng curl file git stow zsh
  else
    warn "No supported package manager (apt-get/dnf/pacman) found."
    warn "Please install manually: build tools, curl, file, git, stow, zsh."
  fi
}

install_macos_deps() {
  # The Homebrew installer pulls in the Command Line Tools automatically, but
  # trigger it explicitly so the first run is not an interactive GUI prompt.
  if ! xcode-select -p >/dev/null 2>&1; then
    log "Installing Xcode Command Line Tools (a GUI prompt may appear)…"
    xcode-select --install || warn "xcode-select --install returned non-zero (may already be pending)."
  else
    log "Xcode Command Line Tools already present."
  fi
}

case "$os" in
  linux)  install_linux_deps ;;
  darwin) install_macos_deps ;;
  *)      warn "Unsupported OS '$os' — skipping base package install." ;;
esac

# ---------------------------------------------------------------------------
# 2. Homebrew
# ---------------------------------------------------------------------------
# SKIP_BREW lets CI / container tests validate the base-package path without
# pulling in the (heavy) Homebrew install.
if [[ -n "${SKIP_BREW:-}" && "${SKIP_BREW}" != "0" && "${SKIP_BREW}" != "false" ]]; then
  log "SKIP_BREW set — skipping Homebrew install."
  log "Prerequisites complete (base packages only). Next: run ./install"
  exit 0
fi

if ! have brew; then
  log "Installing Homebrew…"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  log "Homebrew already installed ($(command -v brew))."
fi

# Put brew on PATH for the rest of this script and future shells.
brew_prefix=""
for candidate in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
  if [[ -x "$candidate/bin/brew" ]]; then
    brew_prefix="$candidate"
    break
  fi
done

if [[ -n "$brew_prefix" ]]; then
  eval "$("$brew_prefix/bin/brew" shellenv)"
  log "Homebrew ready at $brew_prefix"
else
  warn "Could not locate the brew binary after install; open a new shell and re-run if needed."
fi

# stow/zsh may come from Homebrew rather than the system package manager.
have stow || { log "Installing stow via Homebrew…"; brew install stow || warn "brew install stow failed"; }
have zsh  || { log "Installing zsh via Homebrew…";  brew install zsh  || warn "brew install zsh failed"; }

log "Prerequisites complete. Next: run ./install"
