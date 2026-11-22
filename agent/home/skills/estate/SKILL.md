---
name: estate
description: 'Survey open work across every repo in the estate in one read-only pass, then recommend where to spend focused time: issue and PR counts per repo, P0/P1 listed individually, Dependabot separated from human PRs, and one flag per repo ordered so the top of the table is what needs attention. Use when deciding what to pick up next, when asking which repo is in the worst shape, or for a periodic review of the whole estate.'
---

# Survey the estate's open work

```sh
~/.claude/bin/estate-report
```

That is the whole gathering step. The script enumerates the estate, reads every
repo's open issues and PRs, derives the flags and renders the table. **Do not
re-derive any of it by hand** — the thresholds are arithmetic, they are tested
in `tests/estate-report-test.sh`, and a second opinion computed in conversation
is just an unverified copy that will disagree eventually.

Your job starts where the table ends: saying which repo to open, and why.

## What this skill is for, and what it is not

| Question | Owner |
| --- | --- |
| Is the estate configured correctly? | `paul-context/tools/repo-audit.sh` |
| What has rotted inside *this* repo? | `repo-review` |
| What are the workable units in this backlog? | `bundle-issues` |
| **Where is the work, across everything?** | **here** |

The division worth remembering: **this skill says which repo to open;
`bundle-issues` says what to do once you are in there.** Resist adding a
settings check — `repo-audit.sh` owns that, and two answers to one question
drift apart silently.

## The output is evidence — never commit it, never paste it

This repo is public. The script and this file are **method** and stay public.
A run's output is **evidence**: it names private repos and what is wrong in
them. That is the estate's standing standard-public / evidence-private line.

The specific failure to avoid: a run looks good, so it gets pasted into this
file as "example output", or into an issue as context — and now a public repo
carries an estate inventory. **Any example here uses invented repo names.**
Keep real output in the session or a scratch directory.

## Reading the table

Counts tell you where the **volume** is. Flags tell you where the **pain** is,
and only the flags are ordered. A repo gets at most one, most severe first, and
the table sorts by it — so the top few rows are the answer.

| Flag | What it actually means | Usual response |
| --- | --- | --- |
| `P0` | Something is broken now | Open it today |
| `blocked` | A human PR is sitting unreviewed | Review it, or chase the reviewer — the owner merges, and an agent only when asked |
| `automation` | Dependabot has stopped landing | **One config bug, not N pieces of work.** Check `AUTOMERGE_PAT` and required checks — `repo-review` F3 |
| `stalled` | Real priority, no recent commits | Decide honestly: pick it up, or drop the priority |
| `untriaged` | Issues arriving faster than they are labelled | A `bundle-issues` session, not a fix |
| *(blank)* | Open work, nothing overdue | **Nothing.** This is healthy |
| `quiet` | No open work | Confirm it is genuinely done |

Two readings that are easy to get wrong:

- **A large backlog is not a problem.** An actively-worked repo with eighty
  open issues and no flag is in better shape than a six-issue repo flagged
  `stalled`. The flags exist precisely so volume alone cannot raise an alarm;
  do not reintroduce that by editorialising about the biggest number.
- **`automation` is one bug.** Twelve Dependabot PRs is a single broken gate,
  not twelve tasks. Counting it as backlog inflates the repo's apparent load
  and points the day at the wrong work.

## Whole-estate runs need a workstation; scoped runs work anywhere

An agent sandbox **binds a session to its configured repositories** and refuses
every GitHub path reaching wider — `/user/repos` and
`/installation/repositories` both 403. That refusal sits upstream of the
credential, so **no token at any scope changes it**, and the session's identity
still resolves fine. If a run here exits 2 saying so, that is the binding, not
a permissions problem to solve.

So:

- **Whole estate** — run on the workstation, where enumeration works.
- **Scoped** — `--repos a,b,c` over the repos a session actually has. This is a
  **supported mode, not a consolation prize**: a cloud session with four or
  five deliberately chosen repos gives a real report over them, and the flags
  mean exactly what they always mean.

A scoped run labels itself, and that label is the point:

```text
estate — 4 repos, as of 2026-09-20T10:08Z  (SCOPED: --repos, not the whole estate)
```

**Never present a scoped table as the estate.** Without that marker a report
omitting thirty-five repos reads exactly like one omitting none — nothing in it
looks wrong, which is what makes it worse than an error. `--json` carries the
same `scoped` field for the same reason. When summarising a scoped run, say
which repos it covered.

## Some repos are excluded, and the report says so

`lifeos` and `lifeos-sandbox` keep a personal to-do list in Issues rather than
engineering work, so the script excludes them by default. Counted as backlog
they would arrive large and permanently `untriaged` — life tasks will never
carry `P0`–`P4` labels — and outrank real work on volume, which teaches you to
stop reading the top of the table.

Every run prints what it left out:

```text
excluded (2): lifeos, lifeos-sandbox
```

**Read that line rather than skipping it.** An exclusion nobody sees is a blind
spot nobody can audit, and unlike an unreachable repo it never comes back on
its own. `--exclude a,b` extends the list for one run; `--repos` overrides it
entirely, which is how you deliberately look at an excluded repo.

## The numbers are an as-of, not a reconciliation

Sessions run in parallel on this estate, so the backlog genuinely moves during
a run — counts taken minutes apart will differ by real closes. The header
carries the run time for that reason.

This is fine for choosing where to spend a day and wrong for anything that
needs to balance. If two figures disagree, the cause is concurrent work until
proven otherwise; "the platform is broken" is the last hypothesis, not the
first.

## Finish with a recommendation

The table is evidence, not an answer. Close with two or three sentences naming
where you would spend the time and what you would do first. If the top rows
disagree with what the user already planned, say so plainly — that is the
whole reason to run it.

Where nothing is flagged, say that too. "Nothing needs attention, here is what
I would pick up anyway" is a useful answer and a common one.

## When it cannot run

The script exits non-zero and says why. Relay the reason; **never substitute a
partial view for a clean one**.

- **Exit 1, no token** — needs `GH_TOKEN`, `GITHUB_TOKEN`, or `gh auth login`.
- **Exit 2, session bound to its configured repositories** — see the section
  above. Not a credential problem; do not go looking for a better token.
- **Exit 2, everything was excluded** — a distinct message, so nobody debugs
  credentials over a list they wrote themselves.
- **`not checked` lines** — those repos are **unknown, not clean**. Say so when
  summarising. A repo dropped silently is indistinguishable from a healthy one,
  which is the exact failure the report exists to catch.

Where the script genuinely cannot run but GitHub is reachable through MCP
tools, `mcp__github__list_issues` and `mcp__github__list_pull_requests` can
answer a single repo's shape by hand. Do not attempt the full estate that way:
forty repos of issue JSON through a conversation is what the script exists to
avoid, and hand-tallied flags are exactly the drift it exists to prevent.
