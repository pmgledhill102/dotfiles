# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get
started.

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status=in_progress  # Claim work
bd close <id>         # Complete work
```

## Session Completion

Work is NOT complete until `git push` succeeds.

1. Close finished issues (`bd close <id>`)
2. Create issues for remaining work (`bd create --title="..." --description="..."`)
3. Commit and push code changes
4. Verify `git status` shows "up to date with origin"

## Rules

- Use bd for ALL task tracking — no markdown TODOs or external trackers
- Always push before ending a session
- Link discovered work: `bd dep add <new> discovered-from:<parent>`
