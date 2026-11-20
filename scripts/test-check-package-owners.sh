#!/bin/sh
# test-check-package-owners.sh — control for check-package-owners.sh.
#
# A check that reports nothing proves nothing until it is shown able to report
# something. This runs the check against the real templates (must pass), then
# against copies with a planted overlap (must fail, and must name it).
#
# Needs chezmoi, as the check itself does.

set -eu

cd "$(git rev-parse --show-toplevel)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
rc=0

expect_fail() { # name, expected substring
  name="$1"
  needle="$2"
  if out="$(sh scripts/check-package-owners.sh 2>&1)"; then
    printf 'CONTROL FAILED: %s: check passed on a planted overlap\n' "$name" >&2
    rc=1
  elif printf '%s' "$out" | grep -qF "$needle"; then
    printf 'ok: %s fails as it should\n' "$name"
  else
    printf 'CONTROL FAILED: %s: failed, but without naming %s:\n%s\n' "$name" "$needle" "$out" >&2
    rc=1
  fi
}

# Baseline: today's lists share only the bootstrap set.
sh scripts/check-package-owners.sh

# The copy lives in a directory of its own, so --source still resolves.
mkdir "$tmp/home"
planted="$tmp/home/.chezmoi.toml.tmpl"

# plant NAME: copy the config template with NAME added to the personal apt list.
plant() {
  awk -v name="$1" '
    /if eq \$machineType "personal"/ { personal = 1 }
    personal && /"curl",/ {
      print
      sub(/"curl"/, "\"" name "\"")
      print
      personal = 0
      next
    }
    { print }
  ' home/.chezmoi.toml.tmpl >"$planted"
  # A plant that did not take would make every case below vacuous.
  grep -qF "\"$1\"," "$planted" || {
    printf 'CONTROL ERROR: could not plant %s in the personal apt list\n' "$1" >&2
    exit 2
  }
}

# 1. jq in the personal apt list; the Brewfile already has it.
plant jq
APT_TEMPLATE="$planted" expect_fail "jq in personal apt and Brewfile" "jq is in both"

# 2. A Debian rename: fd-find in apt must collide with brew "fd".
plant fd-find
APT_TEMPLATE="$planted" expect_fail "fd-find in apt, fd in Brewfile" "fd is in both"

# 3. A darwin-only Brewfile entry is not an overlap on Linux: colima is planted
#    in apt, and the check must still pass because the darwin guard drops it.
plant colima
if APT_TEMPLATE="$planted" sh scripts/check-package-owners.sh >/dev/null 2>&1; then
  printf 'ok: darwin-only colima is not counted as a Linux overlap\n'
else
  printf 'CONTROL FAILED: colima is darwin-only, but the check saw it in the Linux Brewfile\n' >&2
  rc=1
fi

exit "$rc"
