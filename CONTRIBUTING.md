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

- **PRs**: lint only — ShellCheck, markdownlint-cli2, actionlint, private-repo
  reference check (~2 min)
- **Push to main**: lint + full install test matrix (Ubuntu, macOS, Windows)
- **Weekly / manual dispatch**: full install tests to catch upstream breakage

Pre-commit hooks run markdownlint-cli2 locally.

## This repository is public

It has to be: the bootstrap is a single `curl` on a fresh machine, before any
credential exists to authenticate with. So everything here is world-readable and
indexed **permanently** — git history included, meaning a later deletion does
not unpublish anything. Issue and PR bodies on this repo are public too.

**No direct references to private repositories.** Not their names or URLs, not
their issue numbers (especially paired with what they were about), not their
workflow or branch names, not their architecture or release process.

Tooling here may still *operate on* private repos — make the repo an input read
from untracked machine config (`~/.config/<tool>.conf`), never a committed
default. The `ci-vm-*` scripts work this way.

`scripts/check-no-private-repos.sh` enforces this in CI and pre-commit against
the allowlist in `scripts/public-repos.txt`. If it flags a repo that really is
public, add its bare name to that file. Full reasoning in
[ADR-0014](docs/adrs/0014-public-repo-no-private-references.md).

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
