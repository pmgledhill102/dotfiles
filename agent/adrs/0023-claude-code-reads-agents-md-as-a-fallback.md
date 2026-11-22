# ADR-0023: Claude Code reads a repo's `AGENTS.md` as a fallback, so the pointer file is optional

- **Status**: Proposed (2026-10-22)
- **Date**: 2026-10-22
- **Supersedes**: in part, [ADR-0019](0019-agents-md-is-the-repo-instruction-source.md)
  — its "Claude Code needs a `CLAUDE.md` pointer" half. Its other half,
  **`AGENTS.md` is the single source of repo-level instructions**, stands
- **Tags**: context, portability, claude-code, codex
- **Scope**: user (applies to all personal repos and agent surfaces)

## Context

ADR-0019 required every repo to carry a `CLAUDE.md` whose job was to import
`AGENTS.md`, because on 2026-09-05 Claude Code did not read a repo-level
`AGENTS.md` on its own. It said the measurement was dated so it could be
re-checked. On 2026-10-14 the owner found a repo with an `AGENTS.md` and no
`CLAUDE.md` whose `AGENTS.md` was loaded as project instructions (Claude Code
2.1.294, workstation), and raised #596. `setup-common` was still generating the
pointer for every new repo and telling agents that Claude Code ignores
`AGENTS.md`.

## What was measured

**Claude Code 2.1.308, cloud sandbox, 2026-10-22.** Throwaway git repos, each
instruction file holding a unique marker string, queried with tools disabled so
the session can only report what was loaded rather than go and read it:

```sh
claude -p --tools "" --no-session-persistence "Without using any tools … does
the literal string <MARKER> appear in a loaded file? If so, under which path?"
```

Every query also asked for a marker that exists nowhere, and every one came
back `NO` — so a `NO` was a reachable answer.

| Case | Files present | Loaded |
| ---- | ------------- | ------ |
| A, F (×2) | `AGENTS.md` only (plus a `README.md` control) | `AGENTS.md`; `README.md` not |
| C | `CLAUDE.md` only | `CLAUDE.md` |
| E (×2) | `AGENTS.md` + `CLAUDE.md`, **no import** | `CLAUDE.md` only — **`AGENTS.md` dropped** |
| B | `AGENTS.md` + `CLAUDE.md` = `@AGENTS.md` + a Claude-only line | both texts, `AGENTS.md` **once** |
| U | `~/.claude/AGENTS.md` beside `~/.claude/CLAUDE.md` | `CLAUDE.md` only |
| G1 | isolated `CLAUDE_CONFIG_DIR` holding only `CLAUDE.md` (control) | that `CLAUDE.md` |
| G2 | isolated `CLAUDE_CONFIG_DIR` holding only `AGENTS.md` | nothing |

The Claude Code binary carries a description of the same behaviour, naming an
`instructionFiles` option whose default, `claude-md-or-agents-md`, is "a
project with no CLAUDE.md of its own gets its AGENTS.md files instead". The
other modes (`claude-md-and-agents-md` loads both, de-duplicating a file
`CLAUDE.md` already imports) were not tested, and this decision does not rely
on them.

Against #596's open questions:

1. **Does the shim load `AGENTS.md` twice?** No. With `CLAUDE.md` importing it,
   `AGENTS.md` is loaded once, through the import (case B). The shim is
   redundant, not costly.
2. **Does a `CLAUDE.md` with Claude-only guidance still load alongside
   `AGENTS.md`?** It loads *instead of* it. `AGENTS.md` is a fallback, read
   only when the repo has no `CLAUDE.md`; a `CLAUDE.md` without the import
   silently drops the shared text (case E). So a repo with Claude-only
   guidance still needs the import.
3. **Is the user-level portable core loaded twice?** Not here. A
   `~/.claude/AGENTS.md` is not loaded at all, beside `CLAUDE.md` or alone
   (cases U, G2). The fallback is project-level only. Delivery already
   matches: Claude profiles compose `CLAUDE.md` alone and no longer ship an
   `AGENTS.md` (#310).
4. **This surface and version.** All of the above is the cloud sandbox on
   2.1.308. The workstation half is the owner's 2026-10-14 run on 2.1.294,
   which established case A only; the session that raised #596 also saw both
   user-level files in context, which case U does not reproduce here.

## Decision

**A repo's instructions live in `AGENTS.md`, and a repo carries a `CLAUDE.md`
only when it has Claude-specific guidance to add.** When it does, that
`CLAUDE.md` imports the shared text:

```markdown
# Claude Code

@AGENTS.md

<Claude-specific guidance, as an addition to AGENTS.md rather than a copy of it>
```

Rules that follow from it:

- **New repos get `AGENTS.md` alone.** `setup-common` stops generating the
  pointer.
- **A `CLAUDE.md` beside an `AGENTS.md` always imports it.** This is the rule
  that inverts. ADR-0019 warned that deleting `CLAUDE.md` makes Claude read
  nothing; the live hazard is now the opposite — *adding* a `CLAUDE.md`
  without the import makes Claude stop reading `AGENTS.md`.
- **A pure pointer `CLAUDE.md` is redundant, not wrong.** It costs no
  context, so existing ones are removed for tidiness, one issue per repo,
  only once this ADR is accepted. ADR-0019's follow-on "convert the remaining
  repos to the import shape" is dropped: a repo whose only file is
  `CLAUDE.md` is moved to `AGENTS.md` alone, not to two files.
- **User level is unchanged.** Claude profiles deliver `CLAUDE.md` only.

## Consequences

**One file for most repos, and it is the vendor-neutral one.** That is the
outcome ADR-0019 wanted, without the second file it had to pay for it.

**The hazard moved somewhere quieter.** Under ADR-0019 a missing pointer was
loud: Claude had no instructions at all. Now a `CLAUDE.md` added later, by a
person or by `claude /init`, drops `AGENTS.md` with no error, and whatever was
in it simply stops applying. The rule above is the only guard; it is worth a
check in the repo audit if it is ever seen in the wild.

**This depends on a Claude Code default, which moved once already.** The
fallback arrived between the 2026-09-05 and 2026-10-14 measurements. If it is
withdrawn, repos with `AGENTS.md` alone lose their instructions on Claude
Code, and the fix is ADR-0019's pointer again. Re-run the table above when
Claude Code's context behaviour changes; that is why it is dated and
versioned.

## References

- [ADR-0019](0019-agents-md-is-the-repo-instruction-source.md) — the decision
  this partly supersedes
- [ADR-0018](0018-composing-agent-context-per-surface.md) — user-level
  composition, and why one policy file per surface
- [#596](https://github.com/pmgledhill102/agentic-coding-config/issues/596) —
  the stale premise; [#310](https://github.com/pmgledhill102/agentic-coding-config/issues/310)
  — retiring the user-level `AGENTS.md` from Claude profiles
