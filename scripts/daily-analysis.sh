#!/bin/bash
# Daily Stock Analysis Automation
# Runs at 12:15 AM PDT — full /trading-desk:analyze on every stock in the watchlist
#
# FMP rate limit: 300 calls/minute (paid plan, no daily cap)
# Each stock takes ~55-73 tool calls across all MCPs, well under 300/min
#
# Prerequisites:
#   1. claude CLI installed and authenticated
#   2. trading-desk repo at $TRADING_DESK (contains the plugin source under trading-desk/)
#   3. .env at ~/workspace/secrets/trading-desk/.env (FMP_ACCESS_TOKEN, ALPACA_*)
#   4. FMP server running on :8080 (start via /trading-desk:setup once, OR ./start.sh)
#   5. TradingView Desktop (optional — auto-launched here for chart screenshots + order book)

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
TRADING_DESK="/Users/srivardhanjalan/workspace/trading-desk"
PLUGIN_DIR="$TRADING_DESK/trading-desk"
ENV_FILE="$HOME/workspace/secrets/trading-desk/.env"
LOG_DIR="$TRADING_DESK/reports/logs"
WATCHLIST_FILE="$TRADING_DESK/examples/watchlist.csv"

# Source .env so the plugin's MCP servers get FMP/Alpaca keys at startup
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
else
    echo "FATAL: $ENV_FILE missing. Run /trading-desk:setup once." >&2
    exit 1
fi

mapfile -t WATCHLIST < <(grep -v '^\s*$' "$WATCHLIST_FILE")
DELAY_BETWEEN_STOCKS=5     # Seconds between analyses
MAX_BUDGET_PER_STOCK=8     # USD budget cap per claude -p invocation

DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOG_DIR/analysis_${DATE}.log"

mkdir -p "$LOG_DIR"
mkdir -p "$TRADING_DESK/reports"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "═══ Daily Analysis Started ═══"
log "Date: $DATE | Stocks: ${#WATCHLIST[@]} | Plugin: $PLUGIN_DIR"

# ─── Step 0a: Launch TradingView Desktop with CDP ────────────────────────────
if pgrep -x "TradingView" > /dev/null 2>&1; then
    log "TradingView Desktop already running"
else
    log "Launching TradingView Desktop with CDP (port 9222)..."
    open -a TradingView --args --remote-debugging-port=9222 2>/dev/null || true
    TV_STARTED=true
    for i in $(seq 1 30); do
        if curl -s http://localhost:9222/json > /dev/null 2>&1; then
            log "TradingView Desktop ready (CDP active on port 9222)"
            break
        fi
        sleep 1
    done
    if ! curl -s http://localhost:9222/json > /dev/null 2>&1; then
        log "WARNING: TradingView Desktop not responding. Charts may be unavailable."
    fi
fi

# ─── Step 0b: Verify FMP server is running on :8080 ──────────────────────────
log "Checking FMP server on :8080..."
if curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8080/mcp \
   -H "Content-Type: application/json" \
   -H "Accept: application/json, text/event-stream" \
   -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"daily","version":"1"}}}' 2>/dev/null | grep -qE "^[24]"; then
    log "FMP server responding on :8080"
else
    log "FMP server not running. Attempting ./start.sh fallback..."
    if [ -x "$TRADING_DESK/start.sh" ]; then
        (cd "$TRADING_DESK" && ./start.sh) 2>&1 | tee -a "$LOG_FILE" || true
        FMP_STARTED=true
    fi
    if ! curl -s -o /dev/null http://localhost:8080/mcp 2>/dev/null; then
        log "WARNING: FMP server still not responding. FMP-dependent phases will fail."
    fi
fi

# ─── Step 1: Full analysis on every stock ─────────────────────────────────────
log "Running full /trading-desk:analyze on all ${#WATCHLIST[@]} stocks..."

COMPLETED=0
FAILED=0
RESULTS=()

for i in "${!WATCHLIST[@]}"; do
    STOCK="${WATCHLIST[$i]}"
    IDX=$((i + 1))
    log "─── [$IDX/${#WATCHLIST[@]}] Analyzing: $STOCK ───"

    START_TIME=$(date +%s)

    if claude -p \
        --plugin-dir "$PLUGIN_DIR" \
        --permission-mode auto \
        --max-budget-usd "$MAX_BUDGET_PER_STOCK" \
        --no-session-persistence \
        "/trading-desk:analyze ${STOCK}

This is an automated nightly analysis (${IDX}/${#WATCHLIST[@]}).
TradingView Desktop is running with CDP on port 9222 — use all Desktop phases (screenshots, order book, chart annotations).
At the very end of your output, print a single line: RESULT:${STOCK}:<SCORE>:<SIGNAL>
where SCORE is the composite 0-100 and SIGNAL is STRONG_BUY/BUY/HOLD/SELL/STRONG_SELL.
Example: RESULT:AMD:72:BUY" \
        2>>"$LOG_FILE" > "$TRADING_DESK/reports/${STOCK}_output_${DATE}.txt"; then

        RESULT_LINE=$(grep -o "RESULT:${STOCK}:.*" "$TRADING_DESK/reports/${STOCK}_output_${DATE}.txt" | head -1 || echo "")
        if [ -n "$RESULT_LINE" ]; then
            RESULTS+=("$RESULT_LINE")
            log "✓ ${STOCK} complete — ${RESULT_LINE}"
        else
            RESULTS+=("RESULT:${STOCK}:??:UNKNOWN")
            log "✓ ${STOCK} complete (could not parse score)"
        fi
        COMPLETED=$((COMPLETED + 1))
    else
        log "✗ ${STOCK} failed (exit code: $?)"
        RESULTS+=("RESULT:${STOCK}:FAIL:ERROR")
        FAILED=$((FAILED + 1))
    fi

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    log "   Duration: ${ELAPSED}s"

    if [ "$IDX" -lt "${#WATCHLIST[@]}" ]; then
        sleep "$DELAY_BETWEEN_STOCKS"
    fi
done

# ─── Step 2: Generate daily summary ──────────────────────────────────────────
log "Generating daily summary..."

RESULTS_STR=$(printf '%s\n' "${RESULTS[@]}")

claude -p \
    --plugin-dir "$PLUGIN_DIR" \
    --permission-mode auto \
    --max-budget-usd 2 \
    --model sonnet \
    --no-session-persistence \
    "Read all report files in $TRADING_DESK/reports/ matching *_${DATE}.md.
Also here are the parsed results from tonight's run:

${RESULTS_STR}

Generate a concise daily summary at $TRADING_DESK/reports/daily-summary_${DATE}.md with:
1. Market conditions (VIX, macro from the reports)
2. Ranked table of all ${#WATCHLIST[@]} stocks sorted by composite score
3. Highlight any BUY or STRONG_BUY signals with key catalysts
4. Highlight any SELL or STRONG_SELL signals with key risks
5. Score deltas vs prior run if $TRADING_DESK/reports/scores.csv has historical data
6. Top 3 actionable trades for tomorrow" \
    2>>"$LOG_FILE" >> "$LOG_FILE"

# ─── Summary ─────────────────────────────────────────────────────────────────
log ""
log "═══ Daily Analysis Complete ═══"
log "Analyzed: ${COMPLETED}/${#WATCHLIST[@]} | Failed: ${FAILED}"
log ""
log "Results:"
for R in "${RESULTS[@]}"; do
    log "  $R"
done
log ""
log "Reports: $TRADING_DESK/reports/"
log "Summary: reports/daily-summary_${DATE}.md"
log "Full log: $LOG_FILE"

# Stop FMP server if we started it
if [ "${FMP_STARTED:-false}" = true ]; then
    (cd "$TRADING_DESK" && ./start.sh --stop) 2>&1 | tee -a "$LOG_FILE" || true
fi

# Quit TradingView Desktop if we started it
if [ "${TV_STARTED:-false}" = true ]; then
    osascript -e 'quit app "TradingView"' 2>/dev/null && log "TradingView Desktop closed" || true
fi
