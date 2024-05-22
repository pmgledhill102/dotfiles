#!/usr/bin/env zsh

CURRENT_OS=$(uname)

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

CLEAR='\033[0m'

script_exit_code=0
passed=0
failed=0

if [[ "$(uname)" == "Darwin" ]]; then
  HOMEBREW_PATH_DIR="/opt/homebrew/bin"
else
  HOMEBREW_PATH_DIR="/home/linuxbrew/.linuxbrew/bin"
fi

@verify_binary() {
  if [ -x "$(which "$1")" ]; then
      passed=$(( passed + 1 ))
      echo -e "${GREEN}PASS:${CLEAR} $1 exists and is on PATH"
  else
      failed=$(( failed + 1 ))
      echo -e "${RED}FAIL:${CLEAR} $1 does not exist or is not on PATH"
      script_exit_code=1
  fi
}

@verify_directory() {
  if [ -d "$1" ]; then
    passed=$(( passed + 1 ))
    echo -e "${GREEN}PASS:${CLEAR} $1 is a valid directory"
  else
    failed=$(( failed + 1 ))
    echo -e "${RED}FAIL:${CLEAR} $1 is not a valid directory"
    script_exit_code=1
  fi
}

@verify_file() {
  if [ -f "$1" ]; then
    passed=$(( passed + 1 ))
    echo -e "${GREEN}PASS:${CLEAR} $1 is a valid file"
  else
    failed=$(( failed + 1 ))
    echo -e "${RED}FAIL:${CLEAR} $1 is not a valid file"
    script_exit_code=1
  fi
}

@verify_environment_variable() {
  if [[ -v $1 ]]; then
    passed=$(( passed + 1 ))
    echo -e "${GREEN}PASS:${CLEAR} $1 is a valid environment variable"
  else
    failed=$(( failed + 1 ))
    echo -e "${RED}FAIL:${CLEAR} $1 is not an valid environment variable"
    script_exit_code=1
  fi
}

@verify_on_path() {
  if [[ ":$PATH:" == *":$1:"* ]]; then
    passed=$(( passed + 1 ))
    echo -e "${GREEN}PASS:${CLEAR} $1 is configured on path"
  else
    failed=$(( failed + 1 ))
    echo -e "${RED}FAIL:${CLEAR} $1 is not configured on path"
    script_exit_code=1
  fi
}

@verify_symlink() {
  if [[ "$(readlink $1)" == "$2" ]]; then
    passed=$(( passed + 1 ))
    echo -e "${GREEN}PASS:${CLEAR} $1 is a valid symlink"
  else
    failed=$(( failed + 1 ))
    echo -e "${RED}FAIL:${CLEAR} $1 is an invalid symlink"
    script_exit_code=1
  fi
}

@show_results() {
  local total=$((passed + failed))
  echo "Executed: ${total}, Passed: ${passed}, Failed: ${failed}"
  exit $script_exit_code
}

@display_banner() {
  echo -e "${CLEAR}";
  echo -e '\033[0;31m ____        _    __ _ _           ';
  echo -e '\033[0;31m|  _ \  ___ | |_ / _(_) | ___  ___ ';
  echo -e '\033[0;31m| | | |/ _ \| __| |_| | |/ _ \/ __|';
  echo -e '\033[0;31m| |_| | (_) | |_|  _| | |  __/\__ \';
  echo -e '\033[0;31m|____/ \___/ \__|_| |_|_|\___||___/';
  echo -e "${CLEAR}";
}

@verify_macos () {
  @verify_binary aws
  @verify_binary python3
  @verify_binary bat
  @verify_binary az
  @verify_binary fzf
  @verify_binary git
  @verify_binary go
  @verify_binary task
  @verify_binary gradle
  @verify_binary gum
  @verify_binary java
  @verify_binary helm
  @verify_binary jenv
  @verify_binary jq
  @verify_binary kubectl
  @verify_binary mvn
  @verify_binary openssl
  @verify_binary sam
  @verify_binary terraform
  @verify_binary oh-my-posh

  @verify_directory ~/.dotfiles

  @verify_file ~/.zshrc
  @verify_file ~/.hushlogin

  @verify_environment_variable LANG
  @verify_environment_variable LC_ALL
  @verify_environment_variable HOMEBREW_NO_ANALYTICS
  @verify_environment_variable SAM_CLI_TELEMETRY
  @verify_environment_variable DOTNET_CLI_TELEMETRY_OPTOUT
  @verify_environment_variable PYTHONIOENCODING
  @verify_environment_variable HISTCONTROL
  @verify_environment_variable HOME
  @verify_environment_variable DOTFILES_DIR

  @verify_on_path $HOMEBREW_PATH_DIR

  @verify_symlink ~/.hushlogin .dotfiles/zsh/.hushlogin
  @verify_symlink ~/.zshrc .dotfiles/zsh/.zshrc
  @verify_symlink ~/Brewfile .dotfiles/brew/Brewfile
}

@verify_ubuntu () {
  @verify_binary git
  @verify_binary jq
  @verify_binary openssl
  @verify_binary zip
  @verify_binary unzip
  @verify_binary wget
  @verify_binary zsh
  @verify_binary stow

  #@verify_binary oh-my-posh

  @verify_directory ~/.dotfiles

  @verify_file ~/.bashrc
  @verify_file ~/.nanorc
  @verify_file ~/.nano/go.nanorc

  @verify_environment_variable PYTHONIOENCODING
  @verify_environment_variable HISTCONTROL
  @verify_environment_variable HOME
  @verify_environment_variable DOTFILES_DIR

}

@display_banner

if [[ "${CURRENT_OS}" == "Darwin" ]]; then
  @verify_macos "$@"
else
  @verify_ubuntu "$@"
fi

@show_results