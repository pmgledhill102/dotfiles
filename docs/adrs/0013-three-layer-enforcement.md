# ADR-0013: Three-layer enforcement — CI, pre-commit, Claude Code hooks

- **Status**: Accepted
- **Date**: 2026-04-26
- **Tags**: ci, quality, claude-code

## Context

Project hygiene — linting, formatting, secrets scanning, type checking —
needs to be enforced consistently. Each enforcement venue has different
latency and authority:

- **CI** is authoritative but slow (round-trip via GitHub).
- **Local pre-commit hooks** are fast and run before push, but can be
  bypassed.
- **Claude Code's own PostToolUse hooks** can run on every file write,
  giving Claude immediate feedback — but they only fire when Claude is
  the editor.

Picking just one venue leaves obvious gaps. CI alone is too slow for
day-to-day editing. Hooks alone are easy to bypass.

## Decision

Apply the same checks at three layers, with CI as the source of truth.

### Layer 1 — CI (always enforced)

Runs on every push and pull request via GitHub Actions
(`.github/workflows/ci.yml`):

- `shellcheck` over `scripts/` and `home/`
- `markdownlint-cli2` over all `*.md`
- `actionlint` over workflows
- Full install test on `ubuntu-latest`, `macos-latest`,
  `windows-latest` (PRs run a fast variant that skips package
  installs)

Nothing merges without these passing. CI is the unambiguous gate.

### Layer 2 — Pre-commit hooks

The same checks run locally before push, via the `pre-commit` framework.
The `/setup-common` slash command installs the framework on a fresh
repo; each `/setup-*` language command registers its tools into it.

### Layer 3 — Claude Code PostToolUse hooks

Where it pays off, mirror the checks as Claude Code hooks so they run on
file write — Claude sees failures immediately and fixes them rather than
waiting for pre-commit or CI.

| Tool category | CI | Pre-commit | Claude hook |
| ------------- | :-: | :--------: | :---------: |
| Formatters (prettier, rustfmt, gofmt, ruff format) | yes | yes | yes (auto-fix on write) |
| Fast linters with auto-fix (eslint --fix, ruff check --fix) | yes | yes | optional |
| Type checkers (mypy, tsc) | yes | yes | no |
| Security scanners (gitleaks, bandit, trivy) | yes | yes | no |
| Dependency audits | yes | no | no |

Type checkers and security scanners stay at L1/L2: they're too slow or
need full project context, so running them per-file is wasteful.

## Consequences

### Positive

- Faster feedback at the layer closest to where the editor is working.
- CI remains authoritative — no ambiguity about what blocks merge.
- Claude Code spends fewer turns on formatting because hooks fix it
  before the next user prompt.
- Pre-commit catches issues that hooks missed (non-Claude commits).

### Negative / trade-offs

- Three places to keep tool versions roughly aligned.
- Pre-commit config and `/setup-*` slash command snippets must agree on
  what gets installed.
- Layer 3 only fires for Claude Code clients; other editors fall through
  to L1/L2.

## Alternatives considered

- **CI-only** — slow round-trip, expensive in agent turns.
- **Pre-commit only** — easy to bypass with `--no-verify`; CI is still
  needed as the gate.
- **Claude hooks only** — no enforcement when humans (or other tools)
  commit, and not enforced on the GitHub side.
- **A single mega-tool** (e.g. trunk-io, mega-linter) — adds an
  abstraction that obscures which check is firing where.
