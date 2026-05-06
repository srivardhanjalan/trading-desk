# Adversarial Audit: Temporal Staleness & Data Freshness
## Date: 2026-05-06

I'll read all the requested files to conduct a thorough temporal staleness audit.

---

Now let me read 2-3 stock reports to examine actual data staleness in practice.

---

Now let me read the PLTR report (most recent score entry) and check for the AMD final synthesis report for more staleness evidence.

---

Now let me check for any existing staleness handling or freshness mechanisms in the codebase.

---

Now I have a thorough understanding of the entire system. Let me produce the audit findings.

---

# TEMPORAL STALENESS AND DATA FRESHNESS AUDIT

## Executive Summary

The trading-desk analysis pipeline has **zero explicit freshness mechanisms**. There is no staleness detection, no age-based weighting, no expiration warning, and no automatic invalidation for any data source. The single mention of staleness in the entire codebase is a cosmetic note in `output-formats.md` that says "Volume/options data may be stale" when markets are closed. This is a systemic vulnerability that affects every dimension of the scoring system.

---

## FINDING 1: Annual Financial Statements (FY) Are Up to 16 Months Stale

**File:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-fundamental.md`, lines 35-36

The pipeline calls `getIncomeStatement` with `period="FY", limit=2` and `getBalanceSheetStatement` with `period="FY", limit=1`. For AMD, the report at `/Users/srivardhanjalan/workspace/trading-desk/reports/AMD_fundamental.md` shows FY2025 data (fiscal year ending December 2025). This analysis ran on May 4, 2026 -- meaning the FY data is already 4 months old, and by mid-year it will be 6+ months old. For companies with non-calendar fiscal years (like CRDO, whose FY ends April 30), the FY data could be up to 16 months old before the next FY closes.

**Evidence from reports:** The AMD fundamental report uses FY2025 revenue of $34.64B and FY2024 of $25.79B for growth calculations. But by May 2026, Q1 2026 actuals already exist (revenue ~$9.88B, +33% YoY). The FY-based growth rate (34.3%) does not capture any acceleration or deceleration in the most recent quarter.

**The TTM contradiction (Finding 7 amplified):** The pipeline also fetches `getIncomeStatementTTM` and `getBalanceSheetStatementTTM`, but there is no rule for which takes priority. In the AMD report, TTM revenue would be approximately $36-37B (rolling four quarters through Q1 2026) while FY revenue is $34.64B. The Fundamental score (8/10) and the PEG ratio (3.95) are both computed from FY data. If TTM data were used, the PEG would be different. The pipeline comment says "Use for run-rate estimates. When most recent quarter shows acceleration, TTM better reflects current earnings power" but this is advisory, not enforced. No scoring rule references TTM over FY.

**Proposed freshness rule:**
- If today's date is more than 120 days past the FY end date, append warning: `STALE FY DATA: {FY_end_date} was {N} days ago. TTM data is more current.`
- For growth calculations (revenue growth, EPS growth, PEG), mandate TTM as the primary source when the FY end date is >90 days old. Use FY only for YoY comparisons.
- For companies with non-calendar fiscal years, always check whether a more recent quarterly filing exists and flag the lag.

---

## FINDING 2: 13F Institutional Data Has a 4-5 Month Blind Spot

**File:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-sentiment.md`, lines 119-126

The 13F lag rule is correctly documented: "Use the most recent quarter Q where (Q_end_date + 45 days) < today." On May 4, 2026, this means Q4 2025 data (quarter ended Dec 31, filings due Feb 14). This data is 4+ months old by the analysis date.

**Evidence from reports:** The AMD sentiment report (`/Users/srivardhanjalan/workspace/trading-desk/reports/AMD_sentiment.md`, line 129) shows Q4 2025 institutional data: 3,288 holders, +60.4M shares, 67.13% ownership. But AMD's stock price went from ~$96 in late 2025 to $360 by May 2026 -- a 275% move. The institutional picture from Q4 2025 predates the entire AI-driven rally. Institutions that filed in February could have dramatically changed positions during the March-April surge. The report correctly notes the Q4 quarter but gives no weight penalty for the 4-month lag.

The pipeline says "If the calculated quarter returns significantly fewer holders than the prior quarter (>50% drop), warn" -- but this is an incomplete data check, not a staleness check. A quarter could have perfect filing coverage and still be 4 months old.

**Critical window problem:** On May 4-14 (the 11-day window before the Q1 filing deadline), there is maximum uncertainty. Some funds have already filed Q1 (visible in the data), while others have not. The pipeline has no mechanism to detect this partial-filing state.

**Proposed freshness rule:**
- Always display: `13F Data Age: {N} days since quarter end ({quarter} {year}). Next filing deadline: {deadline_date}.`
- If data age > 100 days: `WARNING: Institutional data is {N} days old. Positions may have changed materially.`
- During the 45-day filing window (quarter_end to quarter_end + 45 days): `FILING WINDOW: Q{N} filings in progress. Data reflects Q{N-1}. Check back after {deadline_date} for updated positions.`
- Weight institutional signals at 0.7x when data age > 90 days, 0.5x when > 120 days.

---

## FINDING 3: Insider Trade Data Has No Recency Filter

**File:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-sentiment.md`, line 80

The pipeline calls `searchInsiderTrades` with `limit=10` but no date filter. The 10 most recent trades could span any time period. An insider trade from 11 months ago carries the same analytical weight as one from yesterday.

**Evidence from reports:** In the AMD sentiment report, insider trades range from April 24, 2026 (2 weeks old) to March 12, 2026 (53 days old). These are reasonably current. But for less-traded stocks, the 10 most recent insider trades could easily span 12-18 months. The scoring rubric (`scoring-rubrics.md`, lines 166-189) makes no distinction between a $10M sale last week and a $10M sale 9 months ago. Both trigger the same "ceiling 4" rule.

**The 10b5-1 temporal problem:** A 10b5-1 plan adopted September 9, 2025 (Lisa Su's plan) was used to execute sales in March 2026 -- 6 months later. The plan adoption date is relevant context, but the pipeline treats the execution date as the signal date. A sale under a 6-month-old plan has different information content than a discretionary sale last week.

**Proposed freshness rule:**
- Categorize insider trades by recency: Last 30 days (1.0x weight), 31-90 days (0.7x weight), 91-180 days (0.4x weight), >180 days (0.2x weight -- context only).
- If all 10 trades are >90 days old: `STALE INSIDER DATA: Most recent insider trade was {N} days ago on {date}. Insider signal has limited current relevance.`
- For the Smart Money dimension, only trades within 90 days should affect the score floor/ceiling. Older trades should be reported for context but excluded from the magnitude thresholds ($1M buy boost, $10M sell ceiling).

---

## FINDING 4: Analyst Estimates Have No Staleness Weighting

**File:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-fundamental.md`, lines 106-107

The pipeline calls `getAnalystEstimates` with `period="quarter", limit=4` and `getPriceTargetLatestNews`. There is no mechanism to distinguish between an estimate published yesterday and one from 4 months ago.

**Evidence from reports:** The AMD fundamental report shows analyst price targets ranging from Susquehanna's $375 (April 29, 2026 -- 5 days old) to Benchmark's reiteration (February 4, 2026 -- 89 days old). The "Last Year" average of $270.45 from 65 analysts includes targets set when AMD was at $96-$150 -- those analysts may not have updated. The pipeline averages them all equally.

The CRDO fundamental report shows Goldman Sachs raising to $170 on April 16, while Barclays set $260 on January 15 -- a 3-month gap. Barclays's $260 was set when CRDO was around $150 (pre-Q3 FY2026 earnings). These estimates carry equal weight in the consensus despite being set at very different price points and information states.

**Proposed freshness rule:**
- Weight estimates by recency: Last 30 days (1.0x), 31-60 days (0.8x), 61-90 days (0.6x), >90 days (0.4x).
- Compute both raw consensus and recency-weighted consensus. Report both: `Analyst Consensus (all): $X ({N} analysts) | Analyst Consensus (30-day): $Y ({M} analysts)`
- If fewer than 3 estimates are from the last 60 days: `LOW ESTIMATE COVERAGE: Only {N} estimates updated in last 60 days. Consensus may not reflect current information.`

---

## FINDING 5: scores.csv Has No Staleness Warning or Expiration

**File:** `/Users/srivardhanjalan/workspace/trading-desk/reports/scores.csv`

All scores are dated 2026-05-04 (with one PLTR entry from 2026-05-05). Today is 2026-05-06. The audit prompt notes AMD moved +14.8% in 2 days. The AMD score of 39/SELL was computed at a price of $360.54. If AMD is now at $413+ (after a 14.8% move), every dimension is affected: RSI changed, extension risk changed, valuation multiples changed, options premiums changed, analyst targets relative to price changed.

There is no mechanism in the system to detect or warn about score staleness. No command reads scores.csv and compares the score date to today. No consumer of this file gets a warning that the data is N days old.

**Proposed freshness rule:**
- Add columns to scores.csv: `price_at_scoring`, `price_current`, `price_change_since_scoring`.
- Any system reading scores.csv must compute: `days_since_scoring = today - date`. 
- Display thresholds:
  - 0-1 days: No warning
  - 2-3 days: `AGING: Score from {date} ({N} days ago). Consider re-analyzing if significant price movement.`
  - 4-7 days: `WARNING: Score from {date} is {N} days old. Price has moved {X}% since scoring. Re-analyze recommended.`
  - >7 days: `STALE: Score from {date} is {N} days old. Do not use for trading decisions. Re-analyze required.`
- If price has moved more than 5% since scoring (in either direction), regardless of age: `INVALIDATED: Price moved {X}% since scoring. Score no longer reliable. Re-analyze required.`

---

## FINDING 6: Technical Analysis (22% Weight) Has No Staleness Mechanism

**Files:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/_shared/scoring-rubrics.md` (lines 26-53), output-formats.md (line 10)

Technical analysis is the highest-weighted dimension at 22% for stocks. RSI, MACD, ADX, Stochastic, and Bollinger Bands are all point-in-time snapshots. The only staleness acknowledgment in the entire system is a cosmetic note: "data reflects last close. Volume/options data may be stale."

**Evidence from reports:** The AMD technical analysis has RSI at 79.84 (triggering the overbought override, subtracting 5 from composite). But RSI 79.84 was computed on May 4 -- a Sunday. By Tuesday May 6, after a +14.8% move (or whatever the actual move was), the RSI could be at 88 (triggering the "EXTREME OVERBOUGHT -- cap at 55" rule) or could have pulled back to 65 (removing the penalty entirely). The 5-point overbought penalty swings the signal from HOLD (44) to SELL (39). This single stale data point determines the trade recommendation.

The MACD histogram, ADX trending state, and Stochastic crossovers can all flip intraday. Yet the scores persist indefinitely in scores.csv with no decay.

**Proposed freshness rule:**
- Technical scores expire at market close of the day they were computed. After that: `TECHNICAL EXPIRED: Indicators computed {N} days/hours ago. RSI, MACD, Stochastic may have shifted. Re-analyze before trading.`
- If the analysis was run on a weekend or holiday: `OFF-HOURS ANALYSIS: Technical indicators reflect {last_trading_day} close. Current values unknown.`
- When markets are open, include a market-hours timestamp: `Technical data as of {time} ET. If market still open, indicators are changing.`
- For scores.csv consumers: Technical dimension weight should decay linearly -- 22% on day 0, 18% on day 1, 11% on day 2, 0% on day 3+. Redistribute to Fundamental (most time-stable dimension).

---

## FINDING 7: FY vs TTM Data Priority Is Undefined (Expanded)

**File:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-fundamental.md`, lines 35-41

The pipeline fetches both FY and TTM data but never specifies which takes priority in calculations. Line 37 says `getIncomeStatementTTM` provides "more current than FY data. Use for run-rate estimates." But the scoring rubric at `scoring-rubrics.md` references "revenue growing >20% YoY" and "revenue growing >10%" without specifying FY or TTM as the source.

**Evidence from reports:** The AMD fundamental report computes all growth rates from FY data (FY2025 vs FY2024: revenue +34.3%). The TTM data is fetched but only used for ratios (P/E TTM 135.57, margins). The growth rate that drives Track B routing (34.3% > 20% threshold) and the PEG ratio (P/E 135.57 / revenue growth 34.3% = 3.95) both use FY growth. If Q1 2026 showed revenue acceleration to 38%, the TTM growth rate would be higher and the PEG lower. If Q1 showed deceleration to 25%, TTM would be lower and PEG higher. The choice between FY and TTM directly changes the valuation score.

For CRDO (CRDO_fundamental.md), the discrepancy is even larger. FY margins (operating 8.5%, net 11.9%) vs TTM margins (operating 30.2%, net 31.8%) show the company's trajectory has changed dramatically since the FY data was compiled. The Fundamental score of 8/10 uses TTM ratios for ROE (29.6%) but FY data for revenue segments and growth rates. This mixing is inconsistent and undocumented.

**Proposed freshness rule:**
- Establish a clear priority hierarchy: TTM > quarterly > FY for all growth and profitability calculations.
- FY data should only be used for: (a) YoY comparisons where the same FY period exists, (b) segment breakdowns not available in TTM, (c) historical trend analysis.
- When FY and TTM diverge by >20% on any key metric (revenue, margins, FCF), flag: `FY/TTM DIVERGENCE: {metric} FY={X} vs TTM={Y}. Using TTM as primary. FY is {N} months old.`
- PEG and growth-driven routing (Track A vs Track B) should always use TTM growth rate when the FY end date is >90 days old.

---

## FINDING 8: Earnings Transcript Age Is Poorly Gated

**File:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-sentiment.md`, lines 133-138

The rule says "Only fetch if earnings within 30 days (from Phase 11 calendar) OR analyzing most recent quarter." The "most recent quarter" condition has no time bound. For CRDO, the most recent earnings were March 2, 2026 (63 days before the May 4 analysis). The report says "Skipped -- not within 30-day recency window" -- but this is inconsistent with the "OR analyzing most recent quarter" clause, which would suggest fetching it.

For AMD, the Q4 2025 transcript was fetched (earnings reported Feb 3, 2026 -- 90 days before analysis). The transcript contains forward guidance for Q1 2026 ("revenue ~$9.8B +/- $300M"). By May 4, Q1 2026 results are about to be reported (May 5). The forward guidance in the transcript is about to be either confirmed or refuted. The transcript analysis says "Management confidence level: HIGH" -- but this confidence was expressed 90 days ago about a quarter that is now complete. This is effectively analyzing a prediction whose outcome is already determined but not yet revealed.

**Proposed freshness rule:**
- Earnings transcripts should carry a temporal context tag:
  - <30 days old: "CURRENT GUIDANCE: Forward-looking statements are still prospective."
  - 30-60 days old: "AGING GUIDANCE: Some forward guidance may have been partially realized. Weight guidance statements at 0.7x."
  - 60-90 days old: "STALE GUIDANCE: Most forward guidance covers a period now largely elapsed. Weight guidance at 0.4x. Focus on structural themes only."
  - >90 days old: "EXPIRED GUIDANCE: Forward guidance is for a period already completed. Use only for management tone and strategic direction, not quantitative predictions."
- If earnings are imminent (within 7 days), explicitly note: "EARNINGS IMMINENT: Transcript guidance for {quarter} is about to be resolved. Do not use guidance numbers for predictions."

---

## FINDING 9: Price Change Data Is Intraday-Sensitive With No Market-Hours Check

**File:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-fundamental.md`, line 17

The pipeline calls `getStockPriceChange` for the sector ETF and individual stocks. The Momentum Extension Modifier (scoring-rubrics.md, lines 380-418) uses 1M and 3M percentage changes as hard thresholds: 1M >= 60% = EXTREME (-5 penalty), 1M >= 30% = HIGH (-2 penalty).

**Evidence from reports:** AMD's 1M change was +63.7% and 3M was +80.1%. These numbers would be different depending on when during the trading day the API was called. If called at 10am, the 1D return is only 3.5 hours of trading. If called after-hours (as AMD's May 4 analysis was -- a Sunday), the 1D return reflects Friday's close but the 1M and 3M returns may not include after-hours price action.

The AMD analysis ran on Sunday May 4. The `getStockPriceChange` returned 1M: +63.7% reflecting the April rally. But by Monday morning (when a trader would act on the score), pre-market could have shifted the 1M return by several percentage points. The EXTREME threshold is a cliff at 60% -- a stock at 59.9% gets no penalty while 60.1% gets -5 points. This cliff effect is dangerous when the input data has a multi-hour or multi-day lag.

**Proposed freshness rule:**
- Check market status before computing extension risk. If markets are closed: `OFF-MARKET: Price changes reflect {last_close_date} close. Current prices may differ.`
- For the Extension Modifier, use a buffer zone around thresholds: 55-65% = "EXTREME/HIGH boundary -- re-check at market open before trading." 25-35% = "HIGH/MEDIUM boundary -- verify before acting."
- Timestamp all price change data: `Price changes as of {timestamp}. 1D return is {partial/complete} (market {open/closed}).`

---

## FINDING 10: News and Press Releases Have No Date-Based Weighting

**File:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-sentiment.md`, lines 72, 86

The pipeline calls `getStockNews` with `limit=5` and `getPressReleases` with `limit=5`. These return the 5 most recent items but the News NLP analysis treats all articles equally in sentiment weighting.

**Evidence from reports:** The AMD sentiment report analyzes 3 articles. One discusses a "CNBC: AMD shares soar 12% on no company news" from April 24 (10 days before analysis). Another discusses the Meta deal announced earlier. These are treated with equal sentiment weight to coverage of the May 5 earnings. A 10-day-old news article about a 12% move has already been priced in. Its sentiment contribution should be near zero for a current trading decision.

The analyst events section (scoring-rubrics.md, line 154) actually has some temporal weighting: "This week = 2x, this month = 1x, older = 0.5x." This is the ONLY temporal weighting in the entire sentiment system, and it applies only to analyst upgrades/downgrades (10% of sentiment weight). The other 90% (Reddit, Twitter, StockTwits, News NLP) has no temporal adjustment.

**Proposed freshness rule:**
- News articles should be weighted by recency: Same day (1.0x), 1-3 days (0.8x), 4-7 days (0.6x), 8-14 days (0.4x), 15-30 days (0.2x), >30 days (exclude from sentiment, report for context only).
- Press releases: Same weighting scheme. Corporate press releases >30 days old should only feed into the Extension Catalyst Exception check, not sentiment scoring.
- Apply the existing analyst event temporal weighting to ALL sentiment sources: "Extend the 'this week = 2x, this month = 1x, older = 0.5x' rule to news NLP and social media sentiment."
- Display the date range of analyzed content: `Sentiment window: {oldest_article_date} to {newest_article_date} ({N} days span).`

---

## SYSTEMIC RECOMMENDATION: Add a Data Freshness Layer

None of the 10 findings above exist in isolation. The core problem is that the pipeline has no concept of data age. Every API response is treated as equally current regardless of when the underlying data was generated. This should be addressed at the architecture level.

**Proposed addition to `scoring-rubrics.md`:**

A new section "Data Freshness Rules" that applies across all dimensions:

1. **Score expiration:** Every composite score expires after 3 calendar days. After 3 days, scores in `scores.csv` must display a warning. After 7 days, they must not be used for trade decisions.

2. **Dimension-specific half-lives:**
   - Technical: 1 trading day (most volatile)
   - Sentiment: 2 trading days
   - Options flow: 1 trading day
   - Smart Money (insider/institutional): 30 days (slowest-moving)
   - Fundamental: 90 days (anchored to earnings cycle)
   - Valuation: 7 days (price-dependent)
   - Macro: 7 days
   - Backtest: 30 days (strategy performance is relatively stable)

3. **Price-triggered invalidation:** If price moves >5% from the scoring price, all price-dependent dimensions (Technical, Valuation, Risk, Options, Extension) are invalidated regardless of calendar age.

4. **Event-triggered invalidation:** Earnings reports, major news events (>5% move on news), analyst upgrades/downgrades, and material insider trades should automatically invalidate the relevant dimensions.

5. **Freshness metadata in reports:** Every report should include a "Data Freshness" section listing each data source with its effective date and age in days, similar to the existing "Data Completeness" table but for temporal currency rather than coverage.