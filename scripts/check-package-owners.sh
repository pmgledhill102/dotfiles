#!/bin/sh
# check-package-owners.sh — one owner per tool on a Linux tier that runs
# Homebrew (ADR-0019).
#
# Rule: a tool is installed by the tier's apt list ([data.packages.apt] in
# home/.chezmoi.toml.tmpl) or by its Brewfile (home/Brewfile.tmpl rendered for
# Linux), never both. The one exception is the bootstrap set below, which apt
# must provide before Homebrew exists. Two owners is how ADR-0004's fzf
# incident happened: whichever copy came first on PATH won, silently.
#
# Both templates are rendered with chezmoi, so the comparison sees exactly what
# a Linux machine of that tier would get, including the Brewfile's darwin
# guard. Rendering details, each a trap that makes a wrong render look right:
#   - The tier is pre-seeded as [data] machine_type in a throwaway --config
#     file. `--init --promptChoice machine_type=<tier>` does NOT work with the
#     template's promptChoiceOnce: it silently renders the minimal list for
#     every tier. See docs/TESTING.md.
#   - The throwaway config also stops the user's own ~/.config/chezmoi data
#     from deciding the tier.
#   - The templates are read from this working tree on stdin, never from the
#     installed source copy.
#   - .chezmoi.os is replaced with "linux" before rendering, so the result is
#     the Linux one even when this runs on macOS.
#   - The rendered config must name the tier asked for, or the check errors.
#
# Fails when a tier's apt list and its Linux Brewfile share a tool outside the
# bootstrap set. Debian package names are mapped to Homebrew formula names
# first (fd-find is fd, and so on).
#
# Inputs (environment, for the control test):
#   APT_TEMPLATE   default home/.chezmoi.toml.tmpl
#   BREWFILE       default home/Brewfile.tmpl
#   TIERS          default "personal"
#
# TIERS lists the tiers that run Homebrew on Linux: personal (ADR-0017) and
# work (ADR-0019, #502). Minimal stays apt-only, so it is not checked.
#
# Needs chezmoi.

set -eu

APT_TEMPLATE="${APT_TEMPLATE:-home/.chezmoi.toml.tmpl}"
BREWFILE="${BREWFILE:-home/Brewfile.tmpl}"
TIERS="${TIERS:-personal work}"

# apt installs these before Homebrew exists, so both lists may carry them.
BOOTSTRAP_SET="curl git wget zsh"

for f in "$APT_TEMPLATE" "$BREWFILE"; do
  [ -f "$f" ] || {
    printf 'error: %s not found\n' "$f" >&2
    exit 2
  }
done
command -v chezmoi >/dev/null 2>&1 || {
  printf 'error: chezmoi is required\n' >&2
  exit 2
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Debian package name -> Homebrew formula name, for the tools whose names
# differ. Ubuntu's bat, git-delta and ripgrep packages already match brew's
# formula names (only bat's binary differs: batcat), so they map to themselves;
# batcat and delta are mapped in case a list ever names the binary instead.
brew_name() {
  case "$1" in
    fd-find) echo fd ;;
    batcat) echo bat ;;
    delta) echo git-delta ;;
    *) echo "$1" ;;
  esac
}

render() { # tier, template -> stdout
  printf '[data]\n    machine_type = "%s"\n' "$1" >"$tmp/config.toml"
  sed 's/\.chezmoi\.os/"linux"/g' "$2" \
    | chezmoi --config "$tmp/config.toml" \
      --persistent-state "$tmp/state.boltdb" \
      --source "$(dirname "$2")" \
      execute-template --init
}

fail=0
for tier in $TIERS; do
  render "$tier" "$APT_TEMPLATE" >"$tmp/config.rendered"
  render "$tier" "$BREWFILE" >"$tmp/Brewfile.rendered"

  # Prove the render is the tier asked for, not a silent fallback.
  grep -qxF "    machine_type = \"$tier\"" "$tmp/config.rendered" || {
    printf 'error: %s did not render as tier %s\n' "$APT_TEMPLATE" "$tier" >&2
    exit 2
  }

  # The packages array directly under [data.packages.apt].
  awk '
    /^[[:space:]]*\[data\.packages\.apt\]/ { inapt = 1; next }
    inapt && /^[[:space:]]*\[/ && !inarr { inapt = 0 }
    inapt && /^[[:space:]]*packages[[:space:]]*=/ { inarr = 1 }
    inarr {
      line = $0
      sub(/#.*/, "", line)
      while (match(line, /"[^"]+"/)) {
        print substr(line, RSTART + 1, RLENGTH - 2)
        line = substr(line, RSTART + RLENGTH)
      }
      if ($0 ~ /\]/) exit
    }
  ' "$tmp/config.rendered" | while IFS= read -r p; do
    brew_name "$p"
  done | sort -u >"$tmp/apt"

  # brew and cask entries, tap prefix stripped.
  sed -nE 's/^[[:space:]]*(brew|cask)[[:space:]]+"([^"]+)".*/\2/p' \
    "$tmp/Brewfile.rendered" | sed 's|.*/||' | sort -u >"$tmp/brew"

  # Sanity floor: an empty parse would turn the comparison into a pass.
  if [ ! -s "$tmp/apt" ] || [ "$(wc -l <"$tmp/brew")" -lt 5 ]; then
    printf 'error: tier %s: parsed %s apt and %s Brewfile entries; the parser no longer matches the templates\n' \
      "$tier" "$(wc -l <"$tmp/apt" | tr -d ' ')" "$(wc -l <"$tmp/brew" | tr -d ' ')" >&2
    exit 2
  fi

  comm -12 "$tmp/apt" "$tmp/brew" >"$tmp/both"
  while IFS= read -r t; do
    case " $BOOTSTRAP_SET " in
      *" $t "*) continue ;;
    esac
    printf 'FAIL: tier %s: %s is in both the apt list (%s) and the Linux Brewfile (%s); pick one owner\n' \
      "$tier" "$t" "$APT_TEMPLATE" "$BREWFILE" >&2
    fail=1
  done <"$tmp/both"

  if [ "$fail" -eq 0 ]; then
    printf 'ok: tier %s: apt (%s) and Linux Brewfile (%s) share only the bootstrap set: %s\n' \
      "$tier" "$(wc -l <"$tmp/apt" | tr -d ' ')" "$(wc -l <"$tmp/brew" | tr -d ' ')" \
      "$(tr '\n' ' ' <"$tmp/both" | sed 's/ $//')"
  fi
done

exit "$fail"
