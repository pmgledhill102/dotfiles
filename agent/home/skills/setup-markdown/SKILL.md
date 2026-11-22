---
name: setup-markdown
description: Set up markdown linting and formatting for a project — markdownlint-cli2 and prettier, wired into pre-commit and CI.
---

# Set up markdown linting

## What to install and configure

### 1. markdownlint-cli2

Create `.markdownlint.yaml` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```yaml
# Default state for all rules
default: true

# MD013 - Line length
MD013: false

# MD033 - Inline HTML
MD033: false

# MD041 - First line should be a top-level heading
MD041: false
```

### 2. Prettier (markdown formatting)

Add markdown configuration to `.prettierrc` (create if needed, merge if exists):

```json
{
  "proseWrap": "always",
  "printWidth": 120,
  "tabWidth": 2
}
```

Create `.prettierignore` if it doesn't exist:

```text
CHANGELOG.md
```

### 3. Add pre-commit hooks

Append these repos to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/DavidAnson/markdownlint-cli2
    rev: v0.23.2
    hooks:
      - id: markdownlint-cli2
```

Use the `rev:` shown, not the latest tag. It is the estate pin from agentic-coding-config's `cloud/precommit-warm.yaml`, which the cloud bootstrap pre-builds, so a new repo's first commit in a sandbox needs no hook build. Bumps go through that file.

For the prettier hook, do **not** use `pre-commit/mirrors-prettier` — it is archived and no longer receives releases. Use a `repo: local` hook running the project's own binary. If the project has a `package.json`, add prettier as a devDependency (`npm install -D prettier`) and use:

```yaml
  - repo: local
    hooks:
      - id: prettier
        name: prettier
        entry: npx --no-install prettier --write
        language: system
        types_or: [markdown]
```

(`--no-install` matters: without it, a missing `node_modules` makes npx silently download some other version instead of failing.)

If the project has no `package.json` (a docs-only repo), either install prettier globally (`brew install prettier`) and use `entry: prettier --write`, or skip the prettier hook — markdownlint-cli2 already covers lint-level formatting.

### 4. GitHub Actions workflow

Create or update the CI workflow to include a markdown lint job that only runs when markdown files change.

```yaml
  markdown-lint:
    name: Markdown Lint
    runs-on: ubuntu-latest
    if: >-
      github.event_name == 'push' ||
      (github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name == github.repository)
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - uses: DavidAnson/markdownlint-cli2-action@<full-sha> # <version>
```

Add a path filter on the workflow trigger so this job only runs when relevant files change:

```yaml
on:
  push:
    paths: ['**/*.md']
  pull_request:
    paths: ['**/*.md']
```

If there's already a CI workflow with broader triggers, add the job there and use a job-level `if` with `github.event.pull_request` changed files, or create a separate workflow file (e.g., `.github/workflows/markdown.yml`) with the path filter. Don't duplicate if a markdown lint job already exists.

### 5. Verify

Run `pre-commit run --all-files` to confirm. Fix any markdown lint issues that surface.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `setup-common` first.
