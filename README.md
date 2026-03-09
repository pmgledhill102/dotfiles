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
dotup                 # Update dotfiles, brew, OMZ, plugins, and starship
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

## Migrating from Old Setup (Stow)

See [docs/MIGRATION.md](docs/MIGRATION.md) for the full cleanup guide
covering stow symlink removal, Oh My Posh → Starship transition, and
per-platform notes.

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
