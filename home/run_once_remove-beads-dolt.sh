#!/bin/sh
# One-time cleanup: uninstall beads (bd) and dolt. Beads was retired as the
# task tracker on 2026-07-18 (ADR-0015) and both formulae have now left the
# Brewfile (#459). brewup only installs, so without this they would linger.
#
# Runs once per machine via chezmoi's run_once_ prefix. A no-op where Homebrew
# is absent or neither formula is installed. beads depends on dolt, so it is
# uninstalled first. --force removes every installed version: a plain uninstall
# takes only the linked one, and a leftover older beads then blocks dolt (#461).

set -eu

for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [ -x "$brew_bin" ]; then
    eval "$("$brew_bin" shellenv)"
    break
  fi
done

if ! command -v brew >/dev/null 2>&1; then
  exit 0
fi

for formula in beads dolt; do
  if brew list --formula "$formula" >/dev/null 2>&1; then
    echo "==> Removing '$formula' (retired, see ADR-0015)..."
    brew uninstall --force --formula "$formula" ||
      echo "Warning: could not uninstall $formula; run 'brew uninstall $formula'"
  fi
done
