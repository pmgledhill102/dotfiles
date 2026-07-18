# Agent Instructions

This project uses **GitHub Issues** for issue tracking, per the global
conventions (sub-issue hierarchy, P0–P4 priority labels, `type: *` labels,
blocked-by dependencies — see `agentic-coding-config`
`docs/github-issues-workflow.md`).

```bash
gh issue list --search "is:open -is:blocked"   # Find available work
gh issue view <n>                              # View issue details
gh issue edit <n> --add-assignee @me           # Claim work
gh issue close <n> --comment "Shipped in #<pr>"  # Complete work
```

## Session Completion

Work is NOT complete until `git push` succeeds.

1. Close finished issues (or let `Closes #<n>` in the PR body do it on merge)
2. Create issues for remaining work
3. Commit and push code changes
4. Verify `git status` shows "up to date with origin"

## Rules

- Use GitHub Issues for ALL task tracking — no markdown TODOs
- Use `gh issue list` / direct reads, never `gh search issues`, for anything
  time-sensitive (search is eventually consistent)
- Always push before ending a session
