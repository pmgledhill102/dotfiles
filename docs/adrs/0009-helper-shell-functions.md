# ADR-0009: Helper shell functions for daily dotfiles workflow

- **Status**: Accepted
- **Date**: 2026-04-26
- **Tags**: shell, dx

## Context

Routine maintenance of a chezmoi-managed dotfiles environment involves
several multi-step incantations that nobody remembers off the top of
their head:

- Pull the latest dotfiles, refresh Oh My Zsh and its plugins, update
  Starship and Rust, reload functions in the current shell.
- Update Homebrew, install everything declared in the Brewfile, then
  upgrade.
- Configure Claude Code MCP servers with the right credentials.
- Show the current machine type, source path, last applied date, and any
  pending diff.

Without first-class commands, each task is a copy-paste from a wiki
somewhere. The previous repo had only a few ad-hoc helpers (e.g.
`test_posh()`) and no unifying convention.

## Decision

Define a small set of `dot*` and `note*` zsh functions, one per file,
under `home/dot_config/zsh/functions/`, autoloaded by the shell.

| Function | Purpose |
| -------- | ------- |
| `dotup` | Pull dotfiles, refresh Oh My Zsh + plugins, update Starship (Linux) + Rust toolchain, reload aliases/functions in the current shell. |
| `dotbrew` | `brew update` + `brew bundle install` against `~/Brewfile` + `brew upgrade`. |
| `dotclaude` | Interactive Claude Code MCP server setup (GitHub MCP from `gh` token, Google Developer Knowledge from Bitwarden). |
| `dotstatus` | Print machine type, chezmoi source path, last applied time, and any pending diff. |
| `dotfuncs` | List every custom function with its one-line description (self-documenting). |
| `note` / `n` | Append a timestamped bullet to `~/notes/<project>.md` (project = git repo basename or cwd basename). `note -e` opens it in `$EDITOR`. |
| `notes` | List all note files, or grep across them. |

Each function lives in its own file so it can be read, tested, and
reloaded individually. `dotfuncs` is the entry point for discovery.

## Consequences

### Positive

- Memorable, short commands replace multi-step incantations.
- One file per function keeps the shell config tidy and easy to lint.
- `dotfuncs` keeps the helper set discoverable without external docs.
- The `dot*` prefix makes them easy to grep and to tab-complete.

### Negative / trade-offs

- Zsh-only — Windows PowerShell does not have equivalents yet
  (beads `dotfiles-lpn` tracks the gap).
- Discoverability still depends on running `dotfuncs`; no man pages.
- Any addition is one more thing to keep working across `dotup` chains.

## Alternatives considered

- **Aliases only** — fine for one-liners, no good for multi-step logic
  with conditional fallbacks.
- **Make targets** — assumes a fixed cwd; awkward for shell-state
  operations like reloading functions.
- **Standalone scripts on `PATH`** — fragments the helpers across the
  filesystem; loses the shared autoload directory.
