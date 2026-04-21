End-of-session tidy-up: leave git, GitHub, beads, and Claude Code state at a verifiable "clean walk-away" point, then optionally run the retrospective.

This command runs in two phases. Phase 1 is the tidy-up (mix of auto-actions and confirmations). Phase 2 is a prompt to kick off the retrospective. The retrospective itself is read-only — it only updates `~/.claude/retros.md` — so all repo-state changes must happen in Phase 1.

## Action tiers

Every step in Phase 1 falls into one of three tiers — keep this in mind when adding or editing steps:

- **Tier 1 — auto-act, no prompt**: safe, reversible, expected. Examples: `git fetch --prune`, `git pull --rebase`, `bd dolt push`, `bd preflight`, read-only surface listings.
- **Tier 2 — auto-act behind one batched confirmation**: destructive but predictable, judgment is yes/no for the whole list. Examples: deleting merged branches, deleting squash-merged branches, pushing `main` if ahead.
- **Tier 3 — surface only, user drives**: needs per-item judgment, or affects shared state in ways one y/n can't capture. Examples: open PRs awaiting merge, `bd in_progress` issues, stashes, user-started background processes.

When in doubt, downgrade a tier (Tier 1 → 2, or 2 → 3). Never upgrade silently.

## Pre-flight

This command **requires a git-backed repository**. If the current directory is not inside a git work tree, print a single-line warning ("`/end-session` requires a git-backed repo — nothing to tidy, stopping.") and exit. Do not run any further checks, do not proceed to Phase 2.

```sh
git rev-parse --is-inside-work-tree 2>/dev/null || { echo "not a git repo"; exit 1; }
```

## Phase 1 — Tidy-up

### 1. Gather state (read-only)

Run as a single shell block so the full picture lands in one output:

```sh
echo "===pwd==="; pwd
echo "===current branch==="; git branch --show-current
echo "===status==="; git status --porcelain=v1 --branch
echo "===origin==="; git remote get-url origin 2>&1
echo "===main branch name==="; git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
echo "===unpushed commits on current branch==="; git log @{u}..HEAD --oneline 2>&1 | head -20
echo "===beads workspace==="; [ -f .beads/metadata.json ] && echo "yes" || echo "no"
```

### 2. Fetch and prune remote-tracking refs (Tier 1)

```sh
git fetch --all --prune --tags
```

### 3. Check `main` CI status (Tier 1 — surface)

If `gh` is available and the repo has a remote:

```sh
gh run list --branch main --limit 10 --json status,conclusion,name,headSha,createdAt,url 2>/dev/null
```

Parse the most recent run per workflow:

- **Failed**: flag loudly with workflow name + URL. A red `main` is the loudest "not clean" signal.
- **In progress**: list with elapsed time. Means a deploy / long check is mid-flight.
- **All green**: silent.

If `gh` isn't installed or there's no remote, skip silently. Carry the result forward — it gates the Phase 2 prompt.

### 4. Handle uncommitted or unpushed work (Tier 3)

Before any branch switching or deletion:

- **Dirty working tree** (uncommitted changes in `git status --porcelain`): stop, show the user what's dirty, ask whether to (a) commit, (b) stash, or (c) abort the tidy-up. Do **not** silently stash.
- **Current branch has unpushed commits** and isn't `main`: surface this — ask whether to push (create PR if needed) or abort. Don't switch away from a branch with unpushed work without explicit permission.

### 5. Return to main and rebase (Tier 1)

If not already on `main` (or whatever the repo's default branch is):

```sh
git checkout main
git pull --rebase origin main
```

If the rebase fails (conflicts, divergent history), stop and surface the error — don't attempt `--abort` or destructive recovery without asking.

### 6. Prune obsolete local branches (Tier 2 — two batches, each prompted once)

Two batches. Present each list, ask **one** y/n per batch, then act on the whole list. Never iterate per-branch.

**Batch A — Branches fully merged into `origin/main`** (safe, uses `-d`):

```sh
git branch --merged origin/main --format='%(refname:short)' \
  | grep -vE '^(main|master|HEAD)$'
```

**Batch B — Squash-merged branches** — branches whose upstream was deleted (`[upstream: gone]`, typical after GitHub squash-merge + branch delete) AND whose tree is identical to `main`. These won't show up in Batch A because squash-merging rewrites history; `-d` would refuse them. The empty-diff check is the safety net — if it passes, the content is already on `main` and `-D` is safe:

```sh
git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads/ \
  | awk '$2 ~ /gone/ { print $1 }' \
  | grep -vE '^(main|master)$' \
  | while read -r branch; do
      git diff --quiet main.."$branch" 2>/dev/null && echo "$branch"
    done
```

For each batch:

- If empty, say so and move on.
- Otherwise present the full list and ask once: "delete all of these? (y/n)".
- On `y`: `-d` for Batch A, `-D` for Batch B.

If a `[gone]` branch has a non-empty diff vs `main`, surface it by name ("`feat/x` — upstream gone but diffs against `main`, left alone") so the user can decide manually. Don't roll it into Batch B.

For remote-tracking refs, `git fetch --prune` in step 2 already handled stale `origin/*` refs. Don't delete anything on the remote itself.

### 7. Push main if ahead (Tier 2)

```sh
git log origin/main..HEAD --oneline
```

If main is ahead of origin/main (shouldn't normally happen, but catches the case where commits landed locally), ask before pushing.

### 8. Open PRs needing your action (Tier 3 — surface only)

For PRs you authored (open). Prefer `mcp__github__list_pull_requests` (state=open, head filter); fall back to:

```sh
gh pr list --author @me --state open --json number,title,isDraft,mergeable,statusCheckRollup,reviewDecision,url
```

Categorise and present:

- **Mergeable, CI green, approved/no-review-needed** → "ready to merge in UI"
- **Mergeable, CI green, awaiting review** → "waiting on reviewer"
- **CI failed** → list with link to the failing run
- **Merge conflict** → list with PR URL
- **Draft** → list separately

Never auto-merge. List, link, move on.

### 9. Stashes (Tier 1 — surface)

```sh
git stash list
```

If non-empty, surface count + entries. Don't drop or apply anything.

### 10. Beads in-progress check (Tier 3 — surface)

If beads workspace:

```sh
bd list --status=in_progress
```

Filter to issues claimed by the current user (assignee matches `git config user.email` or local username). Surface count + IDs/titles. User decides which to close — common forgetfulness pattern.

### 11. Beads preflight (Tier 1)

If beads workspace:

```sh
bd preflight
```

Surface output. Includes lint, stale, orphans checks — all read-only.

### 12. Other worktrees (Tier 3 — surface)

```sh
git worktree list
```

If more than one entry, list non-primary worktrees with their branch. If any have uncommitted work, flag with `*`. Don't remove anything.

### 13. Background processes

Split by origin:

- **Spawned by Claude in this session** (via `run_in_background`): list. Reap any that have completed (Tier 1 — auto). If still running and the task seems incomplete, surface before reaping.
- **Started by the user / pre-existing**: surface only (Tier 3). Don't kill.

### 14. Beads sync (Tier 1)

If `.beads/metadata.json` exists:

```sh
bd dolt push
```

If this fails, surface the error but don't block the phase — the user can retry manually.

### 15. Phase 1 summary

Print a concise summary. Each line says "none" loudly when clean, so noise scales with actual mess:

- Branches pruned (merged): `<list or "none">`
- Branches pruned (squash-merged): `<list or "none">`
- Stashed/committed work this run: `<describe or "none">`
- Main rebased: `<yes/no, behind/ahead counts>`
- `main` CI status: `<green / running: N (<workflow names>) / FAILED: <workflow names>>`
- Open PRs needing action: `<count by category, or "none">`
- Stashes outstanding: `<count, or "none">`
- Beads in_progress (yours): `<count, or "none">`
- Beads preflight: `<pass/issues>`
- Other worktrees: `<count, or "none">`
- Background processes (reaped): `<count>`
- Background processes (user-owned, surfaced): `<count>`
- Beads pushed: `<yes/no/n/a>`
- Anything skipped/surfaced: `<list>`

## Phase 2 — Retrospective

If `main` CI is **failing** or **currently running** (per step 3), pre-prompt:

> `main` CI is `<failing|running>`. Defer the retrospective? (y/n)

On `y`: stop here. Re-run `/end-session` later or run `/retrospective` directly when ready.

Otherwise (or after the pre-prompt is dismissed with `n`), ask:

> Proceed to retrospective? (y/n)

On `y`: invoke the `retrospective` skill via the Skill tool. Do not perform the retrospective inline — let the skill own its contract.

On `n`: stop. The session is tidied; the user can run `/retrospective` later if they change their mind.

## Guardrails

- **`-D` (force delete) is allowed only for Batch B of step 6** — branches that are `[upstream: gone]` AND have an empty `git diff` against `main`. Everywhere else: always `-d`. If `-d` refuses, that's signal — surface it, don't override.
- **Never `git push --force` or `git reset --hard`.** Those aren't session-tidy operations; if they're needed, the user should drive them.
- **Never auto-merge PRs, auto-close issues, or auto-drop stashes.** Per-item judgment lives with the user (Tier 3).
- **Ask before every Tier 2 destructive action** (branch deletes, force-pushing). One y/n per batch is fine — don't ask per-branch if a single list is presented.
- **Don't modify settings, config, or unrelated files.** This command's scope is git, GitHub, beads, and process state only.
