#!/bin/sh

# Exit on error
set -e

# Set default branch name. The script is downloaded from a branch,
# so we can use that as the default.
DEFAULT_BRANCH="001-dotfiles-setup"
# Use the first argument as the branch name, or the default if not provided
BRANCH_NAME="${1:-$DEFAULT_BRANCH}"

# Define the chezmoi source directory
CHEZMOI_SOURCE_DIR="$HOME/.local/share/chezmoi"

# Check if the chezmoi source directory exists and remove it
if [ -d "$CHEZMOI_SOURCE_DIR" ]; then
  echo "Removing existing chezmoi source directory: $CHEZMOI_SOURCE_DIR"
  rm -rf "$CHEZMOI_SOURCE_DIR"
fi

# Run the chezmoi installation
echo "Running chezmoi installation from branch: $BRANCH_NAME"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply --branch "$BRANCH_NAME" https://github.com/pmgledhill102/dotfiles.git

echo "Installation complete!"
