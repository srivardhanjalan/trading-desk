# Adversarial Audit: Data Integrity & Cross-Symbol Contamination
## Date: 2026-05-06

I'll start by reading all the specified files to understand the pipeline and then examine the reports for data integrity issues.

---

Now let me read the individual stock reports.

---

Now let me check the sub-reports for these stocks and the shared configuration files to cross-reference data integrity.

---

The intermediate phase reports have been cleaned up. Let me check the shared files for the sector ETF mapping and other shared configurations that could cause data leakage.

---

Good, the intermediate reports are available. Let me read the relevant ones to cross-check data attribution.

---

Now let me check the key concern areas. Let me look at how the `getEarningsCalendar` and `smart_volume_scanner` and other exchange-wide calls are documented and how the sector ETF mapping works.

---

Now let me check the FIX reports and look for the specific sector ETF mapping issue.

---

Now let me check the key areas of concern more carefully. Let me look at whether the earnings calendar data (unfiltered) could cause cross-contamination, and check VIX values across reports.

---

Now let me check some critical cross-stock comparison points. Let me verify if VIX values and macro data are consistent/shared across same-day reports, and verify the `getEarningsCalendar` handling.

---

Now let me check the `getEarningsSurprisesBulk` call which is documented to return ALL companies for a year. Let me also check if there's a `getEarningsCalendar` cross-contamination risk.

---

Now let me check for the `getEarningsSurprisesBulk` handling and other batch calls that might cross-contaminate.

---

Now I have a comprehensive view of the entire pipeline. Let me do a few more targeted checks.

---

Now I have a thorough understanding of the entire pipeline. Let me now do a few final targeted checks to verify specific numbers in reports.

---

Now let me verify the Macro score capping rule for sector ETF and check if it was correctly applied across reports.

---

This is a critical finding. Let me verify AMD's Macro score against this rule.

---

Let me also check that CRDO correctly uses SMH as its sector ETF (it's classified as "Communication Equipment" not "Semiconductors").

---

This is a finding. CRDO is classified as "Communication Equipment" by FMP but is being mapped to SMH (Semiconductors) for the sector ETF. Let me check the mapping rules.

---

Now let me verify the VIX values and dates across reports more carefully to check for session caching issues.

---

Interesting. I see different VIX values across same-date reports (17.47 vs 18.16 vs 18.17 vs 18.14), which is expected since they might have been run at different times. But let me verify if AMD's VIX of 17.47 (same as the INFQ, ALMU, and FIX reports) versus CRDO's 18.17 is because they were run in different batches.

---

Good. Now let me check the `getEarningsSurprisesBulk` usage -- this is an unfiltered bulk call that returns ALL companies. Let me see if it's used correctly.

---

Now let me check a few more things -- the `getBatchQuotes` handling in peer comparison, and the `getEarningsCalendar` handling for AMD specifically.

---

Let me now verify the scores.csv data against the individual reports.

---

Let me verify the AMD scoring. The CSV shows: AMD,39,SELL,5,8,3,7,5,7,2,3,87. Let me check the report.

In the AMD report: Technical=5, Fundamental=8, Valuation=3, Sentiment=7, Smart Money=5, Macro=7, Backtest=2, Risk=3. Final composite=39. This matches the CSV.

Now let me verify PLTR: CSV shows 50,HOLD,4,9,4,5,6,7,1,4,88. Report shows Technical=4, Fundamental=9, Valuation=4, Sentiment=5, Smart Money=6, Macro=7, Backtest=1, Risk=4, Final=50. This matches.

CRDO: CSV shows 55,HOLD,7,8,8,7,5,7,1,3,85. Report shows Technical=7, Fundamental=8, Valuation=8, Sentiment=7, Smart Money=5, Macro=7, Backtest=1, Risk=3. Final=55. This matches.

FIX: CSV shows 56,HOLD,7,9,4,7,5,7,1,5,88. Report shows Technical=7, Fundamental=9, Valuation=4, Sentiment=7, Smart Money=5, Macro=7, Backtest=1, Risk=5. Final=56. This matches.

Now let me check one more thing -- whether the backtest Buy & Hold numbers are consistent per stock.

---

Now let me check if the 1Y return (278.7%) and the B&H return (282.06%) are approximately the same. They differ by ~3pp, which could be due to the backtest period not being exactly 1Y or different start dates. That seems fine.

Let me now check the FIX backtest B&H number vs its 1Y return.

FIX 1Y return: +329.19% (from technical report), B&H: 332.08% (from backtest). Close enough, the slight difference is expected from different measurement windows.

Now let me check for a potential PLTR data issue. PLTR was analyzed on 2026-05-05 (the day after the other stocks). The PLTR earnings were reported on May 4 (Sunday/after hours), and the report says the stock dropped 6.93%. Let me check if this post-earnings analysis correctly triggered the Sell-the-News check.

---

The PLTR report does not mention Override 7 (Sell-the-News) at all, despite analyzing PLTR on May 5 which is within 2 trading days after the May 4 earnings report. Let me verify the conditions.

---

Let me check what PLTR's stock change was post-earnings and what EPS/revenue beat was.

---

Now I have all the information I need. Let me compile the findings.

Here is the adversarial data integrity audit:

---

## Data Integrity Audit Findings

**1. CRITICAL -- AMD Macro Score of 7/10 violates the sector ETF data cap rule when SMH returns 402**

- **Files:** `/Users/srivardhanjalan/workspace/trading-desk/reports/AMD_2026-05-04.md` (line 90-91), `/Users/srivardhanjalan/workspace/trading-desk/reports/AMD_fundamental.md` (line 13)
- **Rule:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/_shared/scoring-rubrics.md` (line 207): "If sector ETF data is unavailable (FMP 402 or no data), cap Macro at 6."
- **Evidence:** The AMD fundamental report explicitly states: "Sector ETF (SMH): N/A -- FMP 402 -- tier limitation." Yet the AMD synthesis report scores Macro at 7/10 and justifies it with: "No rubric-defined modifier for missing sector ETF data." This directly contradicts the scoring rubric which explicitly defines a cap of 6 when sector ETF data is unavailable. The AMD Macro score should be 6, not 7. This 1-point error propagates to the composite: the weighted difference is 0.06 (7 vs 6 at 6% weight), which rounds to approximately 0.6 raw points. The composite would shift from 48.7 to 48.1 raw (still rounding to 48-49 pre-overrides), so the final signal likely remains SELL at 38-39, but the score is still technically wrong.
- **Severity:** HIGH -- The rubric has an explicit rule that was violated. The same issue may affect CDNS_2026-05-04.md which also shows "Sector ETF: N/A -- FMP 402" (visible in the grep results).

**2. HIGH -- CRDO sector ETF mapped to SMH (Semiconductors) despite FMP classifying CRDO as "Communication Equipment" industry**

- **Files:** `/Users/srivardhanjalan/workspace/trading-desk/reports/CRDO_technical.md` (line 8: "Industry: Communication Equipment"), `/Users/srivardhanjalan/workspace/trading-desk/reports/CRDO_fundamental.md` (line 7: "Sector ETF (SMH -- Semiconductors)")
- **Rule:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-fundamental.md` (line 17): The sector ETF mapping defines "Semiconductors -> SMH" and "Comm Services -> XLC" as separate mappings. The mapping key is based on the stock's sector/industry from `getCompanyProfile`.
- **Evidence:** CRDO is classified by FMP as Technology sector, Communication Equipment industry. The pipeline's lookup table maps by sector ("Technology -> XLK") and has a special carve-out only for "Semiconductors -> SMH." Communication Equipment is NOT semiconductors; it should map to XLK (Technology parent sector) or arguably XLC (Comm Services). The analyst manually overrode to SMH, labeling it "Semiconductors" in parentheses despite FMP's classification. While CRDO does design semiconductor connectivity products and SMH may be economically more appropriate, the pipeline's lookup table does not have "Communication Equipment" as a key, creating an ambiguous mapping that invites human judgment errors. The SMH +134% 1Y return is very different from XLK +55% 1Y, which would have changed the Macro scoring context.
- **Severity:** HIGH -- The sector ETF lookup table in `analyze-fundamental.md` line 17 has no entry for "Communication Equipment" as a sub-sector. The mapping is industry-name dependent but only has 12 entries (11 sectors + 1 sub-sector carve-out for Semiconductors), leaving dozens of FMP industry classifications unmapped. Any industry not explicitly listed falls through to the parent sector, but the pipeline applied a sub-sector override (SMH) not supported by the mapping rules.

**3. HIGH -- `getEarningsCalendar` returns ALL companies without symbol filter, creating cross-contamination risk**

- **Files:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-sentiment.md` (line 87)
- **Rule:** The command explicitly documents: "returns ALL companies' earnings (no symbol filter). Must search response for $ARGUMENTS."
- **Evidence:** The pipeline relies on the LLM to correctly search a large response for the target symbol. There is no programmatic filter -- the entire response (potentially hundreds of companies) is passed to the LLM context. If two symbols have similar tickers (e.g., if analyzing "BE" and the response contains "BEAM", "BEP", "BEST"), a mis-match could cause wrong earnings dates to be attributed. The same risk applies to `getEarningsSurprisesBulk` (line 107 of analyze-fundamental.md) which returns ALL companies' surprise data for a year. The pipeline instruction says to "track surprise MAGNITUDE trend" but does not specify a post-filter step for the bulk response like it does for `smart_volume_scanner`. This is a structural risk in the prompt-based pipeline since there is no code-level symbol filter.
- **Severity:** HIGH -- While the error-handling.md file (line 32-35) documents post-filtering for `smart_volume_scanner` and `advanced_candle_pattern`, it does NOT document post-filtering requirements for `getEarningsCalendar` or `getEarningsSurprisesBulk`, even though these have the same exchange-wide/bulk return pattern.

**4. MEDIUM -- PLTR analysis on 2026-05-05 (within 2 trading days post-earnings) did not evaluate Override 7 (Sell-the-News Detector)**

- **Files:** `/Users/srivardhanjalan/workspace/trading-desk/reports/PLTR_2026-05-05.md` (no mention of Override 7 anywhere in the file)
- **Rule:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/synthesize.md` (lines 166-170): "Override 7: Sell-the-News Detector (only if within 2 trading days AFTER earnings)." Conditions: EPS beat >10% AND revenue beat >3% AND stock change <-5% AND (P/S >30x OR P/E >100x).
- **Evidence:** PLTR Q1 2026 earnings were reported May 4. Analysis was May 5 (within 2 trading days). EPS beat = +19% (>10%), revenue beat = +6% (>3%), stock down -6.93% (<-5%), P/S = 59.6x (>30x) AND P/E = 142.6x (>100x). ALL four conditions are met. Override 7 should have subtracted 5 from composite, changing the score from 50 to 45 and the signal would remain HOLD (40-59 range), but the score and analysis are inaccurate. Additionally, the secondary note "Stock in distribution phase despite strong fundamentals" would apply since the 6M return is -22.4% (< -15%) AND earnings beat. Neither the primary override nor the secondary note appears in the report. The Overrides Applied section (lines 255-259) lists Overrides 1-5 but skips Override 6 and Override 7 entirely.
- **Severity:** MEDIUM -- The final signal (HOLD) would not change (45 is still HOLD), but the composite score would be 5 points lower (45 vs 50), which is a meaningful difference and the "Sell-the-News" and "distribution phase" warnings would provide important context for the investor.

**5. MEDIUM -- `getBatchQuotes` for peer comparison mixes target and peer data in a single response without documented extraction protocol**

- **Files:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-fundamental.md` (lines 67-69)
- **Rule:** Phase 8 Step 2 calls `getBatchQuotes` with "symbols=$ARGUMENTS + top 3 peers (comma-separated, e.g., 'AMD,NVDA,INTC,QCOM')." The response contains price, change%, marketCap, 50SMA, 200SMA for ALL symbols in one payload.
- **Evidence:** Unlike `smart_volume_scanner` and `advanced_candle_pattern`, which have explicit post-filter instructions in `error-handling.md` (lines 32-35), `getBatchQuotes` has no documented extraction protocol. The LLM must correctly attribute each quote in the batch response to the right column in the peer comparison table. In the AMD fundamental report (lines 149-163), peer data appears correctly separated (AMD $360.54, NVDA $198.45, INTC $99.61, QCOM $177.04), but the structural risk remains: if a peer ticker were invalid or missing from the response, the pipeline could silently shift columns. There is no validation step to confirm that the returned symbol matches the expected column.
- **Severity:** MEDIUM -- No actual misattribution found in the reports examined, but the lack of explicit extraction/validation protocol for batch responses is a structural gap.

**6. MEDIUM -- Sector ETF lookup table in `analyze-fundamental.md` is incomplete and maps by sector name, not industry**

- **Files:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-fundamental.md` (line 17)
- **Rule:** The mapping lists 12 entries: 11 GICS sectors + 1 industry carve-out ("Semiconductors -> SMH").
- **Evidence:** FMP returns over 100 distinct industry classifications (e.g., "Communication Equipment," "Software - Infrastructure," "Engineering & Construction," "Specialty Chemicals," etc.). The mapping only has one industry-level override (Semiconductors -> SMH). All other stocks must map by their parent sector field. This creates ambiguity for stocks whose sector classification is debatable or where sub-industries behave very differently from the sector ETF. For example, PLTR (Software - Infrastructure) maps to XLK (Technology), but its business (government/defense AI) may be more correlated with ITA (Defense) or ARKK (Innovation). FIX (Engineering & Construction) maps to XLI (Industrials), which is reasonable. But the pipeline has no way to express these nuances and no fallback for unrecognized sector strings.
- **Severity:** MEDIUM -- This is a design limitation rather than an active bug. It could cause systematic mismapping for stocks in niche industries.

**7. LOW -- No shared state/caching mechanism exists between sequential stock analyses, but VIX values vary within same-date batch**

- **Files:** Multiple reports dated 2026-05-04 show different VIX values: AMD/FIX/INFQ/ALMU = 17.47, CRDO = 18.17, ASX = 18.14, others = 18.16
- **Evidence:** The VIX call (`getIndexQuote` with symbol="^VIX") is made fresh per stock analysis. The different values (17.47 vs 18.16-18.17) indicate the analyses were run in at least two separate sessions/batches. The `analyze-fundamental.md` marks this call as "cacheable per session" (line 15), but since each stock analysis is an independent Claude conversation, there is no actual caching mechanism. This means each analysis gets a slightly different VIX reading. This is NOT a data integrity error (each reading was accurate at its time), but it means same-day composite scores across stocks are not directly comparable on the Macro dimension since they used different VIX values. FIX_fundamental.md (line 3) explicitly says "Treasury Yields: Cached" confirming some data was reused within a session, but VIX was re-fetched.
- **Severity:** LOW -- The variance (17.47 vs 18.17) is small and would not change any VIX regime label (both are "normal" in the 15-20 range). But for a systematic comparison dashboard, this inconsistency means Macro scores are not fully normalized across the watchlist.

**8. LOW -- `getEarningsSurprisesBulk` never appears in any stock report, suggesting it is called but its data may not be correctly attributed**

- **Files:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-fundamental.md` (line 107), all stock reports
- **Evidence:** The command specifies calling `getEarningsSurprisesBulk` with year={current year} in Phase 9 Step 2. However, searching all reports reveals this API's output is never directly referenced or attributed in any individual stock report. The previous adversarial audit (`adversarial_audit_2026-05-05.md`) noted this as a gap. It is unclear whether this bulk call (which returns surprise data for ALL stocks in a given year) was called and its data lost, or was never called at all. Either way, the pipeline specifies it should be used to "track surprise MAGNITUDE trend" but none of the reports show this trend analysis. The earnings surprise data in the reports comes from `getEarningsReports` (per-symbol) or WebSearch, not from the bulk endpoint.
- **Severity:** LOW -- The data is available through other per-symbol endpoints, so no wrong-symbol attribution has occurred. But the intended bulk-to-per-symbol extraction for this endpoint is not happening.

---

**Summary of findings:**
- 1 CRITICAL flaw (AMD Macro score violates explicit 402 cap rule)
- 3 HIGH flaws (CRDO sector ETF mis-mapping, `getEarningsCalendar` bulk response without post-filter protocol, missing post-filter for `getEarningsSurprisesBulk`)
- 3 MEDIUM flaws (PLTR Override 7 not evaluated, `getBatchQuotes` lacks extraction protocol, sector ETF lookup table incomplete)
- 2 LOW flaws (VIX variance across same-date batch, bulk endpoint data never surfaced)

No cases of actual wrong-symbol data appearing in a report were found (e.g., NVDA numbers in the AMD report). The peer comparison tables across all 4 reports examined contain plausible, correctly-attributed data. The flaws are primarily in the pipeline's structural safeguards against potential cross-contamination rather than confirmed instances of it.