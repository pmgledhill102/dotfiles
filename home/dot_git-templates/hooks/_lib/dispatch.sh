# dispatch.sh — shared library for git hook dispatchers
# Sourced (not executed) by each hook script.
# shellcheck shell=sh

# ---------------------------------------------------------------------------
# Detection helpers (file-based, fast)
# ---------------------------------------------------------------------------

has_precommit() {
    [ -f "${GIT_WORK_TREE:-.}/.pre-commit-config.yaml" ]
}

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

command_available() {
    command -v "$1" >/dev/null 2>&1
}

_warn() {
    echo "git-hook-dispatch: $*" >&2
}

# ---------------------------------------------------------------------------
# Dispatch helpers
# ---------------------------------------------------------------------------

run_precommit() {
    _stage="$1"
    shift
    has_precommit || return 0
    if ! command_available pre-commit; then
        _warn "pre-commit config found but 'pre-commit' is not installed"
        return 0
    fi
    pre-commit run --hook-stage "$_stage" "$@"
}

# run_beads: backward-compatibility stub for hooks installed before dotfiles#153
# decoupled this library from beads.
#
# Since PR #153, template hooks no longer call run_beads; modern bd installs
# its own BEADS INTEGRATION block directly into .beads/hooks/*. But .git/hooks/*
# files are PER-CLONE artifacts copied at `git init`/`git clone` time and are
# not updated by `chezmoi apply` — so every repo on this machine cloned before
# 2026-04-19 still has template hooks that call `run_beads <stage>` after
# sourcing this library. Without the function, pre-commit's `set -e` blocks
# every commit; post-checkout/post-merge print noisy "command not found" lines.
#
# This stub no-ops cleanly when:
#   - the repo has no `.beads/` directory (most non-beads repos), OR
#   - `bd` is not installed, OR
#   - bd's hook takes too long (covered by the same timeout escape-hatch used
#     by bd's own integration block; treats GNU-timeout's exit 124 as "continue").
#
# When all three conditions are favourable it delegates to `bd hooks run`,
# matching what the pre-#153 behaviour of this function was.
#
# The stub is intentionally backward-compat-only: new hooks should embed bd's
# managed BEADS INTEGRATION block (installed by `bd hooks install`) rather than
# rely on this dispatcher.
run_beads() {
    _hook="$1"
    shift
    [ -d "${GIT_WORK_TREE:-.}/.beads" ] || return 0
    command_available bd || return 0
    _bd_timeout=${BEADS_HOOK_TIMEOUT:-300}
    if command_available timeout; then
        timeout "$_bd_timeout" bd hooks run "$_hook" "$@"
        _rc=$?
        if [ "$_rc" -eq 124 ]; then
            _warn "beads hook '$_hook' timed out after ${_bd_timeout}s — continuing"
            return 0
        fi
        return "$_rc"
    else
        bd hooks run "$_hook" "$@"
    fi
}
