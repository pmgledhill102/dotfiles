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

## Pre-flight checks (do these first; stop if any fail)

1. Run `bd version` and confirm it's ≥ 1.0. If not, tell the user to upgrade `bd` first (e.g. `brew upgrade beads` on macOS) and stop.
2. Read `.beads/metadata.json` and `.beads/config.yaml`. Capture the current state across the three target axes:
   - **Local mode**: `metadata.json` field `dolt_mode` (`"server"` or `"embedded"`).
   - **Sync remote**: `bd dolt remote list` — does a `git+...` or `https://github.com/...` remote exist for this repo?
   - **JSONL tracked**: `git ls-files --error-unmatch .beads/issues.jsonl` — currently in git?
3. Determine which transitions are needed (Step A, B, C below). If all three are already at target, skip to Step G (verify and report).
4. Check `git status`. If there are unrelated uncommitted changes, ask the user whether to proceed (the modernisation creates one commit) before continuing.
5. Identify the project's GitHub origin URL: `git remote get-url origin`. If not GitHub (`github.com` host), the Dolt git-remote step won't work — surface this and ask whether to skip Step B or stop entirely.
6. Identify the issue prefix (only needed if Step A runs):
   - Preferred: parse the first line of `.beads/issues.jsonl` (the `id` field is `<prefix>-<hash>` — strip the last `-` segment).
   - Fallback: use the basename of the project directory (this matches `bd init`'s default).
7. If `dolt_mode=server`, identify whether a `dolt sql-server` is currently running for this project: read `.beads/dolt-server.pid` if present.

Brief the user in one or two sentences on which steps will run before any destructive action.

## Procedure

### Step A: Migrate to embedded Dolt — only if `dolt_mode=server`

Skip this entire section if pre-flight detected `dolt_mode: "embedded"` already.

#### A.1 Preserve the issues JSONL

```sh
# If the working-tree copy is missing but it's tracked at HEAD, restore it
if [ ! -f .beads/issues.jsonl ] && git ls-files --error-unmatch .beads/issues.jsonl >/dev/null 2>&1; then
  git restore .beads/issues.jsonl
fi
wc -l .beads/issues.jsonl
```

If `.beads/issues.jsonl` is genuinely missing (not just deleted from working tree), STOP and ask the user where the source-of-truth issue data lives — without it the migration will silently produce an empty database.

Make a timestamped backup outside the repo:

```sh
cp .beads/issues.jsonl /tmp/beads-issues-backup-$(basename "$PWD")-$(date +%s).jsonl
```

#### A.2 Stop the running Dolt server

```sh
if [ -f .beads/dolt-server.pid ]; then
  pid=$(cat .beads/dolt-server.pid)
  kill "$pid" 2>/dev/null || true
  sleep 1
  ps -p "$pid" >/dev/null 2>&1 && kill -9 "$pid" || true
fi
```

Only kill the PID recorded in this project's `.beads/dolt-server.pid` — never kill arbitrary `dolt sql-server` processes; other projects on the same machine may also be using server mode.

#### A.3 Wipe server-mode artifacts and runtime state

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
       .beads/metadata.json
```

Keep `.beads/.gitignore`, `.beads/config.yaml`, `.beads/README.md`, `.beads/issues.jsonl`.

#### A.4 Disable git hooks (CRITICAL — required to avoid deadlock during `bd init`)

`bd` 1.0.x in embedded mode deadlocks when `bd` triggers its own internal `git commit` (e.g. `bd init`'s post-init commit, `bd dolt remote remove`'s config commit). The fired pre-commit hook calls `bd export`, which cannot acquire the embedded-DB lock that the parent `bd` is still holding. Point `core.hooksPath` at an empty directory for the duration of the migration.

```sh
SAVED_HOOKS_PATH=$(git config --get core.hooksPath || true)
mkdir -p /tmp/empty-hooks-no-bd
git config core.hooksPath /tmp/empty-hooks-no-bd
```

Remember `$SAVED_HOOKS_PATH` (may be empty) so step A.7 can restore it.

#### A.5 Re-init with embedded mode and import the JSONL

Use the prefix from pre-flight step 6. Embedded is the default — do NOT pass `--server`.

```sh
bd init --from-jsonl -p <prefix> --non-interactive --role=maintainer
```

Run this in the foreground. It typically completes in under 30s for small projects but can take longer if the JSONL is large. If it appears to hang past ~3 minutes, check `ps -ef | grep -E "bd init|bd export|git commit"` — a stuck `bd export` child indicates hooks fired despite the override and you need to kill the chain (`kill -9`) and investigate.

Verify the import:

```sh
bd stats   # Total Issues should match wc -l of the JSONL
```

If the count mismatches, STOP and surface the discrepancy — do not proceed.

#### A.6 Remove auto-detected stale Dolt remote (only if it's the wrong shape)

`bd init` auto-detects the project's `git remote origin` and registers a Dolt remote, typically `git+ssh://git@github.com/<user>/<repo>.git`. If that's already the right form for the GitHub git-ref backend, leave it — Step B will accept it as-is.

If it's something else (a stale `dolthub://...`, a broken URL, etc.):

```sh
bd dolt remote list
bd dolt remote remove origin   # only if existing remote is wrong
```

Hooks are still disabled so this won't deadlock.

#### A.7 Restore hooks

```sh
if [ -n "$SAVED_HOOKS_PATH" ]; then
  git config core.hooksPath "$SAVED_HOOKS_PATH"
else
  git config core.hooksPath "$PWD/.beads/hooks"
fi
```

### Step B: Configure the Dolt git remote — only if not already set up

Skip if `bd dolt remote list` already shows a remote whose URL matches the project's GitHub origin (in any of the accepted forms: `https://github.com/...`, `git+https://...`, `git+ssh://git@github.com:...`).

Compute the canonical HTTPS URL from `git remote get-url origin` and add it via `bd` (not raw `dolt`) so the URL is persisted to `.beads/config.yaml` as `sync.remote` for fresh-clone bootstrap:

```sh
GH_URL=$(git remote get-url origin | sed -e 's|^git@github.com:|https://github.com/|')
case "$GH_URL" in
  *.git) ;;
  *) GH_URL="${GH_URL}.git" ;;
esac
bd dolt remote add origin "$GH_URL"
```

Confirm the remote was registered:

```sh
bd dolt remote list
```

Seed `refs/dolt/data` on the remote with the current Dolt content:

```sh
bd dolt push
```

Verify the ref exists on GitHub:

```sh
git ls-remote origin refs/dolt/data
```

A non-empty result confirms the remote is live. If the push fails with a credential prompt error, this is the known Dolt v1.81.10 bug — switch the remote URL to `git+ssh://git@github.com:<user>/<repo>.git` form (uses ssh-agent, no STDIN credential needed) and re-push:

```sh
bd dolt remote remove origin
bd dolt remote add origin "git+ssh://git@github.com:<user>/<repo>.git"
bd dolt push
```

### Step C: Stop committing the JSONL — only if currently tracked

Skip if `git ls-files --error-unmatch .beads/issues.jsonl` returns non-zero (already untracked).

#### C.1 Disable auto-staging

Update `.beads/config.yaml` to set `export.git-add: false`. Leave `export.auto: true` (default) so the file stays fresh on disk for IDE visibility — it just never enters commits. If the keys aren't already present, append:

```yaml
export:
  git-add: false
```

#### C.2 Add to project-level `.gitignore`

Append `.beads/issues.jsonl` to the **project root** `.gitignore` (not `.beads/.gitignore`, which is owned by `bd init` and may be regenerated). Group it under a `# Beads` section if one doesn't already exist:

```gitignore
# Beads exports (source of truth is Dolt; refs/dolt/data on origin is the sync channel)
.beads/issues.jsonl
```

#### C.3 Untrack the file

```sh
git rm --cached .beads/issues.jsonl
```

The on-disk copy stays — `git rm --cached` only removes it from git's index.

### Step D: Review and tidy `bd init`'s `CLAUDE.md` / `AGENTS.md` additions — only if Step A ran

`bd init` wraps its additions in `<!-- BEGIN BEADS INTEGRATION ... -->` / `<!-- END BEADS INTEGRATION -->` markers. The block contains a "Beads Issue Tracker" quick reference and a "Session Completion" section that mandates `git push` and `bd dolt push`.

Inspect both files. **Remove the BEADS INTEGRATION block** if any of these apply:

- The project already has an equivalent beads section (especially in `AGENTS.md` — bd init's block usually duplicates what's there).
- The "Session Completion" guidance contradicts the project's actual workflow — common cases:
  - Ephemeral branches with no upstream (the SessionStart hook will say so)
  - The project doesn't use a `git push` workflow

Use the `Edit` tool to delete from the `<!-- BEGIN BEADS INTEGRATION` line through the `<!-- END BEADS INTEGRATION -->` line inclusive, plus the leading blank line. If the block is genuinely useful for this project (e.g. brand-new repo with no agent guidance), keep it.

### Step E: Stage and commit

Stage only what was actually changed. Typical set:

```sh
git add .beads/.gitignore .beads/config.yaml .beads/metadata.json \
        .beads/hooks/ .gitignore \
        .claude/settings.json AGENTS.md CLAUDE.md 2>/dev/null
# If Step C ran, the staged set will include the deletion of .beads/issues.jsonl
git status   # confirm what's staged; should NOT include .beads/issues.jsonl as a modification
git commit -m "chore: modernise beads — embedded Dolt, git remote, JSONL gitignored" \
           -m "<one-paragraph summary of which steps actually ran>"
```

If the project's `pre-commit` framework is installed and auto-fixes files (typically trailing newlines on `.beads/config.yaml`, `.beads/metadata.json`, `.claude/settings.json`), the first commit will fail. Re-`git add` the modified files and commit again. External `git commit` from a shell does NOT deadlock — only `bd`-initiated internal commits do.

### Step F: Push

This command does not push the resulting commit — push (or open a PR) per the project's own workflow conventions. If Step B ran, `bd dolt push` was already done as part of seeding `refs/dolt/data`.

### Step G: Verify the final state

```sh
bd stats                                                   # issue counts intact
bd dolt remote list                                        # exactly one remote, the GitHub git+(https|ssh) form
git ls-remote origin refs/dolt/data                        # remote ref exists
ls .beads/                                                 # no dolt-server.*, no .local_version
git ls-files .beads/                                       # issues.jsonl NOT listed (tracked); README/config/metadata/hooks ARE listed
ps -ef | grep "dolt sql-server" | grep -v grep || true     # no server for THIS project
git log --oneline -3
```

Report a brief summary to the user: which transitions actually ran, issue count preserved, any decisions made (URL form chosen for the remote? CLAUDE.md/AGENTS.md blocks removed?).

## Idempotency

Each step is independently conditional. Re-running this command on an already-modernised project should:

- Pre-flight detect `dolt_mode=embedded`, correct git remote present, JSONL untracked
- Skip Steps A, B, C entirely
- Run Step G and report "already in target state"

## Reverting from `/bd-enable-server-mode`

`/bd-enable-server-mode` flips `dolt_mode` to `"server"`. To go back: just re-run `/bd-modernize` — Step A will detect server mode and migrate it back to embedded. No separate reverse skill exists by design.

## Known issues / footnotes

- The hook deadlock between `bd`-initiated git commits and bd's pre-commit hook is a real characteristic of `bd` 1.0.2 embedded mode. The hooks-disabled window in Step A is the workaround. Once modernisation is done, normal external `git commit` from a shell fires the hooks and works fine.
- Dolt v1.81.10 has a bug where git-remote operations fail if `git` requires interactive STDIN for credentials. Use `git+ssh://` URL form (ssh-agent) or set up a git credential helper to work around it.
- Don't run `bd init` ad-hoc on an already-initialised project later — it may re-add the BEADS INTEGRATION blocks to `CLAUDE.md` / `AGENTS.md`.
- If the user explicitly wants to keep `.beads/issues.jsonl` in git for visibility (e.g. so PR reviewers can see issue diffs), skip Step C and document why on the project. The conflict pattern across parallel feature branches will return.
