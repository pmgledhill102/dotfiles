# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

This is a **chezmoi-managed dotfiles repository**. It provisions a development environment across macOS, Linux (Ubuntu/Debian), WSL, and Windows.

Claude Code's user-level configuration (slash commands, hooks, settings, MCP) lives in a separate repo, [`agentic-coding-config`](https://github.com/pmgledhill102/agentic-coding-config) — mounted into `~/.claude/` via chezmoi externals (see `home/.chezmoiexternal.toml.tmpl`). When working in this repo, agentic edits go in *that* repo; this repo handles machine config (shell, brew/winget, OS bootstrap).

## Repository Architecture

This repo uses **chezmoi** with `.chezmoiroot` set to `home/`, meaning files in `home/` map to `$HOME`. Chezmoi naming conventions:

- `dot_` prefix = `.` in target (e.g., `dot_zshrc` -> `~/.zshrc`)
- `.tmpl` suffix = Go template processed with data from `.chezmoi.toml`
- `run_once_` prefix = script runs once per machine
- `run_onchange_` prefix = script re-runs when its contents (or watched files) change

Key paths relative to repo root:

- `.chezmoi.toml` — config data (user info, package lists per platform)
- `home/` — all managed dotfiles and scripts
- `home/.chezmoiexternal.toml.tmpl` — declares the agentic-coding-config repo as a git-repo external mounted at `.claude/`
- `home/.chezmoiignore` — target-side rules; includes `.claude/<file>` exclusions for repo-meta files inside the external
- `home/Brewfile.tmpl` — installs `claude` and `claude-code@latest` casks (the binaries; their config lives in agentic-coding-config)
- `home/run_onchange_setup-claude.sh` — configures MCP servers per machine; reads keys from `~/.secrets`. Stays here because it's machine-bootstrap, not content
- `scripts/` — validation scripts for CI
- `specs/REQUIREMENTS.md` — consolidated project requirements and key decisions
- `docs/` — documentation (testing, troubleshooting)

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

## Related repos

- [`agentic-coding-config`](https://github.com/pmgledhill102/agentic-coding-config) — Claude Code commands/hooks/settings/MCP. Mounted at `~/.claude/` from this repo.
- [`paul-context`](https://github.com/pmgledhill102/paul-context) — private personal context: principles, decisions, repo registry, direction.
