# Contributing

## Prerequisites

- Git
- [chezmoi](https://www.chezmoi.io/install/) (`brew install chezmoi` on macOS)
- Familiarity with Zsh and shell scripting

## Repository Structure

```text
home/                    # Files managed by chezmoi (maps to $HOME)
scripts/                 # CI validation scripts
specs/REQUIREMENTS.md    # Consolidated requirements and key decisions
docs/                    # Testing and troubleshooting guides
.chezmoi.toml.tmpl       # Config template (machine type, package lists)
install.sh               # Remote one-liner installer
```

Chezmoi naming conventions: `dot_` = `.` prefix, `.tmpl` = Go template,
`run_once_` / `run_onchange_` = lifecycle scripts.

## Making Changes

```bash
chezmoi edit ~/.zshrc     # Edit a managed file
chezmoi diff              # Preview pending changes
chezmoi apply -v          # Apply to home directory
source ~/.zshrc           # Reload in current shell
```

### Adding New Files

```bash
chezmoi add ~/.config/foo   # Start managing a file
```

### Platform-Specific Config

Use chezmoi templates:

```gotmpl
{{ if eq .chezmoi.os "darwin" }}
# macOS only
{{ else if eq .chezmoi.os "linux" }}
# Linux only
{{ end }}
```

## Commit Style

Conventional commits: `<type>(<scope>): <description>`

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`

```text
feat(zsh): add git aliases for common workflows
fix(install): correct Ubuntu package installation
```

## CI

CI is defined in `.github/workflows/ci.yml`:

- **PRs**: lint only — ShellCheck, markdownlint-cli2, actionlint (~2 min)
- **Push to main**: lint + full install test matrix (Ubuntu, macOS, Windows)
- **Weekly / manual dispatch**: full install tests to catch upstream breakage

Pre-commit hooks run markdownlint-cli2 locally.

## Secrets

This repo uses `age` encryption. Never commit plaintext secrets. Highly
sensitive credentials (API keys, passwords) belong in Bitwarden, not here.

```bash
chezmoi edit --encrypted ~/.config/secret-file
```

## Links

- [README.md](README.md) — overview and quick start
- [docs/TESTING.md](docs/TESTING.md) — CI pipeline details
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — common issues
- [specs/REQUIREMENTS.md](specs/REQUIREMENTS.md) — project requirements
