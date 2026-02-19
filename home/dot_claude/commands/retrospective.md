Run a retrospective analysis of this session and append findings to `~/.claude/retros.md`.

## Steps

### 1. Read existing state

- Read `~/.claude/retros.md` (create it if it doesn't exist, with a `# Session Retrospectives` heading)
- Read `~/.claude/settings.json` to understand current permission settings

### 2. Analyse the session

Review the full conversation history and evaluate each of these dimensions. Skip any that aren't relevant to this session.

- **Approval friction**: Which tool calls required manual approval? Were any repeatedly approved and should be added to `allowedTools` in settings? Note the specific tool patterns.
- **CI round-trips**: How many push-then-fix cycles happened? What caused each failure? Could any have been caught locally first?
- **Errors and debugging**: What errors were encountered? How long did each take to resolve? Were any red herrings?
- **Approach pivots**: Where did the initial approach fail and require a different strategy? What was learned?
- **Prompt clarity**: Were instructions clear enough, or did ambiguity cause wasted work?
- **Tool gaps**: Were there tasks that no available tool handled well?
- **Memory updates**: Were learnings captured in auto-memory files, or were they missed?
- **Beads hygiene**: Were issues created before work started? Were they closed properly?

### 3. Check previous recommendations

Scan existing entries in `~/.claude/retros.md` for items marked `[PENDING]`. For each one:

- If it has been addressed (e.g., a setting was changed, a pattern was adopted), update it to `[DONE]`
- If it's still relevant, leave it as `[PENDING]`
- If it's no longer applicable, update it to `[SKIPPED]`

### 4. Write the entry

Append a new entry to `~/.claude/retros.md` using this format:

```markdown
---

## YYYY-MM-DD — <short session summary>

**Project**: <repo name or context>
**Duration**: <approximate, based on conversation length>
**Beads closed**: <list of bead IDs closed, or "none">

### What went well
- <bullet points>

### What didn't go well
- <bullet points>

### Recommendations
- `[PENDING]` <actionable recommendation with specific details>
- `[PENDING]` <another recommendation>
```

## Guidelines

- Be specific and actionable — not "improve error handling" but "add `google_project_service` explicit depends_on to prevent 403 race conditions"
- Include exact tool patterns for permission recommendations, e.g., `Bash(chezmoi apply)`
- Keep each entry concise — aim for 15-30 lines maximum
- If the session was uneventful with no notable friction, say so briefly and skip the detailed sections
- Reference specific errors, file paths, and bead IDs where relevant
