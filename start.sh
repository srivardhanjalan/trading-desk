#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Trading Desk — Start FMP Server
# ============================================================
# Starts the Financial Modeling Prep MCP server in the background.
# Run this before opening Claude Code.
#
# Usage:
#   ./start.sh          # start FMP server
#   ./start.sh --stop   # stop FMP server
#   ./start.sh --status # check if running
# ============================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$REPO_DIR/.env"
FMP_DIR="$REPO_DIR/mcp-servers/fmp"
PID_FILE="$REPO_DIR/.fmp.pid"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load .env
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

FMP_PORT="${FMP_PORT:-8080}"
FMP_TOKEN="${FMP_ACCESS_TOKEN:-}"

# ── Stop command ───────────────────────────────────────────
if [[ "${1:-}" == "--stop" ]]; then
  if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID"
      rm -f "$PID_FILE"
      echo -e "${GREEN}[OK]${NC} FMP server stopped (PID $PID)"
    else
      rm -f "$PID_FILE"
      echo -e "${YELLOW}[WARN]${NC} PID file found but process not running. Cleaned up."
    fi
  else
    echo -e "${YELLOW}[WARN]${NC} No PID file found. FMP server may not be running."
    # Try to find and kill any fmp-mcp process
    pkill -f "fmp-mcp" 2>/dev/null && echo -e "${GREEN}[OK]${NC} Killed fmp-mcp process" || true
  fi
  exit 0
fi

# ── Status command ─────────────────────────────────────────
if [[ "${1:-}" == "--status" ]]; then
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo -e "${GREEN}[RUNNING]${NC} FMP server on port $FMP_PORT (PID $(cat "$PID_FILE"))"
  else
    echo -e "${RED}[STOPPED]${NC} FMP server is not running"
  fi
  exit 0
fi

# ── Start command ──────────────────────────────────────────

# Check if already running
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo -e "${GREEN}[OK]${NC} FMP server already running on port $FMP_PORT (PID $(cat "$PID_FILE"))"
  exit 0
fi

# Validate
if [[ -z "$FMP_TOKEN" ]]; then
  echo -e "${RED}[FAIL]${NC} No FMP_ACCESS_TOKEN in .env. Run ./setup.sh first."
  exit 1
fi

if [[ ! -d "$FMP_DIR/node_modules" ]]; then
  echo -e "${RED}[FAIL]${NC} FMP server not installed. Run ./setup.sh first."
  exit 1
fi

# Check if port is in use
if lsof -i :"$FMP_PORT" &>/dev/null; then
  echo -e "${YELLOW}[WARN]${NC} Port $FMP_PORT already in use. Checking if it's FMP..."
  if curl -s "http://localhost:$FMP_PORT/mcp" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} FMP server already running on port $FMP_PORT"
    exit 0
  else
    echo -e "${RED}[FAIL]${NC} Port $FMP_PORT in use by another process. Change FMP_PORT in .env"
    exit 1
  fi
fi

# Start FMP server in background
echo -e "Starting FMP server on port $FMP_PORT..."

FMP_ACCESS_TOKEN="$FMP_TOKEN" npx --prefix "$FMP_DIR" \
  fmp-mcp --port "$FMP_PORT" &>/dev/null &

FMP_PID=$!
echo "$FMP_PID" > "$PID_FILE"

# Wait for server to be ready (max 15 seconds)
for i in $(seq 1 15); do
  if curl -s "http://localhost:$FMP_PORT/mcp" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} FMP server running on port $FMP_PORT (PID $FMP_PID)"
    echo ""
    echo "  Ready to use Claude Code. Open in this directory:"
    echo "    claude"
    echo ""
    echo "  Stop later with:"
    echo "    ./start.sh --stop"
    exit 0
  fi
  sleep 1
done

# If we get here, server didn't start
echo -e "${YELLOW}[WAIT]${NC} FMP server starting (PID $FMP_PID)... may need a few more seconds."
echo "  Check status: ./start.sh --status"
echo "  If it fails, check: FMP_ACCESS_TOKEN is valid in .env"
