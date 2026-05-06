# Adversarial Audit: Sector & Industry Bias
## Date: 2026-05-06

I'll start by reading the scoring rubrics and scores CSV, then examine reports from different sectors.

---

Now let me read the detailed reports for the key stocks I need to compare across sectors.

---

Now let me read the remaining sector reports -- energy/cleantech and defense/govt.

---

Now let me also check the GEV report for another industrial data point and look at the scoring rubrics for sector ETF mapping details.

---

Now I have all the data needed. Let me compile the comprehensive audit findings.

---

# Sector and Industry Bias Audit -- Findings

## Overview of Stocks Examined

| Stock | Sector | Composite | Signal | Key Observations |
|-------|--------|-----------|--------|------------------|
| AMD | Technology / Semiconductors | 39 | SELL | P/E 136, Rev growth 34% |
| CRDO | Technology / Communication Equipment | 55 | HOLD | P/E 96, Rev growth 126% |
| CDNS | Technology / EDA Software | 43 | HOLD | P/E 79, Rev growth 14% |
| PLTR | Technology / Software | 50 | HOLD | P/E 143, Rev growth 56% |
| BBAI | Technology / IT Services | 39 | SELL | P/E N/A, Rev growth -19% |
| FIX | Industrials / Engineering & Construction | 56 | HOLD | P/E 54, Rev growth 30% |
| NVT | Industrials / Electrical Equipment | 53 | HOLD | P/E 52, Rev growth 30% |
| GEV | Utilities / Renewable Utilities | 53 | HOLD | P/E 31, Rev growth 9% |
| BE | Industrials / Electrical Equipment | 37 | SELL | P/E N/A, Rev growth 37% |
| AMPX | Industrials / Electrical Equipment | 42 | HOLD | P/E N/A, Rev growth 202% |

---

## BIAS 1: Valuation Track Routing -- The P/E >40 Boundary Problem

**Finding: FIX and NVT are borderline cases that expose an inconsistency.**

FIX has P/E 53.8 and revenue growth 29.5%. NVT has P/E 52.4 and revenue growth 29.5%. Both are correctly routed to Track B (both conditions met independently: rev growth >20% AND P/E >40). The routing is consistent today.

However, GEV with P/E 30.5 and revenue growth 8.94% is routed to Track A (DCF-based). GEV's DCF scores are devastating: price is 234% above standard DCF, yielding Valuation 3/10. Had GEV been evaluated on PEG (Track B), its revenue PEG would be 30.5/8.94 = 3.41 -- still poor, but the rubric allows EPS-PEG divergence adjustments that could have added +1 to +3 points. GEV had a 944% EPS beat in Q1, suggesting massive margin expansion that Track A ignores entirely.

**Quantified impact:** GEV Valuation = 3/10 on Track A. On Track B with EPS-PEG divergence, it could plausibly score 4-5/10. This is a +1 to +2 point valuation difference, translating to +1.5 to +3.0 composite points (15% weight). This systematically penalizes industrials in "earnings inflection" mode that haven't yet crossed the P/E 40 or revenue growth 20% thresholds.

**The real problem:** The rubric says "Revenue growth >20% YoY OR P/E >40 = Track B." GEV's 8.94% revenue growth and 30.5 P/E both fail. But its EPS grew 944% in Q1 and its forward P/E is 57.9. The rubric has no mechanism to route based on forward P/E or EPS acceleration. An industrial company at the beginning of a massive margin expansion cycle will be scored on DCF (which is backward-looking for high-growth) rather than PEG (which captures the growth trajectory). This is a structural anti-industrial bias for turnaround/inflection stories.

---

## BIAS 2: Growth Stock Definition -- Mature Tech with Legacy Valuation

**Finding: CDNS is the textbook case of this flaw.**

CDNS has P/E 79.21 and revenue growth of only 14.12%. The rubric routes it to Track B solely because P/E >40. On Track B, its Revenue PEG = 79.21 / 14.12 = **5.61** -- mapping to the absolute worst score bracket (1-2 range, PEG >3.0). CDNS scored Valuation 2/10.

But CDNS is not a "growth stock" by any reasonable definition. It's a mature, high-quality EDA monopoly with 89% gross margins, $8B backlog, and 7/7 earnings beats. If evaluated on Track A (DCF), the standard DCF of ~$174 would still show overvaluation, but the peer-relative P/E comparison (vs. SNPS at 24x EV/EBITDA) and analyst consensus ($380, +12% upside) would likely yield a 3-4/10 valuation rather than 2/10.

**The scoring asymmetry:** The "P/E >40 = Track B" rule created a PEG of 5.61 that is mathematically brutal. A mature company with flat-ish revenue but high P/E (from high margins, not growth) is punished worse than an actual growth company with temporarily high P/E. CRDO with P/E 96 but 126% revenue growth gets PEG 0.76 and scores 8/10. CDNS with P/E 79 but 14% growth gets PEG 5.61 and scores 2/10. The 6-point valuation gap is entirely an artifact of the routing rule, not fundamentally justified.

**Quantified impact:** If CDNS were on Track A, its valuation might be 3-4/10 instead of 2/10. At 15% weight, this is 1.5-3.0 composite points. CDNS composite would be 44-46 instead of 43.

**This bias systematically penalizes mature tech companies** (high-margin EDA, SaaS, infrastructure software) that trade at premium P/E multiples not because of growth expectations, but because of margin quality and competitive moats. The rubric conflates "high P/E" with "growth stock," which is incorrect.

---

## BIAS 3: Sector ETF Mapping Errors

**Finding: Multiple misclassifications detected.**

- **PLTR** is mapped to XLK (Technology). The report uses "XLK +55% 1Y sector outperformance." But PLTR is arguably a Defense/Government contractor -- 74% US revenue, major DoD/IC contracts, closest comps are defense primes (LHX, BAH) not software (MSFT, ORCL). Using XLK instead of XAR (SPDR Aerospace & Defense) or ITA would give a different macro context. Defense ETFs have different cyclical profiles than broad tech.

- **BE** is classified as "Industrials / Electrical Equipment" and mapped to XLI. But BE is a fuel cell / clean energy company. Its actual sector exposure aligns more with ICLN (iShares Global Clean Energy) or QCLN. XLI returned +11.5% YTD -- reasonable for traditional industrials. ICLN has been much more volatile. Using XLI flatters BE's macro score.

- **GEV** is classified as "Utilities / Renewable Utilities" but its macro section uses XLI (+28% 1Y). GEV should map to XLU (Utilities) which has dramatically different performance characteristics. However, GEV is really a power equipment manufacturer, not a utility -- so neither XLU nor XLI captures it precisely. The scoring rubric's lookup table is too coarse.

- **AMPX** (battery technology) is also classified as "Industrials / Electrical Equipment" and uses XLI. AMPX is a pre-revenue battery startup with EV/aviation exposure -- XLI is a poor proxy.

**Quantified impact:** The Macro dimension carries only 6% weight, so misclassification alone shifts the composite by 0.6 points per score point. But the rubric says "Sector ETF data cap: If sector ETF data is unavailable, cap Macro at 6." Several stocks (AMD, CDNS) had FMP 402 errors on sector ETF data and still scored Macro 7. This violates the rubric's own data cap rule. If enforced, AMD and CDNS Macro would drop from 7 to 6, costing 0.6 composite points each.

---

## BIAS 4: Geographic Risk -- Systematic Anti-Semiconductor Penalty

**Finding: The -1/-2 geographic penalty is structurally biased against semiconductors.**

CRDO has 74.1% China/HK revenue and received -1 to Risk (Risk base 4 dropped to 3). This is correct per the rubric ("single non-US country >60% revenue = -1"). But the rubric treats geographic concentration as a company-specific risk when for semiconductors it's an **industry-structural characteristic**. Nearly all fabless semiconductor companies (AMD, CRDO, Broadcom, Marvell) have 50-80% APAC revenue because that's where the manufacturing and assembly happens. Penalizing this is like penalizing oil companies for having revenue from oil-producing countries.

**Cross-sector comparison:**
- CRDO: 74% China/HK = -1 Risk modifier. Risk 3/10.
- PLTR: 74% US = no modifier. Risk 4/10.
- FIX: ~100% US = no modifier. Risk 5/10.
- AMPX: >60% non-US = -1 Risk modifier. Risk 3/10.

The -1 risk modifier at 12% weight costs 1.2 composite points. For CRDO, this pushed Risk from 4 to 3, which contributed to the composite being 55 instead of 56-57.

**Is -2 appropriate for >80%?** The rubric would penalize a semiconductor company with 82% APAC revenue by -2, dropping Risk by 2.4 composite points. Combined with other risk factors (typically high beta for semis), this can push Risk scores to 1-2, triggering potential "Risk <=2 AND composite >=60: Downgrade to HOLD" overrides. This means a fundamentally strong semiconductor stock with normal industry-level geographic distribution could be forcibly downgraded to HOLD purely because of where its customers are.

**Recommendation:** The geographic penalty should be industry-relative. For semiconductors, the >60% threshold should be raised to >80%, and >80% to "single country >90%." Alternatively, the penalty should exclude manufacturing/assembly-related geographic revenue (where goods are shipped, not where end demand exists).

---

## BIAS 5: Piotroski F-Score -- Capital-Light Tech Advantage

**Finding: The Piotroski score creates a measurable but modest pro-tech bias.**

| Stock | Sector | Piotroski | Notes |
|-------|--------|-----------|-------|
| FIX | Industrial | 9/9 | Perfect score -- but FIX is unusually capital-light for industrials |
| PLTR | Software | 7/9 | Software company with typical scores |
| AMD | Semiconductor | 7/9 | High-growth semi with inventory management |
| CRDO | Semiconductor | 7/9 | Recently turned profitable |
| NVT | Industrial | 6/9 | Typical industrial |
| BE | Energy/Cleantech | 7/9 | Despite negative net income -- Piotroski rewards improvement |
| BBAI | Defense/Govt IT | 3/9 | Genuinely distressed |
| CDNS | Software/EDA | 5/9 | Average |
| GEV | Utilities/Power | 5/9 | Average |
| AMPX | Battery/Cleantech | 4/9 | Pre-profit |

**Analysis:** The expected bias (software companies trivially achieving 9/9 due to no inventory and no debt) is NOT strongly visible in this watchlist. FIX (industrial) actually has the highest Piotroski at 9/9, while PLTR and AMD (tech) score 7/9. CDNS, a capital-light software company, only scores 5/9.

The Piotroski components that favor tech (positive ROA, positive operating cash flow, no long-term debt decline, no share dilution) are offset by components that are harder for high-growth tech (current ratio improvement, asset turnover improvement). The bias exists in theory but is **not material in this watchlist** -- the scoring spread within sectors is wider than between sectors.

**Quantified impact:** Minimal. Piotroski feeds into Fundamental score but is one of many inputs (alongside Z-Score, revenue growth, margins, earnings beats). A 2-point Piotroski difference translates to roughly 1 point on Fundamental (moving from 5-6 range to 7-8 range), which at 15% weight is 1.5 composite points. But this difference is not systematically favoring tech over industrials in the actual reports.

---

## BIAS 6: SBC Margin Adjustment -- Tech-Only Penalty

**Finding: The SBC >10% threshold exclusively affects tech companies, as designed. But the threshold is arbitrary.**

PLTR has SBC at 14% of revenue, noted in the warnings ("SBC 14% of revenue -- ongoing dilution concern"). However, the SBC margin adjustment in the rubric did NOT fire to produce a Fundamental penalty in the PLTR report. The report shows Fundamental 9/10 without any SBC deduction.

**Checking the rubric:** The SBC adjustment fires when "SBC >10% of revenue" AND "GAAP-equivalent operating margin < 20% while reported > 30%." PLTR's reported operating margin is 38.1% and its SBC is 14%. GAAP-equivalent = 38.1% - 14% = 24.1%. Since 24.1% > 20%, the first condition for penalty (-1) is not met. So the rule technically doesn't fire.

**The problem:** A company with 38% operating margin and 14% SBC gets no penalty (GAAP-equivalent 24% > 20%). But a company with 32% operating margin and 12% SBC gets -1 (GAAP-equivalent 20% is borderline). This creates a perverse situation where **higher SBC is penalized less** if the company also has very high margins.

**Cross-sector comparison:** No industrial company in the watchlist has SBC >10% of revenue, confirming this adjustment only applies to tech. FIX has SBC well under 5%, NVT similar, GEV similar. The adjustment is effectively a tech-sector-only modifier, but it fails to penalize the most egregious cases (PLTR at 14% SBC) because the margin thresholds are set too low.

**Quantified impact:** In this watchlist, zero stocks actually received an SBC penalty, so the real-world impact is null. But the rule's design means it would only ever penalize mid-tier tech companies (25-30% operating margin + >10% SBC) while sparing both premium tech (PLTR, 38% margins) and all non-tech sectors. This is a poorly calibrated penalty that misses its target.

---

## BIAS 7: Backtest Strategy Bias -- Universally Terrible, but Potentially Sector-Differential

**Finding: Every single stock in the watchlist scored Backtest 1-2/10. This dimension is broken across ALL sectors.**

| Stock | Sector | Backtest | Best Strategy | B&H Return | Trades |
|-------|--------|----------|---------------|------------|--------|
| AMD | Semi | 2 | MACD 40% | 265% | 5 |
| CRDO | Semi | 1 | Bollinger 46% | 282% | 2 |
| CDNS | EDA | 4 | Bollinger 36% | 11% | 6 |
| PLTR | Software | 1 | RSI 6% | 25% | 2 |
| BBAI | Defense IT | 2 | MACD 17% | 23% | 7 |
| FIX | Industrial | 1 | MACD 23% | 332% | 8 |
| NVT | Industrial | 1 | Supertrend 34% | 167% | 2 |
| GEV | Utilities | 2 | MACD 57% | 168% | 9 |
| BE | Energy | 1 | Supertrend 218% | 1667% | 3 |
| AMPX | Battery | 2 | Supertrend 152% | 788% | 4 |

**Key observation:** CDNS is the ONLY stock where a strategy beat B&H (Bollinger 36% vs B&H 11%), and it is also the only stock to score above 2/10 on Backtest (scoring 4/10). This happened because CDNS had moderate, range-bound price action -- the exact conditions where mean-reversion strategies work.

**The sector bias:** Stocks with explosive momentum (BE +1667% B&H, AMPX +788%, FIX +332%, CRDO +282%) are systematically destroyed by the B&H comparison penalty. The strategies tested (RSI, Bollinger, MACD, EMA Cross, Supertrend, Donchian) are all designed for range-bound or moderately trending markets. They are structurally unable to capture parabolic moves. This means:

- **High-momentum sectors (semis, cleantech, high-growth industrials):** Backtest always 1-2/10 because B&H crushes all strategies.
- **Low-momentum sectors (utilities, mature software):** Backtest potentially 3-5/10 because strategies can compete with modest B&H returns.

At 10% weight, this costs high-momentum stocks 3-4 composite points relative to low-momentum stocks. The B&H >100% penalty waiver exists in the rubric ("B&H return >100%: Penalty WAIVED"), but it was not applied in several reports. BE's B&H is 1667% -- the penalty should have been waived but the report shows "subtract 2" still applied.

**Critical finding:** The B&H >100% waiver rule is being inconsistently applied. FIX B&H 332% -- penalty applied anyway (-2). CRDO B&H 282% -- penalty applied (-2). AMD B&H 265% -- penalty applied (-2). BE B&H 1667% -- penalty applied (-2). The rubric clearly states "B&H return > 100%: Penalty WAIVED." This rule was violated in at minimum 6 of 10 reports, costing each stock 2 Backtest score points and approximately 2 composite points (10% weight).

Additionally, the Adaptive Backtest Weighting rule reduces the effective weight when trade counts are low. With <5 trades, weight should drop from 10% to 2%, redistributing 8% to other dimensions. Several stocks have <5 trades (CRDO 2, NVT 2, BE 3, AMPX 4, PLTR 2) but there is no evidence in the reports that adaptive weighting was applied. If it were, the Backtest 1/10 scores would have far less impact.

---

## Summary of Sector Biases (Ranked by Severity)

| Bias | Severity | Affected Sectors | Composite Impact | Status |
|------|----------|-----------------|-----------------|--------|
| **B&H >100% waiver not applied** | CRITICAL | All high-momentum (semi, cleantech, industrial) | -2.0 points per stock | Rubric violation |
| **Adaptive Backtest Weighting not applied** | HIGH | All stocks with <5 trades | Up to -4.0 points | Rubric violation |
| **Growth stock definition (P/E >40 = Track B)** | HIGH | Mature tech (CDNS-type) | -1.5 to -3.0 points | Design flaw |
| **Track routing for inflection industrials** | MEDIUM | Industrials in turnaround (GEV-type) | -1.5 to -3.0 points | Design flaw |
| **Geographic risk threshold** | MEDIUM | Semiconductors, international companies | -1.2 points | Design flaw |
| **Sector ETF mapping** | LOW-MEDIUM | Cleantech, defense crossovers | -0.6 to -1.2 points | Data/mapping gap |
| **SBC adjustment calibration** | LOW | Does not fire in practice | 0 points observed | Design flaw (inactive) |
| **Piotroski tech advantage** | LOW | Not observed in practice | Negligible | Theoretical only |

The two most urgent fixes are the **B&H waiver violation** (a rubric compliance issue, not a design issue) and the **P/E >40 Track B routing** (which needs a secondary check: "Is P/E >40 driven by high growth expectations or by high margins on stable revenue?"). The geographic risk threshold should be made sector-relative, and the Adaptive Backtest Weighting rule needs to be enforced in the scoring engine.