# Adversarial Audit: Risk Score Methodology
## Date: 2026-05-06

I'll start by reading the scoring rubric, then examine several stock reports to see how risk is scored in practice.

---

Let me read 4 stock reports to see how Risk was scored in practice.

---

Now let me also check the BBAI report for a smaller-cap example to see how liquidity risk plays out.

---

Now I have comprehensive data. Let me compile the full audit.

---

## ADVERSARIAL AUDIT: Risk Score Methodology — 9 Flaws Analyzed

### Evidence Base
- **Rubric reviewed:** `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/_shared/scoring-rubrics.md` (lines 251-266)
- **Reports reviewed:** CDNS, PLTR, CRDO, AMD, BBAI (all from `/Users/srivardhanjalan/workspace/trading-desk/reports/`)

---

### FLAW 1: Risk Inversion Is Poorly Communicated

**The problem:** Risk is scored "10 = lowest risk" while every other dimension uses "10 = best." The rubric header says `Risk Score (1-10) — INVERTED: 10 = lowest risk` (line 251), but in the actual reports, the only communication is a brief parenthetical like `(inverted: 10 = lowest risk)` buried in the scoring justification section. A reader scanning the Scores table sees "Risk 3/10" and instinctively reads it as "low risk" -- exactly backward.

**Evidence in reports:**
- CRDO scores table: `Risk | 3/10 | ███░░░░░░░ | 12% | Beta 2.72...` -- the visual bar being 30% full *looks like* "low risk" but means "high risk."
- AMD: `Risk | 3/10` -- same problem.
- BBAI: `Risk | 2/10` -- extreme risk, but the presentation says "2 out of 10."
- The composite calculation treats Risk 3 as a low weighted contribution (3 x 0.12 = 0.36), which *correctly* drags the composite down. But this works only because the math is right -- the *presentation* is misleading.

**Additionally:** The Quality-Timing dual score puts Risk into the Timing Score with 25% weight. When Risk = 3 (high risk), the Timing Score is lowered -- correct mathematically. But the label "Timing Score" combined with an inverted Risk input is doubly confusing.

**Proposed fix -- change rubric line 251 and add report formatting guidance:**

```markdown
## Risk Score (1-10) — INVERTED: 10 = lowest risk, 1 = highest risk

**PRESENTATION RULE:** In the Scores summary table, display Risk using the
INVERTED label to prevent misreading:

| Risk (10=safest) | 3/10 | ███░░░░░░░ | 12% | Beta 2.72... |

In all narrative text, always write: "Risk: 3/10 (HIGH RISK — inverted scale)"
Never write "Risk: 3/10" without the parenthetical clarification.

**Alternative (preferred):** Convert Risk to a non-inverted "Safety" score 
where 10 = safest, OR flip the internal scoring so 1 = safest and 10 = riskiest, 
then subtract from the composite rather than adding. This eliminates the 
inversion confusion entirely.
```

---

### FLAW 2: RSI Overbought Double-Counting Between Risk and Technical (ADX-Conditional Fix Not Propagated)

**The problem:** The Technical score has an ADX-conditional RSI interpretation (rubric lines 38-47) where ADX > 35 means RSI overbought is treated as "momentum CONFIRMATION -- no penalty." But the Risk score criteria (line 258) still penalizes for "RSI overbought/oversold" in the 3-4 range unconditionally. There is no ADX-conditional carve-out in Risk.

**Evidence in reports:**
- AMD: RSI 79.84, ADX 47.99. Technical correctly notes "ADX 47.99 strong trend" but caps at 5-6 due to RSI overbought. Risk scores 3/10 and explicitly lists "RSI 79.84 overbought -> drops to 3-4." The ADX-conditional fix is NOT applied to Risk. AMD gets hit for RSI overbought in: (a) Technical score cap, (b) Risk score drop, and (c) Override 1 (overbought penalty -5). That is triple-counting, with Risk being the only dimension that ignores the ADX context.
- CRDO: RSI 64.87, ADX 32.73. RSI not overbought so the issue does not trigger here, but if RSI were 76+ with ADX 32.73, Risk would penalize without any ADX consideration.

**Proposed fix -- add to Risk rubric after line 259:**

```markdown
**ADX-Conditional RSI in Risk (mirrors Technical):**
When ADX > 35 with +DI > 2x -DI, RSI overbought is trend-confirming. 
Risk scoring should NOT penalize for RSI overbought in this condition:
- ADX > 35 + strong directional bias: RSI overbought does NOT drop Risk 
  to 3-4. Stay at beta-derived base. Note: "RSI overbought ignored for 
  Risk — ADX {value} confirms trend."
- ADX 25-35: Partial penalty — drop Risk by 1 (not full tier).
- ADX < 25: Full penalty — RSI overbought drops Risk to 3-4 as current rubric.

This prevents triple-counting the same RSI signal across Technical, Risk, 
and Override 1.
```

---

### FLAW 3: SMA Extension Double-Counting Between Risk 1-2 and Override 5

**The problem:** Risk criteria 1-2 includes "extended >30% from 50 SMA" (line 259). The Momentum Extension Override (lines 380-417) independently penalizes stocks extended >30% in 1M or >30% in 3M. These two mechanisms measure overlapping signals -- a stock +50% from SMA50 will almost certainly have +30% or more in 1M/3M. The stock gets penalized in Risk scoring AND in the composite override.

**Evidence in reports:**
- CRDO: "+44.5% from SMA50" is cited in Risk scoring (drops base to 3-4 range) AND Extension Override EXTREME (-5 from composite). The same price extension is counted twice.
- AMD: "+53.1% above SMA50" is cited in Risk scoring AND Extension EXTREME (-5). Same signal, counted twice.

The rubric explicitly says Override 5 "Does NOT stack with Override 1" (line 291) to prevent RSI double-counting, but there is NO equivalent anti-stacking rule between Risk scoring and Override 5 for SMA extension.

**Proposed fix -- add to Risk rubric:**

```markdown
**SMA Extension in Risk vs Override 5 (anti-stacking):**
If Override 5 (Momentum Extension) applies a penalty (HIGH or EXTREME), 
do NOT also penalize for SMA50 extension in the Risk dimension. Use the 
Override penalty only, as it is the more calibrated measure (considers 1M 
and 3M returns, IPO exceptions, recovery exceptions).

When Override 5 is active:
- Risk should score SMA extension as "captured by Override 5 — no 
  additional penalty in Risk base." 
- Risk base should derive from beta + IV/HV + earnings proximity + 
  other non-extension factors only.
```

---

### FLAW 4: IV/HV Ratio Not Adjusted for Earnings Proximity

**The problem:** Risk 3-4 criteria includes "IV/HV > 1.5" (line 258). But implied volatility naturally spikes before ANY earnings announcement regardless of actual risk. A stable company like CDNS will see IV/HV climb above 1.5 in the 2 weeks before earnings simply because the options market prices in the binary event. This is not a risk signal -- it is a structural feature of options pricing.

**Evidence in reports:**
- BBAI: IV/HV = 4.6x with earnings tomorrow. This correctly signals extreme event risk, but a significant portion of that 4.6x is the mechanical earnings IV spike, not idiosyncratic danger.
- CDNS: IV/HV = N/A (not collected), but the report notes CDNS has earnings in ~2 months. If analyzed 2 weeks before earnings, IV/HV would spike above 1.5 simply due to earnings proximity, making a low-beta, Piotroski-5 stock look risky.
- AMD: IV/HV = 0.49 (actually inverted because HV is anomalously high from the 74% rally). The report itself flags this: "HV of 230% reflects the 74% April rally, not normal volatility." This shows IV/HV is fragile as a standalone metric.

**Proposed fix -- add IV/HV adjustment:**

```markdown
**IV/HV Earnings Proximity Adjustment:**
IV naturally rises before earnings regardless of actual risk. Adjust 
the IV/HV risk threshold when earnings are within 21 days:

| Days to Earnings | IV/HV Risk Threshold Adjustment |
|-----------------|--------------------------------|
| > 21 days       | Use standard thresholds (1.5 for 3-4 range) |
| 14-21 days      | Raise threshold to 2.0 (mild earnings premium normal) |
| 7-14 days       | Raise threshold to 2.5 (significant earnings premium expected) |
| < 7 days        | Raise threshold to 3.0 (IV crush imminent, high ratio is structural) |

When IV/HV exceeds the adjusted threshold, it IS a genuine risk signal 
(market expects outsized move beyond normal earnings volatility). When 
IV/HV is below the adjusted threshold, it is structural and should not 
penalize Risk.

**Additionally:** When HV is anomalously high due to a recent sharp move 
(HV > 150% annualized), flag IV/HV as unreliable and use absolute IV 
percentile (vs. its own 52-week IV range) instead:
- IV > 80th percentile of 52-week range: treat as elevated
- IV < 50th percentile: treat as normal
- Note: "IV/HV UNRELIABLE — HV distorted by recent {X}% move. 
  Using IV percentile: {Y}th."
```

---

### FLAW 5: Geographic Concentration Ignores US Domestic Concentration Risk

**The problem:** The Risk modifier says "-1 for >60%, -2 for >80% single non-US country" (line 263). This implicitly treats US revenue as zero risk. But a company with 95% US revenue is heavily exposed to US economic cycles, US regulatory changes, US consumer spending, and USD monetary policy. The rubric penalizes CRDO for 74% China/HK exposure but gives no penalty to a hypothetical US-only company that is equally concentrated.

**Evidence in reports:**
- CRDO: "Geographic concentration: China+HK 74.1% >60% = -1 modifier" -- correctly applied.
- PLTR: "No geographic concentration risk (US-based company, US 74% revenue)" -- PLTR gets zero penalty despite 74% US concentration. If US enters recession, PLTR's government contracts may face budget cuts. The geographic risk is real but unpenalized.
- AMD: "China 22.4% revenue (below 60% threshold -- no modifier)" -- correctly no penalty for China, but AMD's remaining 77.6% US/global diversification is implicitly treated as safe.

**Proposed fix -- expand geographic modifier:**

```markdown
**Geographic Concentration Risk (revised):**
- Single NON-US country >60% revenue: -1. >80%: -2.
- US domestic >90% revenue: -0.5 (rounded). US economic cycle exposure 
  is real but less volatile than emerging market concentration.
- ANY single country (including US) = 100% revenue: -1. Total geographic 
  concentration is a risk regardless of which country.
- Diversified (no single country >50%): no modifier.

Note: The asymmetry between US and non-US penalties reflects that US 
markets have deeper capital access and more stable regulatory frameworks, 
but does NOT mean US concentration is risk-free.
```

---

### FLAW 6: Beta Is Not Decomposed Into Upside/Downside

**The problem:** The rubric uses absolute beta: Beta <1.0 = 9-10, Beta 1.0-1.5 = 7-8, etc. (lines 255-259). But absolute beta averages upside and downside sensitivity. A stock that moves 2x the market on up days but only 0.5x on down days (asymmetric upside beta) is far less risky for a long holder than one with 2x beta in both directions. The rubric treats them identically.

**Evidence in reports:**
- PLTR: Beta 1.521, scored in 5-6 range. But PLTR's actual downside behavior may differ from its upside -- the report does not decompose.
- BBAI: Beta 3.236, scored in 1-2 range. Given BBAI's extreme beta, knowing whether it is symmetric or skewed would materially change the risk assessment.
- CRDO: Beta 2.72. If CRDO has asymmetric upside beta (which high-growth stocks often do during bull markets), the risk is overstated.

**Proposed fix -- add downside beta modifier:**

```markdown
**Downside Beta Modifier (when data available):**
Compute downside beta = covariance(stock returns, market returns | 
market returns < 0) / variance(market returns | market returns < 0).

If downside beta data is available (from FMP or computed from daily 
returns over trailing 6 months):
- Downside beta < 0.7x absolute beta: Risk +1 (stock falls less than 
  expected in down markets — less risky than absolute beta implies)
- Downside beta > 1.3x absolute beta: Risk -1 (stock falls MORE than 
  expected in down markets — riskier than absolute beta implies)
- Downside beta within 0.7x-1.3x of absolute beta: no modifier 
  (symmetric — absolute beta is representative)

Note: "Downside beta: {X} vs absolute beta {Y}. Ratio: {Z}x. Modifier: 
{+1/0/-1}."

When downside beta is unavailable, note "DOWNSIDE BETA: N/A — using 
absolute beta only" and apply no modifier.
```

---

### FLAW 7: Bid/Ask Spread Measurement Timing Is Unspecified

**The problem:** The rubric says "-1 for >2%, -2 for >5%" (line 263) but does not specify WHEN the spread is measured. Spreads vary dramatically: wide at open, narrow midday, wide again at close, extremely wide after hours. If measured from an Alpaca snapshot at market close or after hours, spreads may be artificially inflated.

**Evidence in reports:**
- PLTR: "Bid/ask spread 4.43% (>2% = -1 modifier)" -- the report also notes "AFTER-HOURS SPREAD: 4.43% -- use limit orders only." This means the -1 penalty was applied using an after-hours spread, which is NOT representative of normal trading conditions. PLTR trades ~80M shares/day; its intraday spread is typically $0.01-0.02 on a $135 stock (0.01-0.02%), not 4.43%.
- CRDO: "AFTER-HOURS SPREAD: 27.1% -- use limit orders only" -- this after-hours spread is cited in warnings but the Risk scoring section does not explicitly apply the -1/-2 modifier. However, the inconsistency is clear: some reports penalize for stale after-hours spreads, others do not.
- BBAI: "Bid/ask spread 1.69% (acceptable)" -- under 2%, no penalty. But BBAI at $4.14 with low volume likely has wider spreads during market hours than 1.69%. When was this measured?

**Proposed fix -- add spread measurement rules:**

```markdown
**Bid/Ask Spread Measurement Rules:**
- Source: Alpaca `get_stock_latest_quote` or `get_stock_snapshot`
- ONLY apply spread modifier during MARKET HOURS (9:30-16:00 ET). 
  After-hours and pre-market spreads are structurally wide and 
  unrepresentative.
- If analysis is run outside market hours: note "SPREAD: After-hours 
  ({X}%) — not used for Risk modifier. Use limit orders at open." 
  Do NOT apply -1/-2 modifier from after-hours data.
- If market-hours spread is available from the most recent trading 
  session's midday snapshot (11:00-15:00 ET preferred): use that value.
- When no market-hours spread is available: note "SPREAD: N/A (market 
  closed)" and apply no modifier. Flag for re-check at market open.
```

---

### FLAW 8: No Liquidity Risk Component

**The problem:** The Risk score has no concept of liquidity risk. A $50M market cap stock trading 10K shares/day is fundamentally riskier than a $200B stock, even if both have the same beta, RSI, and IV/HV. Position sizing partially addresses this via the 20% portfolio cap, but the Risk SCORE does not reflect it. A low-liquidity stock scored Risk 7/10 (low risk) would mislead a reader into thinking it is safe.

**Evidence in reports:**
- BBAI: Market cap ~$825M (based on $4.14 price and share count). Risk scored 2/10 for other reasons (beta, IV/HV, earnings), but liquidity is never mentioned as a risk factor despite BBAI being a micro/small-cap stock with potentially thin order books.
- CDNS: Market cap ~$93B. Much more liquid but scored Risk 5/10 -- the same range BBAI could receive in a calm period despite being 100x less liquid.
- The rubric's bid/ask spread modifier (line 263) partially captures liquidity, but spread is a symptom, not the cause. A stock can have a tight spread at the moment of measurement but still be illiquid when you try to exit a large position.

**Proposed fix -- add liquidity risk modifier:**

```markdown
**Liquidity Risk Modifier:**
Compute from market cap and average daily volume (from FMP or Alpaca):

| Market Cap | Avg Daily $ Volume | Risk Modifier |
|-----------|-------------------|---------------|
| < $500M   | < $5M/day         | -2 (illiquid micro-cap) |
| < $2B     | < $20M/day        | -1 (thin small-cap) |
| $2B-$10B  | < $50M/day        | -0.5 (rounded) |
| > $10B    | > $100M/day       | 0 (liquid large-cap) |

**Exit risk test:** If recommended position size (from Phase 15) exceeds 
5% of average daily volume, apply additional -1. "POSITION LIQUIDITY 
WARNING: {shares} shares = {X}% of ADV. Exit may move price."

Note: This modifier stacks with bid/ask spread modifier (they measure 
different aspects of liquidity — spread measures cost, volume measures 
capacity).
```

---

### FLAW 9: Earnings Proximity Is Binary, Not Scaled

**The problem:** The Risk 5-6 criteria says "earnings within 14d" (line 257) and Risk 3-4 says "earnings imminent" (line 258). "Within 14d" and "imminent" are vaguely defined, and the rubric treats earnings in 13 days the same as earnings tomorrow. In reality, earnings tomorrow carries dramatically more risk: IV has peaked, gap risk is maximal, and no new information will resolve uncertainty before the event. At 13 days out, a trader could still exit before the event.

**Evidence in reports:**
- AMD: "Earnings TOMORROW" -- Risk scored 3/10, with earnings proximity as one factor among many. The report correctly flags this as extreme, but the rubric only pushes it into the 3-4 range, same as "earnings in 10 days."
- BBAI: "EARNINGS TOMORROW" -- Risk scored 2/10, partially due to other extreme factors (beta 3.24, IV/HV 4.6x). But the earnings proximity itself is treated the same way it would be at 13 days.
- CRDO: "Earnings in 28 days" -- outside the 14-day window, no earnings penalty. But at 14 days the penalty would suddenly appear, while at 15 days it would not. This is a cliff effect.
- The Earnings Catalyst Modifier (Override 6, lines 297-315) triggers at 7 calendar days and applies a composite modifier. But the Risk dimension's 14-day threshold and Override 6's 7-day threshold are inconsistent and partially overlapping.

**Proposed fix -- replace binary earnings proximity with scaled:**

```markdown
**Earnings Proximity Risk (scaled, replaces binary "within 14d"):**

| Days to Earnings | Risk Modifier | Rationale |
|-----------------|---------------|-----------|
| > 21 days       | 0             | Event too distant to affect near-term risk |
| 14-21 days      | -0.5 (rounded)| Awareness phase — IV starting to build |
| 7-14 days       | -1            | Active risk — IV expanding, gap risk rising |
| 3-7 days        | -1.5 (rounded)| High risk — limited time to exit before event |
| 1-2 days        | -2            | Extreme — earnings imminent, max gap risk |
| Day of (pre-report) | -3        | Binary event — full gap exposure |

This modifier is ADDITIVE to the base Risk score derived from beta/RSI/IV.

Interaction with Override 6 (Earnings Catalyst): Override 6 adjusts the 
COMPOSITE based on beat probability. The Risk proximity modifier adjusts 
the Risk DIMENSION based on event timing. They operate at different levels 
and DO stack: a high-EBP stock still has gap risk even if the gap is 
likely positive.
```

---

### SUMMARY OF INTERCONNECTIONS

Several of these flaws compound each other:

1. **Triple RSI counting** (Flaws 2 + existing Override 1): A stock like AMD with RSI 79.84 and ADX 47.99 gets penalized in Technical (cap at 5-6), Risk (drop to 3-4), AND Override 1 (-5 from composite). Three penalties for one signal. The ADX-conditional fix in Technical was a step in the right direction but was never propagated to Risk.

2. **Double extension counting** (Flaw 3): SMA extension hits both Risk scoring and Override 5. The rubric already has anti-stacking logic for RSI (Override 1 vs Override 5) but forgot to extend it to Risk vs Override 5.

3. **Phantom spread penalties** (Flaw 7): PLTR lost a Risk point for a 4.43% after-hours spread that would be 0.01% during market hours. This is a data quality problem masquerading as a risk signal.

4. **Missing liquidity dimension** (Flaw 8): Without liquidity in Risk scoring, the bid/ask spread modifier (which itself is unreliable per Flaw 7) is the only proxy for market microstructure risk. Adding an explicit liquidity modifier would make the spread modifier less critical.

5. **IV/HV and earnings proximity interact** (Flaws 4 + 9): Both need to account for the structural relationship between IV and earnings dates. Fixing them together (scaling both by days-to-earnings) creates a coherent pre-earnings risk framework.