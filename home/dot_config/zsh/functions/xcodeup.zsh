#!/bin/zsh
# shellcheck disable=SC1071
# Install/update Xcode via xcodes, select the toolchain, report simulator runtimes

xcodeup() {
  if [ "$(uname -s)" != "Darwin" ]; then
    echo "Error: xcodeup is macOS-only."
    return 1
  fi

  if ! command -v xcodes >/dev/null 2>&1; then
    echo "Error: xcodes not found — run 'brewup' first."
    return 1
  fi

  # Xcode downloads come from Apple and need an Apple ID + 2FA, so this
  # can never run unattended the way brewup does.
  if [ ! -t 0 ]; then
    echo "Error: xcodeup requires an interactive shell (Apple ID sign-in)."
    return 1
  fi

  if ! command -v aria2c >/dev/null 2>&1; then
    echo "Note: aria2 not installed — download will be 3-5x slower."
    echo "      'brewup' installs it from the Brewfile."
  fi

  echo "==> Currently installed Xcode versions:"
  xcodes installed || echo "  (none)"

  echo "\n==> Refreshing available version list..."
  xcodes update

  # xcodes no-ops if the latest release is already installed. --select points
  # xcode-select at it either way, which is the part that silently stays on
  # CommandLineTools otherwise.
  echo "\n==> Installing latest Xcode (prompts for Apple ID)..."
  if ! xcodes install --latest --select --experimental-unxip; then
    echo "Error: Xcode install failed."
    return 1
  fi

  echo "\n==> Active toolchain: $(xcode-select -p)"

  # A fresh Xcode ships with no simulator runtimes; they are a separate
  # multi-GB download. Report rather than auto-install — most work does
  # not need them and the download is large.
  local runtimes
  runtimes="$(xcrun simctl list runtimes 2>/dev/null | grep -c '^iOS\|^watchOS\|^tvOS\|^visionOS')"
  if [ "$runtimes" -eq 0 ]; then
    echo "\nNote: no simulator runtimes installed."
    echo "      Install one with: xcodes runtimes install \"iOS 26.5\""
    echo "      List available:   xcodes runtimes"
  else
    echo "\n==> ${runtimes} simulator runtime(s) installed."
  fi

  echo "\n==> Xcode up to date."
}
