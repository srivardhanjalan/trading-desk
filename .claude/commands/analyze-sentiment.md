# Sentiment & Options Analysis: $ARGUMENTS

Run Phases 10, 11, 12, 13, 14 for the given symbol. This is a standalone entry point for sentiment, options, institutional, and backtesting analysis.

**Before starting:** Read `.claude/commands/_shared/error-handling.md`. If running standalone, you'll need the current price from `mcp__financial-modeling-prep__getCompanyProfile` for options chain filtering.

---

## Phase 10: Options Flow & Implied Volatility

### Step 1 — Pull chain data (3 calls, parallel)

Get the current price first (from Phase 1 data or a quick `getCompanyProfile` call).

- Call `mcp__alpaca__get_option_chain` with:
  - underlying_symbol=$ARGUMENTS
  - type="call"
  - strike_price_gte={price * 0.9} (ATM - 10%)
  - strike_price_lte={price * 1.1} (ATM + 10%)
  - expiration_date_gte={today YYYY-MM-DD}
  - expiration_date_lte={today + 45 days YYYY-MM-DD}
  - limit=50

- Call `mcp__alpaca__get_option_chain` with same params but type="put"

- Call `mcp__financial-modeling-prep__getStandardDeviation` with:
  - symbol=$ARGUMENTS
  - periodLength=30
  - timeframe="1day"
  - from_date={30 days ago YYYY-MM-DD}
  - to={today YYYY-MM-DD}
  - **MUST include date filters** — without them response is 269KB

If `get_option_chain` returns empty: note "No options market for $ARGUMENTS", use HV only, set options-derived scores to N/A.

### Step 2 — Premium trending (1 call, sequential after Step 1)

- Identify the top 3 contracts by volume from Step 1 results (across both calls and puts)
- Call `mcp__alpaca__get_option_bars` with:
  - symbols={top 3 contract symbols, comma-separated}
  - timeframe="1Day"
  - start={7 days ago YYYY-MM-DD}
- Shows 7-day daily OHLCV for highest-volume contracts. Rising call premiums = bullish momentum. Rising put premiums = increasing fear.

### Step 3 — Derived analysis (computed, no additional calls)

Calculate these 10 metrics from the chain data:

| Metric | Calculation |
|--------|-------------|
| **Put/Call Volume Ratio** | sum(put volume) / sum(call volume). >1.0 = bearish, <0.7 = bullish, 0.7-1.0 = neutral |
| **Put/Call OI Ratio** | sum(put OI) / sum(call OI). More stable than volume. >1.2 = sustained bearish |
| **IV Skew** | Avg put IV (ATM +/-2 strikes) - avg call IV (ATM +/-2 strikes). Positive = fear premium. >5% = significant |
| **Max Pain** | Strike where sum of all (call OI * max(0, strike-S) + put OI * max(0, S-strike)) is minimized across all strikes S. Price magnet near expiry. |
| **IV vs HV** | Avg chain IV / HV from getStandardDeviation. >1.5 = expects big move. <0.8 = complacent. ~1.0 = normal |
| **Expected Move** | ATM call premium + ATM put premium (nearest expiry straddle). E.g., "$12.50 = +/-7.8%" |
| **Unusual Activity** | Contracts where today's volume > 5x open interest. Report: strike, expiry, direction, vol/OI ratio |
| **Most Active Strikes** | Top 3 call and top 3 put strikes by volume. Clustering = institutional price targets |
| **Premium Trend** | From `get_option_bars`: 7-day price change % for top 3 contracts. Rising/falling conviction |
| **Net Delta Exposure** | sum(call OI * call delta) - sum(put OI * abs(put delta)). Positive = market net long. Magnitude = conviction |

---

## Phase 11: Sentiment & Insider/Political Activity

### Step 1 — Multi-platform sentiment + news (10-12 calls, parallel)

- `mcp__tradingview-analysis__market_sentiment` with symbol=$ARGUMENTS, market="stocks" — Reddit sentiment across r/stocks, r/wsb, r/investing, r/options
- `mcp__tradingview-analysis__multi_agent_analysis` with symbol=$ARGUMENTS, exchange from Phase 1, timeframe="1D" — 3-agent debate: Technical + Sentiment + Risk Manager
- `mcp__financial-modeling-prep__getStockNews` with symbol=$ARGUMENTS, limit=5 — headlines with URLs (URLs used in Step 2)
- `WebSearch` query: "$ARGUMENTS stock twitter sentiment {current_year}" — Twitter/X sentiment (fastest-moving platform)
- `WebSearch` query: "$ARGUMENTS site:stocktwits.com" — StockTwits sentiment (has built-in bullish/bearish tagging)
- `mcp__financial-modeling-prep__searchInsiderTrades` with symbol=$ARGUMENTS, limit=10 — insider buys/sells with $ amounts. Derive net buy/sell ratio. Weight by: C-suite buys >$1M = strong signal.
- **10b5-1 verification (REQUIRED):** FMP does not return 10b5-1 plan status. After getting insider trades, run `WebSearch` query: `{SYMBOL} "{INSIDER_NAME}" 10b5-1 plan {year} SEC Form 4` for each insider with sales >$1M. The SEC Form 4 footnotes explicitly state whether sales were under a pre-arranged Rule 10b5-1 plan and the plan adoption date. Report as **confirmed 10b5-1** (with adoption date) or **discretionary sale** — never say "likely."
- `mcp__financial-modeling-prep__getSenateTrades` with symbol=$ARGUMENTS — always called. Empty = "No Senate activity"
- `mcp__financial-modeling-prep__getHouseTrades` with symbol=$ARGUMENTS — always called. Empty = "No House activity"
- `mcp__financial-modeling-prep__getEarningsCalendar` with from={today}, to={today + 30 days} — returns ALL companies' earnings (no symbol filter). Must search response for $ARGUMENTS. Alternatively, use `getEarningsReports` from Phase 9 for per-symbol dates.
- `mcp__alpaca__get_corporate_actions` with symbol=$ARGUMENTS — upcoming splits, dividends, spin-offs, mergers within 30 days. Reverse split could trigger stop-losses. Feeds into Risk scoring.

**Crypto route:** `market_sentiment` + `multi_agent_analysis` + `mcp__financial-modeling-prep__searchCryptoNews` + `WebSearch` Twitter. Skip insider/congressional/corporate actions.

### Step 2 — Full-text news NLP (2-3 calls, sequential after Step 1)

- Take the top 2-3 news article URLs from `getStockNews` response
- Call `WebFetch` on each URL
- For each article, analyze: key facts, sentiment (positive/negative/neutral), impact magnitude (high/medium/low), time horizon
- Apply source credibility tiers: Tier 1 (Reuters, Bloomberg, WSJ) = 1.0x weight, Tier 2 (CNBC, Yahoo Finance) = 0.8x, Tier 3 (blogs, unknown) = 0.5x

**Why full-text matters:** Headlines are often clickbait. A "Stock drops 5%" headline might be planned dilution (bad) or profit-taking after +30% run (neutral). Only the article body reveals the actual signal.

---

## Phase 12: Institutional Ownership

**1 call:**
- Call `mcp__financial-modeling-prep__getPositionsSummary` with symbol=$ARGUMENTS, year={current year}, quarter={adjusted quarter}

**13F filing lag (45 days):** Adjust quarter:
- Jan-Mar → use Q3 of previous year
- Apr-Jun → use Q4 of previous year
- Jul-Sep → use Q1 of current year
- Oct-Dec → use Q2 of current year

Extract: number of institutional holders, changes in share count, total investment value.
Empty = "No institutional data this quarter" (normal for micro-caps).

---

## Phase 13: Earnings Deep Dive

**0-1 call (conditional):**
- Call `mcp__financial-modeling-prep__getEarningsTranscript` with symbol=$ARGUMENTS, year={most recent earnings year}, quarter={most recent earnings quarter}
- **Only fetch if:** earnings within 30 days (from Phase 11 calendar) OR analyzing most recent quarter. Skip otherwise to manage context size (transcripts are 50-100KB).
- If fetched: analyze for tone (bullish/cautious/defensive), key themes, forward guidance language, risk flags, management confidence level.

---

## Phase 14: Strategy Backtesting

### Step 1 — TV-Analysis backtesting (3 calls, sequential)

- Call `mcp__tradingview-analysis__compare_strategies` with symbol=$ARGUMENTS, period="1y" — ranked leaderboard: RSI, Bollinger, MACD, EMA Cross, Supertrend, Donchian
- Call `mcp__tradingview-analysis__backtest_strategy` with symbol=$ARGUMENTS, strategy={best from compare_strategies}, include_trade_log=false — win rate, Sharpe, max drawdown, profit factor
- Call `mcp__tradingview-analysis__walk_forward_backtest_strategy` with symbol=$ARGUMENTS, strategy={best strategy}, period="2y" — overfit validation on unseen data

### Step 2 — Desktop cross-validation (2 calls, conditional on Desktop running)

- Call `mcp__tradingview__data_get_strategy_results` — TradingView's native Strategy Tester: commission/slippage modeling, equity curve, individual trade P&L
- Call `mcp__tradingview__data_get_equity` — equity curve data: drawdown periods, recovery time, consistency

**Cross-validation rule:** If TV-Analysis backtest return diverges from Desktop Strategy Tester by >20%, flag "OVERFIT WARNING" and cap Backtest score at 5.

If Desktop unavailable: skip Step 2, note "No cross-validation available."

---

## Output

Write all collected data to `reports/{SYMBOL}_sentiment.md`:

```markdown
# {SYMBOL} Sentiment & Options Analysis — {DATE}

## Options Flow
- Put/Call Volume Ratio: X ({bullish/bearish/neutral})
- Put/Call OI Ratio: X
- IV Skew: X% ({fear premium/greed/neutral})
- Max Pain: $X (current price distance: X%)
- IV vs HV: X ({expects big move/complacent/normal})
- Expected Move: +/-$X (+/-X%) by {expiry}
- Unusual Activity: {details or "None"}
- Most Active Calls: {strike1, strike2, strike3}
- Most Active Puts: {strike1, strike2, strike3}
- Premium Trend (7d): {rising/falling} — {details}
- Net Delta Exposure: X ({market net long/short/neutral})
- Historical Volatility (30d): X%

## Sentiment
### Reddit (weight: 0.30)
- Signal: {bullish/bearish/neutral} ({X}% bullish)
- Key themes: {summary}

### Twitter/X (weight: 0.20)
- Signal: {bullish/bearish/neutral/unavailable}
- Key themes: {summary}

### StockTwits (weight: 0.20)
- Signal: {bullish/bearish/neutral/unavailable}
- Bull/Bear ratio: {X}% bulls

### News NLP (weight: 0.20)
- Articles analyzed: X
- Positive: X | Neutral: X | Negative: X
- Key finding: {most impactful article summary}

### Analyst Events (weight: 0.10)
- Recent upgrades: X | Downgrades: X
- Notable: {specific events}

### Multi-Agent Debate
- Technical Agent: {verdict}
- Sentiment Agent: {verdict}
- Risk Manager: {verdict}
- Consensus: {BUY/SELL/HOLD}

## Insider Activity
| Date | Name | Role | Action | Shares | Price | Value |
|------|------|------|--------|-------:|------:|------:|
| {rows from searchInsiderTrades} |
| **Net** | | | **{NET_LABEL}** | | | **${NET_VALUE}** |

- 10b5-1 status: {CONFIRMED 10b5-1 (adopted DATE) / DISCRETIONARY / NOT VERIFIED}
  - Source: SEC Form 4 footnotes via WebSearch
  - Never say "likely" — always verify or say "not verified"

## Congressional Activity
- Senate: {trades or "No activity"}
- House: {trades or "No activity"}

## Institutional Ownership
- Holders: X institutions
- Share change: {increased/decreased by X shares}
- Quarter: {Q and year, with lag note}

## Earnings
- Next earnings: {date or "Not within 30 days"}
- Transcript analysis: {summary or "Skipped — not within window"}

## Corporate Actions
- Upcoming: {splits/dividends/mergers or "None within 30 days"}

## Backtesting
- Best Strategy: {name}
- Return: X% | Win Rate: X% | Sharpe: X | Profit Factor: X
- Max Drawdown: X%
- Total Trades: X
- Walk-Forward: {validates/fails} (X% return on unseen data)
- Desktop Cross-Validation: {consistent/divergent/unavailable}
- Buy-and-Hold Comparison: Strategy X% vs B&H X%

## Data Completeness: {X}%
```
