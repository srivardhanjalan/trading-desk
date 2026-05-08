#!/bin/bash
# Launch the TradingView Desktop MCP server.
#
# If the upstream clone (https://github.com/tradesdontlie/tradingview-mcp) has
# been installed under ${CLAUDE_PLUGIN_DATA}/mcp-servers/tradingview-mcp/,
# exec the real server. Otherwise run a tiny no-op stdio MCP server that
# responds to the protocol with an empty tool list — this way Claude Code
# does NOT log a startup error when the user hasn't installed the optional
# TradingView Desktop integration. The TV Desktop phase in /trading-desk:analyze
# gracefully marks itself N/A when no tools are available.
#
# To install the real server later, ask Claude: "install the tradingview
# desktop MCP for trading-desk", or run manually:
#   git clone https://github.com/tradesdontlie/tradingview-mcp \
#     "${CLAUDE_PLUGIN_DATA}/mcp-servers/tradingview-mcp"
#   (cd "${CLAUDE_PLUGIN_DATA}/mcp-servers/tradingview-mcp" && npm install)

set -e

TV_PATH="${CLAUDE_PLUGIN_DATA}/mcp-servers/tradingview-mcp/src/server.js"
if [ -f "$TV_PATH" ]; then
    exec node "$TV_PATH"
fi

# No-op MCP server: tells Claude Code "I'm running, I just have zero tools."
exec python3 - <<'PY'
import json, sys

def send(m):
    sys.stdout.write(json.dumps(m) + "\n")
    sys.stdout.flush()

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        m = json.loads(line)
    except json.JSONDecodeError:
        continue
    mid = m.get("id")
    method = m.get("method")
    if method == "initialize":
        send({
            "jsonrpc": "2.0",
            "id": mid,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "tradingview-not-installed", "version": "0.0.0"},
            },
        })
    elif method == "tools/list":
        send({"jsonrpc": "2.0", "id": mid, "result": {"tools": []}})
    elif method == "notifications/initialized":
        pass
    elif method == "tools/call":
        send({
            "jsonrpc": "2.0",
            "id": mid,
            "error": {
                "code": -32601,
                "message": "TradingView Desktop MCP not installed. Ask Claude: 'install the tradingview desktop MCP for trading-desk'.",
            },
        })
PY
