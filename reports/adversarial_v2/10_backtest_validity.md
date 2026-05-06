# Adversarial Audit: Backtest Validity
## Date: 2026-05-06

I'll start by reading the required files to understand the current methodology.

---

Now let me read the backtest examples from the reports.

---

Now let me also check the full analysis reports for how backtest scores were actually computed in the synthesis phase.

---

Let me read the relevant sections of the AMD and PLTR full reports to understand the adaptive weighting in practice.

---

Now let me also check how the AMD report handled the adaptive weighting and look at the pre-earnings weight switching.

---

Now I have all the data I need. Let me examine one more thing -- whether the AMD report used pre-earnings weights or normal weights.

---

Interesting -- the AMD report does NOT mention pre-earnings weight switching despite earnings being "TOMORROW." Let me verify.

---

This confirms AMD used NORMAL weights (22%, 15%, 15%, etc.) instead of pre-earnings weights, despite earnings being 1 day away. That's a separate bug but relevant to the weight analysis. Now I have everything needed for the audit.

---

# BACKTEST STATISTICAL VALIDITY AUDIT

## Nine Flaws Identified, Quantified, and Remediated

---

### FLAW 1: Statistical Insignificance of Low-Trade-Count Strategies

**Evidence from reports:**
- PLTR RSI strategy: **2 trades** in 1 year. Win rate 50% (1W, 1L). Sharpe 3.70.
- AMD RSI strategy: **1 trade** (100% win rate, Sharpe 129.92, profit factor Infinity).
- AMD MACD strategy: **5 trades** (2W, 3L).
- PLTR EMA Cross: **1 trade** (0% win rate).
- PLTR Donchian: **0 trades**.

**Statistical impact:**

With 2 trades, the 95% confidence interval for win rate is [1.3%, 98.7%] (exact binomial). A reported "50% win rate" is statistically indistinguishable from 0% or 100%. The Sharpe ratio of 3.70 from 2 observations has a standard error of approximately Sharpe/sqrt(n-1) = 3.70/1.0 = 3.70. The 95% CI for Sharpe is [-3.70, +11.10]. This is meaningless.

With 1 trade (AMD RSI), reporting "100% win rate" and "Sharpe 129.92" is not just uninformative -- it is actively misleading. These numbers carry zero predictive value.

**Current mitigation adequacy:**

The Adaptive Backtest Weighting reduces weight from 10% to 2% for <5 trades and caps the score at 2. But the cap of 2 still implies the backtest contains SOME negative information. A score of 2/10 on a dimension weighted at 2% contributes -0.16 to the composite vs a neutral 5/10 score. The impact is tiny but the problem is philosophical: you are treating noise as signal.

**Proposed fix:**
- **<3 trades: Zero weight (0%), score N/A.** Do not score. Do not display Sharpe, win rate, or profit factor. State: "INSUFFICIENT DATA: {N} trades. No statistical inference possible. Backtest dimension excluded."
- **3-4 trades: Weight 1%, cap at 3.** Report metrics with explicit confidence intervals.
- **5-9 trades: Weight 3%, cap at 4.** (Current cap is correct, weight should drop further.)
- **10-14 trades: Weight 7%, cap at 6.**
- **15-29 trades: Weight 10%, no cap.**
- **30+ trades: Weight 10%, no cap, metrics are statistically meaningful.**

Add mandatory CI reporting: "Win rate: 50% [95% CI: 1.3%-98.7%, n=2] -- NOT SIGNIFICANT."

---

### FLAW 2: Walk-Forward Data Overlap (In-Sample Subset of Walk-Forward Period)

**Evidence from reports:**
- Phase 14 instructions: `compare_strategies` uses `period="1y"`. `walk_forward_backtest_strategy` uses `period="2y"`.
- PLTR walk-forward: Avg train return +25.55%, avg test return +5.55%, robustness 0.42.
- AMD walk-forward: Avg train return -3.15%, avg test return 0.0%, robustness 0.0.

**Methodological error:**

The 1-year backtest period is contained WITHIN the 2-year walk-forward period. If the walk-forward tool uses k-fold cross-validation (which it appears to -- "3 folds"), then one of the training folds almost certainly includes the exact same data used to select the "best" strategy. This is data leakage. The strategy was selected because it performed best on the 1-year window. When that same window appears as training data in walk-forward, the "validation" is partially circular.

**Quantified impact:**

With 3 folds on 2 years, each fold trains on ~16 months and tests on ~8 months. The 1-year selection period overlaps approximately 67-100% with at least one training fold. The robustness score is therefore biased upward. A stock where the true robustness is 0.25 might report 0.42 (PLTR's case) because the walk-forward partially validates on in-sample performance.

**Proposed fix:**

Change walk-forward to `period="3y"` or `period="4y"`, ensuring the most recent 1 year (the in-sample period) is ALWAYS a test fold, never a training fold. Alternatively:
```
walk_forward_backtest_strategy(
  symbol=$ARGUMENTS,
  strategy={best strategy},
  period="3y",
  # Ensure in-sample period (most recent 1y) is reserved as final test fold
)
```
If the tool does not support explicit fold control, use `period="5y"` so the 1-year in-sample is at most 20% of total data, reducing leakage impact to one of five folds.

Document: "WALK-FORWARD DATA NOTE: In-sample period (1y) may overlap with walk-forward training folds. Robustness score should be interpreted conservatively."

---

### FLAW 3: Strategy Selection Bias (All Technical, No Diversification)

**Evidence:**

The 6 strategies tested are: RSI, Bollinger Bands, MACD, EMA Crossover, Supertrend, Donchian Channel. All are **trend-following or mean-reversion technical indicators**. No:
- Fundamental strategies (buy when P/E < sector median, sell when P/E > 2x median)
- Event-driven strategies (buy N days before earnings if beat probability > 80%)
- Statistical arbitrage (pairs trading, sector relative strength)
- Volatility strategies (sell straddles when IV/HV > 1.5)
- Seasonal strategies (sell in May, January effect)

**Quantified impact:**

The backtest evaluates the hypothesis "can ANY technical strategy beat buy-and-hold?" The answer for momentum stocks (PLTR +24.85%, AMD +264.92%) is consistently NO. But this does not mean "no strategy works" -- it means "no TECHNICAL strategy works." The conclusion "No mechanical strategy outperforms buy-and-hold for PLTR" (from the report) is an overgeneralization. The correct conclusion is: "No mean-reversion or trend-following technical strategy outperforms buy-and-hold."

For a stock like AMD with B&H +264.92%, a simple momentum strategy ("buy when above 200 SMA, hold") would have captured most of the move. But Donchian (0 trades) and EMA Cross (-15%) failed because their specific parameters missed the regime.

**Proposed fix:**
- Add at minimum 2 non-technical strategies to the compare_strategies pool: (a) "Buy-and-Hold with trailing stop" (not tested -- this is the strategy most long-term holders actually use), (b) "Earnings momentum" (buy after earnings beat, hold for 60 days).
- Add a note to the report: "STRATEGY UNIVERSE: Technical only (6 strategies). Fundamental, event-driven, and volatility strategies not evaluated."
- Weight the backtest score interpretation accordingly: if all 6 technical strategies fail but the stock trends strongly, this is informative about TIMING but not about the stock's tradability.

---

### FLAW 4: Data Source Mismatch (Yahoo Finance vs Alpaca Execution)

**Evidence:**

Phase 14 uses `mcp__tradingview-analysis__compare_strategies` and `mcp__tradingview-analysis__backtest_strategy`, which source data from Yahoo Finance via the TV-Analysis MCP. Actual trades execute on Alpaca. Differences include:
- Yahoo Finance prices are exchange-reported OHLCV. Alpaca uses consolidated tape but may fill at different prices (mid-market, NBBO).
- Yahoo Finance adjusts for splits/dividends retroactively. Alpaca historical data may differ around corporate action dates.
- Pre/post-market moves visible on Alpaca are absent from Yahoo daily bars.

**Quantified impact:**

For liquid large-caps (PLTR, AMD), the price difference is typically <0.1% intraday. For a strategy with 5 trades, cumulative slippage from data mismatch is ~0.5%. This is small relative to strategy returns of 40%+ but significant relative to marginal strategies (PLTR RSI at +5.73% -- a 0.5% drag reduces it to ~5.2%).

For less liquid stocks, the mismatch could be 0.5-2% per trade, potentially flipping marginally profitable strategies to losers.

**Proposed fix:**
- Add a blanket disclaimer: "DATA SOURCE: Backtests use Yahoo Finance (via TradingView). Execution uses Alpaca. Price divergence estimated at 0.1-0.5% per trade for liquid stocks."
- For the Desktop cross-validation (Step 2), use Alpaca historical data if possible, creating a true venue-aligned backtest.
- Apply a haircut: reduce reported strategy returns by 0.3% per trade as a data-source adjustment.

---

### FLAW 5: Buy-and-Hold Penalty Calibration

**Evidence from rubric:**

Current rules:
- B&H > 100%: Penalty WAIVED.
- B&H > 50% AND strategy > 0: Penalty reduced to -1.
- B&H > 0% AND strategy < 0: Full -2.
- B&H < 0% AND strategy > 0: BONUS +2.

**The gap:** B&H between 20-50% is treated with the full -2 penalty. Consider:
- Stock returns 25% B&H. Best strategy returns 18%. Delta = -7%. Penalty: -2.
- Stock returns 25% B&H. Best strategy returns 2%. Delta = -23%. Penalty: -2.

Both receive the same -2, despite vastly different underperformance. The 18% strategy is genuinely useful (captures 72% of B&H with presumably lower drawdown), while the 2% strategy is genuinely bad.

**Quantified impact:**

In the PLTR case: B&H +24.85%, RSI +5.73%. The -2 penalty is applied, dropping the score from cap-2 to min-1. This is arguably correct (strategy captured only 23% of B&H). But for a hypothetical stock with B&H +25% and strategy +20%, the same -2 would be excessive.

**Proposed fix -- graduated B&H penalty:**

| B&H Return | Strategy vs B&H | Penalty |
|-----------|----------------|---------|
| > 100% | Any | WAIVED |
| 50-100% | Strategy > 0 | -1 |
| 20-50% | Strategy > B&H * 0.7 (captures 70%+) | -1 |
| 20-50% | Strategy < B&H * 0.7 (captures <70%) | -2 |
| 0-20% | Strategy > 0 | -1 |
| 0-20% | Strategy < 0 | -2 |
| < 0% | Strategy > 0 | +2 BONUS |
| < 0% | Strategy < 0 | -1 |

This introduces a "capture ratio" concept: if the strategy captures >70% of B&H returns, it is penalized less because it likely achieved this with lower risk. The 70% threshold is based on Sharpe-efficient frontiers where a strategy capturing 70% of returns with 50% of drawdown has a higher risk-adjusted return.

---

### FLAW 6: Robustness Score Ignores Absolute Return Magnitude

**Evidence:**

The walk-forward robustness score appears to be: `test_return / train_return`.
- PLTR: Train +25.55%, Test +5.55%. Robustness = 5.55/25.55 = **0.217** (but reported as 0.42, suggesting a different formula, possibly averaged across folds).
- AMD: Train -3.15%, Test 0.0%. Robustness = 0.0/-3.15 = **0.0**.

**Problem:** A strategy with train return +2% and test return +1.8% has robustness 0.90 (excellent). But both returns are below the risk-free rate (~5% annualized). The strategy is "robustly mediocre." Meanwhile, a strategy with train +50% and test +25% has robustness 0.50 (mediocre), but test performance of +25% is excellent.

**Quantified impact:**

A "robustly mediocre" strategy (robustness 0.90, test return +2%) would NOT trigger the overfitting halving rule (robustness > 0.3). The backtest dimension keeps full weight despite the strategy being economically useless.

**Proposed fix -- Dual-gate robustness:**

```
Effective Robustness = min(
  ratio_robustness,           # test_return / train_return (0.0 to 1.0+)
  magnitude_robustness        # 1.0 if test_return > risk_free_rate, 
                              # test_return / risk_free_rate otherwise
)
```

Thresholds:
- If `test_return < 3%` (annualized, below T-bill): robustness capped at 0.5, regardless of ratio.
- If `test_return < 0%`: robustness = 0.0 (strategy loses money out-of-sample).
- Add to report: "Robustness: 0.42 (ratio) | Test return: +5.55% (above risk-free) | Effective robustness: 0.42"

---

### FLAW 7: Missing Desktop Cross-Validation Has No Score Penalty

**Evidence:**

Both PLTR and AMD reports state: "Desktop Cross-Validation: N/A" / "Desktop unavailable -- no cross-validation available." The rubric says: "If TV-Analysis and Desktop Strategy Tester diverge by >20%, cap at 5 + flag OVERFIT WARNING." But there is NO rule for when Desktop is unavailable.

**Quantified impact:**

Desktop cross-validation serves as a second-opinion check on backtest reliability. Without it, the single-source backtest from TV-Analysis carries full scoring weight. In practice, Desktop is "unavailable" in most runs (it requires TradingView Desktop to be open with the correct strategy loaded). This means the cross-validation safeguard effectively never fires.

The probability of backtest overfitting without cross-validation is higher. Academic literature suggests single-source backtests overstate returns by 30-50% on average (due to survivorship bias, look-ahead bias, and data-snooping). The cross-validation rule exists to catch this, but if it never executes, the protection is illusory.

**Proposed fix:**
- When Desktop is unavailable: reduce effective backtest weight by 20% (e.g., from 10% to 8%).
- Add a mandatory note: "NO CROSS-VALIDATION: Backtest results are single-source (TV-Analysis via Yahoo Finance). Returns may overstate live performance by 30-50%. Weight reduced by 20%."
- If Desktop IS available and results agree within 20%: add a +1 bonus to backtest score ("CROSS-VALIDATED").

Updated Adaptive Backtest Weighting table with cross-validation modifier:

| Trades | Desktop Available | Effective Weight |
|--------|------------------|-----------------|
| < 5 | No | 1.6% (2% * 0.8) |
| < 5 | Yes, agrees | 2.4% (2% * 1.2) |
| 5-9 | No | 4.0% (5% * 0.8) |
| 15+ | No | 8.0% (10% * 0.8) |
| 15+ | Yes, agrees | 10% (full) |

---

### FLAW 8: Zero Transaction Cost Modeling

**Evidence:**

Neither the `compare_strategies` nor `backtest_strategy` calls include any slippage or commission parameters. The rubric mentions that Desktop Strategy Tester has "commission/slippage modeling" but this is only used in the cross-validation step, which (per Flaw 7) almost never runs.

**Quantified impact:**

Alpaca charges $0 commission for stocks, but there IS slippage:
- Bid-ask spread: For PLTR (spread ~$0.01 on a ~$136 stock, ~0.007% per side) and AMD (spread ~$0.02 on a ~$360 stock, ~0.006% per side), slippage is minimal.
- Market impact for position sizes of 100-200 shares: negligible for these large-caps.
- Total round-trip cost: ~0.015% for liquid large-caps.

With PLTR RSI (2 trades = 2 round trips): cost drag = ~0.03%. Negligible.
With AMD MACD (5 trades = 5 round trips): cost drag = ~0.075%. Negligible.

But for a higher-frequency strategy or a less liquid stock:
- 50 trades/year at 0.1% round-trip = 5% annual drag.
- 50 trades/year at 0.5% round-trip (mid-cap) = 25% annual drag.

**Proposed fix:**

Since the current strategies generate very few trades (2-8/year), transaction costs are immaterial for the stocks currently analyzed. However, to be methodologically correct:
- Apply a flat 0.05% round-trip cost deduction per trade to reported strategy returns.
- Formula: `adjusted_return = reported_return - (num_trades * 0.0005 * avg_position_size / initial_capital)`
- For PLTR RSI (2 trades): adjustment = ~0.1%. Reported 5.73% becomes ~5.63%.
- For AMD MACD (5 trades): adjustment = ~0.25%. Reported 40.37% becomes ~40.12%.
- Flag if adjustment changes the ranking of strategies.

---

### FLAW 9: Adaptive Weight Redistribution Incompatibility with Pre-Earnings Weights

**Evidence:**

The rubric defines two weight systems:

**Normal weights:** Technical 22%, Fundamental 15%, Valuation 15%, Smart Money 13%, Risk 12%, Backtest 10%, Sentiment 7%, Macro 6%.

**Pre-earnings weights:** Technical 12%, Fundamental 22%, Valuation 12%, Sentiment 20%, Smart Money 13%, Macro 8%, Risk 10%, Backtest 3%.

The Adaptive Backtest Weighting says: "Redistribution is proportional to remaining dimension weights."

**The math with normal weights (working correctly):**

If backtest has <5 trades: effective weight drops from 10% to 2%. 8% redistributed proportionally.

Remaining weights sum to 90% (100% - 10% backtest). Each dimension gets:
- Technical: 22/90 * 8% = +1.96% -> 23.96%
- Fundamental: 15/90 * 8% = +1.33% -> 16.33%
- Valuation: 15/90 * 8% = +1.33% -> 16.33%
- Smart Money: 13/90 * 8% = +1.16% -> 14.16%
- Risk: 12/90 * 8% = +1.07% -> 13.07%
- Sentiment: 7/90 * 8% = +0.62% -> 7.62%
- Macro: 6/90 * 8% = +0.53% -> 6.53%
- Backtest: 2%
- **Total: 100.00%** (correct)

**The math with pre-earnings weights (the problem):**

Pre-earnings backtest weight is already 3%. Adaptive weighting for <5 trades reduces to 2%. Only 1% is redistributed.

Remaining pre-earnings weights sum to 97% (100% - 3% backtest). Each dimension gets:
- Technical: 12/97 * 1% = +0.12% -> 12.12%
- Fundamental: 22/97 * 1% = +0.23% -> 22.23%
- Sentiment: 20/97 * 1% = +0.21% -> 20.21%
- Smart Money: 13/97 * 1% = +0.13% -> 13.13%
- Macro: 8/97 * 1% = +0.08% -> 8.08%
- Risk: 10/97 * 1% = +0.10% -> 10.10%
- Valuation: 12/97 * 1% = +0.12% -> 12.12%
- Backtest: 2%
- **Total: 99.99%** (rounding, but correct)

**The real problem is NOT the math -- it is the semantic interaction:**

Pre-earnings already demotes backtest to 3% because "Technical oscillators and Backtest results have near-zero predictive power for earnings gap moves." The Adaptive Weighting then further reduces 3% to 2% for low trade counts. But the Adaptive Weighting was calibrated against a 10% base, not a 3% base. Reducing from 10% to 2% (80% reduction) is a strong signal that the backtest is unreliable. Reducing from 3% to 2% (33% reduction) is a weak signal.

**But there is a deeper issue with the AMD report:** AMD's earnings were 1 day away, but the report used NORMAL weights (22%, 15%, 15%, etc.) instead of pre-earnings weights. The pre-earnings weight switch was never applied. This means:
- Backtest weight was 10% instead of the mandated 3%.
- Technical weight was 22% instead of the mandated 12%.
- Sentiment weight was 7% instead of the mandated 20%.

**Quantified impact on AMD composite:**

With pre-earnings weights:
| Dimension | Score | Pre-Earnings Wt | Weighted |
|-----------|------:|----------------:|---------:|
| Technical | 5 | 12% | 0.60 |
| Fundamental | 8 | 22% | 1.76 |
| Valuation | 3 | 12% | 0.36 |
| Smart Money | 5 | 13% | 0.65 |
| Risk | 3 | 10% | 0.30 |
| Backtest | 2 | 3% | 0.06 |
| Sentiment | 7 | 20% | 1.40 |
| Macro | 7 | 8% | 0.56 |
| **Total** | | **100%** | **5.69** |

Pre-earnings composite: **57/100** (before overrides) vs the reported 49/100 with normal weights. After the same overrides (-5 overbought, -5 extension), the pre-earnings composite would be **47/100 (HOLD)** instead of the reported **39/100 (SELL)**. This is an 8-point swing that changes the signal from SELL to HOLD.

**Proposed fix for the weight systems:**
1. **Fix the AMD bug:** Pre-earnings weight switching must be enforced when earnings are within 7 calendar days. The Phase 14 instructions should add an explicit check: "If earnings within 7 days (from Phase 11/13), use Pre-Earnings weights in Phase 16."
2. **Calibrate adaptive weighting for both base rates:**

| Trade Count | Normal Base (10%) | Effective | Pre-Earnings Base (3%) | Effective |
|------------|-------------------|-----------|------------------------|-----------|
| < 3 | 0% | 0% | 0% | 0% |
| 3-4 | 1% | -9% | 0.5% | -2.5% |
| 5-9 | 5% | -5% | 1.5% | -1.5% |
| 10-14 | 8% | -2% | 2.5% | -0.5% |
| 15+ | 10% | full | 3% | full |

This ensures adaptive reductions are proportionally equivalent regardless of base weight.

---

## Summary of Impact Severity

| Flaw | Severity | Impact on Score | Frequency |
|------|----------|----------------|-----------|
| 1. Low trade count as signal | HIGH | +/-1 point composite | Every momentum stock |
| 2. Walk-forward data overlap | HIGH | Robustness biased up ~50% | Every run |
| 3. Technical-only strategies | MEDIUM | Misleading "no strategy works" conclusion | Every run |
| 4. Yahoo vs Alpaca data | LOW | ~0.1-0.5% per trade | Every run, small impact |
| 5. B&H penalty calibration | MEDIUM | Up to 1 point composite swing | B&H 20-50% stocks |
| 6. Robustness ignores magnitude | MEDIUM | Mediocre strategies score well | Low-volatility stocks |
| 7. Missing cross-validation | HIGH | No overfitting detection | Most runs (Desktop rarely available) |
| 8. Zero transaction costs | LOW | <0.5% for current trade counts | Every run, small impact |
| 9. Weight system incompatibility + AMD bug | CRITICAL | 8-point composite swing, signal change | Every pre-earnings analysis |

The most critical finding is **Flaw 9**: the AMD report used normal weights when pre-earnings weights were required, resulting in a SELL signal that should have been a HOLD. This is not a statistical subtlety -- it is a direct implementation error that changed the actionable recommendation.

The second most critical finding is **Flaw 2**: the walk-forward period overlapping with the in-sample period undermines the entire purpose of walk-forward validation. Every "robustness score" reported is potentially inflated because of data leakage.