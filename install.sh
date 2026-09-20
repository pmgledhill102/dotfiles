#!/bin/sh

# Bootstrap and install dotfiles on a fresh machine.
# Handles macOS (Xcode CLT + Homebrew), Linux (git + curl), then chezmoi.
#
# Usage:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)"
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/.../install.sh)" -- feature-branch
#
# Non-interactive (no tty, nothing to answer) — name the machine type up front:
#   DOTFILES_MACHINE_TYPE=cloud-agent sh -c "$(curl -fsSL .../install.sh)"
#   sh -c "$(curl -fsSL .../install.sh)" -- --machine-type cloud-agent
#   sh -c "$(curl -fsSL .../install.sh)" -- feature-branch --machine-type cloud-agent
#
# Given a machine type, this script writes it into
# ~/.config/chezmoi/chezmoi.toml before `chezmoi init`, and leaves that
# directory alone rather than wiping it.
#
# That pre-seed is the only thing that answers the prompt. chezmoi's
# --promptChoice flag does NOT work with promptChoiceOnce, which is what
# home/.chezmoi.toml.tmpl uses: passing --promptChoice machine_type=... on the
# init line is accepted, ignored, and init then blocks on the prompt anyway.
# CI pre-seeds for the same reason (.github/workflows/ci.yml).
#
# With no machine type, behaviour is exactly as before: the config directory is
# wiped so that init re-prompts, which is what an interactive re-install wants.
#
# Environment:
#   DOTFILES_MACHINE_TYPE       personal | work | minimal | cloud-agent
#   DOTFILES_BOOTSTRAP_DRY_RUN  1 = do the prerequisites and the pre-seed, then
#                               stop before fetching and running chezmoi. Used
#                               by CI to assert the pre-seed without also
#                               installing from the remote default branch.

set -e

DEFAULT_BRANCH="main"
BRANCH_NAME=""
MACHINE_TYPE="${DOTFILES_MACHINE_TYPE:-}"
CHEZMOI_SOURCE_DIR="$HOME/.local/share/chezmoi"
CHEZMOI_CONFIG_DIR="$HOME/.config/chezmoi"

usage() {
  echo "Usage: install.sh [branch] [--machine-type personal|work|minimal|cloud-agent]"
}

# Run a command with escalation only where escalation is actually needed. An
# ephemeral agent sandbox usually runs as root with no sudo binary installed at
# all, so `sudo` is resolved rather than assumed (dotfiles#426).
asroot() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "Error: need root or sudo to run: $*" >&2
    return 1
  fi
}

# The historical positional argument is a branch name, and the documented
# "-- feature-branch" form has to keep working, so the machine type is a named
# flag (or an environment variable) rather than a second positional.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --machine-type=*)
      MACHINE_TYPE="${1#*=}"
      ;;
    --machine-type)
      if [ "$#" -lt 2 ]; then
        echo "Error: --machine-type requires a value" >&2
        usage >&2
        exit 2
      fi
      MACHINE_TYPE="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      BRANCH_NAME="$1"
      ;;
  esac
  shift
done

BRANCH_NAME="${BRANCH_NAME:-$DEFAULT_BRANCH}"

case "$MACHINE_TYPE" in
  ""|personal|work|minimal|cloud-agent) ;;
  *)
    echo "Error: unknown machine type: $MACHINE_TYPE" >&2
    echo "Valid values: personal, work, minimal, cloud-agent" >&2
    exit 2
    ;;
esac

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

    # Install Rosetta 2 on Apple Silicon (required by many Intel-based apps)
    if [ "$(uname -m)" = "arm64" ] && ! /usr/bin/pgrep -q oahd; then
      echo "Installing Rosetta 2..."
      softwareupdate --install-rosetta --agree-to-license
    fi
    echo "Rosetta 2: OK"
    ;;

  Linux*)
    echo "Linux detected"
    # Ensure minimum prerequisites are available
    MISSING=""
    command -v git  >/dev/null 2>&1 || MISSING="$MISSING git"
    command -v curl >/dev/null 2>&1 || MISSING="$MISSING curl"
    if [ -n "$MISSING" ]; then
      echo "Installing missing prerequisites:$MISSING"
      if ! command -v apt-get >/dev/null 2>&1; then
        echo "Error: apt-get not found. Install these by hand, then re-run:$MISSING" >&2
        exit 1
      fi
      export DEBIAN_FRONTEND=noninteractive
      asroot apt-get update
      # shellcheck disable=SC2086
      asroot apt-get install -y $MISSING
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

# The wipe and the pre-seed are mutually exclusive by construction: wiping the
# directory would delete the file the pre-seed writes into it.
if [ -n "$MACHINE_TYPE" ]; then
  echo "Pre-seeding machine_type=$MACHINE_TYPE (non-interactive install)"
  mkdir -p "$CHEZMOI_CONFIG_DIR"
  printf '[data]\n    machine_type = "%s"\n' "$MACHINE_TYPE" > "$CHEZMOI_CONFIG_DIR/chezmoi.toml"
elif [ -d "$CHEZMOI_CONFIG_DIR" ]; then
  echo "Removing existing chezmoi config: $CHEZMOI_CONFIG_DIR"
  rm -rf "$CHEZMOI_CONFIG_DIR"
fi

# --- Install chezmoi and apply dotfiles ---
echo "Running chezmoi installation from branch: $BRANCH_NAME"
if [ "${DOTFILES_BOOTSTRAP_DRY_RUN:-}" = "1" ]; then
  echo "DOTFILES_BOOTSTRAP_DRY_RUN=1 — stopping before: chezmoi init --apply --branch $BRANCH_NAME"
  exit 0
fi
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply --branch "$BRANCH_NAME" https://github.com/pmgledhill102/dotfiles.git

echo "Installation complete!"

# Print summary of installed custom shell functions, if any were deployed.
# Sources them in a clean zsh subshell (install.sh is POSIX sh) and invokes
# 'dotfuncs' to produce the list. Fail-safe — never blocks install.
if command -v zsh >/dev/null 2>&1 && [ -d "$HOME/.config/zsh/functions" ]; then
  echo ""
  zsh -c '
    for f in "$HOME/.config/zsh/functions"/*.zsh; do
      [ -f "$f" ] && source "$f"
    done
    command -v dotfuncs >/dev/null 2>&1 && dotfuncs
  ' 2>/dev/null || true
fi
