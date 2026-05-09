# Ian's Dotfiles

<img width="1710" alt="screenshot" src="https://github.com/user-attachments/assets/0f039c1b-6e1c-49c1-8680-120f9f6422c8">

Personal cross-platform (macOS / Linux) dotfiles. Symlinks are managed with **GNU Stow**, orchestrated by a **Go installer** (`setup_quanianitis`) and bootstrapped by a small **bash script** (`install`).

---

## Quick install

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ian-cq/dotfiles/refs/heads/main/install)"
```

Or pin a release:

```sh
./install --version v1.2.3
```

The bootstrap will:

1. Resolve the latest release tag (or use `--version`).
2. Download the prebuilt `setup_quanianitis` binary + the source tarball from GitHub.
3. Clone the repo to `~/dotfiles` (skipped if it already exists).
4. Move artefacts to `~/archives/` and install the binary to `/opt/homebrew/bin` (Apple Silicon) or `/usr/local/bin`.
5. Run `setup_quanianitis` from `~/dotfiles`, which:
   - Installs Homebrew if missing
   - Runs `brew bundle` against `homebrew/Brewfile`
   - Installs Oh My Zsh + the plugins listed in `zsh/.zshrc`
   - `stow`s every top-level directory into `$HOME`
   - Applies macOS `defaults` (appearance, dock, trackpad)

> **Note:** The previous "diagnostics" upload (hostname/IP/git-SHA pushed to a public CSV) has been removed. No telemetry is collected.

---

## Repository layout

```
dotfiles/
├── install              # Bash bootstrap (entry-point for new machines)
├── main.go              # Go installer source for setup_quanianitis
├── aliases/.aliases     # Shell aliases & small functions
├── ansible/             # (Optional) Ansible playbooks for osx/ubuntu
├── config/              # XDG_CONFIG_HOME contents (~/.config/*)
│   ├── alacritty/       # Submodule: catppuccin theme
│   ├── ghostty/
│   ├── gh/
│   ├── helix/
│   ├── nvim/            # Submodule: kickstart.nvim fork
│   └── zellij/
├── git/.gitconfig
├── homebrew/Brewfile    # All brew/cask/tap dependencies
├── ssh/config
├── steampipe/           # Steampipe connection configs
└── zsh/                 # .zshrc, .p10k.zsh, .fzf.zsh, etc.
```

Each top-level directory is a **stow package** — running `stow <dir>` from the repo root creates symlinks in `$HOME` mirroring its layout (e.g. `zsh/.zshrc` → `~/.zshrc`).

---

## Manual usage

Clone with submodules and stow only what you want:

```sh
git clone --recurse-submodules https://github.com/ian-cq/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Symlink individual packages:
stow zsh aliases git ssh
stow -t ~/.config config        # XDG configs go under ~/.config
stow homebrew && brew bundle --file=homebrew/Brewfile
```

Unstow (remove symlinks) with:

```sh
stow -D <package>
```

Adopt existing files in `$HOME` into the repo (use with care):

```sh
stow --adopt <package>
```

---

## What's configured

| Area              | Notes                                                                          |
| ----------------- | ------------------------------------------------------------------------------ |
| **Shell**         | zsh + Oh My Zsh, theme `cloud`, `zsh-vi-mode`, fzf-tab, syntax highlighting    |
| **Prompt extras** | `kube-ps1` for kubectl context (toggle with `kube-toggle`)                     |
| **Editor**        | Helix primary (`hx`), nvim (kickstart fork) for migration                      |
| **Multiplexer**   | zellij (layouts in `config/zellij/layouts/`), tmux as fallback                 |
| **Terminal**      | Alacritty + Ghostty configs                                                    |
| **Search**        | `fd` + `rg` + `fzf` (`Ctrl-F` cd widget, `Ctrl-P` fkill, `Ctrl-K/J` history)   |
| **Git**           | `delta` for diffs, `gh` credential helper, signed commits                      |
| **Cloud / k8s**   | aws-cli, aliyun-cli, kubectl + kubectx/kubens/kustomize/krew, helm, argocd     |
| **Languages**     | pyenv (lazy-loaded), nvm, rust, go, openjdk                                    |

---

## Key bindings & aliases worth knowing

| Binding / alias       | Action                                            |
| --------------------- | ------------------------------------------------- |
| `Ctrl-F`              | fzf cd widget (in normal / insert mode)           |
| `Ctrl-P`              | fkill — interactive process picker                |
| `Ctrl-K` / `Ctrl-J`   | history search backward / forward                 |
| `jk` (insert mode)    | Escape to vi normal mode (zsh-vi-mode)            |
| `cd`                  | Aliased to `z` (zoxide)                           |
| `cat`                 | `bat --theme base16`                              |
| `vim`, `nv`           | `nvim`                                            |
| `tx`                  | `zellij --layout ichan`                           |
| `kctx` / `kns`        | `kubectx` / `kubens`                              |
| `kubeon` / `kubeoff`  | enable / disable kubectl context in prompt        |
| `cdroot`              | `cd` to git repo root                             |
| `reload`              | `exec $SHELL -l` (reload login shell)             |

> **Heads-up:** `grep` is aliased to `rg` in `.aliases`. Ripgrep has different flags from POSIX grep — in scripts, use `command grep` or `/usr/bin/grep` to bypass the alias.

---

## Customising

- **Aliases:** edit `aliases/.aliases` (changes apply to new shells; run `reload` to apply now).
- **Add a Brew formula:** add to `homebrew/Brewfile`, then `brew bundle`.
- **Add a zsh plugin:** add to the `plugins=(...)` array in `zsh/.zshrc`.
- **Local-only overrides:** drop a `~/.zsh_local` file and source it from `.zshrc` (not committed).

---

## Performance notes

The shell is tuned for fast startup (≈100–200 ms on M-series macs):

- `pyenv` is **lazy-loaded** via a shim function — saves ~200 ms on every shell.
- `GPG_TTY` uses zsh's built-in `$TTY` instead of forking `tty(1)`.
- `compinit` runs once (inside Oh My Zsh) instead of twice.
- `path=(…)` array is de-duplicated with `typeset -U`.

Profile your shell startup with:

```sh
zsh -i -c 'zmodload zsh/zprof && exit; zprof' | head -30
```

---

## Limitations

- Most macOS-specific aliases (`flush`, `lscleanup`, `airport`-like, `defaults`) are no-ops on Linux.
- The `install` script assumes Homebrew on macOS / Linuxbrew. Pure-Linux package managers aren't supported by the Go installer (use the `ansible/` playbooks for that path).
- Submodules (`config/nvim`, `config/alacritty/catppuccin`) require `git clone --recurse-submodules`.

---

## TODO

- [ ] Cron-based config sync (Go)
- [ ] Networking dotfiles beyond ssh
- [ ] 1Password autologin integration
- [ ] Finish helix → nvim migration
