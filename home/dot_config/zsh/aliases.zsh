#!/bin/zsh
# shellcheck disable=SC1071
# Zsh aliases and functions

# --- Dotfiles management ---

# Update dotfiles, packages, and plugins
dotup() {
  echo "==> Updating dotfiles..."
  chezmoi update -v

  if command -v brew >/dev/null 2>&1; then
    echo "\n==> Updating Homebrew packages..."
    brew update && brew upgrade
  fi

  if [ -d "$ZSH" ]; then
    echo "\n==> Updating Oh My Zsh..."
    "$ZSH/tools/upgrade.sh"
  fi

  local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [ -d "$plugin_dir/$plugin/.git" ]; then
      echo "\n==> Updating $plugin..."
      git -C "$plugin_dir/$plugin" pull
    fi
  done

  if [ -d "$HOME/.nano/.git" ]; then
    echo "\n==> Updating nano syntax highlighting..."
    git -C "$HOME/.nano" pull
  fi

  if [ "$(uname -s)" = "Linux" ] && ! command -v brew >/dev/null 2>&1 \
     && command -v starship >/dev/null 2>&1; then
    echo "\n==> Updating Starship..."
    curl -sS https://starship.rs/install.sh | sh
  fi

  echo "\n==> All updates complete."
}

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
