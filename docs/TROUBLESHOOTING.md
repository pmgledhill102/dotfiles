# Troubleshooting Guide

This guide helps you diagnose and fix common issues with your dotfiles setup.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Shell and Prompt Issues](#shell-and-prompt-issues)
- [Secret Management Issues](#secret-management-issues)
- [Plugin Issues](#plugin-issues)
- [Performance Issues](#performance-issues)
- [Platform-Specific Issues](#platform-specific-issues)
- [Getting Help](#getting-help)

## Installation Issues

### Issue: Installation Script Fails

**Symptoms:**
- Script exits with error
- Packages fail to install
- Permission denied errors

**Diagnosis:**

```bash
# Run with verbose output
bash -x run_once_install-packages.sh.tmpl

# Check for error messages
# Look for specific failing command
```

**Solutions:**

1. **Package manager not updated**
   ```bash
   # macOS
   brew update
   
   # Ubuntu/Debian
   sudo apt-get update
   ```

2. **Insufficient permissions**
   ```bash
   # Some commands may need sudo
   # Check the script and add sudo where needed
   ```

3. **Missing dependencies**
   ```bash
   # Install basic dependencies first
   # macOS: xcode-select --install
   # Ubuntu: sudo apt-get install build-essential git curl
   ```

4. **Network issues**
   ```bash
   # Test connectivity
   ping -c 3 github.com
   curl -I https://raw.githubusercontent.com
   
   # Check proxy settings if behind corporate firewall
   ```

### Issue: chezmoi Not Found After Installation

**Symptoms:**
- `command not found: chezmoi` after installation
- chezmoi installed but not in PATH

**Solutions:**

```bash
# Check if chezmoi is installed
which chezmoi
/usr/local/bin/chezmoi --version

# Add to PATH if needed (macOS/Linux)
echo 'export PATH="$PATH:/usr/local/bin"' >> ~/.zshrc
source ~/.zshrc

# Or reinstall
sh -c "$(curl -fsLS get.chezmoi.io)"
```

### Issue: Installation Script Runs Every Time

**Symptoms:**
- `run_once_*` script runs on every shell start
- Installs packages repeatedly

**Solutions:**

```bash
# Check chezmoi state
chezmoi state dump

# The script should create a state file
# If missing, chezmoi may not be tracking it correctly

# Manually mark as run
touch ~/.config/chezmoi/run_once_install-packages.sh.tmpl.run

# Or check script for idempotency issues
```

## Shell and Prompt Issues

### Issue: Zsh Not Default Shell

**Symptoms:**
- Bash starts instead of Zsh
- `echo $SHELL` shows `/bin/bash`

**Solutions:**

```bash
# Check if Zsh is installed
which zsh

# Set Zsh as default shell
chsh -s $(which zsh)

# May need to add Zsh to /etc/shells first
sudo echo $(which zsh) >> /etc/shells
chsh -s $(which zsh)

# Restart terminal or log out/in
```

### Issue: Starship Prompt Not Showing

**Symptoms:**
- Default shell prompt instead of Starship
- No custom prompt symbols

**Diagnosis:**

```bash
# Check if Starship is installed
which starship
starship --version

# Check if initialized in .zshrc
grep starship ~/.zshrc
```

**Solutions:**

1. **Starship not installed**
   ```bash
   # macOS
   brew install starship
   
   # Linux
   curl -sS https://starship.rs/install.sh | sh
   ```

2. **Not initialized in .zshrc**
   ```bash
   # Add to ~/.zshrc
   eval "$(starship init zsh)"
   
   # Reload
   source ~/.zshrc
   ```

3. **Configuration file missing**
   ```bash
   # Check for config
   ls ~/.config/starship.toml
   
   # Apply from chezmoi if missing
   chezmoi apply ~/.config/starship.toml
   ```

### Issue: Prompt Shows Weird Characters

**Symptoms:**
- Boxes, question marks, or broken symbols in prompt
- Misaligned prompt elements

**Solutions:**

1. **Missing Nerd Font**
   ```bash
   # Install a Nerd Font
   # macOS
   brew tap homebrew/cask-fonts
   brew install --cask font-meslo-lg-nerd-font
   
   # Set font in terminal emulator
   # Ghostty: Update config file
   # Other: Check terminal preferences
   ```

2. **Terminal doesn't support Unicode**
   ```bash
   # Check locale
   locale
   
   # Set UTF-8 locale
   export LC_ALL=en_US.UTF-8
   export LANG=en_US.UTF-8
   
   # Add to .zshrc
   ```

### Issue: Oh My Zsh Not Loading

**Symptoms:**
- Plugins don't work
- `.zshrc` seems to be ignored

**Diagnosis:**

```bash
# Check if Oh My Zsh is installed
ls -la ~/.oh-my-zsh

# Check .zshrc for Oh My Zsh initialization
cat ~/.zshrc | grep "oh-my-zsh"
```

**Solutions:**

1. **Oh My Zsh not installed**
   ```bash
   # Install Oh My Zsh
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
   
   # Or re-run installation script
   ```

2. **Incorrect .zshrc**
   ```bash
   # Reapply from chezmoi
   chezmoi apply ~/.zshrc
   
   # Verify content
   cat ~/.zshrc
   ```

3. **Syntax error in .zshrc**
   ```bash
   # Check for errors
   zsh -n ~/.zshrc
   
   # View errors and fix
   ```

## Secret Management Issues

### Issue: Age Decryption Fails

**Symptoms:**
- "failed to decrypt" error
- Prompted for passphrase but fails
- Cannot access encrypted files

**Diagnosis:**

```bash
# Check if age is installed
which age
age --version

# Check if key file exists
ls -la ~/.config/chezmoi/key.txt

# Verify key file permissions
ls -l ~/.config/chezmoi/key.txt
# Should be -rw------- (600)
```

**Solutions:**

1. **Age key missing**
   ```bash
   # Restore from backup (Bitwarden)
   mkdir -p ~/.config/chezmoi
   # Paste key content into ~/.config/chezmoi/key.txt
   chmod 600 ~/.config/chezmoi/key.txt
   ```

2. **Wrong key file**
   ```bash
   # Verify key format
   cat ~/.config/chezmoi/key.txt
   # Should start with: AGE-SECRET-KEY-1...
   
   # If wrong, restore correct key from backup
   ```

3. **Incorrect permissions**
   ```bash
   chmod 600 ~/.config/chezmoi/key.txt
   ```

4. **Corrupted encrypted file**
   ```bash
   # Check file
   file ~/.local/share/chezmoi/home/private_*.age
   
   # May need to re-encrypt from source
   ```

### Issue: Secrets Not Applying

**Symptoms:**
- Encrypted files not decrypted to home directory
- Missing configuration files

**Solutions:**

```bash
# Force reapply
chezmoi apply -v

# Check chezmoi status
chezmoi status

# Manually decrypt to test
age -d -i ~/.config/chezmoi/key.txt ~/.local/share/chezmoi/home/private_file.age
```

## Plugin Issues

### Issue: Zsh Autosuggestions Not Working

**Symptoms:**
- No command suggestions as you type
- Plugin seems inactive

**Solutions:**

1. **Plugin not installed**
   ```bash
   # Check installation
   ls ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
   
   # Install if missing
   git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
   ```

2. **Not enabled in .zshrc**
   ```bash
   # Check plugins list
   grep "plugins=" ~/.zshrc
   
   # Should include: zsh-autosuggestions
   # If missing, add to plugins array
   ```

3. **Reload configuration**
   ```bash
   source ~/.zshrc
   ```

### Issue: Syntax Highlighting Not Working

**Symptoms:**
- Commands not color-coded
- No syntax highlighting in terminal

**Solutions:**

```bash
# Check installation
ls ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Install if missing
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Ensure in plugins list
grep "zsh-syntax-highlighting" ~/.zshrc

# Reload
source ~/.zshrc
```

### Issue: Plugin Causing Slow Startup

**Symptoms:**
- Shell takes long time to start
- Noticeable delay when opening terminal

**Diagnosis:**

```bash
# Profile shell startup
time zsh -i -c exit

# Detailed profiling - add to top of .zshrc
zmodload zsh/zprof

# Add to bottom of .zshrc
zprof

# Restart shell and check output
```

**Solutions:**

1. **Disable problematic plugin**
   ```bash
   # Remove from plugins list in .zshrc
   # Test startup time again
   ```

2. **Lazy load plugins**
   ```bash
   # Use conditional loading
   # Or async initialization
   ```

## Performance Issues

### Issue: Slow Shell Startup

**Target:** < 1 second startup time

**Diagnosis:**

```bash
# Time startup
time zsh -i -c exit

# Profile with zprof (add to .zshrc)
zmodload zsh/zprof
# ... rest of config ...
zprof
```

**Solutions:**

1. **Too many plugins**
   - Remove unused plugins
   - Lazy load when possible

2. **Expensive operations in .zshrc**
   ```bash
   # Avoid network calls
   # Cache expensive operations
   # Move to separate scripts
   ```

3. **Large history file**
   ```bash
   # Trim history
   echo "" > ~/.zsh_history
   # Or limit history size in .zshrc
   HISTSIZE=10000
   SAVEHIST=10000
   ```

### Issue: High Memory Usage

**Symptoms:**
- Terminal uses excessive memory
- System becomes sluggish

**Diagnosis:**

```bash
# Check memory usage
ps aux | grep zsh
top -p $(pgrep zsh)
```

**Solutions:**

1. **Plugin memory leak**
   - Identify problematic plugin
   - Update or remove

2. **Too many background jobs**
   ```bash
   # Check jobs
   jobs
   
   # Kill unnecessary jobs
   kill %job_number
   ```

## Platform-Specific Issues

### macOS Issues

#### Issue: Homebrew Installation Fails

```bash
# Check Xcode Command Line Tools
xcode-select --install

# Update Homebrew
brew update
brew doctor

# Fix common issues
brew cleanup
```

#### Issue: Ghostty Not Installing

```bash
# Check if tap exists
brew tap | grep ghostty

# Install manually
brew install --cask ghostty

# Or check official releases
# https://github.com/mitchellh/ghostty/releases
```

### Ubuntu/Debian Issues

#### Issue: apt-get Fails

```bash
# Update package lists
sudo apt-get update

# Fix broken packages
sudo apt-get install -f

# Clean cache
sudo apt-get clean
sudo apt-get autoclean
```

#### Issue: Zsh Not Available

```bash
# Install Zsh
sudo apt-get install zsh

# Verify
which zsh
zsh --version
```

### WSL Issues

#### Issue: Installation Fails on WSL

```bash
# Check WSL version
wsl --version

# Update WSL
wsl --update

# Ensure running WSL 2
wsl --set-version Ubuntu 2
```

#### Issue: Windows Paths in WSL

```bash
# Windows paths may cause issues
# Check PATH
echo $PATH

# Clean up Windows paths if needed
# Edit .zshrc to filter PATH
```

## Common Error Messages

### "command not found"

**Cause:** Tool not installed or not in PATH

**Solution:**
```bash
# Check if installed
which <command>

# Check PATH
echo $PATH

# Reinstall or add to PATH
```

### "permission denied"

**Cause:** Insufficient permissions

**Solution:**
```bash
# Check file permissions
ls -l <file>

# Fix permissions
chmod +x <file>  # For scripts
chmod 600 <file>  # For secrets

# May need sudo for system changes
```

### "file not found"

**Cause:** File missing or incorrect path

**Solution:**
```bash
# Check if file exists
ls -la <path>

# Reapply from chezmoi
chezmoi apply <file>

# Check chezmoi source
chezmoi status
```

## Debugging Tips

### Enable Verbose Output

```bash
# Chezmoi verbose mode
chezmoi apply -v

# Shell debug mode
set -x  # Enable
set +x  # Disable

# Or run script with debug
bash -x script.sh
```

### Check Logs

```bash
# System logs (macOS)
log show --predicate 'process == "zsh"' --last 1h

# System logs (Linux)
journalctl -u user@$(id -u).service --since "1 hour ago"

# Check .zshrc for errors
zsh -n ~/.zshrc
```

### Verify Configuration

```bash
# Check what chezmoi would apply
chezmoi diff

# Verify file sources
chezmoi managed

# Check chezmoi data
chezmoi data
```

### Test in Clean Environment

```bash
# Start Zsh with no config
zsh -f

# Start with minimal config
zsh --no-rcs
```

## Getting Help

### Before Asking for Help

1. **Check this troubleshooting guide**
2. **Review error messages carefully**
3. **Search existing issues on GitHub**
4. **Try in a clean environment (VM)**
5. **Collect relevant information:**
   - OS and version
   - Tool versions
   - Error messages
   - Steps to reproduce

### Where to Get Help

- **Documentation**: Review [README.md](../README.md) and [CONTRIBUTING.md](../CONTRIBUTING.md)
- **GitHub Issues**: Open an issue with details
- **Oh My Zsh**: https://github.com/ohmyzsh/ohmyzsh/wiki
- **Starship**: https://starship.rs/guide/
- **Chezmoi**: https://www.chezmoi.io/user-guide/

### Information to Provide

When asking for help, include:

```bash
# System information
uname -a
echo $SHELL
zsh --version

# Tool versions
chezmoi --version
starship --version
age --version

# Configuration check
chezmoi doctor

# Error messages
# Copy full error output
```

## Emergency Recovery

If everything is broken:

```bash
# 1. Backup current state
mv ~/.zshrc ~/.zshrc.broken
mv ~/.local/share/chezmoi ~/.local/share/chezmoi.broken

# 2. Restore from GitHub
chezmoi init https://github.com/pmgledhill102/dotfiles.git

# 3. Restore age key from Bitwarden
# Copy to ~/.config/chezmoi/key.txt

# 4. Apply configuration
chezmoi apply -v

# 5. Restart shell
exec zsh
```

See [BACKUP_RECOVERY.md](BACKUP_RECOVERY.md) for detailed recovery procedures.

## Checklist for Troubleshooting

When facing an issue, work through this checklist:

- [ ] Read error message carefully
- [ ] Check this guide for the specific issue
- [ ] Verify tool is installed: `which <tool>`
- [ ] Check tool version: `<tool> --version`
- [ ] Review configuration files for syntax errors
- [ ] Test in clean environment (new terminal/VM)
- [ ] Check logs for additional context
- [ ] Search for similar issues online
- [ ] Document solution for future reference

## Prevention

Prevent issues before they occur:

- Keep tools updated regularly
- Test changes in a VM before applying
- Backup critical files (especially age key)
- Document custom modifications
- Review changes before committing
- Use version control for all configs

## Reporting Bugs

Found a bug in the dotfiles? Please report it:

1. **Check if already reported**: Search GitHub issues
2. **Provide details**:
   - Expected behavior
   - Actual behavior
   - Steps to reproduce
   - System information
   - Error messages
3. **Create minimal reproduction**: Simplify to core issue
4. **Submit issue**: Include all relevant information

## Conclusion

Most issues can be resolved by:
1. Checking this guide
2. Verifying installations
3. Reviewing configurations
4. Testing in clean environment

If stuck, don't hesitate to ask for help with detailed information about your issue.
