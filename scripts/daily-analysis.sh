#!/bin/bash
# Daily Stock Analysis Automation
# Runs at 12:15 AM PDT — full /project:analyze on every stock in the watchlist
#
# FMP rate limit: 300 calls/minute (paid plan, no daily cap)
# Each stock takes ~55-73 tool calls across all MCPs, well under 300/min
#
# Prerequisites:
#   1. claude CLI installed and authenticated
#   2. trading-desk repo pulled with .claude/commands/ present
#   3. .env configured in trading-desk/ (FMP_ACCESS_TOKEN, etc.)
#   4. TradingView Desktop auto-launched with CDP for chart screenshots + order book

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
TRADING_DESK="/Users/srivardhanjalan/workspace/trading-desk"
LOG_DIR="$TRADING_DESK/reports/logs"

# Read watchlist from file (one symbol per line, skip blank lines)
mapfile -t WATCHLIST < <(grep -v '^\s*$' "$TRADING_DESK/watchlist.csv")
DELAY_BETWEEN_STOCKS=5     # Seconds between analyses (breathing room)
MAX_BUDGET_PER_STOCK=8     # USD budget cap per claude -p invocation

DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOG_DIR/analysis_${DATE}.log"

# ─── Setup ────────────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"
mkdir -p "$TRADING_DESK/reports"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "═══ Daily Analysis Started ═══"
log "Date: $DATE | Stocks: ${#WATCHLIST[@]} | FMP limit: 300/min (no daily cap)"

# ─── Step 0a: Launch TradingView Desktop with CDP ────────────────────────────
if pgrep -x "TradingView" > /dev/null 2>&1; then
    log "TradingView Desktop already running"
else
    log "Launching TradingView Desktop with CDP (port 9222)..."
    open -a TradingView --args --remote-debugging-port=9222
    TV_STARTED=true
    # Wait for app to fully load and CDP to be ready
    for i in $(seq 1 30); do
        if curl -s http://localhost:9222/json > /dev/null 2>&1; then
            log "TradingView Desktop ready (CDP active on port 9222)"
            break
        fi
        sleep 1
    done
    if ! curl -s http://localhost:9222/json > /dev/null 2>&1; then
        log "WARNING: TradingView Desktop launched but CDP not responding. Charts may be unavailable."
    fi
fi

# ─── Step 0b: Start FMP server using trading-desk's start.sh ─────────────────
log "Starting FMP server..."
cd "$TRADING_DESK"

if ./start.sh --status 2>&1 | grep -q "RUNNING"; then
    log "FMP server already running"
else
    ./start.sh 2>&1 | tee -a "$LOG_FILE"
    FMP_STARTED=true
fi

# ─── Step 1: Full analysis on every stock ─────────────────────────────────────
log "Running full /project:analyze on all ${#WATCHLIST[@]} stocks..."

COMPLETED=0
FAILED=0
RESULTS=()

for i in "${!WATCHLIST[@]}"; do
    STOCK="${WATCHLIST[$i]}"
    IDX=$((i + 1))
    log "─── [$IDX/${#WATCHLIST[@]}] Analyzing: $STOCK ───"

    START_TIME=$(date +%s)

    # Run claude from trading-desk/ so /project: commands are discovered
    if claude -p \
        --permission-mode auto \
        --max-budget-usd "$MAX_BUDGET_PER_STOCK" \
        --no-session-persistence \
        "/project:analyze ${STOCK}

This is an automated nightly analysis (${IDX}/${#WATCHLIST[@]}).
TradingView Desktop is running with CDP on port 9222 — use all Desktop phases (screenshots, order book, chart annotations).
At the very end of your output, print a single line: RESULT:${STOCK}:<SCORE>:<SIGNAL>
where SCORE is the composite 0-100 and SIGNAL is STRONG_BUY/BUY/HOLD/SELL/STRONG_SELL.
Example: RESULT:AMD:72:BUY" \
        2>>"$LOG_FILE" > "$TRADING_DESK/reports/${STOCK}_output_${DATE}.txt"; then

        # Extract result line
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

    # Brief pause between stocks
    if [ "$IDX" -lt "${#WATCHLIST[@]}" ]; then
        sleep "$DELAY_BETWEEN_STOCKS"
    fi
done

# ─── Step 2: Generate daily summary ──────────────────────────────────────────
log "Generating daily summary..."

RESULTS_STR=$(printf '%s\n' "${RESULTS[@]}")

claude -p \
    --permission-mode auto \
    --max-budget-usd 2 \
    --model sonnet \
    --no-session-persistence \
    "Read all report files in reports/ matching *_${DATE}.md.
Also here are the parsed results from tonight's run:

${RESULTS_STR}

Generate a concise daily summary at reports/daily-summary_${DATE}.md with:
1. Market conditions (VIX, macro from the reports)
2. Ranked table of all ${#WATCHLIST[@]} stocks sorted by composite score
3. Highlight any BUY or STRONG_BUY signals with key catalysts
4. Highlight any SELL or STRONG_SELL signals with key risks
5. Score deltas vs prior run if reports/scores.csv has historical data
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
    ./start.sh --stop 2>&1 | tee -a "$LOG_FILE"
fi

# Quit TradingView Desktop if we started it
if [ "${TV_STARTED:-false}" = true ]; then
    osascript -e 'quit app "TradingView"' 2>/dev/null && log "TradingView Desktop closed" || true
fi
