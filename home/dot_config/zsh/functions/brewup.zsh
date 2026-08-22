#!/bin/zsh
# shellcheck shell=bash
# Update Homebrew + Brewfile, then any non-brew package managers (rustup)

# Homebrew has no env var to silence these: they're printed unconditionally
# via opoo (stderr) for anyone not in HOMEBREW_DEVELOPER mode, and upstream
# taps (e.g. cirruslabs/homebrew-cli) own the fix, not us. Drop the specific
# warning paragraphs (up to the next blank line); everything else, including
# real errors, passes through untouched. BREWUP_SHOW_WARNINGS=1 disables this.
_brewup_filter_noise() {
  if [ "$BREWUP_SHOW_WARNINGS" = "1" ]; then
    cat
    return
  fi
  awk '
    /^Warning: Calling `.*`.*(is deprecated|is disabled)!/ { skip = 1; next }
    /^Warning: Formulae dependency graph sorting found a circular dependency:/ { skip = 1; next }
    skip && NF == 0 { skip = 0; next }
    skip { next }
    { print }
  '
}

# Casks that ship their own updater declare `auto_updates` upstream, and their
# uninstall stanza names the launchd service that does it — Squirrel's
# "<bundle-id>.ShipIt" for discord, visual-studio-code, chatgpt and friends.
# Homebrew tears that service down as part of an upgrade, probing both the user
# AND the root launchd domain, and the root probe runs under sudo. So the very
# thing that makes these apps self-updating is what makes `brew upgrade --cask`
# stop dead on a password prompt, which defeats the point of brewup.
#
# Homebrew 6 compares the on-disk app bundle version for these casks, so one
# that has already self-updated is skipped silently; it's the ones you haven't
# launched in a while that hit the sudo path. Upgrading those is redundant as
# well as blocking — the app updates itself next time it starts. Leave them be.
# BREWUP_UPGRADE_SELF_UPDATING=1 upgrades them anyway.
_brewup_upgrade_casks() {
  local outdated wanted skipped cask
  # Errors are suppressed rather than handled: --cask is a no-op on Linux.
  outdated=$(brew outdated --cask --quiet 2>/dev/null)
  [ -n "$outdated" ] || return 0

  wanted=""
  skipped=""
  while IFS= read -r cask; do
    [ -n "$cask" ] || continue
    if [ "$BREWUP_UPGRADE_SELF_UPDATING" != "1" ] &&
      brew info --cask --json=v2 "$cask" 2>/dev/null |
      grep -qE '"auto_updates":[[:space:]]*true'; then
      skipped="${skipped:+$skipped }$cask"
    else
      wanted="${wanted:+$wanted }$cask"
    fi
  done <<<"$outdated"

  if [ -n "$skipped" ]; then
    echo "Self-updating casks left to their own updaters: $skipped"
  fi

  # xargs, not an unquoted splat: zsh doesn't word-split unquoted parameters,
  # and ${=wanted} would be zsh-only syntax in a shellcheck-as-bash file. Cask
  # tokens never contain whitespace, so splitting on it is safe. Guarded on
  # non-empty because bare `xargs brew upgrade --cask` would upgrade the lot.
  if [ -n "$wanted" ]; then
    printf '%s\n' "$wanted" |
      HOMEBREW_NO_ASK=1 xargs brew upgrade --cask 2> >(_brewup_filter_noise >&2)
  fi
}

brewup() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Error: Homebrew is not installed."
    return 1
  fi

  echo "==> Updating Homebrew..."
  brew update 2> >(_brewup_filter_noise >&2)

  local brewfile="$HOME/Brewfile"
  if [ -f "$brewfile" ]; then
    # Homebrew 6 refuses non-official-tap formulae/casks unless trusted via
    # 'brew trust'. Taps declared in the Brewfile are trusted by definition.
    # Guarded for older brews without the 'trust' command.
    if brew trust --help >/dev/null 2>&1; then
      grep '^tap "' "$brewfile" | awk -F'"' '{print $2}' | while read -r tap_name; do
        brew trust --tap "$tap_name" || true
      done
    fi
    printf "\n==> Installing packages from Brewfile...\n"
    # HOMEBREW_NO_ASK=1: Homebrew 6 defaults to ask-mode confirmation prompts;
    # brewup's whole point is unattended install/upgrade.
    # HOMEBREW_BUNDLE_JOBS=1: Homebrew 6's parallel installer (default 'auto')
    # has lock races on shared dependencies (Homebrew/brew#23328); sequential
    # is the pre-brew-6 behavior. Revisit: dotfiles#368.
    # --no-upgrade: this pass installs what's missing, nothing more. Upgrades
    # all happen below, where casks can be filtered — see dotfiles#393.
    HOMEBREW_NO_ASK=1 HOMEBREW_BUNDLE_JOBS=1 brew bundle install --no-upgrade --file "$brewfile" 2> >(_brewup_filter_noise >&2)
  else
    echo "Warning: Brewfile not found at $brewfile"
  fi

  printf "\n==> Upgrading installed packages...\n"
  HOMEBREW_NO_ASK=1 brew upgrade --formula 2> >(_brewup_filter_noise >&2)
  _brewup_upgrade_casks

  # Rust isn't in the Brewfile (rustup manages its own toolchain channel),
  # but it IS a package-manager update, which is brewup's remit. Belongs
  # here, not in dotup.
  if command -v rustup >/dev/null 2>&1; then
    if [ "$BREWUP_SKIP_RUST" = "1" ]; then
      printf "\n==> Skipping Rust toolchain update (BREWUP_SKIP_RUST=1)\n"
    else
      printf "\n==> Updating Rust toolchain...\n"
      # Pre-clean rustup's scratch dirs to avoid hours-long per-file cleanup
      # walks on EDR/AV-scanned machines. rustup recreates them as needed.
      rm -rf "$HOME/.rustup/tmp" "$HOME/.rustup/downloads"
      rustup update
    fi
  fi

  printf "\n==> Packages up to date.\n"
}
