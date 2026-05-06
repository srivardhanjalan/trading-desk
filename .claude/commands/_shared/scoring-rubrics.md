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

**FMP Technical Cross-Validation (Always-On):**
FMP technical indicators (getRSI, getSMA, getEMA, getADX) are ALWAYS fetched alongside TradingView data — not just as fallback. Cross-validate:
- If TV RSI and FMP RSI diverge by >10 points: flag "RSI DATA DIVERGENCE: TV={X}, FMP={Y}. Using average." Use the average for scoring.
- If TV and FMP agree within 5 points: high confidence. Note the confirmation.
- FMP provides DEMA, TEMA, WMA, Williams %R as additional confirmation signals (see below).

**Additional Technical Indicators (from FMP):**
- DEMA (Double EMA): faster trend detection than SMA/EMA. DEMA crossover above price = bullish confirmation.
- TEMA (Triple EMA): even more responsive. TEMA divergence from price = early momentum shift warning.
- WMA (Weighted MA): emphasizes recent price action. WMA slope direction confirms trend.
- Williams %R: overbought/oversold oscillator. Williams < -80 = oversold (bullish), > -20 = overbought (bearish). Confirms RSI when both agree. When Williams and RSI disagree, flag "OSCILLATOR DIVERGENCE" and use the more conservative reading.

**Regime Detection (ADX-Based):**
Classify market regime BEFORE interpreting technical indicators:
- Use 60-day ADX average (from FMP getADX with longer lookback):
  - ADX avg > 25: TRENDING regime — suppress mean-reversion signals (RSI overbought is less penalizing, Bollinger band touches are trend continuation)
  - ADX avg 18-25: TRANSITIONAL regime — standard interpretation
  - ADX avg < 18: MEAN-REVERTING regime — amplify mean-reversion signals (RSI overbought = exhaustion, Bollinger touches = reversal)
- Cross-reference with Bollinger Band Width percentile (from bollinger_scan):
  - Width at 6-month minimum = compression before breakout. In trending regime: breakout likely continues trend. In mean-reverting: breakout may fail.
- Log: "REGIME: {TRENDING/TRANSITIONAL/MEAN-REVERTING} (ADX avg {X}, BB width {percentile}%ile)."
- Regime affects Override 1 interpretation: in TRENDING regime, reduce RSI overbought penalty by additional 0.3x multiplier.

---

## Fundamental Score (1-10)

| Score | Criteria |
|-------|----------|
| 9-10 | Piotroski >=7 AND meets >=5 of 6 other criteria (Z-Score >3 + revenue growing >20% YoY + margins expanding + positive growing FCF + beats >=6/8 quarters + cash flow growth positive) |
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
- **Minimum data rule:** If fewer than 6 of 8 quarters available, do NOT apply beat/miss modifier. Note: "INSUFFICIENT EARNINGS DATA: {X}/8 quarters."
- Beats 7-8 of last 8 quarters: +1
- Misses 5+ of last 8 quarters: -1
- Large surprise magnitude (>10% beat/miss): additional +/-0.5

**Economic Moat Assessment Modifier:**
Computed from data in `{SYMBOL}_fundamental.md` "Economic Moat" section:
- **Margin premium vs peers:** If operating margin > 1.5x sector median: +1 (pricing power).
- **Revenue concentration:** If top customer >30% revenue OR top 3 >60%: -1 (concentration risk).
- **Recurring revenue proxy:** If subscription/recurring revenue >60% of total: +1 (predictability).
- **Capital allocation quality:** FCF yield >5% AND buyback yield >2% AND dividend coverage >2x: +1. Negative FCF + rising debt: -1.
- Net moat modifier range: [-2, +2]. Apply AFTER base Fundamental score. Cap Fundamental at 10.
- Note: "MOAT: {WIDE/NARROW/NONE} (margin premium {X}x, revenue concentration {Y}%, recurring {Z}%, capital alloc {quality}). Modifier: {+/-N}."

**Financial Statement Forensics Modifier:**
Computed from data in `{SYMBOL}_fundamental.md` "Financial Statement Forensics" section:
- **Beneish M-Score > -1.78:** Fundamental -2. "FORENSICS WARNING: Beneish M-Score {X} indicates elevated earnings manipulation risk."
- **Beneish M-Score -1.78 to -2.22:** Fundamental -1. "FORENSICS CAUTION: Beneish M-Score {X} in grey zone."
- **Beneish M-Score < -2.22:** No penalty. Clean signal.
- **Accruals ratio > 10%:** Additional -1. "HIGH ACCRUALS: {X}% — earnings quality concern."
- **Receivables/Revenue ratio increasing >5pp YoY:** Additional -0.5. "RECEIVABLES GROWING: may indicate channel stuffing."
- **Inventory/Revenue ratio increasing >5pp YoY:** Additional -0.5. "INVENTORY BUILDING: may indicate demand softening."
- Net forensics modifier range: [-3, 0]. This is always non-positive (forensics can only flag problems, not confirm quality).
- If forensics data is unavailable (pre-revenue company, REIT, etc.): skip modifier. Note: "FORENSICS N/A: {reason}."

---

## Valuation Score (1-10) — Two-Track

**Growth detection:** Revenue growth >20% YoY OR (P/E >40 AND revenue growth >15%) = Track B (Growth). If P/E >40 but growth <15%, evaluate on BOTH tracks and use the higher score. Log: "DUAL-TRACK EVALUATION: Track A={X}, Track B={Y}." Add EPS-acceleration trigger: trailing EPS growth >100% YoY = eligible for Track B evaluation (dual-track). Otherwise Track A (Value).

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

**PEG Growth Rate Definition (MANDATORY):**
- Use FY YoY revenue growth as base. If FY ended >6 months ago, use TTM instead.
- Apply 0.7x decay factor for growth >80% (extreme growth rates are less sustainable).
- Always compute BOTH trailing PEG and forward PEG (using forward consensus estimates); use the more conservative (higher) PEG for scoring. Report both: "Trailing PEG: {X}, Forward PEG: {Y}."
- If trailing and forward PEG diverge >2x, note "PEG DIVERGENCE: trailing {X} vs forward {Y} — using {higher}."

| Score | Criteria |
|-------|----------|
| 9-10 | PEG <0.8 + below analyst consensus + revenue acceleration + beats >=6/8 quarters |
| 7-8 | PEG in [0.8, 1.2) + near analyst consensus + sustained high growth + beats >=4/8 |
| 5-6 | PEG in [1.2, 2.0) + at analyst consensus + growth decelerating |
| 3-4 | PEG in [2.0, 3.0] + above analyst consensus + growth slowing materially |
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
- P/S graduated cap (see "P/S Guardrail" under DCF usage): <=25x allows +3, 25-35x caps at +2, 35-50x caps at +1, >50x caps at +0
- Report both PEG values: "Revenue PEG: {X}, EPS PEG: {Y}, Divergence Ratio: {Z}"

**Track B earnings execution gate:** If stock misses earnings >=5/8 quarters, cap Track B Valuation at 5.

**DCF usage:**
- Track A: Weighted average of standard DCF and levered DCF. When divergence >50%, weight 70% levered / 30% standard. If sign conflict (one negative, one positive), discard the negative model with -1 Valuation penalty.
- Track B: Use custom DCF (with real growth inputs). If custom DCF still undervalues significantly, PEG overrides.
- **Custom DCF validation:** If custom DCF per-share value > 10x current price OR < 0: discard with note "CUSTOM DCF INVALID — using standard/levered only." Hard cap growth input at 60%.
- **Negative DCF handling:** When BOTH standard and levered DCF are negative, exclude DCF entirely. Route to peer multiples + analyst targets only. Note: "DCF N/A — negative intrinsic value (pre-profit company)."
- Always report all 3 DCF values: "DCF range: $X (standard) / $Y (levered) / $Z (custom)"
- **Analyst target staleness:** Require targets within 6 months. Minimum analyst counts: large cap (>$10B) >= 5, mid ($2-10B) >= 3, small (<$2B) >= 2. Fewer analysts = cap analyst-based Valuation at 6.

**Industry P/E Relative Modifier:**
- Stock P/E < 0.5x industry P/E (from `getIndustryPESnapshot`): Valuation +1
- Stock P/E > 2.0x industry P/E: Valuation -1
- For Track B: if stock PEG within 1.0x of industry median PEG, reduce PEG penalty by one tier.

**P/S Guardrail (Graduated):**
- P/S <= 25x: EPS-PEG divergence adjustment allows up to +3
- P/S 25-35x: cap divergence adjustment at +2
- P/S 35-50x: cap divergence adjustment at +1
- P/S > 50x: cap divergence adjustment at +0

**Bear-Case DCF Stress Test:**
From `{SYMBOL}_fundamental.md` "Stress Test & Implied Value" section:
- Bear-case DCF uses 50% of consensus growth rate and industry-average margins.
- **Margin of safety** = (avg_DCF - current_price) / avg_DCF × 100. Where avg_DCF = average of standard, levered, and custom DCF (excluding invalids).
  - Margin of safety > 30%: Valuation +1. "MARGIN OF SAFETY: {X}% — significant undervaluation."
  - Margin of safety 10-30%: No modifier. "MARGIN OF SAFETY: {X}% — moderate."
  - Margin of safety < 0% (overvalued): Valuation -1. "NEGATIVE MARGIN OF SAFETY: {X}% — price exceeds intrinsic value."
  - Bear-case still shows upside: Valuation +1 additional. "BEAR-CASE UPSIDE: Even under stress, DCF > price."
- **Implied growth rate** = reverse-engineered growth rate that justifies current price. Compare to consensus:
  - Implied growth > 2x consensus growth: Valuation -1. "PRICED FOR PERFECTION: Market implies {X}% growth vs {Y}% consensus."
  - Implied growth < 0.5x consensus growth: Valuation +1. "GROWTH DISCOUNT: Market implies only {X}% growth vs {Y}% consensus."
- **TAM analysis (Track B only):** From fundamental report TAM section. If current revenue < 5% of addressable market: note "TAM RUNWAY: {X}% penetration — long runway supports growth premium."

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
| Reddit | `market_sentiment` | 0.30 | Direct % bullish. >60% = bullish, <40% = bearish. If <10 on-topic posts, halve to 0.15 and redistribute to News NLP. |
| Twitter/X | `WebSearch` | 0.10 | Claude classifies top 5-10 results. **Second-hand data** — label as "via news reports." Login walls → redistribute. |
| StockTwits | `WebSearch` | 0.10 | Extract bull/bear ratio if available. **Second-hand data.** Unavailable → redistribute. |
| News NLP | `WebFetch` articles | 0.30 | Per-article: positive/negative/neutral + impact. Tier 1 (Reuters, Bloomberg, WSJ) = 1.0x, Tier 2 (CNBC, Yahoo) = 0.8x, Tier 3 (blogs) = 0.5x. **Paywall discount:** 3+ articles fetched = full 0.30 weight. 2 fetched = 0.25. 1 fetched = 0.15. 0 fetched = 0.10 floor. Cap Sentiment at 6 when >50% articles are headline-only. |
| Analyst events | `getStockGradeNews` | 0.20 | Upgrades +1, downgrades -1. This week = 2x, this month = 1x, older = 0.5x. **Acceleration detection:** 3+ upgrades in 2 weeks = additional +1. 3+ downgrades in 2 weeks = additional -1. |

Weighted sentiment = sum(platform_score x weight). Bullish > +0.3, bearish < -0.3, else neutral.

**Divergence cap:** If platforms disagree strongly, cap Sentiment at 5 and note "SENTIMENT DIVERGENCE."

**Fallback:** If WebSearch returns unusable results for Twitter/StockTwits, redistribute weight to Reddit + News NLP.

**Consensus Crowding Indicator:**
When >80% of all sentiment sources (Reddit + Twitter + StockTwits + analyst consensus) agree on direction:
- >80% bullish: Sentiment cap at 7. "CONSENSUS CROWDING: {X}% bullish. Contrarian risk — crowded trades unwind violently."
- >80% bearish: Sentiment floor at 4. "CONSENSUS CROWDING: {X}% bearish. Contrarian signal — extreme pessimism may be overdone."
- This is a CONTRARIAN signal: unanimous agreement often precedes reversals.
- Exception: if the stock has strong fundamental momentum (Fundamental >= 8 AND earnings beat 7+/8), suppress the bullish crowding cap. Real quality sometimes deserves consensus.

**Market-Cap-Scaled Sentiment Weights:**
Adjust platform weights based on market cap to reflect information efficiency:

| Platform | Large Cap (>$50B) | Mid Cap ($5-50B) | Small Cap (<$5B) |
|----------|:--:|:--:|:--:|
| Reddit | 0.15 | 0.30 | 0.35 |
| Twitter/X | 0.05 | 0.10 | 0.10 |
| StockTwits | 0.05 | 0.10 | 0.15 |
| News NLP | 0.40 | 0.30 | 0.25 |
| Analyst events | 0.35 | 0.20 | 0.15 |

Rationale: Large-cap stocks have more institutional coverage and better news flow; social media adds noise. Small-cap stocks have sparse analyst coverage; social media and retail sentiment are more informative.

---

## Smart Money Score (1-10)

| Score | Criteria |
|-------|----------|
| 9-10 | Net insider buying (>$1M) + congressional buying + institutional accumulation + bullish options flow (P/C <0.7 + positive net delta + unusual calls + rising call premiums) |
| 7-8 | 3/4 signals positive, OR insider buying >$5M (magnitude override), OR unusual call volume >10x OI |
| 5-6 | Mixed: some insider buying + selling, neutral institutional, P/C 0.7-1.0, no unusual activity |
| 3-4 | Net insider selling + institutional flat/declining + bearish options flow (P/C >1.0 + negative net delta + rising put premiums) |
| 1-2 | Heavy insider selling (>$10M) + congressional selling + institutional dumping + extreme P/C (>1.5) + unusual puts + negative IV skew |

**Insider magnitude weighting (market-cap relative):**
- C-suite buys >$1M OR >0.5% of market cap (whichever is lower for companies <$5B): boost +1
- Sales >$10M from multiple insiders OR >1% of market cap: reduce -1
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

**No-options-market fallback:** When no options market exists (common for small-caps/OTC), redistribute options flow weight to insider + institutional signals. Note: "OPTIONS N/A — Smart Money scored from insider/institutional only." Do not penalize for absence of options data.

**P/C ratio earnings adjustment:** Shift bearish threshold to >1.5 (from >1.0) when earnings are within 7 days. Cross-reference 13F data: if institutions are simultaneously adding shares AND buying puts, classify as "protective hedging" (neutral), not bearish.

**Smart Money quality gate:** Cap Smart Money at 6 when Fundamental <= 3. Note: "SMART MONEY QUALITY GATE: institutional flow into distressed company may be speculative."

**13F institutional data staleness weighting:** 13F filings have a 45-day lag. Weight institutional signals by data age:
- Data age <= 60 days: 1.0x weight
- Data age 61-90 days: 0.7x weight
- Data age 91-120 days: 0.5x weight
- Data age > 120 days: 0.3x weight (note "STALE 13F — {N} days old")

**Fund Quality Weighting:**
Not all institutional accumulation is equal. Cross-reference fund performance:
- If top-alpha funds (e.g., funds with 3Y+ track record of >15% CAGR) are accumulating: Smart Money +1. "FUND QUALITY: Top-performing funds adding shares."
- If primarily index funds / passive ETFs accumulating: no modifier (forced buying, not conviction).
- If activist funds taking >5% stake (from 13F or WebSearch): Smart Money +2, floor at 7. "ACTIVIST INVOLVEMENT: {fund name} acquired {X}% stake."
- Data source: `getFilingExtractAnalyticsByHolder` + `getHolderPerformanceSummary` from fundamental report.

**Dark Pool Activity Proxy:**
From `{SYMBOL}_sentiment.md` "Dark Pool & Alternative Data" section:
- If FINRA ATS data shows unusual dark pool volume (>2x 20-day average): Smart Money +1. "DARK POOL ACTIVITY: {X}x normal ATS volume — possible institutional accumulation."
- If dark pool volume declining while public volume rising: Smart Money -1. "DARK POOL EXIT: Institutions moving to lit exchanges — possible distribution."
- If dark pool data unavailable: no modifier. Note: "DARK POOL: N/A."

---

## Macro Score (1-10)

| Score | Criteria |
|-------|----------|
| 9-10 | Sector ETF outperforming SPY YTD + falling/stable rates + VIX <15 + sector ETF above 200 SMA |
| 7-8 | Sector ETF inline with SPY + stable rates + VIX 15-20 + neutral trend |
| 5-6 | Sector ETF underperforming slightly + rising rates + VIX 20-25 |
| 3-4 | Sector ETF underperforming significantly + rapidly rising rates + VIX 25-30 |
| 1-2 | Sector ETF in freefall + yield curve inverting/steepening sharply + VIX >30 |

**VIX override (graduated):**
- VIX 25-30: subtract 1 from Macro for stocks with beta > 1.5 only.
- VIX 30-35: subtract 2 from Macro for stocks with beta > 1.0.
- VIX > 35: subtract 2 from Macro for ALL stocks (min 1). Add VIX velocity rule: if VIX rose >5 pts in 1 week, additional -1 regardless of level.

**Sector ETF data cap:** If sector ETF data is unavailable (FMP 402 or no data), cap Macro at 5 (not 6). Use `getSectorPerformanceSnapshot` or stock-vs-SPY relative performance as fallback.

**Yield curve detection:**
- Inverted (2Y > 10Y): already scored in 3-4 range.
- Flat (2Y-10Y spread 0-25bps): Macro -1.
- Also check curve direction: bull vs bear steepening matters for sector rotation.

**Per-stock Macro Sensitivity Multiplier (applied after base sector score):**
- Beta > 1.5: Macro -1
- Beta < 0.7: Macro +1
- International revenue >60% in rate-sensitive sector: Macro -1
- D/E > 2.0 during rising rate environment (10Y up >50bps in 3 months): Macro -1

**Economic calendar scoring rules:**
- FOMC decision within 3 trading days: Macro -1
- CPI release within 3 trading days + beta > 1.5: Macro -1
- Two or more major events in same week: Macro -2
- Note: "MACRO EVENT: {event} on {date}. Volatility amplified."

**Global Macro Indicators (from fundamental report):**
Incorporate commodities, currency, and economic data from `{SYMBOL}_fundamental.md`:
- **Copper/Gold ratio** (from getCommodityQuotes): Rising = reflation (bullish cyclicals). Falling = deflation fear (bearish cyclicals, bullish gold miners).
- **Oil price** (from getCommodityQuotes): >$90/bbl = energy sector +1, consumer discretionary -1. <$50/bbl = energy -1, consumer +1.
- **DXY / USD strength** (from getForexQuote USDX): Rising DXY = headwind for multinationals (international revenue >40%: Macro -1). Falling DXY = tailwind for multinationals (+1).
- **GDP growth** (from getEconomicIndicators): <1% = recession risk, Macro -1 for all cyclicals. >3% = expansion, Macro +1 for cyclicals.
- **CPI trend** (from getEconomicIndicators): Accelerating inflation = Macro -1 for growth stocks (rate hike risk). Decelerating = +1 for growth.
- **COT data** (from getCOTAnalysis): If commercial hedgers net long in sector-related commodity = bullish signal for sector. If net short = bearish.

**Macro Regime Classification:**
Combine GDP + CPI trends into regime quadrants:

| GDP ↑ / CPI ↓ | GDP ↑ / CPI ↑ | GDP ↓ / CPI ↑ | GDP ↓ / CPI ↓ |
|:--:|:--:|:--:|:--:|
| **GOLDILOCKS** | **REFLATION** | **STAGFLATION** | **DEFLATION** |
| Growth + Tech +1 | Commodities + Banks +1 | Energy + Utilities +1 | Bonds + Defensive +1 |
| Macro base 7-8 | Macro base 6-7 | Macro base 3-4 | Macro base 4-5 |

- Log: "MACRO REGIME: {GOLDILOCKS/REFLATION/STAGFLATION/DEFLATION}. GDP trend: {X}%, CPI trend: {Y}%."
- Regime provides the BASE Macro score; sector ETF performance and per-stock multipliers then adjust from there.

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
- <3 trades: score = 5 (neutral), weight = 0%. Remove from composite entirely. "BACKTEST N/A: insufficient trades ({N})."
- 3-4 trades: cap at 3, weight = 1%
- 5-9 trades: cap at 4
- 10-14 trades: cap at 6
- 15+ trades: no cap

**Buy-and-hold benchmark (Revised):**
- B&H return > 100%: Penalty WAIVED. "B&H TREND OVERRIDE: Stock returned {X}%. No strategy captures this. Penalty waived." **CHECK THIS FIRST — do not compute penalty before checking.**
- B&H return > 50% AND best strategy > 0: Penalty reduced to -1 (from -2). If strategy captures >70% of B&H return, reduce to -0 (capture ratio).
- B&H return >= 0% AND best strategy < 0: Full -2 penalty (strategy loses in rising market).
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

**Statistical Significance Test (t-test):**
For backtests with >= 10 trades, compute:
- Mean return per trade (μ) and standard deviation (σ)
- t-statistic = μ / (σ / √n), where n = number of trades
- **t > 2.0 (p < 0.05):** Results are statistically significant. Full Backtest score applies. "BACKTEST SIGNIFICANCE: t={X}, p<0.05. Results reliable."
- **t 1.5-2.0:** Marginal significance. Cap Backtest at 7. "BACKTEST MARGINAL: t={X}. Results suggestive but not conclusive."
- **t < 1.5:** Not significant. Cap Backtest at 5. "BACKTEST INSIGNIFICANT: t={X}. Results may be due to chance."
- For < 10 trades: t-test not applicable. Use trade count gate instead.
- Note: This test prevents high scores from a few lucky trades. A strategy with 80% win rate on 5 trades is less convincing than 55% on 50 trades.

---

## Risk Score (1-10) — INVERTED: 10 = lowest risk (safest)

| Score | Criteria |
|-------|----------|
| 9-10 | Beta <1.0 + RSI 40-60 + IV/HV <1.0 + no earnings within 14d + position <5% portfolio |
| 7-8 | Beta 1.0-1.5 + RSI not extreme + IV/HV 1.0-1.3 + no imminent events |
| 5-6 | Beta 1.5-2.0 + RSI approaching extreme OR earnings within 14d + IV/HV 1.3-1.5 |
| 3-4 | Beta >2.0 + RSI overbought/oversold + IV/HV >1.5 + earnings imminent |
| 1-2 | Extreme beta + RSI extreme + IV/HV >2.0 + expected move >10% + extended >30% from 50 SMA + heavy insider selling |

**ADX-Conditional RSI in Risk (anti-stacking with Override 1):**
- When ADX > 35 with +DI > 2x -DI: RSI overbought does NOT contribute to Risk 3-4 classification. It is already penalized via Override 1. Note: "RSI overbought excluded from Risk — ADX trend-confirmed."
- When Override 1 (overbought) is active: do NOT additionally penalize RSI in Risk base score. This prevents triple-counting (Technical + Risk + Override 1).

**Anti-stacking with Override 5 (Extension):**
- When Override 5 applies: do NOT additionally penalize for "extended >30% from 50 SMA" in Risk base score. Override 5 is the calibrated measure.

**Anti-stacking with Smart Money (insider selling):**
- When Smart Money <= 3 due to insider selling: do NOT additionally penalize insider selling in Risk. Same signal should not penalize across two dimensions.

**Earnings proximity ADX gate:**
- When EBP (Earnings Beat Probability) >= 80%: do NOT penalize below Risk 6 for earnings proximity alone. Serial beaters have lower earnings risk.

**IV/HV earnings proximity scaling:**
- IV/HV threshold scales by days-to-earnings: >21d use 1.5, 14-21d use 2.0, 7-14d use 2.5, <7d use 3.0. IV spikes structurally before earnings; using a flat 1.5 threshold unfairly penalizes.

**Beta thresholds adjusted by market cap:**
- >$10B: current thresholds (Beta >2.0 = Risk 3-4)
- $1B-$10B: threshold at Beta 2.5
- <$1B: threshold at Beta 3.0
- If P/B < 1.0 AND cash > stock price: override beta penalty entirely (trading below liquidation value)

**Risk modifiers:**
- Bid/ask spread >2%: subtract 1. >5%: subtract 2. **Only applies when measured during regular market hours.** After-hours spreads are structurally wide and uninformative.
- Geographic concentration: single non-US country >60% revenue = -1. >80% = -2. US >90% revenue = -0.5 (domestic concentration risk).
- Corporate actions: upcoming reverse split or delisting risk = -2
- Minimum after modifiers: 1

---

## Overrides (applied AFTER composite, in order)

### 1. Overbought/Oversold Override (Graduated)
- RSI in [75, 80): subtract 5 from composite. "OVERBOUGHT — RSI {value}. Timing risk elevated."
- RSI in [80, 85): subtract 10. "OVERBOUGHT — RSI {value}. Strong timing risk."
- RSI >= 85: cap at 55. "EXTREME OVERBOUGHT — RSI {value}. Do not enter."
- RSI in (20, 25]: add 5 (LONG only). "OVERSOLD — RSI {value}. Potential snap-back."
- RSI <= 20: add 10 (LONG only). "EXTREME OVERSOLD — RSI {value}. High snap-back probability."
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
- EXTREME (1M >= 80%): subtract 5.
- SEVERE (1M in [60%, 80%)): subtract 4.
- HIGH (1M in [45%, 60%)): subtract 3.
- MODERATE (1M in [30%, 45%)): subtract 2.
- LOW (1M < 30%): no modifier.
- **Combined penalty formula with Override 1:** When BOTH Override 1 (RSI overbought) and Override 5 (Extension) fire, compute: `combined = max(O1, O5) + 0.3 × min(O1, O5)` (rounded to nearest integer). Apply ADX multiplier to Override 1 penalty BEFORE comparison. This replaces the old "use the larger penalty" rule which made the Catalyst Exception and ADX fix architecturally dead.
- Recovery stock exception: 6M negative + 1M positive → reduce category by one tier. **Expanded trigger:** Also applies when 6M < +5% AND 1M > 6x abs(6M change).
- IPO exception (<100 trading days): halve the penalty.
- **Market cap scaling:** Multiply extension thresholds by market cap factor: >$100B = 1.0x (current), $10-100B = 1.2x, $2-10B = 1.5x, <$2B = 2.0x. Example: EXTREME for a <$2B stock requires 1M >= 160% instead of 80%.
- **Fundamental-Catalyst Exception:** If Extension is EXTREME/SEVERE/HIGH AND any of these occurred in last 60 days: (a) major contract >10% of annual revenue, (b) >=3 analyst upgrades in 30 days, (c) revenue growth acceleration >5pp vs prior quarter, (d) major product launch or partnership — then reduce category by ONE tier. Allow -2 tiers for 3+ catalysts from distinct categories (cap reduction at MODERATE). Note: "EXTENSION CATALYST EXCEPTION: {catalyst}. Price move is fundamentally driven."

### 6. Earnings Catalyst Modifier
Triggers when earnings are within 7 calendar days.

**Step 1 — Compute Earnings Beat Probability (EBP):**
- Base: beat_history / total_quarters (e.g., 6/7 = 85.7%)
- If estimate revisions positive in last 30 days: +10%
- If avg surprise magnitude > 10%: +5%
- Cap at 95%

**Minimum quarter gate:**
- <2 quarters of data: EBP not calculable, no modifier applied. Note: "EBP N/A: insufficient history."
- 2-3 quarters: halve the modifier (round toward zero).
- >=4 quarters: full modifier.

**Step 2 — Apply Modifier:**

| EBP | Modifier |
|-----|----------|
| >= 80% | +3 to composite |
| >= 65% | +1 to composite |
| [50%, 65%) | No modifier (neutral zone) |
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

### 8. Multi-Agent Consensus Override
From `multi_agent_analysis` (3-agent debate: Technical + Sentiment + Risk Manager):
- Unanimous SELL (net score <= -4): subtract 3 from composite. "MULTI-AGENT SELL: All agents bearish (net {score})."
- Unanimous BUY (net score >= +4): add 2 to composite. "MULTI-AGENT BUY: All agents bullish (net {score})."
- If `multi_agent_analysis` tool failed or returned no data: skip override, note "MULTI-AGENT: unavailable."

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

**Quality Score** = (Fundamental × 0.30 + Valuation × 0.25 + Smart Money (insiders+institutional+congressional only) × 0.25 + Macro × 0.20) × 10
*"Should I own this stock?"*

**Timing Score** = (Technical × 0.30 + Risk × 0.25 + Sentiment × 0.20 + Backtest × 0.15 + Options Flow × 0.10) × 10
*"Should I buy it RIGHT NOW?"*

**Options flow reclassification:** For Quality-Timing computation, Smart Money is split:
- Quality component = insiders + institutional + congressional signals (Smart Money base without options)
- Timing component = options flow metrics (P/C ratio, unusual activity, IV skew, net delta)
The composite 8-dimension score still uses unified Smart Money. Only the Q-T split separates them.

### Signal Matrix (supplementary — does NOT override composite signal)

| Quality | Timing | Guidance |
|---------|--------|----------|
| >= 60 | >= 60 | STRONG BUY — high quality + good entry |
| >= 60 | 40-59 | HOLD — quality play, wait for better entry |
| >= 60 | < 40 | HOLD — strong business, bad timing. DO NOT SELL. |
| 40-59 | >= 60 | CAUTIOUS BUY — mediocre business, good setup |
| 40-59 | 40-59 | HOLD — follow composite signal |
| 40-59 | < 40 | AVOID |
| < 40 | Any | SELL — weak business |

**Quality Floor rule (with dimension gate):**
NEVER produce SELL when Quality >= 60 unless the stock is held and has hit stop loss. High-quality businesses with bad timing are HOLDs, not SELLs.

**Dimension gate (REQUIRED):** Quality Floor fires ONLY if ALL Quality sub-dimensions >= 4. Suppress Quality Floor if:
- Valuation <= 3 (massively overvalued negates quality)
- RSI >= 85 (extreme overbought = timing risk too high)
- Extension = EXTREME (mean-reversion risk overrides quality)

**Quality Floor time decay:**
- Full protection for 3 months from activation date.
- After 3 months: if price down >25% from HOLD activation price, suspend floor.
- Track `quality_floor_activated_date` and `quality_floor_price` in scores.csv.

---

## Momentum Extension Modifier

**Purpose:** Penalize stocks with extreme recent run-ups where chasing the move carries elevated mean-reversion risk. This captures the *magnitude* of recent moves — something RSI and SMA50 extension only partially reflect.

**Data source:** `FMP: getStockPriceChange` — use 1M and 3M percentage changes.

### Extension Risk Categories (Graduated)

**Note:** Thresholds below are for >$100B market cap (1.0x). Multiply by market cap factor: $10-100B = 1.2x, $2-10B = 1.5x, <$2B = 2.0x.

| Category | Criteria (base thresholds) | Composite Modifier |
|----------|----------|-------------------|
| **EXTREME** | 1M >= 80% OR (1M >= 60% AND 3M >= 120%) | Subtract 5 |
| **SEVERE** | 1M in [60%, 80%) OR (1M >= 40% AND 3M >= 90%) | Subtract 4 |
| **HIGH** | 1M in [45%, 60%) OR (1M >= 30% AND 3M >= 60%) | Subtract 3 |
| **MODERATE** | 1M in [30%, 45%) OR (1M >= 20% AND 3M >= 45%) | Subtract 2 |
| **LOW** | 1M < 30% AND 3M < 45% | No modifier |
| **NONE** | 1M < 15% AND 3M < 30% | No modifier |

### Application Rules

1. **Applied as Override 5** — after all other overrides (Overbought, VIX, Cross-Dimension, R:R)
2. **Combined penalty with Override 1** — if Override 1 (RSI overbought) also applied, use: `combined = max(O1, O5) + 0.3 × min(O1, O5)`, rounded to nearest integer. Apply ADX multiplier to O1 BEFORE this formula. This replaces the old "use the larger" rule.
3. **Minimum composite after extension penalty: 25** — never push a stock below STRONG SELL floor
4. **IPO exception:** Stocks with <100 trading days — reduce extension penalty by half (rounded down).
5. **Recovery stocks exception:** If 6M return is negative AND 1M is positive, OR if 6M < +5% AND 1M > 6x abs(6M change) — reduce category by one tier.
6. **Market cap scaling:** Apply market cap factor to all thresholds before categorization.

### Extension Risk in Warnings

Always include extension risk category in the Warnings table:

| Category | Severity | Warning Text |
|----------|----------|-------------|
| EXTREME | !!! | EXTREME EXTENSION: +{1M}% in 1M, +{3M}% in 3M. Mean reversion highly likely. Wait for consolidation. Override 5: -5. |
| SEVERE | !!! | SEVERE EXTENSION: +{1M}% in 1M, +{3M}% in 3M. High pullback probability. Override 5: -4. |
| HIGH | !! | HIGH EXTENSION: +{1M}% in 1M, +{3M}% in 3M. Elevated pullback risk. Override 5: -3. |
| MODERATE | ! | MODERATE EXTENSION: +{1M}% in 1M. Monitor for consolidation. Override 5: -2. |
| LOW | — | (no warning, no modifier) |
| NONE | — | (no warning, no modifier) |

### Scoring Justification

In the composite calculation section, add a line showing the extension modifier:
```
Extension: {CATEGORY} (1M: +{X}%, 3M: +{Y}%, mcap scaling: {X}x) → modifier: {-5/-4/-3/-2/0}
```

---

## Decision Thresholds

| Composite | Signal | Action |
|-----------|--------|--------|
| >= 75 | STRONG BUY | Aggressive sizing (up to 2x normal) |
| >= 60 AND < 75 | BUY | Standard sizing |
| >= 40 AND < 60 | HOLD | No new position |
| >= 25 AND < 40 | SELL | Reduce/exit position |
| < 25 | STRONG SELL | Exit immediately |

**Position-Aware Signal Translation:**
When the user holds a position (from `get_open_position`), translate signals:

| Raw Signal | No Position | Existing Position |
|------------|-------------|-------------------|
| STRONG BUY | BUY (full size) | ADD (if below cap) |
| BUY | BUY | ADD (if below cap) |
| HOLD | WAIT | MAINTAIN |
| SELL | AVOID | REDUCE/EXIT |
| STRONG SELL | AVOID | EXIT IMMEDIATELY |

---

## Scoring Calibration & Forward Return Tracking

**Purpose:** Enable continuous improvement of the scoring system by tracking how well scores predict actual forward returns.

**Forward Return Columns (in scores.csv):**
The following columns are populated by `price_at_scoring` at analysis time. Forward returns should be computed in future analyses when re-analyzing the same stock:
- `price_at_scoring`: price when composite was computed
- `fwd_1w_return`: % return 5 trading days after scoring
- `fwd_1m_return`: % return 21 trading days after scoring
- `fwd_3m_return`: % return 63 trading days after scoring

**Information Coefficient (IC) Tracking:**
When sufficient data exists (>20 scored stocks with forward returns), compute:
- IC = rank_correlation(composite_score, fwd_1m_return) — Spearman rank correlation
- IC > 0.10: Scoring system has predictive power. "CALIBRATION: IC={X}. Scores are predictive."
- IC 0.05-0.10: Marginal. "CALIBRATION: IC={X}. Marginal predictive power."
- IC < 0.05: Not predictive. "CALIBRATION WARNING: IC={X}. Scoring system needs recalibration."

**Per-Dimension IC:**
Compute IC for each dimension individually to identify which dimensions are actually predictive:
- If a dimension's IC < 0: that dimension is ANTI-predictive. Consider reducing its weight.
- If a dimension's IC > 0.15: that dimension is highly predictive. Consider increasing its weight.
- Log: "DIMENSION IC: Tech={X}, Fund={X}, Val={X}, Sent={X}, SM={X}, Macro={X}, BT={X}, Risk={X}."

**Signal Accuracy Tracking:**
For each signal (STRONG BUY, BUY, HOLD, SELL, STRONG SELL), track:
- What % of STRONG BUY signals had positive 1M returns?
- What % of SELL signals had negative 1M returns?
- This reveals systematic bias (e.g., if SELL signals are frequently wrong, the system is too bearish).

**Staleness Rule:**
Scores older than 3 calendar days OR with >5% price movement from `price_at_scoring` are STALE. When referencing prior scores in a new analysis, flag stale scores: "PRIOR SCORE STALE: {N} days old, price moved {X}%."
