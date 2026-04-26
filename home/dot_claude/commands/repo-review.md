Run a repo currency and cleanup review: validate ADRs against the code, surface deprecated or outdated dependencies, flag stale docs and dead code, and emit an actionable findings list. Read-only — never modifies project code or dependencies. Output is a findings summary plus action items (Beads tasks when the project uses Beads, otherwise a markdown report file in the repo).

## When to use

- Periodically on long-lived projects to surface accumulated drift (deprecated deps, ADRs that no longer match the code, stale docs).
- Before a refactor sprint, to scope cleanup work as concrete action items.
- On a project you're returning to after months — get a fast read on what's rotted.
- After a major dependency or framework migration, to find leftover references to the old stack.

Don't run during ongoing feature work — the action-item output is a sweep-up step, not a continuous-integration check.

## What it doesn't do

- **No fixes.** Read-only diagnostic. Each finding is a suggestion for the user to action separately.
- **No silent fallback when scanners are missing.** Pre-flight halts with an install list. The user installs the tools and re-runs.
- **No automatic scanner installation.** The command prints install commands; the user runs them.
- **No SARIF or CI integration.** Output is markdown for humans. CI integration is out of scope for v1.
- **No bidirectional sync.** Beads tasks are created if the project uses Beads. Nothing is pushed to GitHub Issues, Jira, etc.

## Operational notes

- **Foreground everything.** Scanners are I/O-bound; running them sequentially in the foreground is fine and keeps output legible.
- **Expected runtime**: 1–3 min on a small repo, 5–10 min on a large multi-language repo (most of which is `pip-audit` / `cargo-audit` fetching advisory data).
- **Per-language gating.** A scanner is only required if the corresponding manifest is detected. A pure-Python repo doesn't need `cargo-audit`.
- **`bd create` foreground sync.** Each call ~1s. For a typical 5–20 action-item batch, 30s total.

## Pre-flight: detect, verify, prepare

Run the detection block first as a single shell call so the full state lands in one output:

```sh
echo "===root==="; git rev-parse --show-toplevel 2>&1
echo "===project name==="; basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "===origin url==="; git remote get-url origin 2>&1
echo "===languages detected==="
[ -f package.json ]    && echo "js"     || true
[ -f pyproject.toml ] || [ -f setup.py ] || [ -f setup.cfg ] || [ -f requirements.txt ] && echo "python" || true
[ -f Cargo.toml ]      && echo "rust"   || true
[ -f go.mod ]          && echo "go"     || true
[ -f Gemfile ]         && echo "ruby"   || true
[ -f composer.json ]   && echo "php"    || true
[ -f pom.xml ] || ls *.csproj 2>/dev/null | head -1 || ls build.gradle* 2>/dev/null | head -1 || true
echo "===adr search==="
for d in docs/decisions docs/adr doc/adr architecture/decisions adrs .adr-log; do
  [ -d "$d" ] && echo "found: $d" && ls "$d" | head -10
done
echo "===beads==="; [ -f .beads/metadata.json ] && echo "yes" || echo "no"
echo "===dependabot==="; [ -f .github/dependabot.yml ] || [ -f .github/dependabot.yaml ] && echo "yes" || echo "no"
echo "===renovate==="; [ -f renovate.json ] || [ -f .renovaterc ] || [ -f .renovaterc.json ] && echo "yes" || echo "no"
echo "===pre-commit==="; [ -f .pre-commit-config.yaml ] && echo "yes" || echo "no"
```

Capture the language list — it drives the required-scanners check next.

### Verify required scanners

Required tools per detected language. **Halt if any are missing**: print the install list, do not proceed.

| Detected | Required | Install hint |
| --- | --- | --- |
| any (always) | `lychee` | `brew install lychee` or `cargo install lychee` |
| `js` | `knip`, `npm-check-updates` (and the package manager's outdated subcommand: `npm`/`pnpm`/`yarn`) | `npm i -g knip npm-check-updates` |
| `python` | `pip-audit`, `deptry`, `vulture` | `uv tool install pip-audit deptry vulture` |
| `rust` | `cargo-audit`, `cargo-outdated`, `cargo-udeps` | `cargo install cargo-audit cargo-outdated cargo-udeps` (note: `cargo-udeps` requires nightly) |
| `go` | `govulncheck`, `go-mod-outdated` | `go install golang.org/x/vuln/cmd/govulncheck@latest && go install github.com/psampaz/go-mod-outdated@latest` |

Verification idiom (one block, run after detection):

```sh
missing=""
for tool in lychee; do command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"; done
# Then, conditionally on detected languages, append more tools to the loop above.
[ -n "$missing" ] && { echo "Missing required tools:$missing"; echo "Install them and re-run."; exit 1; }
```

If anything is missing, print:

```text
Missing required scanners for detected languages: <list>

Install with:
  <one line per tool>

Re-run /repo-review when installed.
```

…and stop. Do not proceed.

### Brief the user

Once detection and verification pass, give the user a one-paragraph summary before running phases:

```text
Reviewing <project>: detected <langs>. Found <N> ADRs in <path> (or "no ADRs").
Beads: <yes|no>. Will run phases A–E and output <action-items target>.
Estimated runtime: <X> min. Proceed? (y/n)
```

Wait for explicit `yes`. Anything else, abort.

## Phase A — ADR validation

Skip if pre-flight found no ADR directory.

For each ADR file (`*.md` in the detected ADR directory):

1. Parse the file. Extract:
   - **Title** (first H1 or `# NNNN. ...` heading).
   - **Status** (look for a `Status:` line or `## Status` section — typical values: `Accepted`, `Proposed`, `Deprecated`, `Superseded by ...`).
   - **Date** (look for a `Date:` line or front matter; fall back to the file's `git log -1 --format=%ad` if absent).
   - **Decision claims**: extract every line under a "## Decision" / "## Context" section that names a specific technology, library, framework, service, or pattern. Heuristic: a noun phrase capitalised or in backticks (e.g. `PostgreSQL`, `gRPC`, `redux-toolkit`).

2. For each claim, check whether the named technology appears in the **current** code:
   - Search manifests first (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, etc.) — exact dependency name match.
   - Then `rg -l '\b<name>\b' --type-add 'src:*.{js,ts,py,rs,go,rb,php,java,cs}' -tsrc` (or equivalent), capped at first 5 matches.
   - Record: `present` (manifest hit), `referenced` (code hit only), or `missing` (no hit).

3. Classify each ADR:
   - **OK** — at least one decision claim resolves to `present` or `referenced`.
   - **STALE** — `Status: Accepted` (or unset) but **all** decision claims are `missing`. Likely the decision was reversed and the ADR wasn't updated.
   - **CONTRADICTED** — `Status: Accepted` but a *competing* technology (one not mentioned in the ADR) is also present in the manifest. E.g. ADR says "use REST", but `grpc-go` is in `go.mod`.
   - **STALE-DATE** — date older than 2 years AND status is still `Accepted` AND no edits in `git log` since. Worth re-validating regardless of code state.
   - **EXPLICITLY DEPRECATED** — `Status: Deprecated` or `Superseded`. Skip; no action needed.

4. Output a table: ADR file → status → finding → suggested action ("update", "supersede", "delete", "no action").

## Phase B — Dependency currency

Run the per-language scanners. Each scanner is invoked once. **Run synchronously** — do not background. Aggregate the JSON or text output into a structured findings list.

### JS / TS

```sh
# Outdated (whichever package manager is in use)
[ -f pnpm-lock.yaml ] && pnpm outdated --format=json 2>/dev/null
[ -f yarn.lock ]      && yarn outdated --json 2>/dev/null
[ -f package-lock.json ] && npm outdated --json 2>/dev/null
# Unused / dead code
knip --reporter json 2>/dev/null
# Major-version upgrade picture
npm-check-updates --jsonUpgraded 2>/dev/null
```

### Python

```sh
pip list --outdated --format=json 2>/dev/null
pip-audit --format=json 2>/dev/null
deptry . --json-output /tmp/deptry-out.json 2>/dev/null && cat /tmp/deptry-out.json
vulture --min-confidence 80 . 2>/dev/null
```

### Rust

```sh
cargo audit --json 2>/dev/null
cargo outdated --format json 2>/dev/null
# udeps requires nightly; allow it to fail and surface "skipped" rather than block.
cargo +nightly udeps --output json 2>/dev/null || echo "(cargo-udeps skipped — nightly toolchain not available)"
```

### Go

```sh
govulncheck -json ./... 2>/dev/null
go list -u -m -json all 2>/dev/null | go-mod-outdated -update -direct -json 2>/dev/null
```

### Aggregate

Build a `findings.deps` list, each item:

```text
{language, name, current, latest, kind: outdated|deprecated|cve|unused, severity: P0..P3, source}
```

Severity rules:

- CVE with CVSS ≥ 7.0 → P0
- Deprecated (npm `deprecated`, PyPI yanked, RustSec advisory) → P1
- Major-version behind, current major unsupported → P1
- Major-version behind, current major still supported → P2
- Minor/patch-version behind → P3
- Unused dependency → P2

## Phase C — Deprecated → modern alternative

For each item in `findings.deps` flagged as `deprecated` (Phase B), and additionally for any dependency whose name appears in the curated map below, emit a "consider replacing X with Y" action item. Keep the map in this command file — extend it via PR as new cases come up.

```text
# JS / TS
moment           → Temporal (Node 22+) or date-fns / dayjs
request          → undici (Node 22+ fetch) or node-fetch
node-uuid        → globalThis.crypto.randomUUID() (Node 19+)
tslint           → eslint
node-sass        → sass (Dart Sass)
true-myth        → neverthrow (more active)
husky 4.x        → husky 9.x (config format changed)
yarn 1.x         → pnpm or npm 10+

# Python
PyCrypto         → cryptography
nose             → pytest
black + isort + flake8 → ruff (single tool, faster)
pylint (alone)   → ruff + mypy
mock             → unittest.mock (stdlib)

# Rust
failure          → thiserror + anyhow
error-chain      → thiserror + anyhow

# Build / CI
travis-ci        → GitHub Actions
circleci (small projects) → GitHub Actions

# Generic
README.rst-only without README.md → README.md (better GitHub rendering)
```

The replacement is a *suggestion*, not an automatic action. Each becomes an action item with `priority=P2, type=task`.

## Phase D — Doc and code drift

### Broken links

```sh
lychee --offline --no-progress --format json --include '\.(md|markdown|rst|txt)$' . > /tmp/lychee-offline.json 2>/dev/null
# Optional online pass — only if user opts in. Surface count from offline pass first.
```

Only count `error` results (not `cached` or `excluded`). Each broken link becomes an action item, severity P2.

### README claim drift

Spot-check the project README:

1. Extract every fenced code block whose info string is `bash`, `sh`, `shell`, or unset and whose first line looks like a command (e.g. `npm run dev`, `make build`, `./scripts/foo.sh`).
2. For each, check whether the named entry point exists:
   - `npm run X` / `pnpm X` / `yarn X` → present in `package.json` `scripts`?
   - `make X` → present in `Makefile`?
   - `./scripts/X.sh` → file exists?
3. Mismatches → action item, P2.

This is best-effort — don't try to validate every code fence. The goal is to catch obvious "README says `npm run dev` but only `pnpm` is configured" drift.

### Dead code

Already covered by Phase B's scanners (`knip`, `deptry`, `vulture`, `cargo-udeps`). Promote each unused-export and unused-file finding into an action item if the count is non-trivial (≥3). Bundle small counts as one action item.

### Old TODOs / FIXMEs

```sh
rg -n '\b(TODO|FIXME|XXX|HACK)\b' --type-add 'src:*.{js,ts,py,rs,go,rb,php,java,cs,sh}' -tsrc . 2>/dev/null \
  | head -100
```

For each match, run `git blame -L <line>,<line> <file> --porcelain | head -5` to extract the commit date. Items older than 12 months become an action item. Group by file in the output to keep it readable.

## Phase E — Repo hygiene

### Stale branches

```sh
git for-each-ref --sort=-committerdate refs/remotes/origin --format='%(refname:short) %(committerdate:iso8601-strict)' 2>/dev/null \
  | head -50
```

Heuristic: any branch with last commit > 90 days ago AND merged into `main` (`git branch -r --merged origin/main`). Surface count + a max-10 list. Action item: P3, suggest `git push origin --delete <branch>`.

### GitHub Actions pinning

```sh
rg -n 'uses:\s*[A-Za-z0-9_./-]+@(?:v[0-9]+|[a-f0-9]{6,40})' .github/workflows/ 2>/dev/null
```

For each non-SHA-pinned reference, action item P2 — "pin to commit SHA for supply-chain safety".

### Dependabot / Renovate

If neither `.github/dependabot.yml` / `.yaml` nor `renovate.json` is present: action item P1 — "no automated dependency PRs configured".

### Pre-commit / CI freshness

If `.pre-commit-config.yaml` exists, surface the file's last-modified date (`git log -1 --format=%ad -- .pre-commit-config.yaml`). If older than 12 months, action item P3.

## Output: findings summary (always inline)

Print to chat. Use the structure:

```text
## Findings

ADRs (<N> found)
  - <file>  <STATUS>  <one-line reason>

Dependencies
  Outdated: <N> (major: <a>, minor: <b>, patch: <c>)
  Deprecated: <list of names>
  CVEs: <N> (P0: <a>, P1: <b>)
  Unused: <list of names>

Deprecated → modern alternative
  - <X> → <Y>

Docs & code drift
  Broken links: <N> (offline pass)
  README out-of-date: <list>
  Dead code: <N> exports across <N> files
  Old TODOs: <N> (oldest: <date>)

Repo hygiene
  Stale branches: <N>
  GitHub Actions pinned to floating tags: <N>
  Dependabot/Renovate: <yes|no>
  Pre-commit config last edited: <date>
```

Sections with zero findings should explicitly say "none" — silence is ambiguous.

## Output: action items

Compile every finding into a single ranked list:

```text
## Action items

[P0] (bug)     Update lodash >=4.17.21 — CVE-2021-23337 (high)
[P1] (task)    Replace `request` with `undici` — deprecated since 2020
[P1] (task)    Update ADR docs/decisions/0007-use-yarn.md — repo migrated to pnpm
[P2] (task)    Pin .github/workflows/ci.yml actions to commit SHAs (3 entries)
[P2] (task)    Remove unused exports from src/utils/ (8 across 3 files)
[P3] (task)    Delete stale branches: feature/foo, refactor/bar (12 total, oldest 2024-01)
```

Type tags follow Beads conventions: `bug` (CVE / breakage), `feature` (proposed adoption like Renovate), `task` (cleanup, default).

### If Beads is detected

Show the action item list, then ask once:

```text
<N> action items proposed. Create them as Beads tasks?
  - "yes" — create all
  - "skip <n>,<m>" — create all except listed indices
  - "cancel" — abort
```

On confirmation, for each accepted item:

1. Write the description to `/tmp/repo-review-<index>.md` using the `Write` tool (per the `bd-import-github-issues.md` pattern — never inline-escape multi-line content).
2. Run `bd create --title="<short>" --description="$(cat /tmp/repo-review-<i>.md)" --type=<type> --priority=<0..4>` synchronously.
3. Capture the bead ID. Build a mapping table.

Description file template:

```markdown
Source: /repo-review run on YYYY-MM-DD

<finding details: scanner, severity, location, suggested fix>

---
Generated by /repo-review.
```

If any `bd create` fails, STOP — do not silently continue. Surface the partial state.

### If Beads is not detected

Write the action items to a markdown file:

- Path: `docs/reviews/repo-review-YYYY-MM-DD.md` (create `docs/reviews/` if absent).
- Use the `Write` tool, not heredocs. Overwrite if a file with today's date already exists.

File structure:

```markdown
# Repo review — YYYY-MM-DD

Generated by `/repo-review`.

## Findings summary

<the same findings block printed inline>

## Action items

- [ ] [P0] (bug)  <one-line title>
      <2–4 line description: scanner, location, suggested fix>

- [ ] [P1] (task) <one-line title>
      <description>

...
```

Print the file path on completion. Suggest the user commit the file so the review history accumulates in the repo.

## Idempotency

Re-running on the same day:

- Beads path: re-creates duplicate beads. Surface a warning if any existing bead's title matches an action item title and ask the user to confirm before re-creating.
- Markdown path: overwrites today's file. Yesterday's review (if committed) is preserved in git history.

The command itself does not maintain a state file — its source of truth is the current state of the repo.

## Known issues / footnotes

- **`cargo-udeps` requires nightly.** If the project's `rust-toolchain.toml` pins to stable, the check is skipped with a warning rather than failing the run.
- **`lychee` online pass is opt-in.** The default offline pass catches structural broken links (relative paths, anchors). The online pass adds rate-limited HTTP fetches and can take minutes — only run if the user explicitly asks.
- **README claim drift is a heuristic.** Won't catch every drift case; particularly flaky on repos with multiple READMEs (root + per-package). Treat the output as a starting point.
- **The deprecated→modern map is hand-curated.** Update via PR when a new "X is dead, use Y" case is encountered. Don't auto-generate from npm `deprecated` flags alone — that catches the obvious cases but misses ecosystem shifts (e.g. `tslint` → `eslint` predates the `deprecated` flag).
- **Pre-commit framework interaction.** If the repo has `.pre-commit-config.yaml`, the markdown report file (`docs/reviews/repo-review-*.md`) may trip markdownlint depending on configured rules. The report uses standard markdown so this is rare; if it happens, add `exclude: ^docs/reviews/` to the relevant hook rather than rewriting the report format.
- **GitHub Actions SHA-pinning check uses a regex.** False positives on weird `uses:` syntax; false negatives on actions referenced via composite or local paths. Treat the count as approximate.
