---
description: Technical only — multi-timeframe indicators, volume, candle patterns, chart screenshot
argument-hint: "[SYMBOL]"
---

# Technical Analysis: $ARGUMENTS

Run Phases 0, 1, 3, 4, 5, 6 for the given symbol. This is a standalone entry point for technical-only analysis.

**Before starting:** Read `${CLAUDE_PLUGIN_ROOT}/commands/${CLAUDE_PLUGIN_ROOT}/lib/asset-classifier.md` and `${CLAUDE_PLUGIN_ROOT}/commands/${CLAUDE_PLUGIN_ROOT}/lib/error-handling.md` for routing and error handling rules.

---

## Phase 0: Asset Classification & Market Status

**Step 1 — Market clock (1 call, cacheable):**
- Call `mcp__plugin_trading-desk_alpaca__get_clock`
- Record `is_open`, `next_open`, `next_close`
- This determines the market hours header (see `${CLAUDE_PLUGIN_ROOT}/lib/output-formats.md`)

**Step 2 — Asset classification happens in Phase 1 after `getCompanyProfile` returns.**

---

## Phase 1: Price & Identity

**For stocks (3 calls, parallel):**
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getCompanyProfile` with symbol=$ARGUMENTS
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getStockPriceChange` with symbol=$ARGUMENTS
- Call `mcp__plugin_trading-desk_alpaca__get_stock_snapshot` with symbol=$ARGUMENTS

From `getCompanyProfile`, extract: price, change, volume, avgVolume, marketCap, beta, range (52W), sector, industry, CEO, isEtf, isAdr, country, description, exchange.

From `get_stock_snapshot`: extract bid/ask prices and sizes. Calculate spread = (ask - bid) / midpoint * 100. This is a liquidity signal — wide spreads mean higher slippage.

**Asset classification** (from `getCompanyProfile` response — apply `${CLAUDE_PLUGIN_ROOT}/lib/asset-classifier.md`):
- If symbol ends in USDT/USD → Crypto route
- If `isEtf=true` → ETF route
- If `isAdr=true` or `country != "US"` → ADR route
- If exchange = OTC/Pink Sheets → OTC route (warn: limited data)
- Else → Stock (default)

**For crypto:** Replace with `mcp__plugin_trading-desk_financial-modeling-prep__getCryptocurrencyQuote` + `mcp__plugin_trading-desk_financial-modeling-prep__getCryptocurrencyHistoricalLightChart` + `mcp__plugin_trading-desk_alpaca__get_crypto_snapshot`

---

## Phase 3: Multi-Timeframe Technicals

**2 TV-Analysis + 5-9 FMP + 3 context calls, parallel:**
- Call `mcp__plugin_trading-desk_tradingview-analysis__multi_timeframe_analysis` with symbol=$ARGUMENTS and the appropriate exchange (from Phase 1)
- Call `mcp__plugin_trading-desk_tradingview-analysis__coin_analysis` with symbol=$ARGUMENTS, exchange from Phase 1, and timeframe="1D"

From `multi_timeframe_analysis`: extract trend alignment across Weekly, Daily, 4H, 1H, 15m.
From `coin_analysis`: extract RSI, MACD (value + signal + histogram), Stochastic %K/%D, ADX, Bollinger Bands (upper/middle/lower), all SMAs (50, 200) and EMAs, support/resistance levels, market structure.

Record the RSI value — it's used for overbought/oversold overrides in Phase 16.

**FMP Technical Indicators (ALWAYS-ON — not fallback):**
Always fetch FMP technical indicators alongside TradingView data for cross-validation. Two independent data sources are more reliable than one.

**Core indicators (5 calls, parallel):**
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getRSI` with symbol=$ARGUMENTS, periodLength=14, timeframe="1day", from_date={60 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — RSI(14). Cross-validate with TV RSI. If divergence >10 points, use average and flag "RSI DIVERGENCE."
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getSMA` with symbol=$ARGUMENTS, periodLength=50, timeframe="1day", from_date={60 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — SMA(50). Cross-validate with TV.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getSMA` with symbol=$ARGUMENTS, periodLength=200, timeframe="1day", from_date={300 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — SMA(200). Cross-validate with TV.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getEMA` with symbol=$ARGUMENTS, periodLength=20, timeframe="1day", from_date={60 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — EMA(20) for Bollinger midline proxy
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getADX` with symbol=$ARGUMENTS, periodLength=14, timeframe="1day", from_date={60 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — ADX, +DI, -DI. Cross-validate with TV. Also fetch 60-day lookback for regime detection (ADX average).

**Extended indicators (4 calls, parallel):**
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getDEMA` with symbol=$ARGUMENTS, periodLength=20, timeframe="1day", from_date={60 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — Double EMA, faster trend detection than SMA/EMA
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getTEMA` with symbol=$ARGUMENTS, periodLength=20, timeframe="1day", from_date={60 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — Triple EMA, most responsive. Divergence from price = early momentum shift warning
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getWMA` with symbol=$ARGUMENTS, periodLength=20, timeframe="1day", from_date={60 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — Weighted MA, emphasizes recent bars. Slope direction confirms trend
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getWilliams` with symbol=$ARGUMENTS, periodLength=14, timeframe="1day", from_date={60 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — Williams %R oscillator. < -80 = oversold (bullish), > -20 = overbought (bearish). Confirms RSI readings.

**Cross-validation rules:**
- RSI: If TV and FMP within 5 points = high confidence. If >10 points divergence = flag and average.
- SMA/EMA: If TV and FMP within 1% = confirmed. If >3% divergence = flag data quality issue.
- ADX: Use FMP as primary for 60-day average (regime detection). Use TV for current ADX.
- Williams + RSI agreement: both overbought = strong exhaustion signal. Williams overbought + RSI neutral = weak signal, use Williams as early warning only.

**Regime Detection (computed from FMP ADX 60-day data):**
- ADX 60-day average > 25: TRENDING regime
- ADX 60-day average 18-25: TRANSITIONAL regime
- ADX 60-day average < 18: MEAN-REVERTING regime
- Log: "REGIME: {TRENDING/TRANSITIONAL/MEAN-REVERTING} (ADX avg {X})."
- Regime affects indicator interpretation in Phase 16 scoring (see scoring-rubrics.md).

**If TradingView Analysis returns no data (OTC stocks, data gaps):** FMP data becomes the PRIMARY source instead of cross-validation. Apply -1 data gap penalty to Technical score (FMP lacks Stochastic, support/resistance, multi-timeframe alignment).

**Market Context (3 calls, parallel):**
- Call `mcp__plugin_trading-desk_tradingview-analysis__market_snapshot` — global market overview: major indices, sectors, crypto, FX, commodities. Provides context: is this stock outperforming in a down market (very strong) or underperforming in an up market (very weak)?
- Call `mcp__plugin_trading-desk_tradingview-analysis__top_gainers` with exchange from Phase 1 — daily market leaders. If target stock is a top gainer, note relative strength.
- Call `mcp__plugin_trading-desk_tradingview-analysis__top_losers` with exchange from Phase 1 — daily laggards. If target stock is a top loser, note relative weakness.

**Relative Strength Assessment:** Compare stock's 1D performance against market snapshot. If stock is up while market is down, or up more than market: "RELATIVE STRENGTH: Outperforming market by {X}pp." If underperforming: "RELATIVE WEAKNESS: Underperforming market by {X}pp."

**Multi-Period Relative Strength vs Sector ETF:**
Using stock returns from Phase 1 `getStockPriceChange` and sector ETF returns from Phase 2:
| Period | Stock | Sector ETF | Relative Strength |
|--------|-------|-----------|-------------------|
| 1M     | {X}%  | {Y}%      | {X-Y}pp           |
| 3M     | {X}%  | {Y}%      | {X-Y}pp           |
| 6M     | {X}%  | {Y}%      | {X-Y}pp           |

- RS > +10pp on 3M: "OUTPERFORMING SECTOR" → Technical +0.5
- RS < -10pp on 3M: "UNDERPERFORMING SECTOR" → Technical -0.5
- RS sign flip (outperforming on 1M, underperforming on 3M): flag "TREND REVERSAL" in warnings.

---

## Phase 4: Volume & Smart Money

**6 calls, parallel:**
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getShareFloat` with symbol=$ARGUMENTS — extract float size, short interest %, short ratio
- Call `mcp__plugin_trading-desk_tradingview-analysis__smart_volume_scanner` with the exchange from Phase 1
- Call `mcp__plugin_trading-desk_tradingview-analysis__volume_confirmation_analysis` with symbol=$ARGUMENTS and exchange from Phase 1 — confirms whether price advance/decline is backed by volume. Volume-confirmed moves are more reliable. Feeds into Volume Direction Modifier for Technical scoring.
- Call `mcp__plugin_trading-desk_tradingview-analysis__consecutive_candles_scan` with exchange from Phase 1 and timeframe="1D" — detects sequences of consecutive bullish/bearish candles. 5+ consecutive bullish candles before earnings = momentum confirmation signal.
- Call `mcp__plugin_trading-desk_tradingview-analysis__volume_breakout_scanner` with exchange from Phase 1 — identifies stocks with volume breakouts (high volume + price breakout). POST-FILTER for $ARGUMENTS. Volume breakouts confirm trend changes and provide higher-confidence entry signals.
- Call `mcp__plugin_trading-desk_alpaca__get_stock_trades` with symbol=$ARGUMENTS, start={today - 5 days YYYY-MM-DD}, limit=1000 — **Block Trade Detection.** Filter trades with dollar value >= $200K OR size >= 10,000 shares (whichever is met first). Count block trades, compute average block size. If block trades > 5 in last 5 days AND price rising: "INSTITUTIONAL ACCUMULATION (block trades)." If block trades > 5 AND price falling: "INSTITUTIONAL DISTRIBUTION (block trades)." **Feed limitation:** If using IEX feed (free), only IEX exchange trades are returned — block trade detection is unreliable. Note: "BLOCK TRADES: IEX feed only — partial coverage."

**Post-filter `smart_volume_scanner`:** This returns exchange-wide results. Search the response for $ARGUMENTS. If found, extract that symbol's unusual volume data. If not found, note "No unusual volume detected for $ARGUMENTS" (neutral signal, not negative).

**Post-filter `consecutive_candles_scan`:** Search results for $ARGUMENTS. Record consecutive candle count and direction if found.

---

## Phase 5: Candle Patterns & Bollinger Analysis

**2 calls, parallel:**
- Call `mcp__plugin_trading-desk_tradingview-analysis__advanced_candle_pattern` with exchange from Phase 1 and timeframe="1D"
- Call `mcp__plugin_trading-desk_tradingview-analysis__bollinger_scan` with exchange from Phase 1 — identifies stocks in Bollinger squeeze (low volatility → breakout setup) or Bollinger Walk (riding upper/lower band = strong trend). A stock in Bollinger Walk UP = bullish momentum signal, NOT overbought exhaustion.

**Post-filter advanced_candle_pattern:** Search results for $ARGUMENTS. If found, extract active candle patterns (name, type: reversal/continuation, reliability). If not found, note "No significant candle patterns for $ARGUMENTS."

**Post-filter bollinger_scan:** Search for $ARGUMENTS. If in Bollinger Walk UP, record as trend confirmation (supports ADX-conditional RSI interpretation). If in squeeze, record as pending breakout.

---

## Phase 6: Chart — TradingView Desktop

**Always attempt. Graceful failure if Desktop unavailable.**

**Step 1 — Check/launch Desktop (1-2 calls):**
- Call `mcp__plugin_trading-desk_tradingview__tv_health_check`
- If not connected: call `mcp__plugin_trading-desk_tradingview__tv_launch` to auto-start
- If both fail: log "Chart: Desktop unavailable", skip rest of Phase 6. All technical data from Phase 3 is still available.

**Step 2 — Setup chart (2 calls, sequential):**
- Call `mcp__plugin_trading-desk_tradingview__chart_set_symbol` with symbol=$ARGUMENTS
- Call `mcp__plugin_trading-desk_tradingview__chart_set_timeframe` with timeframe="D" (daily)

**Step 3 — Add indicators (1 call with multiple indicators):**
- Call `mcp__plugin_trading-desk_tradingview__chart_manage_indicator` to add: "Relative Strength Index", "MACD", "Bollinger Bands", "Exponential Moving Average" (period 50), "Simple Moving Average" (period 200), "Volume"
- **IMPORTANT:** Use FULL indicator names, not abbreviations

**Step 4 — Read data (3-4 calls, parallel):**
- Call `mcp__plugin_trading-desk_tradingview__data_get_study_values` — read all visible indicator numeric values
- Call `mcp__plugin_trading-desk_tradingview__data_get_pine_labels` — read custom indicator labels (support/resistance if any Pine scripts loaded)
- Call `mcp__plugin_trading-desk_tradingview__depth_get` — order book / DOM: bid/ask walls, order imbalance, spread. Reveals institutional supply/demand levels. Record: if bid depth > 2x ask depth = bullish (institutional demand). Ask > 2x bid = bearish (supply wall).

**Step 5 — Annotate and capture (2 calls):**
- Call `mcp__plugin_trading-desk_tradingview__draw_shape` with type="horizontal_line" for support/resistance levels from Phase 3 `coin_analysis` (blue lines). **Only draw support/resistance here.** Stop loss and take profit are drawn later in Phase 16b (synthesize) after position sizing is computed.
- Call `mcp__plugin_trading-desk_tradingview__capture_screenshot` with region="chart"

---

## Output

Write all collected data to `reports/{SYMBOL}_technical.md` with this structure:

```markdown
# {SYMBOL} Technical Analysis — {DATE}

## Asset Type: {Stock/Crypto/ETF/ADR/OTC}
## Market Status: {OPEN/CLOSED}

## Price & Identity
- Price: $X | Change: X% | Volume: X (vs avg X)
- Market Cap: $X | Beta: X | Sector: X | Industry: X
- 52W Range: $X - $X
- Bid/Ask: $X / $X (spread: X%)
- Momentum: 1D X% | 1M X% | 3M X% | 6M X% | 1Y X%

## Multi-Timeframe Alignment
- Weekly: {BUY/SELL/NEUTRAL}
- Daily: {BUY/SELL/NEUTRAL}
- 4H: {BUY/SELL/NEUTRAL}
- 1H: {BUY/SELL/NEUTRAL}
- 15m: {BUY/SELL/NEUTRAL}
- Alignment: {X}/5 timeframes agree

## Key Indicators (Daily)
- RSI(14): X
- MACD: X (Signal: X, Histogram: X)
- Stochastic: %K X, %D X
- ADX: X
- Bollinger: Upper X, Middle X, Lower X
- SMA50: $X | SMA200: $X
- Support: $X | Resistance: $X

## FMP Cross-Validation
- RSI: TV {X} vs FMP {X} — {CONFIRMED/DIVERGENCE}
- SMA50: TV ${X} vs FMP ${X} — {CONFIRMED/DIVERGENCE}
- SMA200: TV ${X} vs FMP ${X} — {CONFIRMED/DIVERGENCE}
- ADX: TV {X} vs FMP {X} — {CONFIRMED/DIVERGENCE}
- Williams %R: {X} ({overbought/oversold/neutral})
- DEMA(20): ${X} | TEMA(20): ${X} | WMA(20): ${X}

## Regime Detection
- ADX 60-day average: {X}
- Regime: {TRENDING/TRANSITIONAL/MEAN-REVERTING}
- Interpretation: {how this affects indicator readings}

## Market Context
- Market Snapshot: {broad market direction}
- Relative Strength: {outperforming/underperforming by X%}

## Volume & Float
- Float: X shares | Short Interest: X% | Short Ratio: X
- Unusual Volume: {details or "None detected"}

## Candle Patterns
- {pattern details or "None detected"}

## Order Book (if Desktop available)
- Bid Depth vs Ask Depth: {ratio and interpretation}

## Chart
- Screenshot: {saved/unavailable}
- Desktop: {connected/unavailable}

## Data Completeness: {X}%
```
