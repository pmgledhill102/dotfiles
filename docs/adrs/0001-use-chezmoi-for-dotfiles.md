# ADR-0001: Use chezmoi for dotfiles management

- **Status**: Accepted
- **Date**: 2026-04-26
- **Tags**: tooling, foundation

## Context

The repository needs to provision a consistent shell, editor, and CLI
environment across macOS, Ubuntu/Debian, WSL, and Windows, with per-machine
variation (personal workstation vs work laptop vs headless server). It also
needs to handle secrets, run one-off platform setup scripts, and stay
re-runnable.

A previous incarnation of these dotfiles used GNU Stow plus a hand-rolled
`install.sh` to symlink directories into `$HOME`. That approach hit limits as
soon as configuration needed to vary by OS or machine, and Stow's strict
folder layout caused recurring breakage.

## Decision

Use [chezmoi](https://www.chezmoi.io/) as the sole dotfiles manager.

- `.chezmoiroot` points at `home/`, so files under `home/dot_*` map to
  `~/.*`.
- Per-OS and per-machine variation is expressed in Go templates
  (`{{ if eq .chezmoi.os "darwin" }}`, `{{ if eq .machine_type "personal" }}`).
- One-shot setup runs in `run_once_*.sh.tmpl` scripts; idempotent
  re-application uses `run_onchange_*.sh.tmpl` scripts that re-run only when
  their content (or a watched file) changes.
- A minimal `install.sh` bootstraps prerequisites (Xcode CLT, Homebrew,
  git), then hands off to `chezmoi init --apply`.

## Consequences

### Positive

- One templating engine handles per-OS and per-machine variation in place,
  rather than per-platform forks.
- `run_once` / `run_onchange` give safe, idempotent provisioning out of the
  box.
- First-class age integration for encrypted files.
- `chezmoi diff` shows exactly what would change before applying.

### Negative / trade-offs

- Steeper conceptual ramp than Stow's "symlink a folder".
- Two clones exist on dev machines: the working copy at `~/dev/dotfiles` for
  edits/PRs, and chezmoi's own clone under `~/.local/share/chezmoi` that
  `chezmoi apply` reads from. Edits in one don't take effect until the
  other is synced (`dotup` / `chezmoi update`).

## Alternatives considered

- **GNU Stow** — symlink-only, no templating, no encryption. Used in the
  predecessor repo and abandoned.
- **yadm** — git-over-`$HOME`, lighter than chezmoi but no per-machine
  templating story.
- **Bare git over `$HOME`** — too sharp; no templating, no encryption
  helpers, easy to commit secrets by accident.
- **Nix home-manager** — powerful but invasive; adds a Nix dependency on
  every target machine, including work and Windows boxes.
