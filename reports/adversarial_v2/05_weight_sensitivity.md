# Adversarial Audit: Weight Sensitivity & Fragility
## Date: 2026-05-06

I'll start by reading the scoring rubrics and scores.csv, then sample several stock reports.

---

Now let me read several stock reports to get the actual dimension scores and context.

---

Let me read 6 full stock reports to understand the data better, including backtest trade counts and other details.

---

Now let me read a couple more reports for stocks near thresholds.

---

Now I have all the data I need. Let me compile the full analysis.

---

Now I have all the data needed. Let me perform the comprehensive weight sensitivity analysis.

---

Now I have all the results. Let me compile the comprehensive findings.

---

## Weight Sensitivity Audit Results

### PART 1: Threshold Proximity Analysis

9 of 18 stocks are within 3 points of the SELL/HOLD threshold (40 points). No stocks are near the HOLD/BUY (60) or BUY/STRONG BUY (75) thresholds. The entire watchlist clusters dangerously around the SELL/HOLD boundary.

| Symbol | Composite | Signal | Distance to 40 | Direction | Fragile? |
|--------|-----------|--------|-----------------|-----------|----------|
| AMD | 39 | SELL | 1 | below | YES |
| BBAI | 39 | SELL | 1 | below | YES |
| AMPX | 42 | HOLD | 2 | above | YES |
| ALMU | 38 | SELL | 2 | below | YES |
| INFQ | 37 | SELL | 3 | below | YES |
| BE | 37 | SELL | 3 | below | YES |
| SATS | 37 | SELL | 3 | below | YES |
| FLTCF | 43 | HOLD | 3 | above | YES |
| CDNS | 43 | HOLD | 3 | above | YES |

### PART 2: Kingmaker Dimensions -- Single +/-1 Changes That Flip Signals

**AMD (39 SELL):** The most fragile stock. ANY +1 change to Technical, Fundamental, Valuation, Smart Money, or Risk flips the signal to HOLD. That is **5 of 8 dimensions** are kingmakers. This is because AMD's raw composite is 48.7 (solidly HOLD), but overrides (-5 RSI overbought, -5 extension) push it to 39. A single +1 in a high-weight dimension like Technical (+2.2 points) pushes the final to 41.2 = HOLD.

**BBAI (39 SELL):** Similarly fragile. A +1 in Technical, Fundamental, Valuation, Smart Money, or Risk flips to HOLD. Five kingmaker dimensions.

**AMPX (42 HOLD):** A -1 to Technical drops the composite to 39.8 = SELL. Technical is the sole kingmaker here (22% weight makes it the most influential single dimension).

**ALMU (38 SELL):** Only Technical +1 (22% weight, +2.2 pts) can reach 40. Other dimensions lack enough weight for a single-point flip.

**FLTCF, CDNS, INFQ, SATS, BE:** No single +/-1 dimension change flips these signals. They are 3 points from the threshold, and even the highest-weighted dimension (Technical at 22%) only moves the composite by 2.2 points.

**Key finding:** Technical (22% weight = 2.2 pts per point change) is the most powerful kingmaker. It is the ONLY dimension that can flip a signal from a single +1 change when the stock is exactly 2 points from a threshold.

### PART 3: Pre-Earnings Weight Switching -- AMD and PLTR

| Metric | AMD (Normal) | AMD (Pre-Earn) | PLTR (Normal) | PLTR (Pre-Earn) |
|--------|-------------|----------------|---------------|-----------------|
| Raw Composite | 48.7 | 56.9 | 49.6 | 57.1 |
| Delta | -- | +8.2 | -- | +7.5 |
| With Overrides | 38.7 (SELL) | 46.9 (HOLD) | 49.6 (HOLD) | 57.1 (HOLD) |
| Signal Flip? | -- | **YES** | -- | No |

**AMD flips from SELL to HOLD under pre-earnings weights.** The +8.2 point delta is driven by:
- Fundamental 8/10 gets 22% weight (up from 15%): +0.56 points
- Sentiment 7/10 gets 20% weight (up from 7%): +0.91 points
- Technical 5/10 drops to 12% weight (from 22%): -0.50 points
- Backtest 2/10 drops to 3% weight (from 10%): -0.14 points

This is significant: AMD had earnings the next day. The pre-earnings weight switch correctly recognizes that AMD's strong fundamentals (8/10) and sentiment (7/10) should dominate over its weak technicals and backtest when the stock is about to report. **The current SELL signal may be incorrect for the pre-earnings context.**

**PLTR stays HOLD under both weight regimes,** but moves from 49.6 to 57.1 (nearly BUY territory at 60). PLTR's Fundamental 9/10 benefits enormously from the higher fundamental weight.

### PART 4: Adaptive Backtest Weighting

Three stocks flip signals under adaptive backtest weighting:

| Symbol | Trades | WF Rob | Eff BT Wt | Normal Raw | Adaptive Raw | Delta | Signal Flip |
|--------|--------|--------|-----------|------------|--------------|-------|-------------|
| **FIX** | 8 | 0.00 | 2.5% | 57.5 | 61.5 | +4.0 | HOLD -> BUY |
| **CRDO** | 2 | 0.34 | 2.0% | 59.6 | 64.0 | +4.4 | HOLD -> BUY |
| **BBAI** | 7 | -0.33 | 2.5% | 38.5 | 40.0 | +1.5 | SELL -> HOLD |

The pattern: every stock has Backtest scores of 1-2 (far below their other dimension averages of 4.3-6.4). When backtest weight is reduced, the composite always increases because the below-average backtest was dragging it down. **The adaptive weighting systematically inflates composites because backtest scores are universally low across this watchlist** (15 of 18 stocks score 1-2 on backtest). The largest deltas are for stocks with the biggest gap between their backtest score and other dimensions -- NVT (+4.2 pts, BT 1 vs avg 5.9), CRDO (+4.4 pts, BT 1 vs avg 6.4), FIX (+4.0 pts, BT 1 vs avg 6.4).

### PART 5: Quality-Timing Dual Score

| Symbol | Composite | Signal | Quality | Timing | QT Guidance | Conflict? |
|--------|-----------|--------|---------|--------|-------------|-----------|
| AMD | 39 | SELL | 58.0 | 43.0 | HOLD | QT says HOLD |
| ALMU | 38 | SELL | 44.0 | 45.0 | HOLD | QT says HOLD |
| BE | 37 | SELL | 57.5 | 38.5 | AVOID | -- |
| CRDO | 55 | HOLD | **70.5** | 48.0 | HOLD (quality, wait) | -- |
| FIX | 56 | HOLD | **63.5** | 53.0 | HOLD (quality, wait) | -- |
| NVT | 53 | HOLD | **60.0** | 47.0 | HOLD (quality, wait) | -- |
| GEV | 53 | HOLD | **60.0** | 49.0 | HOLD (quality, wait) | -- |
| PLTR | 50 | HOLD | **66.0** | 36.0 | HOLD (strong biz, bad timing) | -- |

**No hard Quality-floor violations found** (no stock has SELL + Quality >= 60). However, AMD (Quality 58.0) and BE (Quality 57.5) are within 2-3 points of the floor. AMD's Quality is borderline -- if Fundamental went from 8 to 9, Quality would hit 61.0 and the SELL signal would violate the floor rule.

**Two composite SELL stocks have QT guidance of HOLD** (AMD, ALMU), meaning the overrides (extension, overbought) push the composite below what the Quality-Timing matrix would recommend. This is a design tension: the override system can override the Quality-Timing floor.

**PLTR is notable:** Quality 66.0 with Timing 36.0 -- the system correctly produces HOLD, not SELL, despite terrible timing. The dual-score framework is working as intended for PLTR.

### PART 6: Weight Summation After Adaptive Redistribution

For a stock with 3 trades and walk-forward robustness 0.1:

1. 3 trades < 5: effective backtest weight = 2%
2. WF robustness 0.1 < 0.3: HALVE effective weight = 1%
3. Redistribute 9% proportionally to remaining 7 dimensions

| Dimension | Original | New Weight | Change |
|-----------|----------|------------|--------|
| Technical | 22.00% | 24.20% | +2.20pp |
| Fundamental | 15.00% | 16.50% | +1.50pp |
| Valuation | 15.00% | 16.50% | +1.50pp |
| Sentiment | 7.00% | 7.70% | +0.70pp |
| Smart Money | 13.00% | 14.30% | +1.30pp |
| Macro | 6.00% | 6.60% | +0.60pp |
| Backtest | 10.00% | **1.00%** | -9.00pp |
| Risk | 12.00% | 13.20% | +1.20pp |
| **TOTAL** | **100.00%** | **100.00%** | **0.00pp** |

**Verification: PASS.** Weights sum to exactly 100.00% after redistribution. Each remaining dimension receives a uniform +10.0% relative increase because the redistribution is proportional to existing weights.

---

### Summary of Critical Findings

1. **9 of 18 stocks (50%) are fragile** -- within 3 points of the SELL/HOLD threshold. The scoring system produces a cluster around 37-43, suggesting either the watchlist is genuinely mediocre or the overrides (extension, overbought) systematically compress scores into a narrow band.

2. **AMD is the most fragile stock in the watchlist.** Five of eight dimensions are kingmakers -- a single +1 change to any of Technical, Fundamental, Valuation, Smart Money, or Risk flips it from SELL to HOLD. This is because overrides account for -10 points of the 39-point score, and the raw composite (48.7) is solidly HOLD.

3. **Pre-earnings weights flip AMD from SELL to HOLD** (+8.2 points). Since AMD had earnings the next day, this is a meaningful finding -- the report's SELL signal may have been stale given the timing context.

4. **Adaptive backtest weighting flips 3 stocks** (FIX and CRDO to BUY, BBAI to HOLD). The universal pattern of backtest scores being 1-2 across the entire watchlist means adaptive weighting is essentially a systematic upward bias, not a targeted correction.

5. **No hard Quality-floor violations exist**, but AMD (Quality 58.0) is 2 points away from one. Two SELL stocks (AMD, ALMU) have QT guidance of HOLD, revealing a design tension where overrides can push composites below what the Quality-Timing framework recommends.

6. **Weights sum to 100% after adaptive redistribution.** The math is clean -- proportional redistribution preserves the total weight invariant regardless of the trade count or walk-forward robustness values.