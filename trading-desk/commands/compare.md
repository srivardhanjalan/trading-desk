---
description: Side-by-side comparison of two symbols across all 8 scoring dimensions
argument-hint: "[SYMBOL_A] [SYMBOL_B]"
---

# Compare: $ARGUMENTS

Side-by-side comparison of two stocks across all 8 scoring dimensions.

**Usage:** `/trading-desk:compare AMD NVDA`

**Parse $ARGUMENTS:** Extract two symbols separated by space.

---

## Step 1: Run Condensed Analysis on Both (parallel)

For EACH symbol, run these calls in parallel (same as /scan per-stock analysis):

**Per symbol (6 FMP + 2 TV-Analysis = 8 calls):**
- `mcp__plugin_trading-desk_financial-modeling-prep__getCompanyProfile` — price, change, marketCap, beta, sector, P/E
- `mcp__plugin_trading-desk_financial-modeling-prep__getStockPriceChange` — momentum across timeframes
- `mcp__plugin_trading-desk_financial-modeling-prep__getFinancialRatiosTTM` — P/E, margins, debt/equity, ROE, FCF
- `mcp__plugin_trading-desk_financial-modeling-prep__getFinancialScores` — Piotroski + Z-Score
- `mcp__plugin_trading-desk_financial-modeling-prep__getDCFValuation` — intrinsic value
- `mcp__plugin_trading-desk_financial-modeling-prep__getPriceTargetSummary` — analyst consensus + count
- `mcp__plugin_trading-desk_tradingview-analysis__coin_analysis` (symbol, exchange, "1D") — RSI, MACD, trend, support/resistance
- `mcp__plugin_trading-desk_tradingview-analysis__compare_strategies` (symbol, period="1y") — best strategy + win rate

**Run BOTH symbols in parallel** = 16 calls total (+ 2 cached macro calls).

---

## Step 2: Macro Context (cached, 2 calls)

- `mcp__plugin_trading-desk_financial-modeling-prep__getIndexQuote` with symbol="^VIX"
- `mcp__plugin_trading-desk_financial-modeling-prep__getTreasuryRates`

---

## Step 3: Score Both Stocks

For each stock, apply `${CLAUDE_PLUGIN_ROOT}/lib/scoring-rubrics.md` quick scoring:

1. **Technical** — RSI position, MACD signal, timeframe trend from coin_analysis
2. **Fundamental** — Piotroski, Z-Score, margins, ROE
3. **Valuation** — DCF upside %, analyst target distance, P/E relative
4. **Sentiment** — Quick signal from coin_analysis recommendation
5. **Smart Money** — Short interest if available from profile
6. **Macro** — Same for both (sector context)
7. **Backtest** — Best strategy return and win rate
8. **Risk** — Beta, RSI extremes, position sizing impact

Calculate quick composite for each.

---

## Step 4: Head-to-Head Comparison

Build comparison table with winner per metric:

```
=== {SYM1} vs {SYM2} === {DATE} ===
{MARKET_HOURS_HEADER}

| Metric | {SYM1} | {SYM2} | Winner |
|--------|--------|--------|--------|
| Price | ${X} | ${Y} | - |
| Market Cap | ${X}B | ${Y}B | - |
| 1D Change | X% | Y% | {better} |
| 1M Change | X% | Y% | {better} |
| 1Y Change | X% | Y% | {better} |
| Beta | X | Y | {lower = less risk} |
| P/E | X | Y | {context-dependent} |
| ROE | X% | Y% | {higher} |
| Piotroski | X/9 | Y/9 | {higher} |
| Z-Score | X | Y | {higher} |
| DCF Upside | X% | Y% | {higher} |
| Analyst Target | ${X} (Y%) | ${X} (Y%) | {higher upside} |
| RSI | X | Y | {context} |
| Best Strategy | X% return | Y% return | {higher} |
|--------|--------|--------|--------|
| **Technical** | X/10 | Y/10 | {higher} |
| **Fundamental** | X/10 | Y/10 | {higher} |
| **Valuation** | X/10 | Y/10 | {higher} |
| **Sentiment** | X/10 | Y/10 | {higher} |
| **Smart Money** | X/10 | Y/10 | {higher} |
| **Macro** | X/10 | Y/10 | {higher} |
| **Backtest** | X/10 | Y/10 | {higher} |
| **Risk** | X/10 | Y/10 | {higher} |
|--------|--------|--------|--------|
| **Composite** | X/100 | Y/100 | **{WINNER}** |
| **Signal** | {BUY/HOLD/SELL} | {BUY/HOLD/SELL} | |
```

---

## Step 5: Verdict

Provide a clear recommendation:

- **Which is the better buy right now and why** (2-3 sentences)
- **When you'd prefer the other** — different market conditions or time horizons where the losing stock would be preferable
- **Key differentiators** — the 1-2 metrics that most separate them

Offer: "Run `/trading-desk:analyze {SYMBOL}` for full 16-phase analysis on either stock"
