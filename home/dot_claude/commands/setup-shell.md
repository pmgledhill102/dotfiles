Set up shell script linting and formatting for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

## What to install and configure

### 1. ShellCheck

Create `.shellcheckrc` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```
# Default shell dialect
shell=bash

# Allow sourcing from paths that can't be followed
external-sources=true

# Disable specific rules if needed (keep this minimal)
# disable=SC1091
```

### 2. shfmt

shfmt reads its config from `.editorconfig` (indent_style and indent_size). Confirm `.editorconfig` exists and has sane defaults for shell files. If not, add:

```ini
[*.sh]
indent_style = space
indent_size = 2
binary_next_line = true
switch_case_indent = true
```

### 3. .gitignore

No shell-specific entries needed. Confirm `/setup-common` has already created a `.gitignore` with the standard entries (OS files, editor files, `.env`).

### 4. Add pre-commit hooks

Append these repos to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: <latest tag>
    hooks:
      - id: shellcheck
        args: ["--severity=warning"]

  - repo: https://github.com/scop/pre-commit-shfmt
    rev: <latest tag>
    hooks:
      - id: shfmt
```

Look up the latest release tag for each repo and use those for the `rev:` values.

### 5. GitHub Actions workflow

Create or update the CI workflow to include a ShellCheck job that only runs when shell files change. Use a separate workflow file (e.g., `.github/workflows/shell.yml`) with path filters, or add a job to an existing workflow.

```yaml
name: Shell
on:
  push:
    paths: ['**/*.sh', '**/*.bash']
  pull_request:
    paths: ['**/*.sh', '**/*.bash']

jobs:
  shellcheck:
    name: ShellCheck
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ludeeus/action-shellcheck@master
        with:
          scandir: '.'
```

Don't duplicate if a ShellCheck job already exists. Look up the latest pinned commit SHA for `ludeeus/action-shellcheck`.

### 6. Verify

Run `pre-commit run --all-files` to confirm hooks work. Fix any lint or formatting issues.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- If the project has `.bash` or other non-`.sh` extensions, add `types_or: [bash, sh]` to the shellcheck hook.
