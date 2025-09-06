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
