# Ian's Dotfiles

<img width="1710" alt="screenshot" src="https://github.com/user-attachments/assets/0f039c1b-6e1c-49c1-8680-120f9f6422c8">

Personal cross-platform (macOS / Linux) dotfiles. Symlinks are managed with **GNU Stow**, orchestrated by a **Go installer** (`setup_quanianitis`) and bootstrapped by small **bash scripts**.

---

## Quick install — remote one-liner

On a brand-new machine, bootstrap with two `curl | bash` calls (no clone
needed — both scripts live in the repo and are fetched from `main`):

```sh
# 1. Prerequisites: base packages + Homebrew (needs sudo on Linux)
curl -fsSL https://raw.githubusercontent.com/ian-cq/dotfiles/main/scripts/prereqs.sh | bash

# 2. Download the released setup_quanianitis binary, clone the repo, stow everything
curl -fsSL https://raw.githubusercontent.com/ian-cq/dotfiles/main/install | bash
```

`prereqs.sh` is ~25 lines and safe to eyeball before piping. `install` then
resolves the [latest release](https://github.com/ian-cq/dotfiles/releases/latest),
downloads the prebuilt `setup_quanianitis-<version>-<os>-<arch>.tar.gz` asset,
falls back to `go build` if no asset matches, and runs the binary.

Already cloned? Run the local copies instead:

```sh
./scripts/prereqs.sh          # run #1
./install                     # run #2
./install --version v0.6.2    # pin a specific release
```

**Run 1 — [`scripts/prereqs.sh`](scripts/prereqs.sh)** (~25 lines, copy-pasteable
[raw](https://raw.githubusercontent.com/ian-cq/dotfiles/main/scripts/prereqs.sh))
installs the minimal toolchain the installer needs and nothing more:

- OS base packages via `apt-get`/`dnf`/`pacman` (with an `apt-get update` first,
  so it works on a bare image): `build-essential`, `git`, `curl`, `file`,
  `stow`, `zsh`.
- Homebrew (if missing) and puts it on `PATH` for the current shell.

**Run 2 — [`install`](install)** ([raw](https://raw.githubusercontent.com/ian-cq/dotfiles/main/install))
then:

1. Resolves the latest release tag (or uses `--version`).
2. Downloads the prebuilt `setup_quanianitis-<version>-<os>-<arch>.tar.gz`
   release asset from GitHub — or, if no matching release exists (or
   `FORCE_SOURCE_BUILD=1`), builds it from source with `go`.
3. Clones the repo to `~/dotfiles` with submodules (skipped if it already exists).
4. Installs the binary to the first writable Homebrew / `/usr/local` bin dir.
5. Runs `setup_quanianitis` from `~/dotfiles`, which:
   - Runs `brew bundle` against `homebrew/Brewfile` using the Homebrew that
     `prereqs.sh` installed (GUI casks are **not** installed — see
     `homebrew/Brewfile.casks`)
   - Installs Oh My Zsh + the plugins listed in `zsh/.zshrc`
   - `stow`s every package into place, backing up any pre-existing real files
     to `~/.dotfiles-backup-<timestamp>/` so the repo always wins
   - Sets the login shell to zsh via `chsh`, and on macOS applies `defaults`
     (appearance, dock, trackpad) and the hostname

> **Testing:** `test/run.sh` builds a clean Ubuntu container and runs both steps
> end-to-end with `SKIP_BREW=1`, asserting every symlink is created and the zsh
> config loads. See [Testing onboarding](#testing-onboarding).

> **Note:** The previous "diagnostics" upload (hostname/IP/git-SHA pushed to a
> public CSV) has been removed. No telemetry is collected.

---

## Architecture — how onboarding works

Onboarding is split across **three components** with deliberately separate
responsibilities. This is the mental model to keep when editing them:

```
  scripts/prereqs.sh      install (bash)              setup_quanianitis (main.go)
  ─────────────────       ────────────────           ───────────────────────────
  system bootstrap   ─▶   acquire + place binary ─▶  configure the machine
  (run #1, once)          (run #2)                    (invoked by install)
```

| Component | Language | Responsibility | Boundary |
| --------- | -------- | -------------- | -------- |
| `scripts/prereqs.sh` | bash | Install the base toolchain the rest of the process needs: a C toolchain, `git`, `curl`, `file`, `stow`, `zsh` (via apt/dnf/pacman, `apt-get update` first) **and Homebrew**. | Only system-level prerequisites. Does **not** touch dotfiles or symlinks. |
| `install` | bash | Resolve the release, **download the prebuilt `setup_quanianitis` binary** (or `go build` it if no release matches), clone `~/dotfiles` (with submodules), install the binary onto `PATH`, then run it. | The "delivery" layer. It refuses to run and points you back to `prereqs.sh` if `curl`/`git`/`stow` are missing. |
| `setup_quanianitis` (`main.go`) | Go | The actual configuration: `brew bundle` the `Brewfile`, install Oh My Zsh + plugins, **`stow` every package into place**, set macOS `defaults`/hostname, and `chsh` the login shell to zsh. | Everything that shapes `$HOME`. Idempotent; safe to re-run on its own. |

**Why the split:** `prereqs.sh` was carved out of the old `install` so a bare
machine can be brought up predictably (the old script assumed `git`/`stow`/a
compiler already existed and ran `apt install` with no `apt-get update`). Keeping
system bootstrap separate from dotfile configuration means each half can be run,
tested, and reasoned about independently.

### When do I run each?

- **`scripts/prereqs.sh`** — **once, first, on a brand-new machine** (or after
  nuking Homebrew). It's the only step that needs `sudo`.
- **`install`** — right after `prereqs.sh` on a fresh machine, and any time you
  want to re-onboard from scratch (re-download the binary, re-clone, re-run).
- **`setup_quanianitis`** (the binary, directly) — for day-to-day updates on an
  already-onboarded machine: re-stow after adding a config, re-run `brew bundle`
  after editing the `Brewfile`. No need to go through `install` again.

> Homebrew has exactly one owner: **`prereqs.sh`** installs it. `setup_quanianitis`
> only *uses* it — if `brew` isn't on `PATH` it logs a warning and skips
> `brew bundle` rather than installing Homebrew itself. So on a fresh box you must
> run `prereqs.sh` before `install`, and re-running `install` never re-installs
> Homebrew.

### Environment variables (knobs used by the scripts & tests)

| Variable | Effect |
| -------- | ------ |
| `SKIP_BREW=1` | `prereqs.sh` and `main.go` skip all Homebrew work (install/update/`brew bundle`). Used to validate symlinks + shell config fast, without a package manager. |
| `FORCE_SOURCE_BUILD=1` | `install` skips the release download and `go build`s the binary from the local working tree — how you test un-released local changes. |
| `ACTIONS_WORKSPACE` | Set in CI; treated like `SKIP_BREW` and used to locate the checked-out repo. |

---

## Repository layout

```
dotfiles/
├── install                   # Run #2: download/build + run the installer
├── scripts/
│   └── prereqs.sh            # Run #1: base packages + Homebrew (standalone)
├── main.go                   # Go installer source for setup_quanianitis
├── test/                     # Containerised onboarding smoke test
│   ├── Dockerfile            # Clean ubuntu:24.04 "fresh machine"
│   ├── run.sh                # Build image + run onboarding + verify
│   └── onboard-and-verify.sh # The in-container two-step run + assertions
├── aliases/.aliases          # Shell aliases & small functions
├── ansible/                  # (Optional) Ansible playbooks for osx/ubuntu
├── config/                   # XDG_CONFIG_HOME contents (~/.config/*)
│   ├── alacritty/            # Submodule: catppuccin theme
│   ├── ghostty/              # Ghostty terminal config
│   ├── gh/
│   ├── helix/
│   ├── nvim/                 # Submodule: kickstart.nvim fork
│   └── zellij/
├── git/.gitconfig
├── homebrew/
│   ├── Brewfile              # Lean core CLI toolchain (installed by setup)
│   └── Brewfile.casks        # Optional GUI apps (macOS) — opt-in
├── ssh/config
├── steampipe/                # Steampipe connection configs
└── zsh/                      # .zshrc, .p10k.zsh, .fzf.zsh, etc.
```

Each package is stowed into place by the installer — `ssh` → `~/.ssh`, `config/*`
→ `~/.config/*`, and `zsh`/`aliases`/`git`/`homebrew` → `$HOME` (e.g.
`zsh/.zshrc` → `~/.zshrc`).

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

# Optional GUI apps (macOS):
brew bundle --file=homebrew/Brewfile.casks
```

Unstow (remove symlinks) with:

```sh
stow -D <package>
```

The installer never uses `stow --adopt` (which would let a machine's stray files
overwrite the repo). Instead it moves any conflicting real files to
`~/.dotfiles-backup-<timestamp>/` and then stows, so the repo version wins.

---

## Testing onboarding

`test/run.sh` proves that a clean Linux box can be onboarded in the two documented
steps, without publishing a release or installing every package:

```sh
test/run.sh          # build ubuntu:24.04 image, run both steps, verify
test/run.sh shell    # drop into a shell in the test container
```

It runs with `SKIP_BREW=1` (skip Homebrew/`brew bundle`) and `FORCE_SOURCE_BUILD=1`
(build `setup_quanianitis` from the working tree instead of a release), then
asserts every symlink resolves back into `~/dotfiles`, `~/.ssh` is `0700`, the
Oh My Zsh plugins are present, and `~/.zshrc` parses and sources cleanly.

---

## What's configured

| Area              | Notes                                                                          |
| ----------------- | ------------------------------------------------------------------------------ |
| **Shell**         | zsh + Oh My Zsh, theme `cloud`, `zsh-vi-mode`, fzf-tab, syntax highlighting    |
| **Prompt extras** | `kube-ps1` for kubectl context (toggle with `kube-toggle`)                     |
| **Editor**        | Helix primary (`hx`), nvim (kickstart fork) for migration                      |
| **Multiplexer**   | zellij (layouts in `config/zellij/layouts/`)                                   |
| **Terminal**      | Ghostty (primary) + Alacritty configs                                          |
| **Search**        | `fd` + `rg` + `fzf` (`Ctrl-F` cd widget, `Ctrl-P` fkill, `Ctrl-K/J` history)   |
| **Git**           | `delta` for diffs, `gh` credential helper, signed commits                      |
| **Cloud / k8s**   | aws-cli, kubectl + kubectx/kubens/kustomize/krew, helm, kubeconform, argocd    |
| **Terraform**     | tfenv + terraform, terraform-ls, terraform-docs                                |
| **Languages**     | pyenv (lazy-loaded), go, python                                                |

> GUI apps (Ghostty, 1Password, OrbStack, …) live in `homebrew/Brewfile.casks`
> and are **not** installed automatically — run `brew bundle --file=homebrew/Brewfile.casks`.

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

- Most macOS-specific aliases (`flush`, `lscleanup`, `defaults`) are no-ops on Linux.
- `scripts/prereqs.sh` handles apt/dnf/pacman for base packages, but the
  `brew bundle` step still relies on Homebrew/Linuxbrew for the CLI tools.
- Submodules (`config/nvim`, `config/alacritty/catppuccin`) are cloned via
  HTTPS; `install` fetches them with `--recurse-submodules` (best-effort).

---

## TODO

- [ ] Cron-based config sync (Go)
- [ ] Networking dotfiles beyond ssh
- [ ] 1Password autologin integration
- [ ] Finish helix → nvim migration
