# ADR-0015: Tiered ADRs — personal, user-level, and repo-level decision records

- **Status**: Accepted (2026-08-09, ratified via PR #143)
- **Date**: 2026-08-09
- **Tags**: workflow, adr, documentation
- **Scope**: user (applies to all personal repos)

## Context

Per-repo ADRs have proven one of the highest-value habits in this
estate: decisions survive context loss, agents can read the "why" before
proposing changes, and `/repo-review` audits them for currency.

But decisions don't all have repo-sized scope, and the estate already
routes around that fact informally: `paul-context/decisions/` holds
private cross-repo decisions (the a-c-c split, the journal-inbox
pattern), this repo's `adrs/` holds agentic-workflow decisions that
affect every repo (GitHub Issues for tracking, and now ADR-0014), and
project repos hold their own. The tiers exist; nothing declares them,
so a session in a project repo has no reliable way to discover that a
user-level decision applies, and there is no convention for a repo
deviating from a higher-tier decision.

## Decision

Make the existing three tiers explicit, with declared scope, a
discovery path, and supersession rules — no new tooling or repos.

### The tiers

| Tier | Home | Holds | Visibility |
| --- | --- | --- | --- |
| **Personal** | `paul-context/decisions/` | Life/estate decisions, private rationale, repo registry choices | Private |
| **User** | `agentic-coding-config/adrs/` | How I work with agents and repos, across the estate (workflow, tooling, conventions) | Public |
| **Repo** | `<repo>/adrs/` | Architecture and technology choices for that repo | Repo's own |

### Conventions

1. **Every ADR declares its scope** with a `Scope:` header line —
   `personal`, `user`, or `repo` — so a reader (human or agent) knows
   the blast radius without inferring it from the repo it sits in.
2. **Placement follows scope, not convenience.** The authoring test:
   *would this decision still bind if the current repo were archived?*
   If yes, it is not repo-tier. Public-safe cross-repo decisions go to
   the user tier here; anything private goes to the personal tier.
3. **Discovery is via the policy file.** The portable policy core
   (ADR-0014) states where user-tier ADRs live; each repo's own policy
   file (`CLAUDE.md`/`AGENTS.md`) already points agents at its local
   `adrs/`. Higher tiers are consulted on demand — linked, not copied,
   so there is one source of truth and no sync burden.
4. **Lower tiers may deviate, explicitly.** A repo ADR can override a
   user-tier decision for that repo only, and must reference the ADR it
   deviates from and why (mirroring how repo CLAUDE.md label taxonomies
   already override the a-c-c defaults). Silent divergence is the
   failure mode this rule exists to prevent.
5. **Numbering stays per-home** (each ADR directory keeps its own
   sequence); cross-tier references use full URLs, which also work from
   sandbox sessions with no local clones.
6. **`/repo-review` audits tier fit**: flag ADRs whose content outgrew
   their declared scope (a repo ADR that other repos now depend on
   should be promoted to user tier, with a stub left behind).

## Consequences

### Positive

- A decision made once binds everywhere it should, and agents can find
  it from any repo — including sandbox sessions, via URLs.
- Deviations become visible and reasoned instead of silent drift.
- Zero new infrastructure: three existing homes, one new header line,
  one authoring question.

### Negative / trade-offs

- Scope classification is a judgment call; the review backstop is
  `/repo-review`, not enforcement.
- Personal-tier decisions remain invisible to sandbox sessions (private
  repo) — public-safe summaries must be duplicated to the user tier
  when agents need them, a deliberate cost of the public/private split.
- Promoting an ADR between tiers moves its URL; stubs mitigate but
  don't eliminate stale links.

## Alternatives considered

- **Single central ADR repo for everything** — breaks "decision lives
  with the code it governs" for repo-tier ADRs and forces
  public/private into one home; rejected.
- **Copying applicable user ADRs into each repo** — guarantees drift;
  linking beats copying; rejected.
- **A dedicated shared-tier per repo-group** (e.g. per-domain ADR
  repos) — no current grouping needs it; the user tier covers today's
  sharing; revisit if a genuine multi-repo domain emerges.
