#!/bin/sh
#
# Fail when a relative markdown link points at a file that does not exist.
#
# WHY THIS EXISTS: markdownlint validates link *syntax*, never link *targets*.
# docs/adrs/README.md indexed 0012-claude-code-config-via-dotfiles.md for about
# four months after the file was deleted, and nothing noticed until someone read
# the directory by eye (#401). ADR-0015 and ADR-0016 lean on cross-references
# between ADRs, so the exposure grows. See #402.
#
# SCOPE IS DELIBERATELY NARROW: relative links only. External URLs are never
# fetched. Fetching them would make a hermetic check depend on someone else's
# uptime, fail CI on an outage nobody here can fix, and — because ci.yml also
# runs on a weekly schedule — repeatedly hammer third-party hosts for no gain.
# If external link-checking is ever wanted it belongs in its own scheduled job
# that does not gate pull requests.
#
# Checks every tracked *.md file rather than a hard-coded directory list, so a
# new doc is covered the day it lands instead of the day someone remembers to
# add it here.

set -eu

root=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$root" ] || {
	echo "check-markdown-links: not inside a git repository" >&2
	exit 1
}
cd "$root"

findings=$(mktemp)
trap 'rm -f "$findings"' EXIT HUP INT TERM

# Emit "<line>:<target>" for every inline link target in a markdown file.
#
# Two classes of false positive have to be dropped here, because both are
# textually indistinguishable from a link once the context is gone:
#
#   1. Fenced code blocks. docs/TRANSIENT-PROMPT.md carries Starship config
#      containing success_symbol = "[<glyph>](bold green)". That is TOML, not
#      markdown, and a checker that does not strip fences reports "bold green"
#      and "bold red" as dangling links on a clean tree.
#   2. Inline code spans. `[x](y)` inside backticks is sample text.
#
# Stripping code spans is safe for the common [`code`](url) form: the closing
# backtick precedes the "](", so the link target survives the strip.
extract_links() {
	awk '
		{
			body = $0
			sub(/^[ ]*/, "", body)
			indent = length($0) - length(body)
			marker = substr(body, 1, 3)

			# CommonMark: a fence may be indented up to three spaces.
			# Four or more makes it an indented code block, not a fence.
			if (indent <= 3 && (marker == "```" || marker == "~~~")) {
				in_fence = !in_fence
				next
			}
			if (in_fence) next

			gsub(/`[^`]*`/, "", body)

			while (match(body, /\]\([^)]*\)/)) {
				# match spans "](" + target + ")", so the target is
				# RLENGTH minus those three delimiter characters.
				print NR ":" substr(body, RSTART + 2, RLENGTH - 3)
				body = substr(body, RSTART + RLENGTH)
			}
		}
	' "$1"
}

for file in $(git ls-files '*.md'); do
	# git ls-files reads the index, so a file deleted from the working tree
	# without `git rm` is still listed. Skip it rather than let awk fail.
	[ -f "$file" ] || continue

	dir=${file%/*}
	[ "$dir" != "$file" ] || dir="."

	extract_links "$file" | while IFS= read -r record; do
		lineno=${record%%:*}
		target=${record#*:}

		case "$target" in
		"") continue ;;      # []() with an empty target
		\#*) continue ;;     # same-document anchor: no file to check
		*://*) continue ;;   # any scheme — http, https, ftp, ...
		mailto:*) continue ;;
		esac

		# An angle-bracketed target may legitimately contain spaces;
		# a bare one may carry a link title, which is not part of the path.
		case "$target" in
		\<*\>)
			target=${target#<}
			target=${target%>}
			;;
		*\ *)
			target=${target%% *}
			;;
		esac

		# Resolve the file part; a #fragment is not ours to validate.
		target=${target%%#*}
		[ -n "$target" ] || continue

		# Relative to the containing file's directory, NOT the repo root
		# and NOT "anywhere in the tree" — resolving any other way both
		# accepts a link that happens to match elsewhere and mis-reports
		# one that is correct in a sibling directory. A leading slash is
		# GitHub's repo-root-relative form.
		case "$target" in
		/*) resolved=".$target" ;;
		*) resolved="$dir/$target" ;;
		esac

		# -e, not -f: a link to a directory is valid markdown.
		[ -e "$resolved" ] ||
			printf '%s:%s: dangling link -> %s\n' "$file" "$lineno" "$target" >>"$findings"
	done
done

if [ -s "$findings" ]; then
	echo "Dangling relative markdown links:" >&2
	cat "$findings" >&2
	echo >&2
	echo "Each link above resolves to no file. Fix the path, or remove the link." >&2
	exit 1
fi

echo "No dangling relative markdown links found."
