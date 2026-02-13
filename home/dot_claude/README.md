# Claude Code Configuration

Centralized configuration for Claude Code across all repositories — hooks, slash commands, and language-specific setup templates.

## Design Principle

When linting, formatting, and security tools are configured, they become the enforcement mechanism. Claude Code doesn't need to *know* your standards — it just sees failures and fixes them.

This configuration separates **one-time setup** from **ongoing enforcement**, keeping context costs low:

| Concern | Solution | Context Cost |
| ------- | -------- | ------------ |
| Setting up a new project | Slash commands (`/setup-python`) | Loaded only when invoked |
| Enforcing standards during coding | Hooks that run tools automatically | Zero — tool output is the context |
| High-level policy | Lean CLAUDE.md | ~20-30 lines |

## Enforcement Layers

Checks are enforced at three layers, from most authoritative to most immediate. Higher layers are always-on and catch everything; lower layers are optional optimizations that provide faster feedback.

### Layer 1: CI (Always Enforced)

CI runs on every push/PR. This is the **source of truth** — nothing merges without passing. Each `/setup-*` slash command includes a CI workflow snippet for the relevant language.

### Layer 2: Git Pre-commit Hooks

Pre-commit hooks run the same checks locally before code leaves the developer's machine. They catch issues earlier than CI and reduce round-trips. The `/setup-common` command installs the [pre-commit](https://pre-commit.com/) framework, and each language command registers its tools into it.

### Layer 3: Claude Code Hooks (Optional Optimization)

Claude Code hooks provide **immediate feedback during editing**. Only use these for tools that are fast, deterministic, and auto-fix — so Claude doesn't waste turns on formatting.

**Good candidates for file-level hooks (PostToolUse):**

- Formatters in fix mode (ruff format, prettier, rustfmt, gofmt)
- Fast linters with auto-fix (ruff check --fix, eslint --fix)

**Keep at pre-commit / CI only:**

- Type checkers (mypy, pyright, tsc) — need full project context
- Security scanners (bandit, trivy) — slow, project-wide
- Complex linters (golangci-lint with many checks) — too slow per-file

## Tooling Matrix

Each `/setup-*` slash command configures the tools listed below. All commands are **additive and composable** — run `/setup-common` first for the foundation, then stack any combination.

| Language | Formatting | Linting | Type Checking | Security | Deps Audit |
| -------- | ---------- | ------- | ------------- | -------- | ---------- |
| **Common** | — | — | — | gitleaks | — |
| **Markdown** | prettier | markdownlint-cli2 | — | — | — |
| **Shell** | shfmt | shellcheck | — | — | — |
| **Docker** | — | hadolint | — | trivy | — |
| **Terraform** | terraform fmt | tflint, terraform validate | — | tfsec, checkov | — |
| **Go** | gofmt / goimports | golangci-lint | — | — | govulncheck |
| **Python** | ruff | ruff | mypy / pyright | bandit | — |
| **.NET / C#** | dotnet format | Roslyn analysers | — | SecurityCodeScan | dotnet outdated |
| **Rust** | rustfmt | clippy | — | — | cargo-audit, cargo-deny |
| **Java** | google-java-format / spotless | checkstyle, SpotBugs, PMD | — | — | OWASP dependency-check |
| **Ruby** | rubocop | rubocop | — | brakeman | bundler-audit |
| **PHP** | PHP-CS-Fixer / PHP_CodeSniffer | PHPStan / Psalm | — | — | composer audit |
| **Node.js** | prettier | eslint | — | — | npm audit |
| **TypeScript** | prettier | eslint + typescript-eslint | tsc --noEmit | — | npm audit |

### Which Layer Runs What

| Tool Category | CI | Pre-commit | Claude Hook |
| ------------- | :-: | :--------: | :---------: |
| Formatters | yes | yes | yes (auto-fix on write) |
| Fast linters | yes | yes | optional (auto-fix on write) |
| Type checkers | yes | yes | no |
| Security scanners | yes | yes | no |
| Dependency audits | yes | no | no |

## Directory Structure

```text
~/.claude/
├── settings.json              # Universal hooks (runs on every repo)
├── CLAUDE.md                  # Universal policy (loaded on every repo)
└── commands/
    ├── setup-common.md        # Shared tooling (pre-commit, gitleaks)
    ├── setup-shell.md
    ├── setup-markdown.md
    ├── setup-docker.md
    ├── setup-terraform.md
    ├── setup-go.md
    ├── setup-python.md
    ├── setup-dotnet.md
    ├── setup-rust.md
    ├── setup-java.md
    ├── setup-ruby.md
    ├── setup-php.md
    ├── setup-node.md
    └── setup-typescript.md
```

## Slash Commands

Each `/setup-*` command contains:

1. Tool installation commands
2. Configuration file contents
3. Pre-commit hook registration
4. CI workflow snippet

**New project setup:**

```text
/setup-common
/setup-python
```

**Day-to-day coding:**
Claude Code edits files -> hooks auto-run -> Claude sees failures -> fixes them. No context spent on rules — tooling output *is* the context.

## Hook Configuration Examples

**Pre-commit hook (Layer 2):**

```json
{
  "hooks": {
    "PreCommit": [
      {
        "command": "pre-commit run --all-files 2>&1 | tail -40"
      }
    ]
  }
}
```

**File-level auto-fix (Layer 3):**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "write_file|edit_file|create_file",
        "command": "prettier --write $CLAUDE_FILE_PATHS 2>&1 | tail -5"
      }
    ]
  }
}
```

## Customisation

- **Project overrides**: Add `.claude/settings.json` in any repo to extend/override user-level hooks
- **Subdirectory context**: Add `CLAUDE.md` files in subdirectories for monorepo language-specific context
- **New languages**: Copy an existing setup command and adapt the tool list
