Bring this project's beads (`bd`) installation to the default modern target state. Idempotent: re-running on an already-aligned project is safe and exits in <30s.

The target state has three properties:

1. **Local mode**: embedded Dolt (no `dolt sql-server`, no port collisions, no PID files). Default since `bd` v0.63.3.
2. **Sync mechanism**: Dolt git remote on `refs/dolt/data` of the project's GitHub origin (Dolt v1.81.10+). No DoltHub, no extra infra — the same GitHub repo serves as the Dolt remote on a custom ref that normal `git` operations ignore.
3. **JSONL export**: `.beads/issues.jsonl` is **gitignored** and not auto-staged. The file may stay fresh on disk for IDE visibility but never enters commits.

## Shape

Pre-flight detects current state. If all three axes are already at target, run verification and exit. Otherwise: a linear nuke-and-pave pipeline (back up JSONL → wipe `.beads/` → fresh `bd init` → idempotent post-init configuration → commit). One path, no conditional sub-branches, self-healing for partial migrations.

Use this command when:

- Setting up beads on a new project (after `bd init`)
- Aligning a legacy project (server mode, JSONL tracked, missing remote, all three at once — doesn't matter)
- Reverting from `/bd-enable-server-mode` (the inverse skill)
- Periodically verifying alignment

## Operational notes

- **Foreground everything.** Don't background `bd init` or `bd dolt push`. Both complete in <1 minute when the procedure is followed; backgrounding turns failures into polling rounds and adds 10+ minutes of overhead.
- **Bash sessions in agent execution are ephemeral.** Each tool call is a new shell. Don't stash state in `$VAR` and rely on it surviving — chain commands with `&&` in one call, or hardcode the value.
- **Expected runtime**: <30s on the fast-path, 1-2 min on the nuke-and-pave path (most of which is `bd init --from-jsonl` importing the issues).

## Pre-flight

Run all checks as a single shell block so the full state lands in one output:

```sh
echo "===bd version==="; bd version
echo "===metadata.json==="; cat .beads/metadata.json 2>&1
echo "===dolt remote list==="; bd dolt remote list 2>&1
echo "===JSONL tracked?==="; git ls-files --error-unmatch .beads/issues.jsonl 2>&1; echo "exit=$?"
echo "===.beads/dolt/ exists?==="; [ -d .beads/dolt ] && echo "yes (legacy server-mode)" || echo "no"
echo "===git status==="; git status --porcelain
echo "===origin url==="; git remote get-url origin
echo "===running dolt-server pid==="; [ -f .beads/dolt-server.pid ] && cat .beads/dolt-server.pid || echo "(none)"
echo "===init.templatedir==="; td=$(git config --get init.templatedir); echo "templatedir=$td"; [ -n "$td" ] && ls "${td/#~/$HOME}/hooks/" 2>/dev/null | head -5
```

Interpret the results:

- **`bd version` < 1.0**: stop, tell the user to upgrade (e.g. `brew upgrade beads`).
- **`origin url` not on `github.com`**: Dolt git-remote feature won't work. Surface this; offer to skip the remote / push steps or stop entirely.
- **Compute `IS_LEGACY`** = `(.beads/metadata.json missing) OR (dolt_mode != "embedded") OR (.beads/dolt/ exists)`. This signal drives `.beads/config.yaml` preservation in Step 1 (legacy = wipe; modern = preserve).
- **Compute `AT_TARGET`** = `dolt_mode == "embedded"` AND `bd dolt remote list` has a `git+...` or `https://github.com/...` remote matching origin AND JSONL tracked check returned exit 1 (untracked).
- **If `AT_TARGET`**: skip to Step 6 (verification). Reports "already aligned" and exits in <30s. Done.
- **Otherwise**: brief the user in one sentence ("running nuke-and-pave: backup JSONL, wipe .beads/, reinit, configure, commit") and proceed to Step 1.

Also identify the **issue prefix** (only used by `bd init` in Step 4):

- Preferred: `head -1 .beads/issues.jsonl | jq -r .id | sed 's/-[^-]*$//'`
- Fallback: `basename "$PWD"` (matches `bd init`'s default).

## Step 1: Back up JSONL (and config.yaml if modern)

```sh
TS=$(date +%s)
PROJECT=$(basename "$PWD")
test -s .beads/issues.jsonl || { echo "FATAL: .beads/issues.jsonl missing or empty — refusing to nuke"; exit 1; }
cp .beads/issues.jsonl "/tmp/beads-${PROJECT}-${TS}.jsonl"
ORIG_LINES=$(wc -l < .beads/issues.jsonl)
echo "backed up ${ORIG_LINES} issues to /tmp/beads-${PROJECT}-${TS}.jsonl"
# Modern projects: also preserve config.yaml so user customisations survive the nuke.
# Legacy projects: skip — config.yaml hasn't been customised under the modern schema.
if [ "$IS_LEGACY" != "yes" ] && [ -f .beads/config.yaml ]; then
  cp .beads/config.yaml "/tmp/beads-${PROJECT}-${TS}.config.yaml"
  echo "preserved config.yaml for restore in step 4"
fi
```

If the JSONL doesn't exist at all (extremely unusual — would mean nothing to migrate), STOP and ask the user where the source-of-truth issue data lives.

## Step 2: Stop any running Dolt server

```sh
if [ -f .beads/dolt-server.pid ]; then
  pid=$(cat .beads/dolt-server.pid)
  kill "$pid" 2>/dev/null || true
  sleep 1
  ps -p "$pid" >/dev/null 2>&1 && kill -9 "$pid" || true
fi
```

Only kill the PID recorded in this project's `.beads/dolt-server.pid` — never kill arbitrary `dolt sql-server` processes.

## Step 3: Nuke `.beads/` and restore JSONL

```sh
rm -rf .beads
mkdir -p .beads
cp "/tmp/beads-${PROJECT}-${TS}.jsonl" .beads/issues.jsonl
ls .beads/   # should show only issues.jsonl
```

Self-healing: any half-migrated state, stale lock files, orphaned config — all gone.

## Step 4: Fresh `bd init` and restore preserved config

```sh
BEADS_HOOK_TIMEOUT=2 bd init \
  --from-jsonl \
  -p <prefix from pre-flight> \
  --non-interactive \
  --role=maintainer \
  --skip-agents
```

Notes:

- `BEADS_HOOK_TIMEOUT=2` is required. `bd init`'s post-init `git commit` fires the just-installed pre-commit hook, which calls `bd export`, which blocks on the embedded-DB lock that the parent `bd init` is still holding. The hook script wraps `bd hooks run` in `timeout "$BEADS_HOOK_TIMEOUT" ...` (default 300s); lowering it lets the hook timeout-as-success in 2s and `bd init` continues cleanly.
- `--skip-agents` prevents `bd init` from appending the verbose `<!-- BEGIN BEADS INTEGRATION -->` block to `CLAUDE.md` and `AGENTS.md`. Side-effect: it also skips installing `.claude/settings.json` bd-prime hooks — Step 5a installs those itself.
- Run synchronously (foreground). Expected: 30-60s for typical small projects.
- If `timeout` is not on `PATH` (older macOS without `brew install coreutils`), the hook scripts fall back to running without timeout and the deadlock will reappear. Manual recovery: `pkill -9 -f "bd export"` in another terminal — `bd init` will then complete.

Verify the import succeeded:

```sh
bd stats   # Total Issues should match $ORIG_LINES from Step 1
```

If the count mismatches, STOP and surface the discrepancy.

If the project was modern (`IS_LEGACY != "yes"`), restore the preserved config:

```sh
if [ -f "/tmp/beads-${PROJECT}-${TS}.config.yaml" ]; then
  cp "/tmp/beads-${PROJECT}-${TS}.config.yaml" .beads/config.yaml
  echo "restored preserved config.yaml"
fi
```

`bd init` wrote a default config; the user's preserved copy now overlays it. Step 5's idempotent settings updates apply on top.

## Step 5: Post-init configuration

All sub-steps are idempotent — they detect "already done" and no-op. Run in order.

### 5a. Install `.claude/settings.json` bd-prime hooks

`--skip-agents` on `bd init` skipped these. Install them ourselves so `bd prime` runs at SessionStart and PreCompact for any agent in this project.

If `.claude/settings.json` already exists with both hooks present, no-op. Otherwise:

```sh
mkdir -p .claude
# If file is missing, create with both hooks:
[ -f .claude/settings.json ] || cat > .claude/settings.json <<'JSON'
{
  "hooks": {
    "PreCompact": [{"hooks": [{"command": "bd prime", "type": "command"}], "matcher": ""}],
    "SessionStart": [{"hooks": [{"command": "bd prime", "type": "command"}], "matcher": ""}]
  }
}
JSON
# If file exists, the LLM should use jq or Edit to merge missing hook entries
# rather than blindly overwriting. Check existing hooks first.
```

(Heredoc shown for clarity. In agent execution, use the `Write` or `Edit` tool — heredocs are banned in interactive bash per project policy.)

### 5b. Normalise the Dolt remote URL

`bd init` auto-detected `origin` and registered a Dolt remote, typically `git+ssh://git@github.com/<user>/<repo>.git`. That's the right form for ssh-agent users. If the user has no SSH key loaded, switch to `git+ssh://...` form anyway (it's still preferable to `https://...` which trips Dolt v1.81.10's STDIN-credential bug).

```sh
bd dolt remote list   # see what bd init registered
# If the URL is anything other than git+ssh://git@github.com:<user>/<repo>.git or
# the equivalent https form, replace it:
GH_URL=$(git remote get-url origin | sed -e 's|^git@github.com:|https://github.com/|')
case "$GH_URL" in *.git) ;; *) GH_URL="${GH_URL}.git" ;; esac
# Only act if the existing remote URL doesn't already match a target form.
```

### 5c. Remove templatedir-installed hooks from Dolt's internal git-remote-cache

If `init.templatedir` is set with hooks installed (pre-flight detects this), templated hooks were copied into Dolt's internal git-remote-cache when `bd init` created it. Those fire pre-commit framework on every `bd dolt push` and crash with `fatal: this operation must be run in a work tree`.

```sh
rm -rf .beads/embeddeddolt/*/.dolt/git-remote-cache/*/repo.git/hooks/
```

Permanently delete — Dolt's internal git operations don't need them.

### 5d. Seed `refs/dolt/data` on the remote

```sh
bd dolt push
git ls-remote origin refs/dolt/data   # non-empty hash = success
```

If the push fails with a credential-prompt error, that's the Dolt v1.81.10 bug — switch to ssh form via `bd dolt remote remove origin && bd dolt remote add origin "git+ssh://git@github.com:<user>/<repo>.git" && bd dolt push`.

### 5e. Disable JSONL auto-staging

Append (or set) `export.git-add: false` in `.beads/config.yaml`. Leave `export.auto: true` (default) so the file stays fresh on disk for IDE visibility — it just never gets staged.

```yaml
export.git-add: false
```

### 5f. Add `.beads/issues.jsonl` to project `.gitignore`

Append to the **project root** `.gitignore` (not `.beads/.gitignore`, which `bd init` may regenerate):

```gitignore
# Beads exports — source of truth is Dolt + refs/dolt/data on origin.
.beads/issues.jsonl
```

Idempotent: skip if already present.

### 5g. Untrack the JSONL (only if currently tracked)

```sh
git ls-files --error-unmatch .beads/issues.jsonl >/dev/null 2>&1 \
  && git rm --cached .beads/issues.jsonl \
  || echo "(JSONL already untracked — skipping)"
```

The on-disk copy stays.

## Step 6: Commit and verify

Stage only what changed and commit:

```sh
git add .beads/.gitignore .beads/config.yaml .beads/metadata.json \
        .beads/hooks/ .gitignore .claude/settings.json 2>/dev/null
git status   # confirm: .beads/issues.jsonl shows DELETED if 5g ran, NOT modified
git commit -m "chore: modernise beads — embedded Dolt, refs/dolt/data remote, JSONL gitignored" \
           -m "<one-paragraph summary>"
```

If a `pre-commit` framework hook auto-fixes files, the first commit will fail. Re-stage and commit again.

Verify:

```sh
echo "===bd stats==="; bd stats | head -8
echo "===remote list==="; bd dolt remote list
echo "===refs/dolt/data on origin==="; git ls-remote origin refs/dolt/data
echo "===tracked .beads files==="; git ls-files .beads/
echo "===running dolt server==="; ps -ef | grep "dolt sql-server" | grep -v grep || echo "(none)"
echo "===log==="; git log --oneline -3
```

Expected:

- `bd stats` total matches `$ORIG_LINES` from Step 1
- `bd dolt remote list` shows exactly one remote, the GitHub git+(https|ssh) form
- `git ls-remote origin refs/dolt/data` returns a non-empty hash
- `git ls-files .beads/` shows `.gitignore`, `README.md`, `config.yaml`, `metadata.json`, `hooks/*` — but NOT `issues.jsonl`
- No `dolt sql-server` process for this project

Report a brief summary to the user: which path ran (fast-path vs nuke-and-pave), issue count preserved, any decisions made.

## Step 7 (optional): Push

This skill does not push the resulting commit — push (or open a PR) per the project's own workflow conventions.

## Reverting from `/bd-enable-server-mode`

`/bd-enable-server-mode` flips `dolt_mode` to `"server"`. To go back: re-run `/bd-modernize`. Pre-flight detects `dolt_mode != "embedded"`, sets `IS_LEGACY=yes`, and the nuke-and-pave pipeline rebuilds in embedded mode.

## Known issues / footnotes

- The deadlock between `bd init`'s post-init commit and bd's pre-commit hook is real on bd 1.0.x embedded mode. `BEADS_HOOK_TIMEOUT=2` is the resolution; on systems without `timeout` (older macOS without coreutils), fall back to manual `pkill -9 -f "bd export"`.
- Dolt v1.81.10 has a bug where git-remote operations fail if `git` requires interactive STDIN for credentials. Use `git+ssh://` URL form (ssh-agent) or set up a git credential helper.
- Cache-hooks removal in Step 5c is permanent. If `pre-commit` framework is later reinstalled with `init.templatedir` regenerated, you may need to re-run that `rm` once.
- Don't run `bd init` ad-hoc on an already-modernised project later — it would re-add `.beads/hooks/` and (without `--skip-agents`) re-add the BEADS INTEGRATION blocks to CLAUDE.md / AGENTS.md.
- `.beads/config.yaml` preservation only applies on already-modern projects (`IS_LEGACY=no`). Pre-1.0 projects' config files use the legacy schema and aren't worth preserving.
- If the user wants `.beads/issues.jsonl` kept in git for visibility (e.g. so PR reviewers can see issue diffs), skip Step 5e/5f/5g and accept the cross-PR conflict pattern. This is unusual.
