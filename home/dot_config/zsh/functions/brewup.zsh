#!/bin/zsh
# shellcheck disable=SC1071
# Update Homebrew, install everything in your Brewfile, then upgrade

brewup() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Error: Homebrew is not installed."
    return 1
  fi

  echo "==> Updating Homebrew..."
  brew update

  local brewfile="$HOME/Brewfile"
  if [ -f "$brewfile" ]; then
    echo "\n==> Installing packages from Brewfile..."
    brew bundle install --file "$brewfile"
  else
    echo "Warning: Brewfile not found at $brewfile"
  fi

  echo "\n==> Upgrading installed packages..."
  brew upgrade

  echo "\n==> Homebrew packages up to date."
}
