# My Dotfiles

This repository contains my personal dotfiles, managed by `chezmoi`.

## Installation

To install these dotfiles on a new machine, run the following command. You can optionally pass a branch name as an argument to install a specific version of the dotfiles.

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/001-dotfiles-setup/install.sh)" -- [branch-name]
```

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
