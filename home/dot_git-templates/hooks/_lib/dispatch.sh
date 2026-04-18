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
