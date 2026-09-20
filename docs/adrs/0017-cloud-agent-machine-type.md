# ADR-0017: `cloud-agent` machine type for ephemeral agent sandboxes

- **Status**: Accepted
- **Date**: 2026-09-20
- **Tags**: layering, packages, agents

## Context

[ADR-0003](0003-machine-type-tiering.md) established three tiers, all of
which assume a machine someone owns and administers. An ephemeral agent
sandbox is neither: it is created per session, thrown away afterwards, has
no human at its terminal, and typically runs as root with no `sudo` binary
installed at all.

Because chezmoi never reached those sandboxes, their install list grew a
second owner elsewhere — and two owners of one list produced a run of "the
sandbox lacks what the laptop has" defects. Moving that ownership here
needs a tier that means "ephemeral agent sandbox", installable with nothing
present to answer a prompt.

Reusing `minimal` was the obvious shortcut and is wrong twice over.
`minimal` means "headless server": durable, administered, and a shell
someone logs into. Overloading it would mean no config could ever tell the
two apart, and the difference is exactly what needs expressing.

## Decision

Add a fourth `machine_type` value, `cloud-agent`, and make the
non-interactive path a first-class entry point.

- `home/.chezmoi.toml.tmpl` offers it as a fourth `promptChoiceOnce` value
  with its own apt arm: `minimal`'s list minus `zsh` and `tmux` (nothing is
  typed here), plus `unzip`/`zip` (unpacking archives is routine agent work).
- The `~/.claude` external is delivered to `personal` **and** `cloud-agent`,
  and still withheld from `work` and `minimal`. This does not reopen
  [ADR-0016](0016-agent-tooling-is-personal-tier.md): an agent sandbox *is*
  personal-org work, so the entitled set grows to the machines that should
  always have had it.
- `install.sh` takes a machine type — `DOTFILES_MACHINE_TYPE` or
  `--machine-type` — and when given one, pre-seeds
  `~/.config/chezmoi/chezmoi.toml` instead of wiping it. The positional
  argument stays the branch name, so the documented `-- feature-branch`
  form is unaffected.
- Escalation is resolved rather than assumed, in `install.sh` and in
  `run_onchange_install-ubuntu-packages.sh.tmpl`: root needs none, a
  non-root user without `sudo` is told so.
- Everything that exists for a human at a terminal is skipped on this tier:
  Oh My Zsh and its plugins, the default-shell change, rustup, nano syntax
  highlighting, Ghostty terminfo, lazygit, PowerShell, GUI configs, tmux.
- A CI job (`cloud-agent-install`) installs the tier inside a bare
  `ubuntu:24.04` container — root, no `sudo`, stdin closed — and asserts
  that `~/.claude` arrives.

**The pre-seed is the only mechanism that answers the prompt.** chezmoi's
`--promptChoice` flag does not work with `promptChoiceOnce`: it is accepted,
ignored, and `init` blocks on the prompt anyway. This has now bitten twice
(CI, then this work), so it is recorded here, in `install.sh`, in the README
and in `docs/TESTING.md` rather than only in a workflow comment.

## Consequences

### Positive

- Sandbox provisioning is reproducible from this repo, by the same
  mechanism as every other machine — one owner of the install list.
- "Ephemeral agent sandbox" is now expressible in config, so behaviour can
  differ from a headless server without guesswork.
- A non-interactive `install.sh` is useful beyond agents: container builds
  and provisioning scripts get it for free.

### Negative / trade-offs

- ADR-0003 predicted this cost and it is real: a fourth tier touches every
  conditional list, and `{{ else }}` arms silently absorb the new value.
  Where that fallback is wrong the arm is now explicit; where it is right
  (winget — there are no Windows agent sandboxes) a comment says so.
- Two conditions now have to agree about who is entitled to the agent
  config: the external's gate and the removal script's exemption. If they
  drift, an entitled machine deletes what it just received. Both carry a
  comment saying so, and the CI job fails if the delivery half regresses.
- `install.sh` gains argument parsing, and a `DOTFILES_BOOTSTRAP_DRY_RUN`
  hook that exists for CI. The alternative was a test that either proved
  nothing or installed from the remote default branch.

## Alternatives considered

- **Reuse `minimal`** — see Context. Conflates two different kinds of
  machine permanently.
- **Keep the sandbox installer in `agentic-coding-config`** — the status
  quo, and the source of the drift this replaces.
- **`--promptChoice` on the init line** — does not work with
  `promptChoiceOnce`, and fails silently, which is worse than not working.
- **Machine type as a second positional argument to `install.sh`** — would
  collide with the documented branch-name argument.
