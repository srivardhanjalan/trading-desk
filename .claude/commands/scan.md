# Watchlist Scan: $ARGUMENTS

Scan multiple stocks with condensed analysis and rank by composite score.

**Usage:**
- `/project:scan watchlist` — scan the default 16-stock watchlist
- `/project:scan AAPL,MSFT,NVDA` — scan specific symbols
- `/project:scan discover` — use FMP stockScreener to find NEW stocks, then analyze top 10

**Default watchlist:** ALMU, AMD, CRDO, FIX, ASX, KLTR, FLTCF, NVT, CDNS, AMPX, BBAI, LAW, SATS, GEV, BE, KGS

**Budget:** ~6 FMP calls per stock + 2 TV-Analysis = 8 calls/stock. 16 stocks = 99 FMP calls + 32 TV-Analysis calls.

---

## Setup

1. Read `_shared/error-handling.md` for FMP tier-aware degradation
2. Read `_shared/scoring-rubrics.md` for quick scoring
3. Parse $ARGUMENTS to determine mode:
   - "watchlist" or empty → use default watchlist
   - Comma-separated symbols → use those
   - "discover" → discovery mode

---

## Discovery Mode (if $ARGUMENTS = "discover")

**1 FMP call to find candidates:**
- Call `mcp__financial-modeling-prep__stockScreener` with:
  - marketCapMoreThan=1000000000 ($1B+)
  - volumeMoreThan=500000
  - sector="Technology" (or user-specified)
  - betaLessThan=2.5
  - limit=20

Take top 10 results by volume/momentum. Proceed to scan these 10 stocks.

---

## Macro Context (1x, cached for all stocks)

**3 FMP calls, parallel:**
- `mcp__financial-modeling-prep__getTreasuryRates` — yields, curve shape
- `mcp__financial-modeling-prep__getIndexQuote` with symbol="^VIX" — fear gauge
- `mcp__alpaca__get_clock` — market hours

---

## Per-Stock Analysis (for each symbol in the list)

**6 FMP + 2 TV-Analysis calls per stock, parallel where possible:**

- `mcp__financial-modeling-prep__getCompanyProfile` — price, change, volume, marketCap, beta, sector, isEtf, isAdr
- `mcp__financial-modeling-prep__getStockPriceChange` — multi-period momentum (1D/1M/3M/6M/1Y)
- `mcp__financial-modeling-prep__getFinancialRatiosTTM` — P/E, margins, debt/equity, ROE
- `mcp__financial-modeling-prep__getFinancialScores` — Piotroski + Z-Score
- `mcp__financial-modeling-prep__getDCFValuation` — intrinsic value estimate
- `mcp__financial-modeling-prep__getPriceTargetSummary` — analyst consensus + count
- `mcp__tradingview-analysis__coin_analysis` (symbol, exchange, "1D") — RSI, MACD, support/resistance
- `mcp__tradingview-analysis__compare_strategies` (symbol, period="1y") — best strategy + return

### FMP Tier-Aware Degradation

For each stock, fire all 6 FMP calls in parallel. Handle responses:
- **Full tier:** All 6 return data → score all dimensions
- **Partial tier:** Some return 402 → score available dimensions, mark others N/A. Normalize: composite = weighted_sum / sum_of_available_weights * 100
- **Minimal tier:** Most 402 (OTC/micro-cap) → getCompanyProfile + TV-Analysis only. Technical-only score. Rank separately.

### Quick Scoring Per Stock

Score 5 quick dimensions (simplified from full 8):
1. **Technical** (from coin_analysis): RSI position + MACD signal + trend
2. **Fundamental** (from ratiosTTM + financialScores): Piotroski + Z-Score + margins
3. **Valuation** (from DCF + priceTarget): DCF upside + analyst target distance
4. **Backtest** (from compare_strategies): best strategy return + win rate
5. **Risk** (from profile): beta + RSI extremes

Quick composite = weighted average of available dimensions, scaled to 0-100.

---

## Batch Chart Screenshots (if TradingView Desktop running)

- Call `mcp__tradingview__tv_health_check`
- If connected: call `mcp__tradingview__batch_run` with symbols={all symbols in list}, action="screenshot"
- One call screenshots ALL charts instead of individual calls per stock

---

## Output

Use the scan table template from `_shared/output-formats.md`:

```
=== Watchlist Scan === {DATE} === {COUNT} stocks ===
{MARKET_HOURS_HEADER}
FMP Budget: {USED}/250 calls today (estimated)

| # | Symbol | Price | 1D% | Score | Signal | Tech | Fund | Val | Risk | Coverage | Key Signal |
|---|--------|-------|-----|-------|--------|------|------|-----|------|----------|------------|
```

Sort by composite score (descending). Group by coverage tier (Full above Partial above Minimal).

After table:
- **Top Picks:** Top 3 with brief reasoning
- **Flagged:** Stocks with upcoming earnings, extreme RSI, or high risk
- **Offer:** "Run `/project:analyze {SYMBOL}` for full 16-phase deep dive on any stock"

### Budget Tracking

Display estimated FMP calls used this session:
- Macro (cached): 3
- Per stock: 6 × {count}
- Total: 3 + (6 × count)
- Remaining: ~250 - total
