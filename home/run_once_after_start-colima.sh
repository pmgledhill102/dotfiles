#!/bin/sh

# Start Colima now and at every login, so `docker` works without a manual
# `colima start` (ADR-0018). macOS only (see .chezmoiignore); a no-op where the
# Brewfile tier has no colima (minimal).
#
# Skipped in CI: GitHub's macOS runners have no nested virtualisation, so the
# VM cannot boot there. The validator checks the docker CLI instead.

set -e

if [ "${DOTFILES_SKIP_INSTALL:-}" = "1" ] || [ -n "${CI:-}" ]; then
  echo "CI / fast mode — not starting Colima"
  exit 0
fi

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if ! command -v colima >/dev/null 2>&1; then
  echo "Colima not installed on this tier — skipping"
  exit 0
fi

# brew services registers a launchd agent that runs `colima start` at login.
brew services start colima || echo "Warning: could not start Colima; run 'colima start' manually"
