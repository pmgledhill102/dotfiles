# ADR-0018: Composing agent context per surface — profiles, tiers, one mechanism

- **Status**: Proposed (2026-08-18)
- **Date**: 2026-08-18
- **Amended**: 2026-08-23 — principle 8 added (#291), after #265 applied the
  framework to skill bodies and #289 showed how easily a surface difference
  is asserted without being verified; its step 0 added the same day (#293),
  because the cheapest split is the one a script makes unnecessary;
  2026-10-04 — principle 2 gains the earns-its-place test (#309), because
  principle 6 catches text that is false on a surface and nothing caught
  text that is true but inert
- **Tags**: architecture, portability, context, skills, claude-code, codex
- **Scope**: user (applies to all personal repos and agent surfaces)

## Context

[ADR-0016](0016-capability-delivery-principles.md) settled *where* a
capability should live. It did not say how the **content** that reaches a
session is assembled, and the estate has since accumulated three
symptoms of that gap.

**Cloud sandboxes get no policy at all.** Verified 2026-08-17: `ls
~/.claude/*.md` is empty in a sandbox. The 221 lines of portable policy
in `home/AGENTS.md` and `home/ephemeral-first.md` reach workstations via
chezmoi and nothing else. Sessions on what is now the primary surface run
with whatever the opened repo happens to commit.

**Content branches at runtime on which surface it is running.** The
session commands ask `command -v chezmoi` and route on the answer:

```text
home/commands/start-session.md     8 surface conditionals
home/commands/end-session.md      11
home/commands/retrospective.md    16
```

Each branch is text that every session reads and most sessions cannot
use. A sandbox pays context for workstation instructions and then has to
correctly decide to ignore them — a decision it can get wrong, and
[#239](https://github.com/pmgledhill102/agentic-coding-config/issues/239)
is what that looks like when it does.

**Two mechanisms carry the same payload.** `home/commands/*.md` and
`home/skills/*/SKILL.md` both register `/name` and behave identically —
`cloud/bootstrap.sh` says so in a comment and deletes the duplicate
registration it would otherwise create. 17 of 21 commands already have a
skill twin, kept in step by a test that documents its own retirement.

Underneath all three is one question this ADR answers: **when a statement
must hold on some surfaces and not others, what resolves the
difference — the agent at runtime, or the delivery at build time?**

One fact makes the answer available. ADR-0016 established that a
container-created `~/.claude/skills` is read, symlinks included, on both
Claude Code and Codex. A canary on 2026-08-18 extended that to policy: a
`~/.claude/CLAUDE.md` written 37 minutes after session start was loaded
on resume, announced as *"user's private global instructions for all
projects"*. Per-surface policy delivery is therefore possible, which is
what makes per-surface composition worth designing.

## Decision

Adopt eight principles for composing and delivering agent context.

### 1. Determinism over conditionals

**Environment differences are resolved when content is delivered, not
when it is read.** A sandbox receives text that is true in a sandbox. A
workstation receives text that is true on a workstation. Neither receives
a conditional describing the other.

This is binding for always-loaded policy and strong for everything else.
The reasoning differs by tier, which is why they are separated:

- In policy, a conditional costs context on **every turn of every session
  for the rest of time**, and the surface it does not apply to pays that
  cost permanently.
- In a procedure, the cost is smaller but the risk is larger: a branch is
  a decision the agent can take wrongly, and a wrong branch on a
  destructive step is worse than a missing instruction.

The corollary is that runtime surface-detection — `command -v chezmoi`
and its relatives — is a smell in content. It is legitimate in a
*script*, which is code and has no context cost; it is not legitimate in
prose the model reads.

### 2. Tier every statement by what it costs to load

There are three tiers, and they differ by an order of magnitude in cost:

| Tier | Loaded | Cost |
| ---- | ------ | ---- |
| Policy (`AGENTS.md` / `CLAUDE.md`) | in full, every session | highest — permanent |
| Skill description | one line, every session | low, but multiplied by skill count |
| Skill body | only when the skill is used | ~zero until used |

**A statement's tier is chosen deliberately.** Policy is for what must
hold every turn regardless of task. Anything procedural belongs in a
skill body, where it costs nothing until needed.

**Before choosing a tier, establish that the statement earns one.** The
test is behavioural: *would removing this change what an agent does on
this surface?* If not, it belongs at no tier — inert text costs what
useful text costs, at whatever budget. Two shapes recur. A statement of an
**absence** ("rule X does not apply here") is never needed: an agent that
does not read the rule needs no exemption from it, and silence carries
that for free. A statement that is **true but buys nothing here** is the
subtler one — principle 6 catches text that is false on a surface, and
this catches text that is merely useless on it. The test is semantic, so
no deterministic check can apply it; it is a question for the author and
the reviewer.

This reframes the usual question. "Which file does this go in" is
downstream of "how often must this be true", and getting the second right
makes the first mechanical. It is also the answer to the context budget:
Claude Code targets under 200 lines of always-loaded policy, and the
portable core plus principles already exceeds it — not because the
content is wrong, but because some of it is procedure sitting in the
policy tier.

### 3. One mechanism: skills

**Skills are the unit. `home/commands/` is retired.** Slash commands and
skills register identically; skills additionally carry frontmatter that
lets the model invoke them unprompted, bundle adjacent files, and are the
cross-provider standard rather than a per-vendor directory.

Keeping both means every content change is made twice — which is exactly
why `tests/skills-match-commands.py` existed, and that test was
scaffolding for a migration, not a permanent fixture. The migration has
since landed: the command twins were retired and the test was deleted
with them. `home/commands/gcp-credentials.md` survives as the source the
cloud bootstrap generates that one skill from, not as a twin of a
checked-in skill.

### 4. Fragments are the source; delivered artefacts are derived

Content is authored as **fragments** — a portable core, a provider
fragment, an environment fragment. What lands on a surface is
**composed** from them by a single generator, committed, and checked in
CI.

The generator is one program. Composition must not live in the
installers: `cloud/bootstrap.sh` and the chezmoi path would then hold two
implementations of the same logic, delivered by different routes, drifting
independently. That is the failure this repo keeps meeting, one level up.

Committing the composed output rather than assembling at install time
also means **the artefact a surface receives is readable in the repo**,
which matters when the question is "why did the agent believe that".

### 5. Profiles compose from axes, not from names

Surfaces vary along two independent axes:

- **provider** — Claude Code, Codex, OpenCode: tool names, MCP servers,
  invocation spellings
- **environment** — workstation, cloud sandbox: whether chezmoi manages
  `~/.claude`, whether a credential broker exists, what is on `PATH`

A profile is a **point** in that space, not a hand-written file. One core
plus two provider fragments plus two environment fragments composes four
profiles; adding a provider costs one fragment, not one file per
environment. Naming profiles directly — `agents-claude-sandbox.md`,
`agents-codex-sandbox.md` — restates the environment half once per
provider and grows multiplicatively.

`home/local-machine.md` is already an environment fragment. It is only
reachable through `home/CLAUDE.md`, which is why shipping that file
verbatim to a sandbox would inject chezmoi instructions into the one
surface with no chezmoi. The axis split makes that structurally
impossible rather than a thing to remember.

### 6. No delivery assumptions in portable text

Restated from ADR-0016 principle 3 and now load-bearing: content names
what it needs, never where the delivery put it. The `~/.claude/bin/...`
paths in the broker skill are the standing example, and
[#234](https://github.com/pmgledhill102/agentic-coding-config/issues/234)
is the cost.

Under principle 1 this gets sharper. Deterministic delivery removes the
excuse for a path conditional: if a path genuinely differs by surface, it
belongs in the environment fragment, resolved at composition.

### 7. Every profile is built and verified in CI

Deterministic delivery trades runtime adaptability for build-time
correctness. **That is only a good trade if something checks the build.**

A conditional, for all its cost, degrades visibly — the wrong branch runs
and someone notices. A profile that was composed wrongly, or from a stale
fragment, is silent: it is only wrong on a surface, and a surface nobody
used this week is a surface nobody is watching.

So CI composes **every** profile on every change and asserts the
committed outputs match. Additionally, and specifically:

- every committed profile matches what the generator produces from the
  current fragments
- no sandbox profile transitively includes a workstation-only fragment
- every composed policy artefact is reported with its line count, so the
  always-loaded budget is a number in the build rather than a surprise
- every composed skill is reported with how many of its sections carry a
  per-surface variant, so principle 8's bar is a number in the build too

The last two are reports, not gates. A budget overrun and a high variant
ratio are both content decisions, and a build that failed on them would
be a build people learn to override.

This principle is the price of the others. Without it, principle 1
converts loud failures into quiet ones.

### 8. One body until a difference is proven

Composition makes a surface difference cheap to express. That is the
point, and it is also the risk: a mechanism for stating differences
invites stating ones that are not there, and an invented difference ships
a false statement to a surface exactly as effectively as a stale fragment
does.

**The default is one shared body.**

**Step 0: try to absorb the difference in code.** Before asking whether a
split is justified, ask whether there is anything left to split. A
conditional in a script costs nothing to read — it is executed, not
loaded, and the model sees only its output — where a conditional in prose
is paid in context by every session on every surface. Principle 1's
corollary above says surface-detection is legitimate in a script and
illegitimate in prose; step 0 is that corollary used as a design move
rather than as a prohibition.

The worked example is `bin/start-session-claude-drift`. It reported a wall
of phantom drift on a container — 50 files "never deployed", a remedy
naming a program not installed there — because it tested for a `~/.claude`
directory, which a sandbox now has. Two fixes were available: a paragraph
in the sandbox skill body explaining that the section misfires and should
be ignored, or three lines of shell teaching the script to test for
chezmoi and emit `state=absent`. The second costs one line of table in the
composed body, describing an output. The first would have been read by
every sandbox session forever.

The boundary is sharp. **A script can absorb a difference it can
compute. It cannot absorb a difference in what the agent itself must
invoke or decide** — an MCP tool is not callable from a subprocess, which
is why the sandbox `end-session` body genuinely differs while the drift
check does not. Differences in data or detection go to the script;
differences in which tool the agent reaches for, which steps run, or what
it must not do are content.

A script that absorbs a difference must emit a **named state**, never
silence: `gh-unauthorized`, `state=absent`, `chezmoi-unavailable`,
`not-a-container`. "Nothing here" and "not checked" have to stay
distinguishable in its output, or the context saving has bought a
correctness problem — and the skills are already full of rules against
exactly that confusion.

None of which makes shell free. It needs shellcheck, POSIX portability and
BSD/GNU care that prose does not, and the drift fix above reached CI
unverified locally because shellcheck is not installable in the sandbox it
was written in. That cost is paid once, by one author, against a context
cost paid per session by every reader — so this is a preference, not a
law.

Only what survives step 0 reaches the two questions. A per-surface split
is an exception that has to earn itself against both, and both must pass:

1. **Falsifiability.** Write the sandbox sentence and the workstation
   sentence. Is each one *false* on the other surface? If the sandbox text
   would still be true on a workstation, it is not a surface difference —
   it is phrasing, and it belongs in the shared fragment.
2. **Capability, not delivery.** Is the difference in what the surface
   *can do*, or in what has been *shipped* there? A delivery gap is closed
   by shipping the thing. Composing around an absence encodes it, and the
   encoding outlives the absence.

A pair that passes is justified where it is declared, not merely created.
The manifest is the review point, the same way `cloud/bootstrap.sh`'s
whitelist is the review point for which skills reach a sandbox at all.

This is why principle 1 reads "binding for always-loaded policy, strong
for everything else". The economics invert between the tiers of principle
2, and the tier that most invites splitting is the one where splitting
buys least:

| Tier | Cost of a conditional | Cost of splitting |
| ---- | --------------------- | ----------------- |
| Always-loaded policy | every turn, every session, forever | low — fragments are short and declarative |
| Skill body | ~zero until invoked | high — two long procedural texts that must stay in step |

The second row is the one to watch, and its cost is not hypothetical: see
the twin-drift trade-off below. Nothing can check that two variants of one
section still agree, because they are supposed to differ.

## Consequences

### Positive

- A sandbox session reads only statements that are true in a sandbox.
  Context spent on the other surface's instructions goes to zero.
- The single biggest reliability gap closes: `start-session`,
  `end-session` and `retrospective` become deliverable, in a form
  appropriate to each surface, rather than one text hedging across all of
  them.
- Adding a provider is one fragment and a CI row.
- The always-loaded budget becomes measurable and enforced rather than
  discovered when adherence degrades.
- Retiring `home/commands/` halves the edit surface for every content
  change and removes a test that exists only to police duplication.

### Negative / trade-offs

- **This reverses part of [#139](https://github.com/pmgledhill102/agentic-coding-config/issues/139).**
  The surface-aware rework of the session commands — `command -v
  chezmoi`, the `chezmoi-unavailable` sentinel, the silent-skip states —
  is the runtime-detection pattern principle 1 replaces. That work was
  correct under the constraint that one text had to serve every surface.
  Removing the constraint makes it unnecessary, not wrong, and it should
  be unwound deliberately rather than left as two overlapping mechanisms.
- **Generated files in the tree.** Composed artefacts are committed, so
  reviewers see machine-written diffs alongside fragment edits. Mitigated
  by CI failing on a stale artefact, which makes the diff mandatory
  rather than optional.
- **Profiles multiply.** Four today, more as providers and environments
  appear. The axes bound the growth but do not stop it, and ADR-0016
  already flagged environment proliferation as a thing to watch.
- **A fragment used by one profile is exercised by one surface.** Rot is
  invisible without principle 7, and principle 7 checks composition, not
  truth: CI can prove the sandbox profile was built correctly and cannot
  prove its contents are still accurate. That remains a human review.
- **The content review is unavoidable and is not small.** Splitting
  content by surface requires deciding, line by line, which surface each
  line is true on. Much of `home/` predates the cloud surface entirely.
- **Variant twins can drift, and no check can catch it.** The premise
  here is now historical: while a skill still had a command copy, the
  pair was guarded by byte-equality, which is what
  `tests/skills-match-commands.py` asserted — both the twins and that
  test have since been retired (principle 3). The consequence survives
  on its own logic, because it never depended on that guard existing.
  Two composed variants of one section are *deliberately* different, so
  byte-equality is structurally unavailable to them: a fix applied to
  one variant and missed on the other is invisible until someone reads
  that surface's artefact. This is the previous entry's failure reached
  by a second route — the first is a fragment nobody revisits, this is a
  pair that stops agreeing — and principle 8's bar is the mitigation
  rather than the fix. Fewer pairs, fewer places for it to happen.
- **An invented difference is indistinguishable from a real one.** The
  build proves a variant was composed correctly, never that it needed to
  exist. #289 is the worked example: a sandbox variant was proposed on the
  premise that a command could not run there, when it was merely not
  installed there. Principle 8's two questions exist because that error is
  cheap to make and expensive to find.

### Explicitly not decided here

Whether the AGENTS.md format supports any import mechanism, and where a
user-level `AGENTS.md` lives for Codex, are unverified — `agents.md` is
blocked by the sandbox egress policy
([#241](https://github.com/pmgledhill102/agentic-coding-config/issues/241)).
This ADR is written so the answer does not matter: composition produces
complete files, so no consumer needs import support. If it turns out
imports are available, they are an optimisation, not a change of shape.

## Alternatives considered

**Compose by import (`@fragment.md`).** Claude Code expands `@path`
imports at launch, four hops deep, so a three-line `CLAUDE.md` could pull
in core plus fragments with no generator at all. Rejected as the general
mechanism because it is Claude-only, and that is established rather than
assumed: the 2026-08-09 review records that Codex "rejects `$ARGUMENTS`,
`$1..$n`, `` !`cmd` `` and `@file` templating as unsupported". An
`AGENTS.md` containing `@agents-core.md` therefore reaches Codex as
literal text, and the content it names is lost silently rather than
loudly.

This was not hypothetical. `home/AGENTS.md` carried `@ephemeral-first.md`
— a Claude-only construct in the file every *other* agent reads — so
every non-Claude agent lost 72 lines of policy until composition inlined
it. Retained as a possible Claude-side simplification, never as the
general mechanism.

**Assemble at install time in each installer.** `bootstrap.sh` and the
chezmoi path each concatenate fragments. Rejected: two implementations of
one logic, on two delivery routes, with no shared test — and the obvious
fix, a shared script, has to be delivered to both, which is the problem
it was meant to solve.

**Symlink `AGENTS.md` and `CLAUDE.md` to one master.** Works only while
the two files are byte-identical. `CLAUDE.md` carries the GitHub MCP
mapping table, which is meaningless to other providers, so they diverge
immediately. Symlinks remain the right tool *within* a profile — one file
serving several vendor paths, as ADR-0016 confirmed for skills.

**Keep runtime conditionals; do nothing.** Rejected. It is the current
state, it costs context on every surface permanently, and it has already
produced one failure where a session could not tell which half of a
document applied to it.

## References

- [ADR-0014](0014-portable-agent-config-architecture.md) — the mechanisms
  being composed
- [ADR-0015](0015-tiered-adrs.md) — tier conventions; this is a user-tier
  decision
- [ADR-0016](0016-capability-delivery-principles.md) — where capability
  lives; principle 6 here restates its principle 3, and its container-created
  `~/.claude` findings are what make this feasible
- #238, #239, #245 — the delivery gaps this is the framework for
- #246 — staleness; principle 7 is build-time correctness, #246 is
  deployed-time freshness, and they are different problems
- #247, #142, #48 — content review, chezmoi shrink, and the commands
  retirement that principle 3 completes
- #265, #289, #291, #293 — principle 8's origin: #265 extended composition
  to skill bodies, #289 asserted a surface difference that turned out not to
  exist, #291 is the amendment that followed, and #293 added its step 0
- #287 — the `start-session-claude-drift` fix that is step 0's worked example
- #288 — the first composition to run under principle 8: 2 variant pairs out
  of 15 sections, against 4 and 9 for the two composed before it
