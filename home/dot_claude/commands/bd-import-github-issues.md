Import open GitHub Issues into beads as proper bd issues, then close them upstream with a back-link. One-way migration: GitHub → beads. The intended workflow is "capture casually via the GitHub mobile app or web UI; sweep into beads at the start of a development session."

Always asks for explicit confirmation before any change to either system. Idempotent: re-runs skip already-migrated issues via a marker in the closed GitHub issue's body.

## When to use

Run at the start of a session when the GitHub Issues tab on this repo has accumulated user-captured items (typed on the phone, jotted from a meeting) that should now be tracked as beads. Don't run during ongoing work — this is a sweep step, not a continuous sync.

## What it doesn't do

- **No bidirectional sync.** Changes in beads are not pushed back to GitHub. The migrated GitHub issues are closed and inert.
- **No automatic / scheduled execution.** Always invoke explicitly.
- **No PR migration.** GitHub's `list_issues` returns PRs as well as issues — those are filtered out and left alone.
- **No hard delete by default.** GitHub's API doesn't allow non-admins to delete issues; even admins lose the audit trail. Default is close-with-comment-and-link, which gives the same effect for a solo workflow with a recoverable record.

## Operational notes

- Use `mcp__github__*` tools throughout, not the `gh` CLI (per the user's global preference). Specifically: `mcp__github__list_issues`, `mcp__github__add_issue_comment`, `mcp__github__issue_write` (for closing).
- Run all `bd create` calls synchronously in the foreground. Each is fast (~1 sec).
- Expected total runtime: 30 sec to 2 min for a typical batch of 1-10 issues.

## Pre-flight checks

Run all checks as a single block; surface the results to the user before proposing the migration.

```sh
echo "===bd initialised?==="; [ -f .beads/metadata.json ] && jq -r .dolt_mode .beads/metadata.json || echo "(no .beads/metadata.json — not a beads project; stop)"
echo "===project_id==="; jq -r .project_id .beads/metadata.json 2>/dev/null
echo "===origin url==="; git remote get-url origin
```

Then via the GitHub MCP:

- `mcp__github__get_me` — confirm authenticated user, capture login. (Used later for the closing comment author context.)
- `mcp__github__list_issues` with `state: "open"`, `perPage: 100` — fetch all open items.

If `.beads/metadata.json` is missing: report "this isn't a beads project; run `/bd-modernize` first" and stop.

If the open-issues list is empty (or contains only PRs): report "no open GitHub Issues to migrate" and stop.

## Procedure

### Step 1: Build the candidate list

From the `mcp__github__list_issues` response:

- **Filter out PRs**: any item where the `pull_request` field is non-null is a PR — exclude.
- **Filter out already-migrated**: any item whose `body` matches the regex `Migrated to beads [a-z0-9-]+` — exclude. This is the idempotency check; re-runs skip these.
- **For each remaining issue**, capture: `number`, `title`, `body` (may be null/empty), `labels` (array of `{name}`), `assignees`, `created_at`, `html_url`.

If after filtering the candidate list is empty, report "all open issues already migrated or are PRs" and stop.

### Step 2: Infer beads type and priority from labels

For each candidate, derive a proposed `--type` and `--priority` using these rules. Apply rules in order; first match wins.

**Type** (default: `task`):

| Label name (case-insensitive substring) | bd type |
| --- | --- |
| `bug`, `defect`, `regression` | `bug` |
| `feature`, `enhancement`, `epic` | `feature` |
| anything else | `task` |

**Priority** (default: `3`):

| Label name (case-insensitive substring) | bd priority |
| --- | --- |
| `critical`, `p0`, `urgent`, `blocker` | `0` |
| `high`, `p1` | `1` |
| `medium`, `p2` | `2` |
| `low`, `p4`, `backlog` | `4` |
| anything else | `3` |

These are first-pass guesses, not commitments. The user gets to override them in Step 3.

### Step 3: Confirmation A — present the mapping, get explicit yes

Show the user a table of candidates and proposed bd attributes. Use a compact format like:

```text
Migrating 3 open GitHub Issues from owner/repo to beads:

#  GH#  Title                                   Type     Priority   Source labels
1  42   Fix the broken date parser              bug      P1         bug, high
2  43   Add dark mode to settings page          feature  P3         enhancement
3  44   Investigate slow startup time           task     P3         (none)

Proceed with the above mapping?
  - Reply "yes" to migrate all as shown
  - Reply with an override line per issue, e.g. "1: type=task, priority=2" or "skip 3"
  - Reply "cancel" to abort
```

**Wait for explicit `yes` (or per-issue overrides followed by `yes`).** Never proceed on ambiguous input or silence.

### Step 4: Create the beads

For each confirmed candidate, in order:

```sh
bd create \
  --title="<gh title>" \
  --description="Source: <gh html_url>

<gh body, or '(no body)'>

---
Imported from GitHub Issue #<n> on $(date -u +%Y-%m-%d) via /bd-import-github-issues." \
  --type=<inferred or overridden> \
  --priority=<inferred or overridden>
```

Capture the new bead ID from each `bd create` output. Build a mapping table: `{ <gh_number>: <bead_id> }`.

If any `bd create` fails, STOP — do not proceed to the close step. Report the partial state (which beads were created, which weren't) so the user can decide whether to retry or rollback.

Notes:

- Don't try to preserve GitHub labels as bd labels — beads doesn't have a labels concept the same way. The label names are already captured indirectly via type/priority inference; the original list is in the GitHub issue's history (still accessible after closing).
- Don't try to map GitHub assignees — for solo-dev usage they're always you; for multi-user teams the mapping needs more thought and is out of scope for v1.

### Step 5: Confirmation B — close the GitHub issues?

Show the user the mapping table from Step 4 and ask:

```text
Created 3 beads from GitHub Issues:

GH#42 → beads-xxx
GH#43 → beads-yyy
GH#44 → beads-zzz

Close the GitHub issues now?
  - Reply "yes" to close all (with a back-link comment)
  - Reply "skip" to leave them open (you can close them manually later)
  - Reply "cancel" — beads are already created, but stops here
```

The migrate step (creating beads) and the close step (touching GitHub) are deliberately separated: the user might want to keep the GitHub issues open for a colleague to see, or might want to verify the beads first.

### Step 6: Close the GitHub issues with a back-link

If the user said `yes` to Step 5, for each `(gh_number, bead_id)` mapping:

1. Add a comment via `mcp__github__add_issue_comment`:

   ```text
   Migrated to beads <bead_id>. Closing here; track via `bd show <bead_id>` from the repo.
   ```

   The `Migrated to beads <id>` prefix is the idempotency marker — future runs of this skill will skip this issue because Step 1 filters on its presence.

2. Close the issue via `mcp__github__issue_write` with method `update`, `state: "closed"`, `state_reason: "completed"`.

If any close operation fails (network, permissions), continue with the rest and report the failures at the end. The bead has already been created so the migration is recoverable — the user can re-close manually.

### Step 7: Verify and report

```sh
bd list --status=open | head -20
```

Report a summary to the user:

- N beads created (with their IDs and titles)
- N GitHub issues closed (or skipped if Step 5 was "skip")
- Any failures (issues whose close didn't go through, etc.)

If `bd dolt push` is configured for this project, mention that the new beads will sync on next push.

## Idempotency

Re-running this command:

1. Step 1 filters out any GitHub issue whose body contains `Migrated to beads <id>` (added by Step 6's comment).
2. If everything has been migrated, the candidate list is empty and the skill reports "nothing to do".
3. If the user previously said "skip" to Step 5, those issues are still open on GitHub and DON'T have the marker — they'll appear in the candidate list again on next run. The user can choose to re-create the beads (duplicate) or manually close those issues. The skill should detect this case and warn: "GH#N has no marker but its title matches an existing bead — possibly already migrated, please confirm."

## Known issues / footnotes

- **Hard delete is not supported.** GitHub's API requires admin perms to delete issues, and even admins lose the audit trail. If a user really wants hard delete, they can run `gh issue delete <n>` manually after the skill closes the issue. Document this rather than offering a `--delete` flag — the shape of the destructive risk is meaningfully different.
- **Label inference is best-effort.** The mapping table above covers common conventions. Repos with unusual label schemes (e.g. `Type: Bug` instead of `bug`) will fall through to defaults; the user overrides in Step 3 are the catch.
- **GitHub Issue body markdown is preserved verbatim** in the bd description — including any inline images, tables, or `@mentions`. The bd description doesn't render these but the raw markdown is preserved for re-rendering elsewhere.
- **Multi-user teams**: assignee mapping is out of scope. v1 assumes solo-dev.
- **Beads doesn't carry GitHub labels** as first-class metadata. The label list is captured in the inference reasoning shown to the user in Step 3 but not stored on the bead. If a future bd version adds labels, this skill should be updated to forward them.
