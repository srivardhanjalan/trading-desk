# Adversarial Audit: Position Awareness & Portfolio Context
## Date: 2026-05-06

I'll start by reading the two referenced files to understand the current system design.

---

Now let me also check for the output-formats file to see how signals are displayed, and look at whether there's any position-awareness logic already defined.

---

Now let me also check if there's any existing rules.json or configuration that might have position-awareness settings.

---

Now I have a thorough understanding of the system. Let me compile the adversarial audit.

---

## Adversarial Audit: Position Awareness and Portfolio Context

After reading `scoring-rubrics.md`, `synthesize.md`, `trade.md`, `portfolio.md`, and `output-formats.md`, here are the eight flaws and proposed fixes.

---

### Flaw 1: SELL Signal on Non-Held Stock Is Semantically Wrong

**Where it breaks:** `synthesize.md` Phase 15 calls `get_open_position` to check if the stock is held. But this data is never fed back into the signal logic in Phase 16. The Decision Thresholds table (scoring-rubrics.md lines 425-429) maps composite 25-39 to "SELL" and describes the action as "Reduce/exit position." If the user has no position, "reduce/exit" is meaningless.

**Evidence of the gap:** The Quality-Timing Safety Check (synthesize.md line 173) says "QUALITY FLOOR: High-quality business prevents SELL signal." But there is no analogous "POSITION EXISTENCE CHECK" that modifies the signal text. The system will output "SELL" with action "Reduce/exit position" to someone who holds zero shares.

**Proposed fix -- add to `scoring-rubrics.md` after Decision Thresholds:**

```
## Position-Aware Signal Translation (Phase 16, Step 4b)

After determining the raw signal, cross-reference with get_open_position result:

| Raw Signal   | Position Held | Translated Signal | Action Text                          |
|-------------|---------------|-------------------|--------------------------------------|
| STRONG BUY  | No            | STRONG BUY        | Open aggressive position             |
| STRONG BUY  | Yes           | STRONG BUY (ADD)  | Add to existing; check 20% cap       |
| BUY         | No            | BUY               | Open standard position               |
| BUY         | Yes           | BUY (ADD)         | Add to existing; check 20% cap       |
| HOLD        | No            | DON'T BUY         | No entry at this time                |
| HOLD        | Yes (< target)| HOLD              | Maintain current position            |
| HOLD        | Yes (> target)| TRIM TO TARGET     | Reduce to standard allocation size   |
| SELL        | No            | AVOID             | Do not enter; short candidate only   |
| SELL        | Yes           | SELL              | Reduce/exit position                 |
| STRONG SELL | No            | AVOID             | Do not enter                         |
| STRONG SELL | Yes           | STRONG SELL       | Exit immediately                     |

Always display BOTH raw signal and translated signal:
"Signal: SELL (raw) → AVOID (no position held)"
```

---

### Flaw 2: Position Sizing Ignores Existing Holdings

**Where it breaks:** `synthesize.md` lines 45-50 compute position size and "Cap at 20% of portfolio." But this cap is applied to the NEW position size only. The system never subtracts the existing position value. If the user already holds 15% in AMD and the system recommends another 15%, the total becomes 30%, violating the diversification limit.

**Evidence:** `trade.md` line 52 does handle this correctly: "If existing position: new total % = (existing_value + total_cost) / equity * 100." But `synthesize.md` (the recommendation engine that feeds the output card) does NOT perform this check. The recommended position size in the output card is computed as if the user holds nothing.

**Proposed fix -- replace in `synthesize.md` Position Sizing section:**

```
**Position Sizing (Fixed-Fractional, Position-Aware):**
- Risk per trade = equity * 0.02 (2% risk)
- Stop loss = support level from Phase 3, or entry - (ATR * 2), or entry * 0.97 (3% max)
- Max new position ($) = equity * 0.20 (diversification limit)
- If get_open_position returns existing holding:
  - existing_value = current_price * existing_qty
  - existing_pct = existing_value / equity * 100
  - remaining_room = max(0, 20% - existing_pct) * equity
  - Cap position size at remaining_room
  - If remaining_room <= 0: position size = 0; note "POSITION CAP: Already at
    {existing_pct}% allocation. No additional sizing available."
- Position size (shares) = min(risk_per_trade / (entry_price - stop_loss), remaining_room / entry_price)
- Report: "Existing: {existing_pct}% | New: {new_pct}% | Total: {total_pct}%"
```

---

### Flaw 3: Stop Loss Ignores Existing Cost Basis

**Where it breaks:** `synthesize.md` lines 57-61 compute stop loss as "nearest support from Phase 3 (if within 5% of entry)" or "entry * 0.97 (never risk more than 3%)." The "entry" here is the current market price, not the user's actual cost basis. For a user who bought at $100 and the stock is now $150, the system sets stop at $145.50 (3% below $150). This locks in a 45.5% gain on any trigger. But for a user who bought at $140, the same stop is only protecting 3.9%. The risk context is completely different.

**The system has the data:** `get_open_position` returns avg_entry_price. It is fetched but unused in stop/target calculations.

**Proposed fix -- add to `synthesize.md` Stop Loss Level section:**

```
**Cost-Basis-Aware Stop Loss (when position is held):**
If get_open_position returns a position:
- cost_basis = avg_entry_price from Alpaca
- unrealized_pct = (current_price - cost_basis) / cost_basis * 100
- If unrealized_pct > 20%: use trailing stop at max(support, entry * 0.95)
  to protect gains. Note: "TRAILING STOP: +{unrealized_pct}% unrealized gain.
  Stop set to protect at least {protected_pct}% of gain."
- If unrealized_pct between 0% and 20%: use standard stop (entry * 0.97)
- If unrealized_pct < 0% (underwater):
  - compute cost_basis_stop = cost_basis * 0.90 (10% max loss from entry)
  - use tighter of cost_basis_stop and standard stop
  - Note: "UNDERWATER: Entry ${cost_basis}, currently ${current_price}
    ({unrealized_pct}%). Stop set relative to cost basis."
- Always report: "Your entry: ${cost_basis} | Stop: ${stop} |
  Risk from your entry: {risk_from_entry_pct}%"
```

---

### Flaw 4: No Sector/Correlation Concentration Check Across Portfolio

**Where it breaks:** The system checks single-position concentration (>20% cap) but has zero concept of sector concentration. If the user holds AMD (semiconductor), NVDA (semiconductor), CRDO (semiconductor), and the system recommends buying ASML (semiconductor), there is no warning about 60%+ semiconductor exposure.

**Evidence:** `portfolio.md` Step 5 lists concentration risk as "Any single position > 20% of portfolio" only. `trade.md` Step 2 checks the same single-position limit. Neither checks sector totals. The Macro dimension scores sector ETF performance but this is about the sector's health, not the portfolio's exposure to it.

**Proposed fix -- add to `synthesize.md` Phase 15 after Position Sizing:**

```
**Portfolio Sector Concentration Check:**
From get_all_positions (already called in trade.md, add to synthesize.md):
1. For each held position, look up sector via getCompanyProfile (cache from Phase 1)
2. Compute sector_exposure = sum(position_value for all positions in same sector
   as $ARGUMENTS) / equity * 100
3. Compute proposed_total = sector_exposure + new_position_value / equity * 100

| Sector Exposure After Trade | Action                                       |
|----------------------------|------------------------------------------------|
| > 40%                       | BLOCK: "SECTOR CONCENTRATION: {sector} would   |
|                              | be {X}% of portfolio. Max 40%."                |
| 30-40%                      | WARNING: "HIGH SECTOR EXPOSURE: {sector} at    |
|                              | {X}%. Consider diversifying."                  |
| < 30%                       | No warning                                     |

Add to output card Warnings table when triggered.
```

**Also add to `portfolio.md` Step 5:**

```
- **Sector concentration:** Group positions by sector. Flag any sector > 30% of portfolio.
  Display in alerts: "SECTOR CONCENTRATION: {sector} = {X}% ({N} positions: {symbols})"
```

---

### Flaw 5: HOLD Signal Is Ambiguous for Position Sizing

**Where it breaks:** The Decision Thresholds say HOLD means "No new position" (scoring-rubrics.md line 427). But for someone who holds 1000 shares (25% of portfolio, overweight), HOLD means "keep your overweight position," which contradicts the 20% cap rule. For someone who holds 0 shares, HOLD means "don't buy." These are different recommendations disguised as the same word.

**The Position-Aware Signal Translation from Flaw 1 partially addresses this**, but HOLD specifically needs a position-size-relative interpretation.

**Proposed fix -- add HOLD sub-classification to the Position-Aware Signal Translation table:**

```
**HOLD Sub-Classification (requires get_open_position + get_account_info):**

| HOLD + Position State            | Sub-Signal        | Action                              |
|----------------------------------|-------------------|-------------------------------------|
| HOLD + no position               | WAIT              | "Not a buy at this price/time."     |
| HOLD + position < 10% portfolio  | HOLD (UNDERWEIGHT) | "Position small. Add on dips if     |
|                                  |                   | score improves to BUY."             |
| HOLD + position 10-20% portfolio | HOLD              | "Position at target allocation.     |
|                                  |                   | No action needed."                  |
| HOLD + position > 20% portfolio  | TRIM              | "Overweight at {X}%. Trim to 20%   |
|                                  |                   | or below. Sell {Y} shares."         |
| HOLD + position > 30% portfolio  | TRIM (URGENT)     | "Dangerously overweight at {X}%.    |
|                                  |                   | Trim to 20%. Sell {Y} shares."      |

Always report position context: "You hold {qty} shares ({pct}% of portfolio).
HOLD means: {sub-signal explanation}."
```

---

### Flaw 6: No Dollar-Cost Averaging or Position Management Concept

**Where it breaks:** The system is purely binary: BUY (open new), HOLD (do nothing), SELL (close). There is no concept of "add to a losing position at a better price" or "scale out of a winning position." If a stock was BUY at $100 (user bought 50 shares), drops to $80 and now scores HOLD (composite 45), the system says "no action." But this might be a superior averaging opportunity if the fundamentals haven't changed.

**Evidence:** The Quality-Timing matrix (scoring-rubrics.md line 369) has "Quality >= 60, Timing < 40 = HOLD -- strong business, bad timing. DO NOT SELL." This is exactly the scenario where DCA is most appropriate, but the system never says "consider adding."

**Proposed fix -- add new section to `scoring-rubrics.md` after Decision Thresholds:**

```
## Position Management Signals (Supplementary)

When get_open_position returns an existing holding, compute additional signals:

**DCA Opportunity Detection:**
IF Quality >= 60 AND Timing < 40 AND position is held AND unrealized_pnl < -10%:
  Signal: "DCA OPPORTUNITY: Quality business ({Quality}/100) at depressed timing
  ({Timing}/100). Unrealized loss: {pnl}%. Consider averaging down to lower
  cost basis from ${cost_basis} toward ${current_price}."
  - DCA size = min(existing_position_size * 0.50, remaining_20%_room)
  - New avg cost = (existing_qty * cost_basis + dca_shares * current_price) /
    (existing_qty + dca_shares)
  - Report: "DCA would move avg cost from ${old} to ${new} ({improvement}%)"

**Scale-Out Detection:**
IF position is held AND unrealized_pnl > +30% AND (RSI > 70 OR Extension >= HIGH):
  Signal: "SCALE OUT: +{pnl}% unrealized gain with {risk_condition}. Consider
  selling {25-50}% to lock in gains. Remaining position is 'free' (house money)."

**Rebalance Detection:**
IF position is held AND position_pct deviates from target_allocation by > 5pp:
  Signal: "REBALANCE: Position drifted to {pct}% (target: {target}%).
  {BUY/SELL} {shares} to rebalance."
```

---

### Flaw 7: No Tax-Awareness in SELL Timing

**Where it breaks:** The system has no concept of holding period. A SELL signal on a stock held for 11 months (taxed at short-term capital gains, potentially 37% federal) versus one held for 13 months (taxed at long-term capital gains, potentially 20% federal) is a materially different recommendation. The user could save 17% in taxes by waiting 30 days.

**The system has the data:** `get_open_position` returns the position, and `get_account_activities` (used in portfolio.md) returns fill dates. The original purchase date can be derived.

**Proposed fix -- add to `synthesize.md` Phase 16, after Step 4 (signal determination):**

```
**Step 4c -- Tax Efficiency Check (SELL/STRONG SELL only, US equities):**
When signal is SELL or STRONG SELL and get_open_position returns a holding:
1. Retrieve earliest buy fill from get_account_activities for this symbol
2. holding_days = today - earliest_fill_date
3. days_to_ltcg = max(0, 366 - holding_days)

| Condition                       | Action                                      |
|--------------------------------|-----------------------------------------------|
| holding_days >= 366             | No modifier. Note: "LONG-TERM HOLDING:        |
|                                 | LTCG rate applies."                           |
| days_to_ltcg <= 30 AND signal   | Downgrade SELL → HOLD for 30 days. Note:      |
| is SELL (not STRONG SELL)       | "TAX HOLD: {days_to_ltcg} days to LTCG.       |
|                                 | Waiting saves ~17% in tax on ${gain}. SELL    |
|                                 | after {date}. Set stop at ${stop} to protect."|
| days_to_ltcg <= 30 AND signal   | WARNING only (do not override STRONG SELL).   |
| is STRONG SELL                  | "TAX NOTE: {days_to_ltcg} days to LTCG, but   |
|                                 | STRONG SELL overrides tax optimization."       |
| days_to_ltcg > 30              | No modifier. Note: "SHORT-TERM HOLDING:        |
|                                 | {holding_days} days. STCG rate applies."       |

Display in output card: "Holding period: {days} days | Tax status: {STCG/LTCG} |
LTCG in: {days_to_ltcg} days ({target_date})"
```

---

### Flaw 8: Quality Floor Ignores Unrealized P&L Severity

**Where it breaks:** `scoring-rubrics.md` line 374: "NEVER produce SELL when Quality >= 60 unless the stock is held and has hit stop loss." And `synthesize.md` line 173: "After all overrides, if composite < 40 BUT Quality Score >= 60: OVERRIDE to HOLD."

This means a stock with Quality 62 that has dropped 40% from the user's entry is forced to HOLD. The Quality Floor was designed to prevent selling good businesses on bad timing. But a 40% drawdown on a held position is not merely "bad timing" -- it may indicate the quality assessment itself was wrong, or that the quality thesis has not yet been reflected in the price over a significant period.

**The critical nuance:** The existing exception -- "unless the stock is held and has hit stop loss" -- is insufficient because the stop loss is set at 3% below current price, not 40% below cost basis. By the time the stock drops 40%, the stop loss has been recalculated dozens of times.

**Proposed fix -- modify the Quality Floor rule in both files:**

```
**Quality Floor (Revised with P&L Gate):**

After all overrides, if composite < 40 (SELL territory) AND Quality >= 60:
1. Check get_open_position for unrealized P&L
2. Apply tiered floor:

| Unrealized P&L    | Quality Floor Behavior                           |
|-------------------|----------------------------------------------------|
| No position       | Standard floor: override to HOLD (40). "QUALITY    |
|                   | FLOOR: Good business, bad timing."                 |
| P&L > -15%        | Standard floor: override to HOLD (40). "QUALITY    |
|                   | FLOOR: Drawdown within normal range."              |
| P&L -15% to -30%  | Weakened floor: override to HOLD (35). "QUALITY    |
|                   | FLOOR WEAKENED: Significant drawdown ({pnl}%).     |
|                   | Review thesis. Set hard stop at cost_basis * 0.70."|
| P&L < -30%        | Floor DISABLED. Allow SELL signal through.          |
|                   | "QUALITY FLOOR SUSPENDED: {pnl}% drawdown exceeds |
|                   | quality protection threshold. Thesis may be broken.|
|                   | Exit or confirm thesis with /research {SYMBOL}."  |
| P&L < -50%        | Force SELL regardless of Quality. "QUALITY FLOOR   |
|                   | OVERRIDDEN: Catastrophic drawdown ({pnl}%).        |
|                   | Fundamental thesis invalidated by price action."   |

Additionally, if Quality >= 60 AND unrealized P&L < -20% AND holding_days > 180:
  Add warning: "THESIS DURATION WARNING: Held {days} days with {pnl}% loss.
  Quality score says hold, but the market disagrees for {months} months.
  Run /research {SYMBOL} to verify thesis."
```

---

### Summary of Systemic Issue

The root cause across all eight flaws is the same: **the scoring system was designed as a stock evaluator, not a portfolio manager.** It answers "Is this stock good?" but not "Is this stock good *for this user, given what they already own?*" The system fetches position data (`get_open_position` in Phase 15, `get_all_positions` in `trade.md`) but treats it as metadata for the output card rather than as an input to the scoring and signal logic.

The fixes above can be grouped into a single new section in `scoring-rubrics.md` called **"Position Context Layer"** that sits between the Overrides and the Decision Thresholds:

```
## Position Context Layer (applied AFTER overrides, BEFORE final signal)

This layer transforms the raw market-quality signal into a position-aware
recommendation. Requires: get_open_position, get_all_positions, get_account_info,
get_account_activities.

Inputs consumed:
- existing_qty, avg_entry_price, unrealized_pnl, market_value (from get_open_position)
- all_positions with sectors (from get_all_positions + getCompanyProfile cache)
- equity, buying_power (from get_account_info)
- fill dates (from get_account_activities)

Outputs modified:
1. Signal text (Flaw 1: position-aware translation)
2. Position size (Flaw 2: subtract existing holdings from 20% cap)
3. Stop loss (Flaw 3: cost-basis-relative stops)
4. Sector concentration warning (Flaw 4: cross-portfolio sector check)
5. HOLD sub-classification (Flaw 5: trim/wait/hold disambiguation)
6. DCA/scale-out signals (Flaw 6: position management)
7. Tax efficiency flag (Flaw 7: LTCG timing on SELL)
8. Quality Floor P&L gate (Flaw 8: disable floor on severe drawdowns)
```

This would be the single highest-impact addition to the system. Every other dimension, override, and modifier is well-engineered for stock-level analysis. The portfolio-context gap is the remaining blind spot.