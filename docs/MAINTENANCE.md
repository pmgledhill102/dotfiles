# Maintenance Guide

## What's Automated

These run without intervention:

| What | Workflow | Frequency |
| ---- | -------- | --------- |
| Linting (ShellCheck, markdownlint, actionlint) | `ci.yml` | Every PR |
| Cross-platform install smoke tests | `ci.yml` | Every PR |
| Homebrew outdated check | `package-updates.yml` | Weekly (Mon 09:00 UTC) |
| Starship version check | `package-updates.yml` | Weekly |
| Chezmoi version check | `package-updates.yml` | Weekly |
| Oh My Zsh plugin update check | `package-updates.yml` | Weekly |
| Ghostty terminfo regeneration | `ghostty-terminfo.yml` | Weekly (Sun 00:00 UTC) |
| GitHub Actions dependency PRs | Dependabot | Weekly |
| Markdown lint | pre-commit hook | Every commit |

When updates are detected, GitHub issues are created automatically. Review and
act on them as they appear.

## Manual Tasks

### Updating Dependencies

Most tools install via package managers that pull the latest version. To update
on your local machine:

```bash
# macOS — update everything
brew update && brew upgrade

# Oh My Zsh core
omz update

# Oh My Zsh custom plugins
cd ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions && git pull
cd ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting && git pull

# Linux — Starship (not in apt)
curl -sS https://starship.rs/install.sh | sh
```

### Shell Startup Time

Target: under 1 second. Check periodically:

```bash
time zsh -i -c exit
```

If slow, profile with:

```bash
# Add to top of ~/.zshrc temporarily
zmodload zsh/zprof
# Add to bottom
zprof
```

Common culprits: too many plugins, network-dependent commands, slow completions.

### Security

- **Rotate age keys** annually: `age-keygen -o ~/.config/chezmoi/key-new.txt`,
  re-encrypt secrets, verify, delete old key
- **Audit secrets**: ensure nothing plaintext leaked into git history
- **Backup age key** to Bitwarden (not just on disk)

See [BACKUP_RECOVERY.md](BACKUP_RECOVERY.md) for backup and recovery procedures.

### Troubleshooting

**Oh My Zsh update fails:**

```bash
cd ~/.oh-my-zsh && git reset --hard origin/master && git pull
```

**Custom plugin update fails:**

```bash
cd ~/.oh-my-zsh/custom/plugins
rm -rf plugin-name
git clone https://github.com/zsh-users/plugin-name
```

**Package installation fails:**

```bash
# macOS
brew update && brew install <package>

# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y <package>
```
