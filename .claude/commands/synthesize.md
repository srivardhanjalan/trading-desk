# Synthesize & Recommend: $ARGUMENTS

Run Phases 15, 16, 16b for the given symbol. Reads phase report files, scores all 8 dimensions, produces actionable recommendation.

**Before starting:** Read these files:
- `reports/{SYMBOL}_technical.md` (from analyze-technical)
- `reports/{SYMBOL}_fundamental.md` (from analyze-fundamental)
- `reports/{SYMBOL}_sentiment.md` (from analyze-sentiment)
- `.claude/commands/_shared/scoring-rubrics.md` (scoring thresholds)
- `.claude/commands/_shared/output-formats.md` (output templates)

If any report file is missing, note which phases are unavailable and reduce data completeness accordingly.

---

## Phase 15: Risk Quantification & Position Sizing

**9 calls (6 Alpaca + 2 FMP + 1 WebSearch, parallel):**

- Call `mcp__alpaca__get_account_info` — current equity, buying power, cash
- Call `mcp__alpaca__get_open_position` with symbol=$ARGUMENTS — check if already held, current P&L, quantity
- Call `mcp__financial-modeling-prep__getStockPriceChange` with symbol=$ARGUMENTS — multi-period price performance (1D, 5D, 1M, 3M, 6M, 1Y) for momentum extension scoring
- Call `WebSearch` query: "$ARGUMENTS earnings estimate revisions {current_year}" — analyst estimate revision trend from Zacks/Yahoo. Fallback for broken `getAnalystEstimates` (402 error). Rising estimates = bullish catalyst. Falling = headwind.
- Call `mcp__alpaca__get_portfolio_history` with period="3M", timeframe="1D" — portfolio-level equity curve and drawdown over last 3 months. Used for sector concentration context and portfolio-level risk assessment. If max drawdown >15% in last month, apply more conservative position sizing.
- Call `mcp__alpaca__get_all_positions` — all current positions for portfolio-level risk assessment (sector concentration, aggregate beta, correlation risk)
- Call `mcp__financial-modeling-prep__getFullChart` with symbol=$ARGUMENTS, from_date={1 year ago YYYY-MM-DD}, to={today YYYY-MM-DD} — daily OHLCV for historical VaR/CVaR computation (requires 252 trading days of returns)

### Derived Calculations

Using data from all phase reports:

**Momentum Extension Risk (from getStockPriceChange):**
- Extract 1M and 3M percentage changes
- Classify into extension category per `_shared/scoring-rubrics.md` "Momentum Extension Modifier":
  - EXTREME: 1M >= 80% OR (1M >= 60% AND 3M >= 120%) → subtract 5
  - SEVERE: 1M in [60%, 80%) OR (1M >= 40% AND 3M >= 90%) → subtract 4
  - HIGH: 1M in [45%, 60%) OR (1M >= 30% AND 3M >= 60%) → subtract 3
  - MODERATE: 1M in [30%, 45%) OR (1M >= 20% AND 3M >= 45%) → subtract 2
  - LOW: 1M < 30% AND 3M < 45% → no modifier
  - NONE: 1M < 15% AND 3M < 30% → no modifier
- **Market cap scaling:** Multiply thresholds by: >$100B = 1.0x, $10-100B = 1.2x, $2-10B = 1.5x, <$2B = 2.0x
- Check recovery exception: if 6M < 0 AND 1M > 0, OR 6M < +5% AND 1M > 6x abs(6M change) → reduce category by one tier
- Check IPO exception: if <100 trading days, halve the penalty
- Record: 1D%, 5D%, 1M%, 3M%, 6M%, 1Y% in the Momentum row of the report
- This modifier is applied as Override 5. **Combined penalty with Override 1:** `combined = max(O1, O5) + 0.3 × min(O1, O5)` (replaces old "use the larger penalty" rule)

**Historical Value at Risk (VaR) & CVaR:**
Using 1-year daily returns from `getFullChart`:
- Sort daily returns ascending. Daily VaR (95%) = 5th percentile of historical daily returns × position_value.
- Weekly VaR = Daily VaR × sqrt(5).
- **CVaR (Conditional VaR / Expected Shortfall):** Average of all returns below the 5th percentile × position_value. CVaR captures tail risk better than VaR.
- If <200 trading days available: fall back to parametric VaR = price × HV × 1.645 (95% confidence). Note: "VaR: PARAMETRIC (insufficient history for historical)."
- Report: "VaR(95%): ${daily} daily / ${weekly} weekly. CVaR: ${cvar}. Method: {historical/parametric}."

**Bull/Base/Bear Scenario DCF — MANDATORY for Track A, logged skip for Track B:**

**Per `_shared/no-skip-policy.md`, this step MUST be attempted or explicitly logged. Silent skipping is a violation.**

- **Track A (Value):** revenue growth <=20% AND P/E <=40 → **MUST RUN all 3 scenarios.** Call `calculateCustomDCF` 3 times (bull, base, bear) sequentially to avoid session race conditions. If any call fails, retry once after 2 seconds. Log each outcome.
- **Track B (Growth):** revenue growth >20% OR P/E >40 → Skip is valid, but MUST log: `"SCENARIO DCF: SKIPPED — Track B stock (rev growth {X}%, P/E {Y}x). PEG ratio used as primary valuation metric."`
- **Track Unknown:** If data is insufficient to classify → **default to running Scenario DCF.** Log: `"SCENARIO DCF: RUN (track classification uncertain)."`
- **All 3 Fail:** Log: `"SCENARIO DCF: FAILED — {error}. Falling back to Phase 9 DCF range."` Use standard/levered DCF from Phase 9 as substitute.

WACC = riskFreeRate (10Y from Phase 2 getTreasuryRates) + beta (from Phase 1) × marketRiskPremium (from getMarketRiskPremium)

Two-stage model for each scenario:
Stage 1 (5-year explicit projection):
- **Bull (20% weight):** Revenue growth = forward consensus + 5pp (from getAnalystEstimates), margin expansion +2pp
- **Base (60% weight):** Revenue growth = forward consensus (from getAnalystEstimates), current margins
- **Bear (20% weight):** Revenue growth = 50% of forward consensus, margin compression -2pp
- Project FCF for 5 years: FCF_year_n = FCF_current × (1 + scenario_growth)^n × (1 + margin_adjustment)

Stage 2 (terminal value):
- Terminal value = FCF_year_5 × (1 + terminal_growth) / (WACC_scenario - terminal_growth)
- Bull terminal growth = 3.5%, WACC - 0.5%. Base = 3%, current WACC. Bear = 2%, WACC + 1%.

Fair Value = sum(PV of Stage 1 FCFs) + PV of Terminal Value
Probability-weighted FV = Bull×0.20 + Base×0.60 + Bear×0.20

- Use existing bear-case DCF from Phase 9 (calculateCustomDCF bear case) as cross-validation for Bear scenario
- Report: "Scenario DCF: Bull ${X} / Base ${Y} / Bear ${Z} → Weighted: ${W} ({upside/downside}% vs current)"

**Volatility-Scaled Position Sizing:**
- **Base risk per trade:** risk_pct = 2% × (15 / current_VIX), capped at [0.5%, 3%].
  - VIX = 15: risk_pct = 2.0% (normal)
  - VIX = 30: risk_pct = 1.0% (defensive)
  - VIX = 10: risk_pct = 3.0% (capped — aggressive)
- Risk per trade = equity × risk_pct
- Stop loss = support level from Phase 3, or entry - (ATR * 2), or entry * 0.97 (3% max)
- Position size (shares) = risk_per_trade / (entry_price - stop_loss)
- Position size ($) = shares * entry_price
- **Existing holdings check:** Subtract existing position value (from `get_open_position`) from 20% cap before computing new position size. If existing position >= 20%, block new position.
- Cap at 20% of portfolio (diversification limit) for combined existing + new
- If STRONG BUY: allow up to 2x normal sizing (still capped at 20%)
- **Sector concentration check:** After computing position size, check sector exposure across `get_all_positions`. Warn if adding this position pushes sector above 30%. Block if sector would exceed 40%.
- **Drawdown-adjusted sizing:** From `get_portfolio_history`, compute max drawdown in last 30 days:
  - Drawdown > 10%: halve position size. "DRAWDOWN BRAKE: Portfolio down {X}% in 30d. Position halved."
  - Drawdown > 15%: block new positions. "DRAWDOWN BLOCK: Portfolio down {X}% in 30d. No new positions."

**Kelly Criterion (from Phase 14 backtest):**
- Kelly % = win_rate - (loss_rate / avg_win_loss_ratio)
- Half-Kelly = Kelly% / 2 (conservative)
- Use whichever is SMALLER: fixed-fractional or half-Kelly

**Stop Loss Level:**
- Primary: nearest support from Phase 3 (if within 5% of entry)
- Secondary: entry - (2 * ATR)
- Maximum: entry * 0.97 (never risk more than 3% on one trade — unless rules.json overrides)

**Take Profit Level:**
- Primary: nearest resistance from Phase 3
- Secondary: analyst consensus target (if within reasonable range)
- Minimum R:R ratio: 2:1 (take profit must be at least 2x the stop distance)

**Risk/Reward Ratio:**
- R:R = (take_profit - entry) / (entry - stop_loss)
- Must be >= 2.0 for BUY recommendation
- If R:R < 1.5, downgrade to HOLD regardless of composite score

**Gap Risk Adjustment (Earnings Proximity):**
When earnings are within 3 trading days, the expected overnight gap adds unhedgeable risk:
- Compute expected move from options data (from sentiment report Phase 10).
- If expected move > 2x stop distance: BLOCK new entry. "GAP RISK: Expected earnings move ${X} exceeds 2x stop distance ${Y}. Wait for post-earnings setup."
- If expected move > 1x stop distance: reduce position size by 50%. "GAP RISK: Expected move ${X} > stop distance ${Y}. Position halved."
- If expected move < stop distance: normal sizing. Note gap risk in warnings.

**Trailing Stop Framework:**
After entry, provide trailing stop recommendations based on regime (from Technical report):
- **TRENDING regime (ADX avg > 25):** ATR-based trailing stop = entry - (3 × ATR). Trails upward but never downward. "TRAILING STOP (ATR): ${level}. Widens to accommodate trend volatility."
- **MEAN-REVERTING regime (ADX avg < 18):** Fixed percentage stop = entry × 0.95 (5% max loss). "TRAILING STOP (FIXED): ${level}. Tight stop for range-bound market."
- **TRANSITIONAL regime:** Use 2.5 × ATR. "TRAILING STOP (HYBRID): ${level}."
- Trailing stops are ADVISORY — they are displayed in the report and drawn on the chart (Phase 16b) but not auto-executed.

**Portfolio-Level Risk Management:**
Using data from `get_all_positions`:
- **Aggregate portfolio beta:** Compute position-weighted average beta. If aggregate beta > 1.5: "PORTFOLIO BETA WARNING: {X}. Consider hedging or reducing high-beta positions."
- **Sector concentration:** Group positions by sector. If any sector > 30%: "SECTOR CONCENTRATION: {sector} at {X}%. Consider diversifying." If > 40%: block new positions in that sector.
- **Correlation risk:** If >3 positions in same sector or >5 positions with beta > 1.5: "CORRELATION RISK: {N} correlated positions. Portfolio drawdown amplified in sector downturn."
- **Liquidity risk:** If any position > 5% of stock's average daily volume: "LIQUIDITY RISK: Position in {symbol} = {X}% of ADV. May cause slippage on exit."

---

## Phase 16: Synthesis & Recommendation

### Step 0 — Determine Earnings Regime (MANDATORY GATE)

**This step is NON-OPTIONAL and MUST be completed BEFORE computing ANY weights or scores.**

Check `getEarningsCalendar` data from Phase 11 or fundamental report:
- If earnings within 7 calendar days (use trading days via `getCalendar` if available): **USE PRE-EARNINGS WEIGHTS** (see scoring-rubrics.md "Pre-Earnings Weight Switching" section). Note: "PRE-EARNINGS WEIGHT SWITCH active. Earnings in {N} days."
- If analyzing within 2 trading days AFTER earnings report: flag for **Sell-the-News check** (Override 7).
- If earnings date NOT FOUND in calendar data: use normal weights + add caution flag "EARNINGS DATE UNKNOWN" + cap Risk at 6.
- Otherwise: use normal weights.
- **Log which weight table is used:** "WEIGHTS: {NORMAL/PRE-EARNINGS}. Reason: {earnings date or 'no upcoming earnings'}."

### Step 1 — Score all 8 dimensions

Apply `_shared/scoring-rubrics.md` thresholds to data from all phase reports. For each dimension, assign a score 1-10 with brief justification.

**Scoring checklist — ensure all inputs are used:**
- **Technical:** RSI (exact value), Stochastic (%K/%D exact values), MACD, ADX, timeframe alignment count. Apply ADX-conditional RSI interpretation (if ADX > 35 with +DI > 2x -DI, RSI overbought is trend confirmation — no cap). Apply Volume Direction Modifier (distribution/accumulation on high volume). Cross-validate FMP indicators (RSI, SMA, ADX) vs TradingView — flag divergence >10 points. Check regime (TRENDING/TRANSITIONAL/MEAN-REVERTING) and adjust indicator interpretation. Include Williams %R, DEMA/TEMA/WMA confirmation signals. Check relative strength vs market snapshot.
- **Fundamental:** Piotroski, Z-Score, revenue growth, earnings beat/miss history (minimum 6/8 quarters required for modifier). Apply SBC Margin Adjustment: **for EVERY stock, compute SBC/revenue. If >10%, MUST apply SBC Margin Adjustment.** This is not optional. Apply Economic Moat modifier (margin premium, revenue concentration, recurring revenue, capital allocation). Apply Financial Statement Forensics modifier (Beneish M-Score, accruals ratio, receivables/revenue trend, inventory/revenue trend).
- **Valuation:** Revenue PEG (primary), EPS PEG (secondary). Apply Scaled EPS-PEG Divergence Adjustment (divergence ratio >= 4.0 → +3, >= 3.0 → +2, >= 2.0 → +1; cap at Val 7; cap at +2 if P/S > 40x). PSG (routing alt only), DCF range, analyst consensus vs price. Apply Bear-Case DCF stress test (50% growth, industry margins). Compute margin of safety and implied growth rate. Apply Industry P/E relative modifier. For Track B: check TAM penetration.
- **Sentiment:** All 5 platform scores × market-cap-scaled weights (large/mid/small cap tables). Include News NLP compliance status + paywall discount. Check Consensus Crowding indicator (>80% agreement = contrarian risk). Apply multi-agent Override 8 if available.
- **Smart Money:** Insider activity + 10b5-1 status + congressional trades + institutional ownership + options flow. Apply Insider-Institutional Divergence Resolution (if all selling is 10b5-1 + institutional accumulation > 5% → floor 6). Congressional data from `{SYMBOL}_sentiment.md` must be included in justification. Apply fund quality weighting (top-alpha funds accumulating = +1, activist >5% = +2). Check dark pool activity proxy (unusual ATS volume). Apply Smart Money quality gate (cap at 6 if Fundamental <= 3). Apply 13F staleness weighting.
- **Macro:** VIX (graduated by beta) + rates + sector ETF (if available). If sector ETF data unavailable (FMP 402): cap Macro at 5. Apply per-stock sensitivity multiplier (beta, international revenue, D/E ratio). Check economic calendar events (FOMC, CPI within 3 days). Classify macro regime (Goldilocks/Reflation/Stagflation/Deflation) from GDP+CPI trends. Incorporate global indicators: copper/gold ratio, oil, DXY, COT data. Apply yield curve flat detection (0-25bps = -1).
- **Backtest:** Apply trade count gate FIRST (<3 trades = score 5, 0% weight). **CHECK B&H RETURN BEFORE PENALTY:** If B&H > 100%, skip penalty entirely — log "B&H WAIVER: {X}% return." If B&H > 50% AND strategy captures >70% of B&H, no penalty (capture ratio). Apply Adaptive Backtest Weighting (reduce effective weight based on trade count; halve if walk-forward robustness < 0.3). Log: "BACKTEST ADAPTIVE: {N} trades → {X}% weight." Apply statistical significance t-test for >=10 trades (t > 2.0 = significant, 1.5-2.0 = marginal cap at 7, < 1.5 = insignificant cap at 5).
- **Risk:** Beta (market-cap-adjusted thresholds), RSI (ADX-conditional, anti-stacking with Override 1), IV/HV (earnings-proximity-scaled thresholds), earnings proximity (EBP gate), extension from SMA50 (anti-stacking with Override 5), geographic concentration, insider selling (anti-stacking with Smart Money), bid/ask spread (market hours only). Apply all anti-stacking rules to prevent triple-counting.

**Asset type check:** If crypto, use crypto weights (Technical 35%, Smart Money 25%, Risk 20%, Backtest 12%, Sentiment 8%). Skip Fundamental, Valuation, Macro.

### Step 2 — Calculate weighted composite

**Check earnings regime from Step 0:**
- If pre-earnings: use pre-earnings weights from scoring-rubrics.md
- Otherwise: use normal weights
- **Adaptive Backtest Weighting (MANDATORY):** BEFORE computing composite, check trade count. Apply adaptive weight table from scoring-rubrics.md. Log: "BACKTEST ADAPTIVE: {N} trades → {X}% effective weight (redistributed {Y}% to other dimensions proportionally)." If walk-forward robustness < 0.3 AND trade count < 10: set backtest score to 5 (neutral) and reduce weight to 3%.

```
composite = sum(dimension_score * weight) / sum(weights) * 10
```

Scale to 0-100.

**Quality-Timing Dual Score (compute alongside composite):**
```
quality_score = (fundamental * 0.30 + valuation * 0.25 + smart_money * 0.25 + macro * 0.20) * 10
timing_score = (technical * 0.35 + risk * 0.25 + sentiment * 0.20 + backtest * 0.20) * 10
```
Report both in the output. Apply the Quality-Timing signal matrix from scoring-rubrics.md as supplementary guidance.

**Critical:** If Quality >= 60, NEVER produce a SELL signal regardless of composite. High-quality businesses with bad timing are HOLDs, not SELLs.

### Step 3 — Apply overrides (in order)

**MANDATORY: ALL overrides (1-8) MUST be explicitly evaluated and documented.** For each override, log: "OVERRIDE {N}: {APPLIED — details / NOT TRIGGERED — reason}." Skipping evaluation is a rubric violation. This prevents silent omission of Override 6, 7, or 8.

**Override 1: Overbought/Oversold (Graduated, ADX-Conditional)**
- RSI from Phase 3 technical report. ADX and +DI/-DI from Phase 3.
- **First check ADX-conditional RSI** (see scoring-rubrics.md):
  - If ADX > 35 AND +DI > 2x -DI: multiply overbought penalty by 0.5x (trend-confirmed overbought)
  - If ADX 25-35: multiply by 0.6x
  - If ADX < 25: multiply by 1.0x (full penalty — exhaustion signal)
- RSI 75-80: base subtract 5 × ADX_multiplier. Note includes ADX context.
- RSI 80-85: base subtract 10 × ADX_multiplier.
- RSI > 85: cap at 55 regardless of ADX. Note: "EXTREME OVERBOUGHT — RSI {value}. Do not enter."
- RSI 20-25: add 5 (LONG only). Note: "OVERSOLD — RSI {value}. Potential snap-back."
- RSI < 20: add 10 (LONG only). Note: "EXTREME OVERSOLD — RSI {value}. High snap-back probability."
- Oversold does NOT prevent SELL for existing positions.

**Override 2: VIX Panic (Beta-Conditional)**
- VIX from Phase 2 fundamental report. Beta from Phase 1 technical report.
- VIX > 35 AND beta > 1.0 AND composite >= 60: downgrade to HOLD
- VIX > 35 AND beta <= 1.0: warning only, no score change

**Override 3: Cross-Dimension Conflicts**
- Technical vs Fundamental diverge by >=5 points: subtract 3
- Risk <= 2 AND composite >= 60: downgrade to HOLD
- Data completeness < 60%: force HOLD
- Fewer than 5/8 dimensions scored: force HOLD

**Override 4: R:R Check**
- If R:R ratio < 1.5: force HOLD with note "Risk/Reward insufficient"

**Override 5: Momentum Extension (Graduated)**
- Use extension category computed in Phase 15 from `getStockPriceChange`
- Apply market cap scaling to thresholds FIRST (>$100B = 1.0x, $10-100B = 1.2x, $2-10B = 1.5x, <$2B = 2.0x)
- EXTREME → -5. SEVERE → -4. HIGH → -3. MODERATE → -2. LOW/NONE → no change.
- **Combined penalty with Override 1:** If both fire, compute `combined = max(O1, O5) + 0.3 × min(O1, O5)` (rounded). Apply ADX multiplier to O1 BEFORE comparison.
  - Example: RSI 78, ADX 40 = O1 base -5 × 0.5 = -2.5. SEVERE extension = O5 -4. Combined = max(4, 2.5) + 0.3 × min(4, 2.5) = 4 + 0.75 = 5 (rounded).
  - Example: RSI 72 = no O1. SEVERE extension = -4. Apply -4 alone.
- Recovery exception: 6M negative + 1M positive, OR 6M < +5% AND 1M > 6x abs(6M) → reduce category by one tier
- IPO exception: <100 trading days → halve the penalty (round down)
- **Fundamental-Catalyst Exception:** If EXTREME/SEVERE/HIGH AND major catalyst in last 60 days → reduce category by one tier. Allow -2 tiers for 3+ distinct catalysts (cap at MODERATE). Note: "EXTENSION CATALYST EXCEPTION: {catalyst}."
- Note in output: "EXTENSION OVERRIDE: {CATEGORY} (1M: +{X}%, 3M: +{Y}%, mktcap factor: {F}x) → {modifier applied}"

**Override 6: Earnings Catalyst Modifier** (only if earnings within 7 days)
- Compute Earnings Beat Probability (EBP): base = beats/total_quarters + 10% if estimate revisions positive + 5% if avg surprise > 10%. Cap at 95%.
- EBP >= 80%: add +3. EBP >= 65%: add +1. EBP < 50%: subtract 2. EBP < 30%: subtract 4.
- Note: "EARNINGS CATALYST: {date}. Beat probability: {EBP}%. History: {X}/{Y} beats. Modifier: {+/-N}."

**Override 7: Sell-the-News Detector** (only if within 2 trading days AFTER earnings)
- IF EPS beat > 10% AND revenue beat > 3% AND stock change < -5% AND (P/S > 30x OR P/E > 100x):
  - Subtract 5. Note: "SELL-THE-NEWS: Beat on all metrics but stock down {X}%. Further compression likely."
- IF 6M return < -15% AND earnings beat: Note: "Stock in distribution phase despite strong fundamentals."

**Override 8: Multi-Agent Consensus**
- From `multi_agent_analysis` results in sentiment report.
- Unanimous SELL (net score <= -4): subtract 3. Unanimous BUY (net score >= +4): add 2.
- If tool unavailable: skip, note "OVERRIDE 8: NOT TRIGGERED — multi-agent tool unavailable."

**Quality-Timing Safety Check:**
- After all overrides, if composite < 40 (SELL territory) BUT Quality Score >= 60: check dimension gate.
- **Dimension gate:** Quality Floor fires ONLY if ALL Quality sub-dimensions (Fundamental, Valuation, Smart Money, Macro) >= 4. If Valuation <= 3 OR RSI >= 85 OR Extension = EXTREME: suppress Quality Floor.
- If gate passes: OVERRIDE to HOLD (40). Note: "QUALITY FLOOR: High-quality business (Quality {X}) prevents SELL signal. Bad timing, not bad business."
- If gate fails: Allow SELL. Note: "QUALITY FLOOR SUPPRESSED: {dimension} <= 3 / RSI >= 85 / Extension EXTREME."
- Track `quality_floor_activated_date` and `quality_floor_price` in scores.csv for time decay.

### Step 4 — Determine signal

| Composite | Signal |
|-----------|--------|
| >= 75 | STRONG BUY |
| 60-74 | BUY |
| 40-59 | HOLD |
| 25-39 | SELL |
| < 25 | STRONG SELL |

### Step 5 — Track data completeness

Count: phases_with_data / total_phases_attempted. Report as percentage.

### Step 6 — Check for previous analysis

- Check if `reports/{SYMBOL}_*.md` from a prior date exists
- If yes: show delta (score change, signal change, key metric changes)
- Read `reports/scores.csv` for historical scores

---

## Phase 16b: Chart Annotations (TradingView Desktop, conditional)

**Only if Desktop is running (check from Phase 6 report).**

**4 calls:**
- Call `mcp__tradingview__draw_shape` with type="horizontal_line", price={stop_loss}, color="red", text="Stop Loss" — draw computed stop loss on chart
- Call `mcp__tradingview__draw_shape` with type="horizontal_line", price={take_profit}, color="green", text="Take Profit" — draw computed take profit on chart
- Call `mcp__tradingview__alert_create` with symbol=$ARGUMENTS, price={stop_loss}, condition="less_than", message="$ARGUMENTS hit stop loss at ${stop_loss}"
- Call `mcp__tradingview__alert_create` with symbol=$ARGUMENTS, price={take_profit}, condition="greater_than", message="$ARGUMENTS hit take profit at ${take_profit}"

If Desktop unavailable: skip — levels are shown in text output.

---

## Output

### Save report
Write full analysis to `reports/{SYMBOL}_{YYYY-MM-DD}.md`

### Append to scores.csv
Append row to `reports/scores.csv`:
```
{DATE},{SYMBOL},{COMPOSITE},{SIGNAL},{TECH},{FUND},{VAL},{SENT},{SMART},{MACRO},{BT},{RISK},{DATA_PCT},{PRICE},{QUALITY},{TIMING},{QF_DATE},{QF_PRICE}
```

If `reports/scores.csv` doesn't exist, create it with header:
```
date,symbol,composite,signal,technical,fundamental,valuation,sentiment,smart_money,macro,backtest,risk,data_completeness,price_at_scoring,quality_score,timing_score,quality_floor_date,quality_floor_price
```

**Staleness rule:** Scores older than 3 calendar days OR with >5% price movement from `price_at_scoring` should be treated as STALE. When displaying prior scores, check staleness and flag accordingly.

### Display compact card

Use the compact card template from `_shared/output-formats.md`. Fill all fields from the phase reports and computed values. Include:

- Market hours header (from Phase 0)
- All 8 dimension scores
- Valuation track and detail (DCF range, PEG if growth, analyst targets, earnings history)
- Sentiment breakdown by platform
- Options flow summary (10 derived metrics)
- Best strategy with cross-validation note
- Entry/stop/target with bid/ask spread
- Position sizing
- Override warnings
- Top risks and catalysts
- Corporate actions
- Delta from previous analysis (if available)
