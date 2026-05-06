# Adversarial Audit: Pre-Earnings Regime
## Date: 2026-05-06

I'll start by reading the required files to understand the system's design.

---

Now let me read the two report files.

---

Now I have a thorough understanding of all three documents. Let me also check if there are any additional configuration files or earnings-related logic.

---

Now let me check the output-formats.md for any additional earnings-related formatting or logic.

---

Now I have all the information needed. Here is my comprehensive audit.

---

## Adversarial Audit: Pre-Earnings Regime Switching Logic

### FLAW 1: The 7-Calendar-Day Window Is Ambiguous and Potentially Wrong

**The rule:** "earnings within 7 calendar days" triggers pre-earnings weight switching.

**The problem:** Calendar days include weekends and holidays. A stock analyzed on Friday May 1 with earnings on Monday May 4 is "3 calendar days away" -- but only 1 trading day away. Conversely, a stock analyzed on Monday with earnings the following Monday is "7 calendar days away" but only 5 trading days away. The information asymmetry and options pricing behavior that the pre-earnings regime is designed to capture are functions of *trading days*, not calendar days. IV crush, gamma risk, and options pinning happen on trading-day boundaries.

**Specific scenario:** Stock X analyzed on Thursday May 7 with earnings on Wednesday May 13 = 6 calendar days = triggers. Stock Y analyzed on Friday May 8 with earnings on Friday May 15 = 7 calendar days = triggers. But Stock Z analyzed on Saturday May 9 (weekend analysis) with earnings on Friday May 15 = 6 calendar days = triggers. Weekend analyses introduce a 2-day ambiguity in the window.

**Worse:** The rubric says 7 calendar days for weight switching AND Override 6 (Earnings Catalyst Modifier), but the Risk score rubric says "no earnings within 14d" for a 9-10 Risk score and "earnings within 14d" for 5-6. These are different windows for related concepts. A stock 10 days from earnings gets a Risk penalty but no weight switch -- the regime is half-activated.

**Proposed fix:** Change to "within 5 trading days" using market calendar data (already available via `getCalendar` from Alpaca). Add a clarifying note: "Use Alpaca `get_calendar` to count actual trading days between analysis date and earnings date. Weekends and market holidays do not count."

---

### FLAW 2: No Defined Behavior When Earnings Date Is Unknown

**The rule:** synthesize.md Step 0 says "Check `getEarningsCalendar` data from Phase 11 or fundamental report."

**The problem:** `getEarningsCalendar` returns ALL companies' earnings in a date range with **no symbol filter** (explicitly stated in PLAN.md line 255 and analyze-sentiment.md line 87). The system must search the response for the target symbol. If the stock is not in the response -- because (a) the company hasn't announced a date yet, (b) the API's coverage is incomplete, or (c) the date is beyond the 30-day query window -- the system has **no defined behavior**.

The synthesize.md Step 0 says:
- If within 7 days: pre-earnings weights
- If within 2 trading days AFTER: sell-the-news check
- "Otherwise: use normal weights"

But "otherwise" conflates two distinct cases: "earnings are known to be far away" and "earnings date is unknown." These are materially different. An unknown earnings date means there could be a surprise announcement at any moment (some companies give <2 weeks notice). The system silently defaults to normal weights, which could be dangerously wrong.

**Specific scenario:** A small-cap stock with no FMP earnings calendar coverage is analyzed. `getEarningsCalendar` returns nothing for this symbol. The system assumes normal weights. The company reports earnings 2 days later (announced on their IR page but not in FMP's database). The analysis was made with 22% Technical / 7% Sentiment weights when it should have used 12% Technical / 20% Sentiment weights.

**Proposed fix:** Add a third branch: "If earnings date is NOT FOUND in getEarningsCalendar AND getEarningsReports does not return a next-earnings date: Note 'EARNINGS DATE UNKNOWN -- using normal weights with caution flag.' Add warning: 'Earnings date not found in FMP calendar. Verify manually before trading.' Cap Risk score at 6 (cannot achieve 9-10 which requires 'no earnings within 14d' when you don't know the date)."

---

### FLAW 3: EBP Is Undefined for Stocks With <4 Quarters of History

**The rule:** EBP = beat_history / total_quarters. If estimate revisions positive: +10%. If avg surprise magnitude > 10%: +5%. Cap at 95%.

**The problem:** For IPOs, recent spinoffs, or newly-public SPACs, there might be only 1-2 quarters of earnings history. The rubric does not specify a minimum quarter count. With 1 beat in 1 quarter, EBP base = 100%. Add +10% for revisions and +5% for surprise magnitude, and you hit the 95% cap. This triggers a +3 composite modifier (EBP >= 80%). That is an absurdly bullish signal from a single data point.

**Specific scenario:** Company IPO'd in October 2025. It is now May 2026. It has 1 quarter of earnings history (Q4 2025) where it beat by +15%. EBP = 1/1 = 100% -> capped at 95% -> +3 to composite. Meanwhile, a battle-tested company with 6 beats out of 8 quarters gets EBP = 75% -> +1 to composite. The IPO gets 3x the modifier with 1/8th the evidence. This is a statistical confidence problem the system ignores entirely.

**Proposed fix:** Add a minimum-quarter gate to the EBP calculation:

| Quarters Available | Treatment |
|---|---|
| < 2 | EBP NOT CALCULABLE. Override 6 does not apply. Note: "EARNINGS CATALYST: Insufficient history ({N} quarters). No modifier." |
| 2-3 | Halve the EBP modifier (round toward zero). +3 becomes +1, +1 becomes +0, -2 becomes -1, -4 becomes -2. Note: "LIMITED HISTORY: {N} quarters -- modifier halved." |
| >= 4 | Full modifier as designed. |

---

### FLAW 4: AMD Was Analyzed 1 Day Before Earnings But Did NOT Get Pre-Earnings Weights

**The evidence:** AMD was analyzed on May 4, 2026. The report explicitly states: "Earnings: TOMORROW (May 5, after close)." This is 1 calendar day before earnings -- well within the 7-day window.

The composite calculation table in `AMD_2026-05-04.md` (lines 113-126) uses these weights:

| Dimension | Weight Used |
|---|---|
| Technical | 22% |
| Fundamental | 15% |
| Valuation | 15% |
| Smart Money | 13% |
| Risk | 12% |
| Backtest | 10% |
| Sentiment | 7% |
| Macro | 6% |

These are the **normal weights**, not the pre-earnings weights. The pre-earnings weights should have been: Technical 12%, Fundamental 22%, Valuation 12%, Sentiment 20%, Smart Money 13%, Macro 8%, Risk 10%, Backtest 3%.

**Impact of the error:** With pre-earnings weights, the composite would be:

| Dimension | Score | Pre-Earnings Weight | Weighted |
|---|---|---|---|
| Technical | 5 | 12% | 0.60 |
| Fundamental | 8 | 22% | 1.76 |
| Valuation | 3 | 12% | 0.36 |
| Smart Money | 5 | 13% | 0.65 |
| Risk | 3 | 10% | 0.30 |
| Backtest | 2 | 3% | 0.06 |
| Sentiment | 7 | 20% | 1.40 |
| Macro | 7 | 8% | 0.56 |
| **Total** | | **100%** | **5.69** |

Raw composite with pre-earnings weights: **57/100** (vs 49/100 with normal weights). After Override 1 (-5 overbought) = 52. After Override 5 (-5 extension) = 47. **The signal would be HOLD (47), not SELL (39).** The failure to apply pre-earnings weights changed the signal from HOLD to SELL -- a material error.

Additionally, **Override 6 (Earnings Catalyst Modifier) was never applied.** AMD has a beat history (2 beats out of 3 confirmed quarters, per the report), estimate revisions were positive (Bernstein raised estimates), and earnings were within 7 days. The EBP should have been computed and a modifier applied. There is zero mention of Override 6 in the AMD report.

Furthermore, there is no "PRE-EARNINGS WEIGHT SWITCH" note anywhere in the AMD report, which the rubric explicitly requires: "Note: 'PRE-EARNINGS WEIGHT SWITCH: Earnings in {N} days. Weights shifted to fundamental/sentiment emphasis.'"

**Proposed fix:** This is a compliance failure, not a design flaw. The rules exist but were not followed. Add a mandatory pre-check at the top of synthesis: "EARNINGS PROXIMITY CHECK: Before computing any weights, determine earnings date. If within 7 calendar days, STOP and switch to pre-earnings weight table. Log the note. This is not optional."

---

### FLAW 5: PLTR Post-Earnings Analysis Missed Override 7 (Sell-the-News Detector)

**The evidence:** PLTR reported Q1 2026 earnings on May 4 (after hours). The PLTR analysis is dated May 5, 2026 -- exactly 1 trading day after earnings. The synthesize.md rule says Override 7 triggers "within 2 trading days AFTER earnings report."

PLTR's Q1 2026 results (from the report, lines 147-159):
- EPS beat: $0.33 vs $0.28 = +17.9% (> 10% threshold: YES)
- Revenue beat: $1.63B vs $1.54B = +5.8% (> 3% threshold: YES)
- Stock change post-earnings: -6.93% (< -5% threshold: YES)
- Valuation: P/S 59.6x (> 30x threshold: YES) AND P/E 142.6x (> 100x: YES)

**ALL FOUR conditions for Sell-the-News are met.** Override 7 should have subtracted 5 from the composite, dropping it from 50 to 45. The signal would still be HOLD, but the modifier and note should appear.

Additionally, the supplemental check fires: 6M return is -22.4% (< -15%) AND earnings beat -> should note "Stock in distribution phase despite strong fundamentals."

**Neither Override 7 nor the distribution-phase note appears anywhere in the PLTR report.** The Overrides Applied section (lines 255-258) lists Overrides 1-5 but skips 6 and 7 entirely. There is no mention of the Sell-the-News detector despite all conditions being satisfied.

**Proposed fix:** Same as Flaw 4 -- compliance failure. The Override 7 check should be mandatory when the fundamental report shows recent earnings results. Add a checklist item to synthesize.md: "POST-EARNINGS CHECK: If the fundamental report contains actual EPS/revenue results from the last 2 trading days, Override 7 MUST be evaluated. Document the evaluation even if conditions are not met."

---

### FLAW 6: No Handling of Intraday Earnings Reports

**The rule:** The system assumes a binary pre/post state. But some companies report earnings during market hours (e.g., before market open, or mid-day).

**The problem:** If a company reports at 7am ET (before market open), an analysis run at 11am the same day is technically "post-earnings" but the system's date-based logic would see "analysis date = earnings date" and might classify it as either pre- or post-earnings depending on implementation. The rubric uses "calendar days" and "trading days" but never specifies time-of-day.

**Specific scenario:** Company reports at 7:00am ET on May 5. The system runs analysis at 2:00pm ET on May 5. The earnings date is May 5. Is the system 0 days before earnings (pre-earnings weights) or 0 days after earnings (Override 7)? The rubric says "within 7 calendar days" before and "within 2 trading days AFTER." Same-day satisfies BOTH conditions. The system could theoretically apply pre-earnings weights AND Override 7 simultaneously, which is contradictory.

**Proposed fix:** Add a time-aware earnings classification:

```
Step 0 — Determine Earnings Regime:
1. Get earnings date AND reporting time (BMO = Before Market Open, AMC = After Market Close)
2. If earnings date is TODAY:
   a. If BMO and market is open: POST-EARNINGS regime (Override 7 eligible)
   b. If AMC and market is open: PRE-EARNINGS regime (weight switch)
   c. If AMC and market is closed: PRE-EARNINGS regime (report hasn't happened yet)
3. If earnings date is in the future within 7 calendar days: PRE-EARNINGS
4. If earnings date was within 2 trading days ago: POST-EARNINGS (Override 7)
5. Regimes are MUTUALLY EXCLUSIVE. Never apply both.
```

The FMP `getEarningsCalendar` API does return a `time` field (BMO/AMC), so this data is available.

---

### FLAW 7: Estimate Revision Direction Cannot Be Determined From Available Data

**The rule:** EBP Step 1: "If estimate revisions positive in last 30 days: +10%."

**The problem:** The system calls `getAnalystEstimates` which returns *current* consensus estimates (estimated EPS and revenue for future quarters). It does NOT return historical estimate snapshots. To determine if revisions are "positive in last 30 days," you need to compare today's consensus to 30-days-ago consensus. The FMP API does not provide historical estimate time-series.

The system partially addresses this via the Phase 15 WebSearch call: "WebSearch query: '$ARGUMENTS earnings estimate revisions {current_year}' -- analyst estimate revision trend from Zacks/Yahoo. Fallback for broken getAnalystEstimates." But this is a web scrape of unstructured text, not a quantitative comparison. The AMD report (line 33) shows qualitative data: "Bernstein raised Q1 revenue from $9.8B to $9.9B" -- this came from WebSearch, not from the API.

**The core issue:** The +10% EBP modifier is supposed to be quantitative ("revisions positive") but the data source is qualitative (scraping Zacks headlines). What counts as "positive"? If 3 analysts raised estimates and 1 lowered, is the net direction positive? The rubric doesn't define this. For the AMD case, "net upward revisions, but stock has priced in expectations" was noted -- but even that determination required human-level judgment, not a computable signal.

**Proposed fix:** Define the revision check explicitly:

```
Estimate Revision Check:
1. PRIMARY: WebSearch "{SYMBOL} earnings estimate revisions" on Zacks.com or Yahoo Finance.
   Look for Zacks Estimate Revisions table showing "Last 7 Days" and "Last 30 Days" columns.
2. POSITIVE = more upward revisions than downward in last 30 days (by count, not magnitude).
3. NEGATIVE = more downward than upward.
4. MIXED/UNAVAILABLE = do not apply the +10% modifier. Note: "Estimate revision data inconclusive."
5. SECONDARY: If WebSearch fails, check getAnalystEstimates current quarter estimate vs 
   getEarningsReports prior quarter actuals. If current estimate > prior actual * (1 + historical growth rate),
   analysts are implicitly revising up. This is a rough proxy.
```

Alternatively, add `getEarningsSurprisesBulk` data to track whether actual results have been trending above estimates, which is a proxy for "analysts are behind the curve."

---

### FLAW 8: Pre-Earnings Weights and Post-Earnings Override 7 Can Conflict on Edge Dates

**The rule:** Pre-earnings weights apply "within 7 calendar days" before. Override 7 applies "within 2 trading days AFTER."

**The problem:** Consider after-hours earnings. AMD reports earnings May 5 after close. Analysis runs May 5 at 3:00pm -- before the earnings call at 4:30pm. The system correctly applies pre-earnings weights. But then the earnings come out at 4:30pm. If someone re-runs the analysis at 5:00pm the same day, the system should switch to post-earnings mode. But there is no mechanism in the design to detect that earnings have *already been reported* on the same calendar date.

**Worse edge case:** Analysis runs May 4 (Sunday? No -- May 4, 2026 is a Monday). Earnings report comes out May 4 after-hours. The system ran with pre-earnings weights at 2pm. The AMD report is dated May 4. If someone looks at this report on May 5 (after earnings are out), the report's pre-earnings-weighted recommendation is stale in a way that is not flagged.

**The actual AMD case demonstrates this perfectly:** AMD was analyzed on May 4. Earnings were May 5 after close. The analysis correctly identified "Earnings: TOMORROW." But the system failed to apply pre-earnings weights (Flaw 4). If it had, the pre-earnings weights would have been correct for May 4. But there is NO mechanism to flag the report as "expires after earnings" or "re-analyze required post-earnings."

**Proposed fix:** Add a report expiry concept:

```
When Pre-Earnings Weight Switch is active:
1. Add header: "EXPIRES: After {SYMBOL} earnings report on {DATE} {TIME}. Re-analyze immediately post-earnings."
2. After override application, note: "This analysis assumes NO earnings information. 
   If earnings have already been reported, this analysis is INVALID."
3. In scores.csv, add column: expires_after_event={earnings_date}
```

---

### FLAW 9: Sell-the-News Detector Requires Actual EPS That May Not Be Available

**The rule:** Override 7 requires "EPS beat > 10%" which means actual EPS vs estimated EPS.

**The problem:** When analyzing within 2 trading days after earnings, the actual EPS must come from somewhere. The FMP `getEarningsReports` API typically has actual EPS populated within hours of the earnings call. But "within hours" is not instantaneous. If the system runs at 6:00am the morning after an after-hours report, the FMP database may not yet have the actual EPS populated.

**Specific scenario:** Company reports at 4:15pm ET on Monday. The system runs analysis at 6:30am ET on Tuesday (within 2 trading days). `getEarningsReports` still shows the *prior* quarter as the most recent, because FMP hasn't ingested the new quarter's data yet. Override 7 cannot fire because there is no actual EPS to compare against. By the time FMP updates (say, noon Tuesday), the system has already produced a report without Override 7.

For the PLTR case, the earnings data was available (the report contains a full table of actuals vs estimates on lines 147-159). But the system still failed to apply Override 7 -- this time not because of data availability but because of a compliance failure (Flaw 5). The data availability problem is an additional, separate risk.

**Proposed fix:**

```
Override 7 Data Availability Check:
1. Check getEarningsReports for actual EPS/revenue from the most recent quarter.
2. If actual data is present and report date is within 2 trading days: proceed with Override 7.
3. If actual data is NOT present but earnings were scheduled within 2 trading days (per getEarningsCalendar):
   a. Run WebSearch "{SYMBOL} Q{N} {YEAR} earnings results EPS revenue"
   b. Extract actual EPS and revenue from press coverage (Reuters, Bloomberg, company PR)
   c. If found: proceed with Override 7 using web-sourced actuals
   d. If NOT found: Note "OVERRIDE 7: Cannot evaluate -- actual EPS not yet available in FMP. 
      Earnings were scheduled {DATE}. Manual check required." Flag report as INCOMPLETE.
4. NEVER skip Override 7 silently when post-earnings conditions exist.
```

---

## Summary of Findings

| Flaw | Type | Severity | Evidence |
|------|------|----------|----------|
| 1. 7-calendar-day window | Design flaw | Medium | Calendar vs trading day mismatch; inconsistent with Risk rubric's 14-day window |
| 2. Unknown earnings date | Missing edge case | High | No defined behavior; silent default to normal weights |
| 3. EBP with <4 quarters | Missing edge case | High | 1/1 = 100% EBP gives +3 modifier from a single data point |
| 4. AMD missing pre-earnings weights | Compliance failure | **Critical** | Changed signal from HOLD (47) to SELL (39); Override 6 also missing |
| 5. PLTR missing Override 7 | Compliance failure | **Critical** | All 4 Sell-the-News conditions met; 5-point deduction not applied |
| 6. Intraday earnings timing | Design flaw | Medium | No time-of-day handling; same-day analysis ambiguous |
| 7. Estimate revision uncomputable | Design flaw | Medium | +10% EBP modifier requires data the API doesn't provide |
| 8. Pre/post regime conflict | Design flaw | Medium | No report expiry; stale pre-earnings reports not flagged |
| 9. Actual EPS availability | Design flaw | Medium | FMP may not have actuals immediately; no fallback defined |

The two most damaging findings are **Flaw 4** (AMD) and **Flaw 5** (PLTR), both compliance failures where existing rules were simply not applied. Flaw 4 is the worst: it flipped a HOLD to a SELL for a stock 1 day before earnings, the exact scenario the pre-earnings weight switch was designed to handle. The system's most sophisticated earnings logic -- weight switching, EBP calculation, and Override 6 -- was completely bypassed in the one report where it most needed to fire.