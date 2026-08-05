# ADR-0014: This repo is public by design; no private-repo references

- **Status**: Accepted
- **Date**: 2026-08-05
- **Tags**: privacy, ci, quality

## Context

This repository is public, and not incidentally. The bootstrap is a single
`curl` on a fresh machine — before any credential exists to authenticate with —
so the install path cannot require auth. That constraint is load-bearing and is
not going to change.

The consequence is easy to state and easy to forget in the moment: everything
committed here is world-readable and indexed **permanently**. Git history keeps
what a later commit deletes, so removing a line does not unpublish it. The same
applies to issue and pull request bodies on this repo, which are also public.

The tooling here legitimately touches private work. The CI runner VM scripts
(`ci-vm-*`) manage a self-hosted GitHub Actions runner that attaches to a
private repo. When they were added, the docs, the README, the scripts' defaults,
the issue and the pull request all named that repo, linked it, described what it
builds and how it ships, and — the part that actually mattered — paired several
of its internal issue numbers with their subject matter, including one about a
security weakness and when it was fixed.

No credentials were ever exposed. The problem was inference: the existence of a
private project, what it is, and where it had been weak. Reviewing that led to a
second finding, predating it — the private personal-context repo was named and
linked from `CLAUDE.md`. So this is a recurring pattern, not a single lapse, and
guidance alone had already failed to prevent it.

## Decision

**This repository is public by design, and must contain no direct references to
private repositories.** Specifically, do not commit — and do not write in an
issue or pull request here:

- the name or URL of a private repo;
- its issue or PR numbers, especially paired with what they were about;
- its workflow, job, or branch names;
- its architecture, security arrangements, or release process;
- anything identifying what a private project *is* or *does*.

Tooling here may **operate on** private repos. The repo must then be an *input*,
never a constant: read it from untracked machine config such as
`~/.config/<tool>.conf`, with no default committed here. `ci-vm-*` follows this
— `CI_VM_REPO` has no default and the scripts fail with an instruction when it
is unset.

Documents that genuinely need private specifics belong in the private
personal-context repo.

### Enforcement

Per ADR-0013, the same check runs at more than one layer, with CI authoritative:

- **Layer 1 — CI.** A `Private repo references` job runs
  `scripts/check-no-private-repos.sh` on every push and PR.
- **Layer 2 — pre-commit.** The same script, as a local hook.
- **Layer 3 — Claude Code hooks.** Not applicable here; those live in
  `agentic-coding-config`, a separate repo.

The check is an **allowlist**, and this is the crux of the design: a list of
private repo names committed to a public repo would leak precisely the names it
exists to protect. So the check flags every owner-scoped reference that is *not*
in `scripts/public-repos.txt`. A newly created private repo is therefore caught
with no action needed.

An allowlist only sees owner-qualified references, not a bare project name on
its own. The pre-commit layer additionally reads an optional untracked local
file (`~/.config/dotfiles-private-names`) listing bare names to reject. That
file never enters the repo; CI simply skips that half.

## Consequences

### Positive

- The failure mode is caught mechanically rather than depending on whoever is
  editing remembering the rule — which is what had already failed twice.
- New private repos need no configuration to be protected.
- Nothing sensitive is committed in service of protecting sensitive things.
- Forcing the repo to be an input made `ci-vm-*` genuinely reusable, rather than
  hardcoded to one project. The privacy fix and the design improvement were the
  same change.

### Negative / trade-offs

- Public repos legitimately worth naming must be added to the allowlist, or the
  check fails. Mild friction, and deliberately in the safe direction.
- Bare-name detection depends on untracked local config, so it protects the
  machine that has it and not CI. Accepted: the alternative is committing the
  names.
- Design notes about private work now live in two places, and the split has to
  be maintained by hand.
- This does not undo prior disclosure. The commits that named a private repo
  remain in history, and one commit subject still does. Rewriting history was
  considered and judged disproportionate.

## Alternatives considered

- **Denylist of private repo names.** Rejected outright: it publishes the list
  of private repos to a public repo, which is the exact harm being prevented.
- **Resolve visibility via the GitHub API in CI.** Attractive because it needs
  no list at all, but a public repo's CI token cannot see private repos — a
  private repo and a typo both return 404, so the signal is ambiguous. It also
  makes the check network-dependent.
- **Guidance only, no check.** This is what was already in place implicitly, and
  it failed twice, including once immediately after the reviewer had been
  primed on the risk.
- **Make the repo private.** Impossible without breaking the credential-free
  `curl` bootstrap, which is the reason it is public in the first place.
- **Split into a private working repo and a public mirror.** Genuinely
  attractive, and would move issues and history behind auth rather than
  filtering their content. Larger structural change; not decided here, and this
  ADR does not preclude it.
