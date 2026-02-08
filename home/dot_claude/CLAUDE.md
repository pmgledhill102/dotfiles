# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

This is a subdirectory of a **chezmoi-managed dotfiles repository** (`/Users/paul/dev/dotfiles`). The full repo provisions a development environment across macOS, Linux (Ubuntu/Debian), WSL, and Windows.

This directory (`home/dot_claude/`) maps to `~/.claude/` when chezmoi applies dotfiles. It contains centralized Claude Code configuration (hooks, slash commands, policy) intended for use across all repositories.

## Repository Architecture

The parent dotfiles repo uses **chezmoi** with `.chezmoiroot` set to `home/`, meaning files in `home/` map to `$HOME`. Chezmoi naming conventions:
- `dot_` prefix = `.` in target (e.g., `dot_zshrc` -> `~/.zshrc`)
- `.tmpl` suffix = Go template processed with data from `.chezmoi.toml`
- `run_once_` prefix = script runs once per machine
- `run_onchange_` prefix = script re-runs when its contents (or watched files) change

Key paths relative to repo root:
- `.chezmoi.toml` — config data (user info, package lists per platform)
- `home/` — all managed dotfiles and scripts
- `home/dot_claude/` — this directory, Claude Code config
- `scripts/` — validation scripts for CI
- `specs/` — feature specifications
- `docs/` — documentation (testing, maintenance, troubleshooting, migration)

## CI/CD and Linting

CI runs on push/PR to `main` via `.github/workflows/ci.yml`:
- **ShellCheck** on `scripts/` and `home/`
- **markdownlint-cli2** on all `*.md` files (config: `.markdownlint.yaml`)
- **actionlint** on GitHub Actions workflows
- **Test Install** matrix: Ubuntu, macOS, Windows — runs `chezmoi init --apply` then validation scripts

Pre-commit hooks (`.pre-commit-config.yaml`) run markdownlint-cli2.

## Commit Style

Conventional commits: `<type>(<scope>): <description>`
Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`

## Claude Code Config Architecture (This Directory)

The design separates concerns by context cost:
- **Slash commands** (`/setup-python`, etc.) — loaded only when invoked, set up language tooling
- **Hooks** — run tools automatically (pre-commit, formatters) with zero context cost
- **CLAUDE.md** — lean universal policy, always loaded

See `README.md` in this directory for the full implementation plan including enforcement layers and per-language tool matrices.
