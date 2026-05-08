# Output Formats Reference

Templates for consistent output across all commands.

---

## CRITICAL RULE: DISPLAY CONSISTENCY

**Every stock analysis MUST display the FULL Compact Card (all 16 sections below) to the user in conversation output.** This is non-optional. Do NOT summarize, abbreviate, or skip sections. The same format applies to every stock, every time.

After writing report files to disk, you MUST also display the complete Compact Card in the conversation. Writing to files alone is NOT sufficient.

**Variance between runs is a pipeline violation.** If a section has no data (e.g., no congressional trades), display the section header with "None detected" — do NOT omit the section.

---

## Market Hours Header (from `Alpaca: get_clock`)

- `is_open=true`: `Market OPEN — live data | VIX: {value} ({label})`
- `is_open=false`: `Market CLOSED (opens {next_open}) — data reflects last close. Volume/options data may be stale. | VIX: {value} ({label})`

VIX labels: <15 = "calm", 15-20 = "normal", 20-25 = "elevated", 25-30 = "fear", >30 = "PANIC"

---

## Compact Card — 16 Mandatory Sections

Every analysis MUST include ALL 16 sections in this exact order. No section may be skipped or merged. If data is unavailable for a section, display "Data unavailable — {reason}" within that section.

### Section 1: Header [MANDATORY]

```
# {SYMBOL} — {COMPANY_NAME} | {DATE}

| | |
|---|---|
| **Price** | ${PRICE} ({CHANGE_PCT}%) — {AH_NOTE_IF_APPLICABLE} |
| **Sector** | {SECTOR} / {INDUSTRY} |
| **Score** | **{COMPOSITE}/100 — {SIGNAL}** |
| **Confidence** | {CONF} |
| **Data** | {COMPLETENESS}% complete |
| **Market** | {MARKET_HOURS_HEADER} |
```

### Section 2: Scores Table [MANDATORY]

All 8 dimensions must appear. Use `█` filled and `░` empty (10 chars total).

```
## Scores

| Dimension | Score | Bar | Weight | Key Driver |
|-----------|------:|-----|-------:|------------|
| Technical | {T}/10 | {BAR} | {WT}% | {ONE_LINE_REASON} |
| Fundamental | {F}/10 | {BAR} | {WT}% | {ONE_LINE_REASON} |
| Valuation | {V}/10 | {BAR} | {WT}% | {ONE_LINE_REASON} |
| Smart Money | {SM}/10 | {BAR} | {WT}% | {ONE_LINE_REASON} |
| Risk (10=safest) | {R}/10 | {BAR} | {WT}% | {ONE_LINE_REASON} |
| Backtest | {BT}/10 | {BAR} | {WT}% | {ONE_LINE_REASON} |
| Sentiment | {S}/10 | {BAR} | {WT}% | {ONE_LINE_REASON} |
| Macro | {M}/10 | {BAR} | {WT}% | {ONE_LINE_REASON} |
| **Composite** | **{RAW}/100** | | | Overrides: {LIST} → **{FINAL}/100** |
```

Key Driver: one-line reason for the score. Must include the primary data point(s) that determined the score.

### Section 3: Quality vs Timing [MANDATORY]

```
### Quality vs Timing
| Sub-Score | Value | Components | Guidance |
|-----------|------:|------------|----------|
| **Quality** | {Q}/100 | Fund {F} × 0.30 + Val {V} × 0.25 + Smart {SM} × 0.25 + Macro {M} × 0.20 | "Should I own this?" |
| **Timing** | {T}/100 | Tech {T} × 0.30 + Risk {R} × 0.25 + Sent {S} × 0.20 + BT {BT} × 0.15 + Opt {O} × 0.10 | "Should I buy now?" |
| **Matrix** | | Quality {Q_LABEL} + Timing {T_LABEL} | → {MATRIX_SIGNAL} |
```

If pre-earnings weights active, add note below table.

### Section 4: Momentum & Extension [MANDATORY]

```
### Momentum
| Period | 1D | 5D | 1M | 3M | 6M | 1Y |
|--------|---:|---:|---:|---:|---:|---:|
| Change | {1D}% | {5D}% | {1M}% | {3M}% | {6M}% | {1Y}% |

**Extension Risk: {CATEGORY}** — {DESCRIPTION}. Override 5: {MODIFIER}.
```

Categories: EXTREME (1M>=80%) | SEVERE (60-80%) | HIGH (45-60%) | MODERATE (30-45%) | LOW (15-30%) | NONE (<15%). Market cap scaling applied.

### Section 5: Valuation [MANDATORY]

```
## Valuation

| Metric | Value | Note |
|--------|------:|------|
| **Valuation Track** | {TRACK} | {REASON} |
| Trailing PEG (or P/E) | {VALUE} | {LABEL} |
| Forward PEG (or P/E) | {VALUE} | {LABEL} |
| PEG Divergence | {RATIO}x | {NOTE} |
| EPS-PEG Adjustment | {+N or N/A} | {REASON} |
| DCF — Standard | ${VALUE} | {NOTE} |
| DCF — Levered | ${VALUE} | {NOTE} |
| DCF — Custom | ${VALUE} | {NOTE — or INVALID with reason} |
| Analyst Target | ${TARGET} ({UPSIDE}%) | {COUNT} analysts, {BREAKDOWN} |
| Bear-Case DCF | ${VALUE} | 50% growth, industry margins |
| Scenario DCF | Bull ${X} / Base ${Y} / Bear ${Z} | Weighted: ${W} ({PCT}% vs price) |
| Margin of Safety | {PCT}% | {LABEL — significant/moderate/negative} |
| Implied Growth | {PCT}% | vs {CONSENSUS}% consensus — {LABEL} |
| Next Earnings | {DATE} | EPS est {EPS}, Rev est {REV} |
```

For Track B, add note: "DCF unreliable for high-growth — PEG is primary metric."
If margin of safety > 30%: highlight green. If negative: highlight red.

### Section 6: Sentiment [MANDATORY]

```
## Sentiment

| Source | Signal | Detail |
|--------|--------|--------|
| Reddit | {SIGNAL} | {DETAIL — post count, dominant theme} |
| StockTwits | {SIGNAL} | {DETAIL} |
| Twitter/X | {SIGNAL} | {DETAIL — note if second-hand} |
| News NLP | {SIGNAL} | {DETAIL — article count, tier breakdown} |
| Analyst Actions | {SIGNAL} | {DETAIL — recent upgrades/downgrades} |
```

If multi-agent analysis was run, add row: `| Multi-Agent | {SIGNAL} | {NET_SCORE}, {AGENT_BREAKDOWN} |`

### Section 7: Options Flow [MANDATORY]

```
## Options Flow

| Metric | Value | Interpretation |
|--------|------:|----------------|
| P/C Volume Ratio | {RATIO} | {BULLISH/BEARISH/NEUTRAL} |
| P/C OI Ratio | {RATIO or N/A} | {INTERPRETATION} |
| IV/HV Ratio | {RATIO} | {LABEL — normal/elevated/extreme} |
| IV Skew | {DESCRIPTION} | {NORMAL/ABNORMAL — detail} |
| Expected Move | ±${AMOUNT} (±{PCT}%) | {CONTEXT — straddle vs IV method} |
| Max Pain | ${PRICE} | {VS_CURRENT — above/below/at} |
| Unusual Activity | {STRIKES} | {DETAIL — volume multiples} |
| Net Delta Exposure | {VALUE} | {BULLISH/BEARISH/NEUTRAL} |
| GEX | {VALUE} | {LONG/SHORT GAMMA — dampens/amplifies moves} |
| IV Surface | ATM {X}%, 25d skew {Y}% | {NORMAL/INVERTED} |
| Theta Profile | Net {VALUE} | {TIME DECAY interpretation} |
| Vega Hotspot | {STRIKES} | {SPECULATION interpretation} |
```

If no options market exists (small-cap), display: "OPTIONS N/A — no liquid options market. Smart Money scored from insider/institutional only."

### Section 8: Insider Activity [MANDATORY]

```
## Insider & Institutional

| Date | Name | Role | Action | Value | 10b5-1 |
|------|------|------|--------|------:|--------|
| {DATE} | {NAME} | {ROLE} | {BUY/SELL} | ${VALUE} | {CONFIRMED/NOT VERIFIED} |
| ... | | | | | |
| **Net** | | | **{NET_LABEL}** | **${TOTAL}** | |
```

The 10b5-1 column is MANDATORY for every insider listed. Must show verification status.

### Section 9: Institutional Ownership [MANDATORY]

```
| Metric | Current | Prior Q | Change |
|--------|--------:|--------:|-------:|
| Holders | {N} | {N} | {+/-N} |
| Shares | {N} | {N} | {+/-PCT}% |
| Ownership | {PCT}% | {PCT}% | {+/-PP}pp |
| **Staleness** | **{N} days** | | **{WEIGHT}x** |
```

The Staleness row is MANDATORY. Always show 13F data age and weight applied.

### Section 10: Congressional Activity [MANDATORY]

```
## Congressional Activity

| Chamber | Member | Action | Amount | Date |
|---------|--------|--------|-------:|------|
| Senate | {NAME} | {BUY/SELL} | ${RANGE} | {DATE} |
| House | {NAME} | {BUY/SELL} | ${RANGE} | {DATE} |
```

If no trades found: display section header with "No congressional trading activity detected for {SYMBOL}."

### Section 11: Backtest [MANDATORY]

```
## Backtest

| Strategy | Return | Win Rate | Sharpe | Trades |
|----------|-------:|---------:|-------:|-------:|
| **{BEST}** | **{RETURN}%** | **{WR}%** | **{SHARPE}** | **{TRADES}** |
| Buy & Hold | {BH}% | — | — | — |
| Walk-Forward | {STATUS} | robustness {SCORE} | — | {OOS} OOS |
```

Below table, always include these lines:
```
BACKTEST ADAPTIVE: {N} trades → {X}% weight. {REDISTRIBUTION_NOTE}.
B&H BENCHMARK: {RETURN}% return. {WAIVER_STATUS}.
SIGNIFICANCE: t={VALUE}, p={APPROX}. {SIGNIFICANT/MARGINAL/INSIGNIFICANT}.
```

### Section 12: Trade Setup [MANDATORY]

```
## Trade Setup

| | Price | % from Current |
|---|------:|---------------:|
| Entry | ${PRICE} | {NOTE} |
| Stop Loss | ${PRICE} | {PCT}% |
| Take Profit | ${PRICE} | +{PCT}% |
| **R:R Ratio** | **{RATIO}:1** | |
| Spread | ${SPREAD} ({PCT}%) | {LABEL — excellent/acceptable/wide} |
| Position Size | {SHARES} sh / ${AMOUNT} | {PCT}% of ${EQUITY} |
| VaR (95%) | ${DAILY} daily / ${WEEKLY} weekly | {METHOD — historical/parametric} |
| CVaR | ${CVAR} | Expected shortfall |
| Trailing Stop | ${LEVEL} | {TYPE — ATR/fixed/%} per regime |
```

For WAIT signals: Show "Wait Entry" instead of "Entry" with conditions below table.
For no-position HOLD: Add `**Signal: WAIT** — HOLD + no position = WAIT.`

### Section 13: Warnings [MANDATORY]

```
## Warnings

| Severity | Warning | Impact |
|----------|---------|--------|
| {!!!|!!|!} | {WARNING_TEXT} | {SCORE_IMPACT} |
```

Severity: `!!!` = CRITICAL (blocks trade), `!!` = WARNING (score penalty), `!` = CAUTION (informational).
Minimum: always list at least the top 3 warnings. If no warnings, display "No significant warnings."

### Section 14: Risks & Catalysts [MANDATORY]

```
## Risks & Catalysts

| Risks | Catalysts |
|-------|-----------|
| {RISK_1} | {CATALYST_1} |
| {RISK_2} | {CATALYST_2} |
| {RISK_3} | {CATALYST_3} |
| {RISK_4} | {CATALYST_4} |
| {RISK_5} | {CATALYST_5} |
```

Minimum 4 rows, maximum 8. Balance risks and catalysts (same count each side).

### Section 15: Override Log [MANDATORY]

```
## Override Log

| Override | Status | Detail |
|----------|--------|--------|
| O1 Overbought | {APPLIED -N / NOT TRIGGERED} | {RSI value, ADX condition} |
| O2 VIX Panic | {APPLIED / NOT TRIGGERED} | {VIX value} |
| O3 Cross-Dim | {APPLIED -N / NOT TRIGGERED} | {Tech vs Fund gap} |
| O4 R:R Check | {APPLIED / NOT TRIGGERED} | {R:R value} |
| O5 Extension | {APPLIED -N / NOT TRIGGERED} | {1M%, 3M%, category} |
| O6 Earnings | {APPLIED +/-N / NOT TRIGGERED} | {EBP or days to earnings} |
| O7 Sell-News | {APPLIED -5 / NOT TRIGGERED} | {Conditions met/not met} |
| O8 Multi-Agent | {APPLIED +/-N / NOT TRIGGERED / N/A} | {Net score if available} |
```

ALL 8 overrides MUST appear. No override may be omitted. This is the audit trail.

### Section 16: Footer & API Manifest [MANDATORY]

```
| Corporate | {ACTIONS or "No pending corporate actions"} |
|---|---|
| Delta | {CHANGE from prior — e.g. "+5 from 45/HOLD → 50/HOLD" or "First analysis"} |
| Sources | {LIST — FMP, TV-Desktop, TV-Analysis, Alpaca, WebSearch} |
| Position | **{POSITION_STATUS}** — {TRANSLATION per Fix 3.2} |

## API Call Manifest
| # | Tool | Status | Notes |
|---|------|--------|-------|
| 1 | {TOOL_NAME} | {OK/FAIL/PARTIAL/INVALID} | {BRIEF_NOTE} |
| ... | | | |
Data Completeness: {SUCCESS}/{TOTAL} = {PCT}%
```

---

## Section Checklist (verify before displaying)

Before displaying the Compact Card, verify:
- [ ] All 16 section headers present
- [ ] Scores table has exactly 8 dimension rows + composite row
- [ ] Override Log has exactly 8 override rows (O1-O8)
- [ ] Options Flow has all 12 metric rows (or explicit N/A)
- [ ] Insider table has 10b5-1 column populated for every insider
- [ ] Institutional table has Staleness row
- [ ] API Manifest lists every tool call made
- [ ] Trade Setup matches signal (WAIT for HOLD+no position, entry for BUY)

---

## Crypto Compact Card

Same 16-section structure but:
- Omit: Fundamental, Valuation, Macro dimension rows from Scores table
- Omit: Sections 8-10 (Insider, Institutional, Congressional)
- Add crypto-specific: exchange volume, whale activity, funding rate

---

## Scan Table (for /scan)

```
=== Watchlist Scan === {DATE} === {COUNT} stocks ===
{MARKET_HOURS_HEADER}
FMP Budget: {USED}/{LIMIT} calls today

| # | Symbol | Price | 1D% | 1M% | Ext | Score | Signal | Tech | Fund | Val | Risk | Coverage | Key Signal |
|---|--------|-------|-----|-----|-----|-------|--------|------|------|-----|------|----------|------------|
| 1 | AMD    | $160  | +2% | +12%| LOW | 72    | BUY    | 9    | 8    | 8   | 4    | Full     | MACD cross |
...

Top Picks: {TOP_3_WITH_REASONS}
Flagged: {EARNINGS_THIS_WEEK} | {HIGH_RISK_STOCKS}
```

---

## Portfolio Dashboard (for /portfolio)

```
=== Portfolio Dashboard === {DATE} ===
{MARKET_HOURS_HEADER}

Account: ${EQUITY} equity | ${BUYING_POWER} buying power | ${CASH} cash
Today: {DAY_PL} ({DAY_PCT}%) | 1W: {WEEK_PL} | 1M: {MONTH_PL}

| Symbol | Qty | Avg Cost | Current | P&L | P&L% | Signal | Alert |
|--------|-----|----------|---------|-----|------|--------|-------|
...

Alerts:
- {EARNINGS_WARNINGS}
- {CONCENTRATION_WARNINGS}
- {OVERBOUGHT_POSITIONS}
- {CORPORATE_ACTION_WARNINGS}
- {WIDE_SPREAD_WARNINGS}

Recent Activity: {LAST_5_FILLS}
```

---

## Compare Output (for /compare)

```
=== {SYM1} vs {SYM2} === {DATE} ===

| Metric | {SYM1} | {SYM2} | Winner |
|--------|--------|--------|--------|
| Price | ... | ... | |
| Technical | X/10 | Y/10 | {WINNER} |
| Fundamental | ... | ... | ... |
...8 dimensions...
| Composite | X/100 | Y/100 | {WINNER} |
| Signal | BUY | HOLD | |

Verdict: {RECOMMENDATION_WITH_REASONING}
```
