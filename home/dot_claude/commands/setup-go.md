Set up Go linting, formatting, and security scanning for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

## What to install and configure

### 1. golangci-lint

Create `.golangci.yml` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```yaml
linters:
  enable:
    - errcheck
    - govet
    - staticcheck
    - unused
    - gosimple
    - ineffassign
    - typecheck
    - goimports
    - revive
    - misspell
    - gosec

linters-settings:
  goimports:
    local-prefixes: # Leave empty — user should set to their module path
  revive:
    rules:
      - name: exported
        severity: warning

issues:
  exclude-use-default: false
  max-issues-per-linter: 0
  max-same-issues: 0

run:
  timeout: 5m
```

Tell the user to set `local-prefixes` under `goimports` to their Go module path.

### 2. .gitignore

Append these lines to `.gitignore` if they aren't already present:

```gitignore
# Go
bin/
dist/
*.exe
*.test
*.out
coverage.out
coverage.html
vendor/
```

### 3. Add pre-commit hooks

Append these repos to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/golangci/golangci-lint
    rev: <latest tag>
    hooks:
      - id: golangci-lint

  - repo: https://github.com/tekwizely/pre-commit-golang
    rev: <latest tag>
    hooks:
      - id: go-fumpt
```

Look up the latest release tag for each repo and use those for the `rev:` values.

### 4. GitHub Actions workflow

Create or update the CI workflow to include Go lint and vulnerability scanning jobs that only run when Go files change. Use a separate workflow file (e.g., `.github/workflows/go.yml`) with path filters, or add jobs to an existing workflow.

```yaml
name: Go
on:
  push:
    paths: ['**/*.go', 'go.mod', 'go.sum']
  pull_request:
    paths: ['**/*.go', 'go.mod', 'go.sum']

jobs:
  lint:
    name: Go Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - uses: golangci/golangci-lint-action@v6

  govulncheck:
    name: Govulncheck
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - name: Install govulncheck
        run: go install golang.org/x/vuln/cmd/govulncheck@latest
      - name: Run govulncheck
        run: govulncheck ./...
```

Don't duplicate if Go lint jobs already exist. Look up latest action versions.

### 5. govulncheck (local)

Check if `govulncheck` is installed (`go install golang.org/x/vuln/cmd/govulncheck@latest`). If not, tell the user to install it. It's run manually or in CI (above), not as a pre-commit hook (too slow).

### 6. Dependabot ecosystem

Read `.github/dependabot.yml` and add the `gomod` ecosystem entry if it isn't already present. Don't duplicate entries.

```yaml
  - package-ecosystem: "gomod"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "deps"
      include: "scope"
    labels:
      - "dependencies"
      - "go"
    open-pull-requests-limit: 5
```

### 7. Verify

Run `pre-commit run --all-files` to confirm hooks work. Fix any lint issues.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- If there's no `go.mod`, warn the user — Go tooling requires a module.
