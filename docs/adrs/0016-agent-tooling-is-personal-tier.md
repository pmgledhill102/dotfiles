# ADR-0016: Agent tooling and its configuration are personal-tier

- **Status**: Accepted
- **Scope**: Repo — this record binds `dotfiles` only. Per
  [agentic-coding-config ADR-0015](https://github.com/pmgledhill102/agentic-coding-config/blob/main/adrs/0015-tiered-adrs.md),
  the authoring test is whether the decision would still bind if this repo
  were archived. It would not: it is a statement about how *this* repo draws
  its machine tiers.
- **Date**: 2026-08-22
- **Tags**: layering, agents, chezmoi
- **Implements**: [#389](https://github.com/pmgledhill102/dotfiles/issues/389),
  [#395](https://github.com/pmgledhill102/dotfiles/pull/395)

## Context

[ADR-0003](0003-machine-type-tiering.md) established the `personal` / `work` /
`minimal` tiers, but did not say which side of that line agent tooling falls
on. In practice the two halves of it had drifted apart:

- The **binaries** were already personal-tier. `cask "claude"` and
  `cask "claude-code@latest"` sit inside the `personal` branch of
  `home/Brewfile.tmpl`, and no apt or winget list installs them on any tier.
- The **configuration** was not. `home/.chezmoiexternal.toml.tmpl` declared
  the `.claude` external with no `machine_type` guard, so
  `agentic-coding-config`'s `home/**` deployed to `~/.claude/` on `personal`,
  `work` and `minimal` alike.

A work machine therefore received the personal agent configuration *without
the tool that consumes it*: a global `CLAUDE.md` carrying a personal GitHub
workflow and references to the private personal-context repo, plus personal
slash commands, all of it inert because nothing on that machine reads it.

Inert is the charitable reading. The uncharitable one is that a work laptop
carried a description of personal working arrangements for no benefit at all.

Issue #389 and PR #395 fixed the mechanism. This ADR records the policy,
which is a judgement call a reader cannot recover from the templates.

## Decision

**Agent tooling and its configuration are personal-tier.** Both halves — the
binaries and the config that drives them — are gated to
`machine_type == "personal"`.

Concretely:

- The `.claude` external in `home/.chezmoiexternal.toml.tmpl` is wrapped in a
  `personal`-only conditional, using the same defensive `hasKey` preamble as
  `home/.chezmoiignore` so that an absent `machine_type` on an early or
  partial init falls back to `personal` rather than silently withholding
  config.
- `home/run_once_remove-claude-config-nonpersonal.sh.tmpl` removes the payload
  from machines that applied a pre-gate version. This is not optional
  belt-and-braces: chezmoi only ever adds and updates targets, and never
  removes one whose source went away, so gating alone would leave every
  already-applied work machine carrying the config indefinitely.

`minimal` is excluded too. That is deliberate rather than incidental — a
headless server or CI runner has no interactive agent session to configure —
and it is **reversible**: if agents do start running in that tier, the gate
becomes `ne .machine_type "work"` and the removal script's condition inverts
to match. Nothing else in the design assumes two tiers rather than one.

## Consequences

### Positive

- A work machine no longer carries personal working arrangements it cannot
  use.
- The two halves of agent tooling now agree. Previously `Brewfile.tmpl` said
  personal-tier and the external said every tier, and neither file explained
  itself.
- The blast radius of anything added to `agentic-coding-config`'s `home/` is
  now bounded to personal machines by construction.

### Negative / trade-offs

- **The removal script hard-codes a path list, and that list can drift
  silently.** This is the real cost of the approach and is worth stating
  plainly. Once the external is gated off, a work machine has no manifest to
  consult — chezmoi does not know about files it has stopped managing — so
  the script cannot derive what to delete and must carry the list literally.

  That list had **already drifted before it shipped**: #389 enumerated six
  paths as verified, and by the time #395 implemented it there were ten
  (`AGENTS.md`, `.claude-plugin/`, `hooks/` and `skills/` had been added
  upstream in between). Nothing detects this today. It is caught only by
  someone re-deriving the list on a machine that still has the external:

  ```sh
  chezmoi managed | grep '^\.claude/' | cut -d/ -f2 | sort -u
  ```

  A path added upstream after this ADR and not added to the script will
  simply survive on work machines — a quiet under-clean, not a loud failure.
  Whether to add a CI check comparing the script's list against the live
  upstream `home/` is left open; it needs its own issue if it is judged
  warranted.

- `~/.claude/` is **shared** between the external's files and Claude Code's
  own runtime state (`projects/`, `sessions/`, `history.jsonl`, `plugins/`,
  …), so the removal can never be a `rm -rf ~/.claude`. It has to enumerate,
  which is what forces the hard-coded list above.

- `bin/`, `commands/` and `skills/` are removed wholesale on non-personal
  machines. They are external-owned on every machine this targets, but a
  hand-authored slash command or skill placed there on a work machine would
  be destroyed.

- Someone who genuinely wants an agent on a work machine now has to change
  their machine tier or edit the template. That is the intended friction, but
  it is friction.

## Alternatives considered

- **Leave the external ungated.** Rejected: it is the status quo that
  prompted #389, and it puts personal working arrangements on machines that
  cannot act on them.
- **Gate the external but skip the removal script.** Rejected as ineffective.
  chezmoi never deletes a target whose source was removed, so this fixes only
  machines that have never applied — the ones that were never the problem.
- **Record this as a note inside ADR-0003 instead.** Rejected on the
  one-decision-per-ADR convention in this directory's README. ADR-0003 is
  about the existence of the tiers; this is about where one particular
  concern sits within them, and it carries its own trade-offs.
- **Gate on the presence of the `claude` binary rather than on tier.**
  Rejected: it makes deployment depend on install order, and a machine that
  installed the CLI by hand would start receiving personal config without
  anyone deciding that it should.
