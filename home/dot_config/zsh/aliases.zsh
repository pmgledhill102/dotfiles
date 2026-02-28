#!/bin/zsh
# shellcheck disable=SC1071
# Zsh aliases and functions

# --- Dotfiles management ---

# Update dotfiles from remote and apply
alias dotup='chezmoi update -v'

# Show dotfiles status: machine type, last applied, pending changes
dotstatus() {
  echo "Machine type: $(chezmoi data | grep machine_type | head -1 | sed 's/.*: *"\(.*\)".*/\1/')"
  echo "Source path:  $(chezmoi source-path)"

  local last_applied
  last_applied="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$(chezmoi source-path)" 2>/dev/null \
    || stat -c '%y' "$(chezmoi source-path)" 2>/dev/null | cut -d. -f1)"
  echo "Last applied: ${last_applied:-unknown}"

  echo ""
  echo "Pending changes:"
  chezmoi status || echo "  (none)"
}

# --- CLI tool defaults ---

# bat: use as default pager and cat replacement
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
  export BAT_THEME="Dracula"
  export PAGER="bat"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
