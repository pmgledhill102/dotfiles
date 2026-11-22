# ADR-0014: Portable agent-config architecture (skills-first, provider-neutral core)

- **Status**: Accepted (2026-08-09, ratified via PR #143), **amended
  2026-08-13 by [ADR-0016](0016-capability-delivery-principles.md)** —
  which narrows decision 3: per-repo marketplace configuration is not the
  delivery route for everything it implies here. Read 0016 alongside this.
- **Amended**: 2026-08-27 by [#312](https://github.com/pmgledhill102/agentic-coding-config/issues/312)
  — **decisions 3, 4, 5 and 7 no longer hold.** The dual-manifest plugin was
  published, never adopted, and has been withdrawn: `dotfiles` declined it
  ([dotfiles#392](https://github.com/pmgledhill102/dotfiles/issues/392)) and
  the marketplace listing was judged not worth maintaining for anyone else
  (#48, closed). Distribution stays on the two channels this ADR set out to
  replace — the chezmoi archive external and `cloud/bootstrap.sh`; hooks stay
  declared in `settings.json` with their scripts at `~/.claude/bin/`; `home/`
  is not shrinking to a residue. Decisions 1, 2 and 6 stand, and decision 1
  has since completed: the `home/commands/` twins were retired in #313,
  leaving skills as the only form. The reason the plugin failed is specific
  and worth keeping — the marketplace declared `"source": "./home"`, which is
  the `claude-workstation` composition, so it could only ever ship
  workstation-composed context. See
  [ADR-0018](0018-composing-agent-context-per-surface.md) for the
  per-surface composition that turned that from a detail into a defect.
- **Amended**: 2026-10-22 by [ADR-0023](0023-claude-code-reads-agents-md-as-a-fallback.md)
  — **decision 2's mechanism no longer holds; its aim does.** The policy core
  is maintained once, but Claude Code does not consume it through a
  `CLAUDE.md` → `@AGENTS.md` import bridge: ADR-0018 composes a `CLAUDE.md`
  per Claude surface from the same fragments instead. A user-level
  `AGENTS.md` is not read by Claude Code at all, so none is delivered to it.
- **Date**: 2026-08-09
- **Tags**: claude-code, codex, opencode, skills, plugins, architecture
- **Scope**: user (applies to all personal repos and agent surfaces)

## Context

This repo's content is delivered exclusively by chezmoi mounting `home/`
at `~/.claude/` on local machines. Two shifts have broken that model's
coverage:

1. **Most work now runs in cloud sandboxes**, which never read
   `~/.claude/` — on Claude and Codex alike, only repo-committed config,
   managed settings, and environment setup scripts reach a session.
2. **Multiple providers are in play** (Claude Code, OpenAI Codex,
   OpenCode), and the ecosystem has standardised: AGENTS.md for
   instructions, the open Agent Skills spec (SKILL.md, ~44 clients) for
   workflows, Claude-shaped `hooks.json` now shared by Codex, plugin
   marketplaces on both Claude and Codex — with Codex reading Claude's
   plugin manifest directly.

The full evidence base is in
[#136](https://github.com/pmgledhill102/agentic-coding-config/issues/136)
and the [strategic review](../docs/reviews/strategic-review-2026-08-09.md).

## Decision

Restructure this repo around a **provider-neutral content core with thin
per-provider adapters**, distributed as a plugin, with an explicitly
machine-local residue left on the chezmoi path.

1. **Workflows become skills.** The command library converts from
   Claude-format `commands/*.md` to SKILL.md skills (Agent Skills spec).
   Skills are the portable unit: native in Claude Code, Codex (its
   primary customisation unit), OpenCode, Gemini CLI, Cursor and
   Copilot. Skill bodies avoid `$ARGUMENTS`/`` !`cmd` ``/`@file`
   templating, which Codex rejects; arguments arrive as free text.
2. **Policy becomes an AGENTS.md-format core.** The portable part of
   `home/CLAUDE.md` (git workflow, work tracking, process guidelines)
   is maintained once in AGENTS.md form. Claude Code consumes it via
   the documented `CLAUDE.md` → `@AGENTS.md` import bridge;
   Codex/OpenCode read it natively. Claude-specific guidance (MCP tool
   mappings) lives in a Claude adapter, not the core.
3. **Distribution is a dual-manifest plugin in this repo.** The repo
   becomes its own marketplace: Claude `.claude-plugin/marketplace.json`
   plus the portable `plugin.json` / `.agents/plugins/marketplace.json`
   metadata Codex discovers. One plugin ships skills, hooks and the
   policy core to both providers.
   - **Local machines**: plugin installed at user scope (bootstrap step
     in dotfiles).
   - **Cloud sessions**: project-scope enablement in each repo's
     committed `.claude/settings.json` (`extraKnownMarketplaces` +
     `enabledPlugins`), added by `/setup-common` so every repo gains it
     on its next setup refresh.
4. **Hooks port to the shared `hooks.json` shape** (identical event
   names on Claude and Codex). Scripts move into the plugin and are
   referenced plugin-relative, not via `~/.claude/bin/`. An OpenCode JS
   shim is written only if OpenCode becomes a daily driver.
5. **The machine-local residue stays on chezmoi**: permissions
   allowlist, statusline, machine-specific policy fragment, MCP wiring
   (in dotfiles). The `home/` external shrinks to exactly this set,
   using the existing `retired-paths` machinery for the cutover.
6. **The permissions allowlist is frozen.** It remains a local-machine
   convenience; no proactive curation; additions only on real local
   friction. It is not ported to other providers (no common model
   exists) and is absent from cloud by design — the sandbox risk model
   makes that acceptable.
7. **Issue #48 is re-scoped** to implement this architecture
   (skills-first, dual manifest) rather than a commands-directory port.

## Consequences

### Positive

- One content core reaches local Claude, cloud Claude, Codex (local and
  cloud), and OpenCode — the "lost personal content in sandboxes"
  problem is closed by construction, not per-machine sync.
- Skills' progressive disclosure preserves the repo's low-context-cost
  design principle; nothing loads until invoked.
- The chezmoi surface shrinks to config that is genuinely
  machine-local, ending the false expectation that `~/.claude/` content
  follows the user everywhere.
- Betting on published specs (AGENTS.md, Agent Skills) replaces betting
  on one vendor's directory layout.

### Negative / trade-offs

- A migration period with content in two shapes (commands and skills);
  the `retired-paths` mechanism must be driven carefully to avoid
  duplicate commands on local machines.
- Cloud reach requires a one-time `.claude/settings.json` commit per
  repo (mitigated by folding it into `/setup-common`).
- Codex parity for argument-templated commands means rewording, not
  mechanical conversion.
- The public repo constrains content to public-safe material (already
  true; private context stays in paul-context).

## Alternatives considered

- **Keep chezmoi-only delivery** — leaves every cloud session without
  personal config; rejected as the status quo being reviewed.
- **Per-repo `.claude/` duplication** — copies commands/skills into
  every repo; N-way drift, no user-level story; rejected.
- **Cloud environment setup scripts writing `~/.claude` / `~/.codex`
  in-container** — undocumented whether either cloud agent honours it;
  usable as an experiment, not a foundation.
- **Claude-only plugin (original #48 shape)** — solves cloud Claude but
  leaves Codex/OpenCode out just as the formats converge; superseded by
  the dual-manifest approach.
