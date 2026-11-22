# ADR-0020: Surface matrix — OS × persistence × machine type, and which repo delivers what where

- **Status**: Accepted (2026-10-20)
- **Date**: 2026-10-20 (proposed 2026-08-29)
- **Tags**: architecture, portability, delivery, dotfiles, windows, sandbox
- **Scope**: user (applies to all personal repos and agent surfaces; binds `dotfiles` and `agentic-coding-config`)

## Context

Two repos put things onto machines. `dotfiles` makes a machine consistent —
packages, shell, terminal, editor, platform defaults — via chezmoi, on
macOS, Ubuntu, WSL and native Windows, with `personal` / `work` / `minimal`
install tiers. `agentic-coding-config` composes agent context and skills
per profile ([ADR-0018](0018-composing-agent-context-per-surface.md)) and
delivers them: via chezmoi's external on a workstation, via
`cloud/bootstrap.sh` in a cloud sandbox.

Three things went wrong at the seam between them.

**The rules for one repo were read as rules for both.** The workstation
environment fragment said Windows is out of scope. It meant: no PowerShell,
no Windows paths, in *this repo's content*. It was taken to mean dotfiles
should drop Windows, which dotfiles supports on purpose and tests in CI.
Nothing said what Windows gets.

**Two install lists drift.** `cloud/bootstrap.sh` installs a toolchain
(gcloud, pre-commit, gh, terraform, linters) that dotfiles' Brewfile also
installs, and the two drifted: #240 (no terraform in sandboxes), #254 (no
pre-commit), #280 (wrong golangci-lint), #316 (no semgrep), #323 (gcloud too
heavy).

**One "environment" axis was carrying two facts.** `env-workstation` asserted
both *macOS/zsh/BSD* and *durable, chezmoi-managed, a human present*. Those
correlate on the laptop and nowhere else. WSL is durable and GNU. A cloud
sandbox is ephemeral and GNU. Native Windows is durable and not POSIX.

## Decision

### 1. Three axes, and only three

| Axis | Values | What flips on it |
| --- | --- | --- |
| **OS** | `macos` · `ubuntu` · `windows` | package manager, shell, which scripts can run, BSD vs GNU userland |
| **Persistence** | `durable` · `ephemeral` | delivery route (chezmoi apply vs one-shot idempotent script), whether a human is present to answer prompts, setup-time budget, whether GUI applications make sense |
| **Machine type** | `personal` · `work` | whether agent config is delivered at all (dotfiles' `machine_type`) |

`ubuntu` covers Ubuntu, Debian, WSL and every cloud sandbox: one userland.
"Fat client" is not an axis — it is `durable` (a person sits here) and is
derived. Provider (Claude / Codex) is internal to `agentic-coding-config`
and stays out of this matrix.

The axes are not one enum doing two jobs. dotfiles' `machine_type` is its
delivery selector: what gets installed, and whether agent config is
delivered at all. OS × persistence is this repo's fragment selector: which
environment fragments compose into a profile.

A fourth axis is added only when a decision demonstrably flips on it and
on nothing already here.

### 2. Which repo delivers what

- **Tools are declared once, and installed per surface.** One tool manifest
  in `home/standards/` (#506) states, per tool, its version or floor, which
  surfaces it belongs on, and its source on each surface. Each surface keeps
  the installer native to it: dotfiles' Brewfile on macOS, dotfiles' apt data
  on Linux and WSL, and `cloud/bootstrap.sh` in a cloud sandbox. CI asserts
  the installers agree with the manifest. A tool may be excluded from a
  surface on weight grounds, and the manifest records the reason, because the
  exclusion surfaces downstream as *not checked* rather than as a pass.
- **The bootstrap stays the sandbox installer.** This is
  [ADR-0016](0016-capability-delivery-principles.md) principle 2 — a
  toolchain is an environment capability, reaching the cloud via setup
  script and allowed domains — and
  [ADR-0021](0021-agent-sandbox-toolchain-principles.md) builds on it.
  It keeps its degrade-and-record failure semantics: a capability that fails
  is named in the manifest as degraded, and the run continues.
- **`agentic-coding-config` owns agent content**: composed AGENTS/CLAUDE
  files, skills, hooks, and the retired-paths list.
- A coordinate that has no agent profile receives **no agent config**,
  enforced at delivery, not left to whichever fragment happens to compose.

Install ownership does not reach the network. An egress block — #241's
registry hosts, #376's IAP relay — lives in the environment's allowed-domains
list, which neither repo owns.

### 3. Support tiers, per coordinate

| Coordinate | Tier | dotfiles | agentic-coding-config |
| --- | --- | --- | --- |
| macos · durable · personal | **primary** | full (`personal`) | full: `claude-workstation` |
| macos · durable · work | supported | `work` | none (dotfiles ADR-0016) |
| ubuntu · durable · personal (WSL, a VM) | supported | `personal` minus GUI | WSL: `claude-wsl`, delivered by an `archive-file` external (#569, dotfiles#481); a VM: none |
| ubuntu · ephemeral · personal (cloud sandbox) | supported | not applied | `claude-cloud-sandbox` / `codex-cloud-sandbox` |
| windows · durable · personal (the desktop) | **best-effort** | `personal` (WinGet, PowerShell, Windows Terminal) | none until an `env-windows` profile exists (#417) |
| windows · durable · work | best-effort | `work` | none |

Tier meanings:

- **primary** — fixed now, from wherever the user is; CI-tested; every
  new capability lands here first.
- **supported** — CI-tested; defects are queued alongside primary work and
  fixed from the laptop; narrower scope by design (no GUI on a headless
  coordinate).
- **best-effort** — install stays CI-tested so it does not rot; defects are
  fixed opportunistically, at that machine, with no queue position. Issues
  on this tier carry a `surface:` label so they can be excluded from
  what-can-I-do-from-here views without being closed.

"None" on a Windows row is the target, not today's behaviour: until #417
lands, that machine still receives the macOS workstation profile through
dotfiles' external. WSL's route is decided: dotfiles narrows the archive's
`include` to skip `home/CLAUDE.md` there, and a second external of type
`archive-file` extracts `profiles/claude-wsl/CLAUDE.md` from the same tarball
into its place (dotfiles#481). Windows takes the same route once its profile
exists.

### 4. Agent surfaces, as a set

The surfaces an agent runs on are a closed list, so a reader of an old
framing does not mistake a dropped one for an undocumented one:

| Surface | Status | Condition that would change it |
| --- | --- | --- |
| Workstation (macOS) | supported | — |
| Cloud sandbox (Claude, Codex) | supported | — |
| WSL | profile composed, delivery pending | dotfiles#481 lands and is verified on the machine (#569) |
| CloudCoop (bespoke cloud sandbox) | **retired** (#423) | hosted runners with the credential-broker pattern now meet its requirements |

Maturity is not tracked in a hand-maintained table. Where it is tracked at
all it derives from something that runs — today, the composition guard in
`tests/compose-context.py`.

### 5. Environment fragments follow the axes

`context/fragments/` has one fragment per axis value that has content:
`os-macos`, `os-ubuntu`, `persist-durable`, `persist-ephemeral`. A profile
names one of each. The composition guard in `tests/compose-context.py`
checks the pair is legal: no `persist-ephemeral` with `os-macos`, and no
`os-windows` at all, because no profile exists for it.

*Amended 2026-10-22 (#569):* a profile may also name one **host fragment**.
This is an overlay, not a fourth axis. It carries what being inside another
OS adds to one coordinate, and the manifest pins it to that coordinate.
`env-wsl` is the first. WSL is `os-ubuntu` + `persist-durable`, and it also has
the Windows host one `cd` away at `/mnt/c`. That rule depends on nothing the
three axes carry. The guard rejects a host fragment on any other coordinate,
and it requires each of an output's environment fragments exactly once.

### 6. Deviation

Per [ADR-0015](0015-tiered-adrs.md), a repo may deviate from this matrix
only by naming this ADR and saying why.

## Consequences

### Positive

- "Is Windows supported?" has an answer with a tier attached, and dotfiles'
  Windows issues stop reading as policy violations.
- The sandbox-lacks-X family becomes one declared list with several
  installers held to it, instead of two lists that drift silently.
- Each environment fragment says one kind of thing, so a new surface reuses
  the halves it shares instead of restating a userland.

### Negative / trade-offs

- Several installers remain, so the manifest only helps if CI actually
  checks each one against it. A manifest nobody asserts is a third list.
- Four environment fragments instead of two, and a guard to keep their
  pairings honest. More files; each says less.
- Until #417 lands, and dotfiles#481 for WSL, those machines keep receiving
  the macOS profile, which is the status quo and is not made worse.

## Alternatives considered

- **dotfiles owns installs on every coordinate, including ephemeral.** This
  ADR's 2026-08-29 draft, accepted in direction on 2026-09-20 with a fourth
  `machine_type`, `cloud-agent`, and then rejected the same day once built
  (dotfiles#426, dotfiles#427; reasoning in #506). `cloud-agent` changed what
  *kind* of output dotfiles produces — packages, no files — rather than how
  much of a machine it configures; each tier added Go-template conditionals
  across the repo; the built tier shipped config for tools it did not
  install, wrote into the harness's own `~/.claude.json`, and installed none
  of the sandbox toolchain; and it contradicted ADR-0016 principle 2.
- **One flat "surface" enum** (`laptop`, `sandbox`, `wsl`, `windows`).
  Rejected: every new surface is a new value that must restate every
  fact, and WSL and the sandbox would restate the whole Ubuntu userland
  twice.
- **Drop native Windows.** Rejected: it is used, a little, for Claude Code,
  and dotfiles already carries a working install. Keeping it at best-effort
  costs a label and a README table.
- **Give Windows a minimal agent profile now.** Deferred to #417: nothing
  composes for it today, and the delivery route is undecided.

## References

- [ADR-0015](0015-tiered-adrs.md) (tiers),
  [ADR-0016](0016-capability-delivery-principles.md) (capability delivery),
  [ADR-0018](0018-composing-agent-context-per-surface.md) (composition),
  [ADR-0019](0019-agents-md-is-the-repo-instruction-source.md) (`AGENTS.md`
  as repo instruction source),
  [ADR-0021](0021-agent-sandbox-toolchain-principles.md) (sandbox toolchain
  principles)
- [#353](https://github.com/pmgledhill102/agentic-coding-config/issues/353)
  (this ADR, and the decision reconciling §2),
  [#506](https://github.com/pmgledhill102/agentic-coding-config/issues/506)
  (the tool manifest),
  [#423](https://github.com/pmgledhill102/agentic-coding-config/issues/423)
  (the surface set), #354 (the fragment split), #417 and #569 (Windows and
  WSL profiles)
- Sandbox drift: #240, #254, #280, #316, #323
