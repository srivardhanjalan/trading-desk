# Adversarial Audit: API Error Handling
## Date: 2026-05-06

I'll read all the specified files to conduct a thorough audit of API error handling and data gaps.

---

Now let me check for the error-handling file.

---

Let me also read the asset-classifier and output-formats for complete context.

---

Now I have a comprehensive view of the entire pipeline. Let me also check for any additional commands that might show the full orchestration flow.

---

Now I have a complete picture of the pipeline. Here is my comprehensive audit.

---

## ADVERSARIAL AUDIT: API Error Handling & Data Gaps

### FINDING 1: No Centralized Error Tracking Mechanism

**Gap:** The pipeline makes 55-73 tool calls across 4 MCP servers. The `error-handling.md` says to "Log `Phase X: [tool] unavailable`" and "set component to N/A," but there is no structured error registry. Each "log" is just a prose note in a markdown report. There is no counter, no array, no manifest of what succeeded and what failed.

**Failure Scenario:** 10 of 55 calls fail (mix of 402, timeout, rate limit). Each is logged as a one-line note buried in a 200-line report file. When `synthesize.md` reads the three report files in Phase 16, it must parse free-text notes to figure out which data points are missing. There is no structured `errors[]` array or `failed_calls: 10/55` field in the intermediate reports.

**Impact on Scoring:** The synthesize phase says "Count: phases_with_data / total_phases_attempted" (Step 5), but this is defined per **phase**, not per **tool call**. A phase that got 3 of 18 tools to succeed counts as "has data." This inflates data completeness. Phase 7 calls 18 FMP endpoints; if 12 fail but 6 return data, it counts as "Phase 7: has data" -- even though Piotroski, Z-Score, revenue growth, and margins are all missing.

**Proposed Safeguard:** Add a structured `## API Call Manifest` section at the bottom of each intermediate report file:
```
| Tool | Status | Code | Fallback Used |
|------|--------|------|---------------|
| getFinancialRatiosTTM | SUCCESS | 200 | — |
| getKeyMetricsTTM | FAILED | 402 | N/A |
...
```
Then in `synthesize.md`, define data completeness as `successful_calls / total_calls` (not phases). Require the synthesizer to read this manifest before scoring.

---

### FINDING 2: 402 Errors Produce Ambiguous Dimension Scores

**Gap:** `error-handling.md` says: "Tool returns error/404/402: Log. Set component to N/A. Continue." But the scoring rubrics never define what happens when a dimension's inputs are partially N/A.

**Failure Scenario:** FMP returns 402 for `getAnalystEstimates` and `getEarningsReports`. The Fundamental rubric requires "Piotroski >= 8 + Z-Score > 3 + revenue growing > 20% + beats earnings >= 6/8 quarters" for a 9-10 score. If `getFinancialScores` succeeds (Piotroski 8, Z-Score 3.5) but `getEarningsReports` fails, the system has 2/4 criteria. Does it score 7-8 (optimistic assumption), 5-6 (neutral default), or something else?

**Impact on Scoring:** The rubric says "<60% data completeness -> force HOLD" but data completeness is calculated at the pipeline level, not per dimension. A dimension could have 50% of its inputs missing and still produce a score of 7 or 3 based on whatever data it has. The prompt-based scorer (Claude) will use its judgment, but there are no guardrails specifying: "If earnings beat/miss data is unavailable, cap Fundamental at 6."

**Proposed Safeguard:** Add per-dimension minimum data requirements to `scoring-rubrics.md`:
```
## Fundamental Score — Minimum Data
Required: Piotroski OR Z-Score + revenue growth. If missing: cap at 5.
If earnings history missing: cap at 6 (cannot confirm beat/miss pattern).
If ALL financial data 402: score = N/A, do not include in composite.
```

---

### FINDING 3: getEarningsCalendar Bulk Response Misinterpretation

**Gap:** `analyze-sentiment.md` Phase 11 says: "`getEarningsCalendar` with from={today}, to={today + 30 days} — returns ALL companies' earnings (no symbol filter). Must search response for $ARGUMENTS."

**Failure Scenario:** The calendar returns 1000+ entries. The target stock (e.g., a small-cap) is not in the results because (a) it hasn't announced an earnings date yet, or (b) the calendar doesn't cover it. The instructions say "Must search response for $ARGUMENTS." If not found, there is no explicit guidance on what to conclude.

**Impact on Scoring:** The distinction matters enormously. "No upcoming earnings within 30 days" means the Earnings Catalyst Modifier (Override 6, worth +/-4 points) should not trigger. But "earnings data failed to load" means the system lacks information to make that call. If the system incorrectly concludes "no earnings," it skips Override 6 entirely. If earnings are actually in 5 days, this could mean a +3 or -4 modifier is silently dropped.

**Additional risk:** The alternative suggested is "use `getEarningsReports` from Phase 9 for per-symbol dates." But `getEarningsReports` returns HISTORICAL data (past quarters), not future earnings dates. This is a data source confusion.

**Proposed Safeguard:** Add explicit fallback chain:
```
1. Search getEarningsCalendar response for $SYMBOL
2. If not found: WebSearch "$SYMBOL next earnings date {year}"
3. If WebSearch also fails: flag "EARNINGS DATE UNKNOWN — Override 6 skipped with warning"
4. NEVER silently conclude "no upcoming earnings" — always distinguish between "confirmed no earnings" and "earnings date not available"
```

---

### FINDING 4: Smart Money Scoring with 60% Missing Data (Options N/A)

**Gap:** When `get_option_chain` returns empty (OTC, small-caps, newly listed), the instructions say "set options-derived scores to N/A." The Smart Money rubric has 4 signal groups: (1) Insider buying/selling, (2) Congressional activity, (3) Institutional accumulation, (4) Options flow (P/C ratio, net delta, unusual calls, rising call premiums). Options flow accounts for 4 of the 10 Smart Money metrics. Additionally, the OI availability check can eliminate 4 more metrics (P/C OI, Max Pain, Unusual Activity, Net Delta).

**Failure Scenario:** Analyzing a small-cap stock. Options chain returns empty. Congressional trades return empty (normal). So Smart Money is scored on: insider trades + institutional ownership only. That is 2 of 4 signal groups.

**Impact on Scoring:** The rubric says 9-10 requires "Net insider buying + congressional buying + institutional accumulation + bullish options flow." A stock with great insider buying and institutional accumulation but no options data literally cannot score above 7-8 (which requires "3/4 signals positive"). But the rubric does not acknowledge this impossibility. The scorer must invent a handling -- likely defaulting options flow to "neutral" which artificially pushes scores toward 5-6 regardless of the remaining signals.

The `error-handling.md` has the rule "Fewer than 5 of 8 dimensions scored: Force HOLD" but this is per-dimension, not per-metric-within-dimension. A Smart Money dimension scored with 40% of its data is still counted as "1 dimension scored."

**Proposed Safeguard:** Add to `scoring-rubrics.md`:
```
## Smart Money — Reduced Data Mode
If options data unavailable:
- Smart Money is scored on insider + institutional + congressional only
- Max possible score: 8 (cannot confirm 9-10 without options)
- Min possible score: 2 (cannot confirm 1-2 without options flow bearishness)
- Reduce Smart Money weight by 30% and redistribute proportionally
- Note: "SMART MONEY: Options data unavailable — reduced weight"
```

---

### FINDING 5: WebSearch Result Validation is Absent

**Gap:** `analyze-sentiment.md` Phase 11 calls WebSearch with queries like `"$ARGUMENTS stock twitter sentiment {year}"` and `"$ARGUMENTS site:stocktwits.com"`. The `error-handling.md` has no guidance on validating whether WebSearch results are actually about the target stock.

**Failure Scenario:** Analyzing ticker `ON` (ON Semiconductor). WebSearch for "ON stock twitter sentiment 2026" returns generic results about the word "on" in stock discussions, celebrity Twitter posts, or articles about the stock market generally. Similarly, `$ARGUMENTS = "A"` (Agilent Technologies) or `"T"` (AT&T) will return extremely noisy results.

**Impact on Scoring:** The sentiment dimension has Twitter/X at 0.20 weight and StockTwits at 0.20 weight. If WebSearch returns irrelevant results, Claude will attempt to extract sentiment from them -- producing garbage scores. A positive article about a different stock could inflate the sentiment score. A negative article about an unrelated company with a similar ticker could deflate it.

The `analyze-sentiment.md` does say "Fallback: If WebSearch returns unusable results for Twitter/StockTwits, redistribute weight to Reddit + News NLP." But "unusable" is subjective. There is no explicit validation step like "verify that at least 3 of 5 results mention the company name, not just the ticker."

**Proposed Safeguard:** Add a WebSearch validation protocol to `error-handling.md`:
```
## WebSearch Result Validation
For EACH WebSearch result used in sentiment scoring:
1. Verify result mentions the FULL COMPANY NAME (not just ticker symbol)
2. Verify result is from last 30 days
3. If <3 of 5 results pass validation: mark platform as "UNVERIFIED" and redistribute weight
4. For ambiguous tickers (<4 chars): always use full company name in query: "$SYMBOL ($COMPANY_NAME) stock twitter sentiment"
5. Never score sentiment from a single unverified WebSearch result
```

---

### FINDING 6: After-Hours Endpoints Called Regardless of Market Status

**Gap:** `analyze-sentiment.md` Phase 11 calls `getAftermarketQuote` and `getAftermarketTrade` unconditionally. These endpoints return after-hours trading data that is only meaningful when the regular market is closed.

**Failure Scenario:** During regular market hours (9:30 AM - 4:00 PM ET), these endpoints may return: (a) stale data from the previous session's after-hours, (b) empty responses, or (c) pre-market data that is actually current-session data. The pipeline already calls `get_clock` in Phase 0 and knows `is_open`, but this information is not used to gate AH calls.

**Impact on Scoring:** The instructions say AH data is "Critical for earnings reaction detection" and "Large block trades in AH = institutional conviction." If the system uses stale AH data from yesterday's close while the market is currently open and the stock has moved 5% intraday, the AH "institutional conviction" signal is meaningless and potentially contradictory.

**Proposed Safeguard:** Add to `analyze-sentiment.md`:
```
## After-Hours Data Gate
- Read market status from Phase 0 (`is_open` from get_clock)
- If is_open=true AND NOT within first 30 minutes of trading: skip AH calls, note "Market open — AH data stale"
- If is_open=false OR within pre-market window: call AH endpoints, data is current
- If earnings reported after previous close: ALWAYS call regardless of market status (reaction data is critical)
```

---

### FINDING 7: TradingView Desktop Symbol Verification Gap

**Gap:** `analyze-technical.md` Phase 6 Step 2 says: "Call `chart_set_symbol` with symbol=$ARGUMENTS." There is no subsequent verification that the symbol change succeeded.

**Failure Scenario:** Desktop is running, health check passes. `chart_set_symbol` is called for "AMD" but silently fails (symbol not found on current exchange, or the call returns success but the chart takes 2-3 seconds to load, and subsequent calls read data from the previously loaded "AAPL" chart). Phase 6 Step 4 (`data_get_study_values`, `depth_get`) reads indicator values and order book data from the wrong symbol.

**Impact on Scoring:** Order book depth from `depth_get` feeds directly into Smart Money: "bid depth > 2x ask depth = +1, ask > 2x bid = -1." If reading AAPL's order book while analyzing AMD, this modifier is applied to the wrong stock's score. Additionally, `data_get_study_values` would read AAPL's RSI/MACD values, potentially contradicting Phase 3 data from TV-Analysis.

**Proposed Safeguard:** Add verification step to Phase 6:
```
## Step 2b — Verify symbol loaded
- After chart_set_symbol, call chart_get_state
- Verify returned symbol matches $ARGUMENTS
- If mismatch: retry once. If still mismatched: skip Desktop data collection, note "Chart symbol mismatch — Desktop data excluded"
- Cross-validate: if Desktop RSI differs from TV-Analysis RSI by >5 points, flag "INDICATOR DIVERGENCE — Desktop may be showing wrong symbol"
```

---

### FINDING 8: No Rate Limiting or Retry Logic for FMP Bulk Calls

**Gap:** `error-handling.md` addresses rate limits: "If multiple consecutive FMP calls return 429: Note 'FMP rate limit reached.' Score only dimensions with data collected so far." But there is no proactive rate limiting or retry logic.

**Failure Scenario:** Phase 7 fires 18 FMP calls in parallel. Phase 9 fires 12 more in parallel. That is 30 calls hitting FMP near-simultaneously. If FMP rate-limits at 30 calls/minute (common for free/starter tiers), the Phase 9 calls all return 429. Since Phase 9 contains DCF valuations and analyst targets, the entire Valuation dimension is unscorable.

**Impact on Scoring:** The Valuation dimension (15% weight) goes to N/A. Per error-handling: "Normalize composite: weighted_sum / sum_of_available_weights x 100." This means the remaining 7 dimensions are rescaled to fill 100%, amplifying their influence. A stock with strong technicals but unknown valuation gets an inflated composite because Technical (22%) gets effectively rescaled to ~26%.

Additionally, the order in which phases execute matters. Phase 7 (Fundamentals) fires first and succeeds. Phase 9 (Valuation) fires second and is rate-limited. But both are in the same "Phase Group 2: Fundamental" so they run together. The `analyze-fundamental.md` says "18 FMP calls, parallel" for Phase 7 and then more for Phase 9 -- a combined ~30 calls that could trigger rate limits.

**Proposed Safeguard:** Add to `error-handling.md`:
```
## FMP Rate Limiting Protocol
1. Phase 7 (18 calls) fires first. Wait for all to complete before Phase 9.
2. If Phase 7 has any 429 responses: pause 10 seconds before Phase 9.
3. Phase 9 Step 1 (4 DCF calls) fires before Step 2 (8 analyst calls). Stagger.
4. On 429: retry up to 2 times with 5-second backoff. Log retry count.
5. Track cumulative FMP call count in session. Display: "FMP Budget: {USED}/{LIMIT} calls."
6. The analyze.md already mentions "Budget: 33-34 FMP calls" — enforce this as a hard limit with a counter.
```

---

### FINDING 9: Minimum Data Requirements per Dimension

Here is the minimum data required for each dimension to produce a meaningful (non-garbage) score, and what happens when exactly that minimum is missing:

#### Technical (Weight: 22%)
- **Minimum required:** RSI value + at least 3/5 timeframe signals + MACD direction
- **Source:** TV-Analysis `multi_timeframe_analysis` + `coin_analysis`
- **If minimum missing:** Both TV-Analysis calls fail (server down). No RSI, no MACD, no timeframe alignment. Technical score cannot be assigned. Override 1 (overbought/oversold) cannot trigger -- this is the most impactful override (can subtract 10 from composite or cap at 55). The pipeline would produce a composite score with no RSI check, potentially recommending BUY on an RSI-90 stock.
- **Current handling:** None specified. `error-handling.md` does not mention TV-Analysis failure.
- **Safeguard:** If TV-Analysis unavailable AND Desktop unavailable: Technical = N/A, force HOLD. "No technical data available from any source."

#### Fundamental (Weight: 15%)
- **Minimum required:** Revenue growth rate (for valuation track routing) + at least one of (Piotroski, Z-Score)
- **Source:** `getFinancialStatementGrowth` + `getFinancialScores`
- **If minimum missing:** Cannot determine Track A vs Track B for Valuation. Cannot assess financial health. The Fundamental score becomes a guess. Revenue growth is also needed for PEG calculation (Valuation). This cascades: Fundamental N/A AND Valuation N/A = 30% of composite weight missing.
- **Current handling:** No per-dimension minimum defined.
- **Safeguard:** If revenue growth unavailable: use TTM income statement to compute manually. If that also fails: Fundamental = N/A, Valuation capped at 5 (cannot determine track).

#### Valuation (Weight: 15%)
- **Minimum required:** Current price + at least one DCF value + revenue growth (for track routing)
- **Source:** `getDCFValuation` or `getLeveredDCFValuation` + Phase 7 growth data
- **If minimum missing:** All 3 DCF calls return 402. Analyst targets are the only valuation anchor. But analyst targets without DCF create a one-dimensional valuation score. The rubric requires "Price < 70% of DCF" for 9-10 -- without DCF, this criterion is unevaluable.
- **Current handling:** No fallback specified when all DCFs fail.
- **Safeguard:** If all DCFs fail: use analyst target range as primary valuation. Cap Valuation at 7 (cannot confirm 8-10 without intrinsic value estimate). Note: "DCF UNAVAILABLE — analyst targets only."

#### Sentiment (Weight: 7%)
- **Minimum required:** At least 2 of 5 platform signals
- **Source:** `market_sentiment` (Reddit) + WebSearch (Twitter/StockTwits) + `getStockNews` + `getStockGradeNews`
- **If minimum missing:** Reddit (`market_sentiment`) fails + WebSearch returns irrelevant results. Only FMP news and analyst grades remain. With only 0.30 weight (news + analyst), the sentiment score is based on 30% of its intended data.
- **Current handling:** "Fallback: redistribute weight to Reddit + News NLP" -- but what if Reddit ALSO fails? No second-level fallback.
- **Safeguard:** If <2 platforms return data: Sentiment = 5 (forced neutral), reduce Sentiment weight by 50%, redistribute. Note: "SENTIMENT: Insufficient data — forced neutral."

#### Smart Money (Weight: 13%)
- **Minimum required:** At least one of (insider trades, institutional data, options flow)
- **Source:** `searchInsiderTrades` + `getPositionsSummary` + `get_option_chain`
- **If minimum missing:** All three fail (micro-cap OTC stock). Smart Money is unscorable. But the pipeline doesn't flag this -- it would count as 1 fewer dimension, and the "fewer than 5 of 8" check might not trigger if other dimensions succeed.
- **Current handling:** `error-handling.md` lists these as "commonly return empty" but doesn't address all-three-empty.
- **Safeguard:** If all 3 signal groups (insider + institutional + options) return empty: Smart Money = N/A, exclude from composite. Note: "SMART MONEY: No data sources returned data."

#### Macro (Weight: 6%)
- **Minimum required:** VIX value (for Override 2) + at least sector performance OR treasury rates
- **Source:** `getIndexQuote` (VIX) + `getStockPriceChange` (sector ETF) + `getTreasuryRates`
- **If minimum missing:** VIX unavailable. Override 2 (VIX Panic) cannot trigger. In a market crash (VIX 45), the system would not apply the VIX downgrade, potentially recommending BUY on a high-beta stock during a panic.
- **Current handling:** "If sector ETF data returns 402: cap Macro at 6" -- but no handling for VIX failure.
- **Safeguard:** If VIX unavailable: WebSearch "CBOE VIX current value." If also fails: cap composite at 65 (cannot confirm no panic) and note "VIX UNAVAILABLE — cannot verify market conditions."

#### Backtest (Weight: 10%)
- **Minimum required:** At least one strategy backtest with trade count
- **Source:** `compare_strategies` + `backtest_strategy`
- **If minimum missing:** TV-Analysis backtesting server is down. No strategies tested. The Adaptive Backtest Weighting already handles low trade counts (reducing weight to 2% for <5 trades), but complete failure is not handled.
- **Current handling:** No explicit handling for total backtest failure.
- **Safeguard:** If TV-Analysis backtest calls all fail: Backtest = N/A, redistribute full 10% weight. Note: "BACKTEST: Unavailable — weight redistributed."

#### Risk (Weight: 12%)
- **Minimum required:** Beta + RSI + at least one of (IV/HV, earnings proximity)
- **Source:** Phase 1 beta + Phase 3 RSI + Phase 10 IV/HV + Phase 11 earnings calendar
- **If minimum missing:** Beta from `getCompanyProfile` is almost always available. But if Phase 10 (options) fails, IV/HV is unknown. The rubric differentiates 5-6 from 7-8 by "IV/HV 1.3-1.5" vs "IV/HV 1.0-1.3." Without IV data, the Risk score for 5-8 range is ambiguous.
- **Current handling:** None specified.
- **Safeguard:** If IV/HV unavailable: use HV alone (from `getStandardDeviation`). If HV also fails: Risk score cannot differentiate 5-8 range -- default to 6 and note "RISK: Volatility data unavailable."

---

### SUMMARY OF SYSTEMIC ISSUES

1. **Data completeness is calculated at the wrong granularity.** It counts phases, not individual API calls. A phase with 3/18 successful calls counts as "complete."

2. **No distinction between "data confirmed absent" and "data retrieval failed."** Empty congressional trades (normal) and 402 on financial scores (data gap) are treated identically -- both logged as N/A. But their scoring implications differ: absence of congressional trades is a neutral signal; absence of financial scores means the Fundamental dimension is unreliable.

3. **No per-dimension minimum data thresholds.** The only guardrails are pipeline-level: "<60% completeness -> HOLD" and "<5 dimensions scored -> HOLD." A dimension scored with 20% of its inputs is still counted as "scored."

4. **Override dependencies on missing data are unhandled.** The seven overrides (overbought, VIX panic, cross-dimension, R:R, extension, earnings catalyst, sell-the-news) each depend on specific data points. If those data points are in failed calls, the override silently does not trigger -- which can be the difference between a BUY and a HOLD.

5. **No retry logic anywhere.** The error-handling protocol is "log and continue." For transient failures (timeout, 429), a single retry with backoff could recover the data. The current approach treats all failures as permanent.