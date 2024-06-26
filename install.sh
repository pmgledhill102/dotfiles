#!/bin/bash

CURRENT_OS=$(uname)

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

CLEAR='\033[0m'

set -e

function display_banner() {
  echo -e "${CLEAR}";
  echo -e "$RED ____        _    __ _ _           ";
  echo -e "$RED|  _ \  ___ | |_ / _(_) | ___  ___ ";
  echo -e "$RED| | | |/ _ \| __| |_| | |/ _ \/ __|";
  echo -e "$RED| |_| | (_) | |_|  _| | |  __/\__ \\";
  echo -e "$RED|____/ \\___/ \__|_| |_|_|\\___||___/";
  echo -e "$RED ";
  echo -e "$BLUE     ----- $1 -----";
  echo -e "${CLEAR}";
}

function clone_dotfiles() {
  if [ ! -d $HOME/.dotfiles ]; then
    echo -e "${GREEN}INFO:${CLEAR} Cloning dotfiles to $HOME/.dotfiles (${GITHUB_HEAD_REF:-main})";
    git clone https://github.com/pmgledhill102/dotfiles.git --branch ${GITHUB_HEAD_REF:-main} --single-branch $HOME/.dotfiles;
  else
    echo -e "${GREEN}INFO:${CLEAR} Dotfiles already cloned. Pulling latest changes";
    git -C $HOME/.dotfiles pull > /dev/null;
  fi
}

function install_brew() {
  if test ! $(which brew); then
    echo -e "${GREEN}INFO:${CLEAR} Brew not found, installing using install script"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ "${CURRENT_OS}" == "Darwin" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
  fi
}

function install_dependencies_using_brew() {
  echo -e "${GREEN}INFO:${CLEAR} Installing dependencies from $HOME/.dotfiles/brew/Brewfile"
  brew analytics off
  brew update
  brew tap homebrew/bundle
  brew bundle install --file=$HOME/.dotfiles/brew/Brewfile
  brew cleanup
}

function install_oh_my_posh() {
  # Install to $HOME/bin folder
  mkdir -p $HOME/bin
  echo -e "${GREEN}INFO:${CLEAR} Installing Oh My Posh, installing using install script"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d $HOME/bin
}

function create_directories() {
  echo -e "${GREEN}INFO:${CLEAR} Creating directories in $HOME/dev"
  mkdir -p $HOME/dev
  mkdir -p $HOME/dev/personal
  mkdir -p $HOME/dev/work
  mkdir -p $HOME/dev/scratch
}

function install_powershell() {
  # exit if already installed
  if (pwsh --version &>/dev/null); then echo -e " $GREEN - powershell is installed $CLEAR"; return; fi

  # Get Ubuntu source version
  source /etc/os-release
  tmpDir=$(mktemp -d)

  ###################################
    # HACK for 24.04 until they fix it
    if [[ "$VERSION_ID" == "24.04" ]]; then
      echo -e "$GREEN - Installing powershell 24.04 HACK (libicu72) $CLEAR"
      curl -sSL 'https://launchpad.net/ubuntu/+archive/primary/+files/libicu72_72.1-3ubuntu3_amd64.deb' -o "$tmpDir/libicu72_72.1-3ubuntu3_amd64.deb"
      sudo dpkg -i "$tmpDir"/libicu72_72.1-3ubuntu3_amd64.deb
    fi
  ###################################

  ## Using apt with the Microsoft repository adds too much size (200Mb), so using direct installer
  echo -e "$GREEN - Installing powershell (direct .deb) $CLEAR"
  downloadUrl=$(curl -sSL "https://api.github.com/repos/PowerShell/PowerShell/releases/latest" |
    jq -r '[.assets[] | select(.name | endswith("_amd64.deb")) | .browser_download_url][0]')
  curl -sSL "$downloadUrl" -o "$tmpDir/powershell.deb"
  sudo dpkg -i "$tmpDir"/powershell.deb
  rm -rf "$tmpDir"
}

function stow_dotfiles() {
  echo -e "${GREEN}INFO:${CLEAR} Stowing dotfiles"
  rm -rf ~/.zshrc
  rm -rf ~/.zprofile
  rm -rf ~/.bashrc
  rm -rf ~/.bash_profile
  cd $HOME/.dotfiles
  stow bash
  stow zsh
  stow powershell
}

function stow_dotfiles_macos() {
  stow_dotfiles

  echo -e "${GREEN}INFO:${CLEAR} Stowing Mac Only dotfiles"

  cd $HOME/.dotfiles
  #stow iterm
  
  stow brew
  stow zsh
  stow powershell
}

function install_apt_packages() {
  echo -e "${GREEN}INFO:${CLEAR} Checking required packages"

  # Check to see if packages are installed
  INSTALLS_REQUIRED=0
  for i in $(cat $HOME/.dotfiles/apt/pkglist);
    do if dpkg -s $i &>/dev/null; then echo -e " $GREEN - $i is installed $CLEAR";
    else echo -e "$RED - $i is not installed $CLEAR"; INSTALLS_REQUIRED=1; fi;
  done

  # Exit early if they are
  if [[ "$INSTALLS_REQUIRED" -eq 0 ]]; then
    echo -e "${GREEN}INFO:${CLEAR} Packages already installed"
    return
  fi

  # Elevate prvivileges if required
  if [[ $EUID -ne 0 && $INSTALLS_REQUIRED -eq 1 ]]; then
    echo -e "$RED (this script must be run as root to install packages) $CLEAR"
    sudo echo "== Elevated =="
  fi

  # Remove need to restart services
  sudo apt-get -y remove needrestart

  # Update and upgrade APT packages
  echo -e "${GREEN}INFO:${CLEAR} Updating APT package list"
  sudo apt-get update > /dev/null

  # Upgrade all packages
  echo -e "${GREEN}INFO:${CLEAR} Upgrading all APT packages"
  sudo apt-get upgrade -y > /dev/null

  # Install required packages
  echo -e "${GREEN}INFO:${CLEAR} Installing required APT packages"
  for i in $(cat $HOME/.dotfiles/apt/pkglist);
    do echo -e "$GREEN - Installing $i $CLEAR"
    sudo apt-get install $i -y > /dev/null
  done
}

function install_nanorc_highlighting() {
  echo -e "${GREEN}INFO:${CLEAR} Installing Nano syntax highlighting"

  wget -q -O /tmp/nanorc.sh https://raw.githubusercontent.com/scopatz/nanorc/master/install.sh
  sed -i -e 's/wget -O/wget -q -O/g' /tmp/nanorc.sh
  /bin/bash -c "$(cat /tmp/nanorc.sh)" > /dev/null
}

function configure_wsl() {
  # Check if running in WSL
  if [ -z "${WSL_DISTRO_NAME}" ]; then
      return
  fi

  # Running as WSL
  echo -e "${GREEN}INFO:${CLEAR} Windows Subsystem for Linux (WSL) detected"

  # Check if the current user is root
  if [ "$(id -u)" -ne 0 ]; then
    return
  fi

  # Running as default root user in WSL
  echo -e "${RED}INFO:${CLEAR} Default Root User Detected, creating new user"
  NEW_USER=pmg102

  # Install sudo
  sudo apt update > /dev/null
  sudo apt install -y sudo > /dev/null

  # Add user, and add to sudo group
  sudo adduser --gecos "" $NEW_USER
  sudo usermod -aG sudo $NEW_USER

  # Make $NEW_USER the default user
  echo "[user]" >> /etc/wsl.conf
  echo "default=$NEW_USER" >> /etc/wsl.conf

  # Allow $NEW_USER to run echo and apt-get as sudo without password
  # echo "$NEW_USER ALL=(ALL) NOPASSWD: /bin/echo" > /etc/sudoers.d/010_$NEW_USER-nopasswd
  # echo "$NEW_USER ALL=(ALL) NOPASSWD: /usr/bin/apt-get" >> /etc/sudoers.d/010_$NEW_USER-nopasswd

  echo -e "${GREEN}INFO:${CLEAR} New User Created '$NEW_USER' switching context. Re-run install"

  # Rerunning  as new user
  sudo -u $NEW_USER "curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/dev/install.sh | bash"

  #su - $NEW_USER -c "curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/dev/install.sh | bash"

  # Exit
  exit
}

function main_macos() {
  display_banner "MacOS Edition"
  clone_dotfiles
  create_directories
  install_brew
  install_dependencies_using_brew
  install_nanorc_highlighting
  stow_dotfiles_macos
}

function main_ubuntu() {
  display_banner "Ubuntu Edition"
  configure_wsl
  clone_dotfiles
  create_directories
  install_apt_packages
  install_powershell
  install_oh_my_posh
  install_nanorc_highlighting
  stow_dotfiles
}

if [ "${CURRENT_OS}" == "Darwin" ]; then
  main_macos  "$@"
else
  main_ubuntu "$@"
fi

# Execute bash profile scripts
source $HOME/.bash_profile
source $HOME/.bashrc
