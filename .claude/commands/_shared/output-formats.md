# Output Formats Reference

Templates for consistent output across all commands.

---

## Market Hours Header (from `Alpaca: get_clock`)

- `is_open=true`: `Market OPEN — live data | VIX: {value} ({label})`
- `is_open=false`: `Market CLOSED (opens {next_open}) — data reflects last close. Volume/options data may be stale. | VIX: {value} ({label})`

VIX labels: <15 = "calm", 15-20 = "normal", 20-25 = "elevated", 25-30 = "fear", >30 = "PANIC"

---

## Compact Card (Default for /analyze)

```
=== {SYMBOL} Analysis === {DATE} === Score: {COMPOSITE}/100 ===
{MARKET_HOURS_HEADER}
{SIGNAL} ({CONFIDENCE}) | Data: {COMPLETENESS}% complete | {ASSET_TYPE_LABEL}

Tech: {T}/10 | Fund: {F}/10 | Val: {V}/10 ({TRACK_LABEL}) | Sent: {S}/10
Smart$: {SM}/10 | Macro: {M}/10 | BT: {BT}/10 | Risk: {R}/10

Valuation: {TRACK_DETAIL}
         DCF range: ${STD} (standard) / ${LEV} (levered) / ${CUSTOM} (custom)
         Analyst consensus: ${TARGET} ({UPSIDE}%) from {COUNT} analysts (s=${STDDEV})
         Earnings: {BEAT_MISS_SUMMARY}

Sentiment: Reddit {REDDIT_SIGNAL} ({PCT}%) | Twitter {TW_SIGNAL} | StockTwits {ST_PCT}% bulls
          News NLP: {POS} positive, {NEU} neutral, {NEG} negative ({KEY_TOPIC})
          Analyst: {UPGRADES} upgrades, {DOWNGRADES} downgrades last 30d

Options: P/C Vol {PC_RATIO} ({LABEL}) | IV/HV {IVHV} | Expected Move +/-${EM} (+/-{EM_PCT}%)
        Max Pain: ${MP} | Unusual: {UNUSUAL_ACTIVITY}
        Net Delta: {DELTA} ({DELTA_LABEL})

Best Strategy: {STRATEGY_NAME} ({RETURN}% return, {SHARPE} Sharpe, {TRADES} trades)
  {CROSS_VALIDATION_NOTE}
Entry: ${PRICE} (current) | Stop: ${STOP} ({STOP_PCT}%) | TP: ${TP} ({TP_PCT}%)
  Bid/Ask spread: ${SPREAD} ({SPREAD_LABEL})
Position: {SHARES} shares / ${AMOUNT} ({PCT_PORTFOLIO}% of ${EQUITY} account)

{OVERRIDE_WARNINGS}
Top Risks: {RISK_LIST}
Top Catalysts: {CATALYST_LIST}
Corporate: {CORPORATE_ACTIONS}
Delta: {DELTA_FROM_PREV}
===================================================
```

---

## Crypto Compact Card

Same structure but omit: Fund, Val, Macro rows. Show crypto-specific Smart Money (exchange volume, whale activity).

---

## Scan Table (for /scan)

```
=== Watchlist Scan === {DATE} === {COUNT} stocks ===
{MARKET_HOURS_HEADER}
FMP Budget: {USED}/{LIMIT} calls today

| # | Symbol | Price | 1D% | Score | Signal | Tech | Fund | Val | Risk | Coverage | Key Signal |
|---|--------|-------|-----|-------|--------|------|------|-----|------|----------|------------|
| 1 | AMD    | $160  | +2% | 72    | BUY    | 9    | 8    | 8   | 4    | Full     | MACD cross |
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
