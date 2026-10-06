#!/bin/sh
set -e

# The native installer's launcher lives here, and on a fresh machine the apply
# runs from a shell that started before the directory existed (dotfiles#435)
PATH="$HOME/.local/bin:$PATH"

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

# This script re-runs whenever it changes, and `claude mcp add` refuses a name
# that already exists, which under set -e would fail the whole apply. Remove
# first so each run converges: it is also how an older podman-based terraform
# entry becomes the docker one below.
for server in google-dev-knowledge terraform; do
    claude mcp remove --scope user "$server" >/dev/null 2>&1 || true
done

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

# Terraform — provider docs, module search (requires Docker; ADR-0018)
if command -v docker >/dev/null 2>&1; then
    claude mcp add --transport stdio --scope user \
        terraform -- \
        docker run -i --rm hashicorp/terraform-mcp-server
    echo "  Added terraform (via docker)"
else
    echo "  Skipped terraform (no container runtime installed)"
fi

echo "Claude Code MCP setup complete."
