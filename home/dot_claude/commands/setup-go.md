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

### 2. Add pre-commit hooks

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

### 3. govulncheck

Check if `govulncheck` is installed (`go install golang.org/x/vuln/cmd/govulncheck@latest`). If not, tell the user to install it. It's run manually or in CI, not as a pre-commit hook (too slow).

Suggest adding to CI:

```yaml
- name: Run govulncheck
  run: govulncheck ./...
```

### 4. Verify

Run `pre-commit run --all-files` to confirm hooks work. Fix any lint issues.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- If there's no `go.mod`, warn the user — Go tooling requires a module.
