# Implementation Plan: Cross-Platform Dotfiles Setup

**Branch**: `001-dotfiles-setup` | **Date**: 2025-10-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-dotfiles-setup/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See
`.specify/templates/commands/plan.md` for the execution workflow.

## Summary

This plan outlines the technical implementation for creating a cross-platform
dotfiles repository managed by `chezmoi`. The goal is to provide a consistent
Zsh shell experience (OhMyZsh with productivity plugins + Starship prompt)
across macOS, Debian/Ubuntu, and WSL, with Ghostty as the terminal emulator
and secure secret management using age encryption for development-related secrets.

## Technical Context

**Language/Version**: Shell (Zsh, Bash)
**Primary Dependencies**: `chezmoi`, `zsh`, `oh-my-zsh`, `starship`, `git`,
  `age`, `ghostty`
**Storage**: Filesystem
**Testing**: Automated testing via GitHub Actions, validation scripts, ShellCheck for linting.
**Target Platform**: macOS, Debian/Ubuntu, WSL
**Project Type**: Dotfiles management
**Performance Goals**: Installation should take less than 5 minutes on a fresh OS.
**Constraints**: Must work on all three target platforms.
**Scale/Scope**: Personal use for a single developer.

## Testing Strategy

### CI/CD Testing with GitHub Actions

- **Trigger**: Pull requests, pushes to main branch, and scheduled nightly builds
- **Environments**:
  - `macos-latest` runner
  - `ubuntu-latest` runner
- **Matrix Testing**: Multiple OS versions where applicable
- **Artifacts**: Test logs, configuration files, and validation reports
- **Process**: Automated workflows that provision clean environments, run installation, and
  validate results using post-installation scripts

### Local Testing (Optional)

- **Tool**: Local VMs (e.g., UTM, VirtualBox) or containers if applicable
- **Note**: Primary validation is driven by CI/CD to ensuring reproducibility independent of local hardware.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Idempotence**: Do all setup scripts run without changing the system state
  after the initial run?
- **Portability**: Does the system provide a consistent experience across macOS,
  Debian/Ubuntu, and WSL?
- **Security**: Are development secrets managed securely using age encryption
  with passphrase protection, while keeping personal/sensitive secrets in
  Bitwarden for manual management?
- **Modularity**: Are configurations for distinct tools organized into
  self-contained modules?

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
.chezmoi.yaml.tmpl  # chezmoi config file template
home/               # Files and directories to be placed in the home directory
  .gitconfig
  .zshrc
  .config/
    nvim/
      init.vim
.chezmoitemplates/    # Templates for platform-specific configurations
  README.md
run_once_install-packages.sh.tmpl # Script to install packages on new machines
.chezmoiignore      # Files to be ignored by chezmoi
```

**Structure Decision**: The project will use a standard `chezmoi` repository
structure. This allows for easy management of dotfiles across different
platforms. Platform-specific configurations will be handled using `chezmoi`'s
templating engine.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation                  | Why Needed         | Simpler Alternative Rejected Because |
|----------------------------|--------------------|--------------------------------------|
| [e.g., 4th project]        | [current need]     | [why 3 projects insufficient]        |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient]  |
