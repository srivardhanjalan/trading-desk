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

**3 calls (2 Alpaca + 1 WebSearch, parallel):**

- Call `mcp__alpaca__get_account_info` — current equity, buying power, cash
- Call `mcp__alpaca__get_open_position` with symbol=$ARGUMENTS — check if already held, current P&L, quantity
- Call `WebSearch` query: "$ARGUMENTS earnings estimate revisions {current_year}" — analyst estimate revision trend from Zacks/Yahoo. Fallback for broken `getAnalystEstimates` (402 error). Rising estimates = bullish catalyst. Falling = headwind.

### Derived Calculations

Using data from all phase reports:

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

### Step 1 — Score all 8 dimensions

Apply `_shared/scoring-rubrics.md` thresholds to data from all phase reports. For each dimension, assign a score 1-10 with brief justification.

**Scoring checklist — ensure all inputs are used:**
- **Technical:** RSI (exact value), Stochastic (%K/%D exact values), MACD, ADX, timeframe alignment count. RSI overbought prevents 7-8 base.
- **Fundamental:** Piotroski, Z-Score, revenue growth, earnings beat/miss history.
- **Valuation:** Revenue PEG (primary), EPS PEG (secondary check for margin expansion), PSG (routing alt only), DCF range, analyst consensus vs price.
- **Sentiment:** All 5 platform scores × weights. Include News NLP compliance status.
- **Smart Money:** Insider activity + 10b5-1 status + congressional trades + institutional ownership + options flow. Congressional data from `{SYMBOL}_sentiment.md` must be included in justification.
- **Macro:** VIX + rates + sector ETF (if available).
- **Backtest:** Apply trade count gate FIRST, then B&H comparison, then walk-forward status.
- **Risk:** Beta, RSI, IV, earnings proximity, extension from SMA50, geographic concentration.

**Asset type check:** If crypto, use crypto weights (Technical 35%, Smart Money 25%, Risk 20%, Backtest 12%, Sentiment 8%). Skip Fundamental, Valuation, Macro.

### Step 2 — Calculate weighted composite

```
composite = sum(dimension_score * weight) / sum(weights) * 10
```

Scale to 0-100.

### Step 3 — Apply overrides (in order)

**Override 1: Overbought/Oversold (Graduated)**
- RSI from Phase 3 technical report
- RSI 75-80: subtract 5. Note: "OVERBOUGHT — RSI {value}. Timing risk elevated."
- RSI 80-85: subtract 10. Note: "OVERBOUGHT — RSI {value}. Strong timing risk."
- RSI > 85: cap at 55. Note: "EXTREME OVERBOUGHT — RSI {value}. Do not enter."
- RSI 20-25: add 5 (LONG only). Note: "OVERSOLD — RSI {value}. Potential snap-back."
- RSI < 20: add 10 (LONG only). Note: "EXTREME OVERSOLD — RSI {value}. High snap-back probability."
- Oversold does NOT prevent SELL for existing positions.

**Override 2: VIX Panic (Beta-Conditional)**
- VIX from Phase 2 fundamental report. Beta from Phase 1 technical report.
- VIX > 35 AND beta > 1.0 AND composite >= 60: downgrade to HOLD
- VIX > 35 AND beta <= 1.0: warning only, no score change

**Override 3: Cross-Dimension Conflicts**
- Technical vs Fundamental diverge by >5 points: subtract 3
- Risk <= 2 AND composite >= 60: downgrade to HOLD
- Data completeness < 60%: force HOLD
- Fewer than 5/8 dimensions scored: force HOLD

**Override 4: R:R Check**
- If R:R ratio < 1.5: force HOLD with note "Risk/Reward insufficient"

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
