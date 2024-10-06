package main

import (
	"fmt"
	"log"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

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

	// Skip brew upgrades and installs if in a CICD environment
	ghaValue, ghaEnv := os.LookupEnv("ACTIONS_WORKSPACE")
	if !ghaEnv {
		// Update and upgrade Homebrew
		slog.Info("Updating and upgrading Homebrew...")
		createExec("brew update")
		createExec("brew upgrade")

		// Install packages from Brewfile
		homeDir := setHomeDir()
		brewfilePath := filepath.Join(homeDir, "dotfiles", "homebrew", "Brewfile")
		slog.Info("Installing packages from Brewfile...", slog.String("Brewpath", brewfilePath))
		createExec("brew bundle -v --file=" + brewfilePath)
	} else {
		slog.Info("Skipping... CI/CD Environment", slog.String("environment", ghaValue), slog.String("path", homebrewPath))
	}

	// Cleanup Homebrew
	slog.Info("Cleaning up Homebrew...")
	brewCleanup, err := script.Exec("brew cleanup").String()
	if err != nil {
		log.Fatalf("Failed to cleanup Brew: %s", err)
	}
	slog.Info("Brew cleanup output", slog.String("output", brewCleanup))

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
	stowDir("dotfiles/config", ".config/alacritty", "alacritty")
	stowDir("dotfiles/config", ".config/helix", "helix")
	stowDir("dotfiles/config", ".config/gh", "gh")
	stowDir("dotfiles/config", ".config/zellij", "zellij")
	stowDir("dotfiles", "", "zsh")
	stowDir("dotfiles", "", "homebrew")
	stowDir("dotfiles", "", "aliases")
	stowDir("dotfiles", "", "git")
	stowDir("dotfiles", ".steampipe/config", "steampipe")

	// Change user shell to zsh
	slog.Info("Changing user shell to Zsh...")
	createExec("zsh")
}

func createExec(command string) {
	if _, err := script.Exec(command).Stdout(); err != nil {
		slog.Error("Command failed", slog.String("command", command), slog.Any("error", err))
		return
	}
}

func cloneGit(repo string, dest string, depth int) {
	slog.Info("Cloning repository", slog.String("repo", repo), slog.String("destination", dest), slog.Int("depth", depth))
	command := fmt.Sprintf("git clone %s %s --depth %d", repo, dest, depth)
	createExec(command)
}

func setHomeDir() string {
	// Expand $HOME environment variable
	homeDir, err := os.UserHomeDir()
	if err != nil {
		slog.Error("Error getting home directory", err)
	}

	ghaValue, ghaEnv := os.LookupEnv("ACTIONS_WORKSPACE")

	if ghaEnv {
		homeDir = ghaValue
		homeDir = strings.TrimSuffix(homeDir, "/dotfiles")
	}
	return homeDir
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
		slog.Warn("Currently creating directory, destination directory does not exist", slog.String("directory", targetDir))
		err := exec.Command("mkdir", "-p", targetDir).Run()
		if err != nil {
			slog.Error("Failed to create destination directory", slog.String("directory", targetDir), slog.Any("error", err))
			return
		}
		slog.Info("Successfully created destination directory", slog.String("directory", targetDir))
	}

	command := fmt.Sprintf("stow --adopt -d %s -t %s %s", sourceDir, targetDir, packageName)

	slog.Info("Currently stowing package", slog.String("package", packageName), slog.String("source", sourceDir), slog.String("target", targetDir))
	if _, err := script.Exec(command).Stdout(); err != nil {
		slog.Error("Command failed", slog.String("command", command), slog.Any("error", err))
	}
	slog.Info("Successfully stowed package", slog.String("package", packageName), slog.String("source", sourceDir), slog.String("target", targetDir))
}
