# ADR-0019: `AGENTS.md` is the source of repo-level agent instructions

- **Status**: Accepted (2026-09-05); **partially superseded by
  [ADR-0023](0023-claude-code-reads-agents-md-as-a-fallback.md)** (proposed
  2026-10-22)
- **Date**: 2026-09-05
- **Tags**: context, portability, claude-code, codex, skills
- **Scope**: user (applies to all personal repos and agent surfaces)

> **What still holds, and what does not.** `AGENTS.md` is the single source of
> repo-level instructions: still in force. The requirement that every repo
> also carry a `CLAUDE.md` pointer is superseded. Claude Code now reads a
> repo's `AGENTS.md` itself when the repo has no `CLAUDE.md`, so the
> measurement below, the "`CLAUDE.md` is never deleted" rule and the "convert
> the remaining repos" follow-on no longer apply. Where a `CLAUDE.md` exists
> it must still import `AGENTS.md`. The text below is left as recorded.

## Context

[ADR-0018](0018-composing-agent-context-per-surface.md) made **user-level**
policy vendor-neutral by construction: `home/AGENTS.md` and `home/CLAUDE.md`
are composed from the same fragments, so neither can drift from the other.

**Repo-level** instructions had no equivalent, and there is no composer
available inside an arbitrary repo. Removing three redundant `AGENTS.md` files
(#384) was right on its own terms — the content was duplicated, and measured on
2026-09-05 the `AGENTS.md` copies were **not loaded at all** — but taken alone
it would have left every repo's genuinely repo-specific guidance in `CLAUDE.md`
only, which is Claude-only.

That is not boilerplate being lost. `paul-context`'s file carries the offline
test commands and the two-stage sweep invocation; `paul-gledhill-dev`'s carries
tone and voice guidance for a personal site. A Codex or OpenCode session would
write with no idea of either. It also quietly undoes the reason `.agent-policy`
and Beads were dropped, which was to move to an industry-standard, agnostic way
of working.

## What was actually measured

Two separate facts, established rather than assumed, because the answer decides
which options are even available.

**Claude Code does not read a repo-level `AGENTS.md` on its own.** Measured
2026-09-05 in a session where the file was present: both `CLAUDE.md` files
reached the context window and neither `AGENTS.md` did.

**Claude Code does follow an `@AGENTS.md` import from `CLAUDE.md`.** Confirmed
live on 2026-09-05 in a `paul-context` session: that repo's `CLAUDE.md` is a
short pointer whose second line is `@AGENTS.md`, and the session's context
contained the full text of `AGENTS.md`, labelled as project instructions
checked into the codebase.

The two together are what make the decision cheap. Naive option 1 — "put the
content in `AGENTS.md` and hope Claude reads it" — does not work. The **import**
form of option 1 does, and it costs one short file rather than a second copy of
the text.

## Options

1. **`AGENTS.md` is the source; `CLAUDE.md` imports it with `@AGENTS.md`.**
   One text, two entry points. Vendor-neutral by default.
2. **Duplicate, and test that the copies match.** Honest about the duplication
   and makes drift loud, but it is still two copies of every instruction, and
   the test can only run where both files are visible to it.
3. **Leave it.** Cheapest, defensible while the estate is single-user, and
   quietly Claude-only.

## Decision

**Option 1. `AGENTS.md` is the source of repo-level agent instructions.
`CLAUDE.md` is a short pointer that imports it.**

```markdown
# Claude Code

@AGENTS.md

This repository's agent instructions live in [`AGENTS.md`](AGENTS.md) — the
cross-vendor convention that Codex and other coding agents read. Claude Code
reads `CLAUDE.md` and **not** `AGENTS.md`, so this file imports it.

<!-- Claude-specific guidance, if any, goes below this line. -->
```

Rules that follow from it:

- **Instructions are written in `AGENTS.md`, never in `CLAUDE.md`.** A repo
  needing Claude-specific guidance adds it *below* the import, as an addition
  to the shared text rather than a competing copy of it.
- **`CLAUDE.md` is never deleted in favour of `AGENTS.md` alone.** Without it
  Claude Code reads nothing, which is the failure mode this ADR exists to
  avoid.
- **No duplication test is needed**, because there is no duplication. That is
  the substantive advantage over option 2: drift is not detected, it is made
  impossible.

## Consequences

**Adopted where it has been applied.** As of 2026-09-05, three repos —
`paul-context`, `paul-gledhill-dev`, `gtd-private` — carry the import shape,
and it is the shape that was verified working above.

**Eleven repos still carry two divergent texts**, including this one. That is
pre-existing drift rather than a regression, and this ADR is what makes it
reportable: a repo whose `CLAUDE.md` is not a pointer now differs from a
recorded decision instead of merely differing from its neighbours. Converting
them is follow-on work, not a precondition — an instruction file is read, not
executed, so a stale one is a documentation defect rather than a broken build.

**The `@` import is a Claude Code feature, and this ADR depends on it.** If it
is ever withdrawn, the fallback is option 2 with a test, not option 3. Worth
re-confirming when Claude Code's context behaviour changes, since this is
exactly the kind of thing that moves between releases — which is why the
measurement above is dated and says what was observed rather than what is
believed.

**Nothing changes for a non-Claude agent.** `AGENTS.md` is where it already
looks, and now finds the whole text rather than a redundant subset.

## Follow-on work

- Convert the remaining repos to the import shape, one PR each
- `setup-common` generates both files in this shape for a new repo

## References

- [ADR-0018](0018-composing-agent-context-per-surface.md) — the same problem
  solved one level up, by composition
- #389 — the issue that raised it; #384 — the deletion half that surfaced it
