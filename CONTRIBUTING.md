# Contributing to Dotfiles

Thank you for your interest in maintaining and improving these dotfiles! This guide will help you understand how to make changes, test them, and keep the repository in good shape.

## Overview

This dotfiles repository is managed by [chezmoi](https://www.chezmoi.io/), a tool that helps manage configuration files across multiple machines. The repository is designed to work on macOS, Debian/Ubuntu, and WSL.

## Prerequisites

Before making changes, ensure you have:

- Git installed
- chezmoi installed (`brew install chezmoi` on macOS, or see [installation guide](https://www.chezmoi.io/install/))
- Familiarity with Zsh and shell scripting
- (Optional) VMware Fusion or UTM for testing on virtual machines

## Repository Structure

```text
.
├── home/                          # Files managed by chezmoi
│   ├── dot_zshrc                 # Zsh configuration
│   ├── dot_config/               # XDG config directory
│   └── ...
├── run_once_install-packages.sh.tmpl  # Package installation script
├── install.sh                    # Remote installation script
├── specs/REQUIREMENTS.md         # Consolidated requirements and key decisions
├── docs/                         # Additional documentation
└── README.md                     # Main documentation
```

## Making Changes

### 1. Local Development

When working on dotfiles locally:

```bash
# Edit files in the chezmoi source directory
chezmoi edit ~/.zshrc

# See what changes would be applied
chezmoi diff

# Apply changes to your home directory
chezmoi apply -v

# Test the changes in your current shell
source ~/.zshrc
```

### 2. Adding New Configuration Files

To add a new dotfile to the repository:

```bash
# Add a file to chezmoi
chezmoi add ~/.gitconfig

# Or edit it directly in the source directory
chezmoi edit ~/.gitconfig
```

### 3. Modifying the Installation Script

The `run_once_install-packages.sh.tmpl` script is a chezmoi template that:

- Detects the operating system
- Installs required packages
- Sets up tools like Oh My Zsh and Starship

When modifying this script:

1. Ensure it remains idempotent (safe to run multiple times)
2. Test on all supported platforms
3. Add appropriate error handling
4. Document any new dependencies

### 4. Platform-Specific Configurations

Use chezmoi templates for platform-specific settings:

```gotmpl
{{ if eq .chezmoi.os "darwin" }}
# macOS-specific configuration
{{ else if eq .chezmoi.os "linux" }}
# Linux-specific configuration
{{ end }}
```

## Testing Changes

### Local Testing

Before committing changes:

1. **Test in a clean environment**: Use a virtual machine or container
2. **Run the installation script**: Test the complete installation process
3. **Verify functionality**: Ensure all tools and configurations work as expected

### Virtual Machine Testing

See [docs/VMWARE_TESTING_GUIDE.md](docs/VMWARE_TESTING_GUIDE.md) for detailed instructions on testing with VMware Fusion or UTM.

Quick test procedure:

1. Create a fresh VM (macOS or Ubuntu)
2. Run the installation command
3. Verify the shell prompt, tools, and configurations
4. Test Oh My Zsh plugins and Starship prompt

### Automated Testing

Future: CI/CD pipelines will automatically test changes on:

- macOS (via GitHub Actions)
- Ubuntu (via GitHub Actions)

## Code Style

### Shell Scripts

- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `shellcheck` for linting: `shellcheck script.sh`
- Use `set -e` for error handling in critical scripts
- Add comments for complex logic

### Zsh Configuration

- Keep `.zshrc` organized and well-commented
- Group related settings together
- Document any non-obvious configurations
- Test compatibility across Zsh versions

## Commit Guidelines

### Commit Messages

Follow conventional commit format:

```text
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types:

- `feat`: New feature or configuration
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code restructuring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:

```text
feat(zsh): add git aliases for common workflows
fix(install): correct Ubuntu package installation
docs(readme): update installation instructions
```

## Adding New Tools

When adding a new tool to the dotfiles:

1. **Update the installation script**: Add the tool to `run_once_install-packages.sh.tmpl`
2. **Add configuration**: Create the config file in the appropriate location
3. **Document**: Update README.md with information about the tool
4. **Test**: Verify installation on all platforms
5. **Update specs**: Update `specs/REQUIREMENTS.md` if requirements change

Example for adding a new tool:

```bash
# In run_once_install-packages.sh.tmpl
install_newtool() {
    echo "Installing newtool..."
    if command -v newtool &> /dev/null; then
        echo "newtool is already installed"
        return 0
    fi
    
    case $OS in
        "Darwin")
            brew install newtool
            ;;
        "Linux")
            # Ubuntu/Debian
            apt-get install -y newtool
            ;;
    esac
}
```

## Secret Management

### Working with Secrets

This repository uses `age` encryption for secrets:

1. **Never commit plaintext secrets**
2. **Use age encryption**: `chezmoi encrypt <file>`
3. **Document secret requirements**: Update README.md if new secrets are needed
4. **Highly sensitive secrets**: Keep in Bitwarden, not in the repository

### Adding a New Secret

```bash
# Create or edit the secret file
chezmoi edit ~/.config/secret-file

# Encrypt it (chezmoi does this automatically for .age files)
# The file will be stored as home/dot_config/secret-file.age
```

## Maintenance Tasks

### Regular Maintenance

Perform these tasks regularly:

1. **Update dependencies**: Keep Oh My Zsh, Starship, and other tools updated
2. **Review plugins**: Check if Oh My Zsh plugins need updates
3. **Test installations**: Periodically test on fresh VMs
4. **Update documentation**: Keep README and guides current

### Updating Oh My Zsh

```bash
# Update Oh My Zsh
omz update

# Update plugins
cd ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git pull
```

### Updating Starship

```bash
# macOS
brew upgrade starship

# Linux
curl -sS https://starship.rs/install.sh | sh
```

## Troubleshooting

### Common Issues

**Issue**: Installation script fails on a specific OS

- **Solution**: Check OS detection logic and platform-specific commands

**Issue**: Shell prompt doesn't appear correctly

- **Solution**: Verify Starship installation and configuration

**Issue**: Oh My Zsh plugins not working

- **Solution**: Ensure plugins are properly sourced in `.zshrc`

**Issue**: Secret decryption fails

- **Solution**: Verify age key is present at `~/.config/chezmoi/key.txt`

## Getting Help

- Review the [README.md](README.md) for general information
- Check [docs/](docs/) for detailed guides
- Review [specs/REQUIREMENTS.md](specs/REQUIREMENTS.md) for project requirements
- Open an issue for bugs or questions

## Philosophy

These dotfiles follow these principles:

1. **Idempotence**: Scripts should be safe to run multiple times
2. **Portability**: Work consistently across macOS, Linux, and WSL
3. **Security**: Never expose secrets in version control
4. **Modularity**: Keep configurations organized and maintainable
5. **Simplicity**: Prefer straightforward solutions over complex ones

Thank you for contributing to making these dotfiles better!
