# Requirements

Consolidated reference for the dotfiles repository. Sourced from the original
spec, research, and plan documents (Oct 2025).

## Constraints

- **Platforms**: macOS, Debian/Ubuntu, WSL, and Windows (PowerShell)
- **Idempotent**: all install scripts safe to re-run without errors or duplicates
- **Performance**: shell startup under 1 second on modern hardware (NFR-PERF-001)
- **CI budget**: test matrix completes within 10 minutes per platform

## Principles

1. **Idempotence** — scripts produce the same result on every run
2. **Portability** — consistent experience across macOS, Linux, WSL, Windows
3. **Security** — never expose secrets in version control
4. **Modularity** — tool configs are self-contained and independently testable
5. **Simplicity** — prefer straightforward solutions over clever ones

## Functional Requirements

| ID | Requirement |
| ---- | ------------- |
| FR-001 | Single command installs dotfiles on a new machine |
| FR-002 | Install script detects OS and installs correct dependencies |
| FR-003 | Install and configure Zsh as default shell |
| FR-004 | Install and configure Oh My Zsh with plugins (autosuggestions, syntax-highlighting, colored-man-pages, command-not-found, history, copypath, copyfile) |
| FR-005 | Install and configure Starship prompt (including PowerShell) |
| FR-006 | Manage development secrets via age encryption with passphrase |
| FR-007 | Tool configs organized into logical, self-contained modules |
| FR-008 | Automated testing for install validation on macOS and Ubuntu |
| FR-009 | Validation scripts verify correct installation of all components |
| FR-010 | GitHub Actions workflows for CI testing |
| FR-011 | Install and configure Ghostty on macOS and Windows |
| FR-012 | Installation scripts are idempotent and re-runnable |
| FR-013 | Pre-commit hooks enforce markdown linting on all docs |

## Key Decisions

### Secret management: age over Bitwarden CLI

`age` was chosen for development-related secrets because it is lightweight, has
no external dependencies, works on ARM Macs, and has first-class chezmoi
integration. Highly sensitive secrets stay in Bitwarden, managed manually.

### Dotfile manager: chezmoi

The repository uses chezmoi with `.chezmoiroot` set to `home/`, meaning files
under `home/` map to `$HOME`. Platform-specific configs are handled via Go
templates with OS detection (`{{ if eq .chezmoi.os "darwin" }}`).

### Machine type tiers

`promptChoiceOnce` in `.chezmoi.toml.tmpl` offers `personal`, `work`, and
`minimal` profiles. The choice drives conditional package lists for brew, apt,
and winget.

## Architecture

```text
.chezmoi.toml.tmpl          # Config template (machine type, user data)
home/                       # All managed dotfiles (.chezmoiroot target)
  dot_zshrc                 # Zsh config
  dot_config/               # XDG config (starship, ghostty, lazygit, …)
  run_once_*.sh.tmpl        # One-time install scripts (per platform)
  run_onchange_*.sh.tmpl    # Re-run on content change (brew bundle, etc.)
scripts/                    # CI validation scripts
docs/                       # Testing, maintenance, troubleshooting guides
```
