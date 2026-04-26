# ADR-0002: Single source of truth for macOS, Linux, WSL, and Windows

- **Status**: Accepted
- **Date**: 2026-04-26
- **Tags**: cross-platform, foundation

## Context

The author runs dev machines on macOS (Apple Silicon), Ubuntu/Debian Linux,
WSL inside Windows, and native Windows (PowerShell). Keeping these in sync
manually — or via per-OS forks — leads to drift and duplicated effort.

The previous repo had separate top-level directories per platform
(`bash/`, `zsh/`, `powershell/`, `apt/`, `win/`), but no shared logic to
keep them coherent.

## Decision

Provision all four platforms from a single chezmoi source.

- OS-specific behaviour is gated with `{{ if eq .chezmoi.os "darwin" }}`,
  `linux`, or `windows` inside templates.
- Files that should not be deployed on a given OS are excluded via
  templated rules in `.chezmoiignore`.
- Bootstrap entry points:
  - **macOS / Linux / WSL** — `sh -c "$(curl … install.sh)"` installs Xcode
    CLT (macOS), Homebrew or apt prerequisites, then runs
    `chezmoi init --apply`.
  - **Windows** — `winget install twpayne.chezmoi` followed by
    `chezmoi init --apply pmgledhill102` from PowerShell.
- CI runs the full install on `ubuntu-latest`, `macos-latest`, and
  `windows-latest` on every push to main, plus weekly to catch upstream
  drift. PRs run a fast variant that skips package installs.

## Consequences

### Positive

- One repo, one PR for any cross-platform change.
- Drift between platforms is visible at review time, not after the fact.
- CI failure on any of the three platforms blocks merge to main.

### Negative / trade-offs

- Single template files can grow long branches of `if eq .chezmoi.os …`.
- Package lists exist in three native formats (Brewfile, apt, winget) and
  must be kept in conceptual sync — see ADR-0004.
- The full cross-platform CI matrix takes ~22 minutes; a fast PR variant
  trades thoroughness for round-trip speed.

## Alternatives considered

- **Per-OS forks** — diverges quickly; defeats the point of having dotfiles
  at all.
- **Ansible / Chef / Salt** — much heavier, designed for fleets rather than
  personal machines.
- **Pure bash bootstrap with copies/symlinks** — what the previous repo
  did; brittle and hard to template.
