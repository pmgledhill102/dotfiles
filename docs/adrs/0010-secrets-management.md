# ADR-0010: Secrets management strategy

- **Status**: Proposed (decision in progress — currently leaning Bitwarden)
- **Date**: 2026-04-26
- **Tags**: secrets, security

## Context

The repo needs a way to handle two kinds of sensitive material:

1. **Repo-shipped material** — files that should travel with the dotfiles
   but must not be readable in plaintext on GitHub (e.g. `~/.secrets`
   sourced by run scripts, the age key itself).
2. **Per-machine material** — credentials a fresh machine needs at apply
   time (Google Developer Knowledge MCP API key, GitHub PAT, SSH agent
   socket, etc.).

The current state of the repo blends two approaches:

- `specs/REQUIREMENTS.md` and `home/dot_claude/README.md` document an
  age-encrypted `~/.secrets` flow, with the age private key copied into
  `~/.config/chezmoi/key.txt` from a secure store before
  `chezmoi init --apply`.
- The `personal` Brewfile already installs `bitwarden-cli` and the
  Bitwarden cask. The `dotclaude` helper reads the Google Developer
  Knowledge API key from Bitwarden at MCP setup time. Beads
  `dotfiles-7r3` was closed with "Superseded by Bitwarden approach".

So in practice, Bitwarden is doing real work for the Claude MCP setup,
while age remains the documented path for repo-shipped secrets — and the
two have not been reconciled.

## Direction (leaning, not yet decided)

Lean towards **Bitwarden as the source of truth for human-managed
credentials**, including the seed needed to bootstrap a fresh machine.

- `dotclaude` already pulls the Google Developer Knowledge MCP key from
  Bitwarden. Extend the same pattern to any other API key the run scripts
  need.
- Keep `age` available as an option for files that genuinely need to
  travel inside the repo (rare). If `age` ends up unused, retire it.
- Document the bootstrap path: install Bitwarden CLI, `bw login`, then
  `chezmoi init --apply` — the run scripts pull what they need at apply
  time.

## Open questions

- Should Bitwarden be the *only* store, or is there value in keeping
  `age` for repo-shipped encrypted material?
- Bootstrap chicken-and-egg: how does a fresh machine authenticate to
  Bitwarden CLI? (Master password input is fine interactively — what
  about CI?)
- Where do non-interactive secrets (CI runners, minimal tier servers)
  come from? Probably env-var injection, but worth being explicit.
- Is there value in caching unlocked secrets in `~/.secrets` after first
  fetch, or always fetch on demand?

## Consequences (if Bitwarden path is chosen)

### Positive

- One secret store across the household, already paid for and in daily
  use.
- Native CLI plus an SSH agent — both already wired in the zshrc.
- No local key file to copy onto every new machine.

### Negative / trade-offs

- Requires interactive unlock (`bw unlock`) at provisioning time.
- CI and minimal tier need an alternative (env vars, OIDC, sops).
- A Bitwarden outage means MCP servers can't reconfigure; degrade
  gracefully.

## Alternatives considered

- **age-only** — current documented spec; works without external
  dependencies but pushes per-machine key management onto the user.
- **1Password CLI** — capable, but adds another paid service.
- **sops + cloud KMS** — strong story for teams; overkill for a
  single-user setup.
- **Plain `~/.secrets` outside chezmoi** — what gets done by accident;
  no version-controlled audit trail, easy to lose.

## Next steps

This ADR will be updated to **Accepted** once the path is finalised. Open
questions above need answers before that change.
