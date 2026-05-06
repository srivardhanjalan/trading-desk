# Technical Analysis: $ARGUMENTS

Run Phases 0, 1, 3, 4, 5, 6 for the given symbol. This is a standalone entry point for technical-only analysis.

**Before starting:** Read `.claude/commands/_shared/asset-classifier.md` and `.claude/commands/_shared/error-handling.md` for routing and error handling rules.

---

## Phase 0: Asset Classification & Market Status

**Step 1 — Market clock (1 call, cacheable):**
- Call `mcp__alpaca__get_clock`
- Record `is_open`, `next_open`, `next_close`
- This determines the market hours header (see `_shared/output-formats.md`)

**Step 2 — Asset classification happens in Phase 1 after `getCompanyProfile` returns.**

---

## Phase 1: Price & Identity

**For stocks (3 calls, parallel):**
- Call `mcp__financial-modeling-prep__getCompanyProfile` with symbol=$ARGUMENTS
- Call `mcp__financial-modeling-prep__getStockPriceChange` with symbol=$ARGUMENTS
- Call `mcp__alpaca__get_stock_snapshot` with symbol=$ARGUMENTS

From `getCompanyProfile`, extract: price, change, volume, avgVolume, marketCap, beta, range (52W), sector, industry, CEO, isEtf, isAdr, country, description, exchange.

From `get_stock_snapshot`: extract bid/ask prices and sizes. Calculate spread = (ask - bid) / midpoint * 100. This is a liquidity signal — wide spreads mean higher slippage.

**Asset classification** (from `getCompanyProfile` response — apply `_shared/asset-classifier.md`):
- If symbol ends in USDT/USD → Crypto route
- If `isEtf=true` → ETF route
- If `isAdr=true` or `country != "US"` → ADR route
- If exchange = OTC/Pink Sheets → OTC route (warn: limited data)
- Else → Stock (default)

**For crypto:** Replace with `mcp__financial-modeling-prep__getCryptocurrencyQuote` + `mcp__financial-modeling-prep__getCryptocurrencyHistoricalLightChart` + `mcp__alpaca__get_crypto_snapshot`

---

## Phase 3: Multi-Timeframe Technicals

**2 calls, parallel:**
- Call `mcp__tradingview-analysis__multi_timeframe_analysis` with symbol=$ARGUMENTS and the appropriate exchange (from Phase 1)
- Call `mcp__tradingview-analysis__coin_analysis` with symbol=$ARGUMENTS, exchange from Phase 1, and timeframe="1D"

From `multi_timeframe_analysis`: extract trend alignment across Weekly, Daily, 4H, 1H, 15m.
From `coin_analysis`: extract RSI, MACD (value + signal + histogram), Stochastic %K/%D, ADX, Bollinger Bands (upper/middle/lower), all SMAs (50, 200) and EMAs, support/resistance levels, market structure.

Record the RSI value — it's used for overbought/oversold overrides in Phase 16.

**FMP Technical Fallback (when TradingView Analysis returns no data — common for OTC stocks):**
If BOTH `multi_timeframe_analysis` and `coin_analysis` return errors or empty data, fall back to FMP technical indicators:
- Call `mcp__financial-modeling-prep__getRSI` with symbol=$ARGUMENTS, periodLength=14, timeframe="1day", from_date={60 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — RSI(14) daily values
- Call `mcp__financial-modeling-prep__getSMA` with symbol=$ARGUMENTS, periodLength=50, timeframe="1day", from_date={60 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — SMA(50)
- Call `mcp__financial-modeling-prep__getSMA` with symbol=$ARGUMENTS, periodLength=200, timeframe="1day", from_date={300 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — SMA(200)
- Call `mcp__financial-modeling-prep__getEMA` with symbol=$ARGUMENTS, periodLength=20, timeframe="1day", from_date={60 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — EMA(20) for Bollinger midline proxy
- Call `mcp__financial-modeling-prep__getADX` with symbol=$ARGUMENTS, periodLength=14, timeframe="1day", from_date={60 days ago YYYY-MM-DD}, to={today YYYY-MM-DD} — ADX, +DI, -DI

Note: FMP fallback does NOT provide Stochastic, support/resistance, or multi-timeframe alignment. Apply -1 data gap penalty to Technical score when using FMP fallback. TradingView Desktop (Phase 6) can still provide visual confirmation and indicator values.

---

## Phase 4: Volume & Smart Money

**4 calls, parallel:**
- Call `mcp__financial-modeling-prep__getShareFloat` with symbol=$ARGUMENTS — extract float size, short interest %, short ratio
- Call `mcp__tradingview-analysis__smart_volume_scanner` with the exchange from Phase 1
- Call `mcp__tradingview-analysis__volume_confirmation_analysis` with symbol=$ARGUMENTS and exchange from Phase 1 — confirms whether price advance/decline is backed by volume. Volume-confirmed moves are more reliable. Feeds into Volume Direction Modifier for Technical scoring.
- Call `mcp__tradingview-analysis__consecutive_candles_scan` with exchange from Phase 1 and timeframe="1D" — detects sequences of consecutive bullish/bearish candles. 5+ consecutive bullish candles before earnings = momentum confirmation signal.

**Post-filter `smart_volume_scanner`:** This returns exchange-wide results. Search the response for $ARGUMENTS. If found, extract that symbol's unusual volume data. If not found, note "No unusual volume detected for $ARGUMENTS" (neutral signal, not negative).

**Post-filter `consecutive_candles_scan`:** Search results for $ARGUMENTS. Record consecutive candle count and direction if found.

---

## Phase 5: Candle Patterns & Bollinger Analysis

**2 calls, parallel:**
- Call `mcp__tradingview-analysis__advanced_candle_pattern` with exchange from Phase 1 and timeframe="1D"
- Call `mcp__tradingview-analysis__bollinger_scan` with exchange from Phase 1 — identifies stocks in Bollinger squeeze (low volatility → breakout setup) or Bollinger Walk (riding upper/lower band = strong trend). A stock in Bollinger Walk UP = bullish momentum signal, NOT overbought exhaustion.

**Post-filter advanced_candle_pattern:** Search results for $ARGUMENTS. If found, extract active candle patterns (name, type: reversal/continuation, reliability). If not found, note "No significant candle patterns for $ARGUMENTS."

**Post-filter bollinger_scan:** Search for $ARGUMENTS. If in Bollinger Walk UP, record as trend confirmation (supports ADX-conditional RSI interpretation). If in squeeze, record as pending breakout.

---

## Phase 6: Chart — TradingView Desktop

**Always attempt. Graceful failure if Desktop unavailable.**

**Step 1 — Check/launch Desktop (1-2 calls):**
- Call `mcp__tradingview__tv_health_check`
- If not connected: call `mcp__tradingview__tv_launch` to auto-start
- If both fail: log "Chart: Desktop unavailable", skip rest of Phase 6. All technical data from Phase 3 is still available.

**Step 2 — Setup chart (2 calls, sequential):**
- Call `mcp__tradingview__chart_set_symbol` with symbol=$ARGUMENTS
- Call `mcp__tradingview__chart_set_timeframe` with timeframe="D" (daily)

**Step 3 — Add indicators (1 call with multiple indicators):**
- Call `mcp__tradingview__chart_manage_indicator` to add: "Relative Strength Index", "MACD", "Bollinger Bands", "Exponential Moving Average" (period 50), "Simple Moving Average" (period 200), "Volume"
- **IMPORTANT:** Use FULL indicator names, not abbreviations

**Step 4 — Read data (3-4 calls, parallel):**
- Call `mcp__tradingview__data_get_study_values` — read all visible indicator numeric values
- Call `mcp__tradingview__data_get_pine_labels` — read custom indicator labels (support/resistance if any Pine scripts loaded)
- Call `mcp__tradingview__depth_get` — order book / DOM: bid/ask walls, order imbalance, spread. Reveals institutional supply/demand levels. Record: if bid depth > 2x ask depth = bullish (institutional demand). Ask > 2x bid = bearish (supply wall).

**Step 5 — Annotate and capture (2 calls):**
- Call `mcp__tradingview__draw_shape` with type="horizontal_line" for support/resistance levels from Phase 3 `coin_analysis` (blue lines). **Only draw support/resistance here.** Stop loss and take profit are drawn later in Phase 16b (synthesize) after position sizing is computed.
- Call `mcp__tradingview__capture_screenshot` with region="chart"

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
