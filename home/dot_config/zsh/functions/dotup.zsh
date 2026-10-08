#!/bin/zsh
# shellcheck shell=bash
# Update dotfiles and plugins (does not install/upgrade packages)

dotup() {
  _dotup_banner
  echo "==> Updating dotfiles..."
  # --init regenerates ~/.config/chezmoi/chezmoi.toml from .chezmoi.toml.tmpl
  # before applying, so a pull that changes the config template (a new
  # [data.*] key, a package-list edit) applies once, with the fresh config.
  # It is non-interactive: promptChoiceOnce reuses the stored machine_type.
  # This replaces a detect-the-warning-then-re-apply recovery, which ran every
  # changed script twice and gave a failed run_once a second, surprising go
  # (#461).
  # --refresh-externals forces chezmoi externals (e.g. agentic-coding-config
  # mounted at ~/.claude/) to re-fetch, bypassing their refreshPeriod. Cheap
  # for small repos and the user is always online during dotup, so the
  # always-latest semantics are worth the extra ~1s.
  # No -v: verbose mode prints the full unified diff of every changed file,
  # which buries the run in noise on each dotup. Without it, chezmoi applies
  # quietly and git's own pull summary still reports what came in.
  # shellcheck disable=SC2209  # PAGER=cat is an env prefix, not an assignment
  PAGER=cat chezmoi update --init --refresh-externals

  if [ -d "$ZSH" ]; then
    printf "\n==> Updating Oh My Zsh...\n"
    # -v silent: skip OMZ's ASCII-art banner and social-media plugs on success.
    # Errors still surface; our own ==> header announces the section.
    "$ZSH/tools/upgrade.sh" -v silent
  fi

  local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [ -d "$plugin_dir/$plugin/.git" ]; then
      printf "\n==> Updating %s...\n" "$plugin"
      git -C "$plugin_dir/$plugin" pull
    fi
  done

  if [ -d "$HOME/.nano/.git" ]; then
    printf "\n==> Updating nano syntax highlighting...\n"
    git -C "$HOME/.nano" pull
  fi

  if [ "$(uname -s)" = "Linux" ] && ! command -v brew >/dev/null 2>&1 \
     && command -v starship >/dev/null 2>&1; then
    printf "\n==> Updating Starship...\n"
    # Always target ~/.local/bin: the installer's default /usr/local/bin
    # needs sudo (#446). ~/.local/bin precedes /usr/local/bin on PATH, so
    # this shadows a copy left by an older bootstrap. The sed stops at the
    # installer's per-shell setup instructions, which dot_zshrc already covers.
    mkdir -p "$HOME/.local/bin"
    curl -sS https://starship.rs/install.sh \
      | sh -s -- -y -b "$HOME/.local/bin" \
      | sed '/Please follow the steps/,$d'
    if [ -x /usr/local/bin/starship ]; then
      echo "Note: stale /usr/local/bin/starship is shadowed by ~/.local/bin;"
      echo "      remove it with: sudo rm /usr/local/bin/starship"
    fi
  fi

  printf "\n==> Reloading shell aliases and functions...\n"
  # shellcheck source=/dev/null
  [ -f "$HOME/.config/zsh/aliases.zsh" ] && source "$HOME/.config/zsh/aliases.zsh"
  if [ -d "$HOME/.config/zsh/functions" ]; then
    for f in "$HOME/.config/zsh/functions"/*.zsh; do
      # shellcheck source=/dev/null
      [ -f "$f" ] && source "$f"
    done
  fi

  printf "\n==> All updates complete.\n"

  # Remind the user what custom commands are available post-update.
  echo
  dotfuncs
}

# Helper: the opening banner, shaded top to bottom from cyan to magenta. Plain
# when stdout isn't a terminal or NO_COLOR is set, same rule as dotfuncs.
_dotup_banner() {
  local line reset=""
  local colour=1
  set -- 51 45 39 63 99 135 171
  [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && colour=0 && reset=$(printf '\033[0m')

  echo
  while IFS= read -r line; do
    if [ "$colour" -eq 0 ]; then
      printf '\033[1;38;5;%sm%s%s\n' "$1" "$line" "$reset"
      shift
    else
      printf '%s\n' "$line"
    fi
  done <<'EOF'
       _       _
    __| | ___ | |_ _   _ _ __
   / _` |/ _ \| __| | | | '_ \
  | (_| | (_) | |_| |_| | |_) |
   \__,_|\___/ \__|\__,_| .__/
                        |_|
EOF
  if [ "$colour" -eq 0 ]; then
    printf '\033[2m%s%s\n\n' "  dotfiles · plugins · shell" "$reset"
  else
    printf '%s\n\n' "  dotfiles · plugins · shell"
  fi
}
