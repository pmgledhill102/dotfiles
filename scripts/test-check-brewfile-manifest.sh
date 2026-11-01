#!/bin/sh
# test-check-brewfile-manifest.sh — control for check-brewfile-manifest.sh.
#
# A check that reports nothing proves nothing until it is shown able to report
# something. This runs the check against the real Brewfile (must pass), then
# against copies with a planted gap (must fail, and must name the gap).
#
# Needs TOOLS_MANIFEST, as the check itself does.

set -eu

: "${TOOLS_MANIFEST:?set TOOLS_MANIFEST to a local copy of tools.json}"
cd "$(git rev-parse --show-toplevel)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
rc=0

expect_fail() { # name, expected substring, env assignments via function args
  name="$1"
  needle="$2"
  if out="$(sh scripts/check-brewfile-manifest.sh 2>&1)"; then
    printf 'CONTROL FAILED: %s: check passed on a planted gap\n' "$name" >&2
    rc=1
  elif printf '%s' "$out" | grep -qF "$needle"; then
    printf 'ok: %s fails as it should\n' "$name"
  else
    printf 'CONTROL FAILED: %s: failed, but without naming %s:\n%s\n' "$name" "$needle" "$out" >&2
    rc=1
  fi
}

# Baseline: the real files agree.
sh scripts/check-brewfile-manifest.sh

# 1. Remove a common-block tool from the Brewfile.
grep -v '^brew "gitleaks"$' home/Brewfile.tmpl >"$tmp/Brewfile"
BREWFILE="$tmp/Brewfile" expect_fail "Brewfile missing gitleaks" "gitleaks"

# 2. A manifest tool with no decision row.
jq '.tools += [{"name":"planted-tool"}]' "$TOOLS_MANIFEST" >"$tmp/tools.json"
TOOLS_MANIFEST="$tmp/tools.json" expect_fail "manifest tool without a decision" "planted-tool"

# 3. A decision row for a tool the manifest dropped.
jq '.tools |= map(select(.name != "cspell"))' "$TOOLS_MANIFEST" >"$tmp/tools.json"
TOOLS_MANIFEST="$tmp/tools.json" expect_fail "decision for a tool the manifest lacks" "cspell"

# 4. A darwin-only entry must not satisfy ubuntu-durable.
sed 's/^tflint|yes|no|/tflint|yes|yes|/' scripts/tool-surfaces.txt >"$tmp/surfaces.txt"
TOOL_SURFACES="$tmp/surfaces.txt" expect_fail "darwin-only tool wanted on ubuntu-durable" "tflint"

exit "$rc"
