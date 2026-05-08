---
name: setup
description: Bootstrap the trading-desk plugin — collect API keys, install MCP server clones into ${CLAUDE_PLUGIN_DATA}, and start the FMP HTTP server. Run this once after `/plugin install trading-desk@srivardhanjalan`. Use when the user says "set up trading desk", "install trading desk", "configure trading desk keys", "first run trading-desk", or right after a fresh plugin install when commands report missing MCP tools.
---

# Trading Desk — First-Run Setup

Walk the user through one-time setup for the trading-desk plugin. This skill writes their API keys outside the plugin install dir (so updates don't wipe them), clones the TradingView Desktop MCP into the plugin's persistent data dir, installs the FMP MCP npm package there, and starts the FMP HTTP server.

## Required user input

Ask the user — one at a time, via chat — for:

1. **FMP API key** (Financial Modeling Prep). Free tier at https://financialmodelingprep.com/developer.
2. **Alpaca API key** (paper trading). https://app.alpaca.markets/signup.
3. **Alpaca secret key** (from the same Alpaca dashboard).

Do **not** prompt via `read -p` inside Bash — Claude Code shells out without a TTY. Ask via chat, then write what they say to disk.

## Steps

### Step 1 — write `.env` outside the plugin

```bash
ENV_DIR="$HOME/workspace/secrets/trading-desk"
mkdir -p "$ENV_DIR"
chmod 700 "$HOME/workspace/secrets" "$ENV_DIR" 2>/dev/null || true
cat > "$ENV_DIR/.env" <<EOF
# Trading Desk — API Keys
# Each line uses \`export \` so plain \`source\` puts keys into env
# (claude's MCP servers read \${ALPACA_API_KEY} etc. from env at startup).
export FMP_ACCESS_TOKEN=<USER_FMP_KEY>
export ALPACA_API_KEY=<USER_ALPACA_KEY>
export ALPACA_SECRET_KEY=<USER_ALPACA_SECRET>
export ALPACA_BASE_URL=https://paper-api.alpaca.markets/v2
export ALPACA_PAPER=true
export FMP_PORT=8080
EOF
chmod 600 "$ENV_DIR/.env"
echo "Wrote $ENV_DIR/.env"
```

The `export` prefix is critical — without it, `source .env` only sets shell variables (not env vars), and subprocess MCP servers won't see the keys.

Substitute `<USER_FMP_KEY>` etc. with the values the user gave. Confirm path with the user before writing.

### Step 2 — install MCP server runtimes into `${CLAUDE_PLUGIN_DATA}`

```bash
DATA_DIR="${CLAUDE_PLUGIN_DATA}"
mkdir -p "$DATA_DIR/mcp-servers"
cd "$DATA_DIR/mcp-servers"

# TradingView Desktop MCP (Node, optional — required only for chart screenshots)
if [ -d tradingview-mcp ]; then
  (cd tradingview-mcp && git pull --quiet) || true
else
  git clone --quiet https://github.com/tradesdontlie/tradingview-mcp.git
fi
(cd tradingview-mcp && npm install --silent) || echo "WARN: tradingview-mcp npm install failed (optional, can be retried later)"

# FMP MCP (Node, runs as HTTP server on :8080)
mkdir -p fmp
npm install --prefix fmp --silent financial-modeling-prep-mcp-server
```

If `git clone` or `npm install` exceeds Bash tool timeout, split into multiple Bash calls.

### Step 3 — pre-fetch uvx-managed MCPs (cache warm-up, optional)

```bash
uvx --from tradingview-mcp-server tradingview-mcp --help >/dev/null 2>&1 || true
uvx alpaca-mcp-server --help >/dev/null 2>&1 || true
```

### Step 4 — start the FMP HTTP server

```bash
source "$HOME/workspace/secrets/trading-desk/.env"
DATA_DIR="${CLAUDE_PLUGIN_DATA}"

# kill any prior FMP server
lsof -t -i :8080 | xargs -r kill 2>/dev/null || true
sleep 1

# launch
FMP_ACCESS_TOKEN="$FMP_ACCESS_TOKEN" nohup npx --prefix "$DATA_DIR/mcp-servers/fmp" fmp-mcp --port 8080 >"$DATA_DIR/fmp.log" 2>&1 &
echo "$!" > "$DATA_DIR/fmp.pid"
sleep 3

# verify
curl -s -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"setup","version":"1"}}}' \
  | head -c 200
```

If the verify call returns `Financial Modeling Prep MCP`, the server is live.

### Step 5 — verify keys against live endpoints

```bash
source "$HOME/workspace/secrets/trading-desk/.env"

# Alpaca paper account
curl -s -o /dev/null -w "Alpaca: HTTP %{http_code}\n" \
  -H "APCA-API-KEY-ID: $ALPACA_API_KEY" \
  -H "APCA-API-SECRET-KEY: $ALPACA_SECRET_KEY" \
  https://paper-api.alpaca.markets/v2/account

# FMP profile (stable endpoint)
curl -s -o /dev/null -w "FMP: HTTP %{http_code}\n" \
  "https://financialmodelingprep.com/stable/profile?symbol=AAPL&apikey=$FMP_ACCESS_TOKEN"
```

Both should return `HTTP 200`. If not, surface the error to the user verbatim.

### Step 6 — instruct the user

Print exactly:

```
Setup complete. Two things to do before running /trading-desk:analyze:

  1. Source your env file in the shell that launches claude:

       source ~/workspace/secrets/trading-desk/.env

  2. Restart claude so the MCP servers pick up your keys:

       /quit
       claude

  Then try: /trading-desk:portfolio
  Or:       /trading-desk:analyze AMD
```

## Failure recovery

- **`npm install` fails**: rerun the affected Bash block. Network glitches are common.
- **FMP server fails to start**: check `${CLAUDE_PLUGIN_DATA}/fmp.log` for the error. Most common cause is invalid `FMP_ACCESS_TOKEN`.
- **Alpaca curl returns 403**: keys are wrong; ask user to re-paste from the Alpaca dashboard.
- **TradingView Desktop MCP fails**: it's optional — analysis works without it. Skip and continue.

## When this skill should self-skip

- If `~/workspace/secrets/trading-desk/.env` already exists with non-empty `FMP_ACCESS_TOKEN`, `ALPACA_API_KEY`, `ALPACA_SECRET_KEY`, AND the FMP server responds to `curl http://localhost:8080/mcp`, AND `${CLAUDE_PLUGIN_DATA}/mcp-servers/tradingview-mcp/src/server.js` exists — report "already set up" and exit. Don't re-prompt for keys.
