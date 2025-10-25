# Quickstart: Cross-Platform Dotfiles Setup

This guide explains how to install and use this dotfiles repository on a new
machine.

## Prerequisites

Before you begin, ensure that you have the following dependencies installed on
your system:

- `git`
- `bitwarden-cli`

## Installation

To install the dotfiles, run the following command in your terminal:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <your-git-repository-url>
```

This command will:

1. Install `chezmoi` if it is not already installed.
2. Initialize `chezmoi` with your dotfiles repository.
3. Apply the dotfiles to your home directory.

## Secret Management

This repository uses `chezmoi`'s integration with Bitwarden to manage secrets.
To access your secrets, you will need to be logged into the Bitwarden CLI.

1. **Log in to Bitwarden**:

   ```sh
   bw login
   ```

2. **Sync your secrets**:

   `chezmoi` will automatically fetch your secrets from Bitwarden when you run
   `chezmoi apply`.

## Platform-Specific Configurations

This repository uses `chezmoi`'s templating engine to apply platform-specific
configurations for macOS, Debian/Ubuntu, and WSL.

The installation script will automatically detect your operating system and
apply the correct configuration.
