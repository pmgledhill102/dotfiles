# Beads (`bd`) — user manual

This document explains how [beads](https://github.com/gastownhall/beads) is configured in Paul's
personal projects, how its moving parts fit together, and when to use it differently
depending on the shape of the project.

It is written for Paul's own reference and captures the state reached after the
multi-repo modernisation rollout on 2026-04-18/19.

## What beads is

Beads is a local-first issue tracker. Each project has its own issue database
stored in a `.beads/` directory at the project root. Two facts are essential:

1. **The source of truth is a Dolt database**, not a flat file. Dolt is a
   git-style SQL database — it stores table data in git-like refs, so one
   project can "push" its issue database to a git remote using a custom
   ref name that normal `git` ignores.
2. **Issues are exported to a human-readable JSONL file** (`.beads/issues.jsonl`)
   so editors can render them, but the JSONL is **not** the source of truth
   under the modern target state. It is gitignored and regenerated on every
   commit.

The result is:

- No separate infrastructure. The same GitHub repo that hosts the code also
  hosts the issue database, on a custom ref (`refs/dolt/data`).
- Issues are versioned alongside code in a meaningful way, but never clutter
  the `main` branch history.
- Multiple clones can pull/push issue data the same way they pull/push code.

## Data model — three layers

```text
┌──────────────────────────────────┐
│ bd commands (create, update, …)  │
└──────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────┐
│ Embedded Dolt database           │   .beads/embeddeddolt/<db>/
│ (source of truth on disk)        │
└──────────────────────────────────┘
      │                       ▲
      │ bd dolt push          │ bd init --from-jsonl (recovery)
      │ bd dolt pull          │
      ▼                       │
┌──────────────────────────────────┐    ┌──────────────────────────────┐
│ refs/dolt/data on GitHub origin  │    │ .beads/issues.jsonl          │
│ (canonical shared copy)          │    │ (ephemeral on-disk export)   │
└──────────────────────────────────┘    └──────────────────────────────┘
```

- `bd` writes to the **embedded Dolt DB** synchronously.
- On every commit, a hook exports the DB to **JSONL** so editors can see the
  current issues without running `bd`. The JSONL is gitignored — it's a view,
  not a source.
- `bd dolt push` sends the DB's latest data to GitHub on the `refs/dolt/data`
  ref. `bd dolt pull` goes the other way. These are **manual** commands.

## Git hooks

There are **two separate sets of hooks** and it's important to know which is
which.

### 1. Machine-level templates

Location: `~/.git-templates/` (managed by chezmoi from
`home/dot_git-templates/` in this dotfiles repo).

This directory is set as git's `init.templatedir`, so every `git init` and
`git clone` copies these files into the new repo's `.git/hooks/`.

Files:

```text
~/.git-templates/hooks/
  _lib/dispatch.sh
  post-checkout
  post-merge
  pre-commit
  pre-push
```

**These hooks do NOT know about beads.** After PR #153 (2026-04-18), the only
thing they do is dispatch to the `pre-commit` framework if a
`.pre-commit-config.yaml` is present:

```sh
. "$_lib"
run_precommit pre-commit
```

Prior to PR #153, `dispatch.sh` had a `run_beads` function and every template
hook called it. That coupling was removed for three reasons: (a) generic git
tooling shouldn't know about specific apps; (b) the dispatcher called
`bd hooks run` without a timeout wrapper, which deadlocks with `bd init`'s
post-init commit; (c) in beads-enabled repos it caused bd's hook to fire
twice per commit.

### 2. Per-repo hooks installed by `bd init`

Location: `.beads/hooks/` inside each beads-enabled project.

`bd init` installs a set of hook files here and configures the repo's
`core.hooksPath` to point at this directory:

```text
.beads/hooks/
  post-checkout
  post-merge
  pre-commit
  pre-push
  prepare-commit-msg
```

Each one contains a `--- BEGIN BEADS INTEGRATION vX.Y.Z ---` block that
bd manages. The integration block is **timeout-aware**:

```sh
if command -v timeout >/dev/null 2>&1; then
  timeout "$_bd_timeout" bd hooks run pre-commit "$@"
  # exit 124 (timeout) is treated as "continue without beads"
else
  bd hooks run pre-commit "$@"     # no timeout — can hang on macOS
fi
```

The `timeout` escape hatch matters: on stock macOS neither `timeout` nor
`gtimeout` is on `PATH`, so the wrapper falls through to the un-timed branch.
During `bd init`'s own post-init commit this deadlocks — the parent `bd init`
holds the DB lock; the hook spawns `bd export`, which blocks on it. The
`/bd-modernize` skill works around this by prepending a shim `timeout` to
`PATH` for the single invocation (see `home/dot_claude/commands/bd-modernize.md`
Step 4a).

### Composite hooks — the legacy shape

Older bd versions (seen in e.g. `discord-bot-test-suite`, `cloud-run-overlap-ips-with-nat`
before modernisation) produced **composite** hooks — they sourced the
git-templates dispatcher AND had bd's integration block, leading to the
double-invocation / deadlock problems above. The modern `/bd-modernize` skill
sweeps any surviving `run_beads <stage>` lines out of `.beads/hooks/*` during
migration (Step 5h).

### What each hook actually does

Verified against `cmd/bd/hooks.go` in `gastownhall/beads` (v1.0.3):

| Hook | bd-specific behaviour | Side effects | Read-only? |
| --- | --- | --- | --- |
| `pre-commit` | Runs `bd export` to dump DB → `.beads/issues.jsonl`. If `export.git-add: true`, stages the export for commit. Guarded by `export.auto`. | Writes JSONL on disk; may stage in git index. | No |
| `prepare-commit-msg` | When `BD_ACTOR` env var is set (orchestrator / agent context), appends an `Executed-By: <actor>` trailer to the commit message. Skips merge commits. Idempotent. | Modifies the commit-message file when `BD_ACTOR` is set; no-op otherwise. | No (when triggered) |
| `post-checkout` | **No bd-specific logic.** Only chains to `<hook>.old` if present. | None from bd. | Yes |
| `post-merge` | **No bd-specific logic.** Only chains to `<hook>.old`. Always returns 0 — warnings never block merges. | None from bd. | Yes |
| `pre-push` | **No bd-specific logic.** Only chains to `<hook>.old`. (See below for what does *not* live here.) | None from bd. | Yes |

**Surprise from the source-level verification:** `post-checkout`, `post-merge`,
and `pre-push` are pure no-ops for bd — they exist as thin shim locations
for chained user hooks (`<hook>.old`) only. The earlier doc characterised
them as "lightweight bookkeeping"; in practice they don't even reach bd's
issue-tracking code.

**`bd dolt push` is NOT triggered by any git hook.** When `dolt.auto-push: true`
is set in `.beads/config.yaml`, the auto-push runs from the bd command's
`PersistentPostRun` epilogue (after the command completes), not from
`pre-push`. The default is `dolt.auto-push: false` (disabled for concurrency
safety, GH#2453), so pushing issue data to `refs/dolt/data` is a manual
`bd dolt push` unless explicitly opted-in or wired via cron — see the cron-job
discussion below.

### Troubleshooting: `run_beads: command not found`

If `git commit`, `git checkout`, `git pull`, or `git push` prints:

```text
.git/hooks/pre-commit: line 11: run_beads: command not found
```

…it means that clone has a **stale `.git/hooks/*`** file from before PR #153.
The fix is environmental, not per-repo.

Why it happens: `git init` and `git clone` copy template hooks from
`~/.git-templates/hooks/` into the new clone's `.git/hooks/` **once, at
clone time**. `chezmoi apply` updates the source templates but never touches
already-copied hooks in existing clones. Before PR #153, templates ended with
`run_beads <stage>`; after #153 the symbol is gone from `dispatch.sh`, so old
hooks that still call `run_beads` fail.

Important — `.git/hooks/*` are **per-clone, not tracked by git**. They do not
travel when you push or clone. Cloning a repo on another machine produces
fresh hooks from *that machine's* current template library.

The fix: PR #157 restored `run_beads` in `dispatch.sh` as a backward-compat
stub — no-ops when `.beads/` is absent or `bd` isn't installed; otherwise
delegates to `bd hooks run` with timeout handling. Next `dotup` / `chezmoi
apply` propagates it, and all stale hooks on the machine stop erroring in
one step. The template hooks themselves still don't call `run_beads`, so new
clones remain fully decoupled.

Sanity check that the stub is live:

```sh
grep -q '^run_beads()' ~/.git-templates/hooks/_lib/dispatch.sh && echo OK
```

Confirm that a specific repo's `.git/hooks/*` are the only things calling
`run_beads` (nothing is committed — so nothing travels):

```sh
# Files in .git/hooks/ calling run_beads:
grep -lE '^run_beads ' .git/hooks/* 2>/dev/null
# Tracked files calling run_beads (expect zero):
git grep -lE '^run_beads ' HEAD -- . 2>/dev/null | wc -l
```

## Dolt

### Embedded mode (the modern default)

Since `bd` v0.63.3 the default is embedded Dolt — no `dolt sql-server`
process, no local TCP port, no PID files. The DB lives at:

```text
.beads/embeddeddolt/<db_name>/.dolt/
```

`<db_name>` is derived from the repo name with hyphens → underscores (e.g.
`cloud_run_overlap_ips_with_nat`).

### Server mode (legacy)

Some projects ran `dolt sql-server` locally listening on `localhost:3306`.
This adds a moving part (the daemon), opens port conflicts when multiple
projects used it, and leaves stale PID files. The inverse skill
`/bd-enable-server-mode` flips back to server mode if specifically wanted;
`/bd-modernize` goes the other way.

### The `refs/dolt/data` ref on origin

Dolt stores its data inside git refs, but the refs are outside the normal
`refs/heads/*` and `refs/tags/*` namespaces:

```text
refs/dolt/data                                       # the database tip
refs/dolt/blobstore/origin/dolt/data/<uuid>          # content blobs
```

`git push origin main` will not push these refs. `git fetch origin` will not
pull them either (by default). `bd dolt push` and `bd dolt pull` are the
commands that move data in and out.

Inspect the remote state with plain git:

```sh
git ls-remote origin refs/dolt/data
# 6e010f0abc…  refs/dolt/data     ← non-empty hash = seeded
```

### Remote URL forms

`bd init` registers a Dolt remote. The preferred URL form is `git+ssh://`:

```sh
bd dolt remote list
# origin   git+ssh://git@github.com/<user>/<repo>.git
```

The HTTPS form (`https://github.com/<user>/<repo>.git`) also works, but
**Dolt v1.81.10 has a bug** where git-remote operations fail if `git`
requires interactive STDIN for credentials. SSH-agent users are unaffected;
on other setups, use a git credential helper or keep the ssh form.

### The git-remote-cache gotcha

`bd init` creates an internal git-remote cache inside
`.beads/embeddeddolt/<db>/.dolt/git-remote-cache/<hash>/repo.git/`. If
`init.templatedir` is set, git copies its template hooks into **that cache's
`.git/hooks/` directory**, and the pre-commit framework fires every time
Dolt talks to origin, crashing `bd dolt push` with
`fatal: this operation must be run in a work tree`.

`/bd-modernize` Step 5c removes these cache-hooks:

```sh
find .beads/embeddeddolt -type d -name hooks -exec rm -rf {} + 2>/dev/null || true
```

Use `find`, not a shell glob — the Dolt-assigned `<hash>` path component is
unpredictable and a glob silently matches nothing.

## The JSONL export

`.beads/issues.jsonl` is the on-disk projection of the Dolt DB. One line per
issue, full fields as JSON.

### What it's for

- Editors / AI agents read it to see the current issue state without
  running `bd`
- Emergency recovery: if the Dolt DB is corrupted, `bd init --from-jsonl`
  can rebuild the DB from the JSONL (subject to schema compatibility —
  pre-v1.0 schemas have number-valued booleans that modern bd rejects; see
  `/bd-modernize` Step 4 for workarounds)

### What it is NOT

- Not the source of truth. The Dolt DB is.
- Not tracked in git under the modern target state — the modern
  `.gitignore` includes `.beads/issues.jsonl`, and `.beads/config.yaml`
  sets `export.git-add: false` so bd never auto-stages it even if git would
  otherwise see it.

### Why not track it in git?

Conflict noise. Multiple machines or branches updating issues would produce
merge conflicts in JSONL for every issue state change. The Dolt remote on
`refs/dolt/data` handles conflict semantics properly; the flat file does not.

## `.gitignore` strategy

Three gitignore files interact in a beads-enabled repo. Getting them wrong
is the root cause of several pitfalls I hit during the rollout.

### The three files

| File | Who writes it | Scope |
| --- | --- | --- |
| `<repo>/.gitignore` | You (the project author) | Whole repo |
| `.beads/.gitignore` | `bd` (regenerated by `bd init`) | Inside `.beads/` only |
| `.git/info/exclude` | Per-clone, per-user | Local override; not shared |

Rule of thumb: **root `.gitignore` decides what's tracked at the `.beads/`
boundary; `.beads/.gitignore` decides what's tracked inside `.beads/`.**
They layer, they don't conflict.

### What should be tracked

These belong in git (and are not matched by either default `.gitignore`):

```text
.beads/.gitignore         # bd-managed ignore rules (itself tracked)
.beads/README.md          # bd's README for humans browsing the dir
.beads/config.yaml        # per-project bd config (sync.remote, export.git-add, …)
.beads/metadata.json      # dolt_mode, dolt_database, project_id
.beads/hooks/*            # the per-repo git hooks bd installs
```

These are small, change rarely, and need to be the same on every clone
for the project to behave consistently.

### What should NEVER be tracked

Runtime / machine-local / large / high-churn:

```text
.beads/issues.jsonl                 # export — high churn + conflict risk
.beads/embeddeddolt/**              # local Dolt DB — large, per-machine
.beads/dolt/**                      # legacy server-mode DB (same reason)
.beads/backup/**                    # bd's auto-backup — per-machine, noisy
.beads/interactions.jsonl           # runtime event log
.beads/dolt-server.*                # server-mode runtime (pid/port/log/lock)
.beads/dolt-monitor.pid.lock        # server-mode runtime
.beads/.beads-credential-key        # encryption key for federation peers —
                                    # per-machine, never commit
.beads/.local_version               # per-clone version tracking
.beads/.env                         # per-clone env file (GH#2520)
.beads/ephemeral.sqlite3*           # wisps/molecules local store
.beads/.sync.lock                   # per-clone sync state
.beads/export-state*                # per-clone export watermark
```

`.beads/.gitignore` (written by `bd init`) already covers all of these.
**You do not need to add them to the root `.gitignore`.** Let bd manage
the inside-`.beads/` rules.

### What the root `.gitignore` should contain (and only this)

```gitignore
# Beads exports — source of truth is Dolt + refs/dolt/data on origin.
.beads/issues.jsonl
```

That's it. This is defence in depth: `bd init` sets `export.git-add: false`
in `.beads/config.yaml` so bd never stages the export itself, but if a
future `bd init --force` or manual `git add .beads/issues.jsonl` happened,
the root `.gitignore` catches it.

### Anti-patterns — what to NOT put in root `.gitignore`

**The whole `.beads/` directory.** Seen on `paul-gledhill-dev` before
modernise:

```gitignore
# Wrong — masks everything under .beads/
.beads/
```

This blocks `config.yaml`, `metadata.json`, `hooks/*`, and `.beads/.gitignore`
itself from being tracked, which means a fresh clone has no bd configuration
and no hooks. bd works for the person who ran `bd init`, and for nobody
else. `/bd-modernize` now corrects this at Step 5f, and the fresh-clone PR
for paul-gledhill-dev (#13) included the fix as part of the modernise.

**`.dolt/`**. It's tempting to add this to be "safe", but bd uses
`.beads/embeddeddolt/` — `.dolt/` is only present if you ran Dolt directly
outside of bd, which is unusual. Ignoring `.dolt/` is harmless; ignoring
`.beads/embeddeddolt/` is the one that matters, and `.beads/.gitignore`
already does that.

**Negation patterns inside `.beads/.gitignore`.** There's a comment in the
bd-managed `.beads/.gitignore`:

> NOTE: Do NOT add negation patterns here. They would override fork
> protection in `.git/info/exclude`. Config files (metadata.json,
> config.yaml) are tracked by git by default since no pattern above
> ignores them.

Leave bd's ignore rules alone unless you're deliberately extending them.
If you need to track a normally-ignored file, handle it in the **root**
`.gitignore` with a negation there.

### Sanity-check commands

When in doubt, ask git what it thinks:

```sh
# What would git add if I staged everything in .beads/?
git add -n .beads/

# Why is this file ignored?
git check-ignore -v .beads/<file>

# Show the currently tracked set under .beads/:
git ls-files .beads/
```

After `/bd-modernize`, `git ls-files .beads/` should show roughly:

```text
.beads/.gitignore
.beads/README.md
.beads/config.yaml
.beads/hooks/post-checkout
.beads/hooks/post-merge
.beads/hooks/pre-commit
.beads/hooks/pre-push
.beads/hooks/prepare-commit-msg
.beads/metadata.json
```

No `issues.jsonl`. No `embeddeddolt/`. No `backup/`. Nothing else.

## Pre-commit framework and beads

If a project uses the [pre-commit framework](https://pre-commit.com/) (i.e. has
a `.pre-commit-config.yaml` at the repo root), its configured lint hooks will
by default run against every staged file, including the bd-managed files under
`.beads/`. That is almost never what you want:

- `.beads/README.md` has lines longer than most projects' line-length limit
  and vocabulary that `cspell` doesn't know
- `.beads/config.yaml` doesn't start with `---` (which `yamllint --strict`
  flags)
- `.beads/hooks/*` source the dispatch library via a `$_lib` variable, which
  trips `shellcheck` SC1091 (`Not following: …`)

These files are **bd-managed** — they get regenerated on every `bd init`, so
fixing them in place is pointless: the next `bd-modernize` or re-init resets
them. The correct fix is to **exclude `.beads/` from the repo's lint hooks**.

### The canonical exclusion

For most pre-commit hooks:

```yaml
- id: <hook-id>
  exclude: ^\.beads/
```

For hooks that already have an `exclude:` (e.g. `yamllint` often excludes
`^\.github/workflows/`), extend it with a regex union:

```yaml
- id: yamllint
  exclude: ^(\.github/workflows/|\.beads/)
```

### Which hooks to exclude

On a modernised beads repo, add the exclusion to any hook that would run
against `.beads/*`:

| Hook | Why it needs the exclusion |
| --- | --- |
| `markdownlint-cli2` | `.beads/README.md` has long lines |
| `cspell` | `.beads/README.md` uses bd-specific vocabulary |
| `yamllint` | `.beads/config.yaml` lacks `---` document start |
| `shellcheck` | `.beads/hooks/*` source via `$_lib` (SC1091) |
| `trailing-whitespace`, `end-of-file-fixer` | Safe — bd's files pass these. No exclusion needed. |
| `check-yaml`, `check-json` | Safe — structurally valid. No exclusion needed. |

A simpler-but-broader approach: add a **top-level exclude** that applies to
every hook in the config:

```yaml
exclude: ^\.beads/
repos:
  - repo: ...
```

This is tempting but may be too broad if you ever deliberately want to lint
a file inside `.beads/` (unlikely, but possible). Per-hook excludes are more
precise.

### Sanity check

After modernising a repo:

```sh
# Dry-run every pre-commit hook against the committed .beads/ files.
# Any that fail are candidates for the exclusion.
pre-commit run --files $(git ls-files .beads/)
```

If this passes, your excludes are complete.

### Why this isn't already in `/bd-modernize`

The skill can detect that `.pre-commit-config.yaml` exists, but it can't
automatically patch it safely — every project's hook list is different and
structured differently (some share `exclude:` keys, some have top-level
`exclude:`, some use `args:` variants that matter for re-ordering).
`/bd-modernize` Step 6 now surfaces the list of hooks that would likely need
an exclusion as a post-modernise checklist, and this section is the
reference.

## Strategic use — project shapes

The right configuration depends on who uses the project and on what kind of
machine.

### A. Single user, persistent machine

Example: Paul's Mac running this dotfiles repo, or any long-lived personal
dev box.

**Recommended setup:** the modern target state exactly as shipped by
`/bd-modernize`. Embedded Dolt, `refs/dolt/data` on GitHub origin, JSONL
gitignored.

**Push cadence:** manual. `bd dolt push` when you're done with a batch of
issues or when you know the machine might be offline soon.

**Risk profile:** moderate. The local Dolt DB is authoritative until you
next push. If the machine's disk dies before you push, all issues created
since the last push are gone.

**Mitigation:** discipline (push frequently), or a lightweight cron —
see [The ephemeral risk and a push cron](#the-ephemeral-risk-and-a-push-cron)
below.

### B. Multi-user or ephemeral / virtual machine

Example: a Codespace, a devcontainer, a shared VM, or a throwaway dev VM
that gets recreated nightly.

**Recommended setup:** embedded Dolt is still fine (server mode adds
moving parts for no gain), but the assumptions about durability change.

Key discipline changes:

- **On startup:** always `bd dolt pull` before creating / closing issues.
  The local embedded DB may be stale or brand-new; pull first so you
  don't branch from an old state.
- **On every meaningful change:** `bd dolt push` soon after. The window
  between "created an issue" and "the only copy is on a machine that gets
  recycled" should be as short as practical.
- **At shutdown:** `bd dolt push` (critical for genuinely ephemeral
  machines — if you skip this, it's lost).
- **A cron is close to mandatory** for ephemeral machines. See next section.

For **multiple users** on the same persistent box (rare for Paul's setup,
but worth noting): treat it like a multi-agent scenario. Each user's work
pushes to the same `refs/dolt/data`, and Dolt handles the merge on push.
Pull before making changes, push after.

### C. Non-beads projects

Not every project needs beads. If a repo has no issue tracking need
(e.g. infra that's driven entirely by GitHub issues, or a tiny
single-purpose repo), don't `bd init` it. Fewer moving parts is better.

## The ephemeral risk and a push cron

### The problem

`bd dolt push` is **not** automatic. None of the installed hooks run it.
So any issues created between pushes live only in the local embedded Dolt
DB.

For Paul's Mac this is a small window of data loss — low probability,
low impact, mitigated by occasional manual pushes.

For ephemeral machines (Codespaces, nightly-rebuilt VMs, short-lived
containers) this is an **inevitable window of data loss** unless something
pushes automatically.

### Option 1: a scheduled cron

A scheduled push is the most reliable defence. Proposed shape on macOS
(launchd / LaunchAgent):

```xml
<!-- ~/Library/LaunchAgents/com.pmgledhill.bd-dolt-push.plist -->
<plist version="1.0">
<dict>
  <key>Label</key><string>com.pmgledhill.bd-dolt-push</string>
  <key>StartInterval</key><integer>1800</integer>   <!-- every 30 min -->
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/zsh</string>
    <string>-lc</string>
    <string>for d in ~/dev/*/.beads; do (cd "${d%/.beads}" && bd dolt push); done</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/tmp/bd-dolt-push.log</string>
  <key>StandardErrorPath</key><string>/tmp/bd-dolt-push.log</string>
</dict>
</plist>
```

On Linux (systemd --user timer), the equivalent is a `bd-dolt-push.timer`
unit with `OnUnitActiveSec=30min` driving a `bd-dolt-push.service` that runs
the same loop.

**Trade-offs:**

- **Network traffic**: low. Dolt pushes are delta-based; a push with no
  new work is near-free.
- **Conflicts**: `bd dolt push` against `refs/dolt/data` that has advanced
  on the remote (e.g. from a different machine) will reject and need a
  `bd dolt pull` first. For a single-user, single-machine setup this
  doesn't happen. For multi-machine setups the cron should do
  `bd dolt pull || true; bd dolt push` to smooth over this.
- **Sleep / wake**: `StartInterval` survives sleep on macOS — the agent
  fires when the machine wakes if it missed a scheduled slot. systemd
  `Persistent=true` gives the same behaviour.
- **Silent failures**: send stdout/stderr to a log file. Review weekly.
  Better: wrap the push in a short check that posts to Slack / a dead-man
  switch if it fails repeatedly. (Not needed day one.)

### Option 2: wire bd dolt push into git pre-push

Conceptually clean: every time you push the code, you also push the issues.
Downside: makes `git push` slower; not every code push has a corresponding
issue delta.

Add to `.beads/hooks/pre-push` (below the `BEADS INTEGRATION` block):

```sh
bd dolt push 2>&1 | tail -5
```

This is a **supplement** to a cron, not a replacement. It only fires when
you do a git push; the cron catches the case where you haven't pushed code
in a while.

### Recommendation

- **Single user, persistent Mac:** add a launchd-based cron on a 30-minute
  interval. Belt and braces, cheap.
- **Ephemeral / virtual machines:** cron is load-bearing — make it the
  first thing the devcontainer provisions, and make it every 5–10 minutes.
  Consider also wiring `bd dolt push` into any graceful-shutdown hooks
  the platform exposes.

Either way, surface failures loudly: a silent cron that has been failing
for a week is the worst of both worlds.

## Command reference

### Daily use

| Command | What it does |
| --- | --- |
| `bd create --title … --description …` | Create an issue |
| `bd ready` | Show issues ready to work (no blockers) |
| `bd update <id> --claim` | Claim an issue |
| `bd close <id>` | Close an issue |
| `bd show <id>` | Full detail on one issue |
| `bd stats` | Open/in-progress/blocked/closed counts |

### Sync

| Command | What it does |
| --- | --- |
| `bd dolt push` | Push local DB to `refs/dolt/data` on origin |
| `bd dolt pull` | Fetch + merge from `refs/dolt/data` |
| `bd dolt remote list` | Show configured Dolt remotes |
| `git ls-remote origin refs/dolt/data` | Check the ref exists on origin |

### Diagnostics

| Command | What it does |
| --- | --- |
| `bd doctor` | Health check on the installation |
| `bd where` | Resolve `.beads/` directory and config |
| `cat .beads/metadata.json` | Inspect mode (`embedded` vs `server`) + DB name |
| `ps -ef \| grep "dolt sql-server"` | Confirm no stray server process |

### Modernisation / setup

| Skill | Purpose |
| --- | --- |
| `/bd-modernize` | Bring a project to the modern target state |
| `/bd-enable-server-mode` | Flip to server mode (inverse) |
| `/bd-migrate-embedded` | Migrate an existing server-mode project |
| `/bd-import-github-issues` | Import open GitHub issues as beads |

## File locations cheat sheet

```text
~/.git-templates/hooks/                # Machine-level git-hook templates
                                       # (chezmoi-managed, beads-agnostic)

~/.local/share/chezmoi/                # The chezmoi source used by chezmoi apply
                                       # Separate clone from ~/dev/dotfiles!
                                       # Sync both with `dotup`.

<repo>/.beads/                         # Per-project beads state
  config.yaml                          # Per-project bd config
  metadata.json                        # Mode (embedded/server), DB name
  issues.jsonl                         # Export (gitignored, regenerated)
  embeddeddolt/<db>/                   # The Dolt database (if embedded)
  hooks/                               # bd-managed git hooks
                                       # (core.hooksPath points here)

<repo>/.git/hooks/                     # Git's built-in hooks dir
                                       # bd overrides with core.hooksPath
                                       # → .beads/hooks/, so these are
                                       # usually ignored on modernised repos
```

## Open questions

- `bd init --from-jsonl` drops issues silently in some cases (273 → 272 on
  `discord-bot-test-suite`). Cause not determined. Worth a reproducer.
- A cron for `bd dolt push` is not yet set up on any of Paul's machines —
  proposed in this doc, not yet implemented.
