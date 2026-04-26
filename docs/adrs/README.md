# Architecture Decision Records

This directory captures the major architectural decisions that shape this
dotfiles repository. ADRs are short, dated records intended to:

1. Make the *why* behind current design choices discoverable.
2. Provide a checkpoint when considering a change of direction — if the
   reasoning for an ADR no longer holds, it should be revisited.
3. Keep new work aligned with the established intent of the repo.

## Format

Each ADR uses a short [MADR](https://adr.github.io/madr/)-style template:

- **Status** — `Accepted`, `Proposed`, `Superseded`, or `Deprecated`
- **Date** — ISO date the decision was recorded
- **Context** — the situation that called for a decision
- **Decision** — what was chosen
- **Consequences** — positive and negative effects of the choice
- **Alternatives considered** — what was rejected and why

## Conventions

- File names: `NNNN-kebab-title.md` (zero-padded four-digit number).
- Numbers are immutable and never reused. Superseded ADRs stay in place and
  link forward to the ADR that replaced them.
- One decision per ADR. If a single PR touches several decisions, write
  several ADRs.

## Index

| # | Title | Status |
| - | ----- | ------ |
| [0001](0001-use-chezmoi-for-dotfiles.md) | Use chezmoi for dotfiles management | Accepted |
| [0002](0002-single-source-cross-platform.md) | Single source of truth for macOS, Linux, WSL, and Windows | Accepted |
| [0003](0003-machine-type-tiering.md) | Machine-type tiering (personal / work / minimal) | Accepted |
| [0004](0004-native-package-managers-per-platform.md) | Native package managers per platform; no abstraction layer | Accepted |
| [0005](0005-brewfile-canonical-macos-packages.md) | Brewfile.tmpl as canonical macOS package source | Accepted |
| [0006](0006-starship-over-oh-my-posh.md) | Starship over Oh My Posh | Accepted |
| [0007](0007-ghostty-default-terminal.md) | Ghostty as the default terminal on macOS and Windows | Accepted |
| [0008](0008-podman-replaces-docker.md) | Podman replaces Docker | Accepted (with caveats) |
| [0009](0009-helper-shell-functions.md) | Helper shell functions for daily dotfiles workflow | Accepted |
| [0010](0010-secrets-management.md) | Secrets management strategy | Proposed |
| [0011](0011-beads-task-tracking.md) | Beads with embedded Dolt for task tracking | Accepted |
| [0012](0012-claude-code-config-via-dotfiles.md) | Claude Code configuration shipped via the dotfiles repo | Accepted |
| [0013](0013-three-layer-enforcement.md) | Three-layer enforcement — CI, pre-commit, Claude Code hooks | Accepted |
