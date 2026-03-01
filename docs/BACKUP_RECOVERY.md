# Backup and Recovery

## What to Back Up

1. **Age encryption key** (`~/.config/chezmoi/key.txt`) — without this,
   encrypted secrets are unrecoverable. Store in Bitwarden as a Secure Note.
2. **Git repository** — pushed to GitHub (primary source of truth).
3. **SSH keys** (`~/.ssh/`) — can be regenerated but inconvenient.

## Backing Up the Age Key

```bash
# Copy key content into a Bitwarden Secure Note titled "Dotfiles Age Key"
cat ~/.config/chezmoi/key.txt
```

Optionally keep a copy on an encrypted USB drive.

## Quick Source Backup

```bash
tar -czf ~/dotfiles-backup-$(date +%Y%m%d).tar.gz -C ~/.local/share/chezmoi .
```

## Recovery on a New Machine

```bash
# 1. Install chezmoi and apply dotfiles
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)"

# 2. Restore age key from Bitwarden
mkdir -p ~/.config/chezmoi
nano ~/.config/chezmoi/key.txt   # paste key
chmod 600 ~/.config/chezmoi/key.txt

# 3. Re-apply to decrypt secrets
chezmoi apply -v
```

## Lost Age Key

If you have a backup in Bitwarden, restore it to `~/.config/chezmoi/key.txt`.

If no backup exists, encrypted secrets cannot be recovered. Generate a new key
and re-create secrets:

```bash
age-keygen -o ~/.config/chezmoi/key.txt
# Re-encrypt each secret and commit to the repo
```

**Prevention**: always keep the age key in Bitwarden.

## Corrupted Local Repo

```bash
mv ~/.local/share/chezmoi ~/.local/share/chezmoi.bak
chezmoi init https://github.com/pmgledhill102/dotfiles.git
chezmoi apply -v
```

## Accidental File Deletion

```bash
chezmoi apply ~/.zshrc            # re-apply single file
chezmoi apply -v                  # or re-apply everything
```

If the source file is also gone, restore from git:

```bash
cd ~/.local/share/chezmoi
git checkout HEAD -- home/dot_zshrc
chezmoi apply ~/.zshrc
```
