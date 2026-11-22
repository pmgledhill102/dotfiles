# ADR-0025: Review depth sets the workflow

- **Status**: Accepted (2026-11-21)
- **Date**: 2026-11-21
- **Amended**: 2026-11-21, adding section 7: a checkbox on diff-depth pull
  requests records whether the diff was read
  ([#798](https://github.com/pmgledhill102/agentic-coding-config/issues/798))
- **Amended**: 2026-11-21, section 4: an agent may merge when the owner asks
  it to
  ([#807](https://github.com/pmgledhill102/agentic-coding-config/issues/807))
- **Tags**: workflow, github, review
- **Scope**: user (applies to all personal repos and agent surfaces)

## Context

The workflow rules treat every change alike. A typo and a change to an IAM
binding both need a tracking issue, a branch, a pull request of their own, and
a merge by the owner. The rules were written when an agent's work needed that
much supervision, and they have not been re-examined since
([#785](https://github.com/pmgledhill102/agentic-coding-config/issues/785)).

Three things are true of how the work is actually done.

**The owner already reviews at different depths.** He chooses by the kind of
change:

- a dependency update or a routine change: the title, and then CI is trusted
- many changes: the title and a scan of the description
- functional work that matters: most of the diff, with questions about the
  logic

**Nothing records which depth a change got.** GitHub's approve and "viewed"
features are not used, so the history cannot tell a change that was read from
one that was waved through. In this repo, 198 pull requests merged between
21 August and 21 November 2026, at a median of 14 minutes from open to merge,
and CI failed before merge on 9% of them. Those numbers say how fast and how
often; they do not say how closely.

**The agent cannot tell which depth a change will get.** So it writes every
pull request the same way, and the owner works out what to read each time.

Two rules also no longer fit the tools. A cloud session has one branch, so a
session with several small changes already bundles them, against the
single-concern rule. And an issue for every change, however small, grows the
backlog faster than it is worked: the session record shows issue counts rising
while the work they describe was already done.

## Decision

### 1. Three review depths

| Depth | The owner reads | Relied on |
| --- | --- | --- |
| **Title** | The title | CI, and fixing forward if something is missed |
| **Description** | The title and the pull request description | CI, and the description being accurate |
| **Diff** | The diff, or most of it | The owner's own reading |

### 2. The agent proposes the depth, on every pull request

A pull request carries one label: `review: title`, `review: description` or
`review: diff`. Where the labels do not exist yet, the body carries the line
`Review depth: <depth>` at its top, below the checkbox of section 7 and the
`Closes` line where it has them.

Merging without changing the label records that the owner accepted that depth.
He raises or lowers it by changing the label. No other step is asked of him at
title or description depth. Diff depth adds one optional tick (section 7).

The agent proposes by what the change is:

- **Always diff: infrastructure and identity.** Terraform, IAM, CI workflows
  and anything that handles secrets. This is the only category fixed in
  advance.
- **Title**: the title states the whole change and CI can verify it. A
  dependency bump, a typo, a regenerated file, a mechanical rename.
- **Description**: the description can state the change in full, and CI covers
  it.
- **Diff**: logic CI cannot fully verify, anything not easily reversed, and
  anything the agent is unsure of.

When two depths seem to fit, propose the deeper one.

Changes that deploy on merge, changes to agent policy and changes to personal
records were considered for the fixed list and left off it. They are proposed
by judgement like any other change.

### 3. A pull request is written for the depth it proposes

- **Title depth**: the title carries what changed and its effect. The body is
  a few lines.
- **Description depth**: the body says what changed, why, and how it was
  verified.
- **Diff depth**: the body also gives a reading order, names the risky parts,
  says what is not tested, and lists anything the owner must do before or
  after merging.

### 4. The owner merges

An agent merges only when the owner explicitly asks it to, for the pull
request he names, in that session. The ask does not carry to other pull
requests or to later sessions. An agent never approves.

This replaces "don't merge your own PRs", which could not be checked: every
merge is recorded under one account.

Title-depth pull requests do not merge themselves. The existing automatic
merging of dependency updates is unchanged.

### 5. A tracking issue is needed for description and diff depth only

A title-depth change needs no issue. Its pull request is the record. This
amends the rule that an issue comes before every change. That rule is stated
in [`docs/github-issues-workflow.md`](../docs/github-issues-workflow.md) and
in the agent policy, under
[ADR-0013](0013-github-issues-for-work-tracking.md)'s adoption of GitHub
Issues.

The existing exception stands: a doc-sized correction found during a retro or
at the end of a session is fixed in that session.

### 6. Small changes from one session may share a pull request

Title-depth and description-depth changes made in one session may go in one
pull request. The body lists them, one per line. The pull request carries the
deepest depth among them.

A diff-depth change always has a pull request to itself.

### 7. A diff-depth pull request records whether it was read

The label records the depth a change deserved. It does not record the depth it
got: a pull request accepted at diff depth and merged unread looks the same in
the history as one that was read. Lowering the label to match would lose the
other fact, that the change warranted a full read.

So the first line of a diff-depth pull request body is an unticked checkbox:

```markdown
- [ ] I read the diff
```

The owner ticks it when he has read the diff, or most of it. The tick is
optional and is never required to merge: a required tick becomes a reflex and
stops meaning anything.

An agent never ticks it and never writes it ticked.

Title-depth and description-depth pull requests carry no checkbox. There the
label already says everything.

## Consequences

### Positive

- The owner is told how much to read, and the pull request is written for that
  reading.
- Review depth is recorded with no extra step at merge.
- Whether a diff-depth change was read is recorded separately from the depth
  it deserved, for one tick.
- Small changes stop generating an issue and a pull request each.
- The rule about merging can now be checked against the session record: an
  agent that merges without the owner's ask for that pull request, in that
  session, has broken it, whoever's account it used.

### Negative / trade-offs

- The agent classifies its own work. A wrong "title" on a change that needed
  reading is the failure to watch for. The fixed list and "propose the deeper
  one" bound it; the label history measures it.
- A title-depth change has no issue, so its reason lives only in the pull
  request and its commits.
- A bundled pull request is harder to revert in part.
- An unticked checkbox means either "not read" or "read and not ticked", so
  the ticks are a lower bound on what was read.
- A tick is not proof. Every edit to a pull request is recorded under one
  account, the same limit section 4 names for merging.

### What this does not decide

- Automatic merging of title-depth changes written by an agent. It is deferred
  until there is a month of labelled pull requests to judge the labelling by.
- Any change to which checks are required to merge.

## Follow-up work

1. Update the workflow rules in `context/fragments/core.md` and
   `docs/github-issues-workflow.md` to match sections 2 to 7.
2. Add the three `review:` labels to the repository standard, so every repo
   has them.
3. After 30 days of labelled pull requests, count how often the owner changed
   a label, and in which direction, and how many diff-depth pull requests
   were ticked as read. Decide automatic merging on that.

## Revisit triggers

- A title-depth or description-depth change causes a revert or an incident.
  The kind of change it was moves up a depth.
- The owner changes the proposed label on more than about one pull request in
  ten. The proposing rules in section 2 are wrong and need rewriting.

## References

- [#785](https://github.com/pmgledhill102/agentic-coding-config/issues/785):
  the review this decision came out of
- [ADR-0013](0013-github-issues-for-work-tracking.md): adopts GitHub Issues
  for work tracking; the issue-first rule this amends is in the conventions
  doc it delegates to
- [ADR-0015](0015-tiered-adrs.md): why this is a user-tier decision
- [`docs/github-issues-workflow.md`](../docs/github-issues-workflow.md): the
  conventions for issues, which still apply where an issue is needed
