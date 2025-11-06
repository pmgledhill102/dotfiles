# Research: Cross-Platform Dotfiles Setup

This document outlines the research tasks required for the successful
implementation of the dotfiles repository.

## Research Tasks

### 1. Secret Management: `age` vs. Bitwarden

**Task**: Research and decide on the best secret management tool for this
project, considering `age` encryption and Bitwarden.

**Decision**: `age` encryption with a passphrase will be used for
development-related secrets within the dotfiles repository. Bitwarden will
continue to be used for managing highly sensitive, personal secrets, but it will
not be integrated directly into the automated dotfiles setup.

**Rationale**:

- **Simplicity**: `age` is a simple, modern, and lightweight encryption tool with
  no external dependencies. This simplifies the installation process, especially
  in automated, non-interactive environments like CI/CD or new machine setups.
- **Cross-Platform Compatibility**: `age` works flawlessly on all target
  platforms, including ARM-based Macs (M1/M2), where the Bitwarden CLI has
  known issues.
- **Security Model**: Using a separate, passphrase-protected key for
  development secrets provides good security isolation. It avoids exposing the
  master password manager to the command line and build scripts.
- **`chezmoi` Integration**: `age` has first-class, native support in `chezmoi`,
  making the integration seamless.
- **Workflow**: The passphrase-based workflow is convenient for new machine
  setups. The user is prompted once to decrypt secrets, which is a good balance
  between security and automation.

### 2. Platform-Specific Configurations with `chezmoi`

**Task**: Research best practices for managing platform-specific configurations
(macOS, Debian/Ubuntu, WSL) using `chezmoi` templates.

**Questions to Answer**:

- How can `chezmoi` templates be used to apply different configurations based on
  the operating system?
- What variables are available in the templates for detecting the OS?
- What are some common patterns for structuring platform-specific dotfiles?
- How can we ensure that the installation script installs the correct
  dependencies for each platform?

### 3. Starship Configuration

**Task**: Research how to best configure Starship, managed by `chezmoi`.

**Questions to Answer**:

- Which files need to be managed by `chezmoi` for Starship? (`starship.toml`)
- How should Starship be installed by the `chezmoi` installation script across
  different platforms (macOS, Debian/Ubuntu, WSL)?
- How do we configure Starship to replicate the features from the existing
  prompt?
- How does Starship integrate with OhMyZsh?

### 4. Experimenting with Starship

**Task**: Use the `starship-playground.md` to install and configure Starship.
Document the process of configuring custom prompt elements in Starship's configuration.

**Questions to Answer**:

- What is the basic installation and setup process for Starship?
- How do you translate specific prompt features (e.g., git status, Kubernetes context, AWS profile) from the old setup to `starship.toml`?
- What are the common pitfalls or differences in configuration philosophy between Starship and other prompts?
