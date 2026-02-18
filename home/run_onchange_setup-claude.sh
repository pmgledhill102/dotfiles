#!/bin/sh
set -e

# Skip if Claude Code CLI is not installed
if ! command -v claude >/dev/null 2>&1; then
    echo "Claude Code CLI not found, skipping MCP setup..."
    exit 0
fi

# Source secrets if available
SECRETS_FILE="$HOME/.secrets"
if [ -f "$SECRETS_FILE" ]; then
    # shellcheck source=/dev/null
    . "$SECRETS_FILE"
fi

echo "Configuring Claude Code MCP servers..."

# Google Developer Knowledge — requires API key from ~/.secrets
if [ -n "${GOOGLE_DEV_KNOWLEDGE_API_KEY:-}" ]; then
    claude mcp add --transport http --scope user \
        google-dev-knowledge \
        https://developerknowledge.googleapis.com/mcp \
        --header "X-Goog-Api-Key: ${GOOGLE_DEV_KNOWLEDGE_API_KEY}"
    echo "  Added google-dev-knowledge"
else
    echo "  Skipped google-dev-knowledge (no API key in ~/.secrets)"
fi

# Terraform — provider docs, module search (requires Docker)
if command -v docker >/dev/null 2>&1; then
    claude mcp add --transport stdio --scope user \
        terraform -- \
        docker run -i --rm hashicorp/terraform-mcp-server
    echo "  Added terraform"
else
    echo "  Skipped terraform (Docker not installed)"
fi

echo "Claude Code MCP setup complete."
