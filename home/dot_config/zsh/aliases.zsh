#!/bin/zsh
# shellcheck disable=SC1071
# Zsh aliases
#
# Shell functions live in ~/.config/zsh/functions/ — one file per command.

# --- CLI tool defaults ---

# eza: modern ls replacement
if command -v eza >/dev/null 2>&1; then
  alias ls='eza'
  alias l='eza -l --git'
  alias ll='eza -l --git'
  alias la='eza -la --git'
  alias lt='eza --tree --level=2'
fi

# bat: use as default pager and cat replacement
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
  export BAT_THEME="Dracula"
  export PAGER="bat"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# --- Podman (Docker drop-in replacement) ---

if command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
  alias docker='podman'
  alias docker-compose='podman compose'
fi
