#!/bin/sh
# check-no-private-repos.sh — keep private-repo references out of this public repo.
#
# This repository is public by necessity (ADR-0014). Naming a private repo here
# publishes its existence permanently — git history included, so deleting the
# line later does not unpublish it.
#
# Deliberately an ALLOWLIST, not a denylist: a list of private repo names
# committed to a public repo would leak precisely the names it exists to
# protect. Anything owner-scoped that is not in scripts/public-repos.txt fails,
# so a new private repo is caught with no action needed.
#
# Optionally also greps for bare names in an untracked local file
# (~/.config/dotfiles-private-names, one name per line). That catches references
# carrying no owner prefix, which the allowlist cannot see. The file never
# enters the repo, so CI simply skips this half.

set -eu

OWNER="${DOTFILES_REPO_OWNER:-pmgledhill102}"
ALLOWLIST="${DOTFILES_PUBLIC_REPOS:-scripts/public-repos.txt}"
LOCAL_NAMES="${DOTFILES_PRIVATE_NAMES:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles-private-names}"

cd "$(git rev-parse --show-toplevel)"

[ -f "$ALLOWLIST" ] || {
  printf 'error: allowlist not found at %s\n' "$ALLOWLIST" >&2
  exit 1
}

violations="$(mktemp)"
trap 'rm -f "$violations"' EXIT

# --- Owner-scoped references --------------------------------------------

# grep -o prints one match per line; -H keeps the filename on each.
git ls-files -z |
  xargs -0 grep -aoHE "$OWNER/[A-Za-z0-9._-]+" 2>/dev/null |
  while IFS= read -r hit; do
    file="${hit%%:*}"
    name="${hit#*:}"
    name="${name#"$OWNER"/}"
    name="${name%.git}"
    # The allowlist stores bare names, so it never matches this pattern itself.
    grep -qxF "$name" "$ALLOWLIST" ||
      printf '%s: names %s/%s, which is not on the public allowlist\n' \
        "$file" "$OWNER" "$name"
  done | sort -u >>"$violations"

# --- Bare names from untracked local config -----------------------------

if [ -f "$LOCAL_NAMES" ]; then
  while IFS= read -r name || [ -n "$name" ]; do
    case "$name" in '' | '#'*) continue ;; esac
    git ls-files -z |
      xargs -0 grep -ailF -- "$name" 2>/dev/null |
      while IFS= read -r file; do
        printf '%s: contains a name listed in %s\n' "$file" "$LOCAL_NAMES"
      done | sort -u >>"$violations"
  done <"$LOCAL_NAMES"
fi

# --- Report -------------------------------------------------------------

if [ -s "$violations" ]; then
  printf 'This repository is public — private-repo references must not be committed.\n\n' >&2
  sed 's/^/  /' "$violations" >&2
  printf '\nIf the repo named is public, add its bare name to %s.\n' "$ALLOWLIST" >&2
  printf 'If it is private, make it an input instead: read it from untracked\n' >&2
  printf 'machine config (e.g. ~/.config/<tool>.conf) with no default committed here.\n' >&2
  printf 'See docs/adrs/0014-public-repo-no-private-references.md\n' >&2
  exit 1
fi

echo "No private-repo references found."
