# ADR-0012: Claude Code configuration shipped via the dotfiles repo

- **Status**: Superseded — see note at end. Original status: Accepted (2026-04-26).
- **Date**: 2026-04-26
- **Tags**: claude-code, tooling
- **Scope**: user (applies to all personal repos and agent surfaces)

> **Why the numbering starts at 0012.** This directory continues the
> sequence begun in `pmgledhill102/dotfiles`, where the first eleven ADRs
> live. `dotfiles` has since grown its own 0015, so a bare "ADR-0015" is
> ambiguous across the two homes — **cross-repo references should use full
> URLs**, as [ADR-0015](0015-tiered-adrs.md) requires for cross-tier links.

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

---

## 2026-05-03 update — superseded by the agentic-coding-config split

The "separate `claude-config` repo" alternative — rejected here in April
on the grounds of losing the "one repo, one apply" property — was
revisited and adopted on 2026-05-03 as `agentic-coding-config`.

**Why the reversal:** chezmoi externals close the gap that this ADR was
worried about. Externals let chezmoi treat a remote git repo as part of
the source state, so `chezmoi apply` (and therefore `dotup`) still
populates `~/.claude/` from a single command — the "one apply" property
is preserved. The cost calculation that made this ADR reject a split
assumed manual two-step coordination; with externals, that cost
disappears.

**What's different now:** the agentic config has its own iteration cadence
(retro-driven, fast) that doesn't benefit from the dotfiles cross-platform
install matrix. Splitting reduces friction on edits without breaking the
single-`apply` guarantee.

This ADR is preserved for historical context; the operational reality from
2026-05-03 onward is that the content described here lives in
`agentic-coding-config` (this repo), wired into dotfiles via a
`.chezmoiexternal.toml.tmpl` declaration. The decision record for the
split itself lives in the private `paul-context` repo's `decisions/`
folder.
