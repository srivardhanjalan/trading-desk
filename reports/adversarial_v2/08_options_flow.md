# Adversarial Audit: Options Flow & Smart Money
## Date: 2026-05-06

I'll start by reading the three files to understand the current scoring rubrics, sentiment analysis pipeline, and the PLTR report.

---

Now I have a thorough understanding of all three files. Let me examine some additional details that will sharpen the analysis -- specifically looking at how the option chain filtering is actually implemented and whether there are any additional context clues in the codebase.

---

No existing references to historical expected moves or OI thresholds -- confirming these gaps are unaddressed. Here is the full adversarial audit.

---

## Adversarial Audit: Options Flow & Smart Money Scoring

### Flaw 1: Put/Call Volume Ratio Conflates Hedging with Directional Positioning

**What the rubric says:** `>1.0 = bearish, <0.7 = bullish, 0.7-1.0 = neutral` (line 51 of `analyze-sentiment.md`).

**Why this is wrong:** The rubric treats all put volume as directionally bearish. In reality, put volume has at least three distinct sources with opposite implications:

1. **Protective hedging by existing long holders.** Before earnings, institutions holding large positions buy puts as insurance. This drives P/C ratios above 1.0 -- but the signal is "confident enough to hold through earnings, just capping downside." That is neutral-to-bullish, not bearish.
2. **Directional bearish bets.** Speculators buying puts outright to profit from a decline. This is genuinely bearish.
3. **Put selling (premium collection).** Market makers or sophisticated traders selling puts, which generates put volume but is actually a bullish/neutral position (the seller is short volatility, not short delta).

The PLTR report itself demonstrates this confusion. The May 15 expiry showed a P/C ratio of 1.71, and the report interpreted it as "hedging for continued post-earnings volatility." If it is hedging, the rubric should not score it as bearish -- yet the threshold says `>1.0 = bearish`. The report intuitively overrode the rubric, which means the rubric is inadequate.

**Evidence from the PLTR report:** The institutional P/C ratio from 13F filings shifted from 0.986 to 1.043 while institutions simultaneously added 79.7M shares (+6.4%). Institutions were buying stock AND buying puts. The rubric would score the puts as bearish, but the combined position is bullish-with-protection.

**Proposed fix:** Add contextual modifiers to the P/C ratio interpretation:

```
Put/Call Volume Ratio — Context-Adjusted:
- If earnings within 7 days: Shift bearish threshold from >1.0 to >1.5. 
  P/C 1.0-1.5 pre-earnings = "HEDGING OVERLAY — elevated puts likely protective, not directional."
- If institutional ownership >40% AND P/C >1.0: Check 13F share changes.
  Institutions adding shares + adding puts = "PROTECTIVE HEDGING — bullish with downside protection."
  Institutions reducing shares + adding puts = "CONFIRMED BEARISH — directional positioning."
- Require cross-reference with unusual activity: if the high-volume put contracts 
  cluster at deep OTM strikes (>10% below current price), it is more likely hedging.
  If puts cluster at ATM or slightly OTM (2-5% below), it is more likely directional.
```

---

### Flaw 2: IV Skew Interpretation Lacks Market Microstructure Context

**What the rubric says:** `Positive [put IV > call IV] = fear premium. >5% = significant.` The implied inverse is that negative skew (calls > puts) is bullish.

**Why this is wrong:** The rubric conflates two completely different causes of reverse IV skew:

1. **Retail speculative call buying.** Retail traders buying OTM calls bids up call IV relative to puts. This is noisy, often wrong, and frequently a contrarian bearish signal. When retail is euphoric, call IV spikes and the stock often underperforms.
2. **Informed institutional positioning.** When sophisticated buyers accumulate calls before a known catalyst (e.g., a contract announcement that has leaked or been rumored), call IV rises. This is genuinely bullish.
3. **Market maker hedging dynamics.** When market makers sell calls to meet retail demand, they hedge by buying stock (positive gamma), which can temporarily support the stock. But once the event passes and IV crushes, they unwind the hedges, creating selling pressure. The "bullish" signal was transient.

**Evidence from the PLTR report:** The ATM IV skew was -0.184 (calls 18+ points higher IV than puts). The report correctly noted this is "ABNORMAL" and called it a "contrarian bullish signal." But it also acknowledged the stock had just dropped 3.13% post-earnings. The elevated call IV was likely retail traders buying OTM lottery tickets ($140-$149 calls on a $136 stock), not informed positioning. The "Most Active Strikes" section confirmed: call activity concentrated in OTM strikes ($140-$149), labeled by the report itself as "retail lottery tickets." Yet the composite scoring gave IV skew a +1 bullish score.

**Proposed fix:**

```
IV Skew — Qualified Interpretation:
- Negative skew (Call IV > Put IV):
  - If unusual call volume is concentrated >5% OTM: "RETAIL SPECULATION — 
    not informed flow. Score as neutral (0), not bullish."
  - If unusual call volume is concentrated ATM to +3% OTM with large block sizes 
    (>1000 contracts per order): "POTENTIALLY INFORMED FLOW — score as +1 bullish."
  - If both occur simultaneously: "MIXED POSITIONING — score as neutral."
- Positive skew (Put IV > Call IV):
  - If >5%: "FEAR PREMIUM" (existing rule is fine here)
  - If 2-5%: "NORMAL EQUITY SKEW — equities naturally trade with put skew 
    due to portfolio insurance demand. Score as neutral, not mildly bearish."
```

The key principle: normal equity skew has puts trading higher than calls. A small positive skew (2-5%) is the DEFAULT state, not a fear signal. Only deviations from the norm carry information.

---

### Flaw 3: Expected Move Has No Historical Calibration

**What the rubric says:** Compute expected move from the ATM straddle price and also from `Price x ATM_IV x sqrt(DTE/365)`.

**Why this is wrong:** An expected move is only useful in context. If the market prices in a 4.7% move but the stock has historically moved 8-12% on earnings, the options market is UNDERPRICING risk. Conversely, if the market prices in 10% but the stock typically moves 3-5%, options are overpriced and premium sellers have an edge.

This comparison is fundamental to volatility trading and earnings plays. Without it, the expected move metric is informational but not actionable.

**Evidence from the PLTR report:** The straddle-implied move was 4.7% and the IV-derived move was 9.6%. The report noted the discrepancy but had no historical baseline to judge whether either was high or low relative to PLTR's typical earnings reaction. Given that PLTR's earnings transcript revealed "85% revenue growth, accelerating for 11th consecutive quarter," and the stock moved -3.13% post-earnings, a historical comparison would have revealed whether this was a muted reaction (suggesting the selloff is nearly complete) or a typical reaction (suggesting more downside).

**Proposed fix:** Add a required step to Phase 10:

```
Step 2.5 — Historical Earnings Move Calibration (1 call, sequential after Step 1):

- Call mcp__financial-modeling-prep__getEarningsReports with symbol=$ARGUMENTS, limit=8
- For each of the last 8 earnings dates, compute the absolute 1-day price change 
  (close-to-close spanning the earnings date)
- Calculate: avg_historical_move = mean(abs(1-day changes))
- Compare: move_ratio = expected_move_pct / avg_historical_move

Interpretation:
- move_ratio > 1.3: "OPTIONS OVERPRICING RISK — market expects larger move than 
  historical average. Premium sellers favored."
- move_ratio 0.7-1.3: "FAIRLY PRICED — expected move aligns with historical behavior."
- move_ratio < 0.7: "OPTIONS UNDERPRICING RISK — market expects smaller move than 
  typical. Consider straddle/strangle purchase. Hedging may be cheap."

Report as: "Expected move: +/-X% | Historical avg earnings move: +/-Y% | 
Move ratio: Z (overpriced/fair/underpriced)"
```

The 1-day price changes can be derived from the `getEarningsReports` data (which includes the earnings date) combined with `getStockBars` or `getLightChart` for the surrounding price data. This is one additional API call at most.

---

### Flaw 4: Net Delta Exposure Requires Data That Is Consistently Unavailable

**What the rubric says:** `sum(call OI * call delta) - sum(put OI * abs(put delta)). Positive = market net long.`

**Why this is wrong on two levels:**

**Level 1 — Data availability:** The PLTR report showed that OI is not available from Alpaca snapshots. Without OI, the formula cannot be computed as defined. The report improvised with "volume-weighted delta as proxy," computing `avg_delta x total_volume` for each side. This proxy has a critical flaw: volume measures flow (how many contracts traded today), while OI measures positioning (how many contracts are held). A contract could be opened (new OI), closed (reducing OI), or rolled (both). High volume with flat OI means churning, not net positioning. The proxy conflates activity with conviction.

**Level 2 — Even with OI, the metric is questionable:** Net delta exposure from public options data tells you what the aggregate market delta is, but it does not tell you who holds it. Market makers are delta-neutral by design (they hedge with stock), so their delta contribution is misleading -- they hold large OI but their net delta is effectively zero when combined with their stock hedges. The "net delta" of the entire options market is primarily a function of end-user positioning, but you cannot separate market maker OI from end-user OI with public data.

**Evidence from the PLTR report:** The computed net delta was -1,836 delta-equivalent shares, described as "marginally bearish." On a stock with 87.7M shares trading daily, -1,836 delta-shares is noise. The metric provided no useful signal yet consumed analysis space and contributed to the composite scoring.

**Proposed fix:** Replace Net Delta Exposure with a metric that uses available data:

```
REPLACE "Net Delta Exposure" WITH "Call/Put Volume-Weighted Delta Skew":

Calculation:
- call_avg_delta = sum(call_volume * call_delta) / sum(call_volume)
- put_avg_delta = sum(put_volume * abs(put_delta)) / sum(put_volume)
- delta_skew = call_avg_delta - put_avg_delta

Interpretation:
- delta_skew > 0.15: "SPECULATIVE CALLS — flow concentrated in high-delta 
  (ATM/ITM) calls. Directional conviction."
- delta_skew < -0.15: "PROTECTIVE PUTS — flow concentrated in high-delta 
  (ATM/ITM) puts. Fear-driven."
- Between: "NEUTRAL FLOW — balanced positioning."

This uses volume (which IS available) and individual contract deltas (which 
Alpaca DOES return in snapshots). It answers a useful question: are traders 
buying high-conviction (near-ATM) options or low-conviction (far-OTM) options?

If OI becomes available in the future, reinstate the original metric alongside 
this one. But do not report "N/A" for a metric that carries 10% of the 
composite score -- either replace it or remove its weight.
```

---

### Flaw 5: Max Pain Has Weak Predictive Power and Uses an OI-Dependent Proxy

**What the rubric says:** Max pain is the "price magnet near expiry."

**Why this is wrong:**

1. **Academic evidence is weak.** The max pain theory relies on the assumption that market makers manipulate price toward the strike where the most options expire worthless, maximizing their profit. But empirical studies (Ni, Pearson, Poteshman 2005; Goyal and Saretto 2009) show that while expiration-week price clustering near round strikes exists, it is driven by hedging flow mechanics (gamma exposure), not intentional manipulation. The "magnetic" effect is small (typically <1% for liquid stocks) and unreliable.

2. **Institutional ownership matters.** For stocks like PLTR with 55.9% institutional ownership and 3,228 institutional holders, the options market is large and liquid enough that no single market maker can pin the price. For micro-caps with low liquidity, max pain may have more relevance because a single dealer's hedging flow can dominate price action.

3. **OI is required and unavailable.** The PLTR report computed max pain from "volume distribution as proxy," which is fundamentally different from the actual max pain calculation. Volume reflects today's flow; OI reflects accumulated positioning. The proxy may point to a completely different strike than the true max pain strike.

**Evidence from the PLTR report:** The "estimated" max pain was ~$137 based on volume clustering. The stock was at $135.91. The report said this "suggests market makers are neutral around current price." This is a circular observation -- the most traded strikes naturally cluster near the current price because ATM options have the most liquidity. The volume-based proxy does not provide the same information as OI-based max pain.

**Proposed fix:**

```
Max Pain — Conditional Usage:
- If OI data IS available: Compute max pain as defined. Report with caveat:
  "Max pain predictive power is limited for high-institutional-ownership stocks.
  Treat as supplementary context, not a price target."
- If OI data is NOT available: Do NOT compute a proxy. Report:
  "Max pain: N/A (requires OI data). See Most Active Strikes for volume 
  clustering instead."
- Reduce max pain's implicit weight in the Smart Money score. It should not 
  contribute to directional scoring -- it is at best a short-term (expiration 
  week only) price target with high error bars.
- ADD: GEX (Gamma Exposure) estimate if OI and delta/gamma are available.
  Net GEX is a better predictor of price pinning than max pain because it 
  directly measures the hedging flow that causes pin behavior.
```

---

### Flaw 6: Unusual Activity Detection Has No Minimum OI Floor

**What the rubric says:** `volume > 5x open interest` flags unusual activity.

**Why this is wrong:** The 5x OI rule assumes a meaningful baseline OI. Consider these scenarios:

- **OI = 0 (newly listed contract):** Any volume (even 1 contract) yields a division-by-zero or infinite ratio. The rubric has no guard for this.
- **OI = 5 (thinly traded contract):** 26 contracts traded triggers "unusual" (5.2x). But 26 contracts on a $2 option is $5,200 in notional -- not meaningful flow for any stock over $1B market cap.
- **OI = 50,000 (liquid contract):** 250,001 contracts triggers "unusual" (5.0x). This is $50M+ in notional and genuinely unusual.

The 5x multiplier treats all OI baselines equally, which means illiquid or newly listed strikes generate false positives constantly.

**Evidence from the PLTR report:** OI was unavailable, so the report pivoted to a volume-spike analysis (volume vs. previous day's volume). This alternative also has issues (one day of low volume followed by normal volume looks like a spike), but at least it avoids the zero-OI problem. However, the rubric still specifies the 5x OI rule as the primary definition.

**Proposed fix:**

```
Unusual Activity — Minimum Thresholds:

1. OI floor: Only apply the 5x OI rule when OI >= 100.
   - OI < 100: Flag as "LOW LIQUIDITY — unusual activity metric unreliable."
   - OI = 0: Exclude from unusual activity scan entirely.

2. Notional floor: Even if volume/OI > 5x, require:
   - Notional value (volume * contract_price * 100) > $500,000 for stocks >$10B mcap
   - Notional value > $100,000 for stocks $1B-$10B mcap
   - Notional value > $25,000 for stocks <$1B mcap

3. Fallback when OI unavailable: Use volume-spike method as PLTR report did,
   but require:
   - Current volume > 5x 5-day average volume (not just previous day)
   - Notional floor still applies

4. Report format: "UNUSUAL: {contract} — {volume}/{OI} = {ratio}x, 
   notional ${value}. {MEANINGFUL/LOW NOTIONAL}"
```

---

### Flaw 7: The +/-10% Strike Range Is Not Appropriate for All Price Levels

**What the rubric says:** `strike_price_gte={price * 0.9}` and `strike_price_lte={price * 1.1}`.

**Why this is wrong:** A fixed percentage creates dramatically different absolute ranges and captures different option market dynamics depending on price level and volatility:

| Stock Price | Range | Absolute Width | Strike Intervals | Strikes Captured |
|------------|-------|---------------|-----------------|-----------------|
| $5 | $4.50-$5.50 | $1.00 | $0.50 or $1.00 | 1-3 strikes |
| $50 | $45-$55 | $10.00 | $1.00 or $2.50 | 4-10 strikes |
| $135 (PLTR) | $121.50-$148.50 | $27.00 | $1.00 | 27 strikes |
| $400 | $360-$440 | $80.00 | $5.00 | 16 strikes |
| $3,500 (BRK.A) | $3,150-$3,850 | $700.00 | $50.00 | 14 strikes |

For a $5 stock, +/-10% may capture only 1-3 strikes, which is insufficient for computing IV skew (which needs "ATM +/-2 strikes") or max pain. For a high-IV stock like PLTR (88% annualized IV), a 1-standard-deviation move over 45 days is approximately 30%, so +/-10% misses a large portion of the actively traded chain.

**Evidence from the PLTR report:** The chain used strikes $113-$149 (roughly +/-10% from $135.91). But the most active put was the $130P (only 4.3% below ATM) and the most active call was the $140C (only 3% above ATM). The $113 and $149 boundary strikes had minimal volume. Meanwhile, contracts at $150+ and $120- (outside the range) may have carried important unusual activity signals.

**Proposed fix:**

```
Strike Range — Volatility-Adaptive:

range_pct = max(10%, min(30%, ATM_IV * sqrt(DTE_max / 365) * 1.5))

Where DTE_max is the longest expiry in the query (e.g., 45 days).

Examples:
- PLTR (IV=88%, DTE=45): range = max(10%, min(30%, 0.88 * 0.351 * 1.5)) 
  = max(10%, min(30%, 46.3%)) = 30%. Range: $95-$177.
- Low-vol utility (IV=20%, DTE=45): range = max(10%, min(30%, 0.20 * 0.351 * 1.5)) 
  = max(10%, min(30%, 10.5%)) = 10.5%. Range: ~+/-10%.

This ensures high-IV stocks get a wider range (capturing the tail activity that 
carries the most information) while low-IV stocks keep a narrow, appropriate range.

Additionally, add a minimum absolute strikes rule:
- If the range captures fewer than 5 strikes per side (call/put), 
  widen until at least 5 strikes are included.

For penny stocks (<$5): Use a fixed +/-$2.50 range instead of percentage, 
as option strikes below $5 typically use $0.50 increments.
```

---

### Flaw 8: Premium Trending Does Not Distinguish IV Expansion from Directional Conviction

**What the rubric says:** "Rising call premiums = bullish momentum. Rising put premiums = increasing fear." Uses 7-day option bar data for the top 3 contracts by volume.

**Why this is wrong:** Option premiums are a function of at least four variables: intrinsic value (stock price movement), implied volatility (IV), time decay (theta), and interest rates/dividends. The rubric attributes premium changes entirely to directional conviction, ignoring the dominant driver in many scenarios:

1. **Pre-earnings IV expansion.** In the 7 days before earnings, IV can rise 20-50% as the market prices in the upcoming move. Both call AND put premiums rise, not because traders are bullish or bearish, but because volatility is being priced in. Rising call premiums pre-earnings often reflect IV expansion alone.

2. **Post-earnings IV crush.** The PLTR report showed this perfectly: call premiums dropped 80-89% and put premiums dropped 67.5% in 7 days. The report correctly attributed this to "pre-earnings IV crush combined with directional move," but the rubric provides no framework for distinguishing the two components.

3. **Time decay acceleration.** As expiration approaches (especially final 7 days), theta decay accelerates nonlinearly. A call premium that stays flat for 7 days before expiry is actually reflecting bullish pressure offsetting decay -- the "flat" premium is secretly bullish. A declining premium near expiry may simply be theta, not bearish conviction.

**Evidence from the PLTR report:** The premium trend table shows May 8 $140C going from $8.35 to $1.60 (-80.8%). But this contract went from 10 DTE to 3 DTE, crossing earnings (massive IV crush), AND the stock dropped 3.13%. The -80.8% conflates three distinct forces. The report correctly interpreted this as "premium sellers won" but the rubric says "falling call premiums = bearish momentum," which oversimplifies.

**Proposed fix:**

```
Premium Trend — Decomposed Analysis:

Step 1: Compute raw premium change (existing).

Step 2: Decompose into components:
- Delta component: contract_delta * stock_price_change_7d
- Theta component: approximate as -(premium / DTE_start) * 7 (linear approx)
- IV component: residual = actual_change - delta_component - theta_component

Step 3: Interpret the IV component, not the raw premium change:
- IV component rising: "VOLATILITY EXPANSION — not necessarily directional. 
  If earnings within 7 days, this is expected behavior, score as neutral."
- IV component falling: "VOLATILITY CRUSH — post-event normalization. 
  Score as neutral unless accompanied by directional stock move."
- IV component flat + delta component driving change: "DIRECTIONAL CONVICTION — 
  premium change is primarily stock-driven. Score accordingly."

Step 4: Pre-earnings flag:
- If earnings within 7 days of the observation window: 
  "PRE-EARNINGS WINDOW: Premium trends unreliable for directional signal. 
  IV expansion dominates. Use expected move vs historical move (Metric 6) 
  for conviction assessment instead."

Note: Exact decomposition requires knowing the contract's Greeks at each 
observation point. If only OHLCV bars are available from get_option_bars, 
use the approximation: if stock moved <1% over the 7 days but premiums 
rose >10%, the change is primarily IV-driven, not directional.
```

---

### Summary of Structural Issues

Beyond the eight individual flaws, there is a meta-problem: the options flow section contributes to the Smart Money score (13% of composite weight), but 4 of the 10 metrics require Open Interest data that Alpaca does not provide. This means approximately 40% of the options analysis infrastructure is running on proxies or reporting "N/A." The scoring system should either:

1. **Degrade gracefully:** When OI is unavailable, explicitly redistribute the weight of OI-dependent metrics (P/C OI Ratio, Max Pain, Unusual Activity via OI, Net Delta Exposure) to OI-independent metrics (P/C Volume Ratio, IV Skew, IV vs HV, Expected Move, Most Active Strikes, Premium Trend).

2. **Add an alternative data source:** Consider using the 13F institutional options data (which the PLTR report already used as a P/C proxy) as a structured alternative. It is quarterly rather than real-time, but it reflects actual institutional positioning rather than intraday noise.

3. **Flag data quality in the composite:** When >30% of options metrics are N/A or proxy-based, apply a confidence discount to the entire options flow contribution to Smart Money scoring. The current system allows proxy-based metrics to carry the same weight as direct measurements, which overstates confidence.

### Files Examined

- `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/_shared/scoring-rubrics.md` -- Smart Money score definition (lines 166-193), Risk score (lines 251-267)
- `/Users/srivardhanjalan/workspace/trading-desk/.claude/commands/analyze-sentiment.md` -- Phase 10 options flow pipeline (lines 9-62), all 10 derived metrics
- `/Users/srivardhanjalan/workspace/trading-desk/reports/PLTR_sentiment.md` -- Real-world output showing OI gaps, proxy usage, and scoring artifacts