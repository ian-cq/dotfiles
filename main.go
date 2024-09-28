package main

import (
	"fmt"
	"log"
	"log/slog"
	"os"
	"os/exec"

	"github.com/bitfield/script"
)

func main() {
	// Install Homebrew (state: present)
	slog.Info("Ensuring Homebrew is installed...")
	homebrewPath, err := exec.LookPath("brew")
	if err != nil {
		createExec("/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
	} else {
		slog.Info("Homebrew already installed", slog.String("path", homebrewPath))
	}

	// Update and upgrade Homebrew
	slog.Info("Updating and upgrading Homebrew...")
	createExec("brew update")
	createExec("brew upgrade")

	// Install packages from Brewfile
	slog.Info("Installing packages from Brewfile...")
	brewOutput, err := script.Exec("brew bundle --file=homebrew/Brewfile").String()
	if err != nil {
		log.Fatalf("Failed to run Brewfile: %s", err)
	}
	slog.Info("Brewfile output", slog.String("output", brewOutput))

	// Cleanup Homebrew
	slog.Info("Cleaning up Homebrew...")
	brewCleanup, err := script.Exec("brew cleanup").String()
	if err != nil {
		log.Fatalf("Failed to cleanup Brew: %s", err)
	}
	slog.Info("Brew cleanup output", slog.String("output", brewCleanup))

	// Set macOS screencapture location (only if running on Darwin)
	if os.Getenv("OSTYPE") == "darwin" {
		slog.Info("Setting screencapture location to ~/Downloads...")
		createExec("defaults write com.apple.screencapture location ~/Downloads")
	}

	// Install ZSH
	zshPath, err := exec.LookPath("zsh")
	if err != nil {
		createExec("brew install zsh")
	} else {
		slog.Info("Zsh already installed", slog.String("path", zshPath))
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

	// Stow dotfiles
	slog.Info("Stowing dotfiles...")
	stowDir("../../../dotfiles", "$HOME/zsh")
	stowDir("../../../dotfiles", "$HOME/git")
	stowDir("../../../dotfiles", "$HOME/.config/config")
	stowDir("../../../dotfiles", "$HOME/.ssh/ssh")
	stowDir("../../../dotfiles", "$HOME/.steampipe/steampipe")

	// Change user shell to zsh
	slog.Info("Changing user shell to Zsh...")
	createExec("chsh -s /bin/zsh")
}

func createExec(command string) {
	if _, err := script.Exec(command).Stdout(); err != nil {
		slog.Error("Command failed", slog.String("command", command), slog.Any("error", err))
		log.Fatalf("Command failed: %s", err)
	}
}

func cloneGit(repo string, dest string, depth int) {
	slog.Info("Cloning repository", slog.String("repo", repo), slog.String("destination", dest), slog.Int("depth", depth))
	command := fmt.Sprintf("git clone %s %s --depth %d", repo, dest, depth)
	createExec(command)
}

func stowDir(sourceDir string, targetDir string) {
	slog.Info("Stowing directory", slog.String("source", sourceDir), slog.String("target", targetDir))
	command := fmt.Sprintf("stow -d \"%s\" -t \"%s\" %s", sourceDir, targetDir, sourceDir)
	createExec(command)
}
