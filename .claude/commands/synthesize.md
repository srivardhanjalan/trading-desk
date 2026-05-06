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

**4 calls (2 Alpaca + 1 FMP + 1 WebSearch, parallel):**

- Call `mcp__alpaca__get_account_info` — current equity, buying power, cash
- Call `mcp__alpaca__get_open_position` with symbol=$ARGUMENTS — check if already held, current P&L, quantity
- Call `mcp__financial-modeling-prep__getStockPriceChange` with symbol=$ARGUMENTS — multi-period price performance (1D, 5D, 1M, 3M, 6M, 1Y) for momentum extension scoring
- Call `WebSearch` query: "$ARGUMENTS earnings estimate revisions {current_year}" — analyst estimate revision trend from Zacks/Yahoo. Fallback for broken `getAnalystEstimates` (402 error). Rising estimates = bullish catalyst. Falling = headwind.

### Derived Calculations

Using data from all phase reports:

**Momentum Extension Risk (from getStockPriceChange):**
- Extract 1M and 3M percentage changes
- Classify into extension category per `_shared/scoring-rubrics.md` "Momentum Extension Modifier":
  - EXTREME: 1M >= 60% OR (1M >= 40% AND 3M >= 90%) → subtract 5 from composite
  - HIGH: 1M >= 30% OR (1M >= 20% AND 3M >= 60%) → subtract 2 from composite
  - MEDIUM: 1M >= 15% OR 3M >= 30% → no modifier
  - LOW: 1M < 15% AND 3M < 30% → no modifier
- Check recovery exception: if 6M < 0 AND 1M > 0, reduce category by one tier
- Check IPO exception: if <100 trading days, halve the penalty
- Record: 1D%, 5D%, 1M%, 3M%, 6M%, 1Y% in the Momentum row of the report
- This modifier is applied as Override 5 (does NOT stack with Override 1 overbought — use larger penalty)

**Value at Risk (VaR):**
- Daily VaR = price * HV (from Phase 10) * 1.645 (95% confidence)
- Weekly VaR = Daily VaR * sqrt(5)

**Position Sizing (Fixed-Fractional):**
- Risk per trade = equity * 0.02 (2% risk)
- Stop loss = support level from Phase 3, or entry - (ATR * 2), or entry * 0.97 (3% max)
- Position size (shares) = risk_per_trade / (entry_price - stop_loss)
- Position size ($) = shares * entry_price
- Cap at 20% of portfolio (diversification limit)
- If STRONG BUY: allow up to 2x normal sizing (still capped at 20%)

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

---

## Phase 16: Synthesis & Recommendation

### Step 0 — Determine Earnings Regime

Check `getEarningsCalendar` data from Phase 11 or fundamental report:
- If earnings within 7 calendar days: **USE PRE-EARNINGS WEIGHTS** (see scoring-rubrics.md "Pre-Earnings Weight Switching" section). Note: "PRE-EARNINGS WEIGHT SWITCH active."
- If analyzing within 2 trading days AFTER earnings report: flag for **Sell-the-News check** (Override 7).
- Otherwise: use normal weights.

### Step 1 — Score all 8 dimensions

Apply `_shared/scoring-rubrics.md` thresholds to data from all phase reports. For each dimension, assign a score 1-10 with brief justification.

**Scoring checklist — ensure all inputs are used:**
- **Technical:** RSI (exact value), Stochastic (%K/%D exact values), MACD, ADX, timeframe alignment count. Apply ADX-conditional RSI interpretation (if ADX > 35 with +DI > 2x -DI, RSI overbought is trend confirmation — no cap). Apply Volume Direction Modifier (distribution/accumulation on high volume).
- **Fundamental:** Piotroski, Z-Score, revenue growth, earnings beat/miss history. Apply SBC Margin Adjustment if SBC > 10% of revenue.
- **Valuation:** Revenue PEG (primary), EPS PEG (secondary). Apply Scaled EPS-PEG Divergence Adjustment (divergence ratio >= 4.0 → +3, >= 3.0 → +2, >= 2.0 → +1; cap at Val 7; cap at +2 if P/S > 40x). PSG (routing alt only), DCF range, analyst consensus vs price.
- **Sentiment:** All 5 platform scores × weights. Include News NLP compliance status.
- **Smart Money:** Insider activity + 10b5-1 status + congressional trades + institutional ownership + options flow. Apply Insider-Institutional Divergence Resolution (if all selling is 10b5-1 + institutional accumulation > 5% → floor 6). Congressional data from `{SYMBOL}_sentiment.md` must be included in justification.
- **Macro:** VIX + rates + sector ETF (if available). If sector ETF data unavailable (FMP 402): cap Macro at 6.
- **Backtest:** Apply trade count gate FIRST. Apply revised B&H benchmark (waive penalty if B&H > 100%, reduce to -1 if B&H > 50%). Apply Adaptive Backtest Weighting (reduce effective weight based on trade count; halve if walk-forward robustness < 0.3). Apply walk-forward status.
- **Risk:** Beta, RSI, IV, earnings proximity, extension from SMA50, geographic concentration.

**Asset type check:** If crypto, use crypto weights (Technical 35%, Smart Money 25%, Risk 20%, Backtest 12%, Sentiment 8%). Skip Fundamental, Valuation, Macro.

### Step 2 — Calculate weighted composite

**Check earnings regime from Step 0:**
- If pre-earnings: use pre-earnings weights from scoring-rubrics.md
- Otherwise: use normal weights
- If Adaptive Backtest Weighting triggered (low trade count or overfitted): adjust backtest weight and redistribute proportionally

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

**Override 5: Momentum Extension**
- Use extension category computed in Phase 15 from `getStockPriceChange`
- EXTREME → subtract 5. HIGH → subtract 2. MEDIUM/LOW → no change.
- Does NOT stack with Override 1 (overbought). If both apply, use the LARGER penalty only.
  - Example: RSI 78 = -5 (Override 1) + EXTREME extension = -5 (Override 5). Use -5, not -10.
  - Example: RSI 72 = 0 (no Override 1) + EXTREME extension = -5. Apply -5.
- Recovery exception: 6M return negative + 1M positive → reduce category by one tier before applying
- IPO exception: <100 trading days → halve the penalty (round down)
- **Fundamental-Catalyst Exception:** If EXTREME/HIGH AND major catalyst in last 60 days (contract >10% revenue, >=3 upgrades in 30d, revenue acceleration >5pp, major product launch) → reduce category by one tier. Note: "EXTENSION CATALYST EXCEPTION: {catalyst}."
- Note in output: "EXTENSION OVERRIDE: {CATEGORY} (1M: +{X}%, 3M: +{Y}%) → {modifier applied}"

**Override 6: Earnings Catalyst Modifier** (only if earnings within 7 days)
- Compute Earnings Beat Probability (EBP): base = beats/total_quarters + 10% if estimate revisions positive + 5% if avg surprise > 10%. Cap at 95%.
- EBP >= 80%: add +3. EBP >= 65%: add +1. EBP < 50%: subtract 2. EBP < 30%: subtract 4.
- Note: "EARNINGS CATALYST: {date}. Beat probability: {EBP}%. History: {X}/{Y} beats. Modifier: {+/-N}."

**Override 7: Sell-the-News Detector** (only if within 2 trading days AFTER earnings)
- IF EPS beat > 10% AND revenue beat > 3% AND stock change < -5% AND (P/S > 30x OR P/E > 100x):
  - Subtract 5. Note: "SELL-THE-NEWS: Beat on all metrics but stock down {X}%. Further compression likely."
- IF 6M return < -15% AND earnings beat: Note: "Stock in distribution phase despite strong fundamentals."

**Quality-Timing Safety Check:**
- After all overrides, if composite < 40 (SELL territory) BUT Quality Score >= 60: OVERRIDE to HOLD (40).
- Note: "QUALITY FLOOR: High-quality business (Quality {X}) prevents SELL signal. Bad timing, not bad business."

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
{DATE},{SYMBOL},{COMPOSITE},{SIGNAL},{TECH},{FUND},{VAL},{SENT},{SMART},{MACRO},{BT},{RISK},{DATA_PCT}
```

If `reports/scores.csv` doesn't exist, create it with header:
```
date,symbol,composite,signal,technical,fundamental,valuation,sentiment,smart_money,macro,backtest,risk,data_completeness
```

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
