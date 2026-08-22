# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

This is a **chezmoi-managed dotfiles repository**. It provisions a development environment across macOS, Linux (Ubuntu/Debian), WSL, and Windows.

Claude Code's user-level configuration (slash commands, hooks, settings, MCP) lives in a separate repo, [`agentic-coding-config`](https://github.com/pmgledhill102/agentic-coding-config) — mounted into `~/.claude/` via a chezmoi external on `personal` machines only (see `home/.chezmoiexternal.toml.tmpl`). When working in this repo, agentic edits go in *that* repo; this repo handles machine config (shell, brew/winget, OS bootstrap).

## Repository Architecture

This repo uses **chezmoi** with `.chezmoiroot` set to `home/`, meaning files in `home/` map to `$HOME`. Chezmoi naming conventions:

- `dot_` prefix = `.` in target (e.g., `dot_zshrc` -> `~/.zshrc`)
- `.tmpl` suffix = Go template processed with data from `.chezmoi.toml`
- `run_once_` prefix = script runs once per machine
- `run_onchange_` prefix = script re-runs when its contents (or watched files) change

Key paths relative to repo root:

- `.chezmoi.toml` — config data (user info, package lists per platform)
- `home/` — all managed dotfiles and scripts
- `home/.chezmoiexternal.toml.tmpl` — declares the agentic-coding-config repo as an `archive` external mounted at `.claude/`, gated to `personal` machines (#389)
- `home/run_once_remove-claude-config-nonpersonal.sh.tmpl` — removes that payload from work/minimal machines that applied a pre-gate version; chezmoi never deletes a target whose source went away
- `home/.chezmoiignore` — target-side exclusions, gated by OS and by machine type. `.claude/` filtering is *not* done here — it moved to the archive external's `include` pattern (see the comment at the top of the file)
- `home/Brewfile.tmpl` — installs `claude` and `claude-code@latest` casks (the binaries; their config lives in agentic-coding-config)
- `home/run_onchange_setup-claude.sh` — configures MCP servers per machine; reads keys from `~/.secrets`. Stays here because it's machine-bootstrap, not content
- `scripts/` — validation scripts for CI
- `specs/REQUIREMENTS.md` — consolidated project requirements and key decisions
- `docs/` — documentation (testing, troubleshooting)

### Adding a shell script under `home/`

A new `run_*.sh` or `run_*.sh.tmpl` must **also** be listed in
`home/.chezmoiignore` inside the `{{- if eq .chezmoi.os "windows" }}` block,
under **both** its source spelling and its target spelling:

```text
run_once_my-script.sh
my-script.sh
```

Windows has no `/bin/sh`, so a script that is not ignored there makes chezmoi
try to execute it, and the whole apply exits 1 with:

```text
fork/exec ...: %1 is not a valid Win32 application
```

Every existing `.sh` in `home/` already carries both spellings. Nothing
prompts for this — it is discoverable only by noticing the pattern — so it is
usually CI that catches a miss.

### Testing template changes

Two traps make a local test appear to pass while proving nothing. Both are
written up in [docs/TESTING.md](docs/TESTING.md#testing-chezmoi-template-changes):
`chezmoi apply --dry-run` exercises the *installed* source copy rather than
your working tree, and `--promptString machine_type=work` does not populate
`.machine_type`.

## CI/CD and Linting

CI runs on push/PR to `main` via `.github/workflows/ci.yml`:

- **ShellCheck** on `scripts/` and `home/`
- **markdownlint-cli2** on all `*.md` files (config: `.markdownlint.yaml`)
- **actionlint** on GitHub Actions workflows
- **Test Install** matrix: Ubuntu, macOS, Windows — runs `chezmoi init --apply` then validation scripts

Pre-commit hooks (`.pre-commit-config.yaml`) run markdownlint-cli2.

## Commit Style

Conventional commits: `<type>(<scope>): <description>`
Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`

## This repository is public

`dotfiles` is public, and has to be: the bootstrap is a single `curl` on a fresh
machine, before any credential exists to authenticate with. Anything committed
here is world-readable and indexed **permanently** — git history included, so
deleting a line later does not unpublish it. The same applies to issues and pull
requests on this repo.

**Therefore: no direct references to private repositories.** Do not commit, and
do not write in an issue or PR here:

- the name or URL of a private repo;
- its issue or PR numbers — especially paired with what they were about;
- its workflow, job, or branch names;
- its architecture, security arrangements, or release process;
- anything identifying what a private project *is* or *does*.

Tooling here may perfectly well **operate on** private repos — the CI runner VM
scripts do. Make the repo an *input*, never a constant: read it from untracked
machine config such as `~/.config/<tool>.conf`, with no default committed here.

If a document genuinely needs private specifics, it belongs in the private
personal-context repo, not this one.

`scripts/check-no-private-repos.sh` enforces this in CI and pre-commit, against
the allowlist in `scripts/public-repos.txt`. Reasoning: ADR-0014.

## Related repos

- [`agentic-coding-config`](https://github.com/pmgledhill102/agentic-coding-config) — Claude Code commands/hooks/settings/MCP. Mounted at `~/.claude/` from this repo, on `personal` machines only.
- A separate **private** repo holds personal context: principles, decisions, repo
  registry, direction. Not named here, per the section above.
