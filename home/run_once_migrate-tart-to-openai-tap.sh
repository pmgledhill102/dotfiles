#!/bin/sh
# One-time migration: move tart off the retired 'cirruslabs/cli' tap. The
# Brewfile now installs 'openai/tools/tart', and Homebrew 7 can no longer load
# the cirruslabs formulae at all (their 'depends_on macos:' form is disabled),
# so a machine still on them can't upgrade tart and trips 'brew bundle'.
# brew bundle never removes a tap the Brewfile stopped declaring, hence this.
#
# Runs exactly once per machine via chezmoi's run_once_ prefix.
# Idempotent: no-op on Linux, fresh installs, or already-migrated machines.
#
# After this script removes the cirruslabs formulae and tap, the next 'brewup'
# run installs tart from openai/tools via the updated Brewfile.

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

# --full-name reports the tap each keg was installed from, and reads the keg
# rather than the formula file, so it still works while the tap is unloadable.
# Only tart and its softnet dependency are ours to remove; anything else from
# the tap was installed by hand and is left, along with the tap it needs.
installed=$(brew list --formula --full-name |
  grep -x -e 'cirruslabs/cli/tart' -e 'cirruslabs/cli/softnet' || true)

if [ -n "$installed" ]; then
  echo "==> Removing tart from the retired cirruslabs/cli tap (replaced by openai/tools/tart in Brewfile)..."
  # Uninstall by bare keg name, never 'cirruslabs/cli/tart': Formulary.to_rack
  # evaluates the formula file for any name containing '/', which raises the
  # very error this migration exists to get past. A bare name resolves straight
  # to its Cellar rack without loading anything. See dotfiles#424.
  # shellcheck disable=SC2046,SC2086  # one formula name per word, intentionally split
  brew uninstall --ignore-dependencies $(printf '%s\n' "$installed" | sed 's|^cirruslabs/cli/||')
fi

if brew tap | grep -qx 'cirruslabs/cli' &&
  ! brew list --formula --full-name | grep -q '^cirruslabs/cli/'; then
  echo "==> Untapping cirruslabs/cli..."
  # The tap also carries a cask; if one is installed, untap refuses. Leaving a
  # dead tap behind is harmless, failing the whole chezmoi apply is not.
  brew untap cirruslabs/cli ||
    echo "==> Warning: could not untap cirruslabs/cli; remove it by hand with 'brew untap cirruslabs/cli'."
fi

if [ -n "$installed" ]; then
  echo "==> Done. Run 'brewup' to install tart from openai/tools."
fi
