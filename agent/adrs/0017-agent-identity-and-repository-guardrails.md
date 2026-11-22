# ADR-0017: Agent identity, repository guardrails, and access control as code

- **Status**: Proposed (2026-08-16)
- **Date**: 2026-08-16
- **Tags**: security, github, agents, identity, access-control
- **Scope**: user (applies to all personal repos and agent surfaces)

## Context

`CLAUDE.md` carries a rule — no direct push to `main`, no unreviewed
merge — that has been ignored more than once. An audit on 2026-08-16
established why: nothing enforced it anywhere. It was a sentence in a
file that the agent bound by it could also edit.

The audit's specific findings — which controls were absent, on which
repositories, and what an agent session could therefore reach — are
recorded in the **personal tier** under ADR-0015, not here, per the rule
[ADR-0022](0022-public-artefact-content.md) now states for every public
artefact: current-state weaknesses in a live system are personal-tier
material regardless of which repository they concern.

What generalises, and what this ADR records, is the shape of the problem:
a policy expressed only as prose, on a surface where the agent holds the
same privileges as its author, has neither an enforcement boundary nor an
audit boundary. Every option below is an attempt to create one or both.

Two further facts frame the options.

**Cloud sessions authenticate as a user, not as a bot.** The Claude Code
on the web documentation is explicit: a cloud session can access any
repository *the connecting GitHub account* can see, and App installation
"is not a session-level access control"; PR replies "are posted using
your GitHub account, so they appear under your username". Tightening the
Claude GitHub App's permissions on a repo therefore cannot change the
session's identity or take admin away — the token inherits the
connecting account's role. The only lever on identity is **which GitHub
account is connected to the Claude account**.

**Cloud is now the primary surface.** Most work is moving to cloud
sessions, so a control that only binds the local CLI is close to
worthless.

## Primer: what each control mechanism actually does

A short reference, because these are routinely conflated.

| Mechanism | What it is | What it enforces | What it does not do |
| --- | --- | --- | --- |
| **Repository role** | Read / Triage / Write / Maintain / Admin, per collaborator | The ceiling on everything else. Write can push and open PRs; only Admin can change protection rules | Does not distinguish *what* is pushed — a Write collaborator can push anything, anywhere the rules allow |
| **Branch protection (classic)** | The older per-branch settings page | Require PRs, approvals, status checks; block force-push and deletion | Being superseded by rulesets; one rule per branch pattern, no layering |
| **Rulesets** | The modern replacement. Repo- or org-level, layered, with an explicit bypass list | Same controls as above, but multiple rulesets can stack and the bypass list is auditable | Cannot stop a repo Admin from editing the ruleset itself |
| **Required status checks** | Named CI checks that must report success | Blocks merge until CI is green | Names are opaque strings — rename a job and it is required forever and never reports |
| **Required approvals** | `required_approving_review_count: N` | N humans must approve before merge | GitHub forbids approving your own PR, so a solo owner with a single identity can never satisfy `N >= 1` |
| **Require last push approval** | Extra ruleset flag | The most recent pusher cannot be the approver | With one human it deadlocks any PR that human pushed to |
| **CODEOWNERS** | A file mapping path globs to owners | Combined with "require review from Code Owners", forces the named owner to approve changes under those paths | Only affects *review requirements* on PRs. Does nothing about direct pushes |
| **Fine-grained PAT** | A per-repo, per-permission token tied to a user account | Whatever subset of that user's rights you grant it | Still acts as that user; expires and needs rotation |
| **GitHub App** | An installable identity with its own permissions and short-lived tokens | Acts as `app[bot]`, genuinely separate from any human | Cannot be used by Claude Code cloud sessions, which authenticate as the connecting user |
| **Deploy key** | An SSH key scoped to one repo | Git push/pull only | No API access — cannot open or review PRs |
| **Commit signing** | SSH or GPG signature on each commit, plus the Verified badge | Makes authorship cryptographic instead of self-asserted | Only meaningful if each actor holds a *different* key |
| **Claude Code `permissions` / hooks** | `allow`/`deny` lists and `PreToolUse` hooks in `settings.json` | Fast, local feedback before a command runs | Client-side. The agent can edit the file that constrains it, so this is ergonomics, not security |
| **Environments** | Deployment targets with required reviewers | Gates *deployments* | Does not gate merges |
| **Security log** | The account's audit trail at `github.com/settings/security-log` | A record of privileged actions | Records the *account*, so it cannot separate agent from human while they share one |

The pattern worth internalising: **server-side rules bind everyone;
client-side rules bind only the cooperative.** Everything in
`settings.json` and `home/bin/*` is the second kind.

## The gate

The requirement is a human decision point on every change reaching
`main`. The mechanism is negotiable — a submitted approval, a merge
button click, or anything else — but the gate must exist and must be
enforced by GitHub rather than by prose.

This matters for the options below, because a merge-button gate needs no
second identity, while an approval gate does.

## The contribution-statistics question

A separate identity has been informally resisted on the grounds that it
costs personal recognition for work that is real — design direction,
review, 20+ hours a month — even where the lines are not hand-typed.
That concern deserves numbers rather than intuition, and the numbers are
not what they appear. (It is *not* the reason recorded in the
personal-tier decision, which weighed different factors — see
"Reconciling with the personal-tier decision" below.)

**What GitHub counts** toward the contribution graph: commits where you
are the *author* (with an email linked to your account) on the default
branch, issues opened, pull requests opened, and pull request reviews
submitted.

**What it does not count**, confirmed by GitHub staff as intended and
long-standing behaviour: `Co-authored-by:` trailers. Co-authorship
gives attribution in the commit and the PR, but no graph credit. Nor
does being *added* as a reviewer or assignee — only actually submitting
a review counts.

Applied to this repo as it stands today:

| Activity | Author today | Counts for the human? |
| --- | --- | --- |
| Code commits, local CLI sessions | The human's own git identity, with a `Co-Authored-By: Claude` trailer | Yes |
| Code commits, cloud sessions | `Claude <noreply@anthropic.com>`, which GitHub maps to the unrelated `claude` account | **No** |
| Merge commits | `Paul Gledhill`, created by clicking Merge | Yes |
| PRs opened | The human's token, so the human | Yes |
| Issues opened | The human's token | Yes |
| Reviews | None — no approval is required | No |

Commit attribution therefore tracks **the surface the session ran on**,
not who wrote the code. Cloud environments set their own git identity
(`user.name=Claude`, `user.email=noreply@anthropic.com`) because signing
credentials are held outside the sandbox; the local CLI leaves the user's
git config alone and adds a co-author trailer instead.

The 91 non-merge commits in this repo make the effect concrete:

| Origin | Count | Graph credit |
| --- | --- | --- |
| Cloud sessions, authored `Claude` | 38 | None |
| Local sessions, authored human, Claude co-authored | 43 | Full |
| Hand-written, no Claude involvement | 8 | Full |
| Dependabot | 2 | n/a |

The same collaboration is recorded two different ways depending on
whether the session ran in a terminal or a browser. So roughly 42% of
agent-assisted commit credit has already been forfeited — by the move to
cloud sessions, which began 2026-08-04, and not by any identity
decision. Moving primarily to cloud forfeits the rest.

This does not change what Option 2 costs, because a bot account governs
the *GitHub connection*, not the git author recorded in a commit. It
does change the baseline the cost is measured against, and it means the
attribution being defended is already arbitrary.

### Prior art: this is known upstream, and unfixed

The obvious lever — cloud environments accept environment variables and
setup scripts, so set `GIT_AUTHOR_EMAIL` — has been tried by others and
does not work. It breaks GPG/SSH signature verification in web sessions,
because the environment's signing credentials are held outside the
sandbox and are bound to the identity it sets. Assume this route is
closed until proven otherwise.

The upstream record is unambiguous, and consistently stale:

| Issue | Substance | Status |
| --- | --- | --- |
| [claude-code#18715](https://github.com/anthropics/claude-code/issues/18715) | This exact problem: web-session commits attributed solely to Claude, user absent from contributor stats. Asks for an automatic `Co-authored-by` trailer | **Closed, not planned**; `stale` |
| [claude-code#65710](https://github.com/anthropics/claude-code/issues/65710) | Agent commits attributed to an *unrelated* GitHub account, which then appears in Contributors | Open, `stale` |
| [claude-code#72477](https://github.com/anthropics/claude-code/issues/72477) | `noreply@anthropic.com` resolves to no account; asks for a configurable or omitted address | Open, `stale` |
| [claude-code#65657](https://github.com/anthropics/claude-code/issues/65657), [#45137](https://github.com/anthropics/claude-code/issues/45137) | The documented `attribution.commit` setting is ignored; the built-in trailer wins | Open |
| [community#188915](https://github.com/orgs/community/discussions/188915) | A phantom "claude Claude" contributor on GitHub's side, from its own AI attribution feature | Community workaround only |

Issue #65710 is the same class of defect visible in this repo: the
`claude` account credited by our commits is a third party with no
involvement, and it sits in the Contributors list. GitHub offers a
partial mitigation of its own — repository **Settings → Code security
and analysis → AI-powered features → AI contribution attribution** — but
availability is inconsistent and it addresses GitHub's synthetic entries,
not the git author field.

Two conclusions follow. First, cloud commit attribution should be treated
as **fixed and outside our control** for planning purposes, not as a dial
to be tuned. Second, that makes the identity decision *cheaper* rather
than dearer: if cloud commit credit cannot be reclaimed by any means,
the bot identity forfeits nothing further, and the marginal cost narrows
to the PR-opened statistic alone.

What actually changes under a separate identity:

- **Lost**: PRs opened, which move to the bot. Issues too, when the
  agent files them.
- **Kept**: merge commits, because the human still clicks Merge — but
  only under the merge-commit strategy. A squash merge attributes the
  squashed commit to the branch author, so squash-merging would forfeit
  these regardless of identity. Session surface and merge strategy each
  move the graph at least as much as identity does.
- **Gained**: a review contribution per PR, because the approval gate
  makes reviewing mandatory rather than optional.

The trade is roughly one "PR opened" for one "review submitted" per unit
of work. The green squares survive; the labels on them change from
authoring to reviewing, which is a more accurate description of the work
being done. The visible cost is the repo's Contributors list, which is
commit-author based and would show the bot on top.

## Options

### Option 1 — Rulesets only, single identity

Apply a ruleset to `main`: require a PR, require status checks, block
force-push and deletion, empty bypass list. No approval requirement,
because a lone identity cannot satisfy one. The gate is the merge
button, backed by a `deny` entry for `mcp__github__merge_pull_request`,
`Bash(gh pr merge*)`, and `pull_request_review_write`.

- **Cost**: about ten minutes. No new accounts, no per-repo admin.
- **Statistics**: entirely unchanged.
- **Enforcement**: direct push to `main` becomes genuinely impossible.
  The merge gate does not — the session holds admin, so the deny rules
  are the only thing stopping a self-merge, and they are client-side.
- **Audit**: commit authorship already separates agent from human. API
  actions — PR creation, comments, merges — remain indistinguishable.

### Option 2 — Rulesets plus a bot as the connecting identity (recommended)

Create a dedicated machine account, invite it to each repo with **Write**
(never Admin), and reconnect the Claude Code GitHub integration
authorising as that account — either through the browser OAuth flow in a
separate profile, or by logging `gh` in as the bot and running
`/web-setup`. Verify with one command: `get_me` in a fresh cloud session
must return the bot account with `admin: false`.

Then the ruleset from Option 1 plus `required_approving_review_count: 1`,
which becomes possible for the first time because the PR author and the
approver are now different principals.

- **Cost**: account setup with its own email and 2FA; a collaborator
  invite per repo; the PR-opened statistic.
- **Enforcement**: Write cannot edit rulesets, so the agent provably
  cannot weaken its own guardrails. The gate is enforced by GitHub, not
  by the agent's own config file.
- **Audit**: complete separation. Every commit, PR, comment and review
  carries a distinct login.
- **Operational catch**: the GitHub connection is per-Claude-account, not
  per-repo, so cloud sessions can only reach repos the bot can see. A
  repo without the invite fails at session creation. This is a real
  friction and also the foundation of the access-control design below.
- **Note**: the local CLI is unaffected and continues to act as the human
  unless `GH_TOKEN` is pointed at the bot. Given cloud is the primary
  surface, that asymmetry is acceptable.

GitHub's terms permit one machine account alongside a personal account,
and the bot connects to the *existing* Claude account — no second
subscription.

### Option 3 — A self-owned GitHub App

Own an App with `contents: write` and `pull_requests: write` but not
`administration`, minting one-hour installation tokens.

**Rejected.** Cloud sessions cannot use it — they authenticate as the
connecting user — so it would only bind the local CLI and Actions, which
is precisely the surface that matters least. It also requires a
token-minting flow, which is the kind of extra approval machinery this
design is meant to avoid.

### Option 4 — Prose and hooks only (status quo)

**Rejected.** This is the arrangement that failed. An agent that can edit
`home/settings.json` and `home/bin/*` can edit its own constraints in the
same PR that does something else.

## Decision

Adopt **Option 2**, in two stages, so the enforcement lands before the
account work:

1. **Now**: apply the Option 1 ruleset to `main` here and across the
   estate. This is strictly additive and is worth doing whichever way
   the identity question resolves.
2. **Next**: create the bot, move the Claude connection to it, and raise
   `required_approving_review_count` to `1`.

`require_last_push_approval` stays **off** initially. Its effect with a
single human is to make all code arrive via the bot — defensible, but it
deadlocks any PR the human pushes to, and that friction should be a
deliberate later choice rather than a side effect of this ADR.

### Reconciling with the personal-tier decision

This reverses a recorded decision, and says so rather than quietly
diverging — the failure ADR-0015's deviation rule exists to prevent.

A personal-tier decision of 2026-05-13 chose a single-identity model for
sandbox agents and declined a separate bot account. Its reasoning was
**not** contribution statistics, which it never mentions — the informal
objection above and the recorded one are different arguments. It rested on
three grounds: alignment with earlier decisions already committing to one
human identity with the narrowest credential per surface; bounding blast
radius per surface rather than per identity; and audit-trail clarity,
which it considered and explicitly rejected.

The first two survive intact, and Option 2 does not contradict them: a
Write-only bot *is* the narrowest credential for the GitHub connection,
and it bounds blast radius more tightly than a broadly-scoped token on an
admin account can. What changed is the third point, and it changed for a
reason that decision could not have weighed.

**A merge gate needs two principals, and that is a mechanism constraint
rather than a preference.** GitHub does not let a pull request's author
approve it. With one identity, `required_approving_review_count: 1` is
not merely undesirable — it is unsatisfiable, which is exactly what
`setup-repo` already records in the comment *"solo developer — cannot
require approvals from others"*. The earlier decision treated attribution
as the only thing a second identity would buy. It also buys the only
enforceable form of the rule this ADR exists to enforce.

That decision listed its own triggers to revisit, and one has now fired
literally: the first time an actor other than the human needs to operate
against personal-infrastructure repos, which is what the reconciler and
the bot are. The rest of it stands — the per-surface credential model and
the tiered credential delivery are unaffected and should continue.

It also parked a hardening option that this ADR should decline explicitly
rather than silently pass over: a dedicated signing key, giving
pseudo-attribution by signature without changing identity. That remains
true and remains unnecessary. It addresses attribution, which the next
section accepts as lost and not worth reclaiming; it does nothing for the
gate, which is the actual problem.

**Required follow-up**: the personal-tier decision must be marked
superseded, pointing here. A user-tier ADR cannot edit the personal tier,
and leaving two live decisions that contradict each other is worse than
either one alone.

### Contribution attribution

The attribution loss is **accepted, and blocks none of the options
above**. Three findings carry that, and one judgment underwrites it.

- It is mostly already paid. 42% was forfeited by the move to cloud
  sessions, before any identity decision was on the table.
- It cannot be reclaimed. Every documented workaround is closed
  upstream, broken against the environment's signing, or reported
  ignored.
- It measures the wrong thing. 43 of the 51 commits authored to the
  human were Claude-written; the graph has been recording which surface
  a session ran on, in both directions, and never authorship.

Underneath the numbers is a judgment they do not settle. The expectation
that engineers hand-write their code is already historical, and a metric
resting on that assumption measures a shrinking part of the job.
Direction, design argument and review are the contribution being made
here; a commit graph simply does not count them, and adjusting identity
settings will not make it start.

Revisit if upstream ships configurable cloud attribution, or if a
graph-visible signal for review work appears. Neither is expected.

### CODEOWNERS

Adopt it, path-scoped rather than blanket. With one human, whole-repo
CODEOWNERS is redundant with a single required approval. Its value here
is narrower and real: `home/settings.json`, `home/bin/*`,
`home/skills/setup-repo/`, and `.github/workflows/` **are** the
guardrails, and changes to them warrant a stricter gate than a README
edit.

The second-order benefit is the more useful one. With code-owner review
required only on those paths, the default requirement can be *relaxed*,
letting `gh pr merge --auto` actually complete routine documentation and
skill changes on green CI while guardrail changes still stop for a
human. Today everything is gated identically, so nothing auto-merges.

Mechanics: personal repos support `@username` owners; the owner needs
write access, so the bot is never listed; the file must be on `main` to
take effect; and syntax errors silently disable rules, so the validation
view must be checked after committing.

## Access control as code

The per-repo collaborator invite in Option 2 is the point where this
either becomes a system or becomes a chore. Making it declarative is
what turns the friction into the feature: an explicit, reviewable
statement of exactly which repos the agent may touch.

The pattern: a private, personal-tier repository holds a registry, and a
scheduled workflow reconciles reality against it — inviting, downgrading
or removing the agent identity to match the declared permission, applying
the named protection profile to each repo, and opening an issue on drift.
Deleting an entry revokes access on the next run, which is the property
manual invites never have.

```yaml
# agents/access.yaml — shape only
identity: <agent-account>
repos:
  - name: <owner>/<repo>
    permission: push          # GitHub Write
    protection: standard
```

The concrete registry — which identity, which repositories, and where the
reconciler and its credential live — is personal-tier and is not recorded
here.

Two invariants make the pattern safe, and both are load-bearing:

1. **The agent identity has no write access to the registry.** If the
   agent can edit the file declaring its own reach, it can grant itself
   anything. This is the single rule the whole design rests on.
2. **The reconciler credential is reachable only from the registry
   repository.** It needs `administration: write`, so no workflow in any
   repo the agent can write to may be able to read it. Per-repo secret
   scoping gives this by default; stating it stops a later workflow from
   quietly breaking it.

The credential is a fine-grained PAT initially, and a self-owned GitHub
App if rotation becomes a nuisance. This is CI automation with no
interactive approval step, so it does not reintroduce the approval flow
rejected in Option 3.

Keeping the registry private means cloud sessions cannot read the
registry — consistent with the trade-off ADR-0015 already accepted. The
reconciler runs in Actions, so this costs nothing operationally.

### Private repositories: what the plan and the platform allow

Three constraints shape how fine-grained this can get on personal repos.

**Collaborator access is write, or nothing.** GitHub is explicit: *"In a
private repository, repository owners can only grant write access to
collaborators."* The Read / Triage / Write / Maintain / Admin ladder is
an **organization** feature; personal repos have one tier. This cuts
both ways. It is harmless for the guardrail design — write is exactly
what the bot needs, and write still cannot edit protection rules — but
it means access to a private repo is **binary**. There is no way to let
the agent read a private repo without also letting it push. "Just the
right amount of stuff" is therefore per-repo, not per-permission, and
the registry's `permission:` field is aspirational on private repos
until a repo moves to an organization.

**GitHub Pro is a hard dependency, not a nicety.** Protected branches
are available *"in public repositories with GitHub Free… and in public
and private repositories with GitHub Pro, GitHub Team, GitHub Enterprise
Cloud, and GitHub Enterprise Server."* Without Pro, private repos get no
enforcement at all and this entire ADR would apply only to public ones.
The existing subscription is load-bearing. CODEOWNERS is available on
Free, Pro and Team, so it covers private repos too.

Prefer **classic branch protection** for private repos rather than
rulesets. It is confirmed covered by Pro, it is what `setup-repo`
already calls, and it provides every control this ADR needs: required
PRs, required approvals, required status checks, `enforce_admins`, and
blocked force-pushes and deletions. Ruleset availability for private
repos on a personal Pro account is genuinely ambiguous in GitHub's own
documentation — the "Team and Enterprise" phrasing describes
organization-wide rulesets, and the widely-reported "won't be enforced
until you upgrade" error comes from Free *organizations* — so treat
rulesets as a nicer UI to verify on one repo, never as the mechanism the
design depends on.

> **Superseded on this point (2026-09-01, #367).** The ambiguity above was
> resolved empirically: a ruleset enforces fine on a private repo under
> personal Pro (`gcp-org-management` has run on one), and
> [`home/standards/github-standards.md`](../home/standards/github-standards.md) — accepted
> 2026-08-29 — makes rulesets the standard with classic protection as
> legacy, migrate-on-touch. `setup-repo` now applies the standard ruleset;
> an empty bypass list replaces `enforce_admins`. Every control this ADR
> needs exists in the ruleset shape, so the guardrail design is unaffected.

Note also that "restrict who can push" is not usable here: personal
repos cannot name permitted push actors, which `setup-repo` already
records as `restrictions: null`. The available shape is "nobody pushes
to the default branch directly", which is what is wanted anyway.

**Invitations need accepting.** Adding a collaborator by API creates an
*invitation*, not access. The reconciler must either hold the bot's own
token to accept via the repository-invitations endpoint, or leave a
manual acceptance step per repo. Worth designing in deliberately —
otherwise the automation appears to succeed while the bot still cannot
see the repository, and the failure surfaces later as a cloud session
that will not start.

## Consequences

### Positive

- The push and merge rules become facts about the repository rather than
  requests to the agent, and survive an agent that edits its own config.
- Agent and human actions separate completely in the audit trail, across
  commits, PRs, comments and reviews.
- The agent provably cannot alter its own guardrails, because Write
  cannot edit rulesets.
- Agent reach becomes a reviewable file with a working revocation path.
- CODEOWNERS makes routine auto-merge safe, which is a net *reduction*
  in friction despite being a new control.

### Negative / trade-offs

- The PR-opened statistic moves to the bot, and the Contributors list
  shows the bot on top. Reviews replace it on the graph.
- A collaborator invite is required per repo, and a missing one fails at
  session creation rather than with a clear permission error.
- Another account to hold: email, 2FA, recovery.
- Repo ownership still implies admin, so the ruleset can always be
  disabled by the human. The control is that doing so is deliberate and
  logged — prevention is not available to a sole owner.
- The registry repository becomes materially more sensitive: it now
  governs access rather than merely recording decisions.
- A personal-tier decision is reversed, so the estate carries two records
  of this question until the personal tier marks its own superseded. That
  window is the cost of the tiers being in separate repos, one private.

## Follow-on work

- `setup-repo`: replace `required_pull_request_reviews: null` and its now
  obsolete comment with the bot-aware ruleset payload
- Personal tier: mark the 2026-05-13 sandbox-agent-identity decision
  superseded by this ADR, keeping its per-surface credential model
- `CODEOWNERS` for the guardrail paths, plus the relaxed default
- A protection audit script with a `--check` mode for CI drift detection
- `home/settings.json`: a `deny` block for `merge_pull_request`,
  `pull_request_review_write` and `gh pr merge`, and a `prepush-guard`
  extension covering pushes to the default branch and force-pushes

## References

- [Claude Code on the web](https://code.claude.com/docs/en/claude-code-on-the-web)
  — GitHub authentication options; sessions act as the connecting account
- [Co-authored-by and the contribution graph](https://github.com/orgs/community/discussions/186410)
  — GitHub staff confirmation that trailers give no graph credit
- [Creating a commit with multiple authors](https://docs.github.com/en/pull-requests/committing-changes-to-your-project/creating-and-editing-commits/creating-a-commit-with-multiple-authors)
- [Troubleshooting missing contributions](https://docs.github.com/en/account-and-profile/how-tos/contribution-settings/troubleshooting-missing-contributions)
- [ADR-0015](0015-tiered-adrs.md) — tier placement, and the rule that a
  deviation must name what it deviates from
- The personal-tier companion record — the audit findings this decision
  responds to, the 2026-05-13 decision it supersedes, the concrete access
  registry, and remaining tracking. Held privately per ADR-0015; not
  linked from here.
