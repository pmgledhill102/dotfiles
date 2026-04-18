Switch this project's beads (`bd`) installation from embedded local Dolt to local `dolt sql-server` mode, so multiple `bd` processes can write the same Dolt database concurrently. Use this only when you actually need that — most setups don't.

## When to use this

The default modern state (set up by `/bd-modernize`) is **embedded** Dolt: each `bd` invocation opens the Dolt files directly, with a file lock serialising any overlapping writes. That's fine for solo usage, sequential agents, and even multi-agent usage that doesn't actually overlap in time.

Server mode adds a long-running `dolt sql-server` daemon that arbitrates concurrent SQL writes from multiple `bd` clients. The cost: a daemon to manage (PID file, port, log, lifecycle), more failure modes (orphan processes, port collisions, version skew between server and CLI), and slightly higher per-command latency.

Run this skill when you have a concrete reason — for example, a cloud sandbox running multiple Claude agents on the same workspace, where two agents may issue `bd create` at the same instant. If you're not sure, you don't need it; stay on embedded.

## Reverting

There is no separate "disable server mode" skill by design. To go back to embedded: re-run `/bd-modernize`. Its Step A detects `dolt_mode: "server"` and migrates back.

## Pre-flight checks (do these first; stop if any fail)

1. Run `bd version` and confirm it's ≥ 1.0. If not, tell the user to upgrade `bd` first (e.g. `brew upgrade beads` on macOS) and stop.
2. Read `.beads/metadata.json`.
   - If `dolt_mode` is already `"server"`, report the current state with `bd stats` and stop. Nothing to do.
   - If `dolt_mode` is anything other than `"embedded"`, surface the value and stop — the project isn't in the expected starting state. Recommend running `/bd-modernize` first.
3. Confirm with the user, in one short sentence, that they actually want server mode for this project. Mention the cost (daemon to manage) and the reversal path (`/bd-modernize`). Do not proceed without explicit yes.
4. Check `git status`. If there are unrelated uncommitted changes, ask whether to proceed (this command produces one commit) before continuing.
5. Check for port collisions: pick a port (default `3306` for Dolt, but other beads projects on this machine may already be using it). Inspect `~/dev/*/.beads/dolt-server.port` (or whatever the convention is on this machine) to find ports already in use, and pick the next free one. Surface the chosen port to the user before starting the server.

## Procedure

Brief the user in one sentence on what's about to happen.

### 1. Disable git hooks (CRITICAL — same deadlock as `/bd-modernize`)

Server mode doesn't have the embedded-DB lock issue, but the transition itself involves `bd` invocations that may trigger hooks during a state where the database is being reconfigured. Be safe:

```sh
SAVED_HOOKS_PATH=$(git config --get core.hooksPath || true)
mkdir -p /tmp/empty-hooks-no-bd
git config core.hooksPath /tmp/empty-hooks-no-bd
```

Remember `$SAVED_HOOKS_PATH` (may be empty) so step 6 can restore it.

### 2. Update `.beads/metadata.json`

Flip `dolt_mode` from `"embedded"` to `"server"`. Use `jq` if available so the rest of the file is preserved exactly:

```sh
tmp=$(mktemp)
jq '.dolt_mode = "server"' .beads/metadata.json > "$tmp" && mv "$tmp" .beads/metadata.json
```

Verify:

```sh
jq -r .dolt_mode .beads/metadata.json   # should print: server
```

### 3. Start the Dolt server

Use `bd` to start the server so it picks up the metadata change and writes the standard runtime files (`dolt-server.pid`, `dolt-server.port`, `dolt-server.log`):

```sh
bd dolt server start --port <chosen-port-from-pre-flight-5>
```

(If `bd dolt server start` is not the exact command — check `bd dolt --help` and `bd dolt server --help` and use the actual subcommand. Some bd versions name it differently. Update this skill if the command moved.)

Wait a few seconds, then verify:

```sh
cat .beads/dolt-server.pid                 # PID of the running server
cat .beads/dolt-server.port                # the port we chose
ps -p "$(cat .beads/dolt-server.pid)"      # confirm process is alive
```

### 4. Smoke-test issue access via the server

```sh
bd stats                                    # issue counts intact, no errors
bd list --status=open --limit=5             # sanity check that queries work
```

If either errors, STOP. Common causes: server failed to bind the port, metadata.json is malformed, or the embedded Dolt files weren't preserved through the mode flip. Investigate before proceeding.

### 5. Verify the Dolt git remote still works

The remote (set up by `/bd-modernize`) should be unaffected by the local mode change — they're orthogonal. Confirm:

```sh
bd dolt remote list                         # the GitHub git+(https|ssh) remote should still be there
bd dolt push                                # should succeed (no-op if Dolt content unchanged)
git ls-remote origin refs/dolt/data         # remote ref still present
```

### 6. Restore hooks

```sh
if [ -n "$SAVED_HOOKS_PATH" ]; then
  git config core.hooksPath "$SAVED_HOOKS_PATH"
else
  git config core.hooksPath "$PWD/.beads/hooks"
fi
```

### 7. Stage and commit

Only `metadata.json` should have changed in git's view (the runtime files — `dolt-server.pid`, `.lock`, `.log`, `.port` — are gitignored).

```sh
git status   # confirm only .beads/metadata.json is staged
git add .beads/metadata.json
git commit -m "chore: enable beads server mode for concurrent writers" \
           -m "Switches dolt_mode to server. Local sql-server now arbitrates concurrent bd writes from multiple agents on this machine. Reverse with /bd-modernize."
```

If a `pre-commit` framework auto-fixes the file, re-stage and commit again.

### 8. Verify the final state

```sh
bd stats                                    # issue counts unchanged from before
jq -r .dolt_mode .beads/metadata.json       # server
ps -p "$(cat .beads/dolt-server.pid)"       # alive
bd dolt remote list                         # remote intact
git log --oneline -1                        # the commit you just made
```

Report a brief summary to the user: server running on port `<port>`, PID `<pid>`, issue counts preserved, remote intact.

## Idempotency

Re-running this command on a project already in server mode falls out at pre-flight step 2 with "already in server mode" and the current `bd stats`.

## Known issues / footnotes

- Server mode adds the orphan-process risk: if the machine reboots or `bd` crashes, `dolt-server.pid` may point at a dead PID. `bd` 1.0.x typically detects and re-starts but if commands hang or error with "could not connect to server", check `ps -p "$(cat .beads/dolt-server.pid)"` and restart manually with the same `bd dolt server start` invocation.
- Port management is per-machine, not per-project. If you run server mode in multiple projects on one machine, each needs a unique port. Pick from `3307`, `3308`, etc. above the Dolt default of `3306`.
- The `dolt-server.{pid,port,lock,log}` files are gitignored by `.beads/.gitignore` (managed by `bd init`). Don't commit them.
- This command does not push — push (or open a PR) per the project's own workflow conventions.
