# ADR-0011: Beads with embedded Dolt for task tracking

- **Status**: Accepted
- **Date**: 2026-04-26
- **Tags**: workflow, tooling

## Context

The repo needs a per-project task tracker that:

- Survives Claude Code session compaction so context isn't lost across
  sessions.
- Is fast and CLI-driven, so AI agents and humans can both use it without
  context switches into a web UI.
- Stays close to the code — issues, decisions, and persistent memories
  belong with the repo, not in a third-party service.
- Has a real audit trail.

GitHub Issues fits inbound bug reports from external contributors but is
heavy for the rapid local task churn an AI agent generates, and round-trips
to the GitHub UI cost tokens and time.

## Decision

Use [beads](https://github.com/steveyegge/beads) (`bd`) as the primary
task tracker for this repo, with embedded Dolt as the storage backend.

- All routine task tracking goes through `bd`: `bd create`, `bd ready`,
  `bd update`, `bd close`, `bd remember`.
- Persistent memories are written via `bd remember` and survive
  compaction / new sessions.
- Storage is embedded Dolt (no remote server required), with optional
  push via `bd dolt push`.
- Beads installs and manages its own pre-commit / pre-push hooks; the
  generic `~/.git-templates/` library does not call `bd` directly
  (decoupled in beads `dotfiles-gum` / PR #153).
- GitHub Issues is reserved for things that need external visibility —
  bug reports, RFCs, public contributor coordination.

## Consequences

### Positive

- Local-first, fast, agent-friendly CLI.
- Persistent memories and full task history survive Claude Code session
  boundaries.
- Dolt history preserves an audit trail that ordinary markdown TODO
  files cannot.
- One install across all repos via the Brewfile.

### Negative / trade-offs

- Embedded Dolt deadlocks during `bd init` on macOS without GNU
  coreutils, because `bd`'s installed pre-commit hook lacks `timeout`
  to break the lock. Workaround: install `coreutils` or rely on the
  `/bd-modernize` skill, which now handles the case.
- Two issue trackers (beads + GitHub Issues) means contributors must
  know which to use for which kind of task.
- Beads is a relatively young project; upgrades occasionally require
  schema migrations.

## Alternatives considered

- **GitHub Issues only** — loses local-first, costs tokens to use, no
  persistent-memory primitive.
- **Plain markdown TODO files** — no schema, no queries, doesn't survive
  refactors.
- **Linear / Jira** — external service dependency, web UI overhead;
  appropriate for teams, not a personal repo.
- **Just `git log`** — no structure, no open/closed state, no
  dependencies between issues.
