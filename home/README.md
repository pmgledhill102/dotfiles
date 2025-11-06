# My Dotfiles

This repository contains my personal dotfiles, managed by `chezmoi`.

## Installation

To install these dotfiles on a new machine, run the following command:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --branch 001-dotfiles-setup https://github.com/pmgledhill102/dotfiles.git
```

## Secret Management

This repository uses `age` to encrypt sensitive files. `chezmoi` will
automatically decrypt these files when you run `chezmoi apply`, and will prompt
you for your passphrase.

You do not need to perform any manual steps to decrypt secrets during
installation.

To add a new secret or edit an existing one:

1. **Add the file**: Create or edit the plaintext file in your local source
   directory (e.g., `~/.local/share/chezmoi/home/.my-secret`).
2. **Encrypt the file**: Run `chezmoi encrypt ~/.local/share/chezmoi/home/.my-secret`.
   This will create an encrypted file `.../.my-secret.age`.
3. **Commit**: Commit the `.age` file to your repository. `chezmoi` will
   automatically ignore the plaintext version.
