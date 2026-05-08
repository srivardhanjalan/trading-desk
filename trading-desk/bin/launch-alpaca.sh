#!/bin/bash
# Wrapper that sources the user's .env before launching the Alpaca MCP server.
# This means the plugin works without requiring users to source .env in the
# shell that launches claude — Claude Code spawns this script as the MCP
# command, and this script puts the keys into env before exec'ing uvx.

set -e

ENV_FILE="$HOME/workspace/secrets/trading-desk/.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
fi

# If keys are still missing, surface a clear error so MCP startup fails
# loudly rather than the user seeing 401s mid-analysis.
if [ -z "${ALPACA_API_KEY:-}" ] || [ -z "${ALPACA_SECRET_KEY:-}" ]; then
    echo "launch-alpaca.sh: ALPACA_API_KEY/ALPACA_SECRET_KEY not set." >&2
    echo "Run /trading-desk:setup to configure, or set them in $ENV_FILE." >&2
    exit 1
fi

exec uvx alpaca-mcp-server
