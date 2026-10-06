# ADR-0017: Homebrew and the Brewfile on personal Linux machines

- **Status**: Accepted
- **Scope**: Repo — this record binds `dotfiles` only. It decides which
  package manager this repo drives on which machine tier, which would not
  bind anything if this repo were archived.
- **Date**: 2026-10-06
- **Tags**: packages, linux, wsl
- **Supersedes**: [ADR-0004](0004-native-package-managers-per-platform.md)
  for `personal` Linux machines only
- **Implements**: [#450](https://github.com/pmgledhill102/dotfiles/issues/450)

## Context

[ADR-0004](0004-native-package-managers-per-platform.md) puts every Linux
machine on apt, with one-off installers for tools apt lacks or ships too old.
Bootstrapping a personal WSL machine showed what that costs in practice:

- **The tool gap keeps reopening.** A personal Mac gets the whole Brewfile,
  about 80 tools. Personal Linux got about 15 apt packages plus installers,
  and each missing tool was found by hand and closed one PR at a time: nvm
  (#435), gh (#440), mdcat (#417), Starship without sudo (#446), and
  eza/fzf/zoxide/fd/ripgrep (#448). `pre-commit`, `markdownlint-cli2`,
  `actionlint`, `gitleaks`, `yq`, `go`, `github-mcp-server`, `bitwarden-cli`
  and others were still missing.
- **Nothing updates after day one.** `brewup` is the update path on macOS.
  Linux had none: lazygit, mdcat and fzf stayed at whatever version was first
  installed.
- **Names and versions drift.** Ubuntu calls bat and fd `batcat` and `fdfind`,
  and its fzf is too old for `fzf --zsh`. Each needed its own workaround.

Homebrew runs on Linux, and almost every formula in the personal Brewfile has
a Linux bottle. A survey of homebrew-core found only `xcodes` and `xcodegen`
are macOS-only, plus the `openai/tools/tart` tap formula and every cask.

## Decision

**`personal` Linux machines (including WSL) install Homebrew and run the same
`home/Brewfile.tmpl` as macOS.** `work` and `minimal` Linux machines are
unchanged: apt only, as ADR-0004 says.

- `run_once_before_install-packages.sh.tmpl` installs Homebrew to
  `/home/linuxbrew/.linuxbrew` on personal Linux, and
  `run_once_after_install-brewfile.sh.tmpl` runs `brew bundle` there as it
  does on macOS.
- `.chezmoiignore` deploys `~/Brewfile` and `brewup` on macOS and personal
  Linux, so `brewup` is the update path on both.
- **One owner per tool.** The personal apt list shrinks to what the bootstrap
  needs before Homebrew exists (`curl`, `git`, `wget`, `zip`, `unzip`, `zsh`)
  plus `podman`. The one-off installers for lazygit, mdcat, fzf, gh, uv and
  Starship, and the bat/fd links, are skipped on personal machines.
- **Entries that stay macOS-only in the Brewfile** sit behind
  `{{ if eq .chezmoi.os "darwin" }}`:
  - macOS-only upstream: `xcodes`, `xcodegen`, `tart`, `fastlane`, every cask
  - a different Linux owner: `podman` (apt; see
    [ADR-0008](0008-podman-replaces-docker.md)), `powershell` (Microsoft's apt
    repo) and `nvm` (its install script, #435)

## Consequences

### Positive

- One package list and one update command (`brewup`) on a personal Mac and a
  personal Linux machine. New tools reach both by editing one file.
- The per-tool Linux workarounds stop growing on personal machines.

### Negative / trade-offs

- **Size and time.** Homebrew plus the Linux-capable Brewfile is several GB
  and makes the first apply on a personal Linux machine much slower. The
  full-install CI job on Ubuntu now does the same work.
- **Two package managers on one host**, the case ADR-0004 warned about. The
  fzf incident it records happened because apt's stale copy came first on
  `PATH`. Here the order is the other way round: `dot_zshrc` prepends
  `~/.local/bin` first and then evaluates `brew shellenv`, which prepends
  Linuxbrew. So Homebrew wins over both apt (`/usr/bin`) and anything in
  `~/.local/bin`. A machine that ran the older apt-only setup keeps those
  copies on disk, shadowed and harmless; they can be removed by hand.
- A tool added to the Brewfile that has no Linux bottle has to go behind the
  darwin guard.

## Alternatives considered

- **Keep apt and grow the installer list (ADR-0004 as written).** This is what
  produced the gap above. Every tool needs bespoke code and its own update
  story.
- **Homebrew on every Linux tier.** Work and minimal machines value a small,
  fast, native install; the cost isn't worth it there.
- **Nix / home-manager, mise, pkgx.** Rejected in ADR-0004 for the same
  reasons, which still hold.
