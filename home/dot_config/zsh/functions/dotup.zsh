#!/bin/zsh
# shellcheck disable=SC1071
# Update dotfiles and plugins (does not install/upgrade packages)

dotup() {
  echo "==> Updating dotfiles..."
  # --refresh-externals forces chezmoi externals (e.g. agentic-coding-config
  # mounted at ~/.claude/) to re-fetch, bypassing their refreshPeriod. Cheap
  # for small repos and the user is always online during dotup, so the
  # always-latest semantics are worth the extra ~1s.
  local update_log
  update_log=$(mktemp)
  PAGER=cat chezmoi update -v --refresh-externals 2>&1 | tee "$update_log"

  # Auto-recover when chezmoi warns the rendered ~/.config/chezmoi/chezmoi.toml
  # is stale (typically: a new [data.*] block was added to .chezmoi.toml.tmpl
  # since the user last ran init, so downstream templates referencing the new
  # key fail with "map has no entry for key X"). Re-init re-uses stored
  # promptChoiceOnce answers, so it's non-interactive.
  if grep -q "config file template has changed" "$update_log"; then
    echo "\n==> Config template changed — regenerating with 'chezmoi init'..."
    chezmoi init
    echo "\n==> Re-applying with refreshed config..."
    PAGER=cat chezmoi apply -v
  fi
  rm -f "$update_log"

  if [ -d "$ZSH" ]; then
    echo "\n==> Updating Oh My Zsh..."
    # -v silent: skip OMZ's ASCII-art banner and social-media plugs on success.
    # Errors still surface; our own ==> header announces the section.
    "$ZSH/tools/upgrade.sh" -v silent
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

  # Remind the user what custom commands are available post-update.
  echo
  dotfuncs
}
