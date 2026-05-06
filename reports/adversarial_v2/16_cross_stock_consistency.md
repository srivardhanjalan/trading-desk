# Adversarial Audit: Cross-Stock Consistency
## Date: 2026-05-06

I'll start by reading the scores file and scoring rubrics, then dive into the individual stock reports.

---

Now let me read all the stock reports needed for this audit.

---

Now let me read the BBAI report and several other reports needed for this audit.

---

Now let me also check a few more reports for completeness of the extension and macro analysis.

---

Now I have enough data to conduct a thorough cross-stock consistency audit. Let me also check the extension data for PLTR to understand the full picture.

---

Now I have all the data needed. Here is my comprehensive cross-stock consistency audit.

---

## CROSS-STOCK CONSISTENCY AUDIT

### 1. NVT (53) vs GEV (53) -- Identical Composites, Different Stocks

**Dimension-by-dimension comparison:**

| Dimension | NVT | GEV | Delta |
|-----------|-----|-----|-------|
| Technical | 6 | 6 | 0 |
| Fundamental | 7 | 7 | 0 |
| Valuation | 3 | 3 | 0 |
| Sentiment | 7 | 7 | 0 |
| Smart Money | 7 | 7 | 0 |
| Macro | 7 | 7 | 0 |
| Backtest | 1 | 2 | -1 |
| Risk | 4 | 4 | 0 |

**Finding: These stocks are SUSPICIOUSLY identical.** Seven of eight dimensions match exactly. The only difference is Backtest (1 vs 2), which contributes just 1 point to the composite. This is a red flag -- not because two stocks cannot score similarly, but because the underlying data is quite different and the rubric should produce differentiation.

**Specific inconsistencies:**

- **Fundamental (both 7):** NVT has revenue growth of +29.5% YoY with Piotroski 6. GEV has revenue growth of only +8.94% with Piotroski 5 but a Q1 EPS beat of 944%. The rubric says Piotroski 6-7 + Z-Score >3 + revenue >10% maps to 7-8. NVT clearly meets this. GEV barely meets the revenue growth threshold (8.94% is below 10%), and its Piotroski 5 maps to the 5-6 range per the rubric. GEV's Fundamental 7 appears inflated -- the +1 earnings beat modifier pushed a base-6 to a 7, but the base itself may be too high given Piotroski 5 and sub-10% revenue growth.

- **Valuation (both 3):** NVT is Track B (revenue growth 29.5%, PEG 1.78) and GEV is Track A (revenue growth 8.94%, P/E 30.5). Completely different valuation frameworks. NVT's PEG 1.78 maps to the 5-6 range on Track B. GEV's price is 70-234% above DCF range on Track A. Both scoring 3 is defensible for GEV (extreme DCF premium) but NVT should arguably score 4-5 since its PEG is in the 5-6 base range and it received +1 for EPS-PEG divergence.

- **Smart Money (both 7):** NVT has P/C of 0.17 (extremely bullish), institutional calls +92%, House buying, but mild CEO selling. GEV has neutral P/C of ~1.05, but massive institutional accumulation (+36.5M shares, +17.7%). Both at 7 is defensible, but the mechanisms are completely different. The lack of differentiation hides the fact that NVT has a much stronger options flow signal while GEV has a much stronger institutional accumulation signal.

**Calibration fix:** GEV Fundamental should be 6, not 7 (Piotroski 5 and sub-10% revenue growth do not meet the 7-8 criteria). NVT Valuation should be 4, not 3 (PEG 1.78 base is 5-6; after DCF penalty and EPS divergence adjustment, 4 is more appropriate than 3). These corrections would make NVT ~54 and GEV ~51, which better reflects the underlying difference -- NVT is a stronger fundamental story with a more concerning valuation premium, while GEV is priced even further from intrinsic value with weaker growth.

---

### 2. CRDO Valuation 8/10 -- Is It Justified?

**Data supporting the 8:**
- Revenue PEG: 0.76 (below 0.8 threshold for 9-10 range)
- Revenue growth: 126.3% YoY (exceptional)
- Earnings beats: 6/7 with avg +28.8% surprise
- PSG cross-check: 0.13 (confirms growth cheaply priced)

**Data undermining the 8:**
- DCF: Both standard and levered are NEGATIVE ($-51.57 and $-34.64) -- indicating the business does not generate enough free cash flow to justify any positive valuation on a DCF basis
- Analyst consensus: $190.17 vs current $184.38 -- only +3.1% upside. The market has already priced in the growth.
- P/E: 95.8x -- extremely expensive in absolute terms
- P/S: 31.8x -- very high

**Verdict: The 8 is partially justified but contains a contradiction.** The rubric for 9-10 says "PEG <0.8 + below analyst consensus + revenue acceleration + beats >=6/8 quarters." CRDO meets PEG <0.8, revenue acceleration, and 6/7 beats. BUT it fails "below analyst consensus" -- price is AT consensus. The report correctly notes this: "This tempers the score from 9 to 8."

**However, there is a deeper problem.** The rubric for Track B explicitly states DCF should be used as "custom DCF (with real growth inputs)" and if custom DCF still significantly undervalues, PEG overrides. But CRDO's DCFs are not merely "undervaluing" -- they are NEGATIVE. This means the company's actual cash generation is so minimal ($29M FCF on a $34B market cap) that any DCF model rejects the valuation entirely. Giving an 8/10 to a stock where DCF produces a negative value, where the price is already at analyst consensus, and where P/S is 31.8x is too generous. The PEG metric is doing ALL the heavy lifting, and PEG can be misleading for companies that only recently became profitable.

**Calibration fix:** CRDO Valuation should be 7, not 8. The "at analyst consensus" condition should knock it down from the 9-10 PEG range to 7-8, and the negative DCF and extreme absolute multiples should push it to the lower end of that range. This would make CRDO's composite 54 instead of 55 -- a small change, but it matters for cross-stock consistency since a stock at analyst consensus with negative DCF should not have the highest Valuation score in the entire watchlist.

---

### 3. FIX: Fundamental 9/10 + Backtest 1/10 -- Genuine Signal or Artifact?

**The Fundamental 9 is well-supported:**
- Piotroski 9/9 (perfect -- only stock in the watchlist at max Piotroski)
- Z-Score 12.5 (far above the >3 "safe" threshold)
- Revenue +29.5% YoY
- 8/8 consecutive earnings beats with avg +29.4% surprise
- Net income nearly doubled, margins expanding
- FCF >$1B, net cash position

This is a genuine 9/10 by the rubric. There is no inflation here.

**The Backtest 1 is also defensible:**
- Best strategy (MACD) returned 22.53% vs B&H 332% -- strategy massively underperforms
- Walk-forward: 0 out-of-sample trades, robustness 0.0
- 8 trades (cap at 4, minus 2 for B&H)

**Assessment: This is a GENUINE signal, not an artifact.** FIX has risen 329% in 1 year. No systematic strategy can capture a move like that -- the stock is in a parabolic run. The backtest is correctly penalizing the inability of systematic approaches to ride this trend. This actually conveys useful information: you cannot systematically trade FIX using standard technical strategies; the move is fundamentally driven and must be evaluated as a fundamentals play with extreme timing risk.

**However, the rubric should address this pattern.** The B&H benchmark penalty states: "B&H return > 100%: Penalty WAIVED." FIX's B&H return is +332%, which means the -2 penalty should have been WAIVED. The report applies the full -2 penalty despite the B&H trend override existing in the rubric. This is a scoring ERROR.

**Calibration fix:** FIX Backtest should be 4, not 1. With B&H > 100%, the penalty is waived. With 8 trades, the cap is 4. Walk-forward overfitting would reduce effective weight, not the score itself. This would raise FIX's composite from 56 to approximately 59 (before extension override).

---

### 4. Smart Money 7 -- NVT vs BBAI Comparison

Both score Smart Money 7/10, but the underlying data is radically different:

| Signal | NVT | BBAI |
|--------|-----|------|
| Insider Activity | Mild CEO selling ($885K), mostly F-InKind | Small director selling ($320K), CEO F-InKind |
| 10b5-1 Status | NOT VERIFIED | NOT VERIFIED |
| Institutional Accumulation | 768 holders, 92.2% ownership, slight share decline (-445K) | 392 holders, 49.4% ownership, massive share surge (+51.5M, +35.7%) |
| Congressional | Mixed (McCaul sale + Khanna/Kean buys) | Bullish (McClain 4 purchases, no sales) |
| Options P/C | 0.08 -- EXTREMELY bullish | 0.20 -- STRONGLY bullish |
| Company Quality | Piotroski 6, Z-Score 6.3, profitable | Piotroski 3, Z-Score 1.12 (distress), deep losses |

**Inconsistency identified:** The Smart Money rubric says 7-8 requires "3/4 signals positive, OR insider buying >$5M, OR unusual call volume >10x OI." For NVT, the positive signals are: (1) extremely bullish P/C, (2) House buying, (3) institutional calls +92%. The insider selling is minimal and mostly non-discretionary. Score 7 is justified.

For BBAI, the positive signals are: (1) massive institutional share accumulation (+35.7%), (2) congressional buying (4 purchases), (3) very bullish P/C (0.20). But the report also notes BBAI is in the distress zone (Z-Score 1.12), is a serial revenue misser (0/7), and has negative DCF. The Smart Money score evaluates WHO is buying, not WHETHER they are right. So 7 is technically defensible for both.

**But this reveals a systemic problem:** Smart Money 7 for a distressed company with negative DCF and for a profitable company with strong fundamentals convey very different investment signals. When institutions pile into a distressed company, it could be speculative positioning, short covering, or index rebalancing. When they pile into a profitable grower, it is typically fundamental conviction. The Smart Money dimension is not adjusting for the quality of the underlying asset.

**Calibration fix:** Add a quality-gate to Smart Money: If Fundamental score <= 3 (weak business), cap Smart Money at 6 regardless of flow signals, and add a note: "SMART MONEY QUALITY GATE: Strong institutional flow into weak fundamentals. Speculative positioning possible." This would change BBAI Smart Money from 7 to 6, which reduces its composite from 39 to ~38 -- a small change, but it prevents the misleading signal that smart money conviction is equivalent across quality tiers.

---

### 5. Risk Score: FIX (5) vs CDNS (5) vs KGS (5)

Three stocks tied at Risk 5/10 with very different price action:

| Metric | FIX | CDNS | KGS |
|--------|-----|------|-----|
| 1M Change | +30.3% | +22.0% | +17.7% |
| 3M Change | +66.8% | +25.6% | +61.7% |
| 6M Change | +95.4% | +2.3% | +89.0% |
| 1Y Change | +329.2% | +10.4% | +100.6% |
| Beta | 1.598 | 1.041 | 0.876 |
| RSI | 70.3 | 51.2 | 51.2 |
| % above SMA50 | +24.8% | +14.5% | +16.2% |
| % above SMA200 | +78% | +6% | +63% |
| Earnings Proximity | 80 days | ~90 days | 2 DAYS |

**This is a clear inconsistency.** FIX is vastly more extended than CDNS (78% above SMA200 vs 6%), has a higher beta, and has RSI at the overbought boundary. KGS has earnings in 2 DAYS, which should be a major risk factor.

**How did they all arrive at 5?**
- **FIX:** Beta 1.598 (base 5-6), RSI 70.3 approaching overbought, 24.8% above SMA50. The report scores it 5 without detailing the path clearly. With these metrics, Risk should be 4 given the extreme extension.
- **CDNS:** Beta 1.041 (base 7-8), RSI neutral, no imminent earnings. Then -1 for Hexagon acquisition risk, -1 for missing options data. 7 - 2 = 5. The missing-data penalty is driving this down artificially.
- **KGS:** Beta 0.876 (<1.0, base 7-8 or even 9-10), RSI neutral. Then -2 for earnings in 2 days. 7 - 2 = 5. But the report also notes price at ATH, +16% above SMA50 -- these should contribute additional risk.

**The problem:** CDNS's Risk 5 comes from data-quality penalties (missing options data), not from actual risk. FIX's Risk 5 understates the risk of a stock +78% above its 200SMA with RSI at overbought. KGS's Risk 5 is roughly fair given low beta offset by imminent earnings.

**Calibration fix:**
- FIX Risk should be 4 (beta 1.6 base of 5-6, plus extension above 200SMA is extreme, plus RSI approaching overbought). The rubric says "Beta 1.5-2.0 + RSI approaching extreme" = 5-6 range, but +78% above SMA200 should push to the lower end.
- CDNS Risk should be 6. Do not apply a -1 penalty for missing options data as a Risk modifier -- that is a data-completeness issue, not an actual risk metric. Data completeness has its own override. With beta 1.041 and no imminent events, base should be 7 minus 1 for Hexagon = 6.
- KGS Risk 5 is appropriate as-is.

---

### 6. Macro Dimension -- Is It Adding Signal?

**Score distribution for Macro across all stocks:**

| Stock | Macro Score |
|-------|-------------|
| AMD | 7 |
| INFQ | 7 |
| ALMU | 7 |
| FLTCF | 7 |
| FIX | 7 |
| NVT | 7 |
| ASX | 7 |
| AMPX | 7 |
| KGS | 7 |
| BE | 7 |
| CRDO | 7 |
| GEV | 7 |
| PLTR | 7 |
| CDNS | 7 |
| KLTR | 6 |
| LAW | 6 |
| BBAI | 5 |
| SATS | 7 |

**14 of 18 stocks score Macro 7.** Only KLTR (6), LAW (6), and BBAI (5) differ. This dimension has a standard deviation of approximately 0.6 across the watchlist. It is essentially a constant.

**Why this happens:** The Macro rubric is driven by VIX (which was 17-18 for all analyses -- the same market), yield curve (same for all), and sector ETF performance. Since VIX was in the "normal" 15-20 range during all these analyses, every stock gets pushed into the 7-8 band. The only differentiation comes from sector-specific underperformance (BBAI underperforming XLK) or sector ETF data being unavailable (capping at 6).

**Assessment: Macro is adding almost zero signal.** With a 6% weight, Macro contributes between 0.30 and 0.42 to the composite (a range of 0.12 points, or about 1.2 on the 100-point scale). This means the difference between the best and worst Macro score contributes roughly 1 point to the final composite. That is noise.

**Calibration fix:** Either (a) add stock-relative-to-sector differentiation as a mandatory component (e.g., if stock 1Y return is less than half its sector ETF, Macro -1; if stock outperforms sector by >2x, Macro +1), or (b) reduce Macro weight from 6% to 3% and redistribute to dimensions that actually differentiate (Valuation or Risk). The current Macro dimension is tax on the composite without providing decision-relevant information.

---

### 7. Extension Override Consistency

**Comparison of extension classifications and penalties:**

| Stock | 1M Change | 3M Change | Classification | Penalty |
|-------|-----------|-----------|----------------|---------|
| CRDO | +80.0% | +90.2% | EXTREME | -5 |
| BE | +115.2% | +97.2% | EXTREME | -5 |
| NVT | +35.4% | +36.2% | HIGH | -2 |
| FIX | +30.3% | +66.8% | HIGH | -2 |
| GEV | +18.5% | +42.4% | MEDIUM | 0 |
| CDNS | +22.0% | +25.6% | MEDIUM | 0 |
| KGS | +17.7% | +61.7% | MEDIUM | 0 |
| BBAI | +17.9% | -8.0% | LOW (recovery) | 0 |
| LAW | +23.6% | -9.9% | LOW (recovery) | 0 |
| AMD | +74.2% | N/A | Not shown in scores | -5 (RSI override) |

**Inconsistency found with KGS:** KGS has 1M +17.7% and 3M +61.7%. The rubric says HIGH is "1M >= 30% OR (1M >= 20% AND 3M >= 60%)." KGS has 1M of 17.7% (below 30%) and 3M of 61.7% (above 60%), but 1M of 17.7% is below 20%. So it correctly misses the compound criteria. However, the MEDIUM criteria is "1M >= 15% OR 3M >= 30%." KGS meets both MEDIUM conditions. The classification of MEDIUM is correct.

**Inconsistency found with GEV vs FIX:** GEV has 1M +18.5% and 3M +42.4%. It is classified MEDIUM (correct: 1M 18.5% < 30%, but 1M 18.5% >= 15% triggers MEDIUM). FIX has 1M +30.3% and 3M +66.8%. It is classified HIGH (correct: 1M 30.3% >= 30%). The boundary is sharp -- +18.5% gets 0 penalty and +30.3% gets -2. This is the intended behavior of the rubric, but the cliff effect at 30% is worth noting.

**Recovery exception consistency:** Both BBAI (6M -27.7%, 1M +17.9%) and LAW (6M -22.2%, 1M +23.6%) correctly receive the recovery exception. If LAW had not received it, its 1M +23.6% would trigger MEDIUM but no penalty, and 3M -9.9% is negative so it would be LOW anyway. The recovery exception is actually irrelevant for LAW since it would be LOW without it (3M is negative). The report says it was "downgraded from MEDIUM" which is correct for the 1M metric alone.

**Overall extension consistency: MOSTLY CONSISTENT.** The classifications follow the rubric thresholds correctly. The one concern is GEV being +50% above its 200SMA (noted in the report) but only receiving MEDIUM extension since the extension metric uses 1M/3M price change, not SMA distance. A stock can be massively extended from moving averages but get a LOW extension classification if the recent move was gradual. This is a design gap in the rubric, not a scoring error.

---

### SUMMARY OF INCONSISTENCIES AND RECOMMENDED FIXES

**Scoring Errors (clear rubric violations):**
1. **FIX Backtest should be 4, not 1.** B&H return of +332% triggers the ">100% B&H return = penalty WAIVED" rule. The report applies the full -2 penalty anyway. This raises FIX composite from 56 to approximately 59.

**Scoring Inflation/Deflation (rubric applied but borderline wrong):**
2. **GEV Fundamental should be 6, not 7.** Piotroski 5 and revenue growth of 8.94% (below the 10% threshold for 7-8 range) do not meet the 7-8 criteria. The earnings beat modifier pushed it up, but the base was already too high.
3. **CRDO Valuation should be 7, not 8.** Price at analyst consensus fails the "below analyst consensus" requirement for the 9-10 PEG range. Negative DCF and extreme absolute multiples should anchor the bottom of 7-8 rather than the top.
4. **CDNS Risk should be 6, not 5.** The -1 for "missing options data uncertainty" is not a risk metric -- it is a data quality issue handled by the data completeness override.
5. **FIX Risk should be 4, not 5.** A stock +78% above SMA200 with RSI at 70.3 and beta 1.6 has more risk than the score reflects.

**Systemic Design Issues:**
6. **Smart Money lacks a quality gate.** NVT and BBAI both scoring 7 hides the fact that institutional flow into a distressed company (BBAI, Z-Score 1.12) is fundamentally different from flow into a profitable grower (NVT). Recommendation: Cap Smart Money at 6 when Fundamental <= 3.
7. **Macro dimension is non-differentiating.** 14/18 stocks score 7, contributing ~1.2 points of range to the 100-point composite. Either add stock-vs-sector relative performance as a differentiator, or reduce Macro weight from 6% to 3%.
8. **B&H penalty waiver is not being applied consistently.** Multiple stocks with B&H >100% (NVT +167%, FIX +332%, CRDO +282%, GEV +168%) are still receiving the -2 B&H penalty on their backtest scores. This systematic misapplication suppresses Backtest scores across the watchlist.

**Net Impact of All Fixes on Composites:**

| Stock | Current | After Fixes | Change |
|-------|---------|-------------|--------|
| FIX | 56 | ~60 (Backtest 4, Risk 4) | +4 (pushes from HOLD to BUY territory) |
| GEV | 53 | ~51 (Fund 6) | -2 |
| NVT | 53 | ~54 (Backtest up from B&H waiver) | +1 |
| CRDO | 55 | ~54 (Val 7) | -1 |
| CDNS | 43 | ~44 (Risk 6) | +1 |

The most significant finding is the FIX Backtest error: the B&H >100% waiver rule exists in the rubric but is being systematically ignored. If applied consistently, several stocks with extreme B&H returns (FIX, NVT, CRDO, GEV) would have higher Backtest scores, and FIX in particular would cross from HOLD into BUY territory at 60.