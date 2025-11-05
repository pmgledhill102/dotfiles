# Research: Cross-Platform Dotfiles Setup

This document outlines the research tasks required for the successful
implementation of the dotfiles repository.

## Research Tasks

### 1. `chezmoi` and Bitwarden Integration

**Task**: Research best practices for integrating `chezmoi` with Bitwarden for
secret management.

**Questions to Answer**:

- How does `chezmoi` integrate with the Bitwarden CLI?
- What is the recommended workflow for adding, updating, and retrieving secrets?
- How are secrets exposed to the system (e.g., as environment variables, in
  config files)?
- What are the security implications of this approach?

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

### 3. Migrating from Powerlevel10k to Starship

**Task**: Research how to best migrate from Powerlevel10k to Starship, managed
by `chezmoi`.

**Questions to Answer**:

- Which files need to be managed by `chezmoi` for Starship? (`starship.toml`)
- How should Starship be installed by the `chezmoi` installation script across
  different platforms (macOS, Debian/Ubuntu, WSL)?
- How do we configure Starship to replicate the features from the existing
  prompt?
- How does Starship integrate with OhMyZsh?

### 4. Experimenting with Starship

**Task**: Use the `starship-playground.md` to install and configure Starship.
Document the process of migrating custom prompt elements from OhMyPosh/Powerlevel10k to Starship's configuration.

**Questions to Answer**:

- What is the basic installation and setup process for Starship?
- How do you translate specific prompt features (e.g., git status, Kubernetes context, AWS profile) from the old setup to `starship.toml`?
- What are the common pitfalls or differences in configuration philosophy between Starship and Powerlevel10k/OhMyPosh?
