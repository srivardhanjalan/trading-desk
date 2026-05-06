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
| **Expected Move** | ATM call premium + ATM put premium (nearest expiry straddle). Use mid-price (average of bid and ask) for ATM call and put. Expected move = call_mid + put_mid. Also report the IV-based expected move: Price × ATM_IV × sqrt(DTE/365). Report both. E.g., "$12.50 = +/-7.8%". **Historical calibration:** Pull last 8 earnings via `getEarningsReports` (from Phase 9 data or standalone call). Compute avg absolute 1-day post-earnings move. Report `move_ratio = expected_move / avg_historical_move`. If move_ratio > 2.0: "IV INFLATED — market pricing 2x historical move." If < 0.5: "IV DEFLATED — market complacent vs history." |
| **Unusual Activity** | Contracts where today's volume > 5x open interest. Report: strike, expiry, direction, vol/OI ratio |
| **Most Active Strikes** | Top 3 call and top 3 put strikes by volume. Clustering = institutional price targets |
| **Premium Trend** | From `get_option_bars`: 7-day price change % for top 3 contracts. Rising/falling conviction |
| **Net Delta Exposure** | **Preferred:** Call/Put Volume-Weighted Delta Skew = (sum(call volume × call delta) - sum(put volume × abs(put delta))) / total volume. Positive = market net long. **Fallback (only if OI confirmed present):** sum(call OI × call delta) - sum(put OI × abs(put delta)). Volume-weighted is more reliable as it reflects current-day conviction rather than accumulated OI from stale positions. |

**Options Flow Event Contextualization (MANDATORY):**
After computing all 10 metrics, cross-reference against Phase 11 earnings calendar:
- If unusual call activity (volume > 5x OI) AND earnings within 7 days: flag "PRE-EARNINGS UNUSUAL CALLS — potential earnings bet or information edge." Weight this signal 2x in Smart Money scoring.
- If unusual put activity AND earnings within 7 days: flag "PRE-EARNINGS PUT ACCUMULATION — hedging or bearish positioning." Weight 2x.
- If unusual activity AND no catalyst within 30 days: flag "UNUSUAL FLOW IN QUIET PERIOD — possible MNPI or sector rotation."
- If institutions adding shares (from 13F) AND adding puts simultaneously: classify as "PROTECTIVE HEDGING" (neutral), not bearish. Institutional put buying WITH stock buying is standard risk management.

**OI availability check (REQUIRED):** Before computing metrics 2 (P/C OI Ratio), 4 (Max Pain), 6 (Unusual Activity — 5x OI threshold), and 10 (Net Delta Exposure), verify that the `get_option_chain` response contains open interest data. If OI is absent, report these 4 metrics as 'N/A — OI not available from data source' rather than estimating or silently redefining them. Only compute these metrics when OI data is confirmed present in the response.

---

## Phase 11: Sentiment & Insider/Political Activity

### Step 1 — Multi-platform sentiment + news (23-26 calls, parallel)

- `mcp__tradingview-analysis__market_sentiment` with symbol=$ARGUMENTS, market="stocks" — Reddit sentiment across r/stocks, r/wsb, r/investing, r/options
- `mcp__tradingview-analysis__multi_agent_analysis` with symbol=$ARGUMENTS, exchange from Phase 1, timeframe="1D" — 3-agent debate: Technical + Sentiment + Risk Manager
- `mcp__tradingview-analysis__financial_news` with symbol=$ARGUMENTS, category="stocks", limit=10 — real-time RSS feeds from Reuters, CoinDesk, etc. Captures breaking news faster than FMP indexing.
- `mcp__financial-modeling-prep__getStockNews` with symbol=$ARGUMENTS, limit=10 — headlines with URLs (URLs used in Step 2)
- `WebSearch` query: "$ARGUMENTS stock twitter sentiment {current_year}" — Twitter/X sentiment (fastest-moving platform)
- `WebSearch` query: "$ARGUMENTS site:stocktwits.com" — StockTwits sentiment (has built-in bullish/bearish tagging)
- `WebSearch` query: "$ARGUMENTS short interest FINRA {current_year}" — short interest % of float. High SI + approaching earnings = squeeze catalyst. SI data is freely available from FINRA/Nasdaq but not in FMP.
- `WebSearch` query: "$ARGUMENTS earnings whisper estimate {current_year}" — whisper numbers (buy-side expectations). Often higher than published consensus. If actual beats whisper, reaction is more positive than just beating consensus.
- `WebSearch` query: "$ARGUMENTS dark pool activity ATS FINRA {current_year}" — dark pool volume as % of total. If > 40%, signals institutional accumulation/distribution. FINRA publishes biweekly ATS data. Feeds into Smart Money scoring.
- `WebSearch` query: "$ARGUMENTS Google Trends interest {current_year}" — retail interest proxy from Google Trends data. Rising search interest often precedes retail buying waves. Declining interest = waning retail support.
- `WebSearch` query: "{COMPANY_NAME} web traffic app downloads SimilarWeb {current_year}" — alternative demand data for e-commerce/SaaS/mobile companies. Rising web traffic/downloads = leading indicator for next quarter revenue.

**Data provenance note:** WebSearch for Twitter/StockTwits returns articles ABOUT platform sentiment, not actual platform data. Always label the source accurately: 'Twitter/X (via news reports)' or 'StockTwits (via editorial summary)' — never imply direct platform access. If actual bull/bear ratios from the platform are not obtainable, note this limitation. If the `market_sentiment` MCP tool returns platform-specific data, that IS first-party data and should be labeled accordingly.

- `mcp__financial-modeling-prep__searchInsiderTrades` with symbol=$ARGUMENTS, limit=10 — insider buys/sells with $ amounts. **Apply recency weighting:** trades within 30d = 1.0x weight, 31-90d = 0.7x, 91-180d = 0.4x, >180d = 0.2x (only trades within 90 days affect score floor/ceiling). Derive net buy/sell ratio. Weight by: C-suite buys >$1M OR >0.5% of market cap (whichever is lower for <$5B companies) = strong signal.
- `mcp__financial-modeling-prep__getInsiderTradeStatistics` with symbol=$ARGUMENTS — pre-computed net insider buying/selling ratio and trend. Complements raw trade data.
- `mcp__financial-modeling-prep__getLatestInsiderTrading` with symbol=$ARGUMENTS, limit=5 — most recent insider transactions. May capture trades not yet in searchInsiderTrades.
- **10b5-1 verification (REQUIRED):** FMP does not return 10b5-1 plan status. After getting insider trades, run `WebSearch` query: `{SYMBOL} "{INSIDER_NAME}" 10b5-1 plan {year} SEC Form 4` for each insider with sales >$1M. The SEC Form 4 footnotes explicitly state whether sales were under a pre-arranged Rule 10b5-1 plan and the plan adoption date. Report as **confirmed 10b5-1** (with adoption date) or **discretionary sale** — never say "likely."
- `mcp__financial-modeling-prep__getSenateTrades` with symbol=$ARGUMENTS — always called. Empty = "No Senate activity"
- `mcp__financial-modeling-prep__getHouseTrades` with symbol=$ARGUMENTS — always called. Empty = "No House activity"
- `mcp__financial-modeling-prep__getPressReleases` with symbol=$ARGUMENTS, limit=10 — official corporate press releases. Primary source for contract announcements, product launches, partnerships. Feeds into Extension Catalyst Exception check.
- `mcp__financial-modeling-prep__getPriceTargetNews` with symbol=$ARGUMENTS, limit=10 — analyst price target changes with article links. Shows WHICH analysts changed targets, old vs new price, and the reasoning. Critical for detecting recent upgrades/downgrades that move the stock.
- `mcp__financial-modeling-prep__getStockGradeNews` with symbol=$ARGUMENTS, limit=10 — analyst rating changes (upgrade/downgrade/initiation). Shows grading firm, previous vs new grade, action taken. Feeds directly into Analyst sentiment sub-score.
- `mcp__financial-modeling-prep__getEarningsCalendar` with from={today}, to={today + 30 days} — returns ALL companies' earnings (no symbol filter). Must search response for $ARGUMENTS. Alternatively, use `getEarningsReports` from Phase 9 for per-symbol dates.
- `mcp__alpaca__get_corporate_actions` with symbol=$ARGUMENTS — upcoming splits, dividends, spin-offs, mergers within 30 days. Reverse split could trigger stop-losses. Feeds into Risk scoring.
- `mcp__financial-modeling-prep__getAftermarketQuote` with symbol=$ARGUMENTS — after-hours bid/ask, price, volume. **Only call when market is CLOSED** (check `is_open` from Phase 0). During market hours, skip or flag "STALE AH DATA." **Critical for earnings reaction detection.** Shows immediate post-earnings institutional sentiment before next open.
- `mcp__financial-modeling-prep__getAftermarketTrade` with symbol=$ARGUMENTS — AH trade prices, sizes, timestamps. **Only call when market is CLOSED.** **Large block trades in AH = institutional conviction.** Multiple 10K+ share blocks at increasing prices = strong accumulation signal.
- `mcp__financial-modeling-prep__searchStockNews` with symbol=$ARGUMENTS, limit=10 — symbol-specific news search. More targeted than general `getStockNews` feed. Better hit rate for sentiment analysis.
- `WebSearch` query: "$ARGUMENTS stock news {current_year}" — **MANDATORY companion to searchStockNews.** Captures analyst initiations, blog commentary, CNBC/Bloomberg articles, and breaking news that FMP may not index. **ALWAYS use BOTH FMP searchStockNews AND WebSearch for news — never one without the other.**
- `mcp__financial-modeling-prep__searchPressReleases` with symbol=$ARGUMENTS, limit=10 — symbol-specific press releases. Catches pre-earnings guidance revisions, contract wins, partnership announcements. **Feeds into Extension Catalyst Exception.**
- `mcp__financial-modeling-prep__getFilingsBySymbol` with symbol=$ARGUMENTS, limit=10 — recent SEC filings (8-K, 10-Q, etc.). **8-K filings signal material events** — guidance changes, exec departures, major contracts. A cluster of 8-Ks before earnings = something is happening.
- `mcp__financial-modeling-prep__getDividends` with symbol=$ARGUMENTS — dividend history and yield trend. Rising dividends = shareholder return commitment. Dividend cuts = major negative signal. Feeds into Fundamental and Risk scoring.
- `mcp__financial-modeling-prep__getDividendsCalendar` with from={today}, to={today + 30 days} — upcoming ex-dividend dates. POST-FILTER for symbol. Ex-div within 5 days affects near-term price support.
- `mcp__financial-modeling-prep__getStockSplitCalendar` with from={today}, to={today + 60 days} — upcoming stock splits. POST-FILTER for symbol. Forward splits increase retail interest; reverse splits are often bearish.
- `mcp__financial-modeling-prep__searchEquityOfferings` with symbol=$ARGUMENTS — recent equity/debt offerings. Secondary offerings (dilution) are material negative signals. Convertible notes add future dilution risk. Feeds into Risk scoring.
- `mcp__financial-modeling-prep__getLatest8KFilings` — most recent material event filings across all companies. POST-FILTER for symbol. Clusters of 8-Ks near earnings signal material events in progress.

**Crypto route:** `market_sentiment` + `multi_agent_analysis` + `mcp__financial-modeling-prep__searchCryptoNews` + `WebSearch` Twitter. Skip insider/congressional/corporate actions.

### Step 2 — Full-text news NLP (4-5 calls, sequential after Step 1)

- Take the top 4-5 news article URLs from `getStockNews` and `searchStockNews` responses (deduplicate by URL, prioritize Tier 1 sources)
- Call `WebFetch` on each URL
- For each article, analyze: key facts, sentiment (positive/negative/neutral), impact magnitude (high/medium/low), time horizon
- Apply source credibility tiers: Tier 1 (Reuters, Bloomberg, WSJ) = 1.0x weight, Tier 2 (CNBC, Yahoo Finance) = 0.8x, Tier 3 (blogs, unknown) = 0.5x

**Compliance checklist (ALL required):**
1. [ ] WebFetch called on at least 3 article URLs (increased from 2)
2. [ ] Per-article breakdown: key facts, sentiment, impact magnitude, time horizon
3. [ ] Source credibility tier assigned to each article
4. [ ] If WebFetch returns 403/paywall, note 'PAYWALLED — sentiment from headline only (lower confidence)'
5. [ ] At least 1 Tier 1 source (Reuters, Bloomberg, WSJ) sought via WebSearch
6. [ ] Analyst grade/price target news from `getStockGradeNews` and `getPriceTargetNews` cross-referenced with article sentiment
If fewer than 4 of 6 items are completed, add 'NEWS NLP: INCOMPLETE' warning to output.

**Why full-text matters:** Headlines are often clickbait. A "Stock drops 5%" headline might be planned dilution (bad) or profit-taking after +30% run (neutral). Only the article body reveals the actual signal.

---

## Phase 12: Institutional Ownership

**4 calls, parallel:**
- Call `mcp__financial-modeling-prep__getPositionsSummary` with symbol=$ARGUMENTS, year={current year}, quarter={adjusted quarter}
- Call `mcp__financial-modeling-prep__getHolderPerformanceSummary` with symbol=$ARGUMENTS, year={current year}, quarter={adjusted quarter} — **Are the institutional holders good investors?** If high-alpha funds (those outperforming S&P 500) are accumulating, this is a stronger signal than generic institutional buying. Cathie Wood selling while Renaissance buying = trust Renaissance.
- Call `mcp__financial-modeling-prep__getForm13FFilingDates` with symbol=$ARGUMENTS — exact filing dates for the symbol's institutional holders. Detects STALE vs FRESH 13F data and identifies which funds filed most recently.
- Call `mcp__financial-modeling-prep__getHolderIndustryBreakdown` with symbol=$ARGUMENTS — which industries/sectors the institutional holders come from. If holders are concentrated in one industry (e.g., all tech funds), a sector rotation would trigger correlated selling.

**13F filing lag:** Use the most recent quarter Q where (Q_end_date + 45 days) < today. This guarantees all filings for that quarter are past deadline.
Example: On May 4, 2026: Q1 ends Mar 31, deadline May 15 — NOT past → skip. Q4 ends Dec 31, deadline Feb 14 — past → USE Q4 2025.
On May 20, 2026: Q1 deadline May 15 — past → USE Q1 2026.
If the calculated quarter returns significantly fewer holders than the prior quarter (>50% drop), warn: 'Possible incomplete filing data — verify against prior quarter.'

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

- Call `mcp__tradingview-analysis__compare_strategies` with symbol=$ARGUMENTS, period="1y" — ranked leaderboard: RSI, Bollinger, MACD, EMA Cross, Supertrend, Donchian. **Extract Buy-and-Hold return from the response** (usually included as benchmark). If not in response, compute from Phase 1 price change data (1Y return).
- Call `mcp__tradingview-analysis__backtest_strategy` with symbol=$ARGUMENTS, strategy={best from compare_strategies}, include_trade_log=false — win rate, Sharpe, max drawdown, profit factor, **total trade count**
- Call `mcp__tradingview-analysis__walk_forward_backtest_strategy` with symbol=$ARGUMENTS, strategy={best strategy}, period="3y" — overfit validation on unseen data. **Use 3y (not 2y) to ensure in-sample and out-of-sample windows do not overlap.** Report robustness score and out-of-sample trade count.

**Scoring gates (apply in order during Phase 16):**
1. **Trade count gate:** <5 trades → cap score at 2. 5-9 → cap 4. 10-14 → cap 6. ≥15 → no cap.
2. **B&H benchmark:** If best strategy return < buy-and-hold return → subtract 2 from score (min 1).
3. **Walk-forward:** If robustness = 0 or no out-of-sample trades → flag "OVERFITTED" warning.

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

### Twitter/X (weight: 0.10)
- Signal: {bullish/bearish/neutral/unavailable}
- Key themes: {summary}

### StockTwits (weight: 0.10)
- Signal: {bullish/bearish/neutral/unavailable}
- Bull/Bear ratio: {X}% bulls

### News NLP (weight: 0.30)
- Articles analyzed: X
- Positive: X | Neutral: X | Negative: X
- Key finding: {most impactful article summary}

### Analyst Events (weight: 0.20)
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
- Filing Freshness: {latest 13F filing date, staleness weight applied}
- Holder Industry Concentration: {diversified or concentrated in X sector}
- Fund Quality: {top-alpha accumulating / mixed / bottom-quintile dominated}

## Earnings
- Next earnings: {date or "Not within 30 days"}
- Transcript analysis: {summary or "Skipped — not within window"}

## Corporate Actions
- Upcoming: {splits/dividends/mergers or "None within 30 days"}

## Dividends & Splits
- Dividend History: {trend or "N/A"}
- Next Ex-Div: {date or "None within 30 days"}
- Upcoming Split: {details or "None within 60 days"}

## Equity Offerings & Dilution
- Recent Offerings: {secondary/convertible details or "None"}
- Dilution Risk: {assessment based on offering history}

## Recent 8-K Filings
- {date}: {filing summary}
- Cluster Alert: {yes/no — multiple 8-Ks near earnings}

## Dark Pool & Alternative Data
- Dark Pool Volume: {X}% of total ({HIGH/NORMAL/LOW or "Data unavailable"})
- Google Trends: {rising/stable/declining} interest
- Web Traffic/Downloads: {data if available, or "N/A — not applicable to business model"}

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
