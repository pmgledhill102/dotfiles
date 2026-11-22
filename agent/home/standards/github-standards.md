# GitHub estate standards

The normative standard for every repository under `pmgledhill102`. This
document says what a repo's GitHub-side configuration should be and why;
it deliberately does not say what any repo's configuration currently is.
Audits, per-repo tier assignments and the archive list are private and live
in `paul-context` (`registry/`, `tools/repo-audit.sh`) — the split is:
**standard public, evidence private**, one instance of the rule in
[ADR-0022](https://github.com/pmgledhill102/dotfiles/blob/main/agent/adrs/0022-public-artefact-content.md) for what each public
artefact may say.

**Where to read this.** A local copy is delivered to
`$HOME/.claude/standards/github-standards.md` on every surface — by chezmoi on
a workstation, by `cloud/bootstrap.sh` in a sandbox. Prefer it to the URL:
fetching at read time fails exactly when the standard is needed, and a failed
fetch cannot be told apart from a standard that says nothing. The machine-
readable half is `github-repo.json` beside it.

Status: accepted 2026-08-29. Required-check *contexts* remain repo-specific
for now — see [Checks and CI](#checks-and-ci) for what is settled and what
is deferred.

How this document relates to the rest of the estate:

- **The values live in [`home/standards/github-repo.json`](../home/standards/github-repo.json).**
  This document is the rationale; the spec is what `/setup-repo` applies
  and the estate audit diffs against, in the GitHub API's own field names.
  A value stated here and not there is not standard — change both in the
  same PR.
- **Skills in this repo apply it.** `/setup-repo` sets the remote half,
  `/setup-common` the in-repo half. Where a skill's instructions and this
  document disagree, this document wins and the skill has a bug.
- **Verification lives in `paul-context`.** `tools/repo-audit.sh` reads the
  live estate and compares it against this standard. Settings are not
  behaviour (see [Verification](#verification-settings-are-not-behaviour)),
  so the audit is a standing capability, not scaffolding.
- **A repo may deviate, but only explicitly**, per
  [ADR-0015](https://github.com/pmgledhill102/dotfiles/blob/main/agent/adrs/0015-tiered-adrs.md):
  a repo-tier ADR naming what it deviates from and why. Silent divergence is
  the failure this document exists to prevent.

## Account context

The estate is a **personal GitHub Pro account**, not an organisation. Both
halves of that matter.

**Pro is load-bearing.** Rulesets and branch protection on **private**
repositories require a paid plan; on Free they are limited to public repos.
Most of this estate is private, so nearly every rule below works *because*
of the Pro subscription. If the plan ever lapses, enforcement silently
stops on private repos — the rules remain visible in settings but stop
applying, which is exactly the "looks configured, isn't" failure mode this
document is written against.

**Personal means per-repo, always.** Organisation-level rulesets, org
security defaults, and org-wide required workflows are unavailable. Every
standard here is applied N times by script and verified by audit, never
defined once and inherited. Two consequences:

- The apply mechanism is a scripted `gh` sweep plus re-runs of the setup
  skills — decided in `paul-context`
  `decisions/2026-08-18-repo-standards-mechanism.md` (not Terraform, not a
  `.github` defaults repo).
- Verification is first-class, because nothing converges automatically.

If the estate ever moves into an organisation, revisit this whole document:
org rulesets change the arithmetic completely.

**Two account-level settings are load-bearing for post-merge failure
alerts, and no repo declares either.** GitHub's Actions notification
setting must stay on *"Only notify for failed workflows"*, and the Gmail
filter that labels those notifications `auto/github/ci-failure` must stay
in place. If either changes, the Discord relay described under
[Post-merge failure visibility](#post-merge-failure-visibility) goes silent
with nothing to notice — it is the only part of that pipeline that lives
in no repository.

## Merge methods

The standard repository signature:

| Setting | Value |
| --- | --- |
| Allow merge commits | **on** |
| Allow squash merging | **off** |
| Allow rebase merging | **off** |
| Automatically delete head branches | on |
| Allow auto-merge | on where CI gates exist (the `automerge` tier) |

Merge-commit is the only enabled method; squash and rebase are both
disabled at the repository, not merely discouraged. The composed agent policy
(`context/fragments/core.md`, Git Workflow) carries the rule in one line; the
reasoning is here.

**Why disabled, and not just a stated preference.** GitHub has no
default-merge-method field. The only levers are the three booleans above, so
a preference that leaves all three on is enforced by nothing: every merge is
a button click that lands on whatever was clicked last.

**Squash has two costs, paid every time.**

- **It replaces a branch's commits with a new SHA.** Anything built on that
  branch still carries the originals, so it re-applies work `main` already
  has and produces conflicts that are resolved against a change that already
  landed. Rebase-merge has the same defect for the same reason.
- **It drops commit-message trailers.** A `Closes #N` in a commit message
  silently fails to close its issue. That is the audit trail quietly ceasing
  to work, and it is the worse of the two because nothing announces it; a
  stacked branch at least fails loudly.

**Squash's benefit is usually nothing here.** It exists to collapse WIP
noise, and agentic pull requests arrive as one or two already-written
commits. Where a branch genuinely carries WIP or fixup commits, tidy it with
`git rebase -i` before merging — that keeps the cleanup where its author can
see it, rather than making every repo permanently able to lose trailers for
an occasional convenience.

**The known trade-off.** With merge commits, `git bisect` can descend into a
commit that never passed CI on its own. Use `git bisect --first-parent`, and
`git log --first-parent` for the PR-level view.

Two operational facts, both learned the hard way on 2026-08-29
(agentic-coding-config#348 carries the evidence):

- **The merge dropdown is sticky per user per repository.** GitHub
  pre-selects whatever method was last used on that repo, not the "best"
  enabled one. Re-enabling merge commits on a repo that has been
  squash-only does not change what the button does next time; the first
  merge after a settings fix must change the dropdown by hand, once.
- **Never require linear history** (a ruleset/protection rule, not a
  repo setting). It forbids merge commits on the branch regardless of the
  repo-level toggles, and the failure appears at merge time on an approved,
  green PR — far from the setting that caused it. A repo can carry
  `allow_merge_commit: true` and still be unable to merge; only the branch
  rules reveal it.

Commit-message format, for the one method that is enabled:

- Merge commits: title `PR_TITLE`, body `PR_BODY` (API-only; `gh repo edit`
  has no flag for this pair)

No squash message format is set, and setting one is not an omission to
correct: `gh` gates `--squash-merge-commit-message` on `--enable-squash-merge`
being present in the same invocation, so specifying the format re-enables the
button the standard just turned off.

### Keeping armed PRs current

Decided 2026-10-14 under agentic-coding-config#568, after the #588 trial.
The ruleset keeps `strict_required_status_checks_policy: true`, so CI always
runs against what will actually land, and the cost that rule imposes is
paid by a workflow rather than by a person: on an `automerge`-tier repo,
`.github/workflows/update-auto-merge-prs.yaml` merges the default branch
into every open PR that has auto-merge armed and is behind it. Parallel PRs
then land one after another with nobody clicking **Update branch**.

- **Arming auto-merge is the approval.** The ruleset requires no approving
  review, so an armed PR merges as soon as its checks pass. An agent never
  arms auto-merge on its own pull request, because that would be an agent
  merging its own work. Dependabot's patch and minor bumps are the one
  standing exception, armed by their own workflow under the gates in
  [Dependabot](#dependabot).
- **It pushes with `AUTOMERGE_PAT`, never `GITHUB_TOKEN`.** A push made with
  `GITHUB_TOKEN` starts no `pull_request` workflow, so the required checks
  would never run on the updated head and the PR would wait forever. A
  missing secret fails the run rather than falling back.
- **It merges, never rebases**: `PUT /pulls/{n}/update-branch` with
  `expected_head_sha`, so a push between the comparison and the update fails
  the update rather than being merged over. It touches only armed PRs whose
  head is in the same repository, and its runs are serialised rather than
  cancelled.
- **It survives a stale PR head record.** GitHub's record of a PR's head can
  lag its branch, even after this workflow's own update, and the update is
  then refused with 422 `expected head sha didn't match current head ref`.
  On that message alone it re-reads the branch and retries once from the
  branch's real head; if the branch really is at the recorded head it warns
  and skips. Without this, one stale record fails every run until the PR is
  closed by hand (agentic-coding-config#719).
- **It cannot resolve a conflict.** A conflicted PR fails its update and
  turns the run red, which is the signal to fix it by hand. A conflict is
  also a 422 (`merge conflict between base and head`), so the retry above
  matches the head-mismatch message, never the status. GitHub computes
  no merge ref for a conflicted PR, so arming one starts no run either; the
  next push to the default branch still reports it.
- **The CI cost is unchanged, only the clicking goes.** A PR with *k*
  merges ahead of it is updated and re-tested *k* times, the same as
  clicking the button *k* times. Relaxing strict checks would remove that
  cost and the guarantee with it; a merge queue would batch it, and is not
  available to a personal account.

The workflow's load-bearing properties are declared in the spec, under the
`automerge` tier's `files` block, and the sweep checks every repo in the tier
against them. `/setup-common` installs it.

## Branch rules: rulesets, not classic protection

**Rulesets are the standard. Classic branch protection is legacy** —
migrate on touch, don't build anything new on it.

Why rulesets, concretely:

- **One addressable object.** A ruleset is created and updated as a single
  JSON document; classic protection can only be changed by `PUT`ing the
  entire protection object, whose request shape differs from the `GET`
  response shape, so scripting it across the estate risks silently dropping
  rules. For a per-repo estate applied by sweep, this difference is
  decisive.
- **One place to look.** Classic rules and rulesets can both apply to the
  same branch, most-restrictive-wins — which means a blocking rule can hide
  in either layer. Standardising on one collapses the search space
  (the 2026-08-29 linear-history hunt was this exact cost).
- **Bypass is an actor list with an audit log**, not an all-or-nothing
  admin checkbox.
- **Dry-run exists**: a ruleset can be created in *evaluate* mode to see
  what it would have blocked before enforcing it.

GitHub ships a one-click migration
([changelog, 2026-08-11](https://github.blog/changelog/2026-08-11-automatically-migrate-branch-protection-rules-to-repository-rulesets/)):
repo Settings → Branches → the classic rule → **Convert to ruleset**.

### The standard ruleset (default branch)

One ruleset per repo, targeting the default branch:

| Rule | Setting |
| --- | --- |
| Require a pull request before merging | on; required approvals **0** |
| Require status checks to pass | on; contexts are per-repo (see Checks) |
| Block force pushes | on |
| Restrict deletions | on |
| Require linear history | **off — prohibited**, see Merge methods |
| Bypass list | empty by default; add the narrowest actor only when something breaks without it |

Required approvals is 0 because this is a single-human estate: requiring an
approval the same human must give adds a click, not a control. The PR
itself (and its CI) is the control. Revisit per-repo if a repo ever gains a
second maintainer.

### Migration order and its hazards

Do not sweep-convert the estate blind. Three known hazards sit exactly
where this estate lives (Dependabot auto-merge on rulesets), and a fourth
strikes with no migration at all:

1. Reports of **auto-merge never firing after a ruleset migration**
   ([community discussion](https://github.com/orgs/community/discussions/162623))
   — enabled, checks green, merge doesn't happen.
2. A **2026-03 behaviour change**: enabling auto-merge now fails (HTTP 422)
   until all PR requirements are already met
   ([community discussion](https://github.com/orgs/community/discussions/190610))
   — and the Dependabot workflow enables auto-merge at PR-open time, before
   checks finish.
3. **A single required status check can be dropped entirely by the
   conversion.** Observed on four of seven repos in this estate: all four
   had exactly one required context (`gate`) and came out with none, while
   every repo with a multi-context list kept it. The pull-request, deletion
   and force-push rules survive, so the repo looks protected in the UI and
   in a casual API read — and with zero required checks a Dependabot PR
   merges *more* smoothly, so the end-to-end test below reads green
   precisely when the control is gone.
4. **A required context also goes stale when the job that reports it
   leaves the repository.** Moving a job to another repo (a repo split
   especially), deleting the workflow that defines it, or putting it behind
   a `paths:` filter all have the same effect as renaming it: the name stays
   required, nothing ever reports it, and every PR blocks with no failing
   check to point at. Whenever CI jobs move or are removed, re-derive the
   required contexts from a completed run and assert the list — in the
   *source* repo of a move as well as the destination.

So the protocol is: **convert one repo that runs the full Dependabot
auto-merge apparatus, let one real Dependabot PR through end-to-end
(approve → auto-merge arms → checks pass → merge commit lands), and only
then convert the rest.** If hazard 2 bites, the workflow needs a
wait-for-checks step before `gh pr merge --auto`; fix that in the reference
repo first so the sweep propagates the working shape.

That test does not exercise hazard 3, so after converting each repo, and
before moving to the next, assert that the required contexts survived:

```sh
ID=$(gh api "repos/pmgledhill102/$REPO/rulesets" --jq '.[0].id')
gh api "repos/pmgledhill102/$REPO/rulesets/$ID" \
  --jq '[.rules[]|select(.type=="required_status_checks")
         |.parameters.required_status_checks[].context]'
# Must list the same contexts the classic rule required. An empty list
# means the conversion dropped them.
```

## Pull request templates

Every active repo carries `.github/pull_request_template.md`. The template
is a layout for describing the change, not a form to satisfy:

- Sections: summary, type of change, checklist of the repo's own quality
  gates, anything the repo specifically needs (e.g. a Terraform repo asks
  for the plan output).
- Keep the checklist honest: list only gates that exist and can be run.
  A checklist item nobody can execute trains readers to tick boxes.
- N/A answers are answers — "no Terraform in this change, so there is no
  plan" beats a deleted section, because it shows the question was asked.

## Dependabot

The full standard — including why each piece exists and the per-repo tier
assignments — is `paul-context/registry/dependabot-standard.md` (private,
because the tier list names private repos). The normative summary:

**The system has two halves, and each is invisible from the other.** Repo
*settings* (dependency graph, alerts, security updates) are what raise an
alarm when an advisory lands; repo *files* (`dependabot.yml`, the
auto-merge workflow) are how routine bumps arrive. Weekly bump PRs prove
only the file half. A repo shipped bump PRs for months, on schedule,
correctly labelled, while alerts — the half that reports a compromised
dependency — were off.

Settings half (every active repo, and cheap enough for dormant ones):

- Dependency graph **on** (private repos: must be enabled explicitly;
  nothing else works without it)
- Dependabot alerts **on**; security updates **on**; grouped security
  updates **on**

File half (repos with CI worth trusting):

- `dependabot.yml`: weekly schedule; patch+minor grouped per ecosystem;
  majors arrive alone (they are the ones worth reading); **cooldown on
  every ecosystem entry** — auto-merge without a cooldown ships a
  compromised release the moment CI goes green. Caveat: the per-severity
  cooldown keys are accepted by some ecosystems only, and a rejected key
  invalidates the **entire file**, silently stopping every update stream in
  the repo — add keys to a new ecosystem only after checking they are
  accepted.
- Auto-merge workflow: approves and auto-merges **patch/minor only**;
  majors always wait for a human. Both the approval and the merge use a
  fine-grained PAT, not `GITHUB_TOKEN` (Actions may not approve PRs, and a
  `GITHUB_TOKEN` merge does not trigger the workflows that run on push to
  the default branch — deploy pipelines silently stop firing). The PAT
  lives in the **Dependabot** secret store, not Actions — Dependabot-triggered
  runs read from the Dependabot store, and a secret in the wrong store is
  simply empty at run time, with no error. The workflow fails loudly when
  the PAT is missing rather than falling back.
- Merge flag: `--merge`, per the merge-methods standard.

### The `AUTOMERGE_PAT`: one shared token for the estate, not one per repo

Decided 2026-08-29. The auto-merge PAT is a **single shared fine-grained
token**, whose selected-repositories list is exactly the set of repos
running the auto-merge apparatus — no wider.

- **Permissions: Contents read/write, Pull requests read/write, Workflows
  read/write, and the forced Metadata read. Nothing else.** This is the
  floor, not an over-grant: the approval needs the pull-requests half, and
  the merge itself writes commits to the base branch — GitHub has no
  narrower "may merge but not push" permission, so Contents write cannot be
  trimmed away. Workflows write is needed because the branch-update
  workflow pushes a merge commit into the PR head, and GitHub refuses any
  push that touches `.github/workflows/` from a token without it, which
  covers every Dependabot `github-actions` bump.
- **Storage stays per-repo even though the token is shared, and each repo
  holds it twice.** A personal account has no organisation secrets, so the
  same token is stored under the same name in each repo's **Dependabot**
  store, read by the Dependabot auto-merge workflow, and its **Actions**
  store, read by the [branch-update workflow](#keeping-armed-prs-current).
  A Dependabot-triggered run cannot read the Actions store and a
  push-triggered run cannot read the Dependabot one, and either reads an
  absent secret as empty with no error. Keeping one name keeps the workflow
  files the same shape everywhere; the spec's `must_match` patterns, not a
  byte comparison, are what the sweep checks.
- **The token is not kept after it is distributed, so it is only ever
  written to the whole tier at once.** Storing it in one more repo needs
  its value, and the only way to get the value is to regenerate the
  token, which invalidates every copy already stored. A single-repo
  `gh secret set` therefore leaves every other `automerge` repo holding a
  dead token until the next full run, and nothing reports it until each
  of those repos' next Dependabot bump fails with a 403. Adding a repo,
  and rotating, are both the same sequence:
  1. Assign the repo to `automerge` in `paul-context`'s
     `registry/repo-tiers.json`.
  2. Add it to the token's selected-repositories list.
  3. Check that list against
     `paul-context/tools/set-automerge-pat.sh --dry-run`, which derives
     its repos from the registry.
  4. Regenerate the token and run `tools/set-automerge-pat.sh`. It writes
     both stores on every `automerge` repo and verifies each.

  The script is a loop of this shape. The token goes in on stdin, because
  `--body` would put it in `argv`, visible to `ps` while the command runs,
  and whatever set the variable would sit in shell history:

  ```sh
  printf 'Fine-grained PAT (input hidden): '
  read -rs TOKEN; echo
  for r in <every automerge repo>; do
    for app in dependabot actions; do
      printf '%s' "$TOKEN" | gh secret set AUTOMERGE_PAT --app "$app" --repo "pmgledhill102/$r"
    done
  done
  unset TOKEN
  ```

- **Why shared:** per-repo tokens multiply minting, expiry tracking and
  rotation by the repo count to buy isolation between repositories that
  all have the same owner — the blast-radius argument that justifies
  per-repo credentials in a multi-tenant organisation does not apply
  here, and every extra token is another row the PAT inventory has to
  account for. Widening the covered set is an edit to the token's repo
  list plus one full redistribution (above), never a new credential.
- **What bounds a leaked token is the ruleset, not the token's scope.**
  The standard ruleset requires a pull request and passing checks on the
  default branch, with an empty bypass list — so even a stolen
  `AUTOMERGE_PAT` cannot land anything on a default branch without real
  CI going green first, and cannot push to it directly at all. This is
  load-bearing, which is why **the token's repository list and the
  ruleset rollout must be the same list**: a repo reachable by the token
  but lacking the ruleset has none of that protection.
- **The token's coverage cannot be audited.** A fine-grained PAT's
  repository list is not readable from outside the token, so no sweep can
  answer "is this repo actually in scope?" — only using the token answers
  that. A repo added to the auto-merge tier but missed off the list fails
  at run time, and fails *confusingly*: the secret is present and
  non-empty, so the workflow's missing-PAT guard passes, and the failure
  surfaces as a raw 403 from the approve step. Two controls follow, and
  they are the only two available: add the repo to the token's list as an
  explicit step when the auto-merge workflow is installed, and have that
  workflow name this cause when the approve step fails.
- **Upgrade path, recorded rather than adopted:** a private GitHub App
  with the same two permissions, installed on the same repo list, minting
  short-lived installation tokens per run — no expiry dates, no rotation.
  It also fixes the unauditability above: an App's coverage *is* readable,
  one call per repo (`GET /repos/{owner}/{repo}/installation`), so a sweep
  can prove coverage instead of discovering a gap at run time. Adopt it
  the first time PAT rotation actually hurts, when a missed repo has
  cost real debugging, or if the estate ever becomes an organisation;
  until then it is more moving parts than the problem needs.

This posture matches GitHub's own 2026 guidance
([grouping, cooldown, security-fast](https://github.blog/security/supply-chain-security/tame-dependabot-group-your-updates-slow-the-cadence-keep-security-fast/));
the estate's 7-day cooldown is stricter than the platform's 3-day default,
deliberately.

**The combination that must never exist: auto-merge enabled with no
required status checks on the default branch.** Without required checks,
`gh pr merge --auto` merges *immediately* — the "wait for CI" everyone
assumes is supplied by the ruleset, not by the flag.

## Checks and CI

Settled 2026-08-29: **required-check contexts stay repo-specific for now.**
The ruleset migration carries each repo's existing required checks across
as they are; standardising which contexts every repo must require is
deferred until after the migration, so the two changes cannot be confused
with each other when something breaks.

Current practice, from `/setup-common`: every repo gets gitleaks, cspell
and semgrep jobs plus actionlint; language skills add their gates; GitHub
Actions are pinned to commit SHAs.

Two rules are estate-wide **now**, because they are safety invariants
rather than conventions:

- **A repo with auto-merge enabled must require at least one status
  check.** Without one, `gh pr merge --auto` merges immediately — see the
  Dependabot section's never-combination. If a repo has no check worth
  requiring, it does not get auto-merge.
- **A required status check's workflow must not be path-filtered at the
  trigger.** GitHub's
  [troubleshooting table](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks)
  states the failure and the fix: a workflow skipped by path filtering,
  branch filtering or a commit message leaves its checks **Pending** and
  blocks merging, whereas a job skipped by a conditional reports
  **Success** — so "avoid requiring workflows that can be skipped", and
  filter at the job or step level when a build needs it. Measured
  2026-09-05: 19 of 21 required-check workflows already complied, and the
  two that did not each had PRs that could never merge. `setup-common`'s
  actionlint workflow is path-filtered by design and is therefore
  ineligible as a required check. Two gotchas for anyone checking this:
  contexts key on the job's `name:` when set, otherwise the job id; and
  `on: [push, pull_request]` is unfiltered and fine, so a checker that
  looks only for a `pull_request:` mapping raises a false positive on it.
- **A CI workflow's `pull_request` trigger must not be branch-filtered.**
  Same family as the rule above, different failure: a path filter makes a
  *required* check pend forever, while `branches: [main]` on
  `pull_request` makes a stacked PR, whose base is another feature
  branch, silently skip *every* check in that workflow. The PR then shows
  all checks passing, which is true of what ran and says nothing about
  what did not. Agent sessions stack PRs often, so the extra Actions
  minutes (a push to a branch that is also another PR's base runs
  twice) are the accepted price. A `branches:` filter on **`push`** is
  fine: it limits post-merge runs and affects no PR. The rule covers CI
  and check workflows only, and `setup-common`'s "Update auto-merge PRs"
  workflow is exempt by design: its `pull_request: branches: [main],
  types: [auto_merge_enabled]` trigger acts only on PRs armed to merge
  into `main`, and it is not a check, so a sweep must not "fix" it. The
  spec in `github-repo.json` does not assert this rule, because a
  per-file pattern cannot tell a check workflow from that exemption;
  detection lives in the estate sweep, and each repo drops the filter in
  its own PR.

Deferred until after the migration, recorded so the discussion has a home:

- **Which contexts are *required*** (ruleset-enforced) versus merely run.
  Required contexts are named by job, so renaming a job silently detaches
  it from the ruleset — a naming-stability convention is the prerequisite
  for requiring aggressively, and should be decided before contexts are
  standardised.
- Whether a uniform minimum (lint + secrets) should be required on every
  active repo, with language gates required only where the language exists.

### Post-merge failure visibility

**Pre-merge gates are not the whole story.** A workflow that runs on push
to the default branch produces no PR check (the PR already merged, green),
no comment (nothing is open to comment on) and no signal at all beyond the
Actions tab, which nobody opens unless they already suspect something.
One such run, in a private repository, sat red for two days that way, and
was found by accident.

**The estate's backstop is a Discord `#github-main-failures` channel**, fed
by GitHub's failed-workflow notification emails. It is global — every repo,
including ones created later, with nothing to configure per repo — which is
its whole value. Three things about it are worth knowing before leaning on
it:

- **It is a reviewed service, not a mail rule.** GitHub sends its
  failed-workflow notification from `notifications@github.com`; a Gmail
  filter applies the label
  `auto/github/ci-failure`; `automate-inbox` (`internal/handlers/github`,
  Go with tests) parses the subject and posts to a Discord webhook; the
  service and the webhook secret are Terraform in `automate-inbox-infra`.
  Relevance filtering sits in that Go code deliberately rather than in the
  Gmail filter, so the label means "this is a CI failure" and not "one I
  care about today" — which also means changing what is watched is a
  reviewed commit in another repo, not a filter tweak.
- **It covers `main` and `master` only, by design.** A failure on any other
  branch is not forwarded, on the reasoning that it is the author's
  business and already visible in the PR.
- **It rests on two account-level settings that no repo declares** — see
  [Account context](#account-context).

So treat it as a safety net rather than as a repo's own signal, for a
sharper reason than "it is unreviewed": it is `main`/`master`-only,
account-dependent, and owned by a different repository than the one whose
failure it reports.

**A repo that applies infrastructure or deploys on merge should also
announce its own failures.** The relay names the workflow and cannot name
the job, and "Terraform Apply failed" sends someone to a page with
seventeen jobs on it. The pattern, implemented in the private
infrastructure repository (`.github/workflows/notify-failed-run.yaml` plus the `notify-discord`
composite action):

- **Trigger on `workflow_run`, not a `notify` job with `needs:`.**
  `workflow_run` fires on the *workflow's* conclusion, so a job added later
  is covered with no edit — a `needs:` list of sixteen layer jobs is a
  second copy that falls behind.
- **Filter on explicit conclusions** (`failure`, `cancelled`,
  `timed_out`), never `!= 'success'`. A run whose jobs all skipped
  concludes `skipped`, which is routine where jobs are path-filtered, and
  paging on it trains everyone to ignore the channel.
- **Name the failing job**, not just the workflow. This is the one thing
  the relay structurally cannot do.
- **`workflow_run` matches a workflow's `name:`, not its filename.**
  Renaming a watched workflow silently unhooks it, and there is no
  path-based form.

The two are not interchangeable in the other direction either: an in-repo
notifier fires on whatever ref its watched workflow ran on, so a
`workflow_dispatch` against a test branch alerts, where the relay would
correctly have ignored it.

#### Three ways a failure notifier fails silently

All three shipped broken in code written to end silence, which is the
argument for recording them where they will be read before the code is
written rather than after:

- **An alert step gated on `failure()` after a step that captures its own
  exit code never fires.** The capturing step succeeds, so the job is never
  in a failure state.
- **jq object values must be parenthesised.** `{content: "a" + "b"}` parses
  on jq 1.8 and is a syntax error on the older jq GitHub runners carry
  (`syntax error, unexpected '+', expecting '}'`). This shipped reviewed,
  `actionlint`-clean and passing local tests; every call to the action
  failed. It generalises: **local tool versions are not runner tool
  versions**, and `actionlint` does not catch it.
- **A parser that is lazy where it should be greedy discards what it fails
  to match.** The relay splits its subject on the *last* `" - "`, because a
  git ref cannot contain a space but a workflow name can; splitting on the
  first yields a branch that matches no watched branch, and the failure is
  dropped in silence. Guarded by a test there.

And the matching rule for anything that retries: **retry what is transient,
accept what is simply not yours.** Returning an error for a message the
handler has nothing to say about retries it forever; swallowing the failure
of a webhook that is down loses the alert.

## Terraform versions

Applies to every repo whose tree contains a `.tf` file, whatever its tier.
The values are the spec's top-level `terraform` block; this is why they are
shaped the way they are.

> Terraform repos declare `required_version = ">= <floor>"`, where the floor
> is the oldest version whose features the configuration needs. CI and the
> cloud sandbox both run the estate **pin**, which is on the **current minor
> line**. Revisit when a new minor opens: HashiCorp publishes no support
> policy, and in practice the previous line stops receiving patches once the
> next one ships.

**The floor is not the pin.** They are independent values with two
invariants between them, not one value with two derivations:

| Value | Where it lives | What it says |
| --- | --- | --- |
| **floor** | each repo's `required_version` | the oldest Terraform the configuration can run on |
| **pin** | the spec's `terraform.pin` | the one version CI and the sandbox run |
| **new-repo floor** | the spec's `terraform.floor` | what `/setup-terraform` declares when nothing older is known to be needed |

- **`pin >= floor`**, for the spec and for every repo. A repo whose floor is
  above the pin cannot `init` in CI or the sandbox.
- **sandbox == CI == pin.** A sandbox behind CI fails `terraform_validate` in
  every root, so the pre-push hook cannot pass for any push touching a `.tf`
  file; a sandbox ahead of CI can write state CI cannot read.
- **Raising a floor to track the pin is wrong.** It locks out an older local
  binary for no benefit and adds a second value to keep in step. Raise a
  floor only when the configuration starts using a feature that needs it.
- **The constraint is a bare `>=`.** No `~>` and no `<`: an upper bound turns
  every pin move into a sweep of `required_version` edits. Provider
  constraints are a separate axis and may carry ranges.

**Why "current minor line", and why that and not "a supported line".** The
honest intent is *a line still receiving patches*, but that is not
observable. HashiCorp's `.github/SUPPORT.md` makes no version statement, and
`CONTRIBUTING.md` says only that a fix *can* be backported to "one or two
previous minor versions" when someone labels that PR for it — discretionary
per fix, with no window to look up. Observed, patches stop when the next line
opens: 1.15's last was 2026-08-19 and 1.16 opened 2026-08-26; 1.14's last was
2026-04-20 and 1.15 opened 2026-04-29. Nothing announces that a line has gone
quiet, so a rule keyed on it fires only in retrospect, which is the unwatched
condition this section exists to remove. *Is there a newer stable minor?* is
one request against `releases.hashicorp.com`, and it turns the trigger into an
event. Without that check the other two invariants hold indefinitely with the
whole estate frozen on an old line.

**The pin is declared once.** `cloud/bootstrap.sh` carries `TF_VER` because it
runs before anything can parse JSON, and `tests/github-repo-standard.py`
fails CI when the two differ. A workflow's `terraform_version` is a copy the
sweep compares against the pin. Neither copy is an authority: "CI moves up to
meet the sandbox" would have let a sandbox pin set by accident drag every
repo's CI with it, backwards included.

**Rollout order, because state upgrades are one-way.** Once a newer Terraform
writes state, older versions cannot read it back. So a pin move is one change
to CI and the sandbox together, and a floor rises only where it would
otherwise be violated. The cost of a move is dominated by state-format
migration rather than configuration breakage: five repos jumped nine minor
versions, 1.7.0 to 1.16.3, and every root applied `0 added, 0 changed, 0
destroyed`.

**Read the workflow, not the state.** Terraform rewrites a state object's
`terraform_version` only when it persists state, so a no-op apply leaves the
old label and an intentionally empty root reads its first version forever. A
sweep that reads state reports drift that is not there. And list repos and
read their files: GitHub code search returned one hit across nine Terraform
repos when this was measured, the same eventual-consistency trap as issue
search.

## Verification: settings are not behaviour

The recurring failure across the estate is a system that *looks* configured:
settings that were never applied, applied then contradicted by another
layer, or applied but with their effect quietly blocked. Three instances,
one month:

- a repo bumped dependencies weekly while advisory alerts were off;
- a repo carried `allow_merge_commit: true` while a linear-history rule
  made merge commits impossible;
- repos carried `allow_auto_merge: true` with no required checks, making
  "auto-merge when green" actually "merge now".

So the standard includes its own verification discipline:

- **Declared state**: `paul-context/tools/repo-audit.sh` sweeps the estate
  and diffs it against the spec, `home/standards/github-repo.json`. Run it
  after any sweep, and occasionally between. Until the audit's cut-over to
  reading the spec lands (tracked in `paul-context`), it carries its own
  copy of the expected values — the drift the spec exists to end.
- **Declared file contents**: settings compliance is not evidence that the
  apparatus works. A repo has reached zero settings drift — correct merge
  methods, correct ruleset, `AUTOMERGE_PAT` present — while carrying an
  auto-merge workflow that gated on `github.actor` and authenticated with
  `GITHUB_TOKEN`, which GitHub does not permit to approve a pull request;
  its Dependabot PRs skipped silently. So the spec's `automerge` tier
  declares the properties that workflow must have, and the sweep diffs
  against them. **Blob-SHA comparison does not substitute**: it answers
  *"are these copies the same"*, never *"is any of them right"* — five
  repos sharing one broken workflow read as perfectly consistent. The
  spec's top-level `prohibited` list is the mirror image, and closes the
  gap left by a standard that only ever said what a tier must *have*:
  auto-merge apparatus is a safety control, and a repo below the
  `automerge` tier has none of the gates that make it safe.
- **Observed behaviour**: after remediating a repo, watch the first PR
  through — the merge commit exists (`git log --merges --since=<fix date>`;
  date-bound it, or early history satisfies the check vacuously), the
  Dependabot PR actually merged itself, the deploy workflow actually fired.
  A settings read alone has signed off on broken repos three times; the
  behavioural check is the one that counts.

## Tiers

Not every repo earns the full apparatus, and the axis is **consequence**:
what happens if a dependency in the repo turns out to be compromised. Not
how active the repo is, not whether it is public. Three tiers, each
extending the last, defined in the spec:

| Tier | Applies to | Adds |
| --- | --- | --- |
| `baseline` | every repo | dependency graph, alerts, security updates |
| `protected` | deployed or reachable | the merge-methods signature, the standard ruleset |
| `automerge` | protected, and CI proves something | auto-merge, a required-checks rule, `AUTOMERGE_PAT` in both secret stores, the declared properties of the Dependabot auto-merge and branch-update workflows |

Which repo sits in which tier is private, in `paul-context`: the spec
carries the tiers, the private registry carries the assignments. The
Dependabot tiers in that registry are the *file* half of the same idea;
these are the settings half, and its Tier 0 is `baseline`, its Tier 2
`automerge`.

## Applying this standard

- **New repo**: run `/setup-repo` and `/setup-common` at creation. Both
  must land the repo on this document's values; where they don't, the skill
  has a bug — fix the skill, don't hand-patch the repo.
- **Existing repos**: scripted sweep + audit, per the mechanism decision in
  `paul-context`. Archive first; sweep the smaller estate.
- **Changing this standard**: one PR against this file **and the spec**
  (`tests/github-repo-standard.py` keeps the spec self-consistent), then a
  sweep to apply it and an audit run to confirm — a standard changed
  without a sweep is just a wish.
