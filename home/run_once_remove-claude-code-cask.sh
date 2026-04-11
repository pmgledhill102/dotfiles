#!/bin/sh
# One-time migration: remove the legacy 'claude-code' brew cask in favour of
# 'claude-code@latest'. The Brewfile now references the @latest variant which
# tracks upstream's latest release channel directly. Both casks install the
# same /opt/homebrew/bin/claude binary, so they conflict if both are installed.
#
# Runs exactly once per machine via chezmoi's run_once_ prefix.
# Idempotent: no-op on Linux, fresh installs, or already-migrated machines.
#
# After this script removes the legacy cask, the next 'dotbrew' run will
# install 'claude-code@latest' from the updated Brewfile.

set -eu

case "$(uname -s)" in
  Darwin*) ;;
  *) exit 0 ;;
esac

# Ensure brew is in PATH (chezmoi scripts do not source ~/.zshrc)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command -v brew >/dev/null 2>&1; then
  exit 0
fi

if brew list --cask claude-code >/dev/null 2>&1; then
  echo "==> Removing legacy 'claude-code' cask (replaced by 'claude-code@latest' in Brewfile)..."
  brew uninstall --cask claude-code
  echo "==> Done. Run 'dotbrew' to install claude-code@latest from the updated Brewfile."
fi
