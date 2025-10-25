# My Dotfiles

This repository contains my personal dotfiles, managed by `chezmoi`.

## Installation

To install these dotfiles on a new machine, run the following command:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <your-git-repository-url>
## Secret Management

This repository uses `chezmoi`'s integration with Bitwarden to manage secrets. To access your secrets, you will need to be logged into the Bitwarden CLI.

1.  **Log in to Bitwarden**:

    ```sh
    bw login
    ```

2.  **Sync your secrets**:

    `chezmoi` will automatically fetch your secrets from Bitwarden when you run `chezmoi apply`.
