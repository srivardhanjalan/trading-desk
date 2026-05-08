---
description: Daily market briefing — VIX, sector rotation, watchlist score deltas, top gainers/losers
---

# Morning Brief

Daily market briefing with portfolio status, watchlist movers, scanner picks, earnings calendar, and trade ideas.

**~32 total tool calls. Run this at market open for maximum value.**

---

## Step 1: Market Status & Fear Gauge (3 calls, parallel, cached)

- `mcp__plugin_trading-desk_alpaca__get_clock` — is_open, next_open, next_close
- `mcp__plugin_trading-desk_financial-modeling-prep__getIndexQuote` with symbol="^VIX" — VIX value and label
- `mcp__plugin_trading-desk_financial-modeling-prep__getTreasuryRates` — 10Y yield for macro context

---

## Step 2: Market Overview (1 call)

- `mcp__plugin_trading-desk_tradingview-analysis__market_snapshot` — global overview: S&P 500, NASDAQ, Dow, BTC, EUR/USD, key ETFs. Answers "how is the overall market doing?"

---

## Step 3: Portfolio Status (4 Alpaca calls, parallel)

- `mcp__plugin_trading-desk_alpaca__get_account_info` — equity, buying power, day P&L
- `mcp__plugin_trading-desk_alpaca__get_all_positions` — all positions with current P&L
- `mcp__plugin_trading-desk_alpaca__get_portfolio_history` with period="1W", timeframe="1D" — weekly equity curve
- `mcp__plugin_trading-desk_alpaca__get_corporate_actions` — splits/dividends this week across portfolio

Identify: top mover in portfolio (biggest % change), positions with alerts.

---

## Step 4: Watchlist After-Hours & Pre-Market (2 FMP calls)

Default watchlist: Read from `watchlist.csv` in the project root (one symbol per line)

- `mcp__plugin_trading-desk_financial-modeling-prep__getBatchAftermarketQuote` with symbol={watchlist comma-separated} — after-hours/pre-market prices. Earnings are released AH — a stock up 8% on earnings is invisible without this.
- `mcp__plugin_trading-desk_financial-modeling-prep__getBatchQuotes` with symbol={watchlist comma-separated} — current quotes with change%, volume

Flag any stock moving >3% (either direction) in after-hours or current session.

---

## Step 5: Scanners (4 TV-Analysis calls, parallel)

- `mcp__plugin_trading-desk_tradingview-analysis__top_gainers` — biggest gainers on the exchange today
- `mcp__plugin_trading-desk_tradingview-analysis__top_losers` — biggest losers
- `mcp__plugin_trading-desk_tradingview-analysis__volume_breakout_scanner` — stocks breaking out on unusual volume
- `mcp__plugin_trading-desk_tradingview-analysis__bollinger_scan` — Bollinger Band squeezes (volatility contraction → expansion imminent)

Extract top 3 from each scanner.

---

## Step 6: News (1 TV-Analysis call)

- `mcp__plugin_trading-desk_tradingview-analysis__financial_news` — top financial news headlines

Extract top 5 most relevant headlines. Flag any that mention watchlist or portfolio stocks.

---

## Step 7: Earnings Calendar (1 FMP call)

- `mcp__plugin_trading-desk_financial-modeling-prep__getEarningsCalendar` with from={today}, to={today + 7 days} — this week's earnings

Cross-reference with:
- Portfolio positions → "WARNING: You hold {SYMBOL} — earnings on {DATE}"
- Watchlist stocks → "{SYMBOL} reports on {DATE}"

If options data from recent /analyze exists, include expected move.

---

## Step 8: Trade Ideas

Based on all collected data, identify top 2 trade setups:

1. **Watchlist stock with strongest signal:** Best technical setup from scanner intersection (showing up in multiple scanners) + favorable fundamentals from last scan
2. **Portfolio management:** Any position that should be trimmed (overbought, earnings risk) or added to (oversold bounce setup)

For each idea: brief reasoning, entry/target/stop if obvious, suggest `/trading-desk:analyze {SYMBOL}` for full analysis.

---

## Output

Use the morning brief template from `${CLAUDE_PLUGIN_ROOT}/lib/output-formats.md`:

```
=== Morning Brief === {DATE} ===
{MARKET_HOURS_HEADER}

MARKET OVERVIEW
{S&P, NASDAQ, DOW, BTC, EUR/USD summary from market_snapshot}
VIX: {VIX} ({label}) | 10Y: {YIELD}%

PORTFOLIO ({COUNT} positions)
Today: {DAY_PL} ({DAY_PCT}%) | Equity: ${EQUITY}
{Top mover: SYMBOL +/-X%}
{Alerts if any}

WATCHLIST MOVERS (>3% change)
{Symbol: price, change%, AH price if different}

SCANNERS
Top Gainers: {top 3}
Volume Breakouts: {top 3}
Bollinger Squeezes: {top 3}

EARNINGS THIS WEEK
{Date: Symbol (portfolio/watchlist flag)}

CORPORATE ACTIONS
{Splits, dividends, mergers affecting portfolio}

NEWS HIGHLIGHTS
{Top 5 headlines, starred if mentioning portfolio/watchlist}

TRADE IDEAS
1. {Setup with reasoning}
2. {Setup with reasoning}
```
