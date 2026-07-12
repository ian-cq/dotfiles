package main

import (
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

const (
	HOSTNAME = "Hannah Arendt"
)

// skipBrew reports whether Homebrew update/bundle steps should be skipped.
// Skipped in CI (ACTIONS_WORKSPACE) and whenever SKIP_BREW is set, which lets
// the installer be exercised quickly in a container to validate symlinks and
// shell config without waiting on a full brew bundle.
func skipBrew() bool {
	if _, ok := os.LookupEnv("ACTIONS_WORKSPACE"); ok {
		return true
	}
	if v, ok := os.LookupEnv("SKIP_BREW"); ok && v != "" && v != "0" && v != "false" {
		return true
	}
	return false
}

// brewOnPath ensures the Homebrew bin dirs are on PATH for child processes,
// covering Apple Silicon (/opt/homebrew), Intel macOS (/usr/local) and
// Linuxbrew (/home/linuxbrew/.linuxbrew), which is NOT on PATH by default.
func brewOnPath() {
	for _, prefix := range []string{"/opt/homebrew", "/usr/local", "/home/linuxbrew/.linuxbrew"} {
		bin := filepath.Join(prefix, "bin")
		if _, err := os.Stat(filepath.Join(bin, "brew")); err == nil {
			os.Setenv("PATH", bin+":"+filepath.Join(prefix, "sbin")+":"+os.Getenv("PATH"))
			os.Setenv("HOMEBREW_PREFIX", prefix)
			return
		}
	}
}

func main() {
	// Homebrew is installed by scripts/prereqs.sh (run #1). We do NOT install it
	// here — we only locate it and use it, so the two stages have one clear owner.
	brewOnPath()

	switch {
	case skipBrew():
		slog.Info("Skipping Homebrew steps (CI or SKIP_BREW set)")
	default:
		if _, err := exec.LookPath("brew"); err != nil {
			slog.Warn("Homebrew not found on PATH — run scripts/prereqs.sh first; skipping brew bundle")
		} else {
			// Update and upgrade Homebrew
			slog.Info("Updating and upgrading Homebrew...")
			createExec("brew update")
			createExec("brew upgrade")

			// Install packages from Brewfile
			homeDir := setHomeDir()
			brewfilePath := filepath.Join(homeDir, "dotfiles", "homebrew", "Brewfile")
			slog.Info("Installing packages from Brewfile...", slog.String("Brewpath", brewfilePath))
			createExec("brew bundle -v --file=" + brewfilePath)

			// Cleanup Homebrew
			slog.Info("Cleaning up Homebrew...")
			createExec("brew cleanup")
		}
	}

	// zsh is installed by prereqs.sh too; only warn if it is somehow missing.
	if _, err := exec.LookPath("zsh"); err != nil {
		slog.Warn("zsh not found on PATH — run scripts/prereqs.sh first")
	} else {
		slog.Info("Zsh already installed")
	}

	// Install Oh My Zsh
	slog.Info("Installing Oh My Zsh...")
	cloneGit("https://github.com/ohmyzsh/ohmyzsh.git", "~/.oh-my-zsh", 1)

	// Install Zsh plugins
	slog.Info("Installing Zsh plugins...")
	cloneGit("https://github.com/zsh-users/zsh-autosuggestions", "~/.oh-my-zsh/custom/plugins/zsh-autosuggestions", 1)
	cloneGit("https://github.com/zsh-users/zsh-completions", "~/.oh-my-zsh/custom/plugins/zsh-completions", 1)
	cloneGit("https://github.com/zsh-users/zsh-syntax-highlighting", "~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting", 1)
	cloneGit("https://github.com/TamCore/autoupdate-oh-my-zsh-plugins", "~/.oh-my-zsh/custom/plugins/autoupdate", 1)
	cloneGit("https://github.com/Aloxaf/fzf-tab", "~/.oh-my-zsh/custom/plugins/fzf-tab", 1)
	cloneGit("https://github.com/jeffreytse/zsh-vi-mode", "~/.oh-my-zsh/custom/plugins/zsh-vi-mode", 1)

	// Ensure git submodules (nvim, alacritty theme) are checked out before
	// stowing — a plain `git clone` (or a clone whose submodule fetch failed)
	// leaves these dirs empty, so stow would link nothing. Idempotent.
	slog.Info("Initializing git submodules...")
	if homeDir := setHomeDir(); homeDir != "" {
		createExec(fmt.Sprintf("git -C %s/dotfiles submodule update --init --recursive", homeDir))
	}

	// Stow dotfiles (symlink every package into place)
	slog.Info("Stowing dotfiles...")
	stowDir("dotfiles/config", ".config/alacritty", "alacritty")
	stowDir("dotfiles/config", ".config/helix", "helix")
	stowDir("dotfiles/config", ".config/ghostty", "ghostty")
	stowDir("dotfiles/config", ".config/gh", "gh")
	stowDir("dotfiles/config", ".config/zellij", "zellij")
	stowDir("dotfiles/config", ".config/nvim", "nvim")
	stowDir("dotfiles", ".steampipe/config", "steampipe")
	stowDir("dotfiles", ".ssh", "ssh")
	stowDir("dotfiles", "", "zsh")
	stowDir("dotfiles", "", "homebrew")
	stowDir("dotfiles", "", "aliases")
	stowDir("dotfiles", "", "git")

	// ~/.ssh must be private or ssh refuses to use it.
	if home, err := os.UserHomeDir(); err == nil {
		_ = os.Chmod(filepath.Join(home, ".ssh"), 0o700)
	}

	slog.Info("Configuring System Preferences...")
	if runtime.GOOS == "darwin" {
		slog.Info("Updating Hostname...")
		createExec("osascript -e 'tell application \"System Settings\" to quit'")
		createExec(fmt.Sprintf("sudo scutil --set ComputerName '%s'", HOSTNAME))
		createExec(fmt.Sprintf("sudo scutil --set HostName '%s'", HOSTNAME))
		createExec(fmt.Sprintf("sudo scutil --set LocalHostName '%s'", HOSTNAME))
		// Appearance
		slog.Info("Updating System Settings' Appearance")
		writeMacDefaults("NSGlobalDomain", "KeyRepeat", "-int 2")
		writeMacDefaults("NSGlobalDomain", "AppleShowScrollBars", "-string 'WhenScrolling'")

		// Desktop & Dock
		slog.Info("Updating System Settings' Docks and Desktop")
		writeMacDefaults("com.apple.dock", "tilesize", "-int 32")
		writeMacDefaults("com.apple.dock", "mineffect", "-string 'scale'")
		writeMacDefaults("com.apple.dock", "orientation", "-string 'left'")
		writeMacDefaults("com.apple.dock", "magnification", "-bool true")
		writeMacDefaults("com.apple.dock", "static-only", "-bool true")
		writeMacDefaults("com.apple.dock", "autohide", "-bool true")

		// Trackpad, mouse, keyboard, Bluetooth accessories, and input
		slog.Info("Updating System Settings' Trackpad")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "Clicking", "-bool true")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadTwoFingerDoubleTapGesture", "-bool true")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadRightClick", "-bool true")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadTwoFingerFromRightEdgeSwipeGesture", "-int 3")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadThreeFingerDrag", "-int 0")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadThreeFingerHorizSwipeGesture", "-int 2")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadThreeFingerTapGesture", "-int 2")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadThreeFingerVertSwipeGesture", "-int 2")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadFiveFingerPinchGesture", "-int 2")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadFourFingerHorizSwipeGesture", "-int 2")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadFourFingerPinchGesture", "-int 2")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadFourFingerVertSwipeGesture", "-int 2")
		writeMacDefaults("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadHorizScroll", "-bool true")
		writeMacDefaults("NSGlobalDomain", "com.apple.trackpad.enableSecondaryClick", "-bool true")

		// Scrolling
		writeMacDefaults("-g", "com.apple.swipescrolldirection", "-bool false")
	} else if runtime.GOOS == "linux" {
		if !skipBrew() {
			slog.Info("Updating Hostname...")
			createExec(fmt.Sprintf("sudo hostnamectl set-hostname '%s'", HOSTNAME))
		}
		slog.Warn("System Preferences configuration is macOS-only. Skipping...")
	}

	// Set login shell to zsh (do NOT exec an interactive zsh here — that would
	// block the installer). Skipped in CI / SKIP_BREW runs.
	setLoginShellZsh()
	slog.Info("Completed setup_quanianitis")
}

// setLoginShellZsh changes the user's login shell to zsh via chsh, best-effort.
func setLoginShellZsh() {
	if skipBrew() {
		slog.Info("Skipping login-shell change (CI or SKIP_BREW set)")
		return
	}
	zshPath, err := exec.LookPath("zsh")
	if err != nil {
		slog.Warn("zsh not on PATH; skipping login-shell change")
		return
	}
	if strings.HasSuffix(os.Getenv("SHELL"), "zsh") {
		slog.Info("Login shell already zsh")
		return
	}
	slog.Info("Changing login shell to zsh", slog.String("path", zshPath))
	// Ensure zsh is a valid login shell, then chsh (best-effort).
	createExec(fmt.Sprintf("grep -qxF '%s' /etc/shells || echo '%s' | sudo tee -a /etc/shells >/dev/null", zshPath, zshPath))
	createExec(fmt.Sprintf("chsh -s '%s' || sudo chsh -s '%s' \"$USER\"", zshPath, zshPath))
}

func createExec(command string) {
	cmd := exec.Command("/bin/bash", "-c", command)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		slog.Error("Command failed", slog.String("command", command), slog.Any("error", err))
	}
}

func writeMacDefaults(macDomain string, macKey string, macValue string) {
	command := fmt.Sprintf("defaults write %s %s %s", macDomain, macKey, macValue)
	createExec(command)
}

func cloneGit(repo string, dest string, depth int) {
	// Skip if the destination already exists to keep the installer idempotent.
	expanded := dest
	if strings.HasPrefix(dest, "~/") {
		if home, err := os.UserHomeDir(); err == nil {
			expanded = filepath.Join(home, dest[2:])
		}
	}
	if _, err := os.Stat(expanded); err == nil {
		slog.Info("Repository already present; skipping clone", slog.String("destination", dest))
		return
	}
	slog.Info("Cloning repository", slog.String("repo", repo), slog.String("destination", dest), slog.Int("depth", depth))
	command := fmt.Sprintf("git clone %s %s --depth %d", repo, dest, depth)
	createExec(command)
}

func setHomeDir() string {
	// Expand $HOME environment variable
	homeDir, err := os.UserHomeDir()
	if err != nil {
		slog.Error("Error getting home directory", slog.Any("error", err))
	}

	ghaValue, ghaEnv := os.LookupEnv("ACTIONS_WORKSPACE")

	if ghaEnv {
		homeDir = ghaValue
		homeDir = strings.TrimSuffix(homeDir, "/dotfiles")
	}
	return homeDir
}

// backupConflicts moves any pre-existing real files/dirs that stow would
// collide with into ~/.dotfiles-backup-<timestamp>/, so the repo version wins
// and stow never fails on a conflict. Existing correct symlinks are left alone.
func backupConflicts(pkgDir string, targetDir string) {
	entries, err := os.ReadDir(pkgDir)
	if err != nil {
		return
	}
	backupDir := ""
	for _, e := range entries {
		target := filepath.Join(targetDir, e.Name())
		info, err := os.Lstat(target)
		if err != nil {
			continue // nothing there — no conflict
		}
		if info.Mode()&os.ModeSymlink != 0 {
			continue // an existing symlink; stow --restow handles it
		}
		if backupDir == "" {
			home, _ := os.UserHomeDir()
			backupDir = filepath.Join(home, ".dotfiles-backup-"+time.Now().Format("20060102-150405"))
			_ = os.MkdirAll(backupDir, 0o755)
			slog.Warn("Backing up pre-existing files", slog.String("dir", backupDir))
		}
		dest := filepath.Join(backupDir, e.Name())
		if err := os.Rename(target, dest); err != nil {
			slog.Error("Failed to back up file", slog.String("path", target), slog.Any("error", err))
		} else {
			slog.Info("Backed up", slog.String("from", target), slog.String("to", dest))
		}
	}
}

func stowDir(sourceDir string, destDir string, packageName string) {
	homeDir := setHomeDir()

	// Replace $HOME with the actual home directory
	var targetDir string
	sourceDir = fmt.Sprintf("%s/%s", homeDir, sourceDir)
	if destDir == "" {
		targetDir = homeDir
	} else {
		targetDir = fmt.Sprintf("%s/%s", homeDir, destDir)
	}

	if _, err := os.Stat(targetDir); os.IsNotExist(err) {
		slog.Warn("Creating destination directory (does not exist)", slog.String("directory", targetDir))
		if err := exec.Command("mkdir", "-p", targetDir).Run(); err != nil {
			slog.Error("Failed to create destination directory", slog.String("directory", targetDir), slog.Any("error", err))
			return
		}
	}

	// Move conflicting real files aside so stow can't fail (repo wins).
	backupConflicts(filepath.Join(sourceDir, packageName), targetDir)

	// --restow is idempotent: re-linking already-correct symlinks is a no-op.
	command := fmt.Sprintf("stow --restow --no-folding -d %s -t %s %s", sourceDir, targetDir, packageName)

	slog.Info("Stowing package", slog.String("package", packageName), slog.String("source", sourceDir), slog.String("target", targetDir))
	createExec(command)
}
