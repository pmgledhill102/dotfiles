Bring this project's beads (`bd`) installation to the default modern target state. Idempotent — re-running on an already-modernised project is safe and reports "no changes" if nothing needed doing.

The target state has three properties:

1. **Local mode**: embedded Dolt (no `dolt sql-server`, no port collisions, no PID files). Default since `bd` v0.63.3.
2. **Sync mechanism**: Dolt git remote on `refs/dolt/data` of the project's GitHub origin (Dolt v1.81.10+). No DoltHub, no extra infra — the same GitHub repo serves as the Dolt remote on a custom ref that normal `git` operations ignore.
3. **JSONL export**: `.beads/issues.jsonl` is **gitignored** and not auto-staged. The file may stay fresh on disk for IDE visibility but never enters commits. Source of truth is Dolt + the git remote.

Use this command when:

- Setting up beads on a new project (after `bd init`)
- Aligning a legacy project that's still in server mode and/or commits its JSONL
- Reverting a project from server mode back to embedded (this command pulls toward the default; the paired `/bd-enable-server-mode` is the only thing that pushes away from it)
- Periodically verifying alignment

## Operational notes (read first)

- **Run all commands in the foreground.** Do NOT background `bd init` or `bd dolt push`. Both complete in <1 minute when the procedure is followed; backgrounding them turns failures into polling rounds and adds 10+ minutes of overhead. The deadlock and hook-fire failure modes are visible immediately in foreground output.
- **Bash sessions in agent execution are ephemeral.** Each tool call is a new shell. Don't stash state in `$VAR` and rely on it surviving — chain commands with `&&` in one call, or hardcode the value.
- **Expect the procedure to take 3-5 minutes total** on a typical small repo (most of which is `bd init`'s import + the initial `bd dolt push`).

## Pre-flight checks

Run all checks as a single shell block so the full state is captured in one output:

```sh
echo "===bd version==="; bd version
echo "===metadata.json==="; cat .beads/metadata.json 2>&1
echo "===dolt remote list==="; bd dolt remote list 2>&1
echo "===JSONL tracked?==="; git ls-files --error-unmatch .beads/issues.jsonl 2>&1; echo "exit=$?"
echo "===git status==="; git status --porcelain
echo "===origin url==="; git remote get-url origin
echo "===running dolt server pid==="; [ -f .beads/dolt-server.pid ] && cat .beads/dolt-server.pid || echo "(none)"
echo "===init.templatedir==="; td=$(git config --get init.templatedir); echo "templatedir=$td"; [ -n "$td" ] && ls "${td/#~/$HOME}/hooks/" 2>/dev/null | head -5
```

Interpret the results:

- **`bd version` < 1.0**: stop, tell the user to upgrade (e.g. `brew upgrade beads`).
- **`origin url` not on `github.com`**: Step B's git-remote feature won't work. Surface this; offer to skip B or stop.
- **`init.templatedir` has hook files**: this means `bd dolt push` will fire those hooks inside Dolt's internal git context and fail. Step B's procedure handles this by removing the cache hooks before push — note it'll need to run.
- **`metadata.json.dolt_mode = "server"`**: Step A will run.
- **`bd dolt remote list` shows no `git+` or `https://github.com/...` remote matching origin**: Step B will run.
- **JSONL tracked check returns exit 0**: Step C will run.
- **All three at target**: skip Steps A/B/C; jump to Step G.
- **Unrelated uncommitted changes in `git status`**: ask the user before proceeding.
- **Issue prefix** (only needed if Step A runs): `head -1 .beads/issues.jsonl | jq -r .id | sed 's/-[^-]*$//'`. Fallback: `basename "$PWD"`.

Brief the user in one or two sentences on which steps will run before any destructive action.

## Procedure

### Step A: Migrate to embedded Dolt — only if `dolt_mode=server`

Skip this entire section if pre-flight detected `dolt_mode: "embedded"` already.

#### A.1 Preserve the issues JSONL

```sh
if [ ! -f .beads/issues.jsonl ] && git ls-files --error-unmatch .beads/issues.jsonl >/dev/null 2>&1; then
  git restore .beads/issues.jsonl
fi
wc -l .beads/issues.jsonl
cp .beads/issues.jsonl "/tmp/beads-issues-backup-$(basename "$PWD")-$(date +%s).jsonl"
```

If `.beads/issues.jsonl` is genuinely missing (not just deleted from working tree), STOP — without it the migration will silently produce an empty database.

#### A.2 Stop the running Dolt server

```sh
if [ -f .beads/dolt-server.pid ]; then
  pid=$(cat .beads/dolt-server.pid)
  kill "$pid" 2>/dev/null || true
  sleep 1
  ps -p "$pid" >/dev/null 2>&1 && kill -9 "$pid" || true
fi
```

Only kill the PID recorded in `.beads/dolt-server.pid` — never kill arbitrary `dolt sql-server` processes.

#### A.3 Wipe server-mode artifacts and runtime state

Remove everything bd or Dolt manages — `bd init` regenerates whatever it needs:

```sh
rm -rf .beads/dolt \
       .beads/embeddeddolt \
       .beads/backup \
       .beads/dolt-server.lock \
       .beads/dolt-server.log \
       .beads/dolt-server.pid \
       .beads/dolt-server.port \
       .beads/dolt-server.activity \
       .beads/interactions.jsonl \
       .beads/.local_version \
       .beads/metadata.json \
       .beads/hooks
```

Keep only `.beads/.gitignore`, `.beads/config.yaml`, `.beads/README.md`, `.beads/issues.jsonl`. The `.beads/hooks/` directory is wiped because `bd init` rewrites every hook with the current bd version's templates — preserving the old ones is pointless.

#### A.4 Re-init with embedded mode and import the JSONL

`bd` 1.0.x in embedded mode has a known deadlock: `bd init`'s post-init `git commit` fires the pre-commit hook, which calls `bd export`, which blocks on the embedded-DB lock that the parent `bd init` is still holding. The hooks shell scripts wrap their `bd hooks run` calls in `timeout "$BEADS_HOOK_TIMEOUT" ...` (default 300s) — set the env var low so the hook resolves quickly instead of hanging for 5 minutes.

```sh
BEADS_HOOK_TIMEOUT=2 bd init --from-jsonl -p <prefix> --non-interactive --role=maintainer
```

Run synchronously (foreground). Expected: completes in 30-60s for small projects. The post-init commit hook will fire, time out after 2s with a message like `beads: hook 'pre-commit' timed out after 2s — continuing without beads`, and bd init will succeed cleanly.

If `timeout` is not on `PATH` (older macOS without `brew install coreutils`), the hook scripts fall back to running without timeout and the deadlock will reappear. In that case, in another terminal: `pkill -9 -f "bd export"` to break the chain — `bd init` has already imported the data so the killed sub-commit is harmless.

Verify the import:

```sh
bd stats   # Total Issues should match wc -l of the JSONL
```

If the count mismatches, STOP and surface the discrepancy.

`bd init` auto-detects the project's `git remote origin` and registers it as a Dolt remote in the `git+ssh://git@github.com/<user>/<repo>.git` form — exactly what Step B needs. No remote cleanup required.

### Step B: Configure the Dolt git remote — only if not already set up

Skip if `bd dolt remote list` already shows a remote whose URL matches the project's GitHub origin (any of: `https://github.com/...`, `git+https://...`, `git+ssh://git@github.com:...`). After Step A, the remote is usually already there.

If absent, add it via `bd` (not raw `dolt`) so the URL persists to `.beads/config.yaml` as `sync.remote` for fresh-clone bootstrap:

```sh
GH_URL=$(git remote get-url origin | sed -e 's|^git@github.com:|https://github.com/|')
case "$GH_URL" in
  *.git) ;;
  *) GH_URL="${GH_URL}.git" ;;
esac
bd dolt remote add origin "$GH_URL"
bd dolt remote list
```

#### B.1 Remove templatedir-installed hooks from Dolt's internal cache (CRITICAL)

If `init.templatedir` is set with hooks installed (pre-flight detects this), the templated hooks were copied into Dolt's internal git-remote-cache when `bd init` created it. Those hooks fire pre-commit framework on every `bd dolt push` and fail with `fatal: this operation must be run in a work tree` (Dolt's internal git context has no work tree).

Permanently delete these cache hooks — they serve no purpose in Dolt's internal git context:

```sh
rm -rf .beads/embeddeddolt/*/.dolt/git-remote-cache/*/repo.git/hooks/
```

This is a destructive but safe operation: Dolt regenerates the cache hooks dir if it ever needs it (it doesn't), and removing them stops every future `bd dolt push` from failing too.

#### B.2 Seed the remote and verify

```sh
bd dolt push
git ls-remote origin refs/dolt/data
```

A non-empty `git ls-remote` result confirms the remote is live.

If the push fails with a credential prompt error, this is the known Dolt v1.81.10 bug — switch to `git+ssh://git@github.com:<user>/<repo>.git` form (uses ssh-agent, no STDIN credential):

```sh
bd dolt remote remove origin
bd dolt remote add origin "git+ssh://git@github.com:<user>/<repo>.git"
bd dolt push
```

### Step C: Stop committing the JSONL — only if currently tracked

Skip if `git ls-files --error-unmatch .beads/issues.jsonl` returns non-zero (already untracked).

#### C.1 Disable auto-staging in `.beads/config.yaml`

Append (or set) `export.git-add: false`. Leave `export.auto: true` (the default) so the file stays fresh on disk for IDE visibility — it just never gets staged.

```yaml
export.git-add: false
```

(beads' `config.yaml` accepts the dotted-key form.)

#### C.2 Add to project `.gitignore`

Append to the **project root** `.gitignore` (not `.beads/.gitignore`, which `bd init` may regenerate):

```gitignore
# Beads exports — source of truth is Dolt + refs/dolt/data on origin.
.beads/issues.jsonl
```

#### C.3 Untrack the file

```sh
git rm --cached .beads/issues.jsonl
```

The on-disk copy stays.

### Step D: Strip `bd init`'s `CLAUDE.md` / `AGENTS.md` blocks — only if Step A ran

Always remove the BEADS INTEGRATION block from both files. The bd init template is verbose, prescriptive (mandates `git pull --rebase && bd dolt push && git push` which doesn't fit PR-based workflows), and almost always duplicates hand-tuned guidance the project already has. Keeping it requires per-repo curation; removing it is one Edit per file and the project's existing content stays authoritative.

For each of `AGENTS.md` and `CLAUDE.md`, use the `Edit` tool to delete the entire `<!-- BEGIN BEADS INTEGRATION ... -->` through `<!-- END BEADS INTEGRATION -->` block (inclusive), plus the leading blank line.

If after removal the file ends up with no agent guidance at all (rare — usually only on brand-new repos with empty AGENTS.md), use the existing block content as a starting point for hand-tuned guidance, but still strip the auto-generated markers so future `bd init` runs don't double-add.

### Step E: Stage and commit

`bd init` (Step A) leaves a set of files staged from its incomplete post-init commit (which we let time out). Stage anything else needed and commit:

```sh
git add .beads/.gitignore .beads/config.yaml .beads/metadata.json \
        .beads/hooks/ .gitignore \
        .claude/settings.json AGENTS.md CLAUDE.md 2>/dev/null
git status   # confirm: .beads/issues.jsonl shows as DELETED if Step C ran, NOT modified
git commit -m "chore: modernise beads — embedded Dolt, refs/dolt/data remote, JSONL gitignored" \
           -m "<one-paragraph summary of which steps actually ran and any decisions>"
```

Notes on the staged files:

- **`.claude/settings.json`** is new from `bd init` — keep it. It wires `bd prime` into SessionStart and PreCompact hooks; useful for any agent on the repo.
- **`.beads/issues.jsonl`** should appear as `deleted` (from Step C.3's `git rm --cached`), not modified. If it shows modified, the auto-staging didn't get disabled — re-check `.beads/config.yaml` has `export.git-add: false`.

If a `pre-commit` framework hook auto-fixes files (typically trailing newlines), the first commit will fail. Re-`git add` the modified files and commit again. External `git commit` from a shell does NOT deadlock — only `bd`-initiated internal commits do.

### Step F: Push

This skill does not push the resulting commit — push (or open a PR) per the project's own workflow conventions. If Step B ran, `bd dolt push` was already done as part of seeding `refs/dolt/data`.

### Step G: Verify the final state

```sh
echo "===bd stats==="; bd stats | head -8
echo "===remote list==="; bd dolt remote list
echo "===refs/dolt/data on origin==="; git ls-remote origin refs/dolt/data
echo "===tracked .beads files==="; git ls-files .beads/
echo "===running dolt server==="; ps -ef | grep "dolt sql-server" | grep -v grep || echo "(none)"
echo "===log==="; git log --oneline -3
```

Expected:

- `bd stats` total matches the pre-modernisation count
- `bd dolt remote list` shows exactly one remote, the GitHub git+(https|ssh) form
- `git ls-remote origin refs/dolt/data` returns a non-empty hash
- `git ls-files .beads/` shows `.gitignore`, `README.md`, `config.yaml`, `metadata.json`, `hooks/*` — but NOT `issues.jsonl`
- No `dolt sql-server` process for this project

#### G.1 (Optional) Fresh-clone bootstrap verification

The whole point of `refs/dolt/data` is bootstrap-on-fresh-clone. Validate it works end-to-end:

```sh
verify_dir=$(mktemp -d)
git clone --depth 1 "$(git remote get-url origin)" "$verify_dir/clone" >/dev/null 2>&1
( cd "$verify_dir/clone" && bd bootstrap && bd stats | head -8 )
rm -rf "$verify_dir"
```

The `bd stats` from the fresh clone should match the original repo's count. If it shows 0 issues, `refs/dolt/data` wasn't seeded properly or `sync.remote` isn't in `.beads/config.yaml`.

Report a brief summary to the user: which transitions actually ran, issue count preserved, any decisions made.

## Idempotency

Each step is independently conditional. Re-running this command on an already-modernised project should:

- Pre-flight detect `dolt_mode=embedded`, correct git remote present, JSONL untracked
- Skip Steps A, B, C, D, E entirely
- Run Step G and report "already in target state"

## Reverting from `/bd-enable-server-mode`

`/bd-enable-server-mode` flips `dolt_mode` to `"server"`. To go back: just re-run `/bd-modernize` — Step A will detect server mode and migrate it back. No separate reverse skill exists by design.

## Known issues / footnotes

- The deadlock between `bd init`'s post-init commit and bd's pre-commit hook is a real characteristic of `bd` 1.0.2 embedded mode. `BEADS_HOOK_TIMEOUT=2` is the resolution; on systems without `timeout` (older macOS without coreutils), fall back to manual `pkill -9 -f "bd export"`. Once modernisation is done, normal external `git commit` from a shell fires the hooks and works fine.
- Dolt v1.81.10 has a bug where git-remote operations fail if `git` requires interactive STDIN for credentials. Use `git+ssh://` URL form (ssh-agent) or set up a git credential helper.
- The cache-hooks removal in Step B.1 is permanent. If `pre-commit` framework is later reinstalled with `init.templatedir` regenerated, you may need to re-run that `rm` once. A future fix would be to detect this in pre-flight on every run.
- Don't run `bd init` ad-hoc on an already-initialised project later — it will re-add the BEADS INTEGRATION blocks to `CLAUDE.md` / `AGENTS.md` which Step D removed.
- If the user explicitly wants to keep `.beads/issues.jsonl` in git for visibility (e.g. so PR reviewers can see issue diffs), skip Step C and document why. The conflict pattern across parallel feature branches will return.
