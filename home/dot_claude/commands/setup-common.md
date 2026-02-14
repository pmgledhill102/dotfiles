Set up the common development tooling foundation for this project. This is the base layer that language-specific setup commands build on.

## What to install and configure

### 1. EditorConfig

Create `.editorconfig` in the project root (if it doesn't already exist). If one exists, review it and suggest additions for any missing settings.

```ini
root = true

[*]
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
charset = utf-8
indent_style = space
indent_size = 2

[*.{go,py}]
indent_size = 4

[Makefile]
indent_style = tab
```

### 2. pre-commit framework

Create `.pre-commit-config.yaml` in the project root (if it doesn't already exist). If one exists, review it and suggest adding any missing hooks from below.

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: <latest tag>
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict

  - repo: https://github.com/gitleaks/gitleaks
    rev: <latest tag>
    hooks:
      - id: gitleaks
```

Look up the latest release tag for each repo and use those for the `rev:` values.

After creating/updating the config, run:

```sh
pre-commit install
```

If `pre-commit` is not installed, tell the user to install it (`brew install pre-commit`) and stop.

### 3. cspell (spell checking)

Create `cspell.json` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```json
{
  "version": "0.2",
  "language": "en-GB",
  "files": "\\.(md|txt|rst|yaml|yml)$",
  "ignorePaths": [
    "node_modules",
    "go.sum",
    "*.lock",
    ".git"
  ],
  "words": [],
  "dictionaries": ["en_GB", "softwareTerms", "companies", "misc"]
}
```

The `files` pattern limits cspell to prose-heavy file types — markdown, plain text, reStructuredText, and YAML. This avoids noise from code identifiers.

Add a cspell pre-commit hook to `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/streetsidesoftware/cspell-cli
    rev: <latest tag>
    hooks:
      - id: cspell
        types_or: [markdown, plain-text, yaml]
```

Look up the latest release tag and use it for the `rev:` value.

The `words` array is the project-specific dictionary. As cspell flags legitimate words during the verify step, add them here.

### 4. actionlint (GitHub Actions linting)

Add an actionlint pre-commit hook to `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/rhysd/actionlint
    rev: <latest tag>
    hooks:
      - id: actionlint
```

Look up the latest release tag and use it for the `rev:` value.

### 5. semgrep (static analysis)

Add a semgrep pre-commit hook to `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/semgrep/semgrep
    rev: <latest tag>
    hooks:
      - id: semgrep
        args: ['--config', 'auto']
```

Look up the latest release tag and use it for the `rev:` value.

The `--config auto` flag uses Semgrep's curated rulesets appropriate for the languages detected in the repo.

### 6. .gitignore

Create `.gitignore` if it doesn't exist, or append missing entries. Ensure it includes at least:

```gitignore
# OS
.DS_Store
Thumbs.db

# Editors
*.swp
*.swo
*~
.vscode/
.idea/

# Environment
.env
.env.local
.env.*.local
```

Read any existing `.gitignore` first and only add lines that are missing.

### 7. GitHub Actions workflows

Create or update CI workflows. Gitleaks, cspell, and semgrep run on all files (no path filter). Actionlint only needs to run when workflow files change.

Add to `.github/workflows/ci.yml` (or create if needed):

```yaml
  gitleaks:
    name: Gitleaks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  cspell:
    name: Spell Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: streetsidesoftware/cspell-action@v6
        with:
          files: '**/*.{md,txt,rst,yaml,yml}'

  semgrep:
    name: Semgrep
    runs-on: ubuntu-latest
    container:
      image: semgrep/semgrep
    steps:
      - uses: actions/checkout@v4
      - run: semgrep scan --config auto
```

Create a separate `.github/workflows/actionlint.yml` with a path filter (or add to existing CI with the same filter):

```yaml
name: Actionlint
on:
  push:
    paths: ['.github/workflows/**']
  pull_request:
    paths: ['.github/workflows/**']

jobs:
  actionlint:
    name: Actionlint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: rhysd/actionlint@main
```

Don't duplicate if any of these jobs already exist. Look up latest action versions. All action references should use pinned commit SHAs with a version comment, e.g.:

```yaml
- uses: actions/checkout@<full-sha> # v4
```

### 8. Dependabot auto-merge

Create `.github/workflows/dependabot-auto-merge.yml` (if it doesn't already exist):

```yaml
name: Dependabot Auto-merge
on: pull_request

permissions:
  contents: write
  pull-requests: write

jobs:
  auto-merge:
    runs-on: ubuntu-latest
    if: github.actor == 'dependabot[bot]'
    steps:
      - uses: actions/checkout@v4
      - run: gh pr review --approve "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - run: gh pr merge --auto --squash --delete-branch "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Also ensure `.github/dependabot.yml` exists with the base structure. If it doesn't exist, create it:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "ci(deps)"
      include: "scope"
    labels:
      - "dependencies"
      - "github-actions"
    open-pull-requests-limit: 5
```

If `.github/dependabot.yml` already exists, read it first and ensure the `github-actions` ecosystem entry is present. Don't duplicate entries.

> **Note:** Auto-merge requires branch protection or rulesets with required status checks enabled on the default branch. Without this, `--auto` merges immediately without waiting for CI.

### 9. Verify

Run `pre-commit run --all-files` to confirm everything works. Fix any issues that come up.

## Important

- Do NOT blindly overwrite existing config files. Read them first and merge.
