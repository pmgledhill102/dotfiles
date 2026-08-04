#!/bin/sh
# Remove Claude config files that agentic-coding-config has retired.
#
# ~/.claude/ is mounted from agentic-coding-config via the archive external in
# .chezmoiexternal.toml.tmpl. chezmoi only adds and updates target files — it
# never removes a target whose source was deleted, so a retired slash command
# survives on every machine that ever applied a version containing it, and
# Claude Code goes on listing it.
#
# agentic-coding-config ships both halves of the fix: ~/.claude/retired-paths
# (the list) and ~/.claude/bin/claude-prune-retired (the pruner). This script
# is deliberately dumb — keeping the list upstream means retiring a file is a
# one-repo change, and this script never needs to change again.
# See agentic-coding-config#125.
#
# run_after_ (not run_onchange_): run_onchange_ re-runs when the script's own
# contents change, but what actually changes is ~/.claude/retired-paths, which
# arrives via the external and is invisible to this script's hash — it would
# fire once and never again. The pruner is idempotent and cheap, so running it
# on every apply is both correct and simpler.

set -eu

# The pruner arrives via the external, so on a first apply it may not exist
# yet. Exit cleanly and let the next apply pick it up.
[ -x "$HOME/.claude/bin/claude-prune-retired" ] || exit 0

"$HOME/.claude/bin/claude-prune-retired"
