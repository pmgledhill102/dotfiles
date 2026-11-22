---
name: setup-go
description: Set up Go formatting, linting and vulnerability scanning for a project — gofmt, goimports, golangci-lint and govulncheck, wired into pre-commit and CI.
---

# Set up Go tooling

## What to install and configure

### 1. golangci-lint

Create `.golangci.yml` in the project root (if it doesn't already exist). If one exists, review and suggest additions — and if it's in the v1 schema (top-level `linters-settings`, no `version` key), migrate it: golangci-lint v2 rejects v1 configs outright.

```yaml
# golangci-lint v2 schema. The v1 layout (top-level linters-settings, gosimple
# as its own linter) is rejected outright by v2.
version: "2"

linters:
  enable:
    - errcheck
    - govet
    - staticcheck
    - unused
    - ineffassign
    - revive
    - misspell
    - gosec
  settings:
    revive:
      rules:
        - name: exported
          severity: warning

formatters:
  enable:
    - gofmt
    - goimports
  settings:
    goimports:
      local-prefixes:
        - <module path>  # set to the module path from go.mod

issues:
  max-issues-per-linter: 0
  max-same-issues: 0

run:
  timeout: 5m
```

Replace `<module path>` with the module path from `go.mod`. v2 schema gotchas, in case you are adapting an existing config:

- `gosimple` was merged into `staticcheck` and `typecheck` was never a real enableable linter — neither may appear in `enable:`.
- Formatting tools (`gofmt`, `goimports`, `gofumpt`) live in the top-level `formatters:` block, not `linters:`.
- A settings key that is present but empty parses as `null` and fails `golangci-lint config verify` — even though `golangci-lint run` tolerates it. Omit the key entirely rather than leaving it blank. (`run` is generally more permissive than `config verify`, and CI runs `config verify` first — so a config can pass locally and still fail CI.)
- v1's `issues.exclude-use-default` is gone; exclusions are configured under `linters.exclusions`.

After writing the config, run `golangci-lint config verify` to confirm it parses — not just `golangci-lint run`.

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
      - id: golangci-lint-config-verify
      - id: golangci-lint
      - id: golangci-lint-fmt
```

Look up the latest release tag and use it for the `rev:` value. All three hooks come from the one binary, so hook and CI can never run different versions:

- `golangci-lint-config-verify` catches the run/verify strictness gap locally instead of in CI (it only fires when `.golangci.yml` changes).
- `golangci-lint-fmt` runs the `formatters:` block (`gofmt`/`goimports`), replacing any separate formatting hook — do not add `tekwizely/pre-commit-golang` alongside it.

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
      - uses: actions/checkout@<full-sha> # <version>
      - uses: actions/setup-go@<full-sha> # <version>
        with:
          go-version-file: go.mod
      - uses: golangci/golangci-lint-action@<full-sha> # <version>

  govulncheck:
    name: Govulncheck
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - uses: actions/setup-go@<full-sha> # <version>
        with:
          go-version: stable
      - name: Install govulncheck
        run: go install golang.org/x/vuln/cmd/govulncheck@latest
      - name: Run govulncheck
        run: govulncheck ./...
```

The two jobs deliberately select the toolchain differently, so keep them as
written. Lint asks "does this code hold up under the version the module claims
to support?", which is `go-version-file: go.mod` — the module's compatibility
floor. Govulncheck asks "is anything here known-vulnerable today?", and it
scans the standard library of whatever toolchain it runs under: pointed at the
floor it reports every stdlib fix released since that version, which is a large
count of findings that the module cannot act on, so it gets `go-version:
stable`.

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
    cooldown:
      default-days: 7
```

### 7. Verify

Run `pre-commit run --all-files` to confirm hooks work. Fix any lint issues.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `setup-common` first.
- If there's no `go.mod`, warn the user — Go tooling requires a module.
