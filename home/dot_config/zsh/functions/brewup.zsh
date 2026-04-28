#!/bin/zsh
# shellcheck disable=SC1071
# Update Homebrew + Brewfile, then any non-brew package managers (rustup)

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

  # Rust isn't in the Brewfile (rustup manages its own toolchain channel),
  # but it IS a package-manager update, which is brewup's remit. Belongs
  # here, not in dotup.
  if command -v rustup >/dev/null 2>&1; then
    echo "\n==> Updating Rust toolchain..."
    rustup update
  fi

  echo "\n==> Packages up to date."
}
