# Paper Trade: $ARGUMENTS

Execute a paper trade on Alpaca with pre-trade safety checks. **Always requires user confirmation before executing.**

**Usage:**
- `/project:trade buy AMD 1000` — buy $1000 worth of AMD
- `/project:trade sell AMD 50` — sell 50 shares of AMD
- `/project:trade buy BTCUSD 500` — buy $500 of BTC (crypto)

**Parse $ARGUMENTS:** Extract action (buy/sell), symbol, amount ($ for buy, shares or $ for sell).

---

## Step 1: Pre-Trade Data (5 calls, parallel)

- `mcp__financial-modeling-prep__getQuote` with symbol={parsed symbol} — current price, change%, volume
- `mcp__tradingview-analysis__coin_analysis` with symbol={parsed symbol}, exchange, timeframe="1D" — RSI, MACD, trend signal
- `mcp__alpaca__get_account_info` — equity, buying power, cash
- `mcp__alpaca__get_all_positions` — all current positions (for concentration check)
- `mcp__alpaca__get_open_position` with symbol={parsed symbol} — check if already held

---

## Step 2: Safety Checks

Run ALL checks before proceeding. Block trade if ANY critical check fails.

### Critical Blocks (prevent trade execution)

- **OTC stock:** Block. "Cannot paper trade OTC stocks."
- **Signal contradicts direction:** If buying and coin_analysis shows STRONG SELL, block. "Technical signal contradicts buy direction. Run /project:analyze {SYMBOL} first."
- **Insufficient buying power:** If buying and buying_power < amount, block. "Insufficient buying power: ${buying_power} available, ${amount} requested."
- **Buying power buffer:** If buy would leave < $100 buying power, block. "Would leave < $100 buying power."
- **Position doesn't exist:** If selling and no position held, block. "No position in {SYMBOL} to sell."

### Warnings (display but allow override)

- **Concentration risk:** If position after trade would be > 20% of portfolio, warn. "Position would be {X}% of portfolio (>20% limit)."
- **RSI extreme (buying):** If RSI > 75 and buying, warn. "RSI is {X} — overbought. Consider waiting for pullback."
- **RSI extreme (selling):** If RSI < 25 and selling, warn. "RSI is {X} — oversold. Selling near lows."
- **Already held (buying):** If position exists and buying more, warn. "Already hold {X} shares. This increases concentration to {Y}%."
- **Market closed:** If market closed, warn. "Market is closed. Order will execute at next open. Price may gap."

---

## Step 3: Position Sizing

If buying:
- Shares = floor(amount / current_price)
- Total cost = shares * current_price
- Portfolio % = total_cost / equity * 100
- If existing position: new total % = (existing_value + total_cost) / equity * 100

If selling:
- If amount is in $: shares_to_sell = floor(amount / current_price)
- If amount is in shares: shares_to_sell = amount
- Cannot sell more than held quantity

---

## Step 4: Confirmation

Display trade summary and **ASK USER TO CONFIRM:**

```
=== Trade Confirmation ===
Action: {BUY/SELL}
Symbol: {SYMBOL} @ ${PRICE}
Shares: {X} (${TOTAL})
Portfolio Impact: {X}% of ${EQUITY}
{WARNINGS if any}

Technical: RSI {X} | MACD {signal} | Trend {direction}

Confirm? (yes/no)
```

**DO NOT execute without explicit user confirmation.**

---

## Step 5: Execute

After user confirms:

**For stock buy:**
- Call `mcp__alpaca__place_stock_order` with:
  - symbol={symbol}
  - qty={shares}
  - side="buy"
  - type="market"
  - time_in_force="day"

**For stock sell:**
- Call `mcp__alpaca__place_stock_order` with:
  - symbol={symbol}
  - qty={shares}
  - side="sell"
  - type="market"
  - time_in_force="day"

**For crypto:**
- Call `mcp__alpaca__place_crypto_order` with:
  - symbol={symbol}
  - notional={amount} (for $ amount) or qty={qty}
  - side={buy/sell}
  - type="market"
  - time_in_force="gtc"

---

## Step 6: Post-Trade

After order executes:
- Display order confirmation with order ID
- Show updated position (if buy) or remaining position (if sell)
- Show updated buying power
- Offer: "Run `/project:portfolio` to see updated dashboard"
