Start-of-session sync: bring git, beads, and GitHub-issue state up-to-date and surface anything that needs your attention before you begin work.

This command runs in a single phase. It mirrors `/end-session`'s shape — parallel state-gather, three-tier action model — but inverted: where `/end-session` leaves things tidy at walk-away, `/start-session` brings local state forward to "ready to work" and prints a one-screen session brief.

## Action tiers

Every step falls into one of three tiers — keep this in mind when adding or editing steps:

- **Tier 1 — auto-act, no prompt**: safe, reversible, expected. Examples: `git fetch --prune`, `git pull --rebase` on the default branch, `bd dolt pull`, `bd preflight`, read-only surface listings.
- **Tier 2 — auto-act behind one batched confirmation**: predictable but should be a conscious choice. Example: chaining into `/bd-import-github-issues` when unmigrated GitHub issues exist.
- **Tier 3 — surface only, user drives**: needs per-item judgment. Examples: a feature branch trailing `main`, in-progress beads left mid-flight from the last session, red `main` CI.

When in doubt, downgrade a tier (Tier 1 → 2, or 2 → 3). Never upgrade silently.

## Pre-flight

This command **requires a git-backed repository**. Run the bare command below and branch on its exit code — don't paste a compound `||` / `&&` form, which won't match any single allow rule and will trigger a permission prompt.

```sh
git rev-parse --is-inside-work-tree
```

If the exit code is non-zero (or stdout is not `true`), print a single-line warning (`` `/start-session` requires a git-backed repo — nothing to sync, stopping. ``) and stop.

## Phase 1 — Sync

### 1. Gather state (Tier 1 — one tool call)

Run the parallel gather script. It does `git fetch --all --prune --tags` first, resolves the repo's default branch, then fans out all read-only queries (local branch state, `main` CI, beads remote/preflight/ready/in-progress, unmigrated GH issues) in parallel.

```sh
~/.claude/bin/start-session-gather-state
```

Output is a sectioned stream. Each section starts with `===<name> (exit=<N>)===`. The sections are:

| Section | Drives step(s) | Notes on exit code |
| --- | --- | --- |
| `fetch` | 2 (folded in) | Non-zero = network/auth issue — surface before proceeding. |
| `local_state` | 3, 8 | Includes branch, dirty/clean, ahead/behind upstream, ahead/behind `origin/<default>`. |
| `main_ci` | 6 | Content `gh-unavailable` = silent skip. Non-zero with other content = real error. |
| `gh_unmigrated` | 7 | Content `gh-unavailable` or `jq-unavailable` = silent skip. First line is `count=<N>`; remaining lines are `#<n> <title>` per unmigrated issue. |
| `bd_remote` | 4 | Section absent if no beads workspace. Empty content = no remote configured (single-machine setup). |
| `bd_preflight` | 5 | Section absent if no beads workspace. Non-zero = preflight flagged something — surface. |
| `bd_ready` | 8 | Section absent if no beads workspace. Plain `bd ready` output — pick the top 5 entries for the brief. |
| `bd_in_progress` | 8 | Section absent if no beads workspace. Mirrors `/end-session`'s `bd_progress` section. |

Rules for interpreting exit codes:

- `exit=0` with empty content: clean result (no remote configured, no in-progress issues, etc.). Treat as "none".
- `exit=0` with content: normal data — parse it for the relevant step.
- `exit != 0` with content equal to `gh-unavailable` or `jq-unavailable`: silent skip.
- `exit != 0` with other content: real error — surface it before continuing.

### 2. Surface fetch result (Tier 1)

Folded into step 1's gather. The `fetch` section contains the output. If its exit code is non-zero, halt the rest of the phase and surface the error — every downstream step assumes a successful fetch.

### 3. Sync the default branch (Tier 1 / Tier 3)

Read `local_state`, including the `upstream_status` line (`alive` / `gone` / `none`). Behavior depends on which branch you're on:

- **On the default branch** (`branch` matches `default_branch`) and behind `origin/<default>`: run `git pull --rebase --autostash`. Tier 1.
- **On the default branch** and clean / up-to-date: silent.
- **On a feature branch with `upstream_status=gone` and a clean working tree**: auto-switch back to the default branch and bring it up to date. Tier 1.

  `upstream_status=gone` means an upstream is configured in `.git/config` but its remote ref has been pruned during fetch — the canonical signal that the PR was merged and the branch was auto-deleted on the remote. Run:

  ```sh
  git checkout <default_branch>
  git pull --rebase --autostash
  ```

  Add `auto-switched <feature> → <default> (upstream gone)` as an extra line under `Sync:` in the session brief. Leave the local feature branch in place — never delete it. The user can return to it with `git checkout <feature>` if they need to.

- **On a feature branch with `upstream_status=gone` but the working tree is dirty**: do NOT auto-switch. The dirty work might sit on top of commits that are now squash-merged into `main`, and switching would risk surprising the user. Surface as Tier 3: `<branch>'s upstream is gone (PR merged?) but tree is dirty — commit or stash, then switch manually`.
- **On a feature branch with `upstream_status=alive`** and `default_branch` advanced (`vs origin/<default>` shows non-zero `behind`): surface the count — "`<default>` is N commits ahead of your branch". Do **not** auto-rebase. Tier 3 — the user decides whether to rebase, merge, or carry on.
- **On a feature branch with unpushed commits** (non-zero `ahead` vs `@{u}`): surface the count. Don't push from here; that's `/end-session`'s job.

Don't switch branches outside of the auto-switch case above.

### 4. Beads Dolt pull (Tier 1)

If there's no beads workspace (`bd_remote` section absent), skip silently.

If the `bd_remote` section is empty (no remote configured — typical for a single-machine project), print one line: `(no Dolt remote — skipping pull)`, and continue.

Otherwise run:

```sh
bd dolt pull
```

If it fails (auth, network, or genuine conflict), halt the phase and surface the error verbatim. Do **not** attempt auto-merge or auto-resolve — the user needs to fix this manually before continuing. Mention the v1.81.10 credential-prompt workaround documented in `/bd-modernize` step 5d if the failure looks like it.

### 5. Beads preflight (Tier 1 — surface)

From gather section `bd_preflight` (absent if no beads workspace). Surface output verbatim. Includes lint, stale, orphans checks — all read-only. Carry the result forward into the session brief.

### 6. `main` CI status (Tier 1 — surface)

From gather section `main_ci`. Parse the most recent run per workflow:

- **Failed**: flag in the session brief with workflow name + URL. A red default branch is the loudest "not clean" signal — call it out before the user starts new work.
- **In progress**: list with elapsed time.
- **All green**: silent (the brief reports "green").

If the section content is `gh-unavailable` or the repo has no remote, skip silently and report `n/a` in the brief.

### 7. Unmigrated GitHub Issues (Tier 2 — prompt)

From gather section `gh_unmigrated`. The first line is `count=<N>`; remaining lines are `#<number> <title>` per unmigrated issue.

- **`gh-unavailable` / `jq-unavailable` / no remote**: skip silently.
- **`count=0`**: silent.
- **`count > 0`**: print the count and (up to) the first 5 titles, then prompt:

  > `<N>` open GitHub issue(s) haven't been imported into beads yet. Run `/bd-import-github-issues` now? (y/n)

  - **yes** → invoke `/bd-import-github-issues` directly. That command does its own `bd dolt pull` (Step 0) and `bd dolt push` (Step 8); a second pull right after step 4 is a clean no-op, and the push at the end is what we want anyway.
  - **no / empty / cancel** → carry on. Surface the count in the session brief under "Needs attention" so it's visible at a glance.

### 8. Session brief (Tier 1 — final summary)

Always print, even when everything is clean. This is the user-facing payoff — one screenful, scannable, no surprises. Format:

```text
── Session brief ──────────────────────────────
Repo:     <repo>             Branch: <branch> (<clean|dirty>)
Sync:     <default> <ahead/behind/even>   upstream <ahead/behind/even/gone/n/a>
          [auto-switched <feature> → <default> (upstream gone)]    (only when Step 3 auto-switched)
Dolt:     <pulled / up-to-date / no remote / FAILED>
CI:       <green / N failing / N in-progress / n/a>

In progress (you left these mid-flight):
  <id>  P<pri>  <title>            (or "none")

Ready to pick up next:
  <id>  P<pri>  <title>   est:<n>  (top 5 by priority, then est)
  …                                 (or "none — backlog empty")

Needs attention:
  • <unmigrated GH issues: N>      (omit when 0 / n/a)
  • <main CI red on workflow X>    (omit when green)
  • <bd preflight flagged …>       (omit when clean)
  • <feature branch behind main by N>          (omit when on default, even, or auto-switched)
  • <branch upstream gone but tree dirty>      (omit unless that case fires)
───────────────────────────────────────────────
```

Rules:

- Sections with nothing to say collapse to a single `none` line; "Needs attention" is omitted entirely when empty.
- "Ready to pick up next" is sourced from gather section `bd_ready`. Take the first 5 rows of `bd ready`'s output. `bd ready` already filters to issues whose blockers are all closed and sorts sensibly — preserve its order.
- "In progress" is sourced from gather section `bd_in_progress`. No cap (usually 0–3 items).
- If the repo has no beads workspace, drop both Beads sections silently (the brief still shows git/CI/GH lines).
- Truncate any title to ~78 columns to keep rows on one line.

## Guardrails

- **Pre-flight gate is non-negotiable.** Never proceed when not in a git repo.
- **Never auto-rebase a feature branch** onto an advanced default branch. Surface the gap and stop. The user picks the strategy.
- **Never switch branches except when the upstream is gone and the tree is clean.** That single case (PR merged + branch auto-deleted on remote, no local uncommitted work) is auto-handled per Step 3. Otherwise, `/start-session` reports state on whatever branch the user is on.
- **`bd dolt pull` failures halt the phase.** Don't attempt auto-resolve, don't fall back to JSONL, don't rebuild the DB. Surface and stop.
- **Don't push anything.** Pushes belong to `/end-session` (for git/`main`) and `/bd-import-github-issues` (for beads after import). `/start-session` is read-mostly.
- **Don't modify settings, config, or unrelated files.** Scope is git, beads, and GitHub-issue surface only.
