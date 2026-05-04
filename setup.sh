#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Trading Desk — One-Command Setup
# ============================================================
# Installs all dependencies, configures MCP servers, and
# generates the .mcp.json config. Run this once after cloning.
#
# Usage:
#   ./setup.sh              # interactive — prompts for API keys
#   ./setup.sh --from-env   # non-interactive — reads from .env
# ============================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_DIR="$REPO_DIR/mcp-servers"
ENV_FILE="$REPO_DIR/.env"
MCP_JSON="$REPO_DIR/.mcp.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# ── Step 0: Parse args ─────────────────────────────────────
FROM_ENV=false
if [[ "${1:-}" == "--from-env" ]]; then
  FROM_ENV=true
fi

echo ""
echo "========================================="
echo "  Trading Desk — Setup"
echo "========================================="
echo ""

# ── Step 1: Check prerequisites ────────────────────────────
info "Checking prerequisites..."

# Node.js
if ! command -v node &>/dev/null; then
  fail "Node.js not found. Install Node.js 18+: https://nodejs.org"
fi
NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if (( NODE_VERSION < 18 )); then
  fail "Node.js $NODE_VERSION found, need 18+. Update: https://nodejs.org"
fi
ok "Node.js $(node -v)"

# npm
if ! command -v npm &>/dev/null; then
  fail "npm not found. It ships with Node.js."
fi
ok "npm $(npm -v)"

# Python 3
if ! command -v python3 &>/dev/null; then
  fail "Python 3 not found. Install Python 3.10+: https://python.org"
fi
ok "Python $(python3 --version | awk '{print $2}')"

# uv / uvx
if ! command -v uvx &>/dev/null; then
  warn "uvx not found. Installing uv (Python package manager)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # Source the updated PATH
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  if ! command -v uvx &>/dev/null; then
    # Try common install locations
    for p in "$HOME/.local/bin/uvx" "$HOME/.cargo/bin/uvx" "/opt/homebrew/bin/uvx"; do
      if [[ -x "$p" ]]; then
        export PATH="$(dirname "$p"):$PATH"
        break
      fi
    done
  fi
  if ! command -v uvx &>/dev/null; then
    fail "Failed to install uv. Install manually: https://docs.astral.sh/uv/getting-started/installation/"
  fi
fi
ok "uvx $(uvx --version 2>/dev/null || echo 'installed')"

# Claude Code CLI (optional but recommended)
if command -v claude &>/dev/null; then
  ok "Claude Code CLI found"
else
  warn "Claude Code CLI not found. Install: npm install -g @anthropic-ai/claude-code"
  warn "You can still use the repo — just open it in Claude Code Desktop/Web."
fi

echo ""

# ── Step 2: Install TradingView Desktop MCP ────────────────
info "Installing TradingView Desktop MCP server..."

if [[ -d "$MCP_DIR/tradingview-mcp" ]]; then
  info "Already cloned. Pulling latest..."
  cd "$MCP_DIR/tradingview-mcp" && git pull --quiet 2>/dev/null || true
else
  mkdir -p "$MCP_DIR"
  git clone --quiet https://github.com/tradesdontlie/tradingview-mcp.git "$MCP_DIR/tradingview-mcp"
fi

cd "$MCP_DIR/tradingview-mcp"
npm install --silent 2>/dev/null
ok "TradingView Desktop MCP installed"

cd "$REPO_DIR"

# ── Step 3: Verify Python MCP servers ──────────────────────
info "Verifying Python MCP servers (downloaded on first use by uvx)..."

# Pre-fetch so first Claude Code launch is fast
uvx --from tradingview-mcp-server tradingview-mcp --help &>/dev/null 2>&1 || true
ok "TradingView Analysis MCP (tradingview-mcp-server) ready"

uvx alpaca-mcp-server --help &>/dev/null 2>&1 || true
ok "Alpaca MCP (alpaca-mcp-server) ready"

# ── Step 4: Install FMP MCP server ─────────────────────────
info "Installing Financial Modeling Prep MCP server..."

npm install --prefix "$MCP_DIR/fmp" --silent financial-modeling-prep-mcp-server 2>/dev/null
ok "FMP MCP server installed"

echo ""

# ── Step 5: Collect API keys ───────────────────────────────
# Defaults
FMP_KEY=""
ALPACA_KEY=""
ALPACA_SECRET=""
ALPACA_URL="https://paper-api.alpaca.markets/v2"
FMP_PORT_VAL="8080"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE" 2>/dev/null || true
  FMP_KEY="${FMP_ACCESS_TOKEN:-}"
  ALPACA_KEY="${ALPACA_API_KEY:-}"
  ALPACA_SECRET="${ALPACA_SECRET_KEY:-}"
  ALPACA_URL="${ALPACA_BASE_URL:-https://paper-api.alpaca.markets/v2}"
  FMP_PORT_VAL="${FMP_PORT:-8080}"
fi

if [[ "$FROM_ENV" != true ]]; then
  echo "========================================="
  echo "  API Keys Configuration"
  echo "========================================="
  echo ""
  echo "You need API keys for 2 services (both free):"
  echo ""
  echo "  1. Financial Modeling Prep (FMP)"
  echo "     Sign up: https://financialmodelingprep.com/developer"
  echo "     Free tier: ~250 API calls/day"
  echo ""
  echo "  2. Alpaca (Paper Trading)"
  echo "     Sign up: https://app.alpaca.markets/signup"
  echo "     Paper trading: free, no real money"
  echo ""

  read -rp "FMP API Key [${FMP_ACCESS_TOKEN:-}]: " FMP_KEY
  FMP_KEY="${FMP_KEY:-${FMP_ACCESS_TOKEN:-}}"

  read -rp "Alpaca API Key [${ALPACA_API_KEY:-}]: " ALPACA_KEY
  ALPACA_KEY="${ALPACA_KEY:-${ALPACA_API_KEY:-}}"

  read -rp "Alpaca Secret Key [${ALPACA_SECRET_KEY:-}]: " ALPACA_SECRET
  ALPACA_SECRET="${ALPACA_SECRET:-${ALPACA_SECRET_KEY:-}}"

  ALPACA_URL="${ALPACA_BASE_URL:-https://paper-api.alpaca.markets/v2}"
  FMP_PORT_VAL="${FMP_PORT:-8080}"
fi

# Validate we have keys
if [[ -z "${FMP_KEY:-}" ]]; then
  warn "No FMP key provided. FMP tools will not work."
  warn "Get one at: https://financialmodelingprep.com/developer"
fi
if [[ -z "${ALPACA_KEY:-}" ]] || [[ -z "${ALPACA_SECRET:-}" ]]; then
  warn "No Alpaca keys provided. Trading and portfolio tools will not work."
  warn "Get keys at: https://app.alpaca.markets/signup"
fi

# ── Step 6: Write .env ─────────────────────────────────────
info "Writing .env..."
cat > "$ENV_FILE" <<ENVEOF
# Trading Desk — API Keys (generated by setup.sh)
FMP_ACCESS_TOKEN=${FMP_KEY:-}
ALPACA_API_KEY=${ALPACA_KEY:-}
ALPACA_SECRET_KEY=${ALPACA_SECRET:-}
ALPACA_BASE_URL=${ALPACA_URL}
ALPACA_PAPER=true
FMP_PORT=${FMP_PORT_VAL:-8080}
ENVEOF
ok ".env written"

# ── Step 7: Generate .mcp.json ─────────────────────────────
info "Generating .mcp.json..."

# Resolve uvx path (varies by OS/install method)
UVX_PATH="$(command -v uvx)"

cat > "$MCP_JSON" <<MCPEOF
{
  "mcpServers": {
    "tradingview": {
      "command": "node",
      "args": ["$MCP_DIR/tradingview-mcp/src/server.js"]
    },
    "tradingview-analysis": {
      "command": "$UVX_PATH",
      "args": ["--from", "tradingview-mcp-server", "tradingview-mcp"]
    },
    "financial-modeling-prep": {
      "url": "http://localhost:${FMP_PORT_VAL:-8080}/mcp"
    },
    "alpaca": {
      "command": "$UVX_PATH",
      "args": ["alpaca-mcp-server"],
      "env": {
        "ALPACA_API_KEY": "${ALPACA_KEY:-}",
        "ALPACA_SECRET_KEY": "${ALPACA_SECRET:-}",
        "ALPACA_BASE_URL": "${ALPACA_URL}",
        "ALPACA_PAPER": "true"
      }
    }
  }
}
MCPEOF
ok ".mcp.json generated"

# ── Step 8: Create reports directory ───────────────────────
mkdir -p "$REPO_DIR/reports"
if [[ ! -f "$REPO_DIR/reports/scores.csv" ]]; then
  echo "date,symbol,composite,signal,technical,fundamental,valuation,sentiment,smart_money,macro,backtest,risk,data_completeness" > "$REPO_DIR/reports/scores.csv"
fi
ok "reports/ directory ready"

# ── Step 9: Summary ────────────────────────────────────────
echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "  MCP Servers Installed:"
echo "    1. TradingView Desktop  (node, local clone)"
echo "    2. TradingView Analysis (uvx, auto-managed)"
echo "    3. Financial Modeling Prep (npm, HTTP server)"
echo "    4. Alpaca Paper Trading (uvx, auto-managed)"
echo ""
echo "  Next Steps:"
echo ""
echo "    1. Start the FMP server (required before using Claude Code):"
echo ""
echo "       ./start.sh"
echo ""
echo "    2. Open Claude Code in this directory:"
echo ""
echo "       cd $(pwd) && claude"
echo ""
echo "    3. Try a command:"
echo ""
echo "       /project:morning-brief"
echo "       /project:analyze AMD"
echo "       /project:scan watchlist"
echo ""
if [[ -z "${FMP_KEY:-}" ]] || [[ -z "${ALPACA_KEY:-}" ]]; then
  echo "  ⚠ Missing API keys — some features won't work."
  echo "    Edit .env and re-run: ./setup.sh --from-env"
  echo ""
fi
echo "  Optional: TradingView Desktop"
echo "    For chart screenshots, Pine Script, and order book data,"
echo "    open TradingView Desktop before running /project:analyze."
echo "    The analysis works fine without it — those phases are skipped."
echo ""
echo "========================================="
