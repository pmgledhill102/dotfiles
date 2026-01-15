# Maintenance Guide

This guide covers regular maintenance tasks for keeping your dotfiles repository healthy and up-to-date.

## Table of Contents

- [Regular Maintenance Schedule](#regular-maintenance-schedule)
- [Updating Dependencies](#updating-dependencies)
- [Adding New Tools](#adding-new-tools)
- [Monitoring and Health Checks](#monitoring-and-health-checks)
- [Performance Optimization](#performance-optimization)

## Regular Maintenance Schedule

### Weekly Tasks

None required for personal dotfiles usage.

### Monthly Tasks

- [ ] Review and update Oh My Zsh plugins
- [ ] Check for Starship updates
- [ ] Review shell startup time
- [ ] Test installation on one platform

### Quarterly Tasks

- [ ] Full installation test on all platforms (macOS, Ubuntu, WSL)
- [ ] Review and update all dependencies
- [ ] Audit secrets and encryption keys
- [ ] Review and update documentation
- [ ] Check for deprecated configurations

### Annual Tasks

- [ ] Comprehensive security audit
- [ ] Review and refactor installation scripts
- [ ] Update OS version compatibility
- [ ] Backup and verify recovery procedures

## Updating Dependencies

### Oh My Zsh

Oh My Zsh should be updated regularly to get the latest features and bug fixes.

```bash
# Update Oh My Zsh core
omz update

# Or manually
cd ~/.oh-my-zsh
git pull
```

### Oh My Zsh Plugins

Update custom plugins manually:

```bash
# zsh-autosuggestions
cd ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git pull

# zsh-syntax-highlighting
cd ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git pull
```

If you need to update the installation script to reflect new plugin versions:

1. Edit `run_once_install-packages.sh.tmpl`
2. Update the git clone URLs or version tags if pinning
3. Test on a clean VM
4. Commit changes

### Starship

Update Starship prompt:

**macOS:**
```bash
brew upgrade starship
```

**Linux:**
```bash
curl -sS https://starship.rs/install.sh | sh
```

**Verify version:**
```bash
starship --version
```

### Ghostty

**macOS:**
```bash
brew upgrade ghostty
```

Check [Ghostty releases](https://github.com/mitchellh/ghostty/releases) for updates.

### Age (Encryption Tool)

**macOS:**
```bash
brew upgrade age
```

**Linux:**
```bash
# Check for latest release at https://github.com/FiloSottile/age/releases
# Download and install manually or via package manager
```

### Chezmoi

**macOS:**
```bash
brew upgrade chezmoi
```

**Linux:**
```bash
# Check https://www.chezmoi.io/install/ for latest version
sh -c "$(curl -fsLS get.chezmoi.io)"
```

## Adding New Tools

### Step-by-Step Process

When adding a new tool to your dotfiles:

1. **Research the tool**
   - Verify it's available on all target platforms
   - Check installation methods
   - Review configuration requirements

2. **Update installation script**
   
   Edit `run_once_install-packages.sh.tmpl`:

   ```bash
   install_newtool() {
       echo "Installing newtool..."
       
       # Check if already installed (idempotency)
       if command -v newtool &> /dev/null; then
           echo "newtool is already installed"
           return 0
       fi
       
       case $OS in
           "Darwin")
               brew install newtool
               ;;
           "Linux")
               if [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
                   apt-get install -y newtool
               fi
               ;;
       esac
       
       # Verify installation
       if command -v newtool &> /dev/null; then
           echo "newtool installed successfully"
       else
           echo "ERROR: Failed to install newtool"
           return 1
       fi
   }
   
   # Add to main installation flow
   install_newtool
   ```

3. **Add configuration files**

   ```bash
   # Add the tool's config to chezmoi
   chezmoi add ~/.config/newtool/config.toml
   
   # Or create manually
   mkdir -p home/dot_config/newtool
   # Create configuration file
   ```

4. **Test installation**
   - Test on a clean VM for each platform
   - Verify the tool works as expected
   - Check configuration is applied correctly

5. **Update documentation**
   - Add tool description to README.md
   - Document any configuration options
   - Update CONTRIBUTING.md if needed

6. **Commit changes**
   ```bash
   git add .
   git commit -m "feat(tool): add newtool configuration"
   git push
   ```

### Example: Adding a New CLI Tool

Let's say you want to add `bat` (a cat clone with syntax highlighting):

```bash
# 1. Add installation to run_once_install-packages.sh.tmpl
install_bat() {
    echo "Installing bat..."
    if command -v bat &> /dev/null; then
        echo "bat is already installed"
        return 0
    fi
    
    case $OS in
        "Darwin")
            brew install bat
            ;;
        "Linux")
            apt-get install -y bat
            # On Ubuntu, bat is installed as batcat
            if [ ! -f "/usr/local/bin/bat" ]; then
                ln -s /usr/bin/batcat /usr/local/bin/bat
            fi
            ;;
    esac
}

# 2. Add alias in .zshrc
# cat="bat"

# 3. Test and commit
```

## Monitoring and Health Checks

### Shell Startup Time

Monitor shell startup time to ensure plugins aren't slowing things down:

```bash
# Test Zsh startup time
time zsh -i -c exit

# Detailed profiling
# Add to ~/.zshrc temporarily:
zmodload zsh/zprof
# ... (rest of config)
zprof  # At the end
```

**Target**: < 1 second startup time

### Installation Script Health

Periodically test the installation script:

```bash
# On a test machine or VM
bash <(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)

# Check for errors
echo $?  # Should be 0

# Verify installations
command -v zsh
command -v starship
command -v chezmoi
```

### Configuration Validation

Check for common issues:

```bash
# Validate Zsh configuration
zsh -n ~/.zshrc

# Check for broken symlinks
find ~ -maxdepth 3 -type l ! -exec test -e {} \; -print

# Verify Oh My Zsh plugins are loaded
omz plugin list
```

## Performance Optimization

### Reducing Shell Startup Time

If shell startup becomes slow:

1. **Profile the startup**
   ```bash
   # Add to top of ~/.zshrc
   zmodload zsh/zprof
   
   # Add to bottom
   zprof
   ```

2. **Common culprits**
   - Too many Oh My Zsh plugins
   - Slow initialization scripts
   - Network-dependent commands

3. **Optimization strategies**
   - Lazy-load plugins when possible
   - Use async loading for non-critical components
   - Cache expensive operations

### Reducing Installation Time

If installation takes too long:

1. **Parallelize installations** where possible
2. **Skip optional components** on slower machines
3. **Cache package lists** to avoid repeated updates

### Storage Optimization

Keep the repository size manageable:

```bash
# Check repository size
du -sh ~/.local/share/chezmoi

# Remove unnecessary files from history
# (Use with caution!)
git filter-branch --tree-filter 'rm -f large-file' HEAD
```

## Dependency Version Management

### Pinning Versions

For stability, consider pinning tool versions:

```bash
# In run_once_install-packages.sh.tmpl
# Instead of:
brew install starship

# Use:
brew install starship@1.10.0
```

**Trade-offs:**
- ✅ Consistent installations
- ✅ Reproducible environments
- ❌ Manual updates required
- ❌ Security patches delayed

### Tracking Versions

Document current versions:

```bash
# Check installed versions
zsh --version
starship --version
chezmoi --version
age --version

# Save to version file
cat > docs/VERSIONS.md << EOF
# Current Tool Versions

- Zsh: $(zsh --version)
- Starship: $(starship --version)
- Chezmoi: $(chezmoi --version)
- Age: $(age --version)

Last updated: $(date)
EOF
```

## Troubleshooting Maintenance Issues

### Installation Script Failures

**Issue**: Script fails on specific OS
```bash
# Debug by running with verbose output
bash -x run_once_install-packages.sh.tmpl

# Check OS detection
uname -s
uname -m
```

**Issue**: Package installation fails
```bash
# Update package lists first
# macOS
brew update

# Ubuntu/Debian
sudo apt-get update

# Retry installation
```

### Plugin Update Failures

**Issue**: Oh My Zsh update fails
```bash
# Reset to latest
cd ~/.oh-my-zsh
git reset --hard origin/master
git pull
```

**Issue**: Custom plugin update fails
```bash
# Re-clone the plugin
cd ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins
rm -rf plugin-name
git clone https://github.com/user/plugin-name
```

## Backup and Recovery

See [BACKUP_RECOVERY.md](BACKUP_RECOVERY.md) for detailed backup and recovery procedures.

Quick backup:

```bash
# Backup chezmoi source
tar -czf dotfiles-backup-$(date +%Y%m%d).tar.gz ~/.local/share/chezmoi

# Backup age key
cp ~/.config/chezmoi/key.txt ~/Documents/age-key-backup.txt
# Store in Bitwarden!
```

## Security Maintenance

### Regular Security Tasks

1. **Audit secrets**
   ```bash
   # Scan for accidentally committed secrets
   git log -p | grep -i "password\|secret\|key\|token"
   ```

2. **Update encryption**
   ```bash
   # Rotate age keys periodically (e.g., annually)
   # Generate new key
   age-keygen -o ~/.config/chezmoi/key-new.txt
   
   # Re-encrypt secrets with new key
   # Update chezmoi config
   # Delete old key after verification
   ```

3. **Review access**
   - Check who has access to your GitHub repository
   - Review Bitwarden security
   - Verify age key storage

## Staying Up to Date

### Following Updates

- **Oh My Zsh**: Watch [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh)
- **Starship**: Watch [starship/starship](https://github.com/starship/starship)
- **Chezmoi**: Watch [twpayne/chezmoi](https://github.com/twpayne/chezmoi)
- **Ghostty**: Watch [mitchellh/ghostty](https://github.com/mitchellh/ghostty)

### Newsletter and Blogs

- Subscribe to tool-specific newsletters
- Follow maintainers on social media
- Join relevant Discord/Slack communities

## Maintenance Checklist Template

```markdown
## Monthly Maintenance - [YYYY-MM]

- [ ] Oh My Zsh updated
- [ ] Oh My Zsh plugins updated
- [ ] Starship updated
- [ ] Chezmoi updated
- [ ] Shell startup time checked (< 1s)
- [ ] Tested installation on one platform
- [ ] Documentation reviewed
- [ ] No outstanding issues

Notes:
- [Any issues or observations]
```

## Conclusion

Regular maintenance ensures your dotfiles remain reliable, secure, and performant. Schedule these tasks according to your needs and adjust the frequency based on your usage patterns.
