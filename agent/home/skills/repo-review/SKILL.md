---
name: repo-review
description: Audit a repository for accumulated drift and produce actionable findings: validate architecture decision records against the code, surface outdated, deprecated or vulnerable dependencies, and flag stale docs, dead code and old TODOs. Read-only; never modifies code or dependencies.
---

# Review a repo for currency and drift

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
- **No bidirectional sync.** Issues are created in the repo's own GitHub tracker. Nothing is pushed to Jira or other external trackers.

## Operational notes

- **Foreground everything.** Scanners are I/O-bound; running them sequentially in the foreground is fine and keeps output legible.
- **Expected runtime**: 1–3 min on a small repo, 5–10 min on a large multi-language repo (most of which is `pip-audit` / `cargo-audit` fetching advisory data).
- **Per-language gating.** A scanner is only required if the corresponding manifest is detected. A pure-Python repo doesn't need `cargo-audit`.
- **`gh issue create` pacing.** Pace writes ~2s apart when creating a batch — GitHub's secondary rate limits allow at most 80 content-creating requests/min, and bursts trigger 403s. For a typical 5–20 action-item batch, under a minute total.

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
GitHub Issues: <yes|no — origin url contains github.com>. Will run phases A–E and output <action-items target>.
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

### Phase A2 — Tier fit

Per [ADR-0015](https://github.com/pmgledhill102/dotfiles/blob/main/agent/adrs/0015-tiered-adrs.md),
every ADR declares a tier with a `Scope:` header line — `personal`, `user` or
`repo` — and placement is meant to follow scope rather than convenience. This
check is the backstop for that; it is a review prompt, not enforcement.

For each ADR, additionally:

1. **Missing scope.** No `Scope:` line → flag it, and suggest one from the
   authoring test below. Don't guess silently; the point of the header is
   that the blast radius is stated rather than inferred.

2. **Outgrown its tier.** Apply the authoring test — *would this decision
   still bind if this repo were archived?* If yes and it is `Scope: repo`,
   flag it for promotion to the user tier
   (`agentic-coding-config/adrs/`), leaving a stub behind that links to
   the new home. Signals worth searching for:
   - the ADR's own text generalises beyond this repo ("every repo", "all my
     projects", "across the estate")
   - another repo is known to depend on the decision, or the ADR is
     referenced by URL from outside this repo

3. **Undeclared deviation.** A repo-tier ADR that contradicts a user-tier
   decision must say so — naming the ADR it deviates from and why. A repo ADR
   that quietly reverses a user-tier decision without referencing it is the
   failure mode the tier model exists to prevent, so flag it as a finding in
   its own right rather than as a style nit. The user-tier set is listed at
   <https://github.com/pmgledhill102/dotfiles/tree/main/agent/adrs>
   and is readable from a sandbox with no local clones.

Suggested actions for this phase: "add Scope:", "promote to user tier +
stub", "declare the deviation", "no action".

Note that promotion is a **cross-repo** change: per the cross-repo rule, do
not edit the other repo. File an issue against `agentic-coding-config`
containing the ADR's full text and the reason for promotion.

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

File presence is all this phase checks. Whether the configured system actually *works* is Phase F — a repo can ship weekly bump PRs for months with its advisory alerts switched off, and this check passes either way.

### Pre-commit / CI freshness

If `.pre-commit-config.yaml` exists, surface the file's last-modified date (`git log -1 --format=%ad -- .pre-commit-config.yaml`). If older than 12 months, action item P3.

## Phase F — Settings versus behaviour

Every other phase reads the working tree. This one asks whether the repo's GitHub-side configuration matches [`home/standards/github-standards.md`](https://github.com/pmgledhill102/dotfiles/blob/main/agent/home/standards/github-standards.md), and — more importantly — whether it is *having its intended effect*.

**Do not build an estate-wide settings sweep here.** `paul-context`'s `tools/repo-audit.sh` already does that: it reads merge methods, auto-merge, delete-branch-on-merge, alerts, security updates, secret scanning, ruleset counts, Dependabot secret names and shared-config drift by blob SHA, across every repo in one run. Duplicating it produces two answers that drift. This phase covers only what a single-repo review can do that an estate sweep structurally cannot, plus the one field the sweep collects but does not surface.

**The division is not the clone.** Every content comparison behind the estate's last auto-merge failure was done API-only — `contents/…` plus `base64 -d` — and reading one known file across 40 repos is no harder than reading it in one. What divides the two is how much of the tree a check has to understand:

| Check shape | Owner |
| --- | --- |
| A known, small set of files, checked for declared properties | the sweep — it is N× more useful across the tier |
| The whole working tree — dead code, stale TODOs, dependency currency, README claim drift | `repo-review` |

So the auto-merge workflow's *contents* are not checked here. Its load-bearing properties are declared in [`home/standards/github-repo.json`](https://github.com/pmgledhill102/dotfiles/blob/main/agent/home/standards/github-repo.json) under the `automerge` tier's `files` block, and `paul-context`'s `tools/repo-spec-diff.py` diffs every repo in the tier against them — together with the spec's top-level `prohibited` list, which is what catches a *below*-tier repo carrying auto-merge apparatus it has no gate for. Phase F defers to the spec for these files exactly as it already defers to the sweep for settings; a second copy of the properties here would rebuild the duplication the spec was written to remove.

### F1 — Effective branch rules (needs GitHub API access, not necessarily `gh`)

`repo-audit.sh` reports how many rulesets a repo has, not what they contain — and the rule that matters most is invisible in a count. Two calls, for the repo under review:

```sh
# Route in order of preference: mcp__github__* where the MCP server is
# connected, then `gh api` where the CLI is present, then this script. The last
# one works in a cloud sandbox, which has no `gh`.
#
# The token is read inside the script, never built into a command line: a
# header passed to `curl -H` is in argv, which every process on the machine can
# read, and the credential guard refuses such a command outright.
#
# Two `sed` expressions, not one: ERE has no non-greedy quantifier, so the
# `.git` suffix is stripped separately. Both remote forms are in live use.
R=$(git remote get-url origin | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##')
python3 -I - "$R" <<'PY'
import json, os, sys, urllib.request

repo = sys.argv[1]
tok = os.environ.get("GH_TOKEN") or os.environ["GITHUB_TOKEN"]


def get(path):
    req = urllib.request.Request(
        "https://api.github.com/repos/" + repo + path,
        headers={"Authorization": "Bearer " + tok},
    )
    return json.load(urllib.request.urlopen(req))


j = get("")
print(json.dumps({"merge": j["allow_merge_commit"], "squash": j["allow_squash_merge"],
                  "rebase": j["allow_rebase_merge"], "auto": j["allow_auto_merge"]}))

# The DEFAULT branch, never HEAD. A review normally runs from a feature
# branch, which carries no ruleset, so HEAD returns `[]` -- indistinguishable
# from "this repo has no rules configured". That is a silent wrong answer of
# exactly the kind this phase exists to catch, and it was shipped here until
# the snippet was run rather than read.
print(json.dumps([r["type"] for r in get("/rules/branches/" + j["default_branch"])]))
PY
```

**Both of these work in a cloud sandbox.** Measured against a repo the session is bound to: `200` and `200`. Do not skip F1 because `gh` is absent — see Degradation for what genuinely cannot run, and why the difference matters.

Findings:

- `required_linear_history` present → **P1**. It forbids merge commits on the branch regardless of `allow_merge_commit`, so the repo can report `merge: true` and still be unable to merge by the sanctioned route. The failure surfaces at merge time on an approved, green PR, far from its cause.
- `allow_merge_commit: false` → **P1**; `allow_rebase_merge: true` → **P2** (the standard disables it outright).
- Both a classic branch-protection rule and a ruleset on the same branch → **P2**: most-restrictive-wins means a blocking rule can hide in either layer. Migrate to the ruleset and delete the classic rule. **This is the one bullet that needs `/branches/{branch}/protection`**, which a GitHub App token is refused (`Resource not accessible by integration`). Where that is the credential — every cloud sandbox — report this bullet alone as `not checked (token lacks admin scope)` and still report the other three, which ran.
- `allow_auto_merge: true` with no `required_status_checks` rule → **P1**. Without required checks `--auto` merges *immediately*; the "wait for CI" comes from the ruleset, not the flag.

### F2 — Did it actually work? (needs only the clone)

The recurring estate failure is configuration that reads correct and does nothing. Settings answer what is *declared*; the history answers what *happened*, and only this phase can see it.

```sh
git log --merges --oneline --since=<date the settings were last corrected>
```

**Date-bound it.** An unbounded `git log --merges` matches a merge commit from before the settings broke and reports success on a repo that has squashed everything since. If the correction date is unknown, use the repo's most recent 90 days.

Finding: merge commits declared available but none observed in the window → **P2**, "declared mergeable, never observed" — the signal that a merge-method fix restored the option without changing the outcome (GitHub's merge dropdown is sticky per user per repository, so the first merge after a fix must select the method by hand, once).

This check needs no API access, so unlike F1 it **still works where `gh` is absent** — which is every cloud sandbox. It is the one settings-related check that never degrades.

### F3 — Dependabot posture

Phase E checked that a config file exists. The half that goes silent when missing is the settings half — dependency graph, alerts, security updates — and `repo-audit.sh` already reports it estate-wide, along with whether `AUTOMERGE_PAT` is present in each repo's Dependabot store.

Here, check only the pairing that makes a per-repo review the right place to notice it: the repo has an auto-merge workflow **and** the estate audit shows no `AUTOMERGE_PAT` for it, or F1 showed no required status checks. Either combination means the auto-merge apparatus is installed and cannot work safely. **P1**, with the remedy from `setup-common` §8d.

Whether the workflow itself is *correct* is not this phase's question — the spec's `files` block declares that, and the sweep checks it tier-wide. Report the pairing and leave the contents alone.

Note the limit rather than implying coverage: a fine-grained PAT's repository list cannot be read from outside the token, so no check here or in the estate sweep can prove the token actually covers this repo. That is only knowable by using it.

**The pairing has two inputs and they degrade differently — do not skip both because one is unavailable.** The required-status-checks half comes out of F1's ruleset call, which runs anywhere the API is reachable, including a cloud sandbox. Only the `AUTOMERGE_PAT` half needs `/dependabot/secrets`, which a GitHub App token is refused on scope. So where the secret store cannot be read: evaluate the checks half, and report the other as `not checked (token lacks scope)` rather than reporting the pairing unevaluated. An auto-merge workflow with no required status checks is a **P1** on its own — `--auto` merges immediately, PAT or no PAT.

### Degradation

**`gh` being absent is not the same as the API being unreachable, and conflating them is how this phase came to stand down on checks it could run.** A cloud sandbox has no `gh` and *can* reach `api.github.com`: `/user` resolves the right identity, and both F1 calls return `200`. Gate each check on a response, never on `command -v gh`.

Four refusals, each meaning something different. The body says which:

| Response | Meaning | What to report |
| --- | --- | --- |
| `200` | It ran | The finding |
| `Resource not accessible by integration` | GitHub refused the **token's permissions** — a GitHub App installation token lacks admin and Dependabot-secret scopes | `not checked (token lacks scope)` |
| `not permitted through this proxy` | The agent proxy's **endpoint denylist** | `not checked (proxy denylist)` |
| `sessions are bound to their configured repositories` | The sandbox's **session binding** — the repo under review is in scope by definition, so this should not appear here | `not checked (session binding)` |

The distinction is not pedantry. A scope refusal might be fixed by a different credential; a proxy denylist never is; and a session binding is upstream of the credential entirely, so reporting any of them as "no API access" sends the next person after the wrong remedy. That is what the old wording did, and what #501 was filed for.

What this means per check, measured in a cloud sandbox:

- **F1 runs**, including the `required_linear_history` and auto-merge findings — the two P1s. Only the classic-protection bullet degrades, on token scope.
- **F3 does not run**: Dependabot secrets are refused on token scope. Report it as such, not as clean.
- **F2 always runs** — it reads the clone and needs no API at all.

Report an unchecked layer as **unknown, never clean**. That has always been the rule here; the bug was a stale reason gating it, not the principle. **Re-measure before trusting any line above** — a recorded block is a fact about one day, and this section is the second one in this estate to go stale that way.

## Output: findings summary (always inline)

Print to chat. Use the structure:

```text
## Findings

ADRs (<N> found)
  - <file>  <STATUS>  <one-line reason>
  Tier fit: <N> missing Scope:, <N> outgrown their tier, <N> undeclared deviations

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

Settings vs behaviour
  Merge methods: merge=<y/n> squash=<y/n> rebase=<y/n>   [expected: y/y/n]
  Branch rules: <rule types, or "not checked (<reason from Degradation>)">
  Linear history required: <y/n>                         [expected: n]
  Effective: can this repo produce a merge commit? <yes|no>
  Observed: merge commits since <date>: <N>
  Auto-merge: <on/off>, required checks: <y/n>
```

The "effective" line is the AND of the repo setting and the branch rules — the number a human actually wants, and the one neither layer answers alone. "Observed" is the only line that survives with no API access.

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

Type tags follow the GitHub Issues label conventions (`docs/github-issues-workflow.md` in `agentic-coding-config`): `bug` (CVE / breakage), `feature` (proposed adoption like Renovate), `task` (cleanup, default).

### If the repo has a github.com origin remote

Show the action item list, then ask once:

```text
<N> action items proposed. Create them as GitHub Issues?
  - "yes" — create all
  - "skip <n>,<m>" — create all except listed indices
  - "cancel" — abort
```

On confirmation, for each accepted item:

1. Write the description to `/tmp/repo-review-<index>.md` using the `Write` tool (never inline-escape multi-line content).
2. Run `gh issue create --title "<short>" --body-file /tmp/repo-review-<i>.md --label "type: <type>,P<0..4>"` synchronously (prefer a structured GitHub API tool over the CLI when the client offers one). Pace successive creates ~2s apart to stay under GitHub's secondary rate limits. If the standard labels (`P0`–`P4`, `type: *`) don't exist yet, bootstrap them per `docs/github-issues-workflow.md` (idempotent `gh label create --force` loop) before the batch.
3. Capture the issue number/URL. Build a mapping table.

Description file template:

```markdown
Source: /repo-review run on YYYY-MM-DD

<finding details: scanner, severity, location, suggested fix>

---
Generated by /repo-review.
```

If any `gh issue create` fails, STOP — do not silently continue. Surface the partial state.

### If the repo has no github.com origin remote

Write the action items to a markdown file:

- Path: `docs/reviews/repo-review-YYYY-MM-DD.md` (create `docs/reviews/` if absent).
- Use the `Write` tool, not heredocs. Overwrite if a file with today's date already exists.

File structure:

```markdown
# Repo review — YYYY-MM-DD

Generated by `repo-review`.

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

- GitHub Issues path: re-creates duplicate issues. Deduplicate against `gh issue list --state all` (never `gh search issues` — the search API is eventually consistent); surface a warning if any existing issue's title matches an action item title and ask the user to confirm before re-creating.
- Markdown path: overwrites today's file. Yesterday's review (if committed) is preserved in git history.

The command itself does not maintain a state file — its source of truth is the current state of the repo.

## Known issues / footnotes

- **`cargo-udeps` requires nightly.** If the project's `rust-toolchain.toml` pins to stable, the check is skipped with a warning rather than failing the run.
- **`lychee` online pass is opt-in.** The default offline pass catches structural broken links (relative paths, anchors). The online pass adds rate-limited HTTP fetches and can take minutes — only run if the user explicitly asks.
- **README claim drift is a heuristic.** Won't catch every drift case; particularly flaky on repos with multiple READMEs (root + per-package). Treat the output as a starting point.
- **The deprecated→modern map is hand-curated.** Update via PR when a new "X is dead, use Y" case is encountered. Don't auto-generate from npm `deprecated` flags alone — that catches the obvious cases but misses ecosystem shifts (e.g. `tslint` → `eslint` predates the `deprecated` flag).
- **Pre-commit framework interaction.** If the repo has `.pre-commit-config.yaml`, the markdown report file (`docs/reviews/repo-review-*.md`) may trip markdownlint depending on configured rules. The report uses standard markdown so this is rare; if it happens, add `exclude: ^docs/reviews/` to the relevant hook rather than rewriting the report format.
- **GitHub Actions SHA-pinning check uses a regex.** False positives on weird `uses:` syntax; false negatives on actions referenced via composite or local paths. Treat the count as approximate.
- **Phase F is deliberately not an estate sweep.** `paul-context`'s `tools/repo-audit.sh` owns that, and the two must not grow into competing answers. If a settings check would be as useful across 40 repos as on one, it belongs in the audit script, not here — and the same test now sends declared file properties to the sweep, via the spec's `files` and `prohibited` blocks. Phase F's remit is the single-repo view: the effective rules a count cannot show, and the behavioural check that reads this repo's own history.
- **Phase F degrades per check, not per surface, and the reason is part of the finding.** This footnote used to say cloud sandboxes cannot reach `api.github.com`, so F1 and F3 could not run there. That was measured false (#501): F1's two calls both return `200` in a sandbox, and only the classic-protection bullet and F3 are refused, on the *token's* scope rather than reachability. Gate on the response, report the reason from the table in Degradation, and never report an unchecked layer as clean — that part was always right. F2 needs no API and always runs.
