# Adversarial Audit: Macro Regime
## Date: 2026-05-06

I'll start by reading the required files to understand the current scoring system and how macro is implemented.

---

Now let me read some stock reports to see how Macro was actually scored.

---

Let me read a few final reports and fundamental reports to see how Macro was scored.

---

Now let me read the final composite reports to see how Macro was actually scored.

---

Now let me check the scores.csv and a few more reports to see the pattern of Macro scores across different sectors.

---

Now let me look at the adversarial audit that was already done to avoid duplicating findings.

---

I now have a thorough understanding of the system. Let me also check if there's any existing handling of economic calendar events in scoring.

---

Now I have all the evidence I need. Here is my comprehensive audit.

---

## MACRO REGIME SENSITIVITY AUDIT

**Auditor:** Adversarial Macro Regime Agent
**Date:** 2026-05-06
**Scope:** Structural flaws in the Macro dimension scoring, regime detection, and cross-dimensional macro dependencies
**Evidence base:** scoring-rubrics.md, analyze-fundamental.md, 18 stock reports from 2026-05-04/05

---

### EXECUTIVE FINDING

The Macro dimension is the weakest link in the scoring system. Of 18 stocks scored, **15 received Macro = 7**, two received Macro = 6, and one received Macro = 5. A dimension where 83% of stocks get the same score contributes zero differentiating information. At its 6% weight, Macro contributes 0.42 points to the composite for nearly every stock -- it is dead weight masquerading as analysis.

---

### FLAW 1: Macro Is Sector-Level, Not Stock-Level -- It Adds No Differentiating Information

**Evidence from scores.csv:**

| Macro Score | Count | Stocks |
|-------------|-------|--------|
| 7 | 15 | AMD, INFQ, ALMU, FLTCF, FIX, NVT, ASX, AMPX, KGS, BE, CRDO, CDNS, SATS, GEV, PLTR |
| 6 | 2 | KLTR, LAW |
| 5 | 1 | BBAI |

AMD (semiconductor, beta 1.96, 67% Asia revenue) got Macro 7. CDNS (EDA software, beta 1.04, US-focused) got Macro 7. BE (fuel cells, beta 3.19, industrials) got Macro 7. FIX (engineering/construction, beta 1.6) got Macro 7. These companies have completely different interest rate sensitivities, currency exposures, and macro cyclicality profiles.

**Macro-economic reasoning:** Macro risk is not uniform. A rate-sensitive REIT and a subscription software company face opposite forces from the same rate environment. When VIX is 17 and rates are stable, the Macro dimension correctly identifies a benign environment -- but this is not stock analysis, this is weather reporting. Every stock in the same weather gets the same score.

**Proposed fix:** Split Macro into two components:

1. **Macro Environment (portfolio-level):** VIX regime + yield curve shape + credit conditions. Computed once per session, applied as a portfolio-level adjustment to all composites. This is honestly what Macro already is.

2. **Macro Sensitivity (stock-level):** A per-stock modifier based on how exposed that specific company is to the current macro regime. Inputs:
   - Interest rate sensitivity: duration of cash flows (high-growth = long-duration = more rate-sensitive)
   - International revenue % x DXY direction
   - Sector cyclicality (beta to GDP)
   - Commodity input costs (if applicable)
   
   **Scoring rule:** Compute a Macro Sensitivity Multiplier (0.5x to 1.5x) applied to the base Macro Environment score.
   - Revenue >50% international + DXY strengthening: multiply by 0.7
   - Beta >2.0 + VIX 20-30: multiply by 0.8
   - Long-duration growth (P/E >60, no dividends) + 10Y rising >50bps in 3 months: multiply by 0.8
   - Defensive sector (utilities, staples) + VIX >25: multiply by 1.2 (relative haven)
   - Short-duration value (P/E <15, high dividend) + stable rates: multiply by 1.1

---

### FLAW 2: VIX Override Dead Zone Between 25-35

**Evidence from rubric:**
- Macro score table: VIX 25-30 = score 3-4 (labeled "fear")
- VIX override: fires only at VIX > 35 (labeled "PANIC")
- Current VIX: 17.47 for all reports

The rubric's VIX scoring table and its VIX override are inconsistent. The table says VIX 25-30 should produce Macro 3-4. But the override (which subtracts 2 from Macro and forces HOLD for high-beta stocks at composite >= 60) only triggers at VIX > 35. This means at VIX 28:

- The Macro score itself drops to 3-4 (correctly reflecting fear)
- But the composite-level override does NOT fire
- A high-beta stock could still get BUY at composite 65 with VIX at 28

More critically, VIX 30-35 is entirely undocumented in the override logic. The rubric says VIX >30 in the scoring table (score 1-2 range), but the override says >35. A stock could have Macro = 1 from the scoring table but no composite-level protection.

**Macro-economic reasoning:** VIX transitions are not binary. VIX moving from 15 to 28 represents a doubling of implied volatility and typically correlates with a 5-10% drawdown in progress. Historical data shows that VIX sustained above 25 precedes further market declines roughly 60% of the time. Waiting for VIX 35 to trigger the override means the system fires its warning AFTER the damage is done.

**Proposed fix -- graduated VIX override tiers:**

| VIX Range | Override Action | Rationale |
|-----------|----------------|-----------|
| < 15 | None | Complacency; could add +1 to Macro as calm conditions favor risk assets |
| 15-20 | None | Normal |
| 20-25 | Warning only: "VIX ELEVATED at {value}. Tighten stops." | Early caution |
| 25-30 | Subtract 1 from composite for beta > 1.5. Warning for beta <= 1.5. | Fear regime -- high-beta stocks face outsized drawdown risk |
| 30-35 | Subtract 2 from composite for beta > 1.0. Subtract 1 for beta <= 1.0. Downgrade to HOLD if composite 60-70. | Panic building -- even moderate-beta stocks are at risk |
| > 35 | Current rule: Downgrade to HOLD for beta > 1.0. Subtract 3 for all stocks. | Full panic |

**Additional rule:** VIX VELOCITY matters more than level. If VIX rises >5 points in 1 week (from any base), apply -1 to composite regardless of absolute level. A move from 14 to 22 in a week is more dangerous than steady-state VIX 25.

---

### FLAW 3: Treasury Rate Interpretation Is Binary (Inverted vs. Normal) -- Missing Flat Curve and Curve Direction

**Evidence from rubric:** "Check yield curve shape (2Y > 10Y = inverted = recession signal)."

**Evidence from reports:** AMD: "10Y-2Y spread +0.51%, Normal/Steepening." CDNS: "10Y-2Y spread +0.51%, Normal/Steepening." BE: "10Y-2Y spread +0.51%, Normal/Steepening."

The rubric checks only one thing: is 2Y > 10Y? If not inverted, it is "normal" and rates get 7-8 range treatment. But:

- **Flat curve (10Y-2Y spread 0-25bps):** This is NOT normal. A flat curve has historically preceded recessions by 6-18 months. The rubric would call this "normal" because 2Y is not technically above 10Y.
- **Curve direction:** The 10Y-2Y spread went from -100bps (deeply inverted in late 2023) to +51bps (May 2026). This steepening is itself a signal -- it can indicate either (a) the Fed is cutting short rates (bullish) or (b) long-term inflation expectations are rising (bearish). The direction of the steepening matters: bull steepening (short end falling) vs. bear steepening (long end rising) have opposite implications for equities.
- **Absolute level of 10Y:** The rubric does not score whether rates are high or low in absolute terms. The 10Y at 4.39% creates a significantly different equity risk premium environment than 10Y at 2.5%. Discounted cash flow valuations are mechanically lower at higher rates, particularly punishing long-duration growth stocks.

**Proposed fix -- yield curve scoring matrix:**

| Curve Shape | Curve Direction | Rate Level (10Y) | Macro Modifier |
|-------------|----------------|------------------|---------------|
| Inverted (2Y-10Y > 0) | Deepening | Any | -2 (recession imminent) |
| Inverted | Stable | Any | -1 |
| Inverted | Normalizing (spread narrowing toward 0) | Any | 0 (recession risk may be passing) |
| Flat (spread 0-25bps) | Any | Any | -1 (pre-recession warning) |
| Normal (spread 25-100bps) | Bear steepening (10Y rising > 2Y) | >4.5% | -1 (inflation concern) |
| Normal | Bear steepening | <4.5% | 0 |
| Normal | Bull steepening (2Y falling > 10Y) | Any | +1 (Fed easing, bullish) |
| Normal | Stable | <4.0% | +1 (goldilocks) |
| Normal | Stable | 4.0-4.5% | 0 |
| Normal | Stable | >4.5% | -1 (restrictive) |
| Steep (spread >100bps) | Bull steepening | Any | +1 (recovery phase) |

**Implementation note:** This requires calling `getTreasuryRates` for two dates (today and 30 days ago) to compute direction. Currently only today's rates are fetched.

---

### FLAW 4: Missing Data Cap (6) Is HIGHER Than Bad Data Scores (3-4) -- Perverse Incentive

**Evidence from rubric:** "If sector ETF data unavailable, cap Macro at 6."

**Evidence from reports:** AMD got Macro 7 with SMH returning FMP 402. CDNS got Macro 7 with sector ETF returning FMP 402. Both reports note "Sector ETF: N/A -- FMP 402" but still scored 7, not even capped at 6.

This is a compound failure:

1. The cap at 6 is not being enforced -- AMD and CDNS both got 7 despite missing sector ETF data.
2. Even if enforced, capping at 6 for missing data is perverse. If the sector ETF showed -15% YTD performance, the Macro score would drop to 3-4. Missing data literally produces a BETTER score than bad data. This creates a moral hazard: the system is rewarded for failing to collect data.

**Proposed fix:**

- **Enforce the existing cap.** AMD and CDNS should have been capped at 6, not scored 7. This is a compliance failure separate from a design flaw.
- **Change missing data handling:** Instead of cap at 6, use the `getSectorPerformanceSnapshot` as the primary fallback (the rubric already says this). If BOTH fail, compute the implied sector score from available signals:
  - Use `getHistoricalSectorPerformance` (3-month sector trend, already in Phase 2)
  - Use the stock's own relative performance vs SPY as a sector proxy
  - If all sector signals fail, cap at **5** (neutral), not 6. Missing data should never be better than midpoint.

---

### FLAW 5: Economic Calendar Events (CPI, FOMC) Are Collected But Never Scored

**Evidence from analyze-fundamental.md, line 24:**
> "Call `getEconomicCalendar` with from={today}, to={today + 14 days} -- upcoming CPI, FOMC, jobs data. If major macro event coincides with earnings week, volatility amplifies. Flag: 'MACRO EVENT: {event} on {date} during earnings week.'"

**Evidence from scoring-rubrics.md:** There is no scoring rule anywhere that references economic calendar events. The instruction says to "flag" the event, but a flag without a scoring consequence is purely decorative.

**Evidence from reports:** None of the 18 reports mention CPI, FOMC, or any economic calendar event. Either the API was not called, or the results were collected and discarded.

**Macro-economic reasoning:** FOMC meetings and CPI releases are among the highest-impact scheduled events for equity markets. An FOMC meeting in 3 days creates binary outcome risk that is distinct from earnings risk but equally important. CPI surprise drives rate expectations, which feeds directly into valuation discount rates.

**Proposed scoring rules for economic calendar events:**

| Event | Timing | Macro Modifier | Risk Modifier |
|-------|--------|---------------|--------------|
| FOMC rate decision | Within 3 days | -1 to Macro (binary outcome uncertainty) | -1 to Risk |
| FOMC rate decision | Within 7 days | Warning only: "FOMC in {N} days" | No modifier |
| CPI release | Within 3 days AND stock beta > 1.5 | -1 to Macro | No modifier |
| CPI release | Within 3 days AND stock beta <= 1.5 | Warning only | No modifier |
| Non-Farm Payrolls | Within 2 days | Warning only | No modifier |
| Multiple events (FOMC + CPI) within 7 days | Compound | -2 to Macro | -1 to Risk |
| FOMC + stock earnings within same week | Compound | -1 to Macro, note "DUAL CATALYST WEEK" | -2 to Risk |

**Also needed:** A rule for FOMC outcome interpretation AFTER the meeting. If the Fed signals more hikes than expected, this should shift the next batch of analyses. Currently the system has no mechanism to incorporate post-FOMC guidance.

---

### FLAW 6: Industry P/E Data Is Collected But Has No Scoring Rule

**Evidence from analyze-fundamental.md, lines 21 and 23:**
> "Call `getHistoricalIndustryPE` ... Contextualizes the stock's P/E vs. industry norm."
> "Call `getIndustryPESnapshot` ... A P/E of 135 in a sector averaging 80 is very different from P/E 135 in a sector averaging 20."

**Evidence from scoring-rubrics.md:** The Valuation rubric (lines 79-133) has no rule that references industry P/E. Track A uses "P/E below peer median" from `getBatchQuotes` peer comparison (a different data source). Track B uses PEG exclusively. Neither track uses industry-level P/E data.

**Evidence from reports:** AMD's report mentions industry P/E in the adversarial audit as a missing context: "Semiconductor industry P/E history. AMD's P/E of 135 looks extreme in isolation but may be normal relative to the AI semiconductor cohort." But the scoring system itself never used it.

This is a data collection orphan -- the system pays an API call to collect data that has no home in any scoring rule.

**Proposed scoring integration -- Industry P/E Relative Valuation Modifier:**

For Track A:
- Stock P/E < 0.5x industry P/E: Valuation +1 ("DEEP DISCOUNT vs industry norm")
- Stock P/E 0.5-0.8x industry P/E: Valuation +0.5
- Stock P/E 0.8-1.2x industry P/E: no modifier (in-line)
- Stock P/E 1.2-2.0x industry P/E: no modifier (captured in peer comparison)
- Stock P/E > 2.0x industry P/E: Valuation -1 ("EXTREME PREMIUM vs industry: {stock P/E} vs industry {industry P/E}")

For Track B:
- Use industry P/E as a PEG contextualizer. If industry P/E is >50 (as with AI semiconductors in 2026), the entire cohort trades at high multiples. A stock at PEG 3.0 in a sector where ALL peers have PEG 2.5-4.0 is less alarming than PEG 3.0 in a sector where peers average PEG 1.2.
- Rule: If stock PEG is within 1.0x of industry median PEG, reduce PEG penalty by one tier. "INDUSTRY-RELATIVE PEG: Stock PEG {X} vs industry median PEG {Y}. Premium is sector-wide, not stock-specific."

---

### FLAW 7: Interest Rate Sensitivity Is Uniform Across All Sectors

**Evidence from rubric:** The Macro score table applies the same rate criteria to all stocks. "Falling/stable rates" = 7-8 for everyone. "Rapidly rising rates" = 3-4 for everyone.

**Macro-economic reasoning:** This is empirically wrong. Academic and practitioner research consistently shows dramatically different rate sensitivity by sector:

| Sector | Rate Sensitivity | Mechanism |
|--------|-----------------|-----------|
| REITs / Real Estate | EXTREME (negative) | Levered cash flows, property values inversely correlated with rates, dividend yield competition |
| Utilities | HIGH (negative) | Levered, regulated returns compete with bond yields, long-duration cash flows |
| Financials (Banks) | MODERATE (positive for steepening) | Net interest margin expands with steepening curve. But rate INCREASES can cause loan losses. |
| High-Growth Tech | HIGH (negative for levels, mixed for changes) | Long-duration cash flows have highest DCF sensitivity. But rate CUTS signal growth, which is positive for tech. |
| Consumer Staples | LOW | Stable demand regardless of rates. Slight negative from higher debt costs. |
| Energy | LOW-MODERATE | Commodity-driven, not rate-driven. But strong dollar (from rate hikes) hurts international revenue. |
| Healthcare | LOW | Non-cyclical demand. Some R&D-stage biotechs are rate-sensitive (long-duration, no current earnings). |

BE (Bloom Energy) is scored the same as CDNS on rates despite BE having debt/equity of 3.01 and CDNS at 0.30. A rate increase hits BE's interest costs 10x harder.

**Proposed fix -- Sector-Conditional Rate Sensitivity Modifiers:**

Add to the Macro rubric:

```
RATE SENSITIVITY ADJUSTMENT (after base Macro score):
- Compute Rate Regime: Rising (10Y up >25bps in 30d), Stable (+/-25bps), Falling (down >25bps)

If Rate Regime = Rising:
  - REIT/Real Estate: Macro -2
  - Utilities: Macro -2  
  - D/E > 2.0 (any sector): Macro -1
  - High-growth tech (P/E >60, no dividend): Macro -1
  - Financials: Macro +1 (NIM expansion)

If Rate Regime = Falling:
  - REIT/Real Estate: Macro +2
  - Utilities: Macro +1
  - High-growth tech: Macro +1 (duration tailwind)
  - Financials: Macro -1 (NIM compression)

If Rate Regime = Stable: No adjustment.
```

This requires comparing today's 10Y to 30-days-ago 10Y (same implementation need as Flaw 3).

---

### FLAW 8: No Credit Spread Scoring

**Evidence:** The term "credit spread" does not appear anywhere in scoring-rubrics.md, analyze-fundamental.md, or any report. No API call retrieves credit spread data. The FMP API does not appear to have a direct credit spread endpoint, and no WebSearch fallback is specified.

**Macro-economic reasoning:** Credit spreads (the yield premium of corporate bonds over Treasuries) are among the strongest leading indicators for risk appetite and recession probability in the entire macro toolkit. The reason is straightforward: credit spreads reflect the bond market's real-time assessment of corporate default risk, and bond investors are historically more disciplined than equity investors.

Key signal interpretation:
- Investment-grade (IG) spread < 100bps: Risk-on, easy financial conditions
- IG spread 100-150bps: Normal
- IG spread 150-200bps: Caution, conditions tightening
- IG spread > 200bps: Stress, recession risk elevated
- High-yield (HY) spread > 500bps: Acute stress
- HY spread widening >50bps in 30 days: Flight from risk, equities likely to follow

Credit spreads also directly affect companies with debt. BE (D/E 3.01) would face meaningfully higher refinancing costs if credit spreads widened.

**Proposed fix:**

1. **Data source:** Use `WebSearch` to query "ICE BofA US Corporate Index Option-Adjusted Spread" (FRED series BAMLC0A0CM) and "ICE BofA US High Yield Option-Adjusted Spread" (FRED series BAMLH0A0HYM2). Alternatively, approximate from Treasury rates + FMP corporate bond data if available.

2. **Scoring rule:**

| IG Spread | HY Spread | Macro Modifier |
|-----------|-----------|---------------|
| < 100bps | < 350bps | +1 (easy financial conditions) |
| 100-150bps | 350-450bps | 0 (normal) |
| 150-200bps | 450-550bps | -1 (tightening) |
| > 200bps | > 550bps | -2 (stress) |
| Any | > 700bps | -3 + warning "CREDIT STRESS: HY spreads at {value}bps" |

3. **For leveraged companies (D/E > 1.5):** Apply an additional -1 if credit spreads are in "tightening" or worse. These companies face refinancing risk.

---

### FLAW 9: Dollar Strength (DXY) Is Completely Absent

**Evidence:** "DXY" does not appear in any rubric or report. No API call fetches USD index data. AMD's report notes "67% of revenue from Asia-Pacific" but this geographic exposure is only used as a Risk modifier for "Geographic concentration" (-1 if single non-US country >60%), not as a Macro modifier for currency impact.

**Macro-economic reasoning:** For companies with significant international revenue, the US dollar is a direct earnings headwind or tailwind. A 10% move in DXY translates to approximately a 3-5% earnings impact for companies with 50%+ international revenue, purely from translation effects. Beyond translation, a strong dollar makes US exports less competitive globally.

AMD (67% Asia revenue), CDNS (significant international from China operations), and most large-cap tech companies have meaningful DXY exposure. Yet the Macro score treats them identically to purely domestic companies.

**Proposed fix:**

1. **Data source:** `WebSearch` for DXY index level and 30-day change. Alternatively, use FMP's forex data (`getForexQuote` for DX-Y.NYB or USDX) or compute from EUR/USD, JPY/USD, GBP/USD (the three largest DXY components).

2. **Scoring rule -- DXY Macro Modifier:**

```
Compute:
  - international_revenue_pct = from Phase 7 geographic segmentation
  - dxy_30d_change = DXY today vs 30 days ago

If international_revenue_pct > 50%:
  - DXY up >3% in 30d: Macro -1 ("DOLLAR HEADWIND: DXY +{X}% with {Y}% international revenue")
  - DXY up >5% in 30d: Macro -2 ("STRONG DOLLAR HEADWIND")  
  - DXY down >3% in 30d: Macro +1 ("DOLLAR TAILWIND")

If international_revenue_pct 30-50%:
  - DXY up >5% in 30d: Macro -1
  - DXY down >5% in 30d: Macro +1

If international_revenue_pct < 30%: No modifier
```

3. **Cross-dimensional impact:** Add to the Fundamental score's earnings estimate analysis: "If DXY moved >5% since last earnings, forward estimates may not fully reflect currency impact. Flag: CURRENCY RISK NOT PRICED."

---

### SUMMARY: Cumulative Impact of All 9 Flaws

If all nine flaws were addressed, the Macro dimension would transform from a uniform 7-for-everyone decoration into a genuinely differentiating signal. Taking AMD as a case study:

**Current Macro score: 7/10** (VIX normal, rates stable, sector ETF missing)

**Corrected Macro score under proposed rules:**
- Base: 7 (VIX 17.47 normal, curve normal)
- Flaw 1 (Stock-level sensitivity): AMD beta 1.96, 67% international revenue, P/E 135 (long-duration). Sensitivity multiplier ~0.85. Score: 7 x 0.85 = 5.95, round to 6
- Flaw 3 (Curve direction): Normal curve, stable direction, 10Y at 4.39% (moderate-high). No modifier.
- Flaw 4 (Missing sector ETF): Cap at 5 (not 6). Score: min(6, 5) = 5
- Flaw 7 (Rate sensitivity): High-growth tech, P/E >60, no dividend. If rates were rising: -1. Currently stable: 0. Score: 5
- Flaw 9 (DXY): If DXY up >3%, -1. Depends on current data.
- Flaw 8 (Credit spreads): If IG spread <100bps, +1. Depends on current data.

**Result: AMD Macro would likely be 5-6 instead of 7.** At 6% weight, this changes the composite by 0.06-0.12 points (0.6-1.2 on the 100-point scale). Marginal for a single stock, but across 18 stocks, meaningful differentiation emerges where none currently exists.

**The larger structural point:** At 6% weight, Macro can never move the needle enough to matter even when correctly scored. If the system is going to have a Macro dimension, it should either (a) increase its weight to 10-12% and make it genuinely stock-specific per the fixes above, or (b) remove it as a scored dimension entirely and implement it as a portfolio-level regime gate that modifies position sizing and signal thresholds rather than individual stock scores.

**Recommended path:** Option (b). Macro conditions affect ALL positions simultaneously -- they are portfolio risk, not stock risk. Implement Macro as:
- A **Regime Gate** that adjusts decision thresholds: In "fear" regime (VIX >25, spreads widening, curve inverting), raise the BUY threshold from 60 to 70 and lower SELL from 40 to 45.
- A **Position Size Multiplier**: In "panic" regime, halve all position sizes. In "euphoria" regime (VIX <12, spreads <80bps), warn about complacency but do not restrict.
- Stock-specific macro sensitivity factors (DXY, rate sensitivity, credit exposure) should be folded into the **Risk** dimension where they naturally belong.