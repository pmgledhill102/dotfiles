# Paul Gledhill's Dot Files

## TO DO

- Which of these are mine, versus work laptop?
- iTerm => MacOS Terminal settings
- (think there's a fair bit on MacOS settings)

## Install

```sh
bash -c "`curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh`"
```

## Overview

Welcome to my dotfiles repository! This repository contains personal configuration files (often
referred to as dotfiles because they typically start with a dot, like .zshrc or .vimrc) that I
use to personalize and customize my development environment. These dotfiles are managed using
GNU Stow which is downloaded as part of the install.sh script.

I'm looking to support:

- Ubuntu
- MacOS

## Thanks Shivam Khattar

Idea stolen from the absolutely wonderful Shivam Khattar ([@iamkhattar](https://github.com/iamkhattar)).
Many thanks for your endless energy!

## Scope

- Quick installer scripts:
  - Apple Mac - developer
  - Windows - developer
  - Ubuntu - lightweight install (small time, small size)
  - Ubuntu - full install (dev box/WSL)
- Terminal Prompts
  - Windows Terminal:
    - Powershell
    - WSL Bash
  - VS Code Terminal with Powershell
  - Bash on Ubuntu
  - Aliases within Prompts
  - Nerd Fonts
- WSL
  - Disable IP6
  - Disable using Windows Paths (the `gcloud` problem)
  - Change default folder to ~
- Windows Terminal Settings
- Nano Language Support
- Ubuntu core utils

Note: Ubuntu Minimal not supported (lacks git, nano, apt-utils, ...)

## Oh My Posh

I decided to embrace [Oh My Posh](https://ohmyposh.dev/) to provide terminal customisations. Although
not as configurable as [PowerLevel10k](https://github.com/romkatv/powerlevel10k), it is not limited to
`zsh`, it can work across `bash`, `cmd`, `powershell` and `zsh` running on `Windows`, `Linux` or
`MacOS`.

```cmd
winget install JanDeDobbeleer.OhMyPosh -s winget
```

### Fonts

All modern prompts are designed to work best with a ["Nerd Font"](https://www.nerdfonts.com/) (fonts
patched to include icons). I've gone for the [Jet Brains Mono](https://www.jetbrains.com/lp/mono/) Nerd
Font, as it was designed specifically for code so looks great and is easy to install on Windows.

```cmd
winget install --id="DEVCOM.JetBrainsMonoNerdFont" --exact
```

### Windows Terminal

`C:\Users\messe\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`

```json
"defaultProfile": "{7c665dc7-9f17-41f5-b5b1-20d9a46fd961}",
```

```json
{
    "colorScheme": "Campbell",
    "commandline": "\"C:\\Program Files\\PowerShell\\7\\pwsh.exe\"",
    "font": 
    {
        "face": "JetBrainsMonoNL NFP"
    },
    "guid": "{7c665dc7-9f17-41f5-b5b1-20d9a46fd961}",
    "hidden": false,
    "icon": "ms-appx:///ProfileIcons/pwsh.png",
    "name": "Dev",
    "startingDirectory": "c:\\dev"
}
```

### Power Shell

`$PROFILE = "C:\Users\messe\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"`

`oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/ohmyposh/theme.json' | Invoke-Expression`

### VSCode Terminal

``` json
"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font",
```

On MacOS location of settings is `$HOME/Library/Application Support/Code/User/settings.json`

```sh
brew install tidwall/jj/jj

jj -v "JetBrainsMono Nerd Font" -p -i "$HOME/Library/Application Support/Code/User/settings.json" -o "$HOME/Library/Application Support/Code/User/settings.json" "terminal\.integrated\.fontFamily"

# OR...

tmp=$(mktemp)
jq '.["terminal.integrated.fontFamily"] = "JetBrainsMono Nerd Font"' "$HOME/Library/Application Support/Code/User/settings.json" > "$tmp"
mv "$tmp" "$HOME/Library/Application Support/Code/User/settings.json"



```

### Ubuntu

```sh
# Install to $HOME/bin folder
curl -s https://ohmyposh.dev/install.sh | bash -s -- -d $HOME/bin
```

Add this to ~/.bashrc ...

```sh
# Oh My Posh
export PATH="$PATH:$HOME/bin"
eval "$(oh-my-posh init bash --config 'https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/ohmyposh/theme.json')"
```

### MacOS

```sh
brew install jandedobbeleer/oh-my-posh/oh-my-posh

brew install --cask font-jetbrains-mono-nerd-font
```

Add to the `.zshrc` file:

```sh
eval "$(oh-my-posh init zsh)"
```

And install iTerm2:

```sh
brew install --cask iterm2
```

```sh
# Configure iterm2 to use the file from this repo for it's settings, this includes
# the changes to default font

defaults write com.googlecode.iterm2 PrefsCustomFolder -string "~/dev/dotfiles/iterm"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
```

### Lean  Focus

When installed to Ubuntu servers, I want the footprint to be kept to a minimum, as I'll be
charged for the storage. This is a major reason to avoid `homebrew`. To enforce this over time
I've included a 100MB check into the GitHub workflow.

### Brew before I started

Here's my Mac brew list before I started to automate installs

```sh
> brew list
> brew tap
```

Formulae

- autoconf
- brotli
- c-ares
- ca-certificates
- cairo
- fontconfig
- freetype
- gcc
- gettext
- gh
- giflib
- git
- glib
- gmp
- go
- gradle
- graphite2
- grep
- harfbuzz
- icu4c
- isl
- jj
- jpeg-turbo
- kind
- kn
- kubernetes-cli
- libmpc
- libnghttp2
- libpng
- libtiff
- libuv
- libx11
- libxau
- libxcb
- libxdmcp
- libxext
- libxrender
- little-cms2
- lz4
- lzo
- m4
- maven
- mpdecimal
- mpfr
- node
- nvm
- oh-my-posh
- openjdk
- openjdk@17
- openssl@3
- pack
- pandoc
- pcre2
- pixman
- pkg-config
- pyenv
- quarkus
- readline
- rustup-init
- sqlite
- tfenv
- xorgproto
- xz
- zstd

Casks
- discord
- font-jetbrains-mono-nerd-font
- google-cloud-sdk
- insomnia
- inspec
- intellij-idea-ce
- iterm2
- utm
- visual-studio-code

Taps
- buildpacks/tap
- chef/chef
- jandedobbeleer/oh-my-posh
- knative/client
- quarkusio/tap
- tidwall/jj

### Interesting Links

Here are a few links to apps used, or articles related to dotfiles:

- [GNU Stow](https://www.gnu.org/software/stow/) - Symlink manager
- [Using GNU Stow to manage your dotfiles](https://brandon.invergo.net/news/2012-05-26-using-gnu-stow-to-manage-your-dotfiles.html)
- [Awesome Linux shell on Windows: WSL, Windows Terminal, ZSH, oh-my-zsh, and powerlevel10k](https://gist.github.com/RalfG/19dfb8b51dd681abbae22af966c57ced)
- [Scott Hanselman : My Ultimate PowerShell prompt with Oh My Posh and the Windows Terminal](https://www.hanselman.com/blog/my-ultimate-powershell-prompt-with-oh-my-posh-and-the-windows-terminal)
