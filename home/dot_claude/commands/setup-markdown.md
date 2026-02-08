Set up markdown linting and formatting for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

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
    rev: <latest tag>
    hooks:
      - id: markdownlint-cli2

  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: <latest tag>
    hooks:
      - id: prettier
        types_or: [markdown]
```

Look up the latest release tag for each repo and use those for the `rev:` values.

### 4. Verify

Run `pre-commit run --all-files` to confirm. Fix any markdown lint issues that surface.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
