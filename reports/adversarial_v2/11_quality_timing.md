# Adversarial Audit: Quality-Timing Split
## Date: 2026-05-06

I'll start by reading the three core files, then sample stock reports.

---

Now let me read 4-5 stock reports to see actual scoring details.

---

Let me read 5 synthesis reports to examine real scoring details.

---

Now let me also read the BBAI report to get a stock that's in SELL territory with interesting characteristics.

---

Now I have all the data I need. Let me compute the Quality and Timing scores for all 18 stocks systematically.

---

Now let me compute the specific near-miss and interaction scenarios.

---

Now let me check Issue 8 about pre-earnings weight interaction.

---

Now I have all the data to deliver a comprehensive audit. Here is the full analysis:

---

## Adversarial Audit: Quality-Timing Dual Score Architecture

### Overview

I analyzed the scoring rubrics (`scoring-rubrics.md`), the synthesis pipeline (`synthesize.md`), all 18 stocks in `scores.csv`, and 5 full reports (AMD, BE, PLTR, CRDO, FIX, BBAI). The Quality-Timing system has significant architectural problems. Seven of 18 stocks (39%) produce contradictory signals between composite and matrix, and the floor/override logic contains internal inconsistencies.

---

### ISSUE 1: Options Flow is Misclassified in Quality Score

**The problem.** Smart Money includes four sub-signals: insider trading, institutional ownership, congressional trades, and options flow (P/C ratio, unusual activity, IV skew). Options flow is a timing signal -- it measures what traders are betting *right now*, not whether the business is worth owning. Yet it sits inside Smart Money, which feeds the Quality Score at 25% weight.

**Real example: BBAI.** Smart Money = 7, boosted heavily by P/C ratio of 0.20 (massive pre-earnings call buying). Stripping options flow would likely drop Smart Money to 5-6, reducing Quality from 41.5 to ~36.5 -- a 5-point swing. That pre-earnings speculative bet has no bearing on business quality (BBAI has Piotroski 3/9, Z-Score 1.12 distress, revenue -19.3%).

**Real example: PLTR.** Smart Money = 6 includes P/C 0.88 and unusual call activity on down days. Options flow contributes roughly 2.5 points to Quality, inflating it from ~63.5 to 66.0. This moves PLTR further above the Quality Floor threshold.

**Proposed fix.** Split Smart Money into two sub-scores:
- **Smart Money (Quality)**: insider transactions + institutional 13F flow + congressional trades. Weight: keep at 0.25 in Quality.
- **Options Flow (Timing)**: P/C ratio, IV skew, unusual activity, net delta. Add as a 5th dimension in Timing with redistributed weights, e.g., Technical 0.30, Risk 0.20, Sentiment 0.15, Backtest 0.15, Options Flow 0.20.

---

### ISSUE 2: Analyst Upgrades are Double-Classified

**The problem.** The Sentiment dimension includes "Analyst events" at 10% internal weight. These analyst upgrades/downgrades are fundamentally quality signals (an analyst raising their PT is making a valuation judgment about business quality), but they're placed inside Sentiment, which feeds the Timing Score. Meanwhile, the same analyst actions influence Fundamental perception (Zacks rank, beat history narrative) and Valuation (consensus PT vs price).

**Real example: FIX.** Sentiment = 7 partly because of "2 upgrades + 1 initiation in 2 weeks." Those same upgrades drove the "Zacks #1 Strong Buy" citation in the Fundamental narrative. The signal appears in:
1. Sentiment (7) feeding Timing Score at weight 0.20 (contributes 1.4 to Timing)
2. Fundamental/Valuation context feeding Quality Score

This is not a clean arithmetic double-count, but it is a logical double-classification -- the same real-world event influences both the Quality and Timing axes through different dimensions.

**Proposed fix.** Move analyst upgrade/downgrade events from Sentiment to a new "Analyst Conviction" sub-component within Valuation (which already uses analyst PTs). Sentiment should only measure crowd/market sentiment -- social platforms, news tone, retail flow. This preserves the clean Quality vs. Timing separation.

---

### ISSUE 3: Quality Floor Lacks Intra-Dimension Sanity Check

**The problem.** The Quality Floor rule says: "if composite < 40 (SELL) BUT Quality >= 60, override to HOLD." But Quality is an average of four dimensions. A single strong dimension can push Quality above 60 while the others scream danger.

**Constructed example.** Fund=8, Val=2, Smart=8, Macro=7 yields Quality = 63.0. This fires the floor even though Val=2 indicates massive overvaluation. The business may look great on fundamentals (high Piotroski, growing revenue) while being priced for perfection at 200%+ of DCF. The floor prevents a SELL on an absurdly overvalued stock.

**Near-miss: AMD.** Quality = 58.0 (2 points below threshold). If Smart Money had been scored 6 instead of 5 (one extra congressional buyer or slightly different options flow reading), Quality = 60.5 and the floor fires. AMD with composite 39 would be overridden to HOLD despite RSI 79.84, EXTREME extension (+64% in 1M), P/E 135x, and price 53% above SMA50.

**Near-miss: BE.** Quality = 57.5. If Macro were 8 (slightly lower VIX) AND Smart Money were 5 instead of 4, Quality = 62.0 and the floor fires. BE would be forced to HOLD despite +115% extension in 1 month, FY net income still negative, and Beta 3.19.

**Proposed fix.** Add a minimum-dimension gate: Quality Floor only fires if ALL Quality sub-dimensions are >= 4 (out of 10). If any dimension is <= 3 (e.g., Val=2), the floor is suppressed. Also add: "Quality Floor does not override if any of: Valuation <= 3, RSI > 80, or Extension = EXTREME."

---

### ISSUE 4: Quality Floor Computation for All 18 Stocks

**Result: Zero stocks currently trigger the Quality Floor.** No stock has both composite < 40 AND Quality >= 60. The five stocks in SELL territory have Quality scores of: AMD 58.0, INFQ 43.0, ALMU 44.0, BBAI 41.5, BE 57.5, SATS 38.0. AMD and BE are closest to triggering (2.0 and 2.5 points away respectively).

**Why this matters.** The Quality Floor is essentially dead code in the current market environment. For a stock to have composite < 40 AND Quality >= 60, it would need very strong fundamentals/smart-money combined with terrible technical/risk/backtest scores. This is a narrow and somewhat paradoxical profile -- if the business is truly high-quality, the composite typically stays above 40 because fundamentals carry 15% weight directly. The floor would only fire in extreme dislocations, which is arguably when it's most dangerous to prevent selling.

Five stocks with HIGH Quality (>= 60) all have composites well above 40: FIX (63.5/56), NVT (60.0/53), CRDO (70.5/55), GEV (60.0/53), PLTR (66.0/50).

---

### ISSUE 5: No Time Decay on Quality Floor

**The problem.** The rule "Quality >= 60, Timing < 40 -> HOLD. DO NOT SELL" has no expiration. A stock could decline for 6+ months and the system would never recommend selling as long as Fundamental (sticky -- based on trailing financials) and Macro (uniform across market) remain high.

**PLTR is a live demonstration.** Quality = 66.0, Timing = 36.0. The matrix says "HOLD -- strong business, bad timing. DO NOT SELL." PLTR is already down 34% from its November highs and -22% over 6 months. Fundamental = 9 is driven by trailing metrics (85% revenue growth, 7/7 beats) that change only quarterly. If PLTR drops another 30%, Quality would likely remain above 60 because Fund=9 contributes 27 points alone (0.30 * 9 * 10), and Macro=7 adds 14.0. Even if Smart Money drops to 4 (institutions exit) and Val drops to 3 (further from analyst targets), Quality = (9*0.30 + 3*0.25 + 4*0.25 + 7*0.20) * 10 = 58.5. It takes catastrophic degradation across multiple dimensions to break below 60.

**Proposed fix.** Introduce time decay on the Quality Floor:
- Months 0-3: Full protection (HOLD)
- Months 3-6: If price has declined >20% since first HOLD signal, downgrade guidance to "HOLD with STOP LOSS at -25% from first HOLD price"
- Months 6+: If price has declined >30%, Quality Floor is suspended. Composite signal governs.

Track the date when the Quality Floor was first invoked for each stock. Add a field `quality_floor_activated_date` to scores.csv.

---

### ISSUE 6: Composite and Matrix Contradict in 39% of Cases

**The problem.** The rubric says the signal matrix is "supplementary -- does NOT override composite signal." But the Quality Floor rule DOES override composite (forcing SELL to HOLD). These two statements contradict each other. More practically, 7 of 18 stocks (39%) produce contradictory guidance:

| Stock | Composite Signal | Matrix Signal | Nature of Conflict |
|-------|-----------------|---------------|-------------------|
| FLTCF | HOLD (43) | AVOID (Q=57.5, T=39.5) | Matrix says worse |
| KLTR | HOLD (49) | SELL (Q=54.5, T=43.5) | Matrix says SELL weak biz |
| ASX | HOLD (47) | SELL (Q=52.5, T=47.0) | Matrix says SELL weak biz |
| AMPX | HOLD (42) | SELL (Q=46.5, T=41.0) | Matrix says SELL weak biz |
| LAW | HOLD (44) | SELL (Q=51.5, T=41.0) | Matrix says SELL weak biz |
| KGS | HOLD (48) | SELL (Q=55.0, T=49.5) | Matrix says SELL weak biz |
| CDNS | HOLD (43) | SELL (Q=52.5, T=48.0) | Matrix says SELL weak biz |

The matrix's "< 40 Quality = SELL" threshold is aggressive. Stocks with Quality 40-59 and Timing 40-59 fall into a dead zone: the matrix says "SELL (weak business)" but the composite says HOLD. The user has no clear guidance.

**Root cause.** The Quality threshold for "weak business" (< 40) is too low. A stock with Fund=5, Val=5, Smart=5, Macro=5 has Quality = 50 -- perfectly average -- yet the matrix treats everything below 60 as not "high quality." Stocks in the 40-59 Quality range with 40-59 Timing fall outside the matrix's useful categories entirely. The matrix effectively only distinguishes "strong" (>= 60) from "everything else," which is a binary signal, not a matrix.

**Proposed fix.** Revise the matrix to acknowledge the mid-range explicitly:

| Quality | Timing | Guidance |
|---------|--------|----------|
| >= 60 | >= 60 | STRONG BUY |
| >= 60 | 40-59 | BUY on dips |
| >= 60 | < 40 | HOLD -- do not sell |
| 40-59 | >= 60 | CAUTIOUS BUY |
| 40-59 | 40-59 | HOLD -- follow composite |
| 40-59 | < 40 | CAUTIOUS SELL |
| < 40 | >= 60 | AVOID (bad business, good chart = trap) |
| < 40 | 40-59 | SELL |
| < 40 | < 40 | STRONG SELL |

The key change: Quality 40-59 / Timing 40-59 becomes "HOLD -- follow composite" rather than "SELL," which eliminates the contradiction. Also adds Q<40/T>=60 as "AVOID" to catch value traps with good charts.

---

### ISSUE 7: Macro Dilutes Stock-Specific Quality Signal

**The problem.** Macro has 20% weight in Quality, and it is nearly uniform: 15 of 18 stocks score Macro = 7. This means 14 points of Quality (out of 100) come from a market-wide signal that is identical for 83% of the portfolio. Macro contributes no stock-specific differentiation to Quality.

**Effect on Quality spread.** The actual stock-specific Quality signal is compressed. Consider that the remaining 80% of Quality (Fund/Val/Smart) must do all the work of separating good businesses from bad ones. The Macro=7 floor provides a guaranteed 14-point cushion that moves Quality scores upward en masse.

**Bear market fragility.** If VIX spikes and rates rise (Macro drops from 7 to 3 for all stocks), ALL Quality scores drop by 8.0 points simultaneously. This would strip Quality Floor protection from FIX (63.5 -> 55.5), NVT (60.0 -> 52.0), GEV (60.0 -> 52.0), and PLTR (66.0 -> 58.0). The floor becomes regime-dependent: it protects high-quality stocks in calm markets but abandons them in bear markets, which is exactly when you'd want it most.

**Proposed fix.** Two options:
1. **Remove Macro from Quality entirely.** Redistribute its 20% weight: Fund 0.35, Val 0.30, Smart 0.35. Macro is a market environment factor, not a business quality factor. Whether the VIX is 15 or 30 says nothing about whether PLTR is a good business. Keep Macro in the composite only.
2. **If keeping Macro in Quality**, reduce its weight to 10% and add a "Macro-neutralized Quality" metric that strips out Macro for Quality Floor decisions. The floor should only fire based on business-specific dimensions.

---

### ISSUE 8: Pre-Earnings Weights Decouple from Quality-Timing

**The problem.** When earnings are within 7 days, the composite weights shift dramatically (Technical 22% -> 12%, Sentiment 7% -> 20%, Fundamental 15% -> 22%, Backtest 10% -> 3%). But Quality-Timing uses FIXED weights that never change. This means pre-earnings, the composite and Quality-Timing scores are computed under completely different weight regimes.

**AMD example (earnings in 1 day).**
- Normal composite raw: 48.7. Pre-earnings composite raw: 56.9 (+8.2 points).
- Quality Score: 58.0 (static). Timing Score: 43.0 (static).
- The composite shifts AMD from borderline SELL toward mid-HOLD territory, but the Quality-Timing matrix doesn't change at all. The user gets a composite that says "pre-earnings fundamentals look strong" alongside a Timing Score that says "bad entry point" -- computed with weights that ignore the pre-earnings context.

**BBAI example (earnings in 1 day).**
- Normal composite: 38.5. Pre-earnings composite: 40.7 (+2.2). This crosses the SELL/HOLD boundary.
- Quality: 41.5 (static). Timing: 36.5 (static). Matrix says: AVOID.
- Composite flips to HOLD; matrix says AVOID. The user has no idea which to follow.

**Proposed fix.** Create pre-earnings Quality-Timing weights that parallel the composite shift:
- **Quality pre-earnings**: Fund 0.40 (up from 0.30), Val 0.20 (down from 0.25), Smart 0.25 (unchanged), Macro 0.15 (down from 0.20).
- **Timing pre-earnings**: Technical 0.20 (down from 0.35), Risk 0.25 (unchanged), Sentiment 0.35 (up from 0.20), Backtest 0.20 (unchanged -- already low).

Report both normal and pre-earnings Quality-Timing when within 7 days of earnings, with a note: "PRE-EARNINGS Q-T SHIFT: Quality {X} -> {Y}, Timing {X} -> {Y}."

---

### Summary of Severity

| Issue | Severity | Stocks Affected | Current Impact |
|-------|----------|----------------|----------------|
| 1. Options flow cross-classification | HIGH | All 18 | Up to 5pts Quality inflation (BBAI) |
| 2. Analyst upgrades double-classified | MEDIUM | All 18 | Logical contamination, ~1-2pt effect |
| 3. Quality Floor lacks dimension gate | HIGH | Near-misses: AMD, BE | Floor could protect obviously dangerous trades |
| 4. Floor currently dead code | LOW | 0/18 triggered | Architectural risk, not current risk |
| 5. No time decay on floor | HIGH | PLTR active example | System never recommends selling declining quality stocks |
| 6. 39% composite/matrix contradiction | CRITICAL | 7/18 stocks | Users get conflicting signals with no resolution rule |
| 7. Macro dilutes Quality signal | HIGH | 15/18 stocks | 14pt uniform cushion, bear-market fragility |
| 8. Pre-earnings weight decoupling | MEDIUM | 2 stocks (AMD, BBAI) | Composite and Q-T computed under different regimes |

The most urgent fix is Issue 6 (39% contradiction rate) because it directly undermines user trust -- the system gives two signals with no clear hierarchy. The second priority is Issue 7 (Macro uniformity) because it makes Quality scores move in lockstep with market regime rather than measuring business-specific quality. Issue 5 (no time decay) is third because PLTR is a live case where the system may hold through a prolonged decline.