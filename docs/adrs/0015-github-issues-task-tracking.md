# ADR-0015: GitHub Issues as the single task tracker

- **Status**: Accepted
- **Date**: 2026-08-05 (records a decision taken 2026-07-14 and executed
  here 2026-07-18)
- **Supersedes**: [ADR-0011](0011-beads-task-tracking.md) — Beads with
  embedded Dolt for task tracking
- **Tags**: workflow, tooling

## Context

[ADR-0011](0011-beads-task-tracking.md) adopted
[beads](https://github.com/steveyegge/beads) (`bd`) as the primary tracker
here, keeping GitHub Issues for "things that need external visibility".

The decision to replace it was estate-wide rather than local to this repo,
and the full rationale — including the research comparing GitHub Issues,
Backlog.md, Linear, beads_rust and git-bug — lives upstream in
[agentic-coding-config ADR-0013](https://github.com/pmgledhill102/agentic-coding-config/blob/main/adrs/0013-github-issues-for-work-tracking.md).
This ADR records the consequence for this repo and closes out ADR-0011; it
does not restate that reasoning, so that the two records cannot drift.

The short version of why: beads' weight was disproportionate for a solo
project — a large binary, an embedded Dolt database per repo, schema
migrations needing a designated migrator machine, git hooks that conflict
with the pre-commit framework, and sync failures that block work. Beads'
sweet spot is fleets of parallel agents; this estate is one human and one
agent. Meanwhile GitHub had shipped the pieces it previously lacked —
sub-issues, native blocked-by dependencies, and `gh` CLI support for both.

ADR-0011's own trade-offs section had already named the local cost: **two
issue trackers**, with no rule that reliably said which to use. In practice
the split did not hold, because work that started as a `bd` task acquired a
PR, and the PR is on GitHub regardless.

## Decision

**GitHub Issues is the single task tracker for this repo.** There is no
second tracker.

Conventions are the estate-wide ones from
[docs/github-issues-workflow.md](https://github.com/pmgledhill102/agentic-coding-config/blob/main/docs/github-issues-workflow.md):
sub-issues for epic → feature → task, `P0`–`P4` priority labels,
`type: *` labels, and native blocked-by relationships. Agents use
`gh issue list` and direct reads rather than the eventually consistent
search API for anything time-sensitive.

Executed here in [#339](https://github.com/pmgledhill102/dotfiles/pull/339)
(2026-07-18): 120 beads issues migrated to `#187`–`#306`, all labelled
`beads-import`, blocked-by relationships preserved; `.beads/` and its hooks
removed; `AGENTS.md` rewritten onto GitHub Issues conventions.

`bd remember` has no GitHub equivalent, so durable operational knowledge
moved into the docs — four chezmoi memories were ported into
[`docs/TROUBLESHOOTING.md`](../TROUBLESHOOTING.md) as part of that PR, and
that file is now where such knowledge belongs.

## Consequences

### Positive

- One tracker, so no routing decision and no second record to close by hand.
- `Closes #n` in a PR body closes the issue natively on merge, and survives
  squash-merge — beads needed commit scanning for this.
- Issues, PRs, reviews and CI share one place, one permission model, one
  search.
- No tracker binary, database, schema migration or git hook in the path.
  The `bd-push-safe` shim that existed solely to work around beads' hooks
  is gone.

### Negative / trade-offs

- Network-dependent; no offline triage. Accepted — offline operation was
  never a requirement.
- Ticket data is no longer cloned with the repo. The issue timeline is a
  stronger history than beads kept, but it lives in GitHub.
- No memory primitive. Durable knowledge needs a deliberate home in the
  docs and will decay if nobody writes it down.
- Issue bodies here are public, which is a constraint to hold in mind when
  writing them ([ADR-0014](0014-public-repo-no-private-references.md)).

## Alternatives considered

Evaluated upstream rather than here — see
[agentic-coding-config ADR-0013](https://github.com/pmgledhill102/agentic-coding-config/blob/main/adrs/0013-github-issues-for-work-tracking.md)
for the comparison against Backlog.md, Linear, beads_rust and git-bug, and
for why staying on beads was rejected.

Note that `beads` remains installed via the personal Brewfile. It is no
longer used for tracking in this estate, but it is deliberately kept
available.
