# ADR-0009: Helper shell functions for daily dotfiles workflow

- **Status**: Accepted
- **Date**: 2026-04-26 (amended 2026-07-19: naming rule made explicit,
  `dotclaude` → `claudeup`, `xcodeup` added, `dotbrew` alias removed)
- **Note**: deprecation aliases are only warranted for everyday commands.
  `dotbrew` got one because `brewup` runs constantly; `dotclaude` did not,
  because it runs once per machine build.
- **Tags**: shell, dx

## Context

Routine maintenance of a chezmoi-managed dotfiles environment involves
several multi-step incantations that nobody remembers off the top of
their head:

- Pull the latest dotfiles, refresh Oh My Zsh and its plugins, update
  Starship, reload functions in the current shell.
- Update Homebrew, install everything declared in the Brewfile, then
  upgrade.
- Configure Claude Code MCP servers with the right credentials.
- Show the current machine type, source path, last applied date, and any
  pending diff.

Without first-class commands, each task is a copy-paste from a wiki
somewhere. The previous repo had only a few ad-hoc helpers (e.g.
`test_posh()`) and no unifying convention.

## Decision

Define a small set of zsh functions, one per file, under
`home/dot_config/zsh/functions/`, autoloaded by the shell.

Naming follows one rule, by scope of effect:

- **`dot*`** — acts on the dotfiles/chezmoi system itself
  (`dotup`, `dotstatus`, `dotfuncs`).
- **`<tool>up`** — brings a specific third-party tool current on this
  machine (`brewup`, `claudeup`, `xcodeup`).

The original set used `dot*` for everything, which made the prefix a
vanity namespace rather than a meaningful signal: `dotbrew` never
touched dotfiles, it managed Homebrew. Renaming it to `brewup`
established the split above, and `dotclaude` → `claudeup` completes it.

| Function | Purpose |
| -------- | ------- |
| `dotup` | Pull dotfiles, refresh Oh My Zsh + plugins, update Starship (Linux), reload aliases/functions in the current shell. |
| `brewup` | `brew update` + `brew bundle install` against `~/Brewfile` + `brew upgrade` + `rustup update` (rust toolchain isn't in the Brewfile but is a package-manager update). |
| `claudeup` | Interactive Claude Code MCP server setup (GitHub MCP from `gh` token, Google Developer Knowledge from Bitwarden). (Was `dotclaude`; renamed outright with no deprecation alias — it runs once per machine build, so there is no muscle memory to protect.) |
| `xcodeup` | macOS only. Install/update the latest Xcode via `xcodes`, select the toolchain, and report simulator runtime status. Interactive — Apple ID sign-in cannot be automated. |
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
- The prefix now carries meaning: `dot*` signals "touches my dotfiles",
  `<tool>up` signals "touches that tool" — readable without the docs.

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
