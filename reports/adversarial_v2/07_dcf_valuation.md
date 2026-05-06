# Adversarial Audit: DCF & Valuation Methodology
## Date: 2026-05-06

I'll start by reading the rubric and analysis command files, then examine stock reports with DCF values.

---

Now let me find the stock reports with DCF values.

---

Excellent. Let me now read the most illustrative reports in detail.

---

Now let me read a few more reports to round out the analysis, particularly focusing on divergent cases.

---

Now let me read the SATS and INFQ reports as well, since they represent edge cases.

---

Now let me also look at the final reports for the scored valuations to see how these DCF issues translated into actual scores.

---

Now let me also read the full reports for some of the stocks to check the PSG fallthrough logic and the complete valuation scoring.

---

Now let me check the previous adversarial audit too for context.

---

I now have comprehensive data to write the audit. Let me compile the full analysis.

---

## ADVERSARIAL AUDIT: DCF AND VALUATION METHODOLOGY

**Date:** 2026-05-06
**Scope:** Rubric file (`/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/_shared/scoring-rubrics.md`) and `analyze-fundamental.md`, validated against 12 stock reports from `/Users/srivardhanjalan/workspace/trading-desk/reports/`
**Verdict:** The DCF and valuation methodology has 8 structural flaws, several of which produce demonstrably wrong scores. The rubric is underspecified on growth rate definitions, has no mechanism for handling DCF divergence, contains no analyst staleness check, and leaves a P/S guardrail gap.

---

### FLAW 1: Standard DCF vs Levered DCF Divergence -- No Handling When They Disagree Massively

**Rubric text (lines 130-131):**
> "Track A: Average of standard DCF and levered DCF."

**Evidence from reports:**

| Stock | Standard DCF | Levered DCF | Divergence | Average |
|-------|-------------|-------------|------------|---------|
| GEV | $317.83 | $618.18 | 94% | $468.00 |
| FIX | $1,058.54 | $1,623.37 | 53% | $1,340.95 |
| KLTR | $3.77 | $5.37 | 42% | $4.57 |
| FLTCF | -$0.08 | $2.94 | infinite | $1.43 |

GEV's standard and levered DCFs differ by 94%. The average of $468 is mathematically meaningless -- it is not closer to "truth" than either individual model. FLTCF's standard DCF is literally negative while levered is positive; averaging produces $1.43, which has no economic interpretation.

**Why it is wrong:** Simple arithmetic mean of two divergent models produces a number that no model actually supports. When two models differ by >50%, they are disagreeing about fundamental assumptions (debt cost, capital structure treatment). The average inherits errors from both without reflecting either model's logic.

**Proposed fix:**
Add to the DCF usage section:

> **DCF Divergence Protocol:**
> - If |Standard DCF - Levered DCF| / min(Standard DCF, Levered DCF) > 50%: Flag "DCF DIVERGENCE." Use the levered DCF as primary (it accounts for actual capital structure). Weight: 70% levered / 30% standard.
> - If either DCF is negative while the other is positive: Discard the negative model entirely. Use the positive model with a -1 confidence penalty on Valuation score. Note: "DCF SIGN CONFLICT: Standard DCF negative, levered positive. Using levered only."
> - If both are negative: DCF is uninformative. Fall through to PEG/PSG regardless of track.

---

### FLAW 2: Averaging $50 and $200 Is Meaningless -- Wrong Central Tendency Measure

**Rubric text (line 130):**
> "Track A: Average of standard DCF and levered DCF"

**Why it is wrong:** When two estimates are multiplicatively different (one is 2x-4x the other), the arithmetic mean is pulled toward the larger value, overstating fair value. This systematically biases Track A valuations upward when the levered DCF (which typically produces higher values for leveraged companies) is inflated.

**Proposed fix:**
Replace arithmetic mean with geometric mean for DCF combination:

> **DCF combination (Track A):** Use geometric mean: sqrt(Standard_DCF * Levered_DCF). This is scale-invariant and penalizes divergence.
> - Example: Standard $317, Levered $618 => Geometric mean = sqrt(317 * 618) = $442.65 (vs arithmetic $468)
> - Example: Standard $1,058, Levered $1,623 => Geometric mean = sqrt(1058 * 1623) = $1,310.62 (vs arithmetic $1,341)
>
> When divergence is small (<20%), the two methods are nearly identical. When divergence is large, geometric mean dampens the bias from the outlier.
>
> **Constraint:** If either value is negative or zero, geometric mean is undefined. Fall through to the DCF Divergence Protocol (Flaw 1 fix).

---

### FLAW 3: Custom DCF Growth Rate Is Unspecified and Produces Garbage Values

**Rubric text (line 131):**
> "Track B: Use custom DCF (with real growth inputs)."

**`analyze-fundamental.md` (lines 81):**
> "revenueGrowthPct = actual revenue growth rate from Phase 7 getFinancialStatementGrowth"

**Evidence from reports:**

| Stock | Growth Input Used | Custom DCF Result | Actual Growth | Problem |
|-------|-------------------|-------------------|---------------|---------|
| KLTR | 120% | $5,714.60 | 1.2% | API interpreted 1.2 as 120% |
| BBAI | -1932% | $194,855 | -19.3% | API compounded negative growth absurdly |
| FLTCF | 121.45% | $55.13 | 121% | Used trailing, unsustainable rate |
| AMD | N/A | API error | 34.3% | "Parameter scaling issue" |
| CDNS | N/A | API error | 14.1% | "1412% growth interpreted" |

The Custom DCF produced garbage values in 5 out of 12 stocks where it was attempted. The root causes are:
1. The FMP `calculateCustomDCF` API interprets the `revenueGrowthPct` parameter inconsistently -- sometimes as a decimal (0.34 = 34%), sometimes as a percentage (34 = 34%), and sometimes it compounds the number over the projection period without decay.
2. The rubric says "real growth inputs" but does not specify: TTM growth? FY YoY growth? Forward consensus growth? 3Y CAGR?

**Proposed fix:**
Add explicit specification to both the rubric and `analyze-fundamental.md`:

> **Custom DCF growth input hierarchy:**
> 1. **Primary:** Forward consensus revenue growth (next FY estimate / current FY actual - 1). Source: `getAnalystEstimates`. Rationale: forward-looking, analyst-adjusted, captures inflection points.
> 2. **Fallback:** TTM revenue growth (if >5% and <100%). Source: `getFinancialStatementGrowth`.
> 3. **Cap:** revenueGrowthPct is HARD CAPPED at 60%. No company sustains >60% growth in a 5-year DCF. If actual growth exceeds 60%, input 60% and note: "GROWTH CAP APPLIED: Actual {X}%, capped at 60% for DCF sustainability."
> 4. **Floor:** If growth is negative, DO NOT run custom DCF. Note: "CUSTOM DCF SKIPPED: Negative revenue growth."
> 5. **API parameter validation:** Before calling `calculateCustomDCF`, verify the API expects the growth rate as a percentage (e.g., 34 for 34%) not a decimal (0.34). Test with a known-value stock. If the result differs from the standard DCF by >10x, the API is misinterpreting the input -- discard and note "CUSTOM DCF API ERROR."

---

### FLAW 4: No Fall-Through for Negative-Earnings Stocks in Track A

**Rubric text (lines 83-91, Track A):**
> Track A criteria reference "Price vs DCF" and "P/E below peer median" -- both require positive DCF and positive P/E.

**Evidence from reports:**

| Stock | Track | DCF | P/E | Problem |
|-------|-------|-----|-----|---------|
| SATS | A (revenue -5.2%) | -$184.64 / -$122.52 | N/A (negative) | Both Track A criteria undefined |
| BBAI | A (broken growth) | -$0.09 / -$0.03 | N/A (negative) | Routed back to A, but A cannot score it |
| LAW | A | -$9.30 / $0.92 | N/A (negative) | DCF sign conflict + no P/E |
| KLTR | A | $3.77 / $5.37 | N/A (negative) | DCF works but P/E comparison impossible |

The rubric correctly identifies that broken growth stories (negative earnings + negative sales growth) should "Route back to Track A." But Track A requires DCF values and P/E ratios, both of which are undefined for money-losing companies. The analyst falls into a gap -- neither Track A nor Track B can score these stocks.

SATS got Valuation = 2 and BBAI got Valuation = 2, which seems correct given their dire fundamentals, but the process to arrive there is ad-hoc. The rubric provides no explicit pathway.

**Proposed fix:**
Add a Track C or a sub-routing within Track A:

> **Track A fallback for negative-earnings stocks:**
> When Track A is selected but P/E is negative AND DCF is negative:
> 1. Use P/S, EV/EBITDA, and P/B vs peer median as primary valuation metrics
> 2. Scoring thresholds for P/S-based Track A:
>    - 9-10: P/S < 1.0x AND P/B < 1.0x AND below analyst consensus
>    - 7-8: P/S < 2.0x AND P/B < 2.0x AND below analyst consensus
>    - 5-6: P/S 2-5x AND near analyst consensus
>    - 3-4: P/S 5-10x AND above analyst consensus OR no analyst coverage
>    - 1-2: P/S >10x OR EV/EBITDA negative with no path to profitability
> 3. Note: "TRACK A NEGATIVE EARNINGS FALLBACK: DCF and P/E unavailable. P/S-based scoring applied."
> 4. If also no analyst coverage: cap at 4. "NO EXTERNAL ANCHOR: Neither DCF nor analyst consensus available."

---

### FLAW 5: PEG Uses "Revenue Growth Rate (%)" Without Specifying Which One

**Rubric text (line 96):**
> "PEG = P/E / revenue growth rate (%)"

**Evidence from reports showing ambiguity:**

| Stock | TTM Revenue Growth | FY YoY Growth | Forward Consensus | PEG Used |
|-------|-------------------|---------------|-------------------|----------|
| PLTR | ~56% | 36% (FY) | lower | 0.50 (TTM) |
| CRDO | ~126% | 126% (FY) | lower | 0.76 (FY) |
| AMD | ~34% | 34.3% (FY) | uncertain | 3.95 (FY) |
| INFQ | 12.8% (FY) | guided 23.1% | 23.1% | 5.2 (TTM) or 2.3 (forward) |

PLTR's PEG of 0.50 uses TTM revenue growth. But PLTR's forward PEG is 3.37 -- a 6.7x difference. The rubric does not specify which to use, so the analyst picks whichever is available, creating inconsistency across stocks. INFQ explicitly calculated both TTM (5.2x) and forward (2.3x) PSG values, demonstrating the gap.

**Why it is wrong:** Trailing growth captures the past; forward growth captures analyst consensus about the future. For stocks with decelerating growth (like PLTR going from 56% to estimated 30%+), trailing PEG massively overstates attractiveness. For stocks with accelerating growth, trailing PEG understates it.

**Proposed fix:**

> **PEG growth rate specification:**
> - **Primary:** Use the LOWER of TTM revenue growth and forward consensus revenue growth. This is conservative and avoids rewarding unsustainable growth rates.
> - **If forward estimates unavailable:** Use TTM growth with a notation: "PEG BASED ON TRAILING ONLY -- forward estimates unavailable. Higher uncertainty."
> - **If TTM and forward diverge by >50%:** Report both PEGs and use the average. Note: "PEG GROWTH DIVERGENCE: TTM {X}%, Forward {Y}%. Averaged PEG = {Z}."
> - **Never use 3Y or 5Y CAGR for PEG** unless both TTM and forward are unavailable.
>
> Example correction for PLTR: TTM growth ~56%, Forward ~30%. Lower = 30%. Adjusted PEG = 143 / 30 = 4.77 (maps to 1-2 range, not 9-10 range). This produces a drastically different and arguably more honest score.

---

### FLAW 6: Analyst Consensus Has No Staleness Check

**Rubric text (lines 86-91, Track A):**
> "below analyst consensus" / "near analyst consensus" / "above analyst consensus"

**`analyze-fundamental.md` (lines 99-100):**
> "getPriceTargetSummary -- analyst consensus target + analyst COUNT + standard deviation"

**Evidence from reports:**

| Stock | Consensus Target | # Analysts | Staleness Problem |
|-------|-----------------|------------|-------------------|
| KLTR | $4.00 | 1 analyst | Set in Jan 2023 -- 3.3 YEARS stale |
| BBAI | $5.33 (all-time) / $6.50 (1Y) | 2-3 analysts | Cantor downgraded Jan 2026, PT was set at $6.41 |
| AMPX | $16.75 (8 analysts) / $18.50 (2 recent) | 2-8 | Stock at $20.87 -- already above all consensus |
| AMD | $270.45 (65 analysts, 1Y) | 65 | Most set when stock was 25-50% lower; only 5 in last month |

KLTR's analyst "consensus" of $4.00 is from a single analyst target set in January 2023. The stock has fundamentally changed since then. Yet the rubric treats this $4.00 target the same as AMD's $319 consensus from 5 recent analysts. The rubric checks analyst COUNT but not recency.

**Proposed fix:**

> **Analyst consensus staleness filter:**
> 1. **Recency requirement:** Only use targets set within the last 6 months. If `getPriceTargetLatestNews` shows the most recent target is >6 months old, flag: "STALE CONSENSUS: Most recent target set {date}. Reliability degraded."
> 2. **Recency-weighted consensus:** If both `getPriceTargetSummary` (all-time/1Y avg) and `getPriceTargetLatestNews` (recent) are available, use the LAST QUARTER average as primary. The all-time average is only a reference point.
> 3. **Minimum analyst count by market cap:**
>    - Large cap (>$10B): Require >= 5 analysts for "consensus." Fewer = "LIMITED COVERAGE."
>    - Mid cap ($2-10B): Require >= 3 analysts.
>    - Small cap (<$2B): Require >= 2 analysts. If only 1, note "SINGLE ANALYST -- NOT A CONSENSUS."
> 4. **Post-earnings reset:** If stock has reported earnings since the consensus was set and the stock moved >15%, the consensus is structurally stale. Note: "POST-EARNINGS CONSENSUS RESET NEEDED."

---

### FLAW 7: P/S Guardrail Gap Between 20x and 40x

**Rubric text (lines 122-125):**
> "If P/S > 40x: cap divergence adjustment at +2 maximum (premium valuation already extreme)"

**No guardrail exists for P/S between 20x and 40x.** The current structure is binary:
- P/S <= 40x: full +3 adjustment allowed
- P/S > 40x: capped at +2

**Evidence from reports:**

| Stock | P/S | EPS PEG | Revenue PEG | Divergence Ratio | Adjustment Allowed |
|-------|-----|---------|-------------|------------------|--------------------|
| AMD | 17x | 0.82 | 3.95 | 4.82 | +3 (full, P/S <40) |
| CRDO | 31.8x | N/A | 0.76 | N/A | N/A (no divergence) |
| AMPX | 39.2x | N/A | N/A | N/A | N/A |
| INFQ | 66.2x | N/A | N/A | N/A | +2 max (P/S >40) |

The gap matters for stocks like CRDO at P/S 31.8x. If it had a qualifying divergence, it could get +3 despite trading at a >30x sales multiple. A company at P/S 39x getting +3 while one at P/S 41x gets only +2 creates a cliff effect.

**Proposed fix:**
Replace the binary guardrail with a graduated scale:

> **EPS-PEG Divergence Guardrail (Graduated):**
>
> | P/S Range | Maximum Divergence Adjustment |
> |-----------|------------------------------|
> | P/S <= 15x | +3 (full) |
> | P/S 15-25x | +3 (full) |
> | P/S 25-35x | +2 |
> | P/S 35-50x | +1 |
> | P/S > 50x | +0 (no adjustment -- valuation is purely speculative) |
>
> Rationale: At P/S > 25x, a company needs to grow revenue 4x just to reach a reasonable 6x P/S in 5 years. Margin expansion at this level is priced in. At P/S > 50x, even massive margin expansion cannot justify the multiple -- the stock is trading on narrative, not fundamentals.

---

### FLAW 8: Revenue PEG -- Trailing or Forward? The Rubric Does Not Say

**Rubric text (line 96):**
> "PEG = P/E / revenue growth rate (%)"

**And (line 110):**
> "This rubric uses revenue growth for PEG to avoid earnings manipulation and one-time items."

**This is the same issue as Flaw 5 but specifically for the Revenue PEG formulation.** The rubric explains WHY it uses revenue growth (to avoid manipulation) but never says WHICH revenue growth. The `analyze-fundamental.md` file says:

> "revenueGrowthPct = actual revenue growth rate from Phase 7 getFinancialStatementGrowth"

This implies FY YoY trailing growth. But `getFinancialStatementGrowth` returns multiple fields: `growthRevenue` (FY YoY), `threeYRevenueGrowthPerShare`, `fiveYRevenueGrowthPerShare`, etc.

**Evidence of inconsistency across reports:**
- CRDO uses "126.3%" -- this is the FY2025 YoY figure
- PLTR uses TTM growth (higher than FY)
- INFQ calculates BOTH TTM and forward, showing they produce different scores
- AMD uses FY2025 YoY (34.34%)

**Proposed fix:**

> **Revenue growth rate for PEG -- definitive specification:**
> 1. Use **FY YoY revenue growth** from `getFinancialStatementGrowth` as the base.
> 2. If the company's fiscal year ended >6 months ago, supplement with TTM growth from `getIncomeStatementTTM` / `getIncomeStatement`. Use the MORE RECENT of FY or TTM.
> 3. **Growth decay adjustment for extreme rates:** If revenue growth > 80%, apply a 0.7x decay factor for PEG purposes: PEG = P/E / (growth * 0.7). Rationale: 126% FY growth (CRDO) implies the market expects deceleration. Using raw 126% overstates attractiveness.
> 4. Report the growth source: "Revenue PEG: {value} (source: FY2025 YoY / TTM / forward). Growth rate: {X}%."
> 5. When forward consensus is available from `getAnalystEstimates`, compute both trailing and forward PEG, and use the HIGHER (more conservative) of the two for scoring. Report both.

---

### SEVERITY SUMMARY

| Flaw | Severity | Stocks Affected (in sample) | Score Impact |
|------|----------|---------------------------|--------------|
| 1. DCF divergence unhandled | HIGH | GEV, FIX, FLTCF, KLTR (4/12) | +/- 2 on Valuation |
| 2. Wrong central tendency | MEDIUM | All Track A stocks (5/12) | +/- 1 on Valuation |
| 3. Custom DCF garbage values | CRITICAL | KLTR, BBAI, FLTCF, AMD, CDNS, NVT (6/12) | Custom DCF unusable for 50% of stocks |
| 4. No negative-earnings Track A path | HIGH | SATS, BBAI, LAW, KLTR (4/12) | Scoring is ad-hoc, no rubric pathway |
| 5. PEG growth rate unspecified | CRITICAL | PLTR (PEG 0.50 vs 3.37), INFQ (PSG 5.2 vs 2.3) | +/- 4 on Valuation in worst case |
| 6. No analyst staleness check | HIGH | KLTR (3.3yr stale), BBAI (stale), AMPX | +/- 2 on Valuation |
| 7. P/S guardrail gap 20-40x | MEDIUM | Potential: CRDO (31.8x), AMPX (39.2x) | +/- 1 on Valuation |
| 8. Revenue PEG trailing vs forward | CRITICAL | Same as Flaw 5, affects all Track B stocks | +/- 3 on Valuation |

**Most critical finding:** Flaws 5 and 8 are effectively the same root cause -- the rubric does not specify which growth rate to use. This single omission can swing PLTR's PEG from 0.50 (9-10 range) to 4.77 (1-2 range), a potential 8-point swing on Valuation. At 15% weight, that is a 12-point swing on composite, enough to change STRONG BUY to SELL.

**Second most critical finding:** Custom DCF produces garbage values for 50% of stocks tested. It should either be fixed (with the API parameter validation and growth cap proposed) or eliminated entirely from the scoring pipeline. Currently, the analyst correctly ignores garbage values, but the rubric provides no guidance for this -- the analyst is making an ad-hoc judgment call that should be codified.