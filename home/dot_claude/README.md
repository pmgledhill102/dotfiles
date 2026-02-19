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

CI runs on every push/PR. This is the **source of truth** — nothing merges without passing. Each `/setup-*` slash command includes a CI workflow snippet for the relevant language. The `/setup-common` command also installs a Dependabot auto-merge workflow that approves and squash-merges Dependabot PRs once CI passes.

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

| Language | Formatting | Linting | Type Checking | Security | Deps Audit | Dependabot |
| -------- | ---------- | ------- | ------------- | -------- | ---------- | ---------- |
| **Common** | — | — | — | gitleaks | — | github-actions |
| **Markdown** | prettier | markdownlint-cli2 | — | — | — | — |
| **Shell** | shfmt | shellcheck | — | — | — | — |
| **Docker** | — | hadolint | — | trivy | — | docker |
| **Terraform** | terraform fmt | tflint, terraform validate | — | tfsec, checkov | — | terraform |
| **Go** | gofmt / goimports | golangci-lint | — | — | govulncheck | gomod |
| **Python** | ruff | ruff | mypy / pyright | bandit | — | pip |
| **.NET / C#** | dotnet format | Roslyn analysers | — | SecurityCodeScan | dotnet outdated | nuget |
| **Rust** | rustfmt | clippy | — | — | cargo-audit, cargo-deny | cargo |
| **Java** | google-java-format / spotless | checkstyle, SpotBugs, PMD | — | — | OWASP dependency-check | maven |
| **Ruby** | rubocop | rubocop | — | brakeman | bundler-audit | bundler |
| **PHP** | PHP-CS-Fixer / PHP_CodeSniffer | PHPStan / Psalm | — | — | composer audit | composer |
| **Node.js** | prettier | eslint | — | — | npm audit | npm |
| **TypeScript** | prettier | eslint + typescript-eslint | tsc --noEmit | — | npm audit | npm |

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
5. Dependabot ecosystem configuration

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

## MCP Servers

[Model Context Protocol](https://modelcontextprotocol.io/) servers extend Claude Code with external data sources and tools. These are configured per-user via `claude mcp add` and stored in `~/.claude.json`.

MCP servers are set up automatically by `run_onchange_setup-claude.sh` during `chezmoi apply`. Servers that require API keys read them from `~/.secrets` (see [Secrets Management](#secrets-management) below).

### Configured Servers

| Server | Transport | API Key Required | Purpose |
| ------ | --------- | :-: | ------- |
| **google-dev-knowledge** | HTTP | Yes | Google developer documentation (Android, Chrome, Cloud, Firebase, Flutter, etc.) via the [Google Developer Knowledge MCP](https://developerknowledge.googleapis.com/mcp) |

### Graceful Degradation

The setup script skips automatically when:

- The `claude` CLI is not installed
- A required API key is not present in `~/.secrets`

This means `chezmoi apply` works on any machine — MCP servers are only configured where both the CLI and credentials are available.

## Secrets Management

Secrets (API keys, tokens) are stored in `~/.secrets` as shell-sourceable `KEY="value"` pairs. This file is **not committed to the repo** — it is either placed manually or managed via chezmoi age encryption.

### Setting Up age Encryption

age encryption lets `~/.secrets` travel with the repo (encrypted) so that `chezmoi apply` on a new machine provisions secrets automatically — provided the age private key is available.

**1. Generate an age key pair (one-time):**

```sh
age-keygen -o ~/.config/chezmoi/key.txt
```

Note the public key (`age1...`) printed to stdout.

**2. Add age config to `.chezmoi.toml`:**

```toml
[age]
    identity = "~/.config/chezmoi/key.txt"
    recipient = "age1your-public-key-here"
```

**3. Create `~/.secrets` with real values:**

```sh
# Get the API key from Terraform
API_KEY=$(terraform -chdir=layers/3-projects/services output -raw developer_knowledge_api_key)

cat > ~/.secrets << EOF
# ~/.secrets — sourced by chezmoi run scripts
GOOGLE_DEV_KNOWLEDGE_API_KEY="${API_KEY}"
EOF
```

**4. Encrypt and add to chezmoi:**

```sh
chezmoi add --encrypt ~/.secrets
```

This creates an encrypted source file (replacing `dot_secrets.tmpl`). Commit it to the repo.

**5. Update `.chezmoiignore`:**

Change the unconditional `.secrets` ignore to be conditional so that machines with the age key receive the decrypted file:

```text
{{ if not (stat (joinPath .chezmoi.homeDir ".config/chezmoi/key.txt")) }}
.secrets
{{ end }}
```

**6. Provisioning a new machine:**

Before running `chezmoi init --apply`, copy the age private key from Bitwarden (or another secure store) to `~/.config/chezmoi/key.txt`. chezmoi will then decrypt `~/.secrets` and the setup script will configure MCP servers automatically.

On machines without the age key, `~/.secrets` is skipped and the setup script degrades gracefully.

## Customisation

- **Project overrides**: Add `.claude/settings.json` in any repo to extend/override user-level hooks
- **Subdirectory context**: Add `CLAUDE.md` files in subdirectories for monorepo language-specific context
- **New languages**: Copy an existing setup command and adapt the tool list
