# Powershell

## Install Powershell on Ubuntu

```sh
# 1. Update the package list
sudo apt update

# 2. Install prerequisites
sudo apt install -y wget apt-transport-https software-properties-common

# 3. Import the Microsoft GPG key
wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb

# 4. Register the Microsoft repository
sudo dpkg -i packages-microsoft-prod.deb

# 5. Update the package list again
sudo apt update

# 6. Install PowerShell
sudo apt install -y powershell
```

## Install Oh My Posh on top

```pwsh
sudo apt install unzip -y
curl -s https://ohmyposh.dev/install.sh | bash -s
```

and add this to $PROFILE (you may need to create the folder for this file)

```pwsh
$env:PATH += ":$HOME/.local/bin"
oh-my-posh init pwsh --config "https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/ohmyposh/theme.json" | Invoke-Expression
```
