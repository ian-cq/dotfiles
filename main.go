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
	// slog.Info("Updating and upgrading Homebrew...")
	// createExec("brew update")
	// createExec("brew upgrade")

	// Install packages from Brewfile
	// slog.Info("Installing packages from Brewfile...")
	// brewOutput, err := script.Exec("brew bundle --file=/homebrew/Brewfile").String()
	// if err != nil {
	// 	log.Fatalf("Failed to run Brewfile: %s", err)
	// }
	// slog.Info("Brewfile output", slog.String("output", brewOutput))

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
	stowDir("dotfiles/config", ".config/alacritty", "alacritty")
	stowDir("dotfiles/config", ".config/helix", "helix")
	stowDir("dotfiles/zsh", "", "zsh")
	// stowDir(".", "")
	// stowDir(".", ".ssh/ssh")
	// stowDir(".", ".steampipe/steampipe")

	// Change user shell to zsh
	slog.Info("Changing user shell to Zsh...")
	createExec("zsh")
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

func stowDir(sourceDir string, destDir string, packageName string) {
	// Expand $HOME environment variable
	homeDir, err := os.UserHomeDir()
	if err != nil {
		slog.Error("Error getting home directory", err)
		return
	}

	ghaEnv := os.Getenv("ENABLE_CICD")

	if ghaEnv == "true" {
		homeDir = "/github/workspace"
	}

	// Replace $HOME with the actual home directory
	var targetDir string
	sourceDir = fmt.Sprintf("%s/%s", homeDir, sourceDir)
	if destDir == "" {
		targetDir = homeDir
	} else {
		targetDir = fmt.Sprintf("%s/%s", homeDir, destDir)
	}

	slog.Info("Stowing package", slog.String("package", packageName), slog.String("source", sourceDir), slog.String("target", targetDir))

	if _, err := os.Stat(destDir); os.IsNotExist(err) {
		slog.Warn("Destination directory does not exist, creating it", slog.String("directory", destDir))
		err := exec.Command("mkdir", "-p", destDir).Run()
		if err != nil {
			slog.Error("Failed to create destination directory", slog.String("directory", destDir), slog.Any("error", err))
			return
		}
		slog.Info("Successfully created destination directory", slog.String("directory", destDir))
	}

	createExec(fmt.Sprintf("ls %s", sourceDir))
	createExec(fmt.Sprintf("cat %s/*", sourceDir))
	createExec(fmt.Sprintf("ls %s", destDir))
	createExec(fmt.Sprintf("cat %s/*", destDir))

	command := fmt.Sprintf("stow -d %s -t %s %s", sourceDir, targetDir, packageName)

	if _, err := script.Exec(command).Stdout(); err != nil {
		slog.Error("Command failed", slog.String("command", command), slog.Any("error", err))
	}
}
