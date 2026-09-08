# Dotfiles Cheatsheet

Repo: <https://github.com/pmgledhill102/dotfiles>

## Quick Commands

```bash
dotup                 # Update dotfiles, brew, OMZ, plugins, and starship
dotstatus             # Show machine type, source path, pending changes
chezmoi diff          # Preview what would change
chezmoi apply -v      # Apply changes
chezmoi edit ~/.zshrc # Edit a managed file
chezmoi add ~/.foo    # Start managing a new file
```

On Windows, `dotup` exists in PowerShell and does the dotfiles half only —
`chezmoi update --refresh-externals`, config-drift recovery, profile reload.
There is deliberately no `wingetup`: package **upgrades** are UniGetUI's job,
because it spans winget, npm, pip, cargo and .NET tools rather than winget
alone. Package **installs** stay declarative here, in `.chezmoi.toml`. See
[#271](https://github.com/pmgledhill102/dotfiles/issues/271).

Full documentation: <https://github.com/pmgledhill102/dotfiles#readme>
