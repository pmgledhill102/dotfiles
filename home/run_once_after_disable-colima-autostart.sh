#!/bin/sh

# Colima is started on demand (`colima start` / `colima stop`), not at login
# (dotfiles#455). A Mac that applied the earlier run_once_after_start-colima
# registered it as a brew service, which boots the VM at every login; undo
# that here. `brew services stop` both stops the VM and unregisters the login
# agent. A Mac where the service was never registered is left untouched.
# macOS only (see .chezmoiignore).

set -e

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
else
  exit 0
fi

# Status column of `brew services list`: "none" when not registered.
status=$(brew services list 2>/dev/null | awk '$1 == "colima" { print $2 }')
if [ -n "$status" ] && [ "$status" != "none" ]; then
  echo "Removing Colima from login items (start it with 'colima start' when needed)..."
  brew services stop colima || echo "Warning: could not stop the colima service; run 'brew services stop colima'"
fi
