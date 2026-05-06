# Adversarial Audit: Fundamental Score Accuracy
## Date: 2026-05-06

I'll start by reading the scoring rubrics and the analyze-fundamental command, then read all four reports.

---

Now let me read all four reports.

---

Now I have all the data needed for a thorough audit. Let me also check if there are any fundamental-specific intermediate reports that might contain raw data.

---

Now I have all the data needed. Let me also check the AMD case referenced in the question about partial earnings data.

---

Now I have all the evidence. Here is my comprehensive audit:

---

## FUNDAMENTAL SCORE AUDIT REPORT

### 1. FIX scored Fundamental 9/10 -- CORRECTLY ASSIGNED

Checking each criterion from the 9-10 rubric row:

| Criterion | Rubric Requirement | FIX Actual | Met? |
|-----------|-------------------|------------|------|
| Piotroski | >= 8 | **9/9 (perfect)** | YES |
| Z-Score | > 3 | **12.52** | YES |
| Revenue growth | > 20% YoY | **+29.5%** | YES |
| Margins | Expanding | Gross 24.1%->25.1%, Op 14.4%->15.7%, Net 11.2%->12.1% -- **all expanding** | YES |
| FCF | Positive and growing | **$1.03B positive** | YES |
| Earnings beats | >= 6/8 | **8/8 beats** | YES |

The earnings beat modifier also applies: 8/8 beats = +1, and avg surprise 29.4% > 10% = +0.5. Base 9 (from meeting all 9-10 criteria) + modifiers would push it to 10+, but presumably capped at 10. The report gives it a 9, which is actually slightly conservative -- it could arguably be a 10.

**Verdict: Score 9 is defensible. If anything, it could be 10. No inflation here.**

### 2. CRDO scored Fundamental 8/10 -- CORRECTLY ASSIGNED, with one nuance

| Criterion | Rubric Requirement (7-8 row) | CRDO Actual | Met? |
|-----------|------------------------------|-------------|------|
| Piotroski | 6-7 | **7** | YES (7-8 row) |
| Z-Score | > 3 | **110.46** | YES |
| Revenue growth | > 10% | **+126.3%** | YES (massively exceeds) |
| Margins | Stable/expanding | Gross 64.8%->67.8%, Op 8.5%->30.2% -- **dramatically expanding** | YES |
| Earnings beats | >= 4/8 | **6/7 beats** | YES |

The report applies modifiers: beats 6/7 = +1, avg surprise 28.8% > 10% = +0.5. Base 7 (from Piotroski 7 landing in the 7-8 row) + 1.5 modifiers = 8.5, rounded to 8.

**However, there is a rubric design issue (see Issue 6 below).** CRDO has 126% revenue growth, massive margin expansion, strong Z-Score, and 6/7 beats. By every metric except Piotroski (7 vs 8), it meets the 9-10 criteria. The modifier system lets it climb from 7 to 8, but it cannot reach 9 because its Piotroski is 7, not 8. This is a rubric structural problem, not a scoring error given the current rubric.

**Verdict: Score 8 is correct per the rubric as written.**

**SBC Flag:** CRDO has SBC/Revenue = 15.1% (>10% threshold). The report does not explicitly apply the SBC Margin Adjustment. TTM operating margin is 30.2%; SBC is 15.1% of revenue, so GAAP-equivalent operating margin = 30.2% - 15.1% = 15.1%. Since GAAP-equivalent (15.1%) is < 20% AND reported (30.2%) > 30%, the rubric says: Fundamental -1, note "SBC INFLATION." This modifier appears to NOT have been applied. If applied, CRDO should be 8 - 1 = **7/10**. This is a scoring error.

### 3. SATS scored Fundamental 3/10 -- CORRECTLY ASSIGNED

| Criterion | Rubric Row | SATS Actual | Assessment |
|-----------|-----------|-------------|------------|
| Piotroski | 4/9 | Lands in **5-6 row** (4-5 range) | |
| Z-Score | -0.71 | Lands in **1-2 row** (<1.1 distress) | |
| Revenue | -5.18% YoY | **Declining** -- lands in 3-4 row | |
| FCF | -$1.07B | **Negative** -- lands in 1-2 row | |
| Earnings beats | 3/8 (37.5%) | Misses >= 4/8 -- lands in 3-4 row | |

SATS has mixed placement across rows: Piotroski suggests 5-6, Z-Score suggests 1-2, revenue decline and FCF negative suggest 1-2 to 3-4, beats suggest 3-4. The report assigns 3, which includes the -1 modifier for misses 5+ of last 8 (actually 5/8 misses = exactly the threshold for -1).

Could it be 2? A score of 1-2 requires Piotroski 0-1 + Z-Score <1.1 + negative FCF + shrinking revenue + serial earnings misser. SATS has Piotroski 4 (too high for 1-2), and its Z-Score is <1.1, FCF is negative, revenue is shrinking, and beat rate is poor. The Piotroski of 4 prevents this from being a 1-2.

Could it be 4? The 3-4 row requires Piotroski 2-3 + Z-Score 1.1-1.8 + declining revenue/margins + misses >= 4/8. SATS has Piotroski 4 (above the 2-3 range for 3-4), but Z-Score -0.71 is worse than the 3-4 range (it is in distress, which is a 1-2 characteristic). The gravity of the Z-Score distress and negative FCF pulls it down from where Piotroski alone would place it.

**Verdict: Score 3 is reasonable. It sits at the boundary of 2-3, with Piotroski pulling up and Z-Score/FCF pulling down. A score of 2 would also be defensible given the Z-Score of -0.71 and FCF of -$1.07B.**

### 4. BBAI scored Fundamental 3/10 -- CONSISTENCY ISSUE with SATS

| Criterion | BBAI | SATS | Winner |
|-----------|------|------|--------|
| Piotroski | 3/9 | 4/9 | SATS |
| Z-Score | 1.12 (distress, below 1.8) | -0.71 (deep distress) | BBAI |
| Revenue | -19.3% YoY | -5.18% YoY | SATS (less decline) |
| Revenue absolute | $127.7M | $15.0B | SATS (much larger) |
| FCF | -$42.5M | -$1.07B | BBAI (less negative) |
| Net income | -$293.9M | -$23.28B | BBAI (less loss, though impairments distort SATS) |
| EPS beats | 5/7 (71.4%) | 3/8 (37.5%) | BBAI |
| Revenue beats | 0/7 (0%) | Not tracked separately | SATS |
| Debt position | Net cash ($62.8M) | Net debt $29.1B | BBAI |
| Current Ratio | 1.78 | 0.42 | BBAI |

BBAI has notably better characteristics than SATS in several areas: better Z-Score (1.12 vs -0.71), better EPS beat rate (5/7 vs 3/8), net cash vs massive net debt, better current ratio (1.78 vs 0.42). However, BBAI has much worse revenue decline (-19.3% vs -5.2%) and is a serial revenue misser (0/7).

The report's scoring justification for BBAI says: "EPS beats 5/7 quarters (+1 modifier not applied since revenue misses offset)." This is an ad-hoc decision -- the rubric does not have a "revenue miss offset" rule. The rubric's earnings beat/miss modifier specifically references `getEarningsReports` which tracks EPS beats. The report invents a new penalty.

If the rubric were applied literally to BBAI:
- Piotroski 3 = 3-4 row base
- Z-Score 1.12 = technically 1.1-1.8 (grey zone), which is the 3-4 row
- Revenue declining = 3-4 row
- EPS beats 5/7 = this is >=4/8 but below 7/8, so no modifier either way (the +1 requires 7-8 beats, the -1 requires 5+ misses of last 8; BBAI has 2 misses of 7, so neither triggers)

A straight application would give BBAI a base of 3-4. The report gives it 3.

**Should BBAI and SATS have the same score?** Given BBAI's materially better Z-Score, better liquidity, net cash, and better EPS beat rate, a case could be made that BBAI should be 4 rather than 3. The 0/7 revenue miss record is alarming but the rubric does not explicitly penalize revenue misses separately from EPS misses.

**Verdict: BBAI at 3 is slightly harsh relative to SATS also being 3. BBAI's superior balance sheet metrics (net cash, current ratio 1.78 vs 0.42, Z-Score 1.12 vs -0.71) arguably warrant a 4. The report applied a non-rubric "revenue miss offset" to suppress the EPS beat modifier, which is an unauthorized scoring decision.**

### 5. Partial earnings data (FMP 402 error problem)

The AMD case confirms this is a real issue. From `/Users/srivardhanjalan/workspace/trading-desk/reports/AMD_fundamental.md`:
- `getEarningsReports` returned FMP 402
- Only 3 quarters of data were recovered via WebSearch fallback
- AMD's beat record was logged as "2 beats / 1 narrow miss (3 confirmed quarters; FMP 402)"

For FIX, the system got full 8-quarter data (no 402 error). For CRDO, it got 7 quarters of data. For SATS, it got full 8 quarters. For BBAI, it got 7 quarters.

The rubric says "+1 for beats 7-8 of last 8 quarters." When only 3 quarters are available (AMD), the system cannot evaluate this criterion. AMD's report does not show what beat/miss modifier was applied. The rubric says to "fallback to WebSearch for earnings history" when FMP returns 402, but WebSearch recovered only 3 quarters.

**The rubric has no guidance for partial data.** It does not say "extrapolate" or "use proportional beating rate" or "skip the modifier." This is a gap. A company with 2/3 confirmed beats (66.7%) is very different from 5/8 (62.5%) or 7/8 (87.5%), and the confidence interval on 3 data points is enormous.

**Verdict: Confirmed gap in the rubric. The system needs a rule like: "If fewer than 6 of 8 quarters are available, do not apply the beat/miss modifier. Note: 'INSUFFICIENT EARNINGS DATA: {X}/8 quarters available.'"**

### 6. Piotroski F-Score threshold: Is one point worth a full tier?

The rubric creates a hard boundary: Piotroski >= 8 = 9-10 tier, Piotroski 6-7 = 7-8 tier. CRDO demonstrates the problem clearly:

- CRDO: Piotroski 7, Z-Score 110.46, revenue +126%, margins dramatically expanding (op margin 8.5% -> 30.2%), 6/7 beats with 28.8% avg surprise.
- FIX: Piotroski 9, Z-Score 12.52, revenue +29.5%, margins modestly expanding, 8/8 beats with 29.4% avg surprise.

CRDO exceeds FIX on revenue growth (126% vs 29.5%), margin expansion magnitude (3.5x operating margin expansion vs 9% expansion), and Z-Score (110 vs 12.5). Yet CRDO scores 8 and FIX scores 9, solely because Piotroski is 7 vs 9.

The modifier system partially corrects this (CRDO's modifiers push it from 7 to 8), but it cannot push it to 9 because the base tier is capped at 7-8 when Piotroski is in the 6-7 range.

**Verdict: Yes, one Piotroski point is worth a full scoring tier, and this is disproportionate.** The Piotroski F-Score is a blunt instrument (9 binary criteria), and many excellent growth companies score 6-7 simply because they don't pay dividends (one of the 9 criteria). A company could lose a Piotroski point for not paying dividends and be locked out of the 9-10 tier despite being objectively stronger on every other fundamental metric. The rubric should consider treating Piotroski as one input among several rather than as the gating criterion for the entire tier.

### 7. SBC margin adjustment data source

The rubric says: "If stock-based compensation (SBC) >10% of revenue." The `analyze-fundamental.md` pipeline calls `getIncomeStatement` with the note "SBC (stock-based compensation)" on line 35.

However, SBC is frequently reported as a line item in the **cash flow statement** (as a non-cash addback to operating cash flow), not in the income statement. FMP's `getIncomeStatement` may or may not include an SBC field depending on the company.

Evidence from the reports:
- **BBAI**: The fundamental report shows "SBC/Revenue: 18.3%." This data appears to have been sourced, suggesting FMP does return SBC data for some companies. But the report does NOT apply the SBC adjustment to the fundamental score despite SBC being 18.3% > 10%.
- **CRDO**: The fundamental report shows "SBC/Revenue: 15.1%." Again, SBC data was obtained. Again, the SBC adjustment was NOT applied to the fundamental score.

For BBAI: GAAP-equivalent operating margin = -65.3% - 18.3% = -83.6%. The reported operating margin is already deeply negative, so the SBC adjustment would not change the score (it targets cases where reported margin >30% but GAAP-equivalent <20%).

For CRDO: TTM operating margin is 30.2%, SBC is 15.1%. GAAP-equivalent = 30.2% - 15.1% = 15.1%. The rubric says: "GAAP-equivalent <20% AND reported >30%: Fundamental -1." This condition IS met for CRDO. The -1 penalty should have been applied.

**Verdict: The data source appears to work (SBC data is available from FMP), but the SBC modifier is not being consistently applied. CRDO's Fundamental score should be reduced from 8 to 7 after the SBC adjustment.**

### 8. Revenue growth rate source

The rubric says ">20% YoY" without specifying the computation method. The pipeline calls both `getFinancialStatementGrowth` (pre-calculated growth rates) and `getIncomeStatement` with limit=2 (raw revenue figures).

From the FIX fundamental report: "Revenue (FY2025): $9.10B (FY2024: $7.03B) -- YoY: +29.5%." This is consistent with manual computation: ($9.10B - $7.03B) / $7.03B = 29.4%.

From the CRDO fundamental report: "Revenue (FY2025 ending Apr-30): $436.8M (FY2024: $193.0M, YoY: +126.3%)." Manual check: ($436.8M - $193.0M) / $193.0M = 126.3%.

In both cases, the growth rate appears to be manually computed from the two most recent FY income statements, not from the pre-calculated `getFinancialStatementGrowth` API. This is fine when fiscal years are standard, but for companies with non-calendar fiscal years (CRDO's FY ends April 30), the FY2025 income statement may only contain data through April 2025, meaning it could be 12+ months stale at the time of analysis (May 2026). The TTM data from `getIncomeStatementTTM` would be more current.

**Verdict: The revenue growth computation appears consistent (manual from getIncomeStatement limit=2). For CRDO, whose FY ended April 2025, the FY2025 growth rate of 126.3% is over a year old. The TTM revenue is ~$1.07B (implied from P/S 31.8 and market cap $34B), which would show even higher growth. This works in CRDO's favor but could disadvantage companies whose recent-quarter growth is slower than their FY growth.**

### 9. Owner Earnings vs FCF: Which feeds into the Fundamental score?

The rubric says "positive growing FCF" for the 9-10 tier and "negative FCF" for the 1-2 tier. It uses the term "FCF" explicitly, not "owner earnings."

Both metrics are collected:
- **FIX**: FCF $1.03B | Owner Earnings $947M (both positive, close)
- **CRDO**: FCF $29M | Owner Earnings $38M (both positive, close)
- **SATS**: FCF -$1.07B | Owner Earnings -$13.9B (both negative; owner earnings distorted by impairment)
- **BBAI**: FCF -$42.5M | Owner Earnings -$279.1M (both negative; owner earnings much worse due to non-cash charges)

The scoring justifications in all four reports reference **FCF from the cash flow statement**, not owner earnings. For example, FIX's justification says "FCF $1.03B positive and growing." SATS says "FCF -$1.07B." BBAI says "FCF deeply negative."

Owner earnings appears to be collected for informational/analytical purposes but is not the input that determines the Fundamental score.

**Verdict: FCF from `getCashFlowStatement` is the operative metric for scoring, not Buffett-style owner earnings from `getOwnerEarnings`. This is consistent across all four reports. For FIX and CRDO where the two are close, it doesn't matter. For BBAI, where FCF is -$42.5M but owner earnings is -$279.1M, using FCF is more favorable. For SATS, where FCF is -$1.07B but owner earnings is -$13.9B (distorted by impairments), FCF gives a more accurate picture of cash generation. The current approach (using FCF) is reasonable but should be explicitly stated in the rubric.**

---

## SUMMARY OF FINDINGS

| Issue | Severity | Finding |
|-------|----------|---------|
| FIX at 9/10 | Low | **Correctly assigned.** All 9-10 criteria met. Could arguably be 10. |
| CRDO at 8/10 | **HIGH** | **Should be 7/10.** SBC/Revenue is 15.1% (>10%), GAAP-equivalent operating margin is 15.1% (<20% while reported is 30.2% >30%). The -1 SBC penalty was not applied. |
| SATS at 3/10 | Low | **Defensible.** Sits at 2-3 boundary. A score of 2 would also be justifiable given Z-Score -0.71 and FCF -$1.07B. |
| BBAI at 3/10 | **MEDIUM** | **Arguably should be 4.** Materially better balance sheet than SATS (net cash vs $29B net debt, current ratio 1.78 vs 0.42, Z-Score 1.12 vs -0.71). The report invented a non-rubric "revenue miss offset" to suppress the EPS beat modifier. |
| SATS vs BBAI consistency | **MEDIUM** | Both at 3 is inconsistent. BBAI has a clearly better financial position despite worse revenue trends. |
| Partial earnings data | **MEDIUM** | Confirmed gap. AMD had only 3/8 quarters available. Rubric has no guidance for partial data. |
| Piotroski gating | **HIGH (design)** | One Piotroski point creates a full tier boundary. Growth companies that don't pay dividends are systematically penalized. CRDO is the poster child. |
| SBC data source | Low | FMP does return SBC data, but the **modifier is not being applied** when it should be (CRDO). |
| Revenue growth source | Low | Consistently uses manual computation from getIncomeStatement. Acceptable but can be stale for non-calendar FY companies. |
| Owner Earnings vs FCF | Low | FCF is used (correctly). Should be documented explicitly in the rubric. |

**The single most impactful error is CRDO: the SBC margin adjustment was not applied, inflating its Fundamental score from 7 to 8. This flows into the composite and could change the overall signal.**