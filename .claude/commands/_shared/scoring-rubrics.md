# Scoring Rubrics Reference

This file defines the explicit scoring thresholds for all 8 dimensions used by the analysis pipeline. Read this file during Phase 16 (Synthesis) to score each dimension consistently.

---

## Composite Weights

| Dimension | Weight (Stock) | Weight (Crypto) |
|-----------|---------------|-----------------|
| Technical | 22% | 35% |
| Fundamental | 15% | N/A |
| Valuation | 15% | N/A |
| Smart Money | 13% | 25% |
| Risk | 12% | 20% |
| Backtest | 10% | 12% |
| Sentiment | 7% | 8% |
| Macro | 6% | N/A |

Crypto drops Fundamental, Valuation, Macro (36%) and redistributes to remaining 5 dimensions.

---

## Technical Score (1-10)

All scores are **directional for LONG positions** (how good is this stock to BUY right now?).

| Score | Criteria |
|-------|----------|
| 9-10 | All 5 TFs aligned bullish + RSI 40-70 + MACD crossover confirmed + ADX >25 (trending) + Stochastic confirms |
| 7-8 | 4/5 TFs aligned + favorable RSI + positive MACD or ADX >20 + Stochastic aligned |
| 5-6 | Mixed: 3/5 TFs aligned, or RSI overbought/oversold, or MACD flat, or Stochastic diverging |
| 3-4 | 2/5 TFs aligned, conflicting signals, ADX <20 (no trend) |
| 1-2 | All TFs bearish (for buy) or all bullish (for sell), RSI extreme + ADX declining |

**Stochastic modifier:** Stochastic >80 with price at highs = -1. Stochastic <20 with price at lows in uptrend = +1.

**ADX-Conditional RSI Interpretation (Trend-Adjusted):**
The RSI overbought penalty is conditional on trend strength measured by ADX:

| ADX Range | +DI/-DI | RSI >75 Treatment | Technical Cap | Override 1 Multiplier |
|-----------|---------|-------------------|---------------|----------------------|
| ADX > 35 | +DI > 2x -DI | Momentum CONFIRMATION — no penalty | No cap from RSI | 0.5x (halve penalty) |
| ADX 25-35 | — | Partial penalty | Cap at 6 (not 5) | 0.6x |
| ADX < 25 | — | Exhaustion WARNING — full penalty | Cap at 5-6 (existing) | 1.0x (full penalty) |

When ADX > 35 with strong directional bias, RSI overbought indicates trend acceleration, not exhaustion. Note: "TREND-CONFIRMED OVERBOUGHT — ADX {value}. RSI is momentum confirmation."

**Volume Direction Modifier:**
- Price change < -3% AND volume > 1.5x average: Technical -1. "DISTRIBUTION: {volume_ratio}x volume on {change}% day."
- Price change > +3% AND volume > 1.5x average: Technical +1. "ACCUMULATION: {volume_ratio}x volume on {change}% day."
- Price change < -5% AND volume > 2.0x average: Technical -2. "SEVERE DISTRIBUTION."

---

## Fundamental Score (1-10)

| Score | Criteria |
|-------|----------|
| 9-10 | Piotroski >=8 + Z-Score >3 + revenue growing >20% YoY + margins expanding + positive growing FCF + beats earnings >=6/8 quarters |
| 7-8 | Piotroski 6-7 + Z-Score >3 + revenue growing >10% + stable/expanding margins + beats >=4/8 quarters |
| 5-6 | Piotroski 4-5 + Z-Score 1.8-3 + revenue flat or <10% growth + mixed beat/miss history |
| 3-4 | Piotroski 2-3 + Z-Score 1.1-1.8 (grey zone) + declining revenue or margins + misses >=4/8 quarters |
| 1-2 | Piotroski 0-1 + Z-Score <1.1 (distress) + negative FCF + shrinking revenue + serial earnings misser |

**SBC Margin Adjustment:**
If stock-based compensation (SBC) > 10% of revenue, compute GAAP-equivalent operating margin = reported_operating_margin - SBC_pct.
- GAAP-equivalent < 20% AND reported > 30%: Fundamental -1. Note: "SBC INFLATION: Reported {X}% includes {Y}% SBC. GAAP-equivalent: {Z}%."
- GAAP-equivalent < 10%: Fundamental -2.
- SBC <= 10% of revenue: no adjustment.

**Earnings beat/miss modifier** (from `getEarningsReports`):
- Beats 7-8 of last 8 quarters: +1
- Misses 5+ of last 8 quarters: -1
- Large surprise magnitude (>10% beat/miss): additional +/-0.5

---

## Valuation Score (1-10) — Two-Track

**Growth detection:** Revenue growth >20% YoY OR P/E >40 = Track B (Growth). Otherwise Track A (Value).

### Track A (Value stocks — revenue growth <20%, P/E <40)

| Score | Criteria |
|-------|----------|
| 9-10 | Price <70% of DCF + below analyst low target + P/E below peer median |
| 7-8 | Price <90% of DCF + below analyst consensus + P/E near peer median |
| 5-6 | Price near DCF + near analyst consensus + P/E at peer median |
| 3-4 | Price >120% of DCF + above analyst consensus + P/E above peer median |
| 1-2 | Price >200% of DCF + above analyst high target + P/E >2x peer median |

### Track B (Growth stocks — revenue growth >20% OR P/E >40)

**PEG routing:**
- P/E > 0 AND revenue growth > 0: PEG = P/E / revenue growth rate (%)
- P/E is N/A (negative earnings) but sales growth > 0: PSG = Price/Sales / sales growth rate. Same thresholds as PEG
  - PSG is a ROUTING ALTERNATIVE when PEG is not calculable. When PEG IS calculable (P/E > 0 and growth > 0), PEG is the sole primary metric. PSG does NOT offset or modify a PEG-based score.
- Both earnings AND sales growth negative: Route back to Track A (broken growth story)
- P/E N/A AND revenue growth negative: Score = 1-2 automatically

| Score | Criteria |
|-------|----------|
| 9-10 | PEG <0.8 + below analyst consensus + revenue acceleration + beats >=6/8 quarters |
| 7-8 | PEG 0.8-1.2 + near analyst consensus + sustained high growth + beats >=4/8 |
| 5-6 | PEG 1.2-2.0 + at analyst consensus + growth decelerating |
| 3-4 | PEG 2.0-3.0 + above analyst consensus + growth slowing materially |
| 1-2 | PEG >3.0 OR broken growth story (negative earnings + negative sales growth) |

**Revenue vs EPS growth note:** This rubric uses revenue growth for PEG to avoid earnings manipulation and one-time items. However, for companies with rapid margin expansion (net margin doubling or more in 2 years), the revenue-based PEG will systematically undervalue the stock. In these cases, ALSO compute EPS-based PEG as a secondary check.

**EPS-PEG Divergence Adjustment (Scaled):**
When EPS PEG < 1.0 AND Revenue PEG > 2.0, compute DIVERGENCE_RATIO = Revenue_PEG / EPS_PEG:

| Divergence Ratio | Adjustment | Meaning |
|-----------------|------------|---------|
| >= 4.0 | +3 | Massive margin expansion (earnings growing 4x+ faster than revenue) |
| >= 3.0 | +2 | Strong margin expansion |
| >= 2.0 | +1 | Moderate margin expansion |
| < 2.0 | 0 | Minimal divergence |

**Guardrails:**
- Cap: Valuation score cannot exceed 7 via this adjustment alone
- If P/S > 40x: cap divergence adjustment at +2 maximum (premium valuation already extreme)
- Report both PEG values: "Revenue PEG: {X}, EPS PEG: {Y}, Divergence Ratio: {Z}"

**Track B earnings execution gate:** If stock misses earnings >=5/8 quarters, cap Track B Valuation at 5.

**DCF usage:**
- Track A: Average of standard DCF and levered DCF
- Track B: Use custom DCF (with real growth inputs). If custom DCF still undervalues significantly, PEG overrides
- Always report all 3 DCF values: "DCF range: $X (standard) / $Y (levered) / $Z (custom)"

---

## Sentiment Score (1-10)

| Score | Criteria |
|-------|----------|
| 9-10 | Reddit + Twitter/X + StockTwits all bullish + multi-agent BUY high confidence + positive news (NLP confirms) + recent upgrades |
| 7-8 | 2/3 social platforms bullish + multi-agent BUY + neutral-positive news + no downgrades |
| 5-6 | Mixed across platforms + multi-agent HOLD + news mixed or neutral |
| 3-4 | 2/3 social platforms bearish + multi-agent SELL + negative news (NLP confirms) + recent downgrades |
| 1-2 | All platforms bearish + multi-agent SELL high confidence + negative news cluster + multiple downgrades this week |

### Multi-Platform Methodology

| Platform | Source | Weight | Method |
|----------|--------|--------|--------|
| Reddit | `market_sentiment` | 0.30 | Direct % bullish. >60% = bullish, <40% = bearish |
| Twitter/X | `WebSearch` | 0.20 | Claude classifies top 5-10 results. Login walls → redistribute |
| StockTwits | `WebSearch` | 0.20 | Extract bull/bear ratio if available. Unavailable → redistribute |
| News NLP | `WebFetch` articles | 0.20 | Per-article: positive/negative/neutral + impact. Tier 1 (Reuters, Bloomberg, WSJ) = 1.0x, Tier 2 (CNBC, Yahoo) = 0.8x, Tier 3 (blogs) = 0.5x |
| Analyst events | `getStockGradeNews` | 0.10 | Upgrades +1, downgrades -1. This week = 2x, this month = 1x, older = 0.5x |

Weighted sentiment = sum(platform_score x weight). Bullish > +0.3, bearish < -0.3, else neutral.

**Divergence cap:** If platforms disagree strongly, cap Sentiment at 5 and note "SENTIMENT DIVERGENCE."

**Fallback:** If WebSearch returns unusable results for Twitter/StockTwits, redistribute weight to Reddit + News NLP.

---

## Smart Money Score (1-10)

| Score | Criteria |
|-------|----------|
| 9-10 | Net insider buying (>$1M) + congressional buying + institutional accumulation + bullish options flow (P/C <0.7 + positive net delta + unusual calls + rising call premiums) |
| 7-8 | 3/4 signals positive, OR insider buying >$5M (magnitude override), OR unusual call volume >10x OI |
| 5-6 | Mixed: some insider buying + selling, neutral institutional, P/C 0.7-1.0, no unusual activity |
| 3-4 | Net insider selling + institutional flat/declining + bearish options flow (P/C >1.0 + negative net delta + rising put premiums) |
| 1-2 | Heavy insider selling (>$10M) + congressional selling + institutional dumping + extreme P/C (>1.5) + unusual puts + negative IV skew |

**Insider magnitude weighting:**
- Buys >$1M from C-suite: boost +1
- Sales >$10M from multiple insiders: reduce -1
- **10b5-1 plan sales (CONFIRMED via SEC Form 4 footnotes):** Reduce severity by 1 tier. A confirmed 10b5-1 sale of $15M is less bearish than a discretionary $15M sale because plans are adopted months in advance.
- **Discretionary sales (no 10b5-1 plan):** Full severity. C-suite selling without a pre-arranged plan is a stronger signal.
- **Never assume 10b5-1 status.** FMP does not return this field. Always verify via WebSearch of the SEC Form 4 filing. Report as "confirmed 10b5-1 (adopted DATE)" or "discretionary" or "not verified."

**Conflict priority:**
1. Insider magnitude sets floor/ceiling: $15M+ buying → floor 6. $10M+ selling → ceiling 4
2. Options flow adjusts within range: bullish +1, bearish -1
3. Institutional + congressional confirm or moderate: aligned = no change, contradicting = pull 1 toward 5

**Insider-Institutional Divergence Resolution:**
- If ALL insider selling is confirmed 10b5-1: reduce insider signal weight to 30% (from 50%), increase institutional weight to 50% (from 30%). Planned sales are less informative.
- If institutional accumulation > 5% share increase: Smart Money floor = 5 (cannot go below). If also 10b5-1 confirmed: floor = 6.
- If institutional accumulation > 5% AND insider selling is DISCRETIONARY (not 10b5-1): Smart Money ceiling = 4. "INSIDER-INSTITUTIONAL CONFLICT: Discretionary insider selling while institutions accumulate. Insiders may have MNPI."

**Order book depth modifier** (from `depth_get`, Desktop only): bid depth > 2x ask = +1. Ask > 2x bid = -1.

---

## Macro Score (1-10)

| Score | Criteria |
|-------|----------|
| 9-10 | Sector ETF outperforming SPY YTD + falling/stable rates + VIX <15 + sector ETF above 200 SMA |
| 7-8 | Sector ETF inline with SPY + stable rates + VIX 15-20 + neutral trend |
| 5-6 | Sector ETF underperforming slightly + rising rates + VIX 20-25 |
| 3-4 | Sector ETF underperforming significantly + rapidly rising rates + VIX 25-30 |
| 1-2 | Sector ETF in freefall + yield curve inverting/steepening sharply + VIX >30 |

**VIX override:** VIX >30 = subtract 2 from Macro score (min 1).

**Sector ETF data cap:** If sector ETF data is unavailable (FMP 402 or no data), cap Macro at 6. The sector ETF trend is a critical Macro input — without it, cannot confirm 7-8 range.

---

## Backtest Score (1-10)

| Score | Criteria |
|-------|----------|
| 9-10 | Best strategy >50% win rate + >2.0 profit factor + >2.0 Sharpe + walk-forward validates + >=20 trades |
| 7-8 | Best strategy >40% win rate + >1.5 profit factor + >1.0 Sharpe + >=15 trades |
| 5-6 | Best strategy >30% win rate + >1.0 profit factor + positive return + >=10 trades |
| 3-4 | Best strategy breakeven or slight loss, low Sharpe |
| 1-2 | All strategies lose money, negative Sharpe |

**Minimum trade gate (tiered):**
- <5 trades: cap at 2
- 5-9 trades: cap at 4
- 10-14 trades: cap at 6
- 15+ trades: no cap

**Buy-and-hold benchmark (Revised):**
- B&H return > 100%: Penalty WAIVED. "B&H TREND OVERRIDE: Stock returned {X}%. No strategy captures this. Penalty waived."
- B&H return > 50% AND best strategy > 0: Penalty reduced to -1 (from -2).
- B&H return > 0% AND best strategy < 0: Full -2 penalty (strategy loses in rising market).
- B&H return < 0% AND best strategy > 0: BONUS +2 (strategy profits in falling market).

**Adaptive Backtest Weighting:**
When trade count is low or walk-forward robustness is poor, reduce the effective weight of the Backtest dimension and redistribute proportionally to other dimensions:

| Total Trades | Effective Weight | Redistributed |
|-------------|-----------------|---------------|
| < 5 | 2% | 8% to others |
| 5-9 | 5% | 5% to others |
| 10-14 | 8% | 2% to others |
| >= 15 | 10% (full) | 0% |

Walk-forward override: If walk_forward_robustness < 0.3 (OVERFITTED), HALVE the effective weight. Note: "BACKTEST OVERFITTED — robustness {X}. Weight halved."

Redistribution is proportional to remaining dimension weights.

**Desktop cross-validation:** If TV-Analysis and Desktop Strategy Tester diverge by >20%, cap at 5 + flag "OVERFIT WARNING."

---

## Risk Score (1-10) — INVERTED: 10 = lowest risk

| Score | Criteria |
|-------|----------|
| 9-10 | Beta <1.0 + RSI 40-60 + IV/HV <1.0 + no earnings within 14d + position <5% portfolio |
| 7-8 | Beta 1.0-1.5 + RSI not extreme + IV/HV 1.0-1.3 + no imminent events |
| 5-6 | Beta 1.5-2.0 + RSI approaching extreme OR earnings within 14d + IV/HV 1.3-1.5 |
| 3-4 | Beta >2.0 + RSI overbought/oversold + IV/HV >1.5 + earnings imminent |
| 1-2 | Extreme beta + RSI extreme + IV/HV >2.0 + expected move >10% + extended >30% from 50 SMA + heavy insider selling |

**Risk modifiers:**
- Bid/ask spread >2%: subtract 1. >5%: subtract 2
- Geographic concentration: single non-US country >60% revenue = -1. >80% = -2
- Corporate actions: upcoming reverse split or delisting risk = -2
- Minimum after modifiers: 1

---

## Overrides (applied AFTER composite, in order)

### 1. Overbought/Oversold Override (Graduated)
- RSI 75-80: subtract 5 from composite. "OVERBOUGHT — RSI {value}. Timing risk elevated."
- RSI 80-85: subtract 10. "OVERBOUGHT — RSI {value}. Strong timing risk."
- RSI > 85: cap at 55. "EXTREME OVERBOUGHT — RSI {value}. Do not enter."
- RSI 20-25: add 5 (LONG only). "OVERSOLD — RSI {value}. Potential snap-back."
- RSI < 20: add 10 (LONG only). "EXTREME OVERSOLD — RSI {value}. High snap-back probability."
- Oversold does NOT prevent SELL for existing positions.

### 2. VIX Panic Override (Beta-Conditional)
- VIX > 35 AND beta > 1.0 AND composite >= 60: Downgrade to HOLD. "VIX PANIC ({value}) — extreme fear for high-beta stocks."
- VIX > 35 AND beta <= 1.0: Warning only, no score change. "VIX elevated at {value}, but low beta ({beta}) provides protection."

### 3. Cross-Dimension Conflict Resolution
- Technical vs Fundamental diverge by >=5 points: subtract 3 from composite. Do NOT force HOLD.
- Risk <= 2 AND composite >= 60: Downgrade to HOLD. "HIGH RISK OVERRIDE."
- Data completeness <60%: Force HOLD. "LOW DATA: Only {X}% of phases returned data."
- Fewer than 5 of 8 dimensions scored: Force HOLD. "INSUFFICIENT DIMENSIONS."

### 5. Momentum Extension Override
- See "Momentum Extension Modifier" section for full rules.
- EXTREME (1M >= 60%): subtract 5. Does NOT stack with Override 1 — use larger penalty.
- HIGH (1M >= 30%): subtract 2. Does NOT stack with Override 1 — use larger penalty.
- Recovery stock exception: 6M negative + 1M positive → reduce category by one tier.
- IPO exception (<100 trading days): halve the penalty.
- **Fundamental-Catalyst Exception:** If Extension is EXTREME or HIGH AND any of these occurred in last 60 days: (a) major contract >10% of annual revenue, (b) >=3 analyst upgrades in 30 days, (c) revenue growth acceleration >5pp vs prior quarter, (d) major product launch or partnership — then reduce category by ONE tier (EXTREME→HIGH, HIGH→MEDIUM). Note: "EXTENSION CATALYST EXCEPTION: {catalyst}. Price move is fundamentally driven."

### 6. Earnings Catalyst Modifier
Triggers when earnings are within 7 calendar days.

**Step 1 — Compute Earnings Beat Probability (EBP):**
- Base: beat_history / total_quarters (e.g., 6/7 = 85.7%)
- If estimate revisions positive in last 30 days: +10%
- If avg surprise magnitude > 10%: +5%
- Cap at 95%

**Step 2 — Apply Modifier:**

| EBP | Modifier |
|-----|----------|
| >= 80% | +3 to composite |
| >= 65% | +1 to composite |
| < 50% | -2 from composite |
| < 30% | -4 from composite |

Note: "EARNINGS CATALYST: {date}. Beat probability: {EBP}%. History: {X}/{Y} beats, avg surprise {Z}%. Modifier: {+/-N}."

### 7. Sell-the-News Detector
Triggers when analyzing a stock within 2 trading days AFTER earnings report.

IF ALL conditions met:
- EPS beat > 10%
- Revenue beat > 3%
- Stock change post-earnings < -5%
- P/S > 30x OR P/E > 100x

THEN: subtract 5 from composite. "SELL-THE-NEWS: Beat on all metrics but stock down {X}% on extreme valuation. Further multiple compression likely."

Additional: If stock 6M return < -15% AND earnings beat: "Stock in distribution phase despite strong fundamentals."

---

## Pre-Earnings Weight Switching

When earnings are within 7 calendar days, the weight profile shifts to emphasize signals that predict post-earnings outcomes:

| Dimension | Normal Weight | Pre-Earnings Weight |
|-----------|:------------:|:-------------------:|
| Technical | 22% | 12% |
| Fundamental | 15% | 22% |
| Valuation | 15% | 12% |
| Sentiment | 7% | 20% |
| Smart Money | 13% | 13% |
| Macro | 6% | 8% |
| Risk | 12% | 10% |
| Backtest | 10% | 3% |

**Rationale:** Pre-earnings, Technical oscillators and Backtest results have near-zero predictive power for earnings gap moves. Fundamental strength (beat history, quality), Sentiment (analyst upgrades, social momentum), and Macro (sector tailwinds) are the strongest predictors.

Note: "PRE-EARNINGS WEIGHT SWITCH: Earnings in {N} days. Weights shifted to fundamental/sentiment emphasis."

---

## Quality-Timing Dual Score

In addition to the single composite score, compute and report two sub-scores:

**Quality Score** = (Fundamental × 0.30 + Valuation × 0.25 + Smart Money × 0.25 + Macro × 0.20) × 10
*"Should I own this stock?"*

**Timing Score** = (Technical × 0.35 + Risk × 0.25 + Sentiment × 0.20 + Backtest × 0.20) × 10
*"Should I buy it RIGHT NOW?"*

### Signal Matrix (supplementary — does NOT override composite signal)

| Quality | Timing | Guidance |
|---------|--------|----------|
| >= 60 | >= 60 | STRONG BUY — high quality + good entry |
| >= 60 | 40-59 | HOLD — quality play, wait for better entry |
| >= 60 | < 40 | HOLD — strong business, bad timing. DO NOT SELL. |
| 40-59 | >= 60 | CAUTIOUS BUY — mediocre business, good setup |
| 40-59 | < 40 | AVOID |
| < 40 | Any | SELL — weak business |

**Critical rule:** NEVER produce SELL when Quality >= 60 unless the stock is held and has hit stop loss. High-quality businesses with bad timing are HOLDs, not SELLs.

---

## Momentum Extension Modifier

**Purpose:** Penalize stocks with extreme recent run-ups where chasing the move carries elevated mean-reversion risk. This captures the *magnitude* of recent moves — something RSI and SMA50 extension only partially reflect.

**Data source:** `FMP: getStockPriceChange` — use 1M and 3M percentage changes.

### Extension Risk Categories

| Category | Criteria | Composite Modifier |
|----------|----------|-------------------|
| **EXTREME** | 1M >= 60% OR (1M >= 40% AND 3M >= 90%) | Subtract 5 from composite |
| **HIGH** | 1M >= 30% OR (1M >= 20% AND 3M >= 60%) | Subtract 2 from composite |
| **MEDIUM** | 1M >= 15% OR 3M >= 30% | No modifier (already captured in Risk dimension) |
| **LOW** | 1M < 15% AND 3M < 30% | No modifier |

### Application Rules

1. **Applied as Override 5** — after all other overrides (Overbought, VIX, Cross-Dimension, R:R)
2. **Does NOT stack with Overbought override** — if Override 1 (RSI overbought) already applied a penalty, use the LARGER of the two penalties, not both. Rationale: RSI overbought and momentum extension are correlated signals measuring the same underlying risk.
3. **Minimum composite after extension penalty: 25** — never push a stock below STRONG SELL floor
4. **IPO exception:** Stocks with <100 trading days — reduce extension penalty by half (rounded down). New stocks have naturally volatile price action that doesn't carry the same mean-reversion implication.
5. **Recovery stocks exception:** If 6M return is negative AND 1M is positive (bounce from drawdown), reduce category by one tier. A stock recovering from -40% that bounces +35% in a month is not "extended" in the same way as one on a sustained uptrend.

### Extension Risk in Warnings

Always include extension risk category in the Warnings table:

| Category | Severity | Warning Text |
|----------|----------|-------------|
| EXTREME | !!! | EXTREME EXTENSION: +{1M}% in 1M, +{3M}% in 3M. Mean reversion highly likely. Wait for consolidation. |
| HIGH | !! | HIGH EXTENSION: +{1M}% in 1M, +{3M}% in 3M. Elevated pullback risk. |
| MEDIUM | ! | MODERATE EXTENSION: +{1M}% in 1M. Monitor for consolidation. |
| LOW | — | (no warning) |

### Scoring Justification

In the composite calculation section, add a line showing the extension modifier:
```
Extension: {CATEGORY} (1M: +{X}%, 3M: +{Y}%) → modifier: {-5, -2, or 0}
```

---

## Decision Thresholds

| Composite | Signal | Action |
|-----------|--------|--------|
| >= 75 | STRONG BUY | Aggressive sizing (up to 2x normal) |
| 60-74 | BUY | Standard sizing |
| 40-59 | HOLD | No new position |
| 25-39 | SELL | Reduce/exit position |
| < 25 | STRONG SELL | Exit immediately |
