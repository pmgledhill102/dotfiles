#!/bin/sh
# check-brewfile-manifest.sh — assert home/Brewfile.tmpl agrees with the tool
# manifest in agentic-coding-config (home/standards/tools.json).
#
# Rule: "tool present", not "version equal". brew installs latest and the
# manifest pins exact versions for the cloud sandbox, so versions are never
# compared. The decisions per surface live in scripts/tool-surfaces.txt.
#
# Fails when:
#   - a manifest tool has no decision row, or a row names a tool the manifest
#     no longer lists;
#   - a tool decided 'yes' for a surface is missing from the Brewfile section
#     that surface installs;
#   - a 'no' decision, or a renamed provider, carries no reason.
#
# Inputs (environment, for the CI job and for the control test):
#   TOOLS_MANIFEST  path to tools.json (required)
#   BREWFILE        default home/Brewfile.tmpl
#   TOOL_SURFACES   default scripts/tool-surfaces.txt
#
# Needs jq.

set -eu

: "${TOOLS_MANIFEST:?set TOOLS_MANIFEST to a local copy of tools.json}"
BREWFILE="${BREWFILE:-home/Brewfile.tmpl}"
TOOL_SURFACES="${TOOL_SURFACES:-scripts/tool-surfaces.txt}"

for f in "$TOOLS_MANIFEST" "$BREWFILE" "$TOOL_SURFACES"; do
  [ -f "$f" ] || {
    printf 'error: %s not found\n' "$f" >&2
    exit 2
  }
done
command -v jq >/dev/null 2>&1 || {
  printf 'error: jq is required\n' >&2
  exit 2
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Brewfile entries of the personal block, split at the darwin-only part.
# The template keeps the personal block between its machine_type conditions.
awk -v common="$tmp/common" -v darwin="$tmp/darwin" '
  /machine_type "personal"/ { inblock = 1; next }
  /else if eq \.machine_type/ { inblock = 0 }
  !inblock { next }
  /eq \.chezmoi\.os "darwin"/ { out = darwin; next }
  /^(brew|cask) "/ {
    n = $2
    gsub(/"/, "", n)
    sub(/.*\//, "", n)
    print n >> (out == "" ? common : out)
  }
' "$BREWFILE"
: >>"$tmp/common"
: >>"$tmp/darwin"

# A sanity floor: an empty parse would turn every check below into a pass.
if [ "$(wc -l <"$tmp/common")" -lt 5 ]; then
  printf 'error: parsed fewer than 5 personal Brewfile entries from %s; the parser no longer matches the file\n' "$BREWFILE" >&2
  exit 2
fi

fail=0
report() {
  printf 'FAIL: %s\n' "$1" >&2
  fail=1
}

jq -r '.tools[].name' "$TOOLS_MANIFEST" | sort >"$tmp/manifest"
if [ ! -s "$tmp/manifest" ]; then
  printf 'error: no tools read from %s\n' "$TOOLS_MANIFEST" >&2
  exit 2
fi

grep -v '^[[:space:]]*#' "$TOOL_SURFACES" | grep -v '^[[:space:]]*$' >"$tmp/rows" || true
cut -d'|' -f1 "$tmp/rows" | sort >"$tmp/decided"

# Every manifest tool needs a decision; every decision needs a manifest tool.
comm -23 "$tmp/manifest" "$tmp/decided" | while IFS= read -r t; do
  printf 'FAIL: manifest tool %s has no row in %s\n' "$t" "$TOOL_SURFACES" >&2
done >"$tmp/missing" 2>&1
comm -13 "$tmp/manifest" "$tmp/decided" | while IFS= read -r t; do
  printf 'FAIL: %s names %s, which is not in the manifest\n' "$TOOL_SURFACES" "$t" >&2
done >"$tmp/stale" 2>&1
if [ -s "$tmp/missing" ] || [ -s "$tmp/stale" ]; then
  cat "$tmp/missing" "$tmp/stale" >&2
  fail=1
fi

while IFS='|' read -r tool macos durable provider reason; do
  case "$macos:$durable" in
    yes:yes | yes:no | no:yes | no:no) ;;
    *)
      report "$tool: macos/ubuntu-durable must each be yes or no"
      continue
      ;;
  esac
  if { [ "$macos" = no ] || [ "$durable" = no ] || [ "$provider" != "$tool" ]; } && [ -z "$reason" ]; then
    report "$tool: a 'no' decision or a differently named provider needs a reason"
  fi
  if [ "$macos" = yes ]; then
    grep -qxF "$provider" "$tmp/common" "$tmp/darwin" \
      || report "$tool: macos wants it, but the Brewfile personal block has no '$provider'"
  fi
  if [ "$durable" = yes ]; then
    grep -qxF "$provider" "$tmp/common" \
      || report "$tool: ubuntu-durable wants it, but the Brewfile personal block outside the darwin-only part has no '$provider'"
  fi
done <"$tmp/rows"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
printf 'ok: Brewfile agrees with the tool manifest (%s tools, presence only)\n' "$(wc -l <"$tmp/manifest" | tr -d ' ')"
