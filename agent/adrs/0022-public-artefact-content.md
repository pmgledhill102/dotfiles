# ADR-0022: What each kind of artefact may say in a public repo

- **Status**: Accepted (2026-10-22)
- **Date**: 2026-10-22
- **Tags**: security, workflow, github, documentation
- **Scope**: user (applies to all personal repos and agent surfaces)

## Context

Several repos in this estate are public, and so is everything around them:
issues, comments, PR bodies, review threads and every commit message in the
history. None of it has a corrective path. Edit history keeps the original
text, clones and indexes keep their own copies, and a commit message is
permanent the moment it is pushed. A rule about what may be published can only
work before the write.

A current-state audit of a live system was once filed as a public issue and
pushed to a public branch. The decision it supported was fine to publish; the
evidence was not. The failure was one of classification, not judgment: nothing
said which kind of artefact may carry which kind of content, so an agent
writing an issue body reached for the same level of detail it would put in a
private note.

The principle was already written down, three times, each scoped to one case:

- [`home/standards/github-standards.md`](../home/standards/github-standards.md):
  **standard public, evidence private**, for repository-settings audits.
- [`docs/github-issues-workflow.md`](../docs/github-issues-workflow.md),
  "Security-control defects": a report of a control that does not fire goes to
  `paul-context`; the fix stays public; private work is referred to by
  description, not by `repo#number`.
- [ADR-0017](0017-agent-identity-and-repository-guardrails.md), context:
  current-state weaknesses in a live system are personal-tier material,
  whichever repository they concern. Stated there for one audit, not as a rule.

What none of them covers is the per-artefact view an agent needs at the moment
of writing, and in particular commit messages, PR bodies and review comments.
Commit messages are the quiet case: permanent, cloned everywhere, and often
where an agent writes its most detailed reasoning.

[ADR-0015](0015-tiered-adrs.md) tiers *decisions*. This ADR tiers the content
of every other public artefact, using the same personal tier as the private
destination.

## Decision

### The two rules

1. **Current-state security findings about a live system are personal-tier,
   always.** This holds whichever repository the system belongs to, whichever
   repository the session is working in, and whatever artefact is being
   written. A finding is current-state while it describes something still
   true: a control that does not fire, a credential with more reach than it
   should have, a setting that differs from its standard, an access path that
   exists today.
2. **A public commit message may state what changed and why, never what is
   currently exploitable.** "Apply the auth middleware at the router rather
   than per handler" is a change. "The admin routes answer without a token" is
   a finding, and it stays a finding until the fix
   has merged and been deployed everywhere it runs.

### The default route

**Operational evidence goes to `paul-context` by default, whichever repo the
work touched.** Operational evidence means:

- audits and their output: what a live system's configuration currently is,
  and how it differs from the standard
- current-state findings, security or otherwise, that describe a weakness
  rather than a bug
- access topology: which identity can reach what, where a credential lives,
  which repos a registry grants
- incident notes: what happened, what was exposed, for how long

**The public repo gets the fix and the decision.** The code change, its test,
its rationale and any standard or ADR it implements are public as usual.
Titles describe the change, not the hole: "Require the token on every admin
route", not "Admin routes open without a token".

**Refer to private work by description, never by `repo#number`.** A
`paul-context#N` in a public body pins public context to a specific private
issue and is a link no public reader can follow. The same holds for any other
private repository, which is not named in a public artefact at all; #135
carries the full rule and the allowlist check that enforces it.

### Per-artefact table

Apply it by artefact type and content type, not by how sensitive the content
feels. Every row assumes the repository is public.

| Artefact | May be public | Must never be public | Where it goes instead |
| --- | --- | --- | --- |
| Issue body | The change wanted and why; a bug's symptoms and reproduction; acceptance criteria | A current-state finding; audit output; access topology; a private issue number | A `paul-context` issue. The public issue, if any, describes the change |
| Issue comment | Progress, design discussion, the decision taken | Same as issue body | Same as issue body |
| PR body | What changed, why, how it was verified | What was exploitable before the merge; audit evidence that motivated it | The private issue the work came from |
| Review comment | Defects in the diff under review | A weakness in a live system that the diff does not fix | A `paul-context` issue, referred to by description |
| Commit message | What changed and why | What is currently exploitable; audit evidence | The private issue the work came from |
| ADR | The decision, its rationale, the shape of the problem it answers | The specific findings that prompted it | A personal-tier companion record ([ADR-0015](0015-tiered-adrs.md)), not linked from the ADR |
| Code comment | Mechanism, and the surprising fact that keeps the design from being "corrected" into a bug | Which deployment is currently exposed | A `paul-context` issue |
| Session transcript, when shared | Nothing that would not pass the rows above | Anything a row above forbids | Shared privately, or not at all |

A shared transcript is the row most easily forgotten: it usually contains
everything the session read, including any private evidence. Publishing one is
publishing all of it.

### Worked example

An invented system: a web service with an admin endpoint that is meant to
require a token. A session finds that the endpoint answers without one.

- **Private**, in `paul-context`: the endpoint, the deployments affected, how
  it was found, and when it was closed.
- **Public**, in the service's repo: an issue titled "Require the admin token
  on every admin route"; a PR whose body says the middleware is now applied at
  the router rather than per handler, and that a test asserts every admin route
  rejects an unauthenticated request; commit messages saying the same.
- **Not anywhere public**: "the admin endpoint is currently open", a link to
  the private issue, or the list of affected deployments.

After the fix is deployed everywhere, the finding is history rather than
current state, and saying so in public is a choice rather than a breach. The
default remains not to: it buys a reader little the public fix does not.

### What this does not cover

**An ordinary bug stays public.** A wrong exit code, a misleading message, a
flaky test or a missing feature in a security-adjacent tool is a bug, filed
where the code lives. The rule is about current-state weaknesses in a live
system, not about the word "security" appearing in a title. Over-applying it
moves half the tracker into a private repo and loses the public record that
makes the public repos useful.

**Settled history may be public.** A weakness that has been fixed and deployed
everywhere is no longer current state. The default is still to describe the
change rather than retell the incident.

### The existing statements are instances of this

The three statements listed under Context now point here rather than restating
the rule. Each keeps only what is specific to its own case: the settings
standard keeps where its evidence lives, the issues workflow keeps how to file
a security-control defect, and ADR-0017 keeps its own audit's placement.

### Deferred: paired public and private repositories

The alternative weighed alongside this ADR was to work in private repositories
and publish public ones as mirrors through a promotion job, so that issues and
history sit behind authentication instead of being filtered by content.

It is **deferred, not rejected**. It costs a second repository per public
project, a promotion job that has to be correct every time, and a split
between where work is tracked and where it is read. A placement rule and a
private default cost almost nothing by comparison.

**Revisit trigger**: operational evidence reaches a public artefact again
after this ADR is in force, through a route the table already covers. That
would show the rule cannot be applied reliably at the moment of writing, which
is the case the mirror model answers.

## Consequences

### Positive

- One table answers "can this go here?" for every artefact type, without
  judgment about how sensitive the content feels.
- Commit messages, PR bodies and review comments are covered for the first
  time.
- Three partial statements become instances of one rule, so they cannot drift
  apart.

### Negative / trade-offs

- Some work is split across two trackers: the fix in public, its motivation in
  private. A public reader sees a change without its full reason.
- An agent writing a public artefact has to classify its content first. The
  table makes that mechanical, but it is still a step.
- The rule is enforced by the writer, not by tooling. #135's allowlist check
  catches private repository names; nothing catches a finding described in
  prose.

## References

- [ADR-0015](0015-tiered-adrs.md): the personal tier this ADR routes evidence
  to, and companion records that are not linked from public ADRs
- [ADR-0017](0017-agent-identity-and-repository-guardrails.md): the first
  statement of the current-state rule
- [`home/standards/github-standards.md`](../home/standards/github-standards.md):
  standard public, evidence private
- [`docs/github-issues-workflow.md`](../docs/github-issues-workflow.md):
  filing a security-control defect
- #135: no direct references to private repositories, and the allowlist check
  that enforces it
