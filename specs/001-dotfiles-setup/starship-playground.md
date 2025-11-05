# Starship Playground

This document outlines the steps to install and configure Starship.

## Installation

We'll use Homebrew to install Starship on macOS.

```bash
brew install starship
```

## Configuration

To enable Starship in your Zsh shell, you need to add the following line to the end of your `~/.zshrc` file:

```zsh
eval "$(starship init zsh)"
```

Since you are using `chezmoi` to manage your dotfiles, you should add this line to your `home/dot_zshrc` file.

The main configuration file for Starship is `~/.config/starship.toml`. You can create this file to customize your prompt.

## Next Steps

With Starship installed, we can start migrating your existing prompt customizations. I'm ready for your OhMyPosh examples when you are.

## Oh My Posh Configuration Summary

Here is a breakdown of your current Oh My Posh setup, based on `oh-my-posh-theme.yaml`. We will use this as a reference to configure Starship.

### Console Title
- Sets the console title to: `{{ .Shell }} in {{ .Folder }}`

### Left Prompt (`prompt`)
The left side of your prompt displays the following segments in order:
1.  **OS:** Shows an icon for the operating system, and "WSL" if applicable.
2.  **Session:** Displays your username.
3.  **Path:** Shows the current directory path.
4.  **Git:** A detailed git status including:
    - Upstream status icon
    - Branch name (`HEAD`)
    - Branch status (ahead/behind)
    - Working directory changes (e.g., `*M`)
    - Staging area changes (e.g., `+A`)
    - Stash count
5.  **Node.js:** Shows Node.js version.
6.  **Go:** Shows Go version.
7.  **Julia:** Shows Julia version.
8.  **Python:** Shows Python version.
9.  **Ruby:** Shows Ruby version.
10. **Azure Functions:** Shows Azure Functions information.
11. **AWS:** Displays the current AWS profile and region, with specific colors for "default" and "jan" profiles.
12. **Root:** Shows an indicator if you are the root user.
13. **Status:** Shows a success or failure icon based on the last command's exit code.
14. **Text:** A final static icon (`\U000F013E`).

### Right Prompt (`rprompt`)
The right side of your prompt displays:
1.  **Execution Time:** The duration of the last command.
2.  **Shell:** The name of the current shell (e.g., `zsh`).
3.  **Battery:** Battery status icon and percentage.
4.  **Time:** The current date and time.
5.  **Upgrade:** An indicator if an Oh My Posh upgrade is available.

### Tooltips
Tooltips appear when you type certain commands:
- **`gcloud` / `gc`:** Shows GCP project, account, and region.
- **`az`:** Shows Azure environment and user.
- **`kubectl` / `kub`:** Shows Kubernetes context, namespace, and cluster.
- **`cd`:** Shows the full, non-shortened path.
