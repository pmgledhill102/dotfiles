# /end-session — Design & Retrospective

This document captures the reasoning behind the `/end-session` slash command's shape — in particular why its Phase 1 gather runs inside a dotfiles-managed shell script rather than inline.

- Command spec: [`home/dot_claude/commands/end-session.md`](../home/dot_claude/commands/end-session.md)
- Scripts: [`home/dot_claude/bin/`](../home/dot_claude/bin/)
- Beads issue: `dotfiles-7rw` (Parallelize /end-session gather via dotfiles scripts)

## What `/end-session` does

Single-invocation tidy-up to leave a repo at a verifiable "clean walk-away" point: fetch + prune, rebase `main`, prune dead branches (merged and squash-merged), surface outstanding PRs / stashes / in-progress beads issues / worktrees, optionally push beads to Dolt, then offer the retrospective.

Every step is classified by how much human judgment it needs:

- **Tier 1** — auto-act, no prompt (fetch, pull, read-only lists).
- **Tier 2** — auto-act behind one batched confirmation (branch deletes, push-if-ahead).
- **Tier 3** — surface only, user drives (open PRs, in-progress issues, stashes, user-started processes).

When in doubt we downgrade a tier rather than upgrade.

## Retrospective — why the script split exists

Two observations from using the command in anger.

### Observation 1 — recurring approval prompts

Two steps of Phase 1 triggered explicit approval prompts every run, even though every individual sub-command in them was already on the permission allowlist:

- Step 1 (state gather) — a compound `echo "===pwd==="; pwd; echo "===status==="; git status ...` block.
- Step 6 Batch B (squash-merged detection) — a pipeline of `git for-each-ref | awk | grep | while read … git diff …`.

**Root cause.** The Claude Code permission matcher sees a Bash tool call as a single command string. A pattern like `Bash(git status *)` matches a call whose command begins with `git status` — it does **not** match a compound block that happens to contain `git status` alongside other commands. So compound blocks never match a narrow allow rule no matter how many of their pieces are allowed individually.

Three ways to fix this:

1. Pre-approve the exact compound strings. Brittle — any whitespace edit breaks the match.
2. Split the block into N individual tool calls. Works for Step 1 but not for Step 6 Batch B's pipeline, and inflates tool-call count / output noise.
3. Extract the compound logic into a script and allow the script's path. One rule; shellcheck-testable; editable without reshuffling permissions.

We picked (3).

### Observation 2 — round-trip latency dominates

The original Phase 1 issued ~14 sequential Bash tool calls. For each one: the model emits the call, the runtime runs the command (often network-bound — `git fetch`, `gh run list`, `gh pr list`, `bd dolt push`), the result comes back, the model reads it and emits the next call. With a large context (1M), every round trip costs meaningful seconds of model latency **independent of** the command's own runtime.

Of those 14 calls, 8 are independent read-only queries with no inter-dependencies — they can all run in parallel after `git fetch`. Serialising them doubled the latency for no correctness benefit.

Extracting the gather into a script that runs `git fetch` first, then fans out the 8 reads with `&` + `wait`, collapses:

- ~8 sequential tool calls into 1.
- Summed serial network latency into max-of-parallel.
- ~7 model-turn round-trips (each ~3–8s at 1M context) into 1.

Measured on this repo (2026-04-21): Phase 1 gather wall time dropped from an estimated ~70s total to ~15s end-to-end (fetch-dominated). The remaining steps (Tier 2 destructive actions, `bd dolt push`, summary) are serial because they either need a y/n or depend on prior output.

### Decision

Extract two scripts, land one allow rule, rewrite Phase 1 to consume sectioned output. `/retrospective` was deliberately left alone — it's short, doesn't have multi-line approval blockers, and its value is in agentic reasoning rather than fixed commands; parallelisation would buy nothing.

## Architecture

```text
/end-session  (home/dot_claude/commands/end-session.md)
    │
    ├── Step 1  → ~/.claude/bin/end-session-gather-state
    │                  │
    │                  ├── git fetch --all --prune --tags   (blocks)
    │                  └── parallel fan-out:
    │                        ├── local_state   (status, branch, log, origin)
    │                        ├── stashes
    │                        ├── worktrees
    │                        ├── merged_brs
    │                        ├── main_ci       (gh run list)
    │                        ├── open_prs      (gh pr list)
    │                        ├── bd_progress   (if .beads/)
    │                        └── bd_preflight  (if .beads/)
    │
    ├── Steps 2, 3, 6A, 8–12  → read sections from gather output (no tool call)
    ├── Step 4          → prompt on dirty/unpushed (reads local_state)
    ├── Step 5          → git checkout main + git pull --rebase
    ├── Step 6 Batch B  → ~/.claude/bin/end-session-squash-merged
    ├── Step 7          → git log origin/main..HEAD (conditional push)
    ├── Step 13         → background process housekeeping
    ├── Step 14         → bd dolt push
    └── Step 15         → agent-authored summary
```

## Output protocol — gather script

```text
===<section> (exit=<N>)===
<section stdout+stderr>
```

Sections, in emission order: `fetch`, `local_state`, `stashes`, `worktrees`, `merged_brs`, `main_ci`, `open_prs`, `bd_progress`, `bd_preflight`. The two `bd_*` sections are absent entirely when `.beads/metadata.json` is missing.

Progress pings go to stderr (`[gather] …`) so a human watching sees something move without polluting the parseable stream on stdout.

### Exit code semantics

| Outcome | Meaning |
| --- | --- |
| `exit=0`, empty content | Clean result — treat as "none". |
| `exit=0`, content | Normal data — parse for the corresponding step. |
| `exit != 0`, content `gh-unavailable` | Silent skip (no `gh` installed). Steps 3 and 8 degrade. |
| `exit != 0`, other content | Real error — surface before continuing Phase 1. |

Sections where empty output is expected (e.g., `merged_brs` grep returning no matches) append `|| true` inside the script so `exit=0` remains meaningful.

## The squash-merged script

Emits branches that satisfy both:

1. `upstream: gone` — the tracking branch was deleted upstream (typical after a GitHub squash-merge + auto-delete).
2. `git diff --quiet main..<branch>` succeeds — the branch's tree is already represented on main.

Both are required. Rule 1 alone would include legitimate un-merged branches whose remote was deleted; rule 2 alone can't easily distinguish branches the user hasn't merged yet. Together, they identify branches whose content has landed via squash-merge and are safe for `-D`.

## Permission model

One allow rule covers both scripts and any future `end-session-*` sibling:

```text
Bash(~/.claude/bin/end-session-*)
```

Scope rationale: the prefix binds to scripts installed by this dotfiles repo (chezmoi renders `home/dot_claude/bin/executable_end-session-*` → `~/.claude/bin/end-session-*`). Scripts outside `~/.claude/bin/` aren't covered, so a rogue `end-session-*` elsewhere on disk still prompts.

If the tilde pattern turns out not to match on some future Claude Code version, the fallback is an absolute path or a `bash $HOME/.claude/bin/end-session-*` form.

## When to extract a step into a script vs keep it inline

Favour a script when any of these hold:

- The block is multi-line / pipelined in a way no single allow rule can match.
- Multiple independent reads can be run in parallel inside it.
- The logic is worth shellcheck-testing in isolation.
- A future reader needs to see "what this step runs" without hunting through markdown.

Keep it inline in the command spec when:

- It's a single shell command that matches an existing allow rule.
- It needs per-item user judgment between sub-commands (would break into separate prompts anyway).
- It's runtime-level (background process state, agent memory) that can't run from a detached shell.

## Rollout

The scripts live in `home/dot_claude/bin/executable_end-session-*` in this repo. They materialise at `~/.claude/bin/end-session-*` (with exec bit) only after `chezmoi apply`. On this machine that's `dotup` — `chezmoi update -v` pulls + applies from `~/.local/share/chezmoi`.

This matters because the dotfiles working clone (`/Users/paul/dev/dotfiles`, used for editing + PR workflow) and the chezmoi source clone (`~/.local/share/chezmoi`, what chezmoi reads) are separate. A merged PR to `main` does not land in `~/.claude/bin/` until chezmoi pulls and applies. First `/end-session` invocation on a machine after merging this work should be preceded by `dotup`.

## Maintenance

- **ShellCheck**: CI's `./scripts ./home` scan covers the scripts. Run locally with `shellcheck home/dot_claude/bin/executable_end-session-*` before pushing.
- **Paired files**: `settings.json` and `settings.json.md` are paired — any change to the allow rule must update both.
- **Adding a section to the gather**: add a `run_section` or `run_sh` call in the script, extend the section table in `commands/end-session.md`, then add a step (or fold into an existing step) that reads the new section.
- **New sibling script**: name it `executable_end-session-<purpose>`; the existing permission rule covers it.

## Non-goals

- **Replacing `/retrospective`'s flow.** It doesn't suffer from the same approval-prompt or latency issues, and its value is in agentic reasoning — parallel gather has nothing to buy.
- **Parallelising the destructive steps.** Tier 2 actions need a y/n each; splitting them across parallel processes would hide prompts.
- **Auto-merging PRs or auto-closing issues.** Explicit non-goal of the command itself (see `Guardrails` in the spec).
