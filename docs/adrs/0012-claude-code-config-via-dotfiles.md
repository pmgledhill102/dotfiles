# ADR-0012: Claude Code configuration shipped via the dotfiles repo

- **Status**: Accepted
- **Date**: 2026-04-26
- **Tags**: claude-code, tooling

## Context

Claude Code's user-level configuration (`~/.claude/`) defines the
permission allowlist, hooks, slash commands, MCP server setup, and
universal policy that should apply to *every* repo on this machine.

Hand-editing `~/.claude/` per machine causes drift: a slash command added
on one laptop is missing on the next. Reproducing the setup manually on a
fresh machine is brittle and undocumented.

## Decision

Treat `home/dot_claude/` in the dotfiles repo as the source of truth for
`~/.claude/` on every machine.

- `home/dot_claude/settings.json` carries the permission allowlist, hooks,
  and other harness-level config.
- `home/dot_claude/settings.json.md` is the annotated companion. JSON
  doesn't allow comments, so the `.md` file documents groupings and
  rationale. The two files **must be edited together** — that constraint
  is recorded in `CLAUDE.md`.
- `home/dot_claude/CLAUDE.md.tmpl` ships universal policy.
- `home/dot_claude/commands/` contains the slash command library
  (`/setup-*`, `/repo-review`, `/end-session`, `/retrospective`,
  `/start-session`, etc.).
- `home/run_onchange_setup-claude.sh` configures MCP servers
  (currently the GitHub MCP and Google Developer Knowledge MCP), reading
  credentials from Bitwarden or the configured secrets path. It degrades
  gracefully if the `claude` CLI or credentials are absent.

## Consequences

### Positive

- One PR updates Claude Code config on every machine after `dotup`.
- Slash commands are composable (`/setup-common` + `/setup-python` + …).
- MCP setup degrades gracefully when prerequisites are missing.
- Per-repo overrides remain possible via local `.claude/settings.json`
  files; the user-level config is the baseline.

### Negative / trade-offs

- `~/.claude/` becomes effectively read-only — hand-edits get clobbered
  by the next `chezmoi apply`. Iterating on settings means editing the
  source repo, not `~/.claude/` directly.
- `settings.json` and `settings.json.md` have to be kept in sync by
  hand; a divergence is silently allowed by the file system.
- Slash commands and hooks are versioned with the dotfiles repo, so
  rolling back requires a dotfiles revert.

## Alternatives considered

- **Hand-maintain `~/.claude/` per machine** — what we left behind;
  drift is the dominant failure mode.
- **A separate `claude-config` repo** — adds another repo to clone, sync,
  and PR against; loses the "one repo, one apply" property.
- **Per-project `.claude/settings.json` only** — fine for repo-specific
  overrides, but every machine still needs a baseline.
