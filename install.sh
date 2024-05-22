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
  # Install to ~/bin folder
  mkdir -p $HOME/bin
  echo -e "${GREEN}INFO:${CLEAR} Installing Oh My Posh, installing using install script"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/bin
}

function create_directories() {
  echo -e "${GREEN}INFO:${CLEAR} Creating directories in $HOME/dev"
  mkdir -p $HOME/dev
  mkdir -p $HOME/dev/personal
  mkdir -p $HOME/dev/work
  mkdir -p $HOME/dev/scratch
}

function stow_dotfiles() {
  echo -e "${GREEN}INFO:${CLEAR} Stowing dotfiles"
  rm -rf ~/.zshrc
  rm -rf ~/.zprofile
  rm -rf ~/.bashrc
  cd $HOME/.dotfiles
  stow bash
  stow zsh
}

function stow_dotfiles_macos() {
  stow_dotfiles

  echo -e "${GREEN}INFO:${CLEAR} Stowing Mac Only dotfiles"

  cd $HOME/.dotfiles
  #stow iterm
  stow brew
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

  # Update and upgrade APT packages
  echo -e "${GREEN}INFO:${CLEAR} Updating APT package list"
  sudo apt-get update > /dev/null

  # Upgrade all packages
  echo -e "${GREEN}INFO:${CLEAR} Upgrading all APT packages"
  sudo apt-get upgrade -y 1 > /dev/null

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
  clone_dotfiles
  create_directories
  install_apt_packages
  install_oh_my_posh
  install_nanorc_highlighting
  stow_dotfiles
}

if [ "${CURRENT_OS}" == "Darwin" ]; then
  main_macos "$@"
else
  main_ubuntu "$@"
fi
