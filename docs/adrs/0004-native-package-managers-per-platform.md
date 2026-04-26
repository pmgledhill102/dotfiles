# ADR-0004: Native package managers per platform; no abstraction layer

- **Status**: Accepted
- **Date**: 2026-04-26
- **Tags**: packages, cross-platform

## Context

The repo provisions packages on three OSes, each with a strong native
package manager: Homebrew on macOS, apt on Ubuntu/Debian, winget on
Windows. Each handles its own ecosystem well (especially GUI casks and
Windows Store apps) and poorly outside it.

There are tools that try to abstract over native managers (Nix, pkgx,
devbox), but they all add a runtime dependency and an indirection that
hides what is actually being installed.

## Decision

Declare packages directly in each platform's native list, and accept a
small amount of duplication.

- **macOS** — `home/Brewfile.tmpl` (see ADR-0005).
- **Ubuntu/Debian / WSL** — `[data.packages.apt]` arrays in
  `home/.chezmoi.toml.tmpl`, consumed by
  `run_onchange_install-ubuntu-packages.sh.tmpl`.
- **Windows** — `[data.packages.winget]` arrays in
  `home/.chezmoi.toml.tmpl`, plus `packages_pinned` for items with
  built-in auto-updaters that conflict with `winget upgrade`.

No higher-level wrapper sits between these lists and the underlying
manager.

## Consequences

### Positive

- Each list reads in the idiomatic format for its platform; commits are
  searchable and grep-friendly.
- GUI installs (casks, Store apps) feel native — no awkward shimming.
- Easy to debug: `brew bundle install`, `apt install`, `winget install`
  are familiar to anyone running the platform.

### Negative / trade-offs

- Three lists to keep in conceptual sync. A tool added on macOS doesn't
  automatically appear on Linux or Windows.
- Some packages have different identifiers across managers
  (`git-delta` vs `dandavison.delta`).
- Cross-platform PRs touch multiple files.

## Alternatives considered

- **Nix / home-manager** — single source, but heavy; would require Nix on
  every target machine, including Windows.
- **pkgx / devbox / mise** — promising but immature for full-machine
  provisioning, and don't cover GUI casks or Windows Store apps.
- **Hand-rolled YAML mapped to all three managers** — writing and
  maintaining the abstraction is more work than maintaining three lists.
