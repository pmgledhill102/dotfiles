# Dotfiles

Personal dotfiles managed by [chezmoi](https://www.chezmoi.io/). Provides a
consistent dev environment across macOS, Linux, WSL, and Windows.

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

## What's Included

### Shell

- **Unix**: Zsh + Oh My Zsh (autosuggestions, syntax-highlighting, history, etc.)
- **Windows**: PowerShell Core with enhanced profile
- **Prompt**: Starship (all platforms)
- **Terminal**: Ghostty (macOS), Windows Terminal (Windows)
- **Multiplexer**: tmux (Unix)

### Dev Tools

- **Packages**: Brewfile (macOS), apt list (Linux), winget JSON (Windows)
- **Git**: git-delta diffs, lazygit TUI, global gitignore
- **Editor**: VS Code with synced settings and keybindings
- **Fonts**: JetBrains Mono Nerd Font

### Security

- **Secrets**: age encryption for sensitive configs
- **Platform tweaks**: macOS developer defaults, Windows Long Paths + Developer Mode

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

### Daily Commands

```bash
chezmoi diff          # Preview pending changes
chezmoi apply -v      # Apply changes
chezmoi edit ~/.zshrc # Edit a managed file
chezmoi add ~/.foo    # Start managing a new file
```

### Updating

```bash
dotup                 # Pull latest + apply (alias for chezmoi update -v)
dotstatus             # Show machine type, source path, pending changes
```

### Package Management

```bash
# macOS — packages auto-install when Brewfile changes
brew bundle

# Linux — packages auto-install when list changes
chezmoi edit ~/.config/ubuntu_pkglist
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

## Migrating from Other Systems

If you're switching from another dotfile manager:

```bash
# 1. Backup current dotfiles
mkdir -p ~/dotfiles-backup && cp ~/.zshrc ~/.gitconfig ~/dotfiles-backup/

# 2. Install this setup
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)"

# 3. Merge your customizations
chezmoi edit ~/.zshrc   # paste your aliases, functions, etc.
chezmoi apply -v
```

**From GNU Stow**: `stow -D */` to unlink, then install above.
**From yadm**: `yadm list` to inventory, then install above and
`chezmoi add` your custom files.
**From git bare repo**: list tracked files with
`git --git-dir=$HOME/.cfg/ --work-tree=$HOME ls-tree -r --name-only HEAD`,
then install above.

## Platform Support

- macOS (Sonoma and later)
- Ubuntu 22.04+ / Debian 11+
- WSL (Windows Subsystem for Linux)
- Windows 10/11 (PowerShell path)

## Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md) — development workflow and code style
- [docs/TESTING.md](docs/TESTING.md) — CI pipeline and validation scripts
- [docs/MAINTENANCE.md](docs/MAINTENANCE.md) — dependency updates and health checks
- [docs/BACKUP_RECOVERY.md](docs/BACKUP_RECOVERY.md) — age key backup and disaster recovery
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — common issues and fixes

## License

Personal configuration. Feel free to fork and adapt for your own use.
