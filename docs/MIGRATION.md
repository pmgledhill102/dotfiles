# Migration Guide

This guide helps you migrate from other dotfile management systems or manual configurations to this chezmoi-based setup.

## Table of Contents

- [Overview](#overview)
- [Before You Begin](#before-you-begin)
- [Migration Strategies](#migration-strategies)
- [From Manual Dotfiles](#from-manual-dotfiles)
- [From Other Dotfile Managers](#from-other-dotfile-managers)
- [Post-Migration Tasks](#post-migration-tasks)
- [Rollback Procedures](#rollback-procedures)

## Overview

This migration guide covers:

- Moving from manually managed dotfiles
- Migrating from other dotfile managers (GNU Stow, yadm, etc.)
- Adapting existing configurations to chezmoi
- Preserving your customizations
- Safe rollback if needed

**Migration Time Estimate:** 1-2 hours  
**Skill Level:** Intermediate shell/Git knowledge helpful

## Before You Begin

### Backup Everything

⚠️ **Critical:** Backup all your current dotfiles before starting!

```bash
# Create backup directory
mkdir -p ~/dotfiles-backup-$(date +%Y%m%d)
cd ~/dotfiles-backup-$(date +%Y%m%d)

# Backup common dotfiles
cp ~/.zshrc . 2>/dev/null || true
cp ~/.bashrc . 2>/dev/null || true
cp ~/.gitconfig . 2>/dev/null || true
cp ~/.vimrc . 2>/dev/null || true

# Backup config directories
cp -r ~/.config . 2>/dev/null || true
cp -r ~/.ssh . 2>/dev/null || true

# Create archive
cd ..
tar -czf dotfiles-backup-$(date +%Y%m%d).tar.gz dotfiles-backup-$(date +%Y%m%d)/

echo "Backup saved to: ~/dotfiles-backup-$(date +%Y%m%d).tar.gz"
```

### Document Your Current Setup

Create an inventory of what you have:

```bash
# List managed dotfiles
ls -la ~ | grep "^\."

# List config directories
ls -la ~/.config

# Document installed tools
cat > ~/migration-inventory.txt << EOF
Current Shell: $(echo $SHELL)
Shell Version: $(zsh --version 2>/dev/null || bash --version | head -1)

Installed Tools:
$(command -v git && git --version)
$(command -v vim && vim --version | head -1)
$(command -v tmux && tmux -V)
$(command -v starship && starship --version)

Current PATH:
$PATH

Custom Aliases:
$(alias)

Shell Plugins:
$(ls ~/.oh-my-zsh/custom/plugins 2>/dev/null || echo "N/A")
EOF

cat ~/migration-inventory.txt
```

### Prerequisites

Ensure you have:

- [ ] Git installed
- [ ] Backup of current dotfiles
- [ ] List of customizations to preserve
- [ ] Test environment (VM) if possible
- [ ] 1-2 hours of time

## Migration Strategies

Choose the strategy that fits your situation:

### Strategy 1: Fresh Start (Recommended for Beginners)

**When to use:**

- First time using a dotfile manager
- Want a clean, tested configuration
- Can manually migrate specific customizations

**Pros:**

- Cleanest approach
- Starts with working configuration
- Less troubleshooting

**Cons:**

- Need to manually migrate customizations
- May lose some settings initially

### Strategy 2: Gradual Migration (Recommended for Advanced Users)

**When to use:**

- Have extensive customizations
- Need to maintain productivity
- Want to migrate incrementally

**Pros:**

- Keep working setup
- Migrate at your own pace
- Less disruptive

**Cons:**

- Takes longer
- Need to manage two systems temporarily

### Strategy 3: Import Existing (For Experienced Users)

**When to use:**

- Already using a dotfile manager
- Have organized dotfiles repository
- Comfortable with chezmoi

**Pros:**

- Preserve existing setup
- Faster migration

**Cons:**

- May need cleanup
- Requires chezmoi knowledge

## From Manual Dotfiles

If you're managing dotfiles manually (copying files, symlinks, etc.):

### Step 1: Install This Dotfiles Setup

```bash
# Run installation
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)"

# This will install chezmoi and basic setup
```

**Note:** This will backup and replace your existing `.zshrc` and other files.

### Step 2: Identify Your Customizations

Review your backed-up files:

```bash
# Compare your old .zshrc with new one
diff ~/dotfiles-backup-*/. zshrc ~/.zshrc

# List your customizations
grep -v "^#" ~/dotfiles-backup-*/.zshrc | grep -v "^$"
```

### Step 3: Merge Customizations

Add your customizations to the new setup:

```bash
# Edit the new .zshrc
chezmoi edit ~/.zshrc

# Add your custom aliases, functions, etc.
# For example:
# Custom Aliases
alias myalias="my command"

# Custom Functions
myfunction() {
    # your code
}

# Apply changes
chezmoi apply ~/.zshrc

# Test
source ~/.zshrc
```

### Step 4: Migrate Other Config Files

For each config file you want to migrate:

```bash
# Option 1: Add existing file to chezmoi
chezmoi add ~/.gitconfig

# Option 2: Edit in chezmoi and copy content
chezmoi edit ~/.gitconfig
# Paste your old config

# Apply
chezmoi apply
```

### Step 5: Verify and Clean Up

```bash
# Test new setup
# Open new terminal
# Verify all your tools work

# Once satisfied, remove backups
# (Keep them for a while just in case!)
```

## From Other Dotfile Managers

### From GNU Stow

If you're using GNU Stow:

```bash
# 1. Your dotfiles are probably in ~/dotfiles/
cd ~/dotfiles

# 2. Unstow current setup (optional, if you want clean migration)
stow -D */

# 3. Install this setup
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)"

# 4. Migrate each config
# For each stow package, add files to chezmoi
for file in ~/dotfiles/zsh/.zshrc; do
    chezmoi add $file
done

# 5. Commit changes
cd ~/.local/share/chezmoi
git add .
git commit -m "Migrated from GNU Stow"
```

### From yadm

If you're using yadm:

```bash
# 1. Your dotfiles are managed by yadm
# List managed files
yadm list

# 2. Clone this repository to a temp location
git clone https://github.com/pmgledhill102/dotfiles.git ~/dotfiles-new

# 3. For each file, decide:
# - Use this repo's version (recommended for core files)
# - Merge customizations (for configs you've heavily modified)

# 4. Install this setup
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)"

# 5. Migrate custom files
chezmoi add ~/.custom-config

# 6. Remove yadm (optional)
yadm list  # Review what yadm manages
# Decide if you want to keep yadm for other files
```

### From Homesick

If you're using Homesick:

```bash
# 1. List your castles
homesick list

# 2. Export files from castles
# Your files are in ~/.homesick/repos/

# 3. Install this setup
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)"

# 4. Add custom files to chezmoi
chezmoi add ~/.config/custom-tool

# 5. Remove homesick (optional)
gem uninstall homesick
```

### From Git Bare Repository

If you're using a Git bare repository:

```bash
# 1. Your dotfiles are tracked with git bare repo
# Usually aliased like: alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# 2. List tracked files
config ls-tree --full-tree -r --name-only HEAD

# 3. Install this setup
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)"

# 4. For each file, add to chezmoi if not already managed
chezmoi add ~/.myconfig

# 5. Remove bare repo (optional)
# Only after verifying everything works!
rm -rf ~/.cfg
# Remove alias from shell config
```

## Handling Common Scenarios

### Scenario 1: Custom Aliases and Functions

```bash
# Extract from old .zshrc
grep "^alias" ~/dotfiles-backup-*/.zshrc > ~/custom-aliases.txt
grep "^function\|^[a-z_]*() {" ~/dotfiles-backup-*/.zshrc > ~/custom-functions.txt

# Add to new .zshrc
chezmoi edit ~/.zshrc

# Add section:
# Custom Aliases (migrated)
# [paste your aliases]

# Custom Functions (migrated)
# [paste your functions]

# Apply
chezmoi apply ~/.zshrc
```

### Scenario 2: Multiple Machines with Different Configs

If you have machine-specific configurations:

```bash
# Use chezmoi templates
chezmoi edit ~/.zshrc

# Add conditional logic:
{{ if eq .chezmoi.hostname "work-laptop" }}
# Work-specific configuration
export WORK_VAR="value"
{{ else if eq .chezmoi.hostname "personal-desktop" }}
# Personal-specific configuration
export PERSONAL_VAR="value"
{{ end }}

# Apply
chezmoi apply
```

### Scenario 3: Encrypted Secrets

If you have secrets in your old dotfiles:

```bash
# 1. Generate age key if not already done
age-keygen -o ~/.config/chezmoi/key.txt

# 2. Create encrypted file
chezmoi edit --encrypted ~/.secrets

# 3. Add your secrets
# [paste secret content]

# 4. Apply (chezmoi encrypts automatically)
chezmoi apply

# 5. Remove plaintext secrets from old location
# Verify encrypted version works first!
```

### Scenario 4: Custom Scripts and Tools

```bash
# Add your custom scripts directory
mkdir -p ~/.local/bin
chezmoi add ~/.local/bin

# Or add individual scripts
chezmoi add ~/.local/bin/my-script.sh

# Ensure ~/.local/bin is in PATH (already in this setup)
```

## Post-Migration Tasks

### Verify Installation

```bash
# Check shell
echo $SHELL
zsh --version

# Check prompt
# Open new terminal - should see Starship prompt

# Check Oh My Zsh
omz version

# Check plugins work
# Type command and look for suggestions (zsh-autosuggestions)
# Look for syntax highlighting

# Check custom aliases
alias | grep "my"

# Check custom functions
which myfunction
```

### Update Git Repository

```bash
# Commit all changes
cd ~/.local/share/chezmoi
git add .
git commit -m "Migrated from [previous system]"

# Push to your fork (if you forked this repo)
git remote set-url origin https://github.com/yourusername/dotfiles.git
git push
```

### Test on Another Machine

```bash
# Install on another machine or VM
sh -c "$(curl -fsSL https://raw.githubusercontent.com/yourusername/dotfiles/main/install.sh)"

# Verify everything works
```

### Clean Up

After verifying everything works for at least a week:

```bash
# Remove old dotfile manager
# (Specific to what you were using)

# Remove backups (keep archive just in case)
rm -rf ~/dotfiles-backup-20250115/
# Keep: ~/dotfiles-backup-20250115.tar.gz
```

## Rollback Procedures

If you need to rollback:

### Quick Rollback

```bash
# Restore from backup
cd ~/dotfiles-backup-20250115
cp .zshrc ~/.zshrc
cp .bashrc ~/.bashrc
# etc.

# Restart shell
exec zsh  # or exec bash
```

### Complete Rollback

```bash
# 1. Uninstall chezmoi
rm -rf ~/.local/share/chezmoi
rm -rf ~/.config/chezmoi
rm $(which chezmoi)

# 2. Restore all files
cd ~/dotfiles-backup-20250115
cp -r . ~/

# 3. Reinstall old dotfile manager if needed

# 4. Restart shell
exec zsh
```

## Migration Checklist

Use this checklist to track your migration:

```markdown
## Migration Checklist

### Pre-Migration
- [ ] Backed up all dotfiles
- [ ] Documented current setup
- [ ] Identified customizations to preserve
- [ ] Tested in VM (optional)

### Migration
- [ ] Installed new dotfiles setup
- [ ] Migrated shell configuration (.zshrc)
- [ ] Migrated Git config
- [ ] Migrated custom scripts
- [ ] Migrated other config files
- [ ] Set up secret encryption
- [ ] Committed changes to Git

### Verification
- [ ] Shell works correctly
- [ ] Prompt displays correctly
- [ ] All custom aliases work
- [ ] All custom functions work
- [ ] Plugins function correctly
- [ ] Secrets decrypt properly
- [ ] No errors on shell startup

### Post-Migration
- [ ] Tested for at least one week
- [ ] Updated Git repository
- [ ] Tested on another machine
- [ ] Cleaned up old system
- [ ] Removed backups (kept archive)

### Issues Found
- [List any issues and resolutions]
```

## Getting Help During Migration

If you encounter issues:

1. **Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)**
2. **Review your backup**
3. **Test in a VM**
4. **Ask for help with specific error messages**

## Tips for Successful Migration

1. **Take it slow** - Don't rush the migration
2. **Test in VM first** - Especially for major changes
3. **Keep backups** - For at least a month
4. **Migrate incrementally** - One file at a time if needed
5. **Document changes** - Note what you changed and why
6. **Version control** - Commit often during migration
7. **Ask for help** - If stuck, ask with details

## Example Migration Timeline

**Day 1:**

- Backup current setup
- Install new dotfiles
- Basic verification

**Day 2-3:**

- Migrate custom aliases and functions
- Test daily workflows

**Day 4-7:**

- Migrate additional config files
- Fine-tune configurations
- Test thoroughly

**Week 2-4:**

- Use new setup daily
- Fix any issues
- Keep backup accessible

**After 1 Month:**

- If stable, clean up old system
- Archive backups
- Celebrate! 🎉

## Conclusion

Migration to this dotfiles setup gives you:

- ✅ Consistent setup across machines
- ✅ Secure secret management
- ✅ Easy installation
- ✅ Version control
- ✅ Active maintenance

Take your time with the migration, test thoroughly, and don't hesitate to ask for help. Your dotfiles are personal, so make sure the new setup works for you!
