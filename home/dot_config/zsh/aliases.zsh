#!/bin/zsh
# shellcheck disable=SC1071
# Zsh aliases and functions

# --- Dotfiles management ---

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

# Install and upgrade Homebrew packages from Brewfile
dotbrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Error: Homebrew is not installed."
    return 1
  fi

  echo "==> Updating Homebrew..."
  brew update

  local brewfile="$HOME/Brewfile"
  if [ -f "$brewfile" ]; then
    echo "\n==> Installing packages from Brewfile..."
    brew bundle install --file "$brewfile"
  else
    echo "Warning: Brewfile not found at $brewfile"
  fi

  echo "\n==> Upgrading installed packages..."
  brew upgrade

  echo "\n==> Homebrew packages up to date."
}

# Configure Claude Code MCP servers (interactive, personal machines only)
dotclaude() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "Error: Claude Code CLI is not installed."
    return 1
  fi

  if [ ! -t 0 ]; then
    echo "Error: dotclaude requires an interactive shell."
    return 1
  fi

  echo "==> Claude Code MCP server setup"

  local configured
  configured="$(claude mcp list 2>/dev/null)"

  # --- GitHub MCP (OAuth) ---
  if echo "$configured" | grep -q "github"; then
    echo "\n==> GitHub MCP: already configured — skipping"
  else
    printf "\nConfigure GitHub MCP server? (y/n) "
    read -r answer
    if [ "$answer" = "y" ]; then
      echo "==> Adding GitHub MCP server (OAuth — browser will open)..."
      claude mcp add --transport http --scope user github \
        "https://api.githubcopilot.com/mcp/"
      echo "==> GitHub MCP server configured."
    else
      echo "Skipping GitHub MCP."
    fi
  fi

  # Note: Google Calendar and Gmail MCP are first-party Claude.ai
  # integrations managed via Claude's own OAuth — not configured here.

  # --- Google Developer Knowledge API ---
  if echo "$configured" | grep -q "google-developer-knowledge"; then
    echo "\n==> Google Developer Knowledge MCP: already configured — skipping"
  else
    printf "\nConfigure Google Developer Knowledge MCP server? (y/n) "
    read -r answer
    if [ "$answer" = "y" ]; then
      local dk_key
      dk_key="$(_dotclaude_bw_get "claude-mcp-google-developer-knowledge-api-key")"
      if [ -z "$dk_key" ]; then
        echo "Warning: could not retrieve API key — skipping Google Developer Knowledge MCP"
      else
        claude mcp add --transport http --scope user google-developer-knowledge \
          "https://developerknowledge.googleapis.com/mcp?key=$dk_key"
        echo "==> Google Developer Knowledge MCP server configured."
      fi
    else
      echo "Skipping Google Developer Knowledge MCP."
    fi
  fi

  echo "\n==> MCP server setup complete."
  echo "Run 'claude mcp list' to verify."
}

# Helper: retrieve a secret from Bitwarden (unlocks once per dotclaude run)
_dotclaude_bw_get() {
  local item_name="$1"

  if ! command -v bw >/dev/null 2>&1; then
    echo ""
    echo "Error: Bitwarden CLI not found — install with 'brew install bitwarden-cli'" >&2
    return 1
  fi

  # Login if needed
  if ! bw login --check >/dev/null 2>&1; then
    echo "Logging in to Bitwarden..." >&2
    bw login >&2
  fi

  # Unlock once per session (reuse BW_SESSION if already set)
  if [ -z "${BW_SESSION:-}" ]; then
    echo "Unlocking Bitwarden vault..." >&2
    BW_SESSION=$(bw unlock --raw)
    export BW_SESSION
  fi

  bw get notes "$item_name" --session "$BW_SESSION" 2>/dev/null
}

# --- CLI tool defaults ---

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
