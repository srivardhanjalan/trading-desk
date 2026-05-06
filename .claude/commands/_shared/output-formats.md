# Output Formats Reference

Templates for consistent output across all commands.

---

## Market Hours Header (from `Alpaca: get_clock`)

- `is_open=true`: `Market OPEN — live data | VIX: {value} ({label})`
- `is_open=false`: `Market CLOSED (opens {next_open}) — data reflects last close. Volume/options data may be stale. | VIX: {value} ({label})`

VIX labels: <15 = "calm", 15-20 = "normal", 20-25 = "elevated", 25-30 = "fear", >30 = "PANIC"

---

## Compact Card (Default for /analyze)

Use markdown tables throughout for clean, consistent rendering. All sections use tables.

### Header

```
# {SYMBOL} — {COMPANY_NAME} | {DATE}

| | |
|---|---|
| **Price** | ${PRICE} ({CHANGE_PCT}%) |
| **Sector** | {SECTOR} / {INDUSTRY} |
| **Score** | **{COMPOSITE}/100 — {SIGNAL}** |
| **Confidence** | {CONF} |
| **Data** | {COMPLETENESS}% complete |
| **Market** | {MARKET_HOURS_HEADER} |
```

### Scores

```
| Dimension | Score | Bar | Weight | Key Driver |
|-----------|------:|-----|-------:|------------|
| Technical | {T}/10 | {T_BAR} | 22% | {T_DRIVER} |
| Fundamental | {F}/10 | {F_BAR} | 15% | {F_DRIVER} |
| Valuation | {V}/10 | {V_BAR} | 15% | {V_DRIVER} |
| Smart Money | {SM}/10 | {SM_BAR} | 13% | {SM_DRIVER} |
| Risk (10=safest) | {R}/10 | {R_BAR} | 12% | {R_DRIVER} |
| Backtest | {BT}/10 | {BT_BAR} | 10% | {BT_DRIVER} |
| Sentiment | {S}/10 | {S_BAR} | 7% | {S_DRIVER} |
| Macro | {M}/10 | {M_BAR} | 6% | {M_DRIVER} |
| **Composite** | **{RAW}/100** | | | Overrides: {OVERRIDES_APPLIED} → **{FINAL}/100** |
```

After the scores table, add the **Quality-Timing** and **Momentum Extension** rows:

```
### Quality vs Timing
| Sub-Score | Value | Components | Guidance |
|-----------|------:|------------|----------|
| **Quality** | {Q}/100 | Fund {F} × 0.30 + Val {V} × 0.25 + Smart {SM} × 0.25 + Macro {M} × 0.20 | "Should I own this?" |
| **Timing** | {T_SCORE}/100 | Tech {T} × 0.35 + Risk {R} × 0.25 + Sent {S} × 0.20 + BT {BT} × 0.20 | "Should I buy now?" |
| **Matrix** | | Quality {Q_LABEL} + Timing {T_LABEL} | → {MATRIX_SIGNAL} |
```

If pre-earnings weights active, add: `⚡ PRE-EARNINGS WEIGHTS: Earnings in {N} days. Fund/Sentiment emphasized.`

```
### Momentum
| Period | 1D | 5D | 1M | 3M | 6M | 1Y |
|--------|---:|---:|---:|---:|---:|---:|
| Change | {1D}% | {5D}% | {1M}% | {3M}% | {6M}% | {1Y}% |

**Extension Risk: {CATEGORY}** — {1M_DESCRIPTION}. Override 5: {MODIFIER_APPLIED}.
Categories: EXTREME (1M>=80%) | SEVERE (60-80%) | HIGH (45-60%) | MODERATE (30-45%) | LOW (15-30%) | NONE (<15%). Market cap scaling applied: >$100B=1.0x, $10-100B=1.2x, $2-10B=1.5x, <$2B=2.0x.
```

Bar format: `████████░░` for 8/10 — use `█` filled, `░` empty, 10 chars.
Key Driver: one-line reason for the score (e.g. "4/5 TF bullish, RSI 79 overbought").

### Valuation

```
| Metric | Value | Note |
|--------|------:|------|
| **Valuation Track** | {TRACK_LABEL} | {TRACK_REASON} |
| PEG (or P/E for Track A) | {PEG_VALUE} | {PEG_LABEL} |
| PSG (if Track B) | {PSG_VALUE} | {PSG_LABEL} |
| DCF — Standard | ${STD} | {STD_NOTE} |
| DCF — Levered | ${LEV} | {LEV_NOTE} |
| DCF — Custom | ${CUSTOM} | {CUSTOM_NOTE} |
| Analyst Target | ${TARGET} ({UPSIDE}%) | {COUNT} analysts, {RATING_BREAKDOWN} |
| Next Earnings | {EARNINGS_DATE} | EPS est {EPS_EST}, Rev est {REV_EST} |
```

For Track B growth stocks, add a note row: "DCF unreliable for high-growth — PEG is primary metric"

### Sentiment

```
| Source | Signal | Detail |
|--------|--------|--------|
| Reddit | {REDDIT_SIGNAL} | {REDDIT_DETAIL} |
| StockTwits | {ST_SIGNAL} | {ST_DETAIL} |
| Twitter/X | {TW_SIGNAL} | {TW_DETAIL} |
| News NLP | {NEWS_SIGNAL} | {NEWS_DETAIL} |
| Analyst Actions | {ANALYST_SIGNAL} | {ANALYST_DETAIL} |
```

### Options Flow

```
| Metric | Value | Interpretation |
|--------|------:|----------------|
| P/C Volume Ratio | {PC_RATIO} | {PC_LABEL} |
| IV/HV Ratio | {IVHV} | {IVHV_LABEL} |
| IV Skew | Put {PUT_IV}% / Call {CALL_IV}% | {SKEW_LABEL} |
| Expected Move | +/-${EM} (+/-{EM_PCT}%) | {EM_CONTEXT} |
| Max Pain | ${MP} | {MP_VS_PRICE} |
| Unusual Activity | {UNUSUAL_STRIKES} | {UNUSUAL_DETAIL} |
```

### Insider & Institutional

Insider table (60-day window):

```
| Date | Name | Role | Action | Shares | Price | Value |
|------|------|------|--------|-------:|------:|------:|
| {rows} |
| **Net** | | | **{NET_LABEL}** | | | **${NET_VALUE}** |
```

Institutional (latest COMPLETE 13F quarter — never use partial):

```
| Metric | Current | Prior Q | Change |
|--------|--------:|--------:|-------:|
| Holders | {INST_HOLDERS} | {PREV_HOLDERS} | {CHANGE} |
| 13F Shares | {SHARES} | {PREV_SHARES} | {SHARE_CHANGE} |
| Ownership % | {OWN_PCT}% | {PREV_OWN}% | {OWN_CHANGE} |
| New Positions | {NEW} | | |
| Increased | {INC} | | |
| Closed | {CLOSED} | | |
| Reduced | {RED} | | |
```

### Congressional Activity

```
| Chamber | Member | Action | Amount | Date |
|---------|--------|--------|-------:|------|
| Senate | {rows from getSenateTrades} |
| House | {rows from getHouseTrades} |
```

If both empty: `No congressional trading activity detected.`

### Backtest

```
| Strategy | Return | Win Rate | Sharpe | Trades |
|----------|-------:|---------:|-------:|-------:|
| **{BEST}** | **{RETURN}%** | **{WR}%** | **{SHARPE}** | **{TRADES}** |
| {2nd} | ... | ... | ... | ... |
| Buy & Hold | {BH_RETURN}% | | | — |
| Walk-Forward | {WF_STATUS} | | | |
| Desktop Cross-Val | {DESKTOP_STATUS} | | | |
```

**Backtest scoring gates (from rubric, apply in order):**
1. Trade count gate: <5 trades → cap 2, 5-9 → cap 4, 10-14 → cap 6, 15+ → no cap
2. Buy-and-hold benchmark (revised): B&H > 100% → penalty WAIVED. B&H > 50% + strategy profitable → -1 only. Strategy loses in rising market → full -2.
3. Walk-forward: if robustness < 0.3 or OVERFITTED → halve backtest effective weight + flag warning
4. Adaptive weight: effective backtest weight adjusted per trade count (see rubric). Redistributed weight goes proportionally to other dimensions.

### Trade Setup

```
| | Price | % from Current |
|---|------:|---------------:|
| Entry | ${PRICE} | — |
| Stop Loss | ${STOP} | {STOP_PCT}% |
| Take Profit | ${TP} | +{TP_PCT}% |
| **R:R Ratio** | **{RR}** | |
| Spread | ${SPREAD} | {SPREAD_LABEL} |
| Position Size | {SHARES} sh / ${AMOUNT} | {PCT_PORTFOLIO}% of ${EQUITY} |
```

### Warnings

```
| Severity | Warning | Impact |
|----------|---------|--------|
| {ICON} | {WARNING_TEXT} | {SCORE_IMPACT} |
```

Severity levels: `!!!` CRITICAL (blocks trade), `!!` WARNING (score penalty), `!` CAUTION (informational).

### Risks & Catalysts

```
| Risks | Catalysts |
|-------|-----------|
| {RISK_1} | {CATALYST_1} |
| {RISK_2} | {CATALYST_2} |
| ... | ... |
```

### Footer

```
| Corporate | {CORPORATE_ACTIONS} |
|---|---|
| Delta | {DELTA_FROM_PREV — score change from last analysis, or "First analysis"} |
| Sources | FMP, TV-Analysis, Alpaca, WebSearch |
```

**Rendering notes:**
- Bar chars: use `█` for filled, `░` for empty (10 chars total per dimension)
- {TRACK_LABEL}: "Track A: DCF" or "Track B: PEG" (or "Track B: PSG" if negative earnings)
- 13F quarter: ALWAYS use most recent COMPLETE quarter (45-day filing lag). Partial quarters mislead.
- Key Driver column: keeps the score table self-contained — reader doesn't need to scroll to understand each score
- All numbers right-aligned in tables for readability

---

## Crypto Compact Card

Same structure but omit: Fund, Val, Macro rows. Show crypto-specific Smart Money (exchange volume, whale activity).

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

## Morning Brief (for /morning-brief)

```
=== Morning Brief === {DATE} ===
{MARKET_HOURS_HEADER}

MARKET OVERVIEW
{MARKET_SNAPSHOT_DATA}
VIX: {VIX} ({VIX_LABEL}) | 10Y: {YIELD}%

PORTFOLIO ({POSITION_COUNT} positions)
Today: {DAY_PL} | Alerts: {ALERT_COUNT}
{TOP_MOVERS_IN_PORTFOLIO}

WATCHLIST MOVERS (>3% change)
{MOVERS_WITH_AH_PRICES}

SCANNERS
Top Gainers: {TOP_3}
Volume Breakouts: {TOP_3}
Bollinger Squeezes: {TOP_3}

EARNINGS THIS WEEK
{EARNINGS_LIST_WITH_EXPECTED_MOVE}

CORPORATE ACTIONS
{SPLITS_DIVIDENDS_MERGERS}

NEWS HIGHLIGHTS
{TOP_5_NEWS}

TRADE IDEAS
{TOP_2_SETUPS_WITH_REASONING}
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

---

## Full Mode (--full flag)

Complete 16-phase detailed report with:
- All data tables from each phase
- Raw indicator values
- Full options chain analysis
- Complete news NLP breakdown
- Detailed scoring justification per dimension
- Chart screenshot (if Desktop available)
