#!/bin/zsh
# shellcheck disable=SC1071
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

  # --- GitHub MCP (local binary + token from gh auth) ---
  if echo "$configured" | grep -q "github"; then
    echo "\n==> GitHub MCP: already configured — skipping"
  else
    printf "\nConfigure GitHub MCP server? (y/n) "
    read -r answer
    if [ "$answer" = "y" ]; then
      if ! command -v github-mcp-server >/dev/null 2>&1; then
        echo "Warning: github-mcp-server not found — run 'brewup' first"
      elif ! command -v gh >/dev/null 2>&1; then
        echo "Warning: gh CLI not found — skipping GitHub MCP"
      else
        local gh_token
        gh_token="$(gh auth token 2>/dev/null)"
        if [ -z "$gh_token" ]; then
          echo "Warning: gh auth token not available — run 'gh auth login' first"
        else
          echo "==> Adding GitHub MCP server (local binary + gh auth token)..."
          claude mcp add-json github \
            "{\"type\":\"stdio\",\"command\":\"github-mcp-server\",\"args\":[\"stdio\"],\"env\":{\"GITHUB_PERSONAL_ACCESS_TOKEN\":\"$gh_token\"}}" \
            -s user
          echo "==> GitHub MCP server configured."
        fi
      fi
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
        claude mcp add-json google-developer-knowledge \
          "{\"type\":\"http\",\"url\":\"https://developerknowledge.googleapis.com/mcp\",\"headers\":{\"X-Goog-Api-Key\":\"$dk_key\"}}" \
          -s user
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
