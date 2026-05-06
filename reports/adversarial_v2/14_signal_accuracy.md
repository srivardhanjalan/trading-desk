# Adversarial Audit: Signal Accuracy & Track Record
## Date: 2026-05-06

I'll start by reading all the requested files to conduct this audit.

---

Now let me read the AMD and PLTR individual reports.

---

Now let me check if there are any other report files that might provide additional context on outcomes.

---

Let me check the existing adversarial audit and also the watchlist scan for more context.

---

Now let me read the KGS report to understand the prediction about earnings misses.

---

Now I have all the data needed to produce a thorough audit. Let me also quickly check the comparison report for any additional cross-stock context.

---

I now have a comprehensive picture. Here is the full adversarial audit.

---

## Adversarial Audit: Historical Signal Accuracy and Systemic Prediction Failures

### Context

The scoring system analyzed 18 stocks across two dates (May 4 and May 5, 2026). Two outcomes are confirmed: AMD (39 SELL) surged +14.8% post-earnings, and PLTR (50 HOLD) dropped 7% post-earnings. A prior adversarial audit on May 5 already identified 23 structural flaws and proposed 13 fixes. This audit goes deeper: assessing the systemic track record, quantifying biases, and proposing a calibration methodology.

---

### 1. Other Likely Failures Beyond AMD and PLTR

**KGS (48 HOLD, earnings May 6) -- Likely CORRECT call, but for incomplete reasons**

The system flagged KGS as the highest-risk earnings disappointment: "2 consecutive misses, bar raised +14.45%." The KGS report shows:
- Beat history: only 3/7 quarters (worst in watchlist)
- Discretionary insider selling (not 10b5-1) of $933K net
- Institutional 13F shares *declining* by 3.91M despite new holder count increasing
- Institutional put/call ratio of 4.39 (extremely bearish -- institutions buying puts heavily)
- Z-Score 1.70 (grey zone, near distress)
- Revenue PEG 5.72 (most expensive stock in watchlist on this metric)
- Dividend payout ratio 198% (unsustainable)

Given the institutional put buying (4.39 P/C ratio), the discretionary selling, and the 2 consecutive misses, the most likely outcome is that KGS either missed again or delivered a tepid beat that disappointed the elevated +14.45% bar. The HOLD signal at 48 was reasonable but the system should have been more bearish. The watchlist ranking correctly identified KGS as "highest risk of disappointment" -- this is one of the system's better calls.

**CRDO (55 HOLD, pre-extension was 60 BUY) -- Likely FALSE DOWNGRADE**

CRDO had the best quality profile in the watchlist: Fund 8, Val 8 (only stock with PEG 0.76), Tech 7. The extension override alone pushed it from BUY to HOLD. In a momentum market driven by AI infrastructure spending, CRDO's 80% one-month gain was likely fundamental re-rating (same pattern as AMD). If CRDO continued to rise, the extension override cost the system its only BUY signal.

**FIX (56 HOLD, pre-extension was 58) -- Likely MISSED BUY**

Piotroski 9/9 (best in watchlist), Fund 9. The HIGH extension penalty (-2) kept it at 56. FIX is the type of stock that trends persistently upward because institutional capital continuously discovers it. The system's "wait for pullback to $1,507" advice likely resulted in a missed entry as the stock continued to $1,868+.

**BE (37 SELL, pre-extension was 42 HOLD) -- Uncertain, but penalty may be excessive**

Up 21x in 12 months, +115% in 1 month. The extension penalty of -5 pushed it from HOLD to SELL. This is the most defensible SELL in the watchlist because BE's run was genuinely parabolic. However, BE had Fund 7 and Val 5 (decent fundamentals and reasonable valuation for the growth rate). Whether this was correct depends on whether the hydrogen/fuel cell thesis continued to hold.

**BBAI (39 SELL) and SATS (37 SELL) -- Likely CORRECT**

Both had legitimately weak fundamentals (BBAI: revenue -19.3%, 0/7 revenue beats, Z-Score 1.12; SATS: Z-Score -0.71, D/E 5.38x, negative FCF). These are genuine distress signals. The SELL was probably correct.

---

### 2. Zero BUY Signals: How Conservative Is the System?

The system produced 0 BUY (>=60) out of 18 stocks. The highest score was FIX at 56.

**What composite would be needed for 1-2 BUYs?**

Looking at the pre-override scores:
- CRDO: 60 raw (was BUY before extension override)
- FIX: 58 raw
- NVT: 55 raw
- GEV: 53 raw

The extension override moved CRDO from 60 to 55 (-5) and the HIGH override moved FIX from 58 to 56 (-2). Without extension overrides alone, 1 stock (CRDO) would have been BUY. Without the overbought override on AMD, AMD would have been 44 instead of 39.

**The math for BUY signals:** For the top-4 stocks to reach 60, you would need:
- FIX: +4 points (56 to 60) -- achievable by reducing backtest weight alone
- NVT: +7 points (53 to 60) -- requires multiple fixes
- GEV: +7 points (53 to 60) -- same

The reanalysis report showed that reducing backtest weight from 10% to 3% would have pushed CRDO to 64 and FIX to 61 -- producing 2 BUY signals. This single change (reducing weight on a broken dimension) would have solved the zero-BUY problem.

**The deeper issue:** The average composite across 17 stocks (excluding PLTR) was 44.1. The standard deviation was approximately 6.5. For a BUY threshold of 60, stocks need to be 2.4 standard deviations above the mean. In a normal distribution, that means only ~0.8% of stocks would score BUY -- effectively zero from a pool of 17. The system's score distribution is structurally incompatible with the BUY threshold. Either the threshold needs to drop to ~55, or the scoring needs to produce a wider distribution with a higher mean.

---

### 3. SELL Signal Base Rate: Is 28% Too High?

5 of 18 stocks (28%) scored SELL in a bull market (VIX 17, S&P trending up, AI sector booming). For a curated momentum watchlist, this is anomalously high.

**Expected base rate:** In a bull market, a well-curated momentum watchlist should have:
- 15-25% BUY (the best opportunities)
- 55-70% HOLD (solid but not actionable right now)
- 10-20% SELL (genuinely broken stories)

The system produced 0% BUY, 67% HOLD, 28% SELL (plus 5% incomplete). This is inverted from what you would expect.

**Why the inversion exists:** Three of the five SELLs (AMD, BE, ALMU) were pushed from HOLD to SELL by the extension override alone. Without Override 5, the distribution would have been:
- 1 BUY (CRDO at 60)
- 12 HOLD
- 4 SELL (BBAI, SATS, INFQ-unadjusted, possibly one more)

That is 6% BUY, 67% HOLD, 22% SELL -- still conservative but less absurd. The extension override is the single largest distortion in the system.

**The paradox:** The watchlist was curated specifically for momentum/growth stocks. Momentum stocks, by definition, are extended from moving averages. Applying a blanket extension penalty to a momentum watchlist is like screening for tall people and then penalizing them for being tall.

---

### 4. Extension Override Impact Assessment

Four stocks received the -5 EXTREME extension penalty:
- CRDO: 60 BUY to 55 HOLD
- AMD: 44 HOLD to 39 SELL
- BE: 42 HOLD to 37 SELL
- ALMU: 43 HOLD to 38 SELL

Three additional stocks received -2 HIGH extension:
- FIX: 58 to 56
- NVT: 55 to 53
- ASX: 49 to 47

**Was the override correct?**

For AMD: WRONG. AMD surged +14.8% post-earnings. The extension was fundamental re-rating (Meta $100B deal, DA Davidson upgrade, Intel competitive collapse), not speculative froth. The override converted what should have been a HOLD into a false SELL, directly contradicting the outcome.

For CRDO: LIKELY WRONG. CRDO had PEG 0.76 -- the cheapest growth stock in the watchlist. Its 80% one-month gain was driven by AI infrastructure demand for its connectivity products. Extension penalties on stocks growing into their valuation via fundamental catalysts are systematically destructive.

For BE and ALMU: DEBATABLE. BE at +115% and ALMU at +118% in one month are genuinely parabolic. But both had legitimate fundamental stories (BE: hydrogen/fuel cell contracts; ALMU: +407% revenue growth). The penalty may have been directionally correct (mean reversion is more likely at these levels) but the magnitude (-5) was too aggressive -- -2 or -3 would have kept them as HOLD, which is the more appropriate signal for extended-but-fundamentally-sound stocks.

**Net assessment:** The extension override was wrong on 2 of 4 EXTREME cases (AMD and CRDO), debatable on 2, and too aggressive on at least 1 of the 3 HIGH cases (FIX). Its net effect was negative: it destroyed the system's only BUY signal and created at least one false SELL.

---

### 5. Opportunity Cost of "Wait for Consolidation"

The system's recommendation was: "No immediate buys. Wait for consolidation." This is defensible as risk management but has a measurable opportunity cost.

**Quantifiable cost from AMD alone:** The system said SELL at $360.54. AMD then surged +14.8% to approximately $414. On the recommended position size of 55 shares ($19,830), the missed gain was approximately $2,933. On a more aggressive position (full 20% allocation), the miss was approximately $2,933.

**Systemic cost:** If the market continued to rally (VIX 17 indicates low fear, rates stable), then "wait for consolidation" across the entire watchlist means sitting in cash while the portfolio's tracking stocks appreciate. In a momentum market, the cost of being uninvested can exceed the cost of buying at slightly elevated levels.

**How to balance timing caution with opportunity cost:**

The system needs a SCALING model for position sizing rather than a binary buy/don't-buy decision:
- Score 60+: Full position (20% of portfolio)
- Score 55-59: Half position (10% of portfolio) with stop at -5%
- Score 50-54: Quarter position (5% of portfolio) with stop at -3%
- Score <50: No position

This would have resulted in:
- CRDO (55): 10% position, captured some of the upside
- FIX (56): 10% position
- NVT (53): 5% position
- GEV (53): 5% position

Total invested: ~30% of portfolio instead of 0%. The remaining 70% in cash still provides downside protection. This is a much better balance than all-or-nothing.

---

### 6. Backtest Dimension: Net-Negative for Accuracy?

The average backtest score across the watchlist was 1.9/10. At 10% weight, this contributes an average of 1.9 points to composites out of a maximum possible 10. Every stock in the watchlist loses approximately 8 points from the theoretical maximum due to the backtest dimension.

**Is it net-negative?**

Yes. The backtest dimension is actively harmful for this watchlist for three compounding reasons:

1. **Signal inversion:** The strongest stocks (those up 100-300% in a year) systematically score lowest because no strategy beats buy-and-hold. The dimension penalizes the stocks you WANT to own.

2. **Statistical insignificance:** 12 of 17 stocks had fewer than 10 backtest trades. Results from 2-5 trades have no statistical meaning. The system is making decisions based on noise.

3. **Walk-forward failure:** Nearly every stock produced "OVERFITTED" warnings, yet the scores were still used at full weight. An overfitted backtest is worse than no backtest -- it provides false confidence in a non-existent signal.

**Recommendation:** For this type of momentum/growth watchlist, the backtest dimension should be either:
- Reduced to 3% weight (as the reanalysis suggested), or
- Conditionally nullified: when walk-forward robustness < 0.3 AND trade count < 10, set backtest score to 5 (neutral) and reduce weight to 3%

The 7% weight freed up should go to Fundamental (+4%) and Smart Money (+3%), which are the dimensions with the most differentiation across the watchlist.

---

### 7. Confidence Calibration: Completely Untracked

The system outputs HIGH/MEDIUM/LOW confidence labels but there is zero calibration infrastructure. Specific failures:

- AMD was analyzed with 87% data completeness. No confidence label was assigned in the final synthesis beyond the dimension scores. The system had no mechanism to say "I am X% confident this stock will not move more than Y%."

- PLTR was labeled "Medium confidence" HOLD. But what does "Medium" mean operationally? If it means "60% chance the stock stays within +/-5%," then PLTR dropping 7% is within the expected distribution but near the edge. Without calibration data, "Medium" is just a word.

- KGS was also "Medium confidence" HOLD with 75% data completeness. No tracking of whether Medium-confidence HOLDs have historically stayed flat.

**What calibration requires:**
- A database of all prior signals with their confidence levels
- Forward returns at 1-day, 5-day, 20-day, and 60-day intervals
- Statistical comparison: did "HIGH confidence HOLD" stocks actually move less than "LOW confidence HOLD" stocks?
- Brier score calculation for each confidence tier

Without this infrastructure, the confidence labels are decorative, not informative.

---

### 8. Proposed Scoring Calibration Methodology

To determine whether the system's signals actually correlate with future returns, implement the following:

**Phase 1: Signal Tracking Database**

For every stock analyzed, record:
```
{
  symbol, analysis_date, composite_score, signal, confidence,
  pre_override_score, overrides_applied, extension_tier,
  earnings_within_7d (boolean), earnings_within_30d (boolean),
  dimension_scores: {tech, fund, val, sent, smart, macro, bt, risk},
  price_at_analysis, sma50_at_analysis, rsi_at_analysis
}
```

Then track forward returns:
```
{
  return_1d, return_5d, return_20d, return_60d,
  max_drawdown_20d, max_gain_20d,
  hit_stop_loss (boolean), hit_take_profit (boolean)
}
```

**Phase 2: Signal Accuracy Metrics (after 30+ signals)**

1. **Signal Hit Rate:** What percentage of BUY signals generated positive 20-day returns? What percentage of SELL signals generated negative 20-day returns? Target: >60% for actionable signals.

2. **Signal Magnitude Correlation:** Does a higher composite score correlate with higher forward returns? Run Spearman rank correlation between composite scores and 20-day returns. Target: rho > 0.3 (moderate positive correlation).

3. **Override Impact Analysis:** Compare the raw pre-override composite against forward returns, then compare the post-override composite against the same returns. If overrides REDUCE correlation, they are destructive and should be modified or removed.

4. **Dimension Predictive Power:** For each of the 8 dimensions individually, run correlation against forward returns. This reveals which dimensions actually predict outcomes. Hypothesis based on current data: Fundamental and Smart Money will have the highest predictive power; Backtest will have near-zero or negative correlation.

5. **Extension Override Accuracy:** Track forward returns specifically for stocks that received extension penalties. If >50% of EXTREME-penalized stocks continue to rise over 20 days, the override is net-negative.

6. **Earnings Event Analysis:** Separate the dataset into pre-earnings (within 7 days) and non-earnings periods. Calculate signal accuracy for each. If the system is significantly less accurate pre-earnings, implement the pre-earnings weight switching from the prior audit's Fix 7.

7. **Confidence Calibration Curve:** Plot actual outcome frequency against stated confidence. For example, if "HIGH confidence HOLD" appears 20 times, what percentage actually stayed within +/-5% over 20 days? Target: HIGH should correlate with >70% accuracy, MEDIUM with >55%, LOW with <50%.

**Phase 3: Adaptive Recalibration (after 100+ signals)**

1. **Rolling Brier Score:** Calculate Brier score for the system's probabilistic predictions over rolling 30-signal windows. Detect if accuracy is degrading over time (regime change detection).

2. **Dynamic Weight Optimization:** Using the dimension-level predictive power data from Phase 2, adjust dimension weights quarterly. If Backtest consistently shows zero predictive power, formally reduce its weight. If Fundamental consistently predicts well, increase its weight.

3. **Override Pruning:** Any override that reduces signal accuracy in the Phase 2 analysis should be weakened (halve the penalty) or removed. Any override proposed in the prior audit (Fixes 1-13) should be A/B tested: run both the original and modified scoring on the same stocks, compare forward return correlation.

4. **Regime Detection:** Track whether the system's accuracy varies by VIX regime (VIX <15 vs 15-25 vs >25), sector regime (tech bull vs rotation vs bear), and earnings proximity. Use this to dynamically select weight profiles.

---

### Summary of Findings

| Finding | Severity | Evidence |
|---------|----------|----------|
| Extension override is net-destructive: destroyed only BUY signal, created at least 1 false SELL | Critical | AMD +14.8% after SELL, CRDO lost BUY status |
| Zero BUY signals in a bull market indicates systematic conservatism | Critical | 0/18 BUY, 28% SELL in VIX 17 environment |
| Backtest dimension (10% weight) is net-negative for prediction accuracy | High | Average 1.9/10, penalizes strongest stocks, statistically meaningless trade counts |
| No confidence calibration infrastructure exists | High | "Medium confidence" has no tracked meaning |
| 28% SELL rate on a momentum watchlist is structurally inverted | High | 3 of 5 SELLs were created solely by extension override |
| KGS was correctly identified as highest disappointment risk | Positive | Institutional P/C 4.39, discretionary insider selling, 3/7 beats |
| System correctly identified PLTR as HOLD (don't buy) | Positive | Stock dropped 7%, HOLD was appropriate |
| "Wait for consolidation" creates unmeasured opportunity cost | Medium | No position sizing gradient; binary buy/don't-buy decision |
| Quality and timing are conflated into one composite score | Structural | AMD: great business (Fund 8) scored SELL because of timing signals |

**Bottom line:** The system is a good *business quality assessor* (Fundamental dimension correctly identified AMD 8/10 and PLTR 9/10) but a poor *signal generator*. The composite blending, override stacking, and extension penalties systematically push the system toward inaction and false SELLs on the strongest names. The immediate priority is to (1) implement the Quality-Timing split from the prior audit's Fix 12, (2) reduce backtest weight to 3%, (3) add fundamental-catalyst exceptions to the extension override, and (4) begin tracking signal accuracy with the calibration methodology described above. Until forward return data is being collected and analyzed, the system's signals cannot be validated and should be treated as directional hypotheses, not actionable recommendations.