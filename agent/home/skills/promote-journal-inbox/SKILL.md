---
name: promote-journal-inbox
description: 'Drain journal drafts left behind into paul-context journal/: the retro writes entries directly, so this covers its fallback Issues and older drafts. Moves filesystem drafts from _incoming/ and journal-draft-labelled Issues into journal/, commits each, pushes once, then closes the drained Issues with back-links. Use when journal drafts are pending, when start-session reports a non-empty inbox, or when asked to promote journal drafts. Runs from a paul-context checkout on any surface.'
---

# Promote the journal-draft inbox

See `paul-context/decisions/2026-05-05-journal-inbox-promotion.md` for the design rationale.

**This is the drain, not the write path.** The `retrospective` skill writes each entry straight to `journal/` on `main` ([#453](https://github.com/pmgledhill102/agentic-coding-config/issues/453)), so no new entry needs promoting. What is left here is what the direct route could not handle: `journal-draft` Issues from the retro's fallback (a gitleaks finding, a refused write, no network), and drafts filed before #453 shipped. An empty inbox is the expected state.

## Pre-flight

This command **must run inside the `paul-context` working tree.** It commits to that repo; running elsewhere would write into the wrong place. Run the bare commands below and branch on their exit codes — don't paste compound `||` / `&&` forms, which won't match any single allow rule.

```sh
git rev-parse --is-inside-work-tree
basename "$(git rev-parse --show-toplevel)"
```

If the first command's exit code is non-zero (or stdout is not `true`), abort with `/promote-journal-inbox requires a git-backed repo, stopping.` and stop.

If `basename` doesn't match `paul-context`, abort with `promote-journal-inbox must run from a paul-context checkout, not <where>` and stop. The test is the repo, not the path: a clone at any location passes, which is what lets this run in a sandbox as well as on a workstation.

Check the three things that can actually contaminate a journal commit, rather than the whole tree:

```sh
git diff --cached --quiet || echo "staged changes present"
git diff --quiet        || echo "tracked files modified"
git ls-files --others --exclude-standard -- journal/
```

If any of them reports, surface those paths and ask the user to commit or stash before promotion. Otherwise proceed, whatever else is lying around untracked.

**Untracked files outside `journal/` are deliberately not blocking, and that is not an oversight to tidy back into a whole-tree check.** Every stage in this skill names an explicit path — `git add journal/<filename>`, at Phase 1 step 3 and Phase 2 step 5 — and there is no `git add -A`, no `git add .` and no `git commit -a` anywhere in it. So an untracked file elsewhere in the tree cannot reach a journal commit: the old gate blocked on a hazard the rest of the skill already makes impossible. One unrelated untracked note cost a stash, a promotion, a pop, a second stash when `end-session` hit the same tree, and a blocking question to the user with no bearing on the outcome (#419).

What stays blocking, and why each one is a real path into a journal commit:

- **Staged changes.** `git commit` commits the whole index, not just the paths named in the preceding `git add`, so anything staged before this skill ran lands in the first journal commit. This is the true version of the hazard the old gate was aimed at.
- **Tracked-but-modified files.** The same, the moment they are staged.
- **Untracked files inside `journal/`.** One can collide with a draft about to be written there, and the conflict check only tests `journal/<filename>` for the drafts actually being drained.

## Phase 1 — Filesystem inbox drain

### 1. Enumerate `_incoming/`

```sh
ls _incoming/ 2>/dev/null
```

Filter to filenames matching `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+\.md$` and exclude `README.md` (tracked separately). Capture the matching list.

If empty, surface `(no filesystem drafts pending)` and skip to Phase 2.

### 2. For each draft, in deterministic order

For each `<filename>` in the sorted list:

1. **Conflict check**: if `journal/<filename>` already exists, skip. Append to the conflict-list as `<filename> — already in journal/, left in _incoming/`. Continue with the next draft.
2. `mv _incoming/<filename> journal/<filename>` — preserves the filename exactly. Plain `mv` (not `git mv`) because `_incoming/*.md` is gitignored at the repo level — `git mv` refuses to move untracked sources with `fatal: not under version control`. The destination lives under `journal/` (tracked), so step 3 picks it up cleanly.
3. Stage with `git add journal/<filename>`.
4. Derive the commit message slug: strip the leading `<YYYY-MM-DD>-` from `<filename>` and the trailing `.md`. The remainder is `<source-repo-slug>-<topic-slug>`.
5. Commit each draft separately:

   ```sh
   git commit -m "journal: <YYYY-MM-DD> <source-repo-slug>-<topic-slug>"
   ```

   Per-draft commits keep the audit trail clean and let any single entry be reverted without touching others.

## Phase 2 — Issue inbox drain

### 1. Find labeled Issues

List open issues on `pmgledhill102/paul-context` labelled `journal-draft`,
with their number, title, body and creation time.

Prefer `mcp__github__list_issues` (`labels=["journal-draft"]`, `state=OPEN`)
when the MCP server is connected. The `gh` form is the portable fallback, for
sandbox and headless runs where a token is more reliably present than an
interactively-authenticated MCP server:

```sh
gh issue list --repo pmgledhill102/paul-context \
    --label journal-draft --state open --limit 100 \
    --json number,title,body,createdAt
```

If empty, skip to Phase 3.

### 2. For each Issue

For each Issue, in `createdAt` order (oldest first):

1. **Strip prefix**: the title shape is `journal: <YYYY-MM-DD>-<source-repo-slug>-<topic-slug>` (no `.md`). Strip the literal `journal:` prefix (with trailing space). The remainder + `.md` is `<filename>`.
2. **Validate filename**: must match `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+\.md$`. If not, skip with `Issue #N — title doesn't match journal-draft shape, left open` in the conflict-list. Don't try to coerce.
3. **Conflict check**: if `journal/<filename>` already exists, skip with `Issue #N — journal/<filename> already exists, left open` in the conflict-list. Don't close.
4. **Write body**: write the Issue body to `journal/<filename>` with **exactly one trailing newline**. That is the only transformation allowed: paul-context's `end-of-file-fixer` enforces it, and a body that ends in blank lines (or in none, as an Issue body returned by the API often does) cannot be committed there byte-for-byte, so the first commit fails and has to be redone. The body IS the journal markdown — do not fix typos, normalise headings or strip front-matter or metadata. Use the `Write` tool, ending the content with one newline; if the body comes through a shell, `printf '%s\n' "$(cat body)"` does the same, because command substitution drops every trailing newline.
5. **Stage**: `git add journal/<filename>`.
6. **Commit**: `git commit -m "journal: <YYYY-MM-DD> <source-repo-slug>-<topic-slug>"` — date from `<filename>` (already correct), slug from filename per Phase 1.
7. **Capture** Issue `#N` for the close step in Phase 4.

Don't close any Issues yet. Closing happens **after** the push so a failed push doesn't strand drained drafts.

## Phase 3 — Push

If nothing was committed (Phase 1 + Phase 2 both produced zero new commits):

- Surface `(nothing to push)` and skip to Phase 4.

Otherwise, **push where this session is entitled to push.** That is one question, not a surface question, and it has two answers:

**No branch assigned to this session** — you started it, you own the checkout, nothing external decided where your commits go:

```sh
git push origin main
```

This is the direct-push exception the global agent policy names, and it is deliberate rather than sloppy. Promotion is append-only content movement into a single-author private repo with no CI, and the content was authored and approved during the retro that drafted it. A pull request here means reviewing your own journal entry — ceremony, not review, and permanent PR noise on a repo that gets one of these per session.

**A branch has been assigned to this session** — a harness gave you `<branch>` and told you not to push elsewhere:

```sh
git push -u origin <branch>
```

Then open a PR. This is not an exception being waived; it is the ordinary branch-and-PR rule, and it costs almost nothing here because one PR carries every draft this run promoted. **Never push to `main` from a session with an assigned branch** — the instruction not to is not yours to override, and the exception above exists for the case where no such instruction was given.

Either way the commits leave the machine, which is the part that matters: on a disposable container, drafts committed and unpushed are drafts destroyed.

If push fails (rejected, network, hook):

- Surface the error verbatim.
- **Do not** close any Issues. Drafts stay committed locally; the next run will see `journal/<filename>` already exists for those entries and skip them as conflicts (until the user manually resolves by `git push`-ing). The Issues remain open as the source of truth.
- Stop. Don't proceed to Phase 4's close step.

If push succeeds, proceed to Phase 4.

## Phase 4 — Close drained Issues

**Which route Phase 3 took decides this step**, because an Issue must not be closed while its journal entry is still only on a branch.

### If Phase 3 pushed to `main`

The entry is live. For each Issue captured in Phase 2:

1. Add a back-link comment via `mcp__github__add_issue_comment`:

   ```text
   Promoted to paul-context/journal/<filename> (commit <short-sha>). Closing.
   ```

   (Capture the commit sha from `git rev-parse HEAD~<N+offset>` or by walking the recent log — straightforward when each draft is its own commit.)

2. Close the Issue via `mcp__github__issue_write` with `method=update`, `state=closed`, `state_reason=completed`.

If a comment or close fails, surface the failure and continue with the rest. The draft has already been promoted (the journal entry is live on `main`), so a missed close is a recoverable bookkeeping issue — re-running `promote-journal-inbox` will re-enumerate the still-open Issues, find the journal entries already exist, surface them as conflicts, and the user can close manually.

### If Phase 3 pushed to an assigned branch

**Close nothing.** The entry is not on `main` until the PR merges, and an Issue closed before then would strand the draft: closed upstream, absent from `journal/`, and invisible to the next run that would otherwise re-promote it.

Instead:

1. Put `Closes #<n>` in the PR body, once per drained Issue. GitHub closes them on merge, which is the same bookkeeping done by the mechanism that already knows when the entry actually landed.
2. Add the back-link comment as above, but ending `— promoted in #<pr>, closes on merge` rather than `Closing.`

Leaving the Issue open is deliberate and self-correcting: if the PR is never merged, the draft is still discoverable and the next run re-promotes it, which is the outcome you want.

## Phase 5 — Summary

Print a tight wrap-up:

```text
/promote-journal-inbox complete.

  Filesystem drafts drained: <N>
  Issue drafts drained:      <N>
  Conflicts (skipped):       <N>
<for each conflict>:
    - <filename or Issue ref> — <reason>

  Pushed: <main | <branch> + PR #<n> | no | n/a>
  Closed Issues: <count> — <list of #N or "(none)">
```

Surface the conflict list explicitly so it's obvious what didn't move and why.

## Guardrails

- **Never overwrite** an existing `journal/<file>.md`. Skip + surface. Manual resolution lives with the user.
- **Per-draft commits**, single batched push. Each entry is its own commit — clean audit trail, easy revert. The single push at end keeps remote round-trips down and makes the close-Issues precondition simple.
- **Close-Issues happens AFTER push, and only on the `main` route.** If push fails, drafts stay committed locally but upstream Issues remain open — the next run handles the recovery cleanly via the conflict path. On the assigned-branch route nothing is closed here at all; `Closes #<n>` in the PR body does it on merge, when the entry actually reaches `main`.
- **No retries on network failures.** Surface and stop. The user drives the retry.
- **No body transformation on Issue drafts, beyond one trailing newline.** What the Issue body says is what lands in `journal/`, ending in exactly one newline (the repo's `end-of-file-fixer` requires it, and normalising at promote time is the fix that holds). Don't try to fix typos, normalise headings, or strip metadata — that's manual editing, not promotion.
- **Don't `cd` away from `paul-context`** during the run. Every git operation should target the same working tree the pre-flight validated.
