#!/bin/zsh
# shellcheck shell=bash
# Install/update Xcode via xcodes, select the toolchain, download the iOS platform

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

  # 'xcodes update' dumps the entire catalogue (every Xcode back to 1.0) to
  # stdout. Only the refresh matters here; stderr stays open for real errors.
  printf "\n==> Refreshing available version list...\n"
  xcodes update >/dev/null

  # xcodes no-ops if the latest release is already installed. --select points
  # xcode-select at it either way, which is the part that silently stays on
  # CommandLineTools otherwise.
  printf "\n==> Installing latest Xcode (prompts for Apple ID)...\n"
  if ! xcodes install --latest --select --experimental-unxip; then
    echo "Error: Xcode install failed."
    return 1
  fi

  printf "\n==> Active toolchain: %s\n" "$(xcode-select -p)"

  # A fresh Xcode ships with no simulator runtimes; they are a separate
  # multi-GB download. xcodebuild no-ops when the platform is already
  # current, so this is safe to run on every invocation.
  printf "\n==> Downloading iOS platform (simulator runtime)...\n"
  if ! xcodebuild -downloadPlatform iOS; then
    echo "Warning: iOS platform download failed."
    echo "         Retry with: xcodebuild -downloadPlatform iOS"
  fi

  local runtimes
  runtimes="$(xcrun simctl list runtimes 2>/dev/null | grep -c '^iOS\|^watchOS\|^tvOS\|^visionOS')"
  printf "\n==> %s simulator runtime(s) installed.\n" "${runtimes}"

  printf "\n==> Xcode up to date.\n"
}
