# Backup and Recovery Procedures

This guide covers backup strategies and recovery procedures for your dotfiles and associated data.

## Table of Contents

- [What to Back Up](#what-to-back-up)
- [Backup Strategies](#backup-strategies)
- [Automated Backups](#automated-backups)
- [Recovery Procedures](#recovery-procedures)
- [Disaster Recovery](#disaster-recovery)
- [Testing Backups](#testing-backups)

## What to Back Up

### Critical Data

These items are essential and must be backed up:

1. **Age Encryption Key** (`~/.config/chezmoi/key.txt`)
   - **Criticality**: ⭐⭐⭐⭐⭐ CRITICAL
   - Without this, encrypted secrets cannot be decrypted
   - Store in Bitwarden and keep offline backup

2. **Chezmoi Source Directory** (`~/.local/share/chezmoi`)
   - **Criticality**: ⭐⭐⭐⭐ HIGH
   - Contains all dotfile sources
   - Usually synced with Git repository

3. **Git Repository** (GitHub)
   - **Criticality**: ⭐⭐⭐⭐ HIGH
   - Primary source of truth
   - Should be backed up outside GitHub

### Important Data

These items should be backed up but can be recreated:

4. **Bitwarden Vault**
   - Contains highly sensitive secrets
   - Managed by Bitwarden's own backup system
   - Export periodically as additional backup

5. **SSH Keys** (`~/.ssh/`)
   - Can be regenerated but inconvenient
   - Back up private keys securely

6. **Custom Scripts** (if not in dotfiles)
   - Any scripts or tools not tracked by chezmoi

### Optional Data

These items are nice to back up but not critical:

7. **Shell History** (`~/.zsh_history`)
   - Useful for reference
   - Not critical for functionality

8. **Local Configurations**
   - Machine-specific settings
   - Can be recreated

## Backup Strategies

### Strategy 1: Git Repository (Primary)

Your dotfiles are already backed up in Git:

```bash
# Ensure all changes are committed
cd ~/.local/share/chezmoi
git status
git add .
git commit -m "Update dotfiles"
git push
```

**Pros:**
- Automatic version control
- Easy to restore
- Synced across machines

**Cons:**
- Secrets must be encrypted
- Requires internet access
- Limited to what's tracked

### Strategy 2: Age Key Backup (Critical)

The age encryption key must be backed up separately:

```bash
# Copy to a secure location
cp ~/.config/chezmoi/key.txt ~/Documents/age-key-backup-$(date +%Y%m%d).txt

# Store in Bitwarden
# 1. Open Bitwarden
# 2. Create new Secure Note
# 3. Title: "Dotfiles Age Encryption Key"
# 4. Paste key content
# 5. Save
```

**Additional backup locations:**
- Encrypted USB drive
- Password-protected external drive
- Secure cloud storage (encrypted)

### Strategy 3: Full Archive Backup

Create a complete backup archive:

```bash
# Create backup directory
mkdir -p ~/dotfiles-backup

# Backup chezmoi source
cd ~/.local/share/chezmoi
tar -czf ~/dotfiles-backup/chezmoi-source-$(date +%Y%m%d).tar.gz .

# Backup age key
cp ~/.config/chezmoi/key.txt ~/dotfiles-backup/age-key-$(date +%Y%m%d).txt

# Backup SSH keys (optional)
tar -czf ~/dotfiles-backup/ssh-keys-$(date +%Y%m%d).tar.gz ~/.ssh

# Create archive info
cat > ~/dotfiles-backup/README.txt << EOF
Dotfiles Backup
Created: $(date)
Machine: $(hostname)
User: $(whoami)
Git Commit: $(cd ~/.local/share/chezmoi && git rev-parse HEAD)
EOF

# Archive everything
cd ~/dotfiles-backup
tar -czf dotfiles-complete-backup-$(date +%Y%m%d).tar.gz .
```

### Strategy 4: Cloud Sync

Sync backups to cloud storage:

```bash
# Using rsync to cloud storage (if mounted)
rsync -av ~/dotfiles-backup/ /Volumes/CloudDrive/dotfiles-backup/

# Or use rclone for various cloud providers
# rclone sync ~/dotfiles-backup/ remote:dotfiles-backup
```

## Automated Backups

### Daily Backup Script

Create an automated backup script:

```bash
#!/bin/bash
# File: ~/bin/backup-dotfiles.sh

set -e

BACKUP_DIR="$HOME/dotfiles-backup"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="dotfiles-backup-$DATE"

echo "Starting dotfiles backup: $BACKUP_NAME"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup chezmoi source
cd "$HOME/.local/share/chezmoi"
tar -czf "$BACKUP_DIR/$BACKUP_NAME-chezmoi.tar.gz" .

# Backup age key (encrypted)
if [ -f "$HOME/.config/chezmoi/key.txt" ]; then
    cp "$HOME/.config/chezmoi/key.txt" "$BACKUP_DIR/$BACKUP_NAME-age-key.txt"
fi

# Keep only last 7 backups
cd "$BACKUP_DIR"
ls -t | tail -n +15 | xargs -r rm

echo "Backup completed: $BACKUP_NAME"
echo "Location: $BACKUP_DIR"
```

Make it executable and test:

```bash
chmod +x ~/bin/backup-dotfiles.sh
~/bin/backup-dotfiles.sh
```

### Schedule with Cron (Linux/WSL)

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * $HOME/bin/backup-dotfiles.sh >> $HOME/dotfiles-backup/backup.log 2>&1
```

### Schedule with launchd (macOS)

Create `~/Library/LaunchAgents/com.user.dotfiles-backup.plist` (replace `USERNAME` with your actual username):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.dotfiles-backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/USERNAME/bin/backup-dotfiles.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardErrorPath</key>
    <string>/Users/USERNAME/dotfiles-backup/backup-error.log</string>
    <key>StandardOutPath</key>
    <string>/Users/USERNAME/dotfiles-backup/backup.log</string>
</dict>
</plist>
```

**Note**: Replace `USERNAME` with your actual username, or use `$HOME` in the paths where appropriate.

Load the agent:

```bash
launchctl load ~/Library/LaunchAgents/com.user.dotfiles-backup.plist
```

## Recovery Procedures

### Scenario 1: Fresh Machine Setup

Starting from scratch on a new machine:

```bash
# 1. Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# 2. Initialize from your repository
chezmoi init https://github.com/pmgledhill102/dotfiles.git

# 3. Restore age key from Bitwarden
# Copy key content to ~/.config/chezmoi/key.txt
mkdir -p ~/.config/chezmoi
nano ~/.config/chezmoi/key.txt
# Paste key content
chmod 600 ~/.config/chezmoi/key.txt

# 4. Apply dotfiles
chezmoi apply -v

# 5. Verify installation
command -v zsh
command -v starship
```

### Scenario 2: Corrupted Local Repository

If your local chezmoi repository is corrupted:

```bash
# 1. Backup current state (just in case)
mv ~/.local/share/chezmoi ~/.local/share/chezmoi.corrupted

# 2. Re-initialize from GitHub
chezmoi init https://github.com/pmgledhill102/dotfiles.git

# 3. Restore age key
cp ~/path/to/backup/age-key.txt ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt

# 4. Apply dotfiles
chezmoi apply -v

# 5. Verify
chezmoi diff
```

### Scenario 3: Lost Age Key

If you've lost your age encryption key:

**If you have a backup:**

```bash
# Restore from backup
cp ~/backup/age-key.txt ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt

# Verify
chezmoi apply -v
```

**If you have no backup:**

Unfortunately, encrypted secrets cannot be recovered without the key. You'll need to:

1. Generate a new age key
2. Re-create all encrypted secrets
3. Re-encrypt and commit to repository

```bash
# Generate new key
age-keygen -o ~/.config/chezmoi/key.txt

# Update chezmoi config to use new key
# Recreate encrypted files with new secrets
# Commit changes to repository
```

**Prevention:** Always keep age key backed up in Bitwarden!

### Scenario 4: Accidental File Deletion

If you accidentally delete a dotfile:

```bash
# 1. Check current state
chezmoi status

# 2. Re-apply from source
chezmoi apply ~/.zshrc

# Or re-apply everything
chezmoi apply -v

# 3. If source is also deleted, restore from Git
cd ~/.local/share/chezmoi
git checkout HEAD -- home/dot_zshrc
chezmoi apply ~/.zshrc
```

### Scenario 5: Git Repository Issues

If Git history has problems:

```bash
# Option 1: Reset to last known good state
cd ~/.local/share/chezmoi
git reflog  # Find good commit
git reset --hard <commit-hash>

# Option 2: Re-clone from GitHub
cd ~
mv ~/.local/share/chezmoi ~/.local/share/chezmoi.backup
git clone https://github.com/pmgledhill102/dotfiles.git ~/.local/share/chezmoi
```

## Disaster Recovery

### Complete System Loss

Full recovery from complete data loss:

**Prerequisites:**
- Age key stored in Bitwarden ✅
- GitHub repository accessible ✅
- Bitwarden account accessible ✅

**Recovery Steps:**

1. **Set up new machine basics**
   ```bash
   # Install Git (if not present)
   # macOS: xcode-select --install
   # Ubuntu: sudo apt-get install git
   ```

2. **Install chezmoi**
   ```bash
   sh -c "$(curl -fsLS get.chezmoi.io)"
   ```

3. **Retrieve age key from Bitwarden**
   - Log into Bitwarden
   - Find "Dotfiles Age Encryption Key" secure note
   - Copy key content

4. **Initialize dotfiles**
   ```bash
   # Initialize from repository
   chezmoi init https://github.com/pmgledhill102/dotfiles.git
   
   # Add age key
   mkdir -p ~/.config/chezmoi
   nano ~/.config/chezmoi/key.txt  # Paste key
   chmod 600 ~/.config/chezmoi/key.txt
   ```

5. **Apply configuration**
   ```bash
   chezmoi apply -v
   ```

6. **Run installation script**
   ```bash
   # The installation script should run automatically
   # Or run manually if needed
   ```

7. **Verify recovery**
   ```bash
   # Check shell
   echo $SHELL
   
   # Check prompt
   # Open new terminal
   
   # Check tools
   command -v zsh starship chezmoi age
   
   # Check Oh My Zsh
   omz version
   ```

8. **Restore SSH keys** (from backup)
   ```bash
   # Copy from backup location
   # Or generate new keys
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

**Recovery Time Objective (RTO):** ~30 minutes
**Recovery Point Objective (RPO):** Last Git push

## Testing Backups

### Regular Testing Schedule

Test your backup and recovery procedures regularly:

- **Monthly**: Verify age key is in Bitwarden
- **Quarterly**: Full recovery test in a VM
- **Annually**: Disaster recovery drill

### Backup Verification Checklist

```markdown
## Backup Verification - [YYYY-MM-DD]

- [ ] Age key accessible in Bitwarden
- [ ] GitHub repository up to date
- [ ] Latest chezmoi backup exists
- [ ] Backup archive can be extracted
- [ ] Age key from backup can decrypt secrets
- [ ] Fresh install succeeds in VM
- [ ] All tools install correctly
- [ ] Shell prompt appears correctly
- [ ] Plugins work as expected
- [ ] Secrets decrypt successfully

Issues found:
- [List any issues]

Actions taken:
- [List corrective actions]
```

### VM Recovery Test

Perform a complete recovery test in a virtual machine:

```bash
# 1. Create fresh VM (macOS or Ubuntu)
# 2. Document the process
# 3. Time the recovery
# 4. Note any issues
# 5. Update procedures based on findings
```

## Best Practices

1. **Multiple Backup Locations**
   - Git repository (primary)
   - Bitwarden (age key)
   - Local encrypted backup
   - Cloud storage (optional)

2. **Regular Testing**
   - Test restore process quarterly
   - Verify backups are not corrupted
   - Practice disaster recovery

3. **Documentation**
   - Keep recovery procedures updated
   - Document any custom configurations
   - Note machine-specific settings

4. **Security**
   - Encrypt backup archives
   - Secure age key backups
   - Use strong Bitwarden master password
   - Enable 2FA on all accounts

5. **Automation**
   - Automate regular backups
   - Set up monitoring/alerts
   - Log backup operations

## Emergency Contacts

**Key Services:**
- GitHub Support: https://support.github.com
- Bitwarden Support: https://bitwarden.com/contact
- Chezmoi Documentation: https://www.chezmoi.io

**Recovery Resources:**
- This guide: `docs/BACKUP_RECOVERY.md`
- Installation guide: `README.md`
- Contributing guide: `CONTRIBUTING.md`

## Backup Health Checklist

Use this checklist to ensure your backup strategy is working:

```markdown
## Monthly Backup Health Check

Date: [YYYY-MM-DD]

### Critical Backups
- [ ] Age key in Bitwarden (verified accessible)
- [ ] Git repository pushed to GitHub (within 7 days)
- [ ] Local backup archive created (within 30 days)

### Verification
- [ ] Can log into Bitwarden
- [ ] Can access GitHub repository
- [ ] Can find age key in Bitwarden
- [ ] Git repository is not corrupted
- [ ] Backup archives can be extracted

### Documentation
- [ ] Recovery procedures are up to date
- [ ] Backup locations documented
- [ ] Emergency contacts current

### Actions Needed
- [List any required actions]
```

## Conclusion

Regular backups and tested recovery procedures are essential for maintaining your dotfiles. The combination of Git version control, Bitwarden for critical keys, and periodic archive backups provides a robust safety net.

Remember: **A backup you haven't tested is not a backup!**
