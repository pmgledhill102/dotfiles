# ADR-0021: Principles for agent sandbox toolchains

- **Status**: Accepted (2026-10-19); amended 2026-11-10 with the per-tool
  classification (#631)
- **Date**: 2026-10-19
- **Tags**: cloud, toolchain, developer-experience, observability, ci
- **Scope**: user (applies to all personal repos and agent surfaces)

## Context

The cloud bootstrap installs a toolchain into every agent sandbox: linters,
scanners, formatters and the pre-commit hook environments that run them. Over
2026-10 it went from 422s to 75s through a series of measured changes
(#606, #607, #612, #613 and #615). Every one of those changes was argued from first
principles that were never written down, and the next decision is bigger:
whether to keep installing the toolchain eagerly at all (#625).

Four principles were in play. Two of them pull against each other, and
without them on record each decision reopens the argument from scratch. This
ADR records them, says how the tension resolves, and gives later decisions
something to cite.

[ADR-0016](0016-capability-delivery-principles.md) decides *where* a
capability lives. This ADR decides how a toolchain capability is judged once
it lives in the environment.

## Decision

### 1. CI parity: the agent runs what CI runs, at the versions CI runs

This is why the sandbox has a toolchain at all. A push that turns CI red
costs a full cycle and some of the reviewer's trust, and an agent that cannot
run the same checks locally finds out only from the pipeline.

- Every check CI runs that can run locally is installed, at the version CI
  pins. A version that differs from CI is a defect, not a nicety: a local pass
  then predicts nothing.
- Versions are pinned in one place and that place is the source for both
  sides (#506).
- A check that cannot run locally is reported as unverified, never as passed.

### 2. Minimise the seconds a watching user waits

Machine seconds and human seconds are not the same cost. **The objective is
the time a person spends waiting on tooling while they are watching**, not
total time and not average time per session.

- The wait before the first prompt of a new environment is the most watched
  moment there is: the user opened it to start work now.
- A wait in the middle of a task the agent is working through alone is close
  to free: the user is in another session or app, or away from the screen.
  Added to a task that already takes several minutes, it is not noticed.
- So a comparison in raw seconds is the wrong comparison. It favours eager
  installs, because the setup-script snapshot makes them nearly free on a
  cache hit, while the cost they do carry lands on the most watched moment.

When the two disagree, watched time wins.

### 3. Decide from data, not feel

Performance and provisioning decisions cite measurements.

- A change that claims a speed-up states its expected effect as a prediction
  and ships the measurement that will confirm or refute it. The claim is a
  prediction until a real run confirms it; #615 is the pattern.
- What cannot be measured from where the decision is made is instrumented
  first (#430, #607), then decided.
- A decision that had to be made without data says so, names the missing
  number, and is revisited when the number exists.

### 4. Few, generic environments

Each cloud environment is configured by hand through the vendor's settings:
its setup line, allowed hosts and variables. That is manual, unversioned work
that drifts, and its cost multiplies with every environment.

- Keep one generic environment per surface where possible, and a small number
  where not.
- Put variation in the versioned setup script, as flags or profiles, rather
  than in another hand-configured environment.
- A specialised environment that exists only to be faster (one that never
  commits, say) is a sign the generic one is paying a watched cost it should
  not. Fix the generic one.

## How the principles resolve against each other

CI parity says install everything CI runs. Watched wait time says do not make
the user wait for it. The resolution is to install the full toolchain, but not
while anyone is watching:

- The setup script keeps only the cheap, always-needed parts.
- The toolchain installs in the background from `SessionStart`, while the
  agent reads and edits.
- Anything that needs a tool waits on that installer, which has usually
  finished by then.

That gives one generic environment both parity and a fast start, which is
also why principle 4 needs no "no commits" environment. Whether background
install actually beats eager install, per tool, is decided by principle 3.
Issue #625 measures watched wait time, and its acceptance records the result.

## Amendment (2026-11-10): the per-tool classification

Principle 3 has now been applied. The data is in
[`docs/toolchain-install-classification.md`](../docs/toolchain-install-classification.md):
103 sessions, 88 builds and 48 sessions of shim events. The criterion is
**watched wait time**, as principle 2 says, not machine seconds.

Two numbers decide it:

- **About 72% of sessions are rebuilds**, and the first prompt arrives about 3 s
  after session start. So on most sessions the whole setup is watched.
- **The toolchain is first needed late**: the first `pre-commit` run is p50 505 s
  after session start, and only about 4% of sessions need it in a watched turn
  before a background install would finish.

At those numbers, eager install costs about 91 watched seconds per session. A
background installer costs about 2 s at a median install, and 21 s at a
pessimistic bound that applies p90 to every session.

The classification:

| Class | Tools |
| --- | --- |
| **Eager** (setup script) | the toolkit, helpers, skills, shims, gcloud, gh, and the global git hook with `core.hooksPath` |
| **Background, first in the queue** | pre-commit, gitleaks, shellcheck, actionlint |
| **Background** | cspell, markdownlint-cli2, semgrep, hadolint, trivy, terraform, tflint, the tflint ruleset, checkov, golangci-lint, and the pre-commit hook-environment warm |
| **On-demand** | none |

The background installer has three obligations:

- **The git hook waits for it, and never skips.** The hook is installed eagerly
  for exactly this reason. A commit that arrives while the install is still
  running waits for it, bounded well under the agent's 120 s foreground
  timeout. If the bound runs out, the commit fails with a "still installing"
  message rather than passing unchecked (principle 1).
- **A failure is reported per tool.** One stalled download costs one tool. The
  installer writes its own manifest, and a failed tool reads as `degraded`,
  never as absent (#631, #738).
- **Nobody watches it, so it may retry patiently.** A backoff measured in
  minutes is fine in the background, where it would not be on the setup path.

On-demand is empty on purpose. An inline install inside a commit runs within one
agent Bash call, close to that call's timeout, and a commit that waits on the
background installer is strictly better.

The classification is revisited when the manifest `timings=` line shows the
predicted saving (about 93 watched seconds per session) not arriving, or when
the shims record a non-zero `blocked_ms` often enough to matter.

## Consequences

### Positive

- A provisioning change can be judged against stated criteria rather than
  argued afresh.
- Watched wait time gives a single number to optimise that matches what the
  user experiences.
- Fewer environments means less hand configuration to replicate and drift.

### Negative / trade-offs

- Background install spends CPU and network in every session, including
  cache-hit sessions that currently get the toolchain for free. Accepted:
  that cost is unwatched.
- A failed background install surfaces mid-session rather than at build
  time. The installer must report it clearly and never as an absent tool.
- Measuring watched time needs instrumentation inside the container (hook
  timestamps, PATH shims) and a durable sink (#431). Until those exist,
  principle 3 limits what can be decided.

## References

- [#625](https://github.com/pmgledhill102/agentic-coding-config/issues/625):
  measure watched wait time and decide eager vs background per tool
- [#324](https://github.com/pmgledhill102/agentic-coding-config/issues/324):
  observability epic; [#430](https://github.com/pmgledhill102/agentic-coding-config/issues/430)
  bootstrap timings and cache marker;
  [#431](https://github.com/pmgledhill102/agentic-coding-config/issues/431)
  telemetry client and sink
- [#506](https://github.com/pmgledhill102/agentic-coding-config/issues/506):
  one declared tool manifest
- [ADR-0016](0016-capability-delivery-principles.md): where capability lives
- [`docs/cloud-sandbox-design.md`](../docs/cloud-sandbox-design.md) §2, §5:
  the snapshot cache and the just-in-time install verdict this ADR refines
