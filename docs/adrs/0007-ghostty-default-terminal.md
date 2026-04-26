# ADR-0007: Ghostty as the default terminal on macOS and Windows

- **Status**: Accepted
- **Date**: 2026-04-26
- **Tags**: terminal, cross-platform

## Context

The previous repo carried iTerm2 plist configuration. iTerm2 is macOS-only,
which meant the Windows side ran Windows Terminal with an entirely
different config and feature set. There was no consistent terminal story
across platforms.

A new generation of GPU-accelerated terminals (Ghostty, Alacritty, Kitty,
WezTerm) has matured, with config files that lend themselves to chezmoi
templating.

## Decision

Use [Ghostty](https://ghostty.org/) as the default terminal on macOS and
Windows.

- Installed via Homebrew cask on macOS and via winget on Windows, in the
  `personal` and `work` tiers (skipped on `minimal`).
- Configuration lives in `home/dot_config/ghostty/`. The config file is
  intentionally near-default — Ghostty's defaults are good enough that
  custom theming and font tweaking are deferred until they hurt
  (beads `dotfiles-eg1`: "stripped to clean placeholder — Ghostty
  defaults are fine").
- Custom terminfo committed at
  `home/dot_config/ghostty/xterm-ghostty.terminfo` for hosts that don't
  yet ship Ghostty's terminfo entry; a CI workflow opens a PR when
  upstream terminfo is updated.
- Linux/WSL continues to use the host terminal — Ghostty Linux support is
  newer and not yet adopted here.

## Consequences

### Positive

- Same terminal feature set on macOS and Windows.
- GPU-accelerated; native config in a clean human-readable format.
- A near-empty config file is small surface area to maintain.

### Negative / trade-offs

- Linux/WSL uses whatever the host provides — not yet uniform across all
  platforms.
- Ghostty is younger than iTerm2; ecosystem (themes, plugins) is thinner.
- Custom terminfo file needs occasional refresh (handled by a workflow).

## Alternatives considered

- **iTerm2** — macOS-only; doesn't solve the Windows side.
- **Alacritty** — minimal, no native tabs/splits, more config-heavy.
- **Kitty** — strong feature set; macOS support not as polished as
  Ghostty's, no native Windows build.
- **WezTerm** — feature-rich; Lua config is more verbose.
- **Windows Terminal alone** — Windows-only; doesn't unify with macOS.
