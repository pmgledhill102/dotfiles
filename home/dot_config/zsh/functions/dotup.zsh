#!/bin/zsh
# shellcheck disable=SC1071
# Update dotfiles and plugins (does not install/upgrade packages)

dotup() {
  echo "==> Updating dotfiles..."
  PAGER=cat chezmoi update -v

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
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  fi

  if command -v rustup >/dev/null 2>&1; then
    echo "\n==> Updating Rust toolchain..."
    rustup update
  fi

  echo "\n==> Reloading shell aliases and functions..."
  # shellcheck source=/dev/null
  [ -f "$HOME/.config/zsh/aliases.zsh" ] && source "$HOME/.config/zsh/aliases.zsh"
  if [ -d "$HOME/.config/zsh/functions" ]; then
    for f in "$HOME/.config/zsh/functions"/*.zsh; do
      # shellcheck source=/dev/null
      [ -f "$f" ] && source "$f"
    done
  fi

  echo "\n==> All updates complete."
}
