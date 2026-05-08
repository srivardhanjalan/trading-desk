---
name: setup
description: Bootstrap the trading-desk plugin — collect API keys, optionally auto-install TradingView Desktop on macOS, install MCP server runtimes into ${CLAUDE_PLUGIN_DATA}, and start the FMP HTTP server. Run this once after `/plugin install trading-desk@srivardhanjalan`. Use when the user says "set up trading desk", "install trading desk", "configure trading desk keys", "first run trading-desk", or right after a fresh plugin install when commands report missing MCP tools.
---

# Trading Desk — First-Run Setup

Walk the user through one-time setup for the trading-desk plugin. This skill writes their API keys outside the plugin install dir (so updates don't wipe them), optionally auto-installs TradingView Desktop and its MCP integration, installs the FMP MCP package, and starts the FMP HTTP server.

## Required user input

Ask the user — one at a time, via chat — for:

1. **FMP API key** (Financial Modeling Prep). Free tier at https://financialmodelingprep.com/developer.
2. **Alpaca API key** (paper trading). https://app.alpaca.markets/signup.
3. **Alpaca secret key** (from the same Alpaca dashboard).
4. **TradingView Desktop integration?** macOS only — installs the desktop app via Homebrew (~150 MB), clones the MCP server, and auto-launches the app with `--remote-debugging-port=9222` on every claude session start. Adds chart screenshots, order book data, and Pine Script integration. **Default: no.** Just confirm "yes" or "no" — if "yes" the user implicitly consents to brew installing the cask.

Do **not** prompt via `read -p` inside Bash — Claude Code shells out without a TTY. Ask via chat, then act.

## Steps

### Step 0 — detect and resolve MCP config conflicts

The plugin's `.mcp.json` declares `financial-modeling-prep` (HTTP at `localhost:8080/mcp`), `alpaca`, `tradingview`, and `tradingview-analysis`. If a user-level (`~/.claude/.mcp.json`) OR project-level (`<cwd>/.mcp.json` — typically the trading-desk repo's own legacy file) `.mcp.json` declares any of these names, Claude Code dedupes by URL/command and the non-plugin source wins. The plugin's prefixed tools (`mcp__plugin_trading-desk_*`) silently fail to register and commands break with prefix-mismatch errors.

Check BOTH locations and back up any file that has conflicts:

```bash
python3 <<'PY'
import json, os
PLUGIN_MCPS = {"financial-modeling-prep", "alpaca", "tradingview", "tradingview-analysis"}
candidates = [
    os.path.expanduser("~/.claude/.mcp.json"),
    os.path.expanduser("~/workspace/trading-desk/.mcp.json"),  # repo-root legacy
    os.path.join(os.getcwd(), ".mcp.json"),                    # current cwd
]
seen = set()
for path in candidates:
    if path in seen or not os.path.isfile(path):
        continue
    seen.add(path)
    try:
        data = json.load(open(path))
        servers = set(data.get("mcpServers", {}).keys())
        conflicts = servers & PLUGIN_MCPS
        if conflicts:
            print(f"WARNING: {path} declares MCPs that duplicate the plugin: {sorted(conflicts)}")
            os.rename(path, path + ".preplugin.bak")
            print(f"  → backed up to {path}.preplugin.bak")
    except Exception as e:
        print(f"  skip {path}: {e}")
PY
```

Also patch a known FSI plugin bug if present — Claude Code expects `hooks.json` to be `{"hooks": {...}}`. Empty array `[]` or a bare `{}` both fail with "expected record, received undefined". Only patch files that match either bad shape (do NOT touch valid configs):

```bash
python3 <<'PY'
import json, os, glob
for root in [os.path.expanduser("~/.claude/plugins/marketplaces/financial-services-plugins"),
             os.path.expanduser("~/.claude/plugins/cache/financial-services-plugins")]:
    for path in glob.glob(f"{root}/**/hooks.json", recursive=True):
        try:
            data = json.load(open(path))
            broken = (
                (isinstance(data, list)) or
                (isinstance(data, dict) and "hooks" not in data)
            )
            if broken:
                with open(path, "w") as f:
                    json.dump({"hooks": {}}, f)
                    f.write("\n")
                print(f"patched FSI hooks.json: {path}")
        except Exception:
            pass
PY
```

### Step 1 — write `.env` outside the plugin

Set `TD_TV_ENABLED=true` if and only if the user said yes to TradingView Desktop. The SessionStart hook (`bin/ensure-tv-desktop.sh`) reads this flag and auto-launches the app on each claude session.

```bash
ENV_DIR="$HOME/workspace/secrets/trading-desk"
mkdir -p "$ENV_DIR"
chmod 700 "$HOME/workspace/secrets" "$ENV_DIR" 2>/dev/null || true

# Substitute the four user-provided values into this template:
#   <USER_FMP_KEY>          — FMP API key
#   <USER_ALPACA_KEY>       — Alpaca paper API key
#   <USER_ALPACA_SECRET>    — Alpaca paper secret
#   <TV_FLAG>               — "true" if user opted in, "false" otherwise
cat > "$ENV_DIR/.env" <<EOF
# Trading Desk — API Keys (each line uses \`export\` so plain \`source .env\`
# puts keys into env where the plugin's MCP servers read them at startup).
export FMP_ACCESS_TOKEN=<USER_FMP_KEY>
export ALPACA_API_KEY=<USER_ALPACA_KEY>
export ALPACA_SECRET_KEY=<USER_ALPACA_SECRET>
export ALPACA_BASE_URL=https://paper-api.alpaca.markets/v2
export ALPACA_PAPER=true
export FMP_PORT=8080

# TradingView Desktop opt-in (set to "true" to auto-launch the app
# with CDP enabled on every claude session start). macOS only.
export TD_TV_ENABLED=<TV_FLAG>
EOF
chmod 600 "$ENV_DIR/.env"
echo "Wrote $ENV_DIR/.env"
```

### Step 2 — install required MCP runtimes

Always-required (FMP server install + uvx cache warm-up):

```bash
DATA_DIR="${CLAUDE_PLUGIN_DATA}"
mkdir -p "$DATA_DIR/mcp-servers"

# FMP MCP (Node, runs as HTTP server on :8080)
npm install --prefix "$DATA_DIR/mcp-servers/fmp" --silent financial-modeling-prep-mcp-server

# Pre-fetch uvx-managed MCPs (cache warm-up — first run is slow without this)
uvx --from tradingview-mcp-server tradingview-mcp --help >/dev/null 2>&1 || true
uvx alpaca-mcp-server --help >/dev/null 2>&1 || true
```

If `npm install` exceeds Bash tool timeout, split into multiple Bash calls.

### Step 3 — TradingView Desktop integration (only if user said YES in Question 4)

**Skip this entire step if user said no.** Otherwise:

```bash
# Sanity: macOS only
if [[ "$(uname)" != "Darwin" ]]; then
    echo "TradingView Desktop integration is macOS-only. Skipping."
    # Surface to user; they can rerun setup later from a Mac if they get one.
fi
```

Continue only on macOS. Install Homebrew if missing (with explicit user confirmation — DO NOT silently install a package manager):

```bash
if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to install TradingView Desktop. Install it from https://brew.sh and rerun /trading-desk:setup."
    # Surface to user. Do not auto-install Homebrew.
fi
```

Install the TradingView Desktop cask if not already present:

```bash
if ! brew list --cask tradingview >/dev/null 2>&1; then
    echo "Installing TradingView Desktop via Homebrew (~150 MB)..."
    brew install --cask tradingview
fi
```

`brew install --cask tradingview` may take 30–120 seconds. If it exceeds the Bash tool timeout, run it in a follow-up Bash call.

Clone the MCP server into the plugin's persistent data dir:

```bash
DATA_DIR="${CLAUDE_PLUGIN_DATA}"
mkdir -p "$DATA_DIR/mcp-servers"
cd "$DATA_DIR/mcp-servers"
if [ -d tradingview-mcp ]; then
    (cd tradingview-mcp && git pull --quiet) || true
else
    git clone --quiet https://github.com/tradesdontlie/tradingview-mcp.git
fi
(cd tradingview-mcp && npm install --silent)
```

Launch the app once with CDP so the user can sign in and the MCP can connect immediately:

```bash
open -a TradingView --args --remote-debugging-port=9222
echo "TradingView Desktop launched. Sign in to your account if prompted."
echo "From now on it auto-launches with CDP on every claude session start"
echo "(handled by bin/ensure-tv-desktop.sh via the SessionStart hook)."
```

### Step 4 — start the FMP HTTP server

```bash
set -a; source "$HOME/workspace/secrets/trading-desk/.env"; set +a
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
set -a; source "$HOME/workspace/secrets/trading-desk/.env"; set +a

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
Setup complete. One thing to do before running /trading-desk:analyze:

  Restart claude so the MCP servers spawn with your keys:

       /quit
       claude

  (You don't need to source .env — bin/launch-alpaca.sh loads it
   automatically when Claude spawns the Alpaca MCP server.
   If you opted in for TradingView Desktop, the SessionStart hook
   auto-launches the app with CDP on every claude session.)

  Then try: /trading-desk:portfolio
  Or:       /trading-desk:analyze AMD
```

## Failure recovery

- **`npm install` fails**: rerun the affected Bash block. Network glitches are common.
- **`brew install --cask tradingview` fails**: surface the brew error verbatim. Common causes: Xcode license not accepted, brew needs `update`, disk full. The user can rerun setup later or install manually with `brew install --cask tradingview`.
- **FMP server fails to start**: check `${CLAUDE_PLUGIN_DATA}/fmp.log` for the error. Most common cause is invalid `FMP_ACCESS_TOKEN`.
- **Alpaca curl returns 403**: keys are wrong; ask user to re-paste from the Alpaca dashboard.
- **TradingView Desktop opt-in but on non-macOS**: skip the TV install entirely. The plugin's wrapper (`bin/launch-tradingview.sh`) makes the missing tools no-ops so analysis still runs.

## When this skill should self-skip

If `~/workspace/secrets/trading-desk/.env` already exists with non-empty `FMP_ACCESS_TOKEN`, `ALPACA_API_KEY`, `ALPACA_SECRET_KEY`, AND the FMP server responds to `curl http://localhost:8080/mcp`, report "already set up" and exit. Don't re-prompt for keys. The TradingView Desktop install state is independent — if the user wants to enable/disable it after setup, they can edit `TD_TV_ENABLED` in `.env` directly or rerun `/trading-desk:setup` and answer differently to Question 4.
