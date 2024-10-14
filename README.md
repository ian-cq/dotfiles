# Ian's Dotfiles

<img width="1710" alt="image" src="https://github.com/user-attachments/assets/0f039c1b-6e1c-49c1-8680-120f9f6422c8">

## Description

This repository is my personal dotfiles containing a collection of configuration settings for my day-to-day applications and automation scripts to set it up initially. Made to be streamlined across all environments including MacOS (both Darwin x86-64 and arm64 and Linux).

To sync across devices, I use GNU stow for my symlinks and this git repository's contents, a Golang script to initiate installation (and sync configurations #TODO) and an initial bootstrap script to make it even more simpler for the machine init.

## Install

```
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/ian-cq/dotfiles/refs/heads/main/install)"
```

## Catalogue
### List of Configurations
- zsh
- aliases
- alacritty
- helix
- zellij
- neovim (#TODO) - in the midst of migrating to neovim
- gh
- MacOS Settings
- git
- homebrew formulae and casks
- ssh
- steampipe

### List of Capabilities
- GNU Stow
- Go Language
- Bootstrap shell script for Dependencies 
- Github Actions for build, test and release
- Git subtrees for some forked repositories



## Limitations

Haven't tested out on Linux as much. And a lot of the mac settings will definitely error out in linux's environment, but I intend to use homebrew and oh my zsh in a linux environment either way because it's what I've worked with all the time.

**TODO**
- [] Golang script to sync configurations on a cron basis
- [] Include networking dotfiles (other than ssh)
- [] Include 1password autologin
- [] Neovim - migrate from helix to nvim
