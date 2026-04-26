# ADR-0006: Starship over Oh My Posh

- **Status**: Accepted
- **Date**: 2026-04-26
- **Tags**: shell, prompt

## Context

The shell prompt needs to render the same context (cwd, git status,
language version, exit code, cloud account) across zsh on macOS/Linux,
bash, and PowerShell on Windows.

The previous repo used [Oh My Posh](https://ohmyposh.dev/), which required
a custom theme JSON/YAML and per-shell init shims. Cross-shell parity was
limited and prompt cold-start cost was visible in interactive use.

## Decision

Adopt [Starship](https://starship.rs/) as the prompt for every shell.

- Single config at `home/dot_config/starship.toml`, shared across zsh,
  bash, and PowerShell.
- Initialised in `home/dot_zshrc.tmpl` via `eval "$(starship init zsh)"`,
  with a guard that disables it inside the VS Code Copilot Chat terminal.
- Transient prompt configured via a zsh hook so multi-line prompts collapse
  to a single character on Enter — keeps scrollback clean (see
  `docs/TRANSIENT-PROMPT.md`).
- `command_timeout = 2000` raised from the 500 ms default to accommodate
  slower language version checks on busy work machines (beads
  `dotfiles-pvt`).
- Installed via brew (macOS), Starship's installer (Linux), or winget
  (Windows) — present in all tiers that have an interactive shell.

## Consequences

### Positive

- One config file, three shells, three OSes.
- Faster cold-start than OMP in practice.
- Transient-prompt collapses noise on long sessions.
- Active upstream and a permissive TOML config that templates cleanly.

### Negative / trade-offs

- Theme syntax differs from Oh My Posh; existing OMP themes don't port.
- Some custom modules require shelling out to language toolchains, which
  is what made the timeout bump necessary.

## Alternatives considered

- **Oh My Posh** — used previously; per-shell init, slower in practice.
- **Powerlevel10k** — zsh-only; no PowerShell story.
- **Plain `PROMPT`** — fast but no git/OS/language context; not a fit.
- **Spaceship / Pure** — zsh-only, less flexible config.
