# My Dotfiles

This repository contains my personal dotfiles, managed by `chezmoi`. It provides a consistent Zsh shell experience with Oh My Zsh, Starship prompt, and Ghostty terminal across macOS, Ubuntu/Debian, and WSL.

## Quick Start

### Installation

To install these dotfiles on a new machine, run the following command. You can optionally pass a branch name as an argument to install a specific version of the dotfiles.

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)" -- [branch-name]
```

This will:

- Install chezmoi
- Install required packages (Zsh, Oh My Zsh, Starship, age, etc.)
- Install development tools via Brewfile (macOS) or package lists (Linux)
- Apply your dotfile configurations
- Set up Zsh as your default shell
- Configure tmux, git-delta, lazygit, and VS Code
- Install JetBrains Mono Nerd Font (macOS only)
- Apply macOS system defaults (macOS only)

### What's Included

#### Core Shell Environment

- **Shell**: Zsh with Oh My Zsh
- **Prompt**: Starship (fast, customizable prompt)
- **Terminal**: Ghostty (macOS/Windows)
- **Terminal Multiplexer**: Tmux with optimized configuration
- **Plugins**:
  - zsh-autosuggestions
  - zsh-syntax-highlighting
  - colored-man-pages
  - command-not-found
  - history
  - copypath
  - copyfile

#### Development Tools

- **Package Management**:
  - macOS: Brewfile for automated Homebrew package management
  - Linux: Ubuntu package list for apt-based installations
- **Git Enhancements**:
  - git-delta for improved diff viewing
  - lazygit for TUI-based Git operations
  - Global gitignore for system-wide exclusions
- **Editor**: VS Code with synchronized settings and keybindings
- **Fonts**: JetBrains Mono Nerd Font (macOS only, via Brewfile)

#### Security & Configuration

- **Secret Management**: age encryption for sensitive configs
- **macOS Defaults**: Developer-optimized system settings (macOS only)

## Documentation

Comprehensive guides are available:

- **[CONTRIBUTING.md](../CONTRIBUTING.md)** - Guidelines for maintaining and extending these dotfiles
- **[docs/MAINTENANCE.md](../docs/MAINTENANCE.md)** - Regular maintenance tasks and dependency updates
- **[docs/BACKUP_RECOVERY.md](../docs/BACKUP_RECOVERY.md)** - Backup strategies and disaster recovery procedures
- **[docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[docs/MIGRATION.md](../docs/MIGRATION.md)** - Guide for migrating from other dotfile systems
- **[docs/VMWARE_TESTING_GUIDE.md](../docs/VMWARE_TESTING_GUIDE.md)** - Testing with virtual machines

## Secret Management

This repository uses `age` to encrypt sensitive files. `chezmoi` will
automatically decrypt these files when you run `chezmoi apply`, and will prompt
you for your passphrase.

### Initial Setup

On your first installation, you'll need to generate an `age` key:

```sh
age-keygen -o ~/.config/chezmoi/key.txt
```

**Important**: Store this key securely in Bitwarden! You'll need it on each machine
where you want to use these dotfiles. The key file should be placed at
`~/.config/chezmoi/key.txt` on each machine.

### Adding Secrets

To add a new secret or edit an existing one:

1. **Add the file**: Create or edit the plaintext file in your local source
   directory (e.g., `~/.local/share/chezmoi/home/.my-secret`).
2. **Encrypt the file**: Run `chezmoi encrypt ~/.local/share/chezmoi/home/.my-secret`.
   This will create an encrypted file `.../.my-secret.age`.
3. **Commit**: Commit the `.age` file to your repository. `chezmoi` will
   automatically ignore the plaintext version.

### Highly Sensitive Secrets

For highly sensitive secrets (API keys, passwords, tokens), these should be managed
manually using Bitwarden and are NOT stored in this repository.

## Usage

### Daily Commands

```bash
# See what changes chezmoi would apply
chezmoi diff

# Apply changes
chezmoi apply -v

# Edit a config file
chezmoi edit ~/.zshrc

# Add a new file to dotfiles
chezmoi add ~/.gitconfig

# Update Oh My Zsh
omz update

# Update Starship
brew upgrade starship  # macOS

# Start tmux session
tmux

# Use lazygit for interactive Git operations
lazygit

# View git diff with delta
git diff  # delta is automatically used via gitconfig
```

### Package Management

#### macOS - Brewfile

The `Brewfile` in your home directory lists all Homebrew packages. To install or update packages:

```bash
# Install/update all packages from Brewfile
brew bundle

# Add a new package to Brewfile
echo 'brew "package-name"' >> ~/Brewfile
chezmoi add ~/Brewfile
```

The `run_onchange_install-brewfile.sh.tmpl` script automatically runs `brew bundle` when the Brewfile changes.

#### Linux - Package Lists

The Ubuntu package list is located at `~/.config/ubuntu_pkglist`. To add packages:

```bash
# Edit the package list
chezmoi edit ~/.config/ubuntu_pkglist

# Packages are automatically installed when the list changes
```

### Updating

To update the dotfiles on an existing machine:

```bash
# Pull latest changes
cd ~/.local/share/chezmoi
git pull

# Apply updates
chezmoi apply -v
```

## Troubleshooting

Having issues? Check the [Troubleshooting Guide](../docs/TROUBLESHOOTING.md) for common problems and solutions.

Quick checks:

```bash
# Verify tools are installed
command -v zsh starship chezmoi age

# Check chezmoi status
chezmoi doctor

# Verify shell configuration
zsh -n ~/.zshrc
```

## Maintenance

Regular maintenance tasks:

- **Monthly**: Update Oh My Zsh plugins, check for Starship updates
- **Quarterly**: Full installation test, dependency updates
- **As Needed**: Add new tools, update configurations

See [MAINTENANCE.md](../docs/MAINTENANCE.md) for detailed procedures.

## Contributing

Want to improve these dotfiles? See [CONTRIBUTING.md](../CONTRIBUTING.md) for:

- Development workflow
- Testing procedures
- Code style guidelines
- How to add new tools

## Platform Support

Tested and supported on:

- ✅ macOS (Sonoma and later)
- ✅ Ubuntu 22.04 LTS and later
- ✅ Debian 11 and later
- ✅ WSL (Windows Subsystem for Linux)

## License

This is personal configuration. Feel free to fork and adapt for your own use!

## Getting Help

- Review the [documentation](#documentation)
- Check the [troubleshooting guide](../docs/TROUBLESHOOTING.md)
- Open an issue with details about your problem
