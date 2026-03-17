#!/bin/sh

# Bootstrap and install dotfiles on a fresh machine.
# Handles macOS (Xcode CLT + Homebrew), Linux (git + curl), then chezmoi.
#
# Usage:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)"
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/.../install.sh)" -- feature-branch

set -e

DEFAULT_BRANCH="main"
BRANCH_NAME="${1:-$DEFAULT_BRANCH}"
CHEZMOI_SOURCE_DIR="$HOME/.local/share/chezmoi"

# --- Platform-specific prerequisites ---
case "$(uname -s)" in
  Darwin*)
    echo "macOS detected"

    # Install Xcode Command Line Tools if not present (provides git, clang, make)
    if ! xcode-select -p >/dev/null 2>&1; then
      echo "Installing Xcode Command Line Tools (this may take a few minutes)..."
      # Non-interactive CLT install via softwareupdate
      touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
      CLT_PACKAGE=$(softwareupdate -l 2>/dev/null \
        | grep -o '.*Command Line Tools.*' \
        | sort -V | tail -1 \
        | sed 's/^[* ]*//' | sed 's/ *$//')
      if [ -n "$CLT_PACKAGE" ]; then
        softwareupdate -i "$CLT_PACKAGE" --verbose
      else
        echo "Error: Could not find Command Line Tools in softwareupdate."
        echo "Please install manually: xcode-select --install"
        rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        exit 1
      fi
      rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    fi
    echo "Xcode Command Line Tools: OK"

    # Install Homebrew if not present (also validates CLT is working)
    if ! command -v brew >/dev/null 2>&1; then
      echo "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      # Add Homebrew to PATH for the remainder of this script
      if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [ -f /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi
    echo "Homebrew: OK"
    ;;

  Linux*)
    echo "Linux detected"
    # Ensure minimum prerequisites are available
    MISSING=""
    command -v git  >/dev/null 2>&1 || MISSING="$MISSING git"
    command -v curl >/dev/null 2>&1 || MISSING="$MISSING curl"
    if [ -n "$MISSING" ]; then
      echo "Installing missing prerequisites:$MISSING"
      sudo apt-get update
      # shellcheck disable=SC2086
      sudo apt-get install -y $MISSING
    fi
    echo "Prerequisites: OK"
    ;;
esac

# --- Clean existing chezmoi state ---
# Ensures init re-processes the config template (useful for re-installs)
if [ -d "$CHEZMOI_SOURCE_DIR" ]; then
  echo "Removing existing chezmoi source directory: $CHEZMOI_SOURCE_DIR"
  rm -rf "$CHEZMOI_SOURCE_DIR"
fi
if [ -d "$HOME/.config/chezmoi" ]; then
  echo "Removing existing chezmoi config: $HOME/.config/chezmoi"
  rm -rf "$HOME/.config/chezmoi"
fi

# --- Install chezmoi and apply dotfiles ---
echo "Running chezmoi installation from branch: $BRANCH_NAME"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply --branch "$BRANCH_NAME" https://github.com/pmgledhill102/dotfiles.git

echo "Installation complete!"
