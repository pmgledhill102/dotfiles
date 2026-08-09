# ADR-0015: GitHub Issues as the single task tracker

- **Status**: Accepted
- **Date**: 2026-08-05 (records a decision taken and executed 2026-07-18)
- **Supersedes**: [ADR-0011](0011-beads-task-tracking.md) — Beads with
  embedded Dolt for task tracking
- **Tags**: workflow, tooling

## Context

[ADR-0011](0011-beads-task-tracking.md) adopted [beads](https://github.com/steveyegge/beads)
(`bd`) as the primary tracker, on the reasoning that a local-first CLI
tracker survives Claude Code session compaction, costs no round-trips to a
web UI, and keeps issues next to the code. GitHub Issues was explicitly
reserved for "things that need external visibility".

That reasoning had a cost the same ADR named in its own trade-offs: **two
issue trackers**, and no rule that reliably told you which to use. In
practice the split did not hold. Work that started as a local `bd` task
routinely acquired a PR, and the PR is on GitHub — so the discussion, the
review, and the closing reference all ended up on GitHub anyway, with the
`bd` issue as a second record that had to be closed by hand.

Three things shifted the balance further:

- **Agents read and write GitHub Issues directly.** The premise that
  reaching GitHub costs tokens and context switches assumed a web UI. With
  the GitHub MCP server an agent queries, creates, and closes issues in a
  tool call, which is the same shape as running `bd`. The local-first
  advantage narrowed to roughly nothing.
- **This repo is public by design** ([ADR-0014](0014-public-repo-no-private-references.md)).
  Anything an outside contributor files arrives as a GitHub Issue. A
  private local tracker cannot be the canonical list when the canonical
  list has to be readable by people who are not on this machine.
- **The decision was estate-wide, not per-repo.** Beads was being retired
  across every repo (tracked in
  [agentic-coding-config#95](https://github.com/pmgledhill102/agentic-coding-config/issues/95)).
  Keeping one repo on a different tracker would have preserved the exact
  split the migration existed to remove.

## Decision

**GitHub Issues is the single task tracker for this repo.** There is no
second tracker.

- All work is tracked as a GitHub Issue, regardless of whether it
  originated locally or from outside.
- Issues carry a priority label (`P0`–`P4`) and a `type: *` label; the
  taxonomy was bootstrapped during the migration.
- Cross-repo work links by URL rather than being duplicated — an issue
  lives in the repo whose code it changes.
- Durable operational knowledge goes in the docs, not in a tracker's
  memory primitive. `bd remember` had no GitHub equivalent, so the four
  chezmoi-operational memories worth keeping were ported into
  `docs/TROUBLESHOOTING.md`.

Executed in [#339](https://github.com/pmgledhill102/dotfiles/pull/339)
(2026-07-18): 120 beads issues migrated to `#187`–`#306`, all labelled
`beads-import`, with blocked-by relationships preserved; `.beads/` and its
hooks removed; `AGENTS.md` rewritten onto GitHub Issues conventions.

## Consequences

### Positive

- One tracker, so no routing decision and no possibility of two records
  for one piece of work.
- `Closes #n` in a PR body closes the issue natively on merge — no commit
  scanning, and it survives squash-merge.
- Issues, PRs, reviews, and CI all sit in one place with one permission
  model and one search.
- Nothing to install, initialise, or migrate a schema for; no tracker
  hooks in the git hook path.
- Public by default, matching what the repo is.

### Negative / trade-offs

- Network-dependent. No offline triage, and an outage blocks both reading
  and updating.
- No `bd remember` equivalent. Durable knowledge needs a deliberate home
  in the docs and will decay if nobody writes it down.
- No embedded audit trail beyond GitHub's own event log — the Dolt
  history is gone.
- Issue bodies here are public, which is a constraint to hold in mind
  ([ADR-0014](0014-public-repo-no-private-references.md)).

## Alternatives considered

- **Stay on beads** — keeps local-first speed, but leaves the two-tracker
  split that motivated the change, and diverges from every other repo.
- **Beads locally, GitHub Issues as a mirror** — a sync layer to build and
  maintain, with conflicts to resolve; the duplication is the problem, so
  automating it does not remove it.
- **Another external tracker (Linear / Jira)** — rejected in ADR-0011 and
  still rejected: an extra service, away from the code and the PRs.
