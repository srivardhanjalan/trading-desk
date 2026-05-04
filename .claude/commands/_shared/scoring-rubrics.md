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

---

## Fundamental Score (1-10)

| Score | Criteria |
|-------|----------|
| 9-10 | Piotroski >=8 + Z-Score >3 + revenue growing >20% YoY + margins expanding + positive growing FCF + beats earnings >=6/8 quarters |
| 7-8 | Piotroski 6-7 + Z-Score >3 + revenue growing >10% + stable/expanding margins + beats >=4/8 quarters |
| 5-6 | Piotroski 4-5 + Z-Score 1.8-3 + revenue flat or <10% growth + mixed beat/miss history |
| 3-4 | Piotroski 2-3 + Z-Score 1.1-1.8 (grey zone) + declining revenue or margins + misses >=4/8 quarters |
| 1-2 | Piotroski 0-1 + Z-Score <1.1 (distress) + negative FCF + shrinking revenue + serial earnings misser |

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
- Both earnings AND sales growth negative: Route back to Track A (broken growth story)
- P/E N/A AND revenue growth negative: Score = 1-2 automatically

| Score | Criteria |
|-------|----------|
| 9-10 | PEG <0.8 + below analyst consensus + revenue acceleration + beats >=6/8 quarters |
| 7-8 | PEG 0.8-1.2 + near analyst consensus + sustained high growth + beats >=4/8 |
| 5-6 | PEG 1.2-2.0 + at analyst consensus + growth decelerating |
| 3-4 | PEG 2.0-3.0 + above analyst consensus + growth slowing materially |
| 1-2 | PEG >3.0 OR broken growth story (negative earnings + negative sales growth) |

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

**Buy-and-hold benchmark:** If best strategy < buy-and-hold, subtract 2 (min 1).

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
- Technical vs Fundamental diverge by >5 points: subtract 3 from composite. Do NOT force HOLD.
- Risk <= 2 AND composite >= 60: Downgrade to HOLD. "HIGH RISK OVERRIDE."
- Data completeness <60%: Force HOLD. "LOW DATA: Only {X}% of phases returned data."
- Fewer than 5 of 8 dimensions scored: Force HOLD. "INSUFFICIENT DIMENSIONS."

---

## Decision Thresholds

| Composite | Signal | Action |
|-----------|--------|--------|
| >= 75 | STRONG BUY | Aggressive sizing (up to 2x normal) |
| 60-74 | BUY | Standard sizing |
| 40-59 | HOLD | No new position |
| 25-39 | SELL | Reduce/exit position |
| < 25 | STRONG SELL | Exit immediately |
