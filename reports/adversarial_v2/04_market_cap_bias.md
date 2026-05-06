# Adversarial Audit: Market Cap & Size Bias
## Date: 2026-05-06

I'll start by reading the scoring rubrics and scores.csv, then examine individual reports.

---

Now let me read the individual reports for stocks of varying sizes. Let me get reports for AMD (large-cap), FIX (mid-cap), and KLTR, BBAI, SATS (small-caps).

---

Let me read the full synthesis reports for AMD (large-cap), PLTR (large-cap), FIX (mid-cap), GEV (mid-cap), KLTR (small-cap), BBAI (small-cap), and SATS (small-cap).

---

Now let me also check the AMPX and INFQ reports for additional small-cap data points.

---

Now I have comprehensive data across all market cap tiers. Let me also check for the share float data on these stocks.

---

Now let me check how the rubric handles missing options data and look for the watchlist ranking report for a cross-stock comparison.

---

I now have comprehensive data to perform the market cap and size bias audit. Let me compile the findings.

---

# ADVERSARIAL AUDIT: Market Cap and Size Bias in the Scoring System

**Date:** 2026-05-06
**Scope:** Systematic biases that favor or penalize stocks based on market capitalization
**Stocks examined:** AMD (~$230B), PLTR (~$300B), FIX (~$66B), GEV (~$290B), KLTR (~$220M), BBAI (~$820M), SATS (~$35B), AMPX (~$2.9B), INFQ (~$2.1B)

---

## BIAS 1: Backtest Trade Count Gate — Structural Small-Cap Penalty

**Finding:** The trade count gate penalizes ALL stocks in this watchlist equally, but the mechanism differs by cap size. The rubric caps scores at 2 for <5 trades, at 4 for 5-9 trades, and at 6 for 10-14 trades.

**Evidence from reports:**
- AMD (large-cap): 5 trades, capped at 4, final score 2
- PLTR (large-cap): 2 trades, capped at 2, final score 1
- FIX (mid-cap): 8 trades, capped at 4, final score 1
- GEV (mid-cap): 9 trades, capped at 4, final score 2
- KLTR (small-cap): 4 trades, capped at 2, final score 2
- BBAI (small-cap): 7 trades, capped at 4, final score 2
- SATS (small-cap): 7 trades, capped at 4, final score 1
- AMPX (small-cap): 4 trades, capped at 2, final score 2
- INFQ (micro-cap): 1 trade, capped at 2, final score 2

**Surprise finding:** The trade count gate is NOT primarily a small-cap problem. The average backtest score is 1.9/10 across the entire watchlist regardless of market cap. The real bias is that the 1-year backtest window is too short for ALL stocks in a strong bull market. Buy-and-hold crushes every strategy for every stock (B&H ranges from +23% to +788%), triggering the -2 penalty universally.

**However,** the Adaptive Backtest Weighting (rubric lines 233-246) does partially address this by reducing the Backtest weight from 10% to 2% when trades <5, redistributing 8% to other dimensions. INFQ's report explicitly applies this IPO adjustment. But KLTR and AMPX (both with 4 trades) should also benefit from the 2% effective weight, and their reports do not mention this adjustment.

**Quantified impact:** For KLTR, if Adaptive Backtest Weighting were applied (reducing weight from 10% to 2%), the 8% redistributed to other dimensions would change the composite from 49 to approximately 50 (small because the backtest score of 2 is close to the weighted average of other dimensions). Impact: ~1 composite point.

**Proposed fix:** The Adaptive Backtest Weighting already exists in the rubric. The issue is inconsistent application. Add an enforcement rule: "Adaptive Backtest Weighting is MANDATORY when trade count triggers a cap, not optional." Also consider extending backtest windows for low-trade-count stocks (2Y or 3Y) before capping.

---

## BIAS 2: Options Flow — Complete Data Void for Small-Caps

**Finding:** This is the most severe size bias in the system. KLTR has NO options market at all. Its report explicitly states "No options market for KLTR" and "All Metrics: N/A." Despite this, the Smart Money dimension still receives a score (4/10), effectively scoring KLTR only on insider trades and institutional flow, which are the weakest signals for a micro-cap.

**Evidence from reports:**
- AMD: Full options data (P/C 0.43, institutional P/C 1.30, IV skew, unusual activity). Options contribute meaningfully to Smart Money 5/10.
- PLTR: Rich options data (P/C 0.88, OI proxy 1.04, unusual call buying 12x, premium trends). Options drive Smart Money to 6/10.
- FIX: Partial options (P/C ~0.6, IV/HV ~1.15, skew data). Max Pain and unusual activity N/A due to missing OI.
- GEV: Partial options (P/C ~1.05, IV/HV ~1.3). Max Pain and unusual activity N/A.
- KLTR: **ZERO options data.** No chain exists.
- BBAI: Rich options data (P/C 0.20 strongly bullish, IV/HV 4.6x, unusual call activity 6,414 vol). Options data boosted Smart Money from ~4 to 7/10.
- SATS: Partial options (P/C ~1.05, expected move, active strikes). OI unavailable.
- AMPX: Partial options (P/C ~0.68, unusual 649-lot put block). Missing OI.
- INFQ: Partial options (P/C 0.63, IV skew +52.2%, institutional P/C via 13F). Despite micro-cap, some data available.

**Quantified impact:** BBAI's Smart Money score was boosted from ~4-5 to 7/10 primarily because of its strongly bullish options flow (P/C 0.20). KLTR, which has NO options data, scored 4/10 on Smart Money. If KLTR had similarly bullish options flow, Smart Money could have been 6-7/10 instead of 4/10. At 13% weight, a 3-point increase in Smart Money = +3.9 composite points. KLTR's composite would move from 49 to approximately 53 -- potentially the same rank as NVT and GEV.

**The rubric does NOT specify how to handle missing options data.** There is no provision saying "If options data is unavailable, redistribute options weight within Smart Money to insider + institutional signals" or "cap Smart Money at X when options data is missing."

**Proposed fix:** Add to the Smart Money rubric:
1. "If NO options market exists for the stock, redistribute options signal weight (approximately 25% of Smart Money) equally to insider and institutional signals. Note: 'OPTIONS N/A -- weight redistributed.'"
2. "If options data exists but OI is unavailable (partial data), cap the options signal confidence at 50% and note 'PARTIAL OPTIONS DATA.'"
3. Do NOT penalize the composite for missing options -- the absence of an options market is a market structure fact, not a bearish signal.

---

## BIAS 3: Insider Trading Dollar Thresholds — Relative vs. Absolute Magnitude

**Finding:** The rubric uses absolute dollar thresholds: $1M C-suite buy = boost +1, $10M multiple insider selling = reduce -1. These thresholds are appropriate for large-caps but create asymmetric signals for small-caps.

**Evidence from reports:**
- AMD (~$230B mkt cap): $34.6M insider selling from CEO + CTO. $34.6M / $230B = 0.015% of market cap. Treated as significant despite being trivial relative to company value. Ceiling set at 5 (with 10b5-1 mitigation).
- PLTR (~$300B): $3.3M director selling. 0.001% of market cap. 10b5-1 confirmed. Only 2% of Moore's holdings. Treated as mild signal.
- KLTR (~$220M): Net selling of ~$32K. But the BUYS of ~$32K by directors at $1.21-1.29 represent these individuals putting personal money at risk on a $220M company. A director buying $10K of stock in a $220M company is roughly equivalent to a director buying $10M of stock in a $220B company in terms of conviction signal. Yet the rubric assigns ZERO boost because neither buy exceeds $1M.
- BBAI (~$820M): Director sold $320K. This is 0.04% of market cap. The rubric treats this as "small magnitude" and essentially ignores it. But $320K at a $820M company is proportionally equivalent to ~$90M at a $230B company.
- SATS (~$35B): CEO sold $7.63M. This is 0.02% of market cap. Treated as a moderate signal. 10b5-1 not verified.
- AMPX (~$2.9B): $33M insider selling. 1.1% of market cap. This is a MASSIVE signal for a $2.9B company, yet it received the same 10b5-1 severity reduction as AMD's $34.6M on a $230B company.

**Quantified impact:** KLTR's three director buys ($10K each at a $220M company) are arguably a stronger conviction signal than AMD's CEO's $34.6M sale at a $230B company (which was pre-arranged via 10b5-1). But the rubric assigns the KLTR buys zero boost and the AMD sales a ceiling reduction. If the rubric used relative thresholds (e.g., 0.5% of market cap for small-caps instead of $1M absolute), KLTR's Smart Money could gain +1 (from 4 to 5), adding 1.3 composite points.

**Proposed fix:** Add relative thresholds alongside absolute ones:
- "C-suite buys >$1M OR >0.5% of market cap (whichever is lower for companies <$5B market cap): boost +1."
- "Multiple insider selling >$10M OR >1% of market cap (whichever is lower): reduce -1."
- "For micro-caps (<$1B), consider insider ownership percentage change as the primary signal. A CEO increasing stake from 15% to 18% is more meaningful than the dollar value."

---

## BIAS 4: Analyst Coverage Gap — Thin Coverage Penalty

**Finding:** The rubric does not explicitly penalize thin analyst coverage, but the Valuation and Sentiment dimensions implicitly require analyst data. Stocks with 0-3 analysts have structurally lower confidence in their Valuation and Sentiment scores.

**Evidence from reports:**
- AMD: 5 analysts cited in valuation, 36 Buy / 13 Hold / 0 Sell overall. Dense coverage.
- PLTR: 31 analysts, 18 Buy / 11 Hold / 2 Sell. Rich consensus data.
- FIX: 4 analysts last month. Consensus Buy. Moderate coverage.
- GEV: 13+ analysts, 28 Buy / 7 Hold / 0 Sell. Adequate coverage.
- KLTR: **1-2 analysts** (Needham reaffirmed Buy $3 PT). Warning: "Only 1-2 analysts cover KLTR -- thin coverage, Valuation confidence reduced."
- BBAI: **2 analysts** last year. "Very low coverage."
- SATS: 8 analysts, mixed (3 Buy, 2 Hold, 1 Strong Sell). Adequate for its size.
- AMPX: 2 analysts last quarter, 9/9 Buy. But analyst target $18.50 is BELOW current price, suggesting targets are stale.
- INFQ: **Only 2 analysts** (Citi $20, BTIG $22). "Low confidence."

**Impact on Valuation:** KLTR's valuation score of 7/10 was actually HELPED by thin coverage -- the single analyst target of $4.00 represents +174% upside, which maps to a strong valuation signal. But this is a fragile signal -- one analyst could withdraw coverage and the valuation anchor disappears entirely.

**Impact on Sentiment:** For the Analyst Actions sub-component (10% weight in Sentiment), KLTR has exactly 1 recent analyst action (Needham reaffirmed Buy). With so few data points, the signal is either all-or-nothing: one downgrade would flip the entire analyst sentiment. For AMD/PLTR with 30+ analysts, individual actions are diluted. This creates HIGHER VARIANCE, not necessarily bias -- but the rubric treats a single analyst's Buy the same as a consensus of 31.

**Quantified impact:** The impact is more about variance than directional bias. KLTR's Valuation 7/10 could swing to 3/10 if its one analyst dropped coverage or lowered the PT. For AMD/PLTR, the Valuation score is anchored by consensus and cannot swing more than 1-2 points on a single analyst action. This variance asymmetry means small-cap scores are less stable over time, which is a hidden risk not captured anywhere.

**Proposed fix:** Add a "Coverage Confidence Modifier" to the Valuation dimension:
- "<3 analysts: Note 'LOW ANALYST CONFIDENCE -- score variance elevated.' Do not cap the score, but flag it."
- "If analyst count = 1 AND the target is >50% from price (in either direction), treat it as 'indicative only' and weight DCF or peer comparison more heavily."
- In Sentiment, if <3 analysts, redistribute the Analyst Actions weight (10%) to News NLP.

---

## BIAS 5: DCF Reliability for Pre-Profit Small-Caps

**Finding:** The rubric states "Track B: Use custom DCF. If still undervalues, PEG overrides." But for companies with negative earnings AND negative/near-zero revenue growth, DCF models produce absurd results. The rubric handles this by routing to "Track A" (broken growth story), but then Track A's DCF-centric approach also fails completely.

**Evidence from reports:**
- AMD: DCF $64.88 (standard) / $64.41 (levered) vs price $360.54. DCF is structurally unsuited but at least produces positive numbers.
- PLTR: DCF $10.72-17.94 vs price $135.91. All show >90% overvaluation. Report notes "DCF unreliable for hypergrowth."
- FIX: DCF $1,058-1,623 vs price $1,868. DCF is below price but provides useful context.
- KLTR: DCF $3.77 (standard) / $5.37 (levered) vs price $1.46. DCF shows massive UPSIDE (+158-268%). Custom DCF "invalid." DCF actually helps KLTR here.
- BBAI: DCF **negative** (-$0.09, -$0.03). "Stock price >$4 above intrinsic value." Custom DCF "model broke." The DCF model literally says the company is worth less than zero.
- SATS: DCF **negative** (-$184.64, -$122.52). "Model breaks on negative cash flows." Custom DCF "inputs would produce meaningless results." Note: "SATS trades on asset value (SpaceX equity stake ~$11.1B + spectrum portfolio), not earnings power."
- AMPX: DCF **negative** (-$79.84, -$95.43). "Negative -- irrelevant for pre-profit company."
- INFQ: DCF $0.027 (essentially zero). "Confirmed unreliable."

**The pattern is stark:** 4 of 5 small-caps produce negative or near-zero DCF values, which automatically push Valuation toward 1-2 range. The rubric says "Track A: Price >200% of DCF = 1-2 range" -- but when DCF is negative, ANY positive stock price is infinitely above DCF. This is not a meaningful valuation signal.

**Quantified impact:** BBAI scored Valuation 2/10, SATS scored 2/10, AMPX scored 3/10 (saved by PSG), INFQ scored 3/10 (saved by forward PSG and P/B). If the DCF component were neutralized (score 5/10) for companies where DCF produces negative values, and the remaining weight given to peer multiples and analyst targets:
- BBAI: Valuation could move from 2 to 3 (+1 point at 15% weight = +1.5 composite)
- SATS: Valuation could move from 2 to 3 (+1.5 composite)
- AMPX: No change (PSG already routing)

**Proposed fix:** Add explicit handling for negative DCF:
- "If both standard and levered DCF produce negative values, DCF is NOT a valid input. Remove DCF from the Valuation calculation and rely exclusively on: (a) PEG/PSG for Track B, (b) P/S relative to peers and analyst targets for Track A. Note: 'DCF INVALID -- negative intrinsic value. Valuation based on peer multiples and analyst consensus only.'"
- For asset-heavy companies like SATS: "If a company has identifiable asset values (stakes, real estate, spectrum, patents) exceeding 50% of market cap, use sum-of-parts valuation as DCF substitute."

---

## BIAS 6: Float and Short Interest -- Unused Data

**Finding:** The rubric mentions `getShareFloat` but does not incorporate float or short interest into ANY scoring dimension. Small-caps with tiny floats are inherently more volatile, and this volatility is double-counted in Beta (Risk score penalty) without acknowledging that low float IS the mechanism behind high beta.

**Evidence from reports:**
- INFQ: Free float explicitly noted as 23.86% ("very low -- amplifies moves"). Beta 5.60. The report connects these dots -- the tiny float causes the extreme beta. But the rubric penalizes the beta (Risk score 2/10) without acknowledging that the float is the root cause and that low float can also be a POSITIVE for price appreciation.
- KLTR: No float data in report. 98 institutional holders with 27.2% ownership. The rest is presumably insider-held.
- BBAI: No float data, but beta 3.24 suggests constrained float.
- AMD: No float data, but with 94% institutional ownership and 1.6B+ shares outstanding, the float is massive and liquid.

**Quantified impact:** INFQ's beta of 5.60 creates a Risk score of 2/10. If float were incorporated as a modifier (e.g., "if beta >2.0 is primarily driven by float <30%, reduce beta penalty by 1 tier"), Risk could move from 2 to 3, adding 1.2 composite points.

**More importantly,** high short interest in small-caps can be a catalyst for short squeezes. The system completely misses this. A stock with 40% short interest and declining borrow availability is a materially different setup than one with 5% short interest, yet neither appears in the scoring.

**Proposed fix:**
1. Add short interest to Risk scoring: "Short interest >20%: subtract 1 from Risk (higher squeeze/volatility risk). Short interest >40%: subtract 2."
2. Add short interest to Smart Money as a supplementary signal: "Short interest declining >5pp in 30 days while price rising: +1 to Smart Money (short covering = forced buying)."
3. Add float-adjusted beta interpretation: "If beta >2.0 AND free float <30%, note 'FLOAT-AMPLIFIED BETA -- high beta driven by low float mechanics, not fundamental risk.' Consider reducing beta penalty by 1 tier in Risk scoring."

---

## BIAS 7: Beta Penalty -- Inappropriate for Growth Micro-Caps

**Finding:** The Risk rubric assigns: Beta >2.0 = 3-4 base range, Beta 1.5-2.0 = 5-6. This is a severe penalty that assumes high beta is universally negative. For growth micro-caps, high beta is the EXPECTED behavior and often reflects asymmetric upside potential, not just downside risk.

**Evidence from reports:**
- INFQ: Beta 5.60. Risk score 2/10. This stock trades below cash ($12.41 vs $16.11/share) and below book value (P/B 0.94), yet gets the lowest risk score primarily because of beta. The downside is theoretically floored by cash value, but the risk scoring doesn't know this.
- BBAI: Beta 3.24. Risk score 2/10. Report explicitly labels it "EXTREME BETA."
- AMPX: Beta 2.22. Risk score 3/10. "Extreme volatility."
- AMD: Beta 1.963. Risk score 3/10 (also impacted by RSI overbought and earnings).
- PLTR: Beta 1.521. Risk score 4/10.
- FIX: Beta 1.598. Risk score 5/10.
- GEV: Beta 1.196. Risk score 4/10.
- KLTR: Beta not explicitly stated, risk score 4/10 (driven by earnings proximity and Z-Score distress).

**Quantified impact:** INFQ's Risk score of 2/10 contributes 0.24 weighted points (2 x 0.12). If Risk were 4/10 (using a micro-cap adjusted beta threshold), it would contribute 0.48 weighted points, adding 2.4 composite points. That would move INFQ from 37 to approximately 39-40.

For BBAI: Risk 2/10 with beta 3.24. If adjusted to 3/10, adds 1.2 composite points (39 to ~40).

**The deeper issue:** The Risk dimension at 12% weight is a significant drag on all small-caps in this watchlist. Average Risk score for small-caps (KLTR 4, BBAI 2, SATS 3, AMPX 3, INFQ 2) = 2.8. Average for large/mid-caps (AMD 3, PLTR 4, FIX 5, GEV 4, NVT 4) = 4.0. The 1.2-point average gap at 12% weight = 1.44 composite points of systematic drag against small-caps.

**Proposed fix:** Add a market-cap-adjusted beta threshold:
- For companies >$10B market cap: current thresholds (beta >2.0 = 3-4 range).
- For companies $1B-$10B: beta >2.5 = 3-4 range, >1.5-2.5 = 5-6 range.
- For companies <$1B: beta >3.0 = 3-4 range, >2.0-3.0 = 5-6 range. Note: "MICRO-CAP BETA ADJUSTMENT: Higher beta threshold applied for market cap <$1B."
- Additionally: "If P/B <1.0 AND cash/share > stock price, beta >2.0 does NOT trigger automatic 3-4 base. Asset floor limits actual downside risk independent of beta."

---

## CUMULATIVE SIZE BIAS SUMMARY

| Bias | Affected Small-Caps | Composite Point Impact | Direction |
|------|---------------------|----------------------:|-----------|
| Backtest trade gate (inconsistent application) | KLTR, AMPX | ~1 pt | Penalty (slight) |
| Options flow void | KLTR (zero), others partial | up to 3.9 pts | Penalty |
| Insider dollar thresholds | KLTR, BBAI | ~1.3 pts | Penalty (missed signal) |
| Analyst coverage variance | KLTR, BBAI, AMPX, INFQ | 0-3 pts (variance) | Increased instability |
| DCF breakdown | BBAI, SATS, AMPX, INFQ | ~1.5 pts | Penalty |
| Float/short interest ignored | INFQ, BBAI | ~1.2 pts | Penalty |
| Beta penalty | INFQ, BBAI, AMPX | ~1.2-2.4 pts | Penalty |
| **Total potential cumulative small-cap penalty** | | **~5-12 pts** | **Systematic downward** |

A stock like KLTR, which has the highest Valuation score in the entire watchlist (7/10) and a legitimate recovery thesis, is potentially underscored by 5-8 composite points due to structural biases related to its size. Its "true" score -- if the system handled small-caps as well as it handles large-caps -- could be 54-57, placing it firmly in the top 5 alongside FIX and CRDO.

---

## TOP 3 PRIORITY FIXES (by impact)

1. **Options flow handling for illiquid/non-existent options markets** (up to 3.9 pts). Define explicit fallback rules when options data is absent. This is the single largest bias.

2. **DCF invalidity protocol** (1.5 pts + reduced noise). When DCF produces negative values, exclude it from Valuation scoring and route to peer multiples or asset-based valuation. This affects 4 of 5 small-caps.

3. **Market-cap-adjusted beta thresholds in Risk scoring** (1.2-2.4 pts). Micro-caps inherently have higher beta due to float mechanics. Penalizing them identically to large-caps double-counts the risk. Add tiered thresholds.