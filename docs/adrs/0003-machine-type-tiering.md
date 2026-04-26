# ADR-0003: Machine-type tiering (personal / work / minimal)

- **Status**: Accepted
- **Date**: 2026-04-26
- **Tags**: layering, packages

## Context

A single dotfiles repo serves machines with very different needs:

- **Personal workstations** want the full kitchen sink: cloud CLIs, GUI
  apps, games launchers, Office, language toolchains.
- **Work laptops** want the dev essentials but not Steam, Discord, or
  Microsoft Office personal-tier extras.
- **Headless servers / VMs / CI runners** want a small, fast, CLI-only
  install and skip GUI casks entirely.

Without tiering, the repo would either bloat minimal boxes or under-equip
personal ones.

## Decision

Introduce a `machine_type` value with three tiers — `personal`, `work`,
`minimal` — chosen interactively on first apply and driving conditional
package installation.

- The choice is captured in `home/.chezmoi.toml.tmpl` via `promptChoiceOnce`
  and persisted in `~/.config/chezmoi/chezmoi.toml`.
- `machine_type` gates:
  - Brew formulae and casks in `home/Brewfile.tmpl`
  - apt packages in `[data.packages.apt]`
  - winget packages and pinned packages in `[data.packages.winget]`
  - VS Code extensions (`extensions_core` vs `extensions_personal`)
  - GUI-only files via `home/.chezmoiignore`
- Users change tier later by editing `~/.config/chezmoi/chezmoi.toml` and
  re-running `chezmoi apply`.
- CI seeds `machine_type = "personal"` non-interactively, because
  `promptChoiceOnce` does not honour `--promptChoice` flags.

## Consequences

### Positive

- One repo, three behaviours; no per-tier branches.
- Cost-heavy installs (Steam, Office, Adobe Reader) are gated cleanly to
  personal tier.
- A fresh minimal VM gets a fast, lean install.

### Negative / trade-offs

- Templates branch on `eq .machine_type "..."` in many files; readers must
  hold all three branches in their head.
- Adding a fourth tier touches every conditional list.
- Non-interactive environments must seed the value before `chezmoi init`.

## Alternatives considered

- **Hostname-based detection** — brittle (renames, fresh installs) and
  invisible to the user.
- **Environment variable** — does not persist across sessions or survive
  re-applies.
- **Separate branches per machine** — defeats the point of a shared repo.
