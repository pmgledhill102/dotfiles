# Quickstart: Cross-Platform Dotfiles Setup

This guide explains how to install and use this dotfiles repository on a new
machine.

## Prerequisites

Before you begin, ensure that you have the following dependencies installed on
your system:

- `git`
- `age`

## Installation

To install the dotfiles, run the following command in your terminal:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --branch main https://github.com/pmgledhill102/dotfiles.git
```

This command will:

1. Install `chezmoi` if it is not already installed.
2. Initialize `chezmoi` with your dotfiles repository.
3. Apply the dotfiles to your home directory.

## Secret Management

This repository uses `age` to encrypt sensitive files. `chezmoi` will
automatically decrypt these files when you run `chezmoi apply`, and will prompt
you for your passphrase.

You do not need to perform any manual steps to decrypt secrets during
installation. For details on how to add or edit encrypted files, please refer
to the main `README.md` file.

## Platform-Specific Configurations

This repository uses `chezmoi`'s templating engine to apply platform-specific
configurations for macOS, Debian/Ubuntu, and WSL.

The installation script will automatically detect your operating system and
apply the correct configuration.
