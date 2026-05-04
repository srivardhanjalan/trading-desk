# Portfolio Dashboard: $ARGUMENTS

Display current Alpaca paper trading portfolio with enriched analysis, risk flags, and earnings warnings.

---

## Step 1: Account & Positions (4 Alpaca calls, parallel)

- `mcp__alpaca__get_account_info` — equity, buying power, cash, pattern day trader status
- `mcp__alpaca__get_all_positions` — all open positions with qty, avg cost, current price, P&L, market value
- `mcp__alpaca__get_portfolio_history` with period="1M", timeframe="1D" — equity curve, daily P&L for last month
- `mcp__alpaca__get_orders` with status="closed", limit=20 — recent order history

---

## Step 2: Activity & Corporate Actions (2 Alpaca calls, parallel)

- `mcp__alpaca__get_account_activities` with limit=20 — fill execution prices, dividend income, interest, fees. Essential for true P&L attribution.
- For each held position symbol: `mcp__alpaca__get_corporate_actions` — check for upcoming splits, dividends, mergers

---

## Step 3: Per-Position Enrichment

For each position (parallel across positions):

**2 calls per position:**
- `mcp__financial-modeling-prep__getQuote` with symbol={position symbol} — latest price, volume, 52W range
- `mcp__tradingview-analysis__coin_analysis` with symbol={position symbol}, exchange, timeframe="1D" — RSI, MACD, support/resistance

Extract per position: current RSI, trend signal, nearest support/resistance.

---

## Step 4: Earnings Cross-Reference

- `mcp__financial-modeling-prep__getEarningsCalendar` with from={today}, to={today + 14 days} — next 2 weeks of earnings (all companies)
- Cross-reference with held position symbols
- Flag: "WARNING: You hold {SYMBOL} — earnings on {DATE}"
- If options data available from a recent /analyze: include expected move

---

## Step 5: Risk Flags

Check each position for:
- **Concentration risk:** Any single position > 20% of portfolio
- **Overbought:** RSI > 70 on any position
- **Wide spread:** Bid/ask spread > 2% (liquidity risk)
- **Earnings proximity:** Earnings within 14 days
- **Extended:** Price > 20% above 50 SMA
- **Corporate actions:** Upcoming splits, reverse splits, mergers
- **Drawdown:** Position P&L worse than -10%

---

## Output

Use the portfolio dashboard template from `_shared/output-formats.md`:

```
=== Portfolio Dashboard === {DATE} ===
{MARKET_HOURS_HEADER}

Account: ${EQUITY} equity | ${BUYING_POWER} buying power | ${CASH} cash
Today: {DAY_PL} ({DAY_PCT}%) | 1W: {WEEK_PL} | 1M: {MONTH_PL}

| Symbol | Qty | Avg Cost | Current | P&L | P&L% | Signal | Alert |
|--------|-----|----------|---------|-----|------|--------|-------|
```

Signal column: Quick technical signal from coin_analysis (BUY/SELL/NEUTRAL).
Alert column: Key flag (earnings, overbought, concentration, etc.).

After table:
- **Alerts section:** All flagged items with details
- **Recent Activity:** Last 5 fills with execution prices
- **Offer:** "Run `/project:analyze {SYMBOL}` for full analysis on any position"
- **Offer:** "Run `/project:trade sell {SYMBOL} {QTY}` to close a position"
