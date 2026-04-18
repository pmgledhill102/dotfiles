Migrate this project's beads (`bd`) installation from server-mode Dolt to embedded Dolt, preserving all existing issues. Embedded mode has been the default since `bd` v0.63.3 — no separate `dolt sql-server`, no port collisions, no stale lock/pid files.

## Pre-flight checks (do these first; stop if any fail)

1. Run `bd version` and confirm it's ≥ 1.0. If not, tell the user to upgrade `bd` first (e.g. `brew upgrade beads` on macOS) and stop.
2. Read `.beads/metadata.json`. If it already contains `"dolt_mode": "embedded"`, report "already migrated" with the `bd stats` summary and stop.
3. Check `git status`. If there are unrelated uncommitted changes, ask the user whether to proceed (the migration will create one commit) before continuing.
4. Identify the issue prefix:
   - Preferred: parse the first line of `.beads/issues.jsonl` (the `id` field is `<prefix>-<hash>` — strip the last `-` segment).
   - Fallback: use the basename of the project directory (this matches `bd init`'s default).
5. Identify whether a `dolt sql-server` is currently running for this project: read `.beads/dolt-server.pid` if present.

## Procedure

Brief the user on what you're about to do (one or two sentences, no decorative headings) before running destructive steps.

### 1. Preserve the issues JSONL

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

### 2. Stop the running Dolt server

```sh
if [ -f .beads/dolt-server.pid ]; then
  pid=$(cat .beads/dolt-server.pid)
  kill "$pid" 2>/dev/null || true
  sleep 1
  ps -p "$pid" >/dev/null 2>&1 && kill -9 "$pid" || true
fi
```

Only kill the PID recorded in this project's `.beads/dolt-server.pid` — never kill arbitrary `dolt sql-server` processes; other projects on the same machine may also be using server mode.

### 3. Wipe server-mode artifacts and runtime state

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

### 4. Disable git hooks (CRITICAL — required to avoid deadlock during `bd init`)

`bd` 1.0.x in embedded mode deadlocks when `bd` triggers its own internal `git commit` (e.g. `bd init`'s post-init commit, `bd dolt remote remove`'s config commit). The fired pre-commit hook calls `bd export`, which cannot acquire the embedded-DB lock that the parent `bd` is still holding. Point `core.hooksPath` at an empty directory for the duration of the migration.

```sh
SAVED_HOOKS_PATH=$(git config --get core.hooksPath || true)
mkdir -p /tmp/empty-hooks-no-bd
git config core.hooksPath /tmp/empty-hooks-no-bd
```

Remember `$SAVED_HOOKS_PATH` (may be empty) so step 7 can restore it.

### 5. Re-init with embedded mode and import the JSONL

Use the prefix from pre-flight step 4. Embedded is the default — do NOT pass `--server`.

```sh
bd init --from-jsonl -p <prefix> --non-interactive --role=maintainer
```

Run this in the foreground. It typically completes in under 30s for small projects but can take longer if the JSONL is large. If it appears to hang past ~3 minutes, check `ps -ef | grep -E "bd init|bd export|git commit"` — a stuck `bd export` child indicates hooks fired despite the override and you need to kill the chain (`kill -9`) and investigate.

Verify the import:

```sh
bd stats   # Total Issues should match wc -l of the JSONL
```

If the count mismatches, STOP and surface the discrepancy — do not proceed to commit.

### 6. Remove auto-detected Dolt remote (if inappropriate)

`bd init` auto-detects the project's `git remote origin` and registers it as a Dolt remote (e.g. `git+ssh://git@github.com/<user>/<repo>.git`). Unless the project genuinely uses git-as-Dolt-blob-store (rare), this remote will fail every auto-push with `auto-push failed: ...` warnings.

```sh
bd dolt remote list
```

If a `git+ssh://...` or `https://github.com/...` remote was registered and the user has not asked for Dolt-over-git-refs, remove it (hooks are still disabled, so this won't deadlock):

```sh
bd dolt remote remove origin
```

If you're unsure whether the user wants the remote, ask before removing.

### 7. Restore hooks

```sh
if [ -n "$SAVED_HOOKS_PATH" ]; then
  git config core.hooksPath "$SAVED_HOOKS_PATH"
else
  git config core.hooksPath "$PWD/.beads/hooks"
fi
```

### 8. Review and tidy `bd init`'s `CLAUDE.md` / `AGENTS.md` additions

`bd init` wraps its additions in `<!-- BEGIN BEADS INTEGRATION ... -->` / `<!-- END BEADS INTEGRATION -->` markers. The block contains a "Beads Issue Tracker" quick reference and a "Session Completion" section that mandates `git push` and `bd dolt push`.

Inspect both files. **Remove the BEADS INTEGRATION block** if any of these apply:

- The project already has an equivalent beads section (especially in `AGENTS.md` — bd init's block usually duplicates what's there).
- The "Session Completion" guidance contradicts the project's actual workflow — common cases:
  - Ephemeral branches with no upstream (the SessionStart hook will say so)
  - No Dolt remote configured (you removed it in step 6)
  - The project doesn't use a `git push` workflow

Use the `Edit` tool to delete from the `<!-- BEGIN BEADS INTEGRATION` line through the `<!-- END BEADS INTEGRATION -->` line inclusive, plus the leading blank line. If the block is genuinely useful for this project (e.g. brand-new repo with no agent guidance), keep it.

### 9. Stage and commit

```sh
git add .beads/.gitignore .beads/config.yaml .beads/metadata.json \
        .beads/issues.jsonl .beads/hooks/ \
        .claude/settings.json AGENTS.md CLAUDE.md 2>/dev/null
git status   # confirm what's staged
git commit -m "chore: migrate beads to embedded Dolt backend" \
           -m "<one-paragraph summary of the changes>"
```

If the project's `pre-commit` framework is installed and auto-fixes files (typically trailing newlines on `.beads/config.yaml`, `.beads/metadata.json`, `.claude/settings.json`), the first commit will fail. Re-`git add` the modified files and commit again. External `git commit` from a shell does NOT deadlock — only `bd`-initiated internal commits do.

### 10. Verify the final state

```sh
bd stats                                                   # issue counts intact
bd dolt remote list                                        # only intentional remotes
ls .beads/                                                 # no dolt/, dolt-server.*, .local_version
ps -ef | grep "dolt sql-server" | grep -v grep || true     # no server for THIS project
git log --oneline -3
```

Report a brief summary to the user: issue count preserved, embedded mode active, any decisions made (remote removed?, BEADS INTEGRATION blocks removed?).

## Idempotency

Re-running this command on an already-migrated project should fall out at pre-flight step 2 (`metadata.json` already says `"dolt_mode": "embedded"`).

## Known issues / footnotes

- The hook deadlock between `bd`-initiated git commits and bd's pre-commit hook is a real characteristic of `bd` 1.0.2 embedded mode. The hooks-disabled window in this procedure is the workaround. Once migration is done, normal external `git commit` from a shell fires the hooks and works fine.
- Don't run `bd init` ad-hoc on an already-initialised project later — it may re-add the BEADS INTEGRATION blocks to `CLAUDE.md` / `AGENTS.md`.
- This command does not push the resulting commit. Push (or merge to main locally) per the project's own workflow conventions.
