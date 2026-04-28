# ADR-0005: Brewfile.tmpl as canonical macOS package source

- **Status**: Accepted
- **Date**: 2026-04-26
- **Tags**: packages, macos

## Context

Earlier in the project, macOS package definitions were kept inside the
chezmoi config TOML alongside apt and winget lists. That coupled package
updates to the chezmoi-init lifecycle: a fresh `chezmoi apply` was needed
before `dotup` would pick up new packages, and the canonical source split
across two files.

A small bug (`dotfiles-5dn` — fzf appearing in apt's list when Homebrew
was its real source) forced the question: where do macOS packages live?

## Decision

Macos packages live exclusively in `home/Brewfile.tmpl`.

- `Brewfile.tmpl` is templated by chezmoi and renders to `~/Brewfile` per
  the active machine type (personal / work / minimal).
- `brewup` runs `brew update`, `brew bundle install --file ~/Brewfile`,
  then `brew upgrade` — the daily refresh path.
- `run_once_after_install-brewfile.sh.tmpl` runs the bundle install on the
  first `chezmoi apply`, so a fresh machine bootstraps the full package set
  without manual intervention. Ongoing updates run through `brewup`.
- apt and winget lists do not duplicate Homebrew formulae.

## Consequences

### Positive

- One file to edit when adding or removing macOS packages.
- `brewup` always picks up the latest list with no chezmoi reapply.
- `brew bundle dump` round-trips cleanly into the same format.
- Templated tier branches keep personal / work / minimal in one place.

### Negative / trade-offs

- Macos-only — apt and winget still maintain parallel lists for the same
  conceptual tools.
- The file grows long as more tiers and more tools accumulate.

## Alternatives considered

- **Keep packages in chezmoi TOML** — what we used to do; coupled updates
  to chezmoi-init lifecycle, abandoned in PR #91.
- **Separate Brewfiles per tier** — three files to maintain; templating
  branches in one file is simpler.
- **Per-category Brewfiles** (cli/, casks/, dev/) — adds bundling logic
  without solving a real problem.
