End-of-session tidy-up: clean up git branches, sync beads, then optionally run the retrospective.

This command runs in two phases. Phase 1 is the tidy-up (destructive actions require confirmation). Phase 2 is a simple prompt to kick off the retrospective. The retrospective itself is read-only — it only updates `~/.claude/retros.md` — so all repo-state changes must happen in Phase 1.

## Pre-flight

This command **requires a git-backed repository**. If the current directory is not inside a git work tree, print a single-line warning ("`/end-session` requires a git-backed repo — nothing to tidy, stopping.") and exit. Do not run the beads check, do not proceed to Phase 2.

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

### 2. Fetch and prune remote-tracking refs

Safe, non-destructive:

```sh
git fetch --all --prune --tags
```

### 3. Handle uncommitted or unpushed work

Before any branch switching or deletion, check for work that would be lost:

- **Dirty working tree** (uncommitted changes in `git status --porcelain`): stop, show the user what's dirty, ask whether to (a) commit, (b) stash, or (c) abort the tidy-up. Do **not** silently stash.
- **Current branch has unpushed commits** and isn't `main`: surface this — ask whether to push (create PR if needed) or abort. Don't switch away from a branch with unpushed work without explicit permission.

### 4. Return to main and rebase

If not already on `main` (or whatever the repo's default branch is):

```sh
git checkout main
git pull --rebase origin main
```

If the rebase fails (conflicts, divergent history), stop and surface the error — don't attempt `--abort` or destructive recovery without asking.

### 5. Prune merged local branches (destructive — preview first)

List local branches fully merged into `origin/main`, excluding `main` itself and the current branch:

```sh
git branch --merged origin/main --format='%(refname:short)' | grep -vE '^(main|master|HEAD)$'
```

Present this list to the user and ask for confirmation before deleting. Use `git branch -d` (safe delete — refuses if branch has unmerged commits), never `-D`. If there are no merged branches, say so and move on.

For remote-tracking refs, `git fetch --prune` in step 2 already handled stale `origin/*` refs. Don't delete anything on the remote itself.

### 6. Push main if ahead

```sh
git log origin/main..HEAD --oneline
```

If main is ahead of origin/main (shouldn't normally happen, but catches the case where commits landed locally), ask before pushing.

### 7. Beads sync (if beads workspace)

If `.beads/metadata.json` exists:

```sh
bd dolt push
```

If this fails, surface the error but don't block the phase — the user can retry manually.

### 8. Phase 1 summary

Print a concise summary of what was done:

- Branches pruned: `<list or "none">`
- Stashed/committed work: `<describe or "none">`
- Main rebased: `<yes/no, behind/ahead counts>`
- Beads pushed: `<yes/no/not a beads workspace>`
- Anything that was surfaced but skipped (e.g., "branch `feat/x` has unpushed commits — left alone")

## Phase 2 — Retrospective

Ask the user:

> Proceed to retrospective? (y/n)

On `y`: invoke the `retrospective` skill via the Skill tool. Do not perform the retrospective inline — let the skill own its contract.

On `n`: stop. The session is tidied; the user can run `/retrospective` later if they change their mind.

## Guardrails

- **Never use `-D` (force delete) on branches.** Always `-d`. If `-d` refuses, that's signal — surface it, don't override.
- **Never `git push --force` or `git reset --hard`.** Those aren't session-tidy operations; if they're needed, the user should drive them.
- **Ask before every destructive action** (branch deletes, stashing dirty work, force-pushing). A `y/n` per batch is fine — don't ask per-branch if a single list is presented.
- **Don't modify settings, config, or unrelated files.** This command's scope is git + beads state only.
