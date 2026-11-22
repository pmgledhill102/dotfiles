---
name: setup-repo
description: Configure a GitHub repository's settings and branch rules: merge methods, the standard default-branch ruleset with required status checks, auto-delete of merged branches, and the P0-P4 and type labels. Independent of local tooling setup.
---

# Configure GitHub repository settings

> **Note:** This command uses `gh repo edit` and `gh api` to modify remote GitHub settings. Each call will prompt for approval.

## Modes

| Invocation | What runs |
| --- | --- |
| `setup-repo` | The full baseline — steps 1–8 below |
| `/setup-repo --labels-only` | **Step 7 only** (work-tracking labels), then a short confirmation. Skips repo settings, merge strategy, secret scanning, branch rules and verification entirely |

`--labels-only` exists for **infra and secondary repos** that will never get the full treatment — a Terraform-only sibling repo, a fork used as a mirror — but that still need the `P0`–`P4` / `type: *` label set so cross-repo Issues filed against them can follow the convention in `agentic-coding-config` `docs/github-issues-workflow.md`. Without it such repos carry only GitHub's defaults and `gh issue create --label "type: task,P2"` fails.

Step 7's established-taxonomy guard applies **unchanged** in this mode: a repo with a purposeful labelling scheme of its own is still left alone.

## What to configure

### 1. Detect current state

Before making changes, gather the current repository configuration:

- Run `gh repo view --json name,owner,defaultBranchRef,deleteBranchOnMerge,mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed,isPrivate,hasWikiEnabled,hasProjectsEnabled` to get repo metadata
- Read branch rules from **both layers**. Classic protection and rulesets can apply to the same branch, most-restrictive-wins, so the blocking rule can hide in either — an audit that reads one layer gets a wrong answer:
  - `gh api repos/{owner}/{repo}/rulesets` to list rulesets, and `gh api "repos/{owner}/{repo}/rules/branches/{default_branch}"` for the effective ruleset rules on the default branch
  - `gh api repos/{owner}/{repo}/branches/{default_branch}/protection` for classic protection. **A 404 here means "no classic rule", not "unprotected"** — a repo governed only by a ruleset 404s on this endpoint, which reads exactly like an unprotected default branch unless the ruleset endpoints are read too
- Check if `.github/workflows/` exists and list workflow files to detect CI

Display a summary table showing **current vs proposed** values before applying any changes. Where current state contradicts the estate standard — linear history required, merge commits disabled, a required context no run reports — name the contradiction explicitly: a re-run on an already-configured repo is a drift repair, and the diff is the point.

### 2. Repository settings

Apply all settings in a single `gh repo edit` call:

```sh
gh repo edit \
  --delete-branch-on-merge \
  --enable-merge-commit \
  --enable-squash-merge=false \
  --enable-rebase-merge=false \
  --enable-auto-merge \
  --allow-update-branch \
  --enable-wiki=false \
  --enable-projects=false
```

**Merge-commit only. Squash and rebase are both disabled**, which reverses this skill's earlier position that squash "stays enabled for the case it is actually good at" (#348).

**GitHub has no "default merge method" field** — verified again 2026-09-05, the repository API exposes only `allow_merge_commit`, `allow_squash_merge` and `allow_rebase_merge`. So a policy that leaves a button enabled is enforced by nothing: every merge is a click, the UI remembers the last one, and the estate drifted to *zero* merge commits in 62 commits on one private repository while the written policy said merge-commit was the default. Disabling the button is the only mechanism there is.

Two costs, and the second is the one that bites quietly:

- **Squash replaces a branch's commits with a new SHA**, so anything stacked on it re-applies work `main` already has. Rebase-merge shares that defect and offers no cleanup in return.
- **Squash drops commit-message trailers**, so a `Closes #N` in a commit silently fails to close its issue. Two issues stayed open exactly this way (a-c-c#348). Nothing announces it, which makes it worse than the stacked-branch case.

Where a branch genuinely carries WIP or fixup commits, tidy it with `git rebase -i` before merging. That keeps the cleanup where the author can see it, rather than making every repo permanently able to lose trailers for the sake of an occasional convenience.

**`--enable-auto-merge` is conditional on a required check existing.** Without one, `gh pr merge --auto` merges *immediately* — the "wait for CI" everyone assumes comes from the ruleset, not the flag. If step 5 will have no `required_status_checks` rule (no CI yet), drop this flag.

If wiki or projects are currently enabled, note this in the summary but still disable them. Most hobby projects don't use these features.

### 3. Merge commit message formats

Only the merge-commit format matters now that squash is disabled:

```sh
gh api -X PATCH repos/{owner}/{repo} -f merge_commit_title=PR_TITLE -f merge_commit_message=PR_BODY
```

This needs the API directly: `gh repo edit` has **no** `--merge-commit-title`/`--merge-commit-message` flags, only the squash pair. The API accepts just three title/message combinations — `PR_TITLE`+`PR_BODY`, `PR_TITLE`+`BLANK`, and the default `MERGE_MESSAGE`+`PR_TITLE`. Anything else returns a 422 naming the valid set.

The squash message format is deliberately not set. Setting it would require passing `--enable-squash-merge` in the same invocation — `gh` gates the message flag on the enable flag — which would silently re-enable the button this skill just turned off.

### 4. Secret scanning (public repos only)

If the repository is **public**, enable secret scanning and push protection:

```sh
gh repo edit --enable-secret-scanning --enable-secret-scanning-push-protection
```

If the repository is **private**, skip this step and note: "Secret scanning requires GitHub Advanced Security (paid) for private repos. Skipping."

### 5. Branch rules (the standard ruleset)

Branch rules follow
[`home/standards/github-standards.md`](https://github.com/pmgledhill102/dotfiles/blob/main/agent/home/standards/github-standards.md):
**rulesets are the standard; classic branch protection is legacy.** This step
applies a ruleset, and migrates any classic rule step 1 found (see below).
Where this skill and that document disagree, the document wins and this skill
has a bug.

Determine the CI status check names to require. Prefer deriving them from an **actual completed run** — `gh pr checks <n>` on a recent PR, or `gh api repos/{owner}/{repo}/commits/{sha}/check-runs --jq '.check_runs[].name'` — rather than reading the workflow YAML: the rendered check name can differ from the job key, and a wrong string here blocks every PR (see below). Fall back to reading `name:` values from `pull_request`-triggered jobs in `.github/workflows/` only when no run exists yet.

Two hazards to warn the user about while doing this:

- **Required checks are a rename trap.** Rules store check names as opaque strings. Rename or remove a CI job and the old name is required forever, never reports, and every PR is blocked with no failing check to point at — nothing warns you. Whenever a CI job is renamed, removed, or a language port swaps one check for another, the required contexts must be updated in the same change.
- **Path-filtered jobs cannot be required checks.** A job behind a `paths:` filter never reports on PRs it skips, so PRs touching other files block forever. `setup-common` and the language skills deliberately suggest path filters — those jobs are ineligible; only require checks that run on every PR.

**Assert the contexts list; never merge it with what is already required.**
The list derived from live runs is authoritative — apply it as the complete
replacement, and treat any currently-required context that no completed run
reports as stale: remove it and name it in the summary. Stale contexts
accumulate silently and only surface as a blocked PR: one repo required both
`prod` and `prod / terraform`, which are mutually exclusive by construction
(a reusable-workflow caller reports the bare name when skipped and the
composite when it runs), so **no possible PR could merge** — and nothing
caught it until the next PR, months after the rename that caused it.

Whether required contexts should be one aggregate gate rather than per-job
names is deferred estate-wide
(tracked in the private infrastructure repository);
until that lands, require the per-job names a real run reports.

Apply **one ruleset** targeting the default branch. Create it with
`gh api -X POST repos/{owner}/{repo}/rulesets --input <file>`; if step 1 found
an existing ruleset for the default branch, update it in place with
`gh api -X PUT repos/{owner}/{repo}/rulesets/{ruleset_id} --input <file>`
rather than creating a second one. Do not use heredocs to pass the JSON —
write a temporary file and pass it with `--input`.

The payload is the spec's `protected` ruleset. Take it from there rather
than retyping it, so this skill cannot drift from the standard:

```sh
SPEC="${CLAUDE_STANDARDS_SPEC:-$HOME/.claude/standards/github-repo.json}"
jq '.tiers.protected.ruleset' "$SPEC" > ruleset.json
```

The spec ships `required_status_checks` with an **empty** contexts list,
deliberately (its `no-fake-contexts` invariant: a context string that never
reports blocks every PR forever, so the spec must not be able to ship one).
Fill it from the names derived above, or drop the rule when the repo has no
CI:

```sh
# CI exists: require exactly the detected contexts
jq --argjson ctx '[{"context":"ci"},{"context":"lint"}]' \
  '(.rules[] | select(.type == "required_status_checks")
     | .parameters.required_status_checks) = $ctx' ruleset.json > ruleset.final.json

# no CI: omit the rule rather than requiring an empty list
jq 'del(.rules[] | select(.type == "required_status_checks"))' ruleset.json > ruleset.final.json
```

On a surface where `~/.claude/standards/` was not delivered, read the raw
copy of `home/standards/github-repo.json` from this repo's `main` — never
reconstruct the payload from memory.

- Approvals are 0 because this is a single-human estate: requiring an approval the same human must give adds a click, not a control — the PR and its CI are the control
- The **empty bypass list is what `enforce_admins` bought under classic protection**: with no bypass actors the rules bind admin-level tokens and coding agents too. Add the narrowest actor only when something concretely breaks without it
- `strict_required_status_checks_policy: true` requires the branch to be up-to-date before merging
- **Never add a `required_linear_history` rule.** Linear history forbids merge commits on the branch regardless of the repo-level toggles from step 2, so a repo with both applied cannot merge a PR at all by the sanctioned route — and the failure appears at merge time on an approved, green PR, long after the setting that caused it. It reads like a tidy-up worth restoring; it isn't

If the repo has no CI workflows, omit the `required_status_checks` rule
entirely rather than requiring an empty list. The ruleset still prevents
direct pushes and enforces PRs. Two follow-ups in that case: suggest running
`setup-common` to add CI, and **do not leave auto-merge enabled** — with no
required check, `gh pr merge --auto` merges *immediately* (the
never-combination in the standards doc), so drop `--enable-auto-merge` from
step 2 or disable it until a check exists.

**Migrate classic protection on touch.** If step 1 found a classic rule on the
default branch:

1. Fold what it required that the standard also wants — the status-check contexts, after the staleness pass above — into the ruleset payload
2. Apply the ruleset and confirm it took effect (step 8)
3. Delete the classic rule: `gh api -X DELETE repos/{owner}/{repo}/branches/{default_branch}/protection`. Leaving both layers active means most-restrictive-wins, so a future blocking rule can hide in either — one mechanism collapses the search space

One migration hazard where the repo runs Dependabot auto-merge: auto-merge has
been reported to stop firing after a ruleset migration (the standards doc
carries the references). Watch the first Dependabot PR through end-to-end
after converting.

### 6. Default branch name check

If the default branch is `master` instead of `main`, **do not rename it automatically**. Renaming is disruptive (breaks CI, open PRs, local clones). Instead, display a warning with the manual steps:

```text
Warning: Default branch is 'master'. Consider renaming to 'main':
  git branch -m master main
  git push -u origin main
  gh api -X PATCH repos/{owner}/{repo} -f default_branch=main
  git push origin --delete master
```

### 7. Work-tracking labels

*This is the step `--labels-only` runs on its own (see Modes above).*

**Guard: skip this step in repos with an established label taxonomy.** Run
`gh label list` first — if the repo already has a purposeful labelling scheme
(e.g. `lifeos`, whose `kind:`/`effort:`/`area:`/`list:` labels are a format
contract parsed by its mobile apps), do NOT add the standard set; the local
taxonomy is authoritative. Only bootstrap repos with default/no labels.

Create the standard work-tracking label set (see `agentic-coding-config`
`docs/github-issues-workflow.md`). `--force` makes this idempotent —
existing labels are updated, not duplicated:

```sh
gh label create "P0" --color b60205 --description "Critical" --force
gh label create "P1" --color d93f0b --description "High" --force
gh label create "P2" --color fbca04 --description "Medium" --force
gh label create "P3" --color 0e8a16 --description "Low" --force
gh label create "P4" --color c5def5 --description "Backlog" --force
gh label create "type: epic" --color 1d76db --force
gh label create "type: feature" --color 1d76db --force
gh label create "type: task" --color 1d76db --force
gh label create "type: bug" --color 1d76db --force
gh label create "needs: local" --color 5319e7 --description "A step needs the owner's workstation" --force
gh label create "needs: decision" --color 5319e7 --description "Blocked on a choice only the owner can make" --force
gh label create "review: title" --color 006b75 --description "Review depth: the title, then CI" --force
gh label create "review: description" --color 006b75 --description "Review depth: the title and the description" --force
gh label create "review: diff" --color 006b75 --description "Review depth: the diff" --force
```

The two `needs:` labels mark an issue only one place can move;
`docs/github-issues-workflow.md` says when each applies. The three `review:`
labels go on pull requests, not issues: each pull request proposes one
([ADR-0025](https://github.com/pmgledhill102/dotfiles/blob/main/agent/adrs/0025-review-depth-sets-the-workflow.md)).

**Then the ecosystem labels, but only the ones the repo's own
`.github/dependabot.yml` names.** These are a different kind of label: not a
convention anybody applies by hand, but names Dependabot is *told* to use.

```sh
gh label create "dependencies"   --color 0366d6 --description "Dependency updates" --force
gh label create "github-actions" --color 000000 --description "GitHub Actions"     --force
gh label create "go"             --color 00ADD8 --description "Go dependencies"    --force
gh label create "docker"         --color 2496ED --description "Container base images" --force
gh label create "terraform"      --color 7B42BC --force
```

Create a label here **only if `dependabot.yml` references it** — an unused
label is clutter, and the set a repo needs depends on its ecosystems. The
reason to create them at all is that **Dependabot creates none of them, and
naming an absent one risks it applying none at all.** The failure is silent:
the pull requests still arrive, unlabelled, and nothing reports it.
`dfc-gaming` named `dependencies`, `github-actions`, `terraform` and `docker`
and had none of them, on the `automerge` tier, for as long as the file had
existed. The standard records this as the `referenced-labels-exist` invariant,
and `paul-context`'s sweep cross-checks it.

The colours are taste rather than correctness — the sweep asserts existence and
deliberately emits `gh label create` without `--color`. They are written down
here because these are the ones already in use across the estate, and a sixth
variant would be worse than none.

### 8. Verify

In `--labels-only` mode, verify with `gh label list` alone — confirm the fourteen labels above exist — and stop. Do not touch repo settings or branch protection.

After a full run, verify the configuration took effect:

- Diff the repository settings against the spec, key for key, in the API's
  own field names so nothing is translated by hand. Use `protected` for a
  repo without auto-merge; add the `automerge` overlay where it has it:

  ```sh
  SPEC="${CLAUDE_STANDARDS_SPEC:-$HOME/.claude/standards/github-repo.json}"
  jq -S '.tiers.protected.repository' "$SPEC" > expected.json
  # auto-merge repo: jq -S '.tiers.protected.repository + .tiers.automerge.repository' "$SPEC" > expected.json
  gh api "repos/{owner}/{repo}" \
    | jq -S --slurpfile e expected.json 'with_entries(select(.key | IN($e[0] | keys[])))' > actual.json
  diff expected.json actual.json && echo "repository settings match the spec"
  ```

  A non-empty diff is a **stop-and-fix**, not a line in the summary:
  re-run the failing step and diff again before reporting done.

  What this check cannot catch is a spec that changed after the repo was
  configured. The repos that cannot merge a PR (#352) each passed
  verification at the time — against the March 2026 spec, which was
  squash-only with merge commits disabled and `required_linear_history`
  set, a posture this skill itself specified until 2026-08-12. A repo
  configured under a superseded spec reads as "configured" forever,
  because nothing re-reads it. Only a re-run repairs it, which is why
  step 1 treats a re-run on an already-configured repo as a drift repair
  rather than a no-op. Tightening this step would not have found them.
- Run `gh api "repos/{owner}/{repo}/rules/branches/{default_branch}" --jq '[.[].type]'` and confirm the effective rules are the spec's `rules_required` for the tier (`jq '.tiers.protected.rules_required' "$SPEC"`), plus `required_status_checks` where CI exists — and specifically that `required_linear_history` is **absent**: if present, merge commits are blocked and step 5 did not apply as intended
- Where step 5 migrated a classic rule, confirm `gh api repos/{owner}/{repo}/branches/{default_branch}/protection` now returns 404 — here that is the desired end state, meaning the ruleset alone carries the rules
- Confirm the required contexts equal the derived list exactly — no extras surviving from before
- Display a final summary showing all applied settings

## Important

- This command modifies **remote GitHub settings**, not local files. It is safe to re-run (idempotent) — and re-running is how drift gets repaired: settings set once and never re-asserted are how stale contexts and contradicted policy accumulate.
- The ruleset PUT replaces the entire ruleset document. If a repo carries custom rules, review the current config (step 1) before overwriting.
- Rulesets on **private** repos require GitHub Pro. If the API returns a 403, explain this to the user.
- The **empty bypass list** is the setting that matters most for agent safety — an actor on the bypass list skips every other rule, admin tokens included.
- Required status check names are stored as opaque strings — remind the user that renaming a CI job later silently orphans the requirement and blocks all PRs until the ruleset is updated.
