# Dotfiles

Personal dotfiles managed by [chezmoi](https://www.chezmoi.io/). Provides a
consistent dev environment across macOS, Linux, WSL, and Windows.

## What You Get

One curl command on a fresh machine and you walk away with a tuned shell, a
modern CLI toolkit, your editors and Git already configured, secrets
decrypted, and a Claude Code setup that knows how to scaffold any new
language project — all kept in sync across every machine you own with two
short commands.

### One install, three platforms

Works on **macOS, Ubuntu/Debian Linux, WSL, and Windows** from the same
source of truth. Pick a tier at install time (`personal` / `work` /
`minimal`) so a work laptop doesn't get Steam and a minimal VM doesn't get
the full kitchen sink.

### A polished terminal

Zsh + Oh My Zsh with quality-of-life add-ons:

- **`zsh-autosuggestions`** — fish-style as-you-type history suggestions
- **`zsh-syntax-highlighting`** — commands turn green/red before you press
  Enter
- **`colored-man-pages`**, **`command-not-found`**, **`extract`** (one
  command for any archive), **`copypath`**, **`copyfile`**
- **Starship prompt** with transient-prompt collapse so scrollback stays
  clean
- **fzf** wired for `Ctrl-R` history search and fuzzy file pickers
- **zoxide** so `z proj` jumps to your most-used folder without typing the
  path
- Bitwarden SSH agent auto-wired, telemetry opted out, `~/.zshrc.local`
  escape hatch for per-machine tweaks

### A modern CLI toolkit installed for you

- **Better core tools** — `bat`, `fd`, `ripgrep`, `git-delta`, `jq`/`yq`,
  `fzf`, `zoxide`
- **Git + dev** — `gh`, `lazygit`, `pre-commit`, `gitleaks`
- **Languages** — Go, .NET, OpenJDK + `jenv`, `nvm`, `uv` (Python), Rust
- **Cloud / infra** — `gcloud`, `awscli`, `azure-cli`, `tenv` + `tflint`,
  `checkov`, `trivy`, `semgrep`, `podman`
- **Personal-tier GUI apps** — VS Code, Ghostty, Bitwarden, Rectangle,
  Chrome, JetBrains Mono Nerd Font, Claude Desktop, and more

### Short, memorable maintenance commands

You don't need to remember chezmoi or brew incantations:

- **`dotup`** — pull latest dotfiles, update Oh My Zsh + plugins, refresh
  nano syntax, update Starship (Linux) and Rust toolchain, then reload
  aliases/functions in the current shell
- **`dotbrew`** — `brew update` + install everything in your Brewfile +
  `brew upgrade`, in one step
- **`dotclaude`** — interactive Claude Code MCP server setup (GitHub MCP
  wired to your `gh` auth token, Google Developer Knowledge keyed from
  Bitwarden)
- **`dotstatus`** — machine type, source path, last applied, and any
  pending changes
- **`dotfuncs`** — list every custom function with its one-line description
  so you can rediscover what's available after `dotup`

### Quick-capture project notes

- **`note "anything"`** (alias **`n`**) — append a timestamped bullet to
  `~/notes/<project>.md`, where project is the git repo basename (or cwd
  basename outside a repo). No args → print the current project's notes.
- **`note -e`** — open the current project's notes file in `$EDITOR`
- **`notes`** — list all note files across projects
- **`notes grep <pattern>`** (or just `notes <pattern>`) —
  case-insensitive search across every project's notes

### A centralised Claude Code setup that follows you everywhere

Every machine gets the same `~/.claude/` config:

- Curated permission allowlist so common dev/build/lint/GitHub commands
  don't prompt every time, but destructive things still do
- Slash commands to bootstrap any project — `/setup-python`, `/setup-go`,
  `/setup-rust`, `/setup-node`, `/setup-typescript`, `/setup-java`,
  `/setup-ruby`, `/setup-php`, `/setup-dotnet`, `/setup-shell`,
  `/setup-markdown`, `/setup-docker`, `/setup-terraform` — each wires
  formatter + linter + type checks + pre-commit hooks consistently
- Repo helpers — `/setup-repo` (branch protection, Dependabot auto-merge),
  `/setup-common` (pre-commit + gitleaks)
- Session helpers — `/end-session`, `/retrospective`
- Auto-fix hooks — Terraform formatted on save, pre-commit enforced before
  `git push`

### Secrets handled safely

`age`-based encryption — secrets live in the repo encrypted, decrypt on
first run with your key. No plaintext credentials in version control.

### Confidence it works

CI runs lint + full install tests on macOS, Ubuntu, and Windows on every
push to `main`, so a broken bootstrap is caught before it hits your laptop.
`validate-installation.sh` (and `.ps1` for Windows) sanity-checks a fresh
install.

## Quick Start

### macOS / Linux / WSL

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)"
```

### Windows (PowerShell as Administrator)

```powershell
winget install --id twpayne.chezmoi

chezmoi init --apply pmgledhill102
```

This installs chezmoi, packages (Homebrew/apt/winget), shell config (Zsh +
Oh My Zsh or PowerShell), Starship prompt, git-delta, lazygit, tmux, VS Code
settings, JetBrains Mono Nerd Font, and platform-specific defaults.

## Per-Platform Reference

| | macOS | Linux / WSL | Windows |
| --- | --- | --- | --- |
| Shell | Zsh + Oh My Zsh | Zsh + Oh My Zsh | PowerShell Core |
| Terminal | Ghostty | (host terminal) | Windows Terminal |
| Package source | `Brewfile` | `apt` package list | `winget` JSON |
| Platform tweaks | Developer defaults | — | Long Paths + Developer Mode |

## Machine Types

During `chezmoi init` you choose a machine type that controls which packages
are installed:

| Type | Brew formulas | Brew casks | Description |
| --- | --- | --- | --- |
| `personal` | Full (cloud CLIs, runtimes, build tools) | All GUI apps | Full dev workstation |
| `work` | Core CLI + key runtimes | Font, Ghostty, Rectangle | Work essentials |
| `minimal` | Core CLI only | None | Headless / CI server |

To change later, edit `machine_type` in `~/.config/chezmoi/chezmoi.toml` and
run `chezmoi apply`.

## Usage

### Daily helpers

```bash
dotup                 # Pull latest dotfiles + update OMZ, plugins, Starship, Rust
dotbrew               # brew update + install Brewfile + brew upgrade
dotclaude             # Interactive Claude Code MCP server setup
dotstatus             # Machine type, source path, last applied, pending changes
dotfuncs              # List all custom shell functions with descriptions
```

### Quick-capture notes

```bash
note "fixed the auth bug"   # Append a timestamped bullet to ~/notes/<project>.md
n "another shorthand"        # 'n' is an alias for 'note'
note                          # Print the current project's notes
note -e                       # Open the current project's notes in $EDITOR
notes                         # List all note files
notes grep <pattern>          # Search across every project's notes
notes <pattern>               # Shorthand for 'notes grep'
```

### Direct chezmoi commands

```bash
chezmoi diff          # Preview pending changes
chezmoi apply -v      # Apply changes
chezmoi edit ~/.zshrc # Edit a managed file
chezmoi add ~/.foo    # Start managing a new file
```

### Package management

```bash
# macOS — packages auto-install when Brewfile changes
brew bundle

# Linux — apt packages live under [data.packages.apt] in
# home/.chezmoi.toml.tmpl; the rendered ~/.config/ubuntu_pkglist
# regenerates from it, and changes auto-install on the next apply.
chezmoi init --apply
```

## Secret Management

This repo uses `age` to encrypt sensitive files. chezmoi decrypts them
automatically on apply.

### Setup

```bash
age-keygen -o ~/.config/chezmoi/key.txt
```

Store this key in Bitwarden. Place it at `~/.config/chezmoi/key.txt` on each
machine.

### Adding Secrets

```bash
chezmoi edit --encrypted ~/.config/secret-file
chezmoi apply
```

Highly sensitive secrets (API keys, passwords) belong in Bitwarden, not here.

## Platform Support

- macOS (Sonoma and later)
- Ubuntu 22.04+ / Debian 11+
- WSL (Windows Subsystem for Linux)
- Windows 10/11 (PowerShell path)

## Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md) — development workflow and code style
- [docs/TESTING.md](docs/TESTING.md) — CI pipeline and validation scripts
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — common issues and fixes

## License

Personal configuration. Feel free to fork and adapt for your own use.
