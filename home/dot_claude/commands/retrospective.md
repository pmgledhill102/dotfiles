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
- **Missing tools**: Were any CLI tools, SDK components, or binaries expected but not installed or not at the required version? For each:
  - What was attempted and what error or fallback occurred?
  - Is the tool installable via Homebrew, apt, pip, npm, or a component manager (e.g., `gcloud components install alpha`)?
  - Should the tool be added to the dotfiles repo (e.g., Brewfile, chezmoi scripts) so it's provisioned across all workstations?
- **MCP opportunities**: Were CLI tools used via Bash where an MCP server could provide safer, more granular access? Look for:
  - **Approval friction from dual-use CLIs**: Commands that were used read-only (e.g., `gh api` to query releases, `gcloud` to list resources) but couldn't be auto-approved because the same command can also perform destructive actions. An MCP server with scoped, read-only tools would eliminate this friction.
  - **Repeated Bash commands for API queries**: Chains of `gh`, `gcloud`, `aws`, `kubectl`, or similar CLI calls that could be replaced by a dedicated MCP server offering structured, auto-approvable tools.
  - **Already-connected MCP servers that went unused**: Check if configured MCP servers had tools that could have replaced Bash commands used in this session.
  - For each opportunity, name the specific MCP server (if one exists) or note that one should be found/built.
- **Claude addon opportunities**: Did this session manually perform work that an official Claude skill, plugin, or Anthropic-published MCP server already handles? Distinct from the MCP bullet above (that one targets read-only CLI friction); this one targets procedural automation that's already packaged. Prefer official/Anthropic-published addons over community equivalents and over hand-rolled slash commands. Look for:
  - **Skills**: A repeated procedure that overlaps with an installed or marketplace skill — e.g. configuring `settings.json`, scaffolding language tooling, drafting commit messages, reviewing PRs. Check `~/.claude/skills/` and the in-session "available skills" list before proposing a new slash command.
  - **Plugins**: A coherent bundle (skill + commands + hooks together) that a published Claude Code plugin would provide in one install. Check `claude plugin marketplace` before bundling something in-house.
  - **Anthropic-published MCP servers**: Was a third-party/community MCP (or a raw CLI in Bash) used where Anthropic now ships a first-party equivalent? Official servers tend to track auth and permissions better.
  - For each, name the specific addon, mark it official vs community, and explain what manual work or hand-rolled command it would replace.
- **Memory updates**: Were learnings captured in auto-memory files, or were they missed?
- **Beads hygiene**: Were issues created before work started? Were they closed properly?
- **Slash command opportunities**: Did this session perform a procedure that's likely to be repeated — either across other projects, or periodically in this one? Strong signals:
  - The user explicitly mentioned having other projects/contexts that need the same treatment
  - The procedure had non-obvious ordering, workarounds, or gotchas that would be easy to forget on a re-run (the kind of thing where you'd think "I hope I remember to do step 4 first next time")
  - Five-plus coherent sequential steps completed a single logical task
  - A back-out/retry happened because a step was performed in the wrong order, missing a pre-condition
  - Investigation took disproportionate time relative to the eventual fix (the *knowing what to do* was the hard part — and now we know)

  For each candidate, propose: a command name (kebab-case), a one-line description, the key pre-flight checks, and the gotchas the prompt must surface. Existing commands live at `~/.claude/commands/` (mirrored to `~/dev/dotfiles/home/dot_claude/commands/`) — check there first to avoid duplicates.

- **Slash command improvements**: Did this session invoke any existing slash command (or manually perform work that an existing one should have handled)? For each:
  - Was a step missing, wrong, or stale? (e.g. an upstream tool changed flags, a pre-flight check would have caught the failure earlier)
  - Did instructions cause a wrong decision via ambiguity?
  - Did we deviate from the command's plan? Why — and should the command codify the deviation?

  Recommend the specific edit (file path + which section). Treat existing commands the same way you'd treat a regularly-used script — they rot when tools and workflows around them evolve.

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

### Continue
- <things that worked well and should be kept — validated patterns, effective tools, approaches worth repeating>

### Start
- `[PENDING]` <new things to adopt — permissions to add, tools to install, MCP servers to configure, workflow changes>
- `[PENDING]` <another recommendation>

### Stop
- <anti-patterns observed, approaches that wasted time, mistakes to avoid repeating>
```

## Guidelines

- Be specific and actionable — not "improve error handling" but "add `google_project_service` explicit depends_on to prevent 403 race conditions"
- Include exact tool patterns for permission recommendations, e.g., `Bash(chezmoi apply)`
- Only **Start** items get `[PENDING]` tags — these are the actionable changes. **Continue** captures what's working. **Stop** captures what to avoid. Neither need status tracking.
- For missing tools, include **both** the immediate install command (e.g., `brew install foo`, `gcloud components install alpha`) **and** the dotfiles change needed to provision it everywhere (e.g., "add `foo` to `home/Brewfile`", "add `gcloud components install alpha` to the chezmoi setup script"). Recommend the user install the tool now and update dotfiles in the same session.
- For MCP recommendations, explain the **specific friction being solved** (e.g., "spent 5 approval prompts on read-only `gh api` calls that could be auto-approved via a GitHub MCP server"). Include the MCP server name/repo if known, and note whether it should be added to project-level or user-level `settings.json`.
- For Claude addon recommendations, **name the specific skill/plugin/MCP and mark it official vs community**, and cite the manual work or hand-rolled slash command it would replace. Default to suggesting an existing official addon before proposing a new in-house slash command.
- For new slash command proposals, include the **proposed name**, a **one-sentence description**, and the **most important gotcha or pre-flight check** the command must encode. Don't wait to be asked — if the session worked out a non-obvious procedure, surfacing it as a command is usually the highest-leverage recommendation.
- For slash command improvement recommendations, reference the **command file path** and cite the **specific deviation or failure mode** observed this session. "Add a pre-flight check that X" is more actionable than "improve robustness".
- Keep each entry concise — aim for 15-30 lines maximum
- If the session was uneventful with no notable friction, say so briefly and skip the detailed sections
- Reference specific errors, file paths, and bead IDs where relevant
