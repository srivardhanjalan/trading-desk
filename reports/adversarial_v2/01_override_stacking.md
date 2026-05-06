# Adversarial Audit: Override Stacking & Double-Counting
## Date: 2026-05-06

I'll start by reading both files to understand the full scoring system.

---

Now I have a complete picture of both files. Let me also check if there are any other related files that might contain additional scoring logic.

---

Now I have a comprehensive understanding of the entire system. Let me compile the full adversarial audit.

---

# OVERRIDE STACKING & DOUBLE-COUNTING AUDIT

## 1. RSI OVERBOUGHT (>75): Full Penalty Map

RSI overbought creates penalties in **four distinct places**:

### Location A: Technical Score Cap (scoring-rubrics.md, lines 38-47)
> **ADX-Conditional RSI Interpretation:**
> - ADX > 35 + +DI > 2x -DI: "No cap from RSI"
> - ADX 25-35: "Cap at 6 (not 5)"
> - ADX < 25: "Cap at 5-6 (existing)"

This caps the Technical dimension score itself. Also at line 32: score 5-6 is defined as "RSI overbought/oversold."

### Location B: Risk Score (scoring-rubrics.md, lines 253-258)
> - Score 3-4: "Beta >2.0 + **RSI overbought/oversold** + IV/HV >1.5 + earnings imminent"
> - Score 1-2: "Extreme beta + **RSI extreme** + IV/HV >2.0..."

RSI overbought is used as a criterion to push Risk toward 3-4 or 1-2. This is a **second penalty** on a different dimension from the same signal.

### Location C: Override 1 -- Overbought/Oversold Override (scoring-rubrics.md, lines 272-277)
> - RSI 75-80: subtract 5 from composite
> - RSI 80-85: subtract 10 from composite
> - RSI > 85: cap at 55

This is a **third penalty** -- a direct composite deduction after all dimension scores are already calculated.

### Location D: Override 5 -- Momentum Extension (scoring-rubrics.md, lines 289-291)
> "Does NOT stack with Override 1 -- use larger penalty."

Extension itself is correlated with RSI overbought (both measure "the stock ran too far too fast"). The rubric correctly identifies this and says to use the larger, not both. However, this only addresses Override 1 vs Override 5 stacking. It does **not** address Location A (Technical cap) or Location B (Risk score), which still fire independently.

### DOUBLE-COUNTING VERDICT: RSI overbought is **triple-counted**

1. Technical score capped/reduced (Location A)
2. Risk score reduced (Location B)
3. Composite deducted via Override 1 (Location C)

The ADX-conditional fix at Location A says "no cap from RSI" when ADX > 35, and the Override 1 multiplier table says "0.5x" for ADX > 35. But these are **two separate penalties that are each independently halved** -- neither is removed. A stock with RSI 80 and ADX 40 would still: (a) have no Technical cap from RSI -- good, (b) have Risk score penalized for "RSI overbought" -- still fires, no ADX exception mentioned in Risk rubric, (c) get Override 1: subtract 10 * 0.5 = subtract 5 from composite -- still fires.

**Specific gap in the ADX fix:** The ADX-conditional RSI table (scoring-rubrics.md line 42-45) defines Override 1 Multiplier as 0.5x for ADX > 35, but the Risk score criteria (lines 253-258) make no reference to ADX at all. A stock with RSI 80, ADX 45 gets a Risk penalty for "RSI overbought" with zero ADX mitigation in the Risk dimension.

---

## 2. BETA: Full Penalty Map

### Location A: Risk Score (scoring-rubrics.md, lines 253-258)
> - Score 9-10: "Beta <1.0..."
> - Score 7-8: "Beta 1.0-1.5..."
> - Score 5-6: "Beta 1.5-2.0..."
> - Score 3-4: "Beta >2.0..."
> - Score 1-2: "Extreme beta..."

### Location B: Override 2 -- VIX Panic (scoring-rubrics.md, lines 279-280)
> "VIX > 35 AND **beta > 1.0** AND composite >= 60: Downgrade to HOLD."

Beta is a gating condition for the VIX override. A high-beta stock gets (a) a lower Risk score AND (b) is subject to a forced HOLD downgrade during volatility spikes.

### Location C: Position Sizing (synthesize.md, lines 46-50)
> "Position size ($) = shares * entry_price"
> "Cap at 20% of portfolio"

Position sizing uses stop loss distance (ATR-based), not beta directly. However, higher beta stocks have wider ATRs, which mechanically produces smaller position sizes. This is **implicit** rather than explicit double-counting.

### DOUBLE-COUNTING VERDICT: Beta is **double-counted** (Risk + VIX Override), with a mild implicit third penalty through position sizing

The Risk score already accounts for beta (1-10 scale). Override 2 then uses beta as a binary gate (> 1.0) independent of the Risk score. A stock with beta 1.1 and beta 2.5 are treated identically by Override 2 (both trigger), even though the Risk score already differentiated them substantially. This is defensible as a "circuit breaker" design -- but the Risk score penalty for beta and the VIX override penalty for beta do stack on the same underlying signal.

**Not as severe as RSI** because Override 2 only fires when VIX > 35 (rare), and position sizing is an appropriate mechanical consequence rather than a scoring penalty.

---

## 3. EARNINGS PROXIMITY: Full Interaction Map

### Location A: Risk Score (scoring-rubrics.md, lines 253-258)
> - Score 9-10: "no earnings within 14d"
> - Score 5-6: "earnings within 14d"
> - Score 3-4: "earnings imminent"

### Location B: Pre-Earnings Weight Switching (scoring-rubrics.md, lines 332-349)
> When earnings within 7 calendar days, the weight profile shifts. Technical drops from 22% to 12%, Fundamental rises from 15% to 22%, Sentiment rises from 7% to 20%, Backtest drops from 10% to 3%.

### Location C: Override 6 -- Earnings Catalyst Modifier (scoring-rubrics.md, lines 297-315)
> Triggers within 7 calendar days. EBP >= 80%: +3. EBP >= 65%: +1. EBP < 50%: -2. EBP < 30%: -4.

### Interaction Analysis

These three mechanisms interact in a **complex but mostly coherent** way:

- **Risk score** (Location A) penalizes the uncertainty of the upcoming event -- this is a pure risk/volatility concern.
- **Weight switching** (Location B) is structural -- it reshuffles emphasis to dimensions more predictive pre-earnings. It doesn't inherently penalize; it changes *which scores matter more*.
- **Earnings Catalyst** (Location C) modifies the composite based on the *probability of a favorable outcome*.

**However, there is a stacking problem for stocks with LOW beat probability:**

A stock with earnings in 3 days and EBP < 50% gets:
1. Risk score pushed toward 3-4 (from "earnings imminent") -- this reduces composite
2. Pre-earnings weight switch: Risk weight drops from 12% to 10% (slight mitigation), BUT Fundamental rises to 22% (and if fundamentals are poor for a stock that misses earnings, this amplifies the penalty)
3. Override 6: subtract 2 from composite

The Risk dimension penalty and Override 6 both penalize for "earnings are coming and it's probably bad." The Risk score captures event risk generically, while Override 6 captures directional probability -- they are conceptually different, but the *net effect* is that bad-earnings-history stocks get hit twice.

**Conversely, for HIGH beat probability stocks:**
1. Risk score still pushed toward 3-4 (Risk doesn't care about beat history -- it only sees "earnings imminent")
2. Override 6: +3 to composite

This creates a tension: the Risk dimension says "earnings are risky" even when the stock has an 85% beat rate. The Risk score should arguably differentiate between a serial beater (less risky event) and a serial misser (more risky event), but it doesn't -- it treats all "earnings imminent" equally.

### DOUBLE-COUNTING VERDICT: Partial double-counting for low-EBP stocks

The Risk "earnings imminent" penalty and Override 6 negative modifiers stack. For high-EBP stocks, Override 6 partially offsets the Risk penalty, which is reasonable. For low-EBP stocks, both penalties stack without mitigation.

**Proposed fix:** In the Risk score criteria, add: "Earnings within 14d with EBP >= 80%: do not penalize below 7 for earnings proximity alone." This makes Risk score earnings-quality-aware.

---

## 4. VOLUME: Full Appearance Map

### Location A: Volume Direction Modifier in Technical Score (scoring-rubrics.md, lines 49-52)
> - Price change < -3% AND volume > 1.5x: Technical -1. "DISTRIBUTION."
> - Price change > +3% AND volume > 1.5x: Technical +1. "ACCUMULATION."
> - Price change < -5% AND volume > 2.0x: Technical -2. "SEVERE DISTRIBUTION."

### Location B: smart_volume_scanner (referenced in tradingview-analysis MCP)
This is a TradingView analysis tool that identifies volume breakouts. It's used in Phase 4 of the analysis pipeline (not defined in these files, but referenced in the tool list).

### Location C: volume_confirmation_analysis (referenced in tradingview-analysis MCP)
Another TradingView analysis tool for volume confirmation.

### Stacking Analysis

Location A is a **scoring modifier** -- it directly changes the Technical score. Locations B and C are **data-gathering tools** that feed into the analysis. The question is whether the *data* from B and C is used to trigger A, and whether it also independently influences other scores.

Looking at the Technical scoring criteria (lines 26-34), volume is not explicitly mentioned in the tier definitions (9-10, 7-8, etc.) -- it only appears via the Volume Direction Modifier. So if the analyst uses smart_volume_scanner data to inform the Technical score tier AND also applies the Volume Direction Modifier, volume could be double-counted within the Technical dimension itself.

### DOUBLE-COUNTING VERDICT: Potential double-counting within Technical

The rubric does not explicitly prohibit using volume data from Phase 4 scanners to justify the base Technical score (e.g., "strong volume confirms trend, score 8") AND then also applying the Volume Direction Modifier (+1/-1/-2). The fix is straightforward: clarify that the Volume Direction Modifier is the **sole** mechanism for volume's impact on the Technical score.

---

## 5. INSIDER SELLING: Full Penalty Map

### Location A: Smart Money Score (scoring-rubrics.md, lines 166-191)
> - Score 3-4: "Net insider selling + institutional flat/declining..."
> - Score 1-2: "Heavy insider selling (>$10M)..."
> - Insider magnitude: "Sales >$10M from multiple insiders: reduce -1"
> - Conflict priority: "$10M+ selling -> ceiling 4"

### Location B: Risk Score (scoring-rubrics.md, lines 258-259)
> Score 1-2: "...heavy insider selling"

### DOUBLE-COUNTING VERDICT: Yes, double-counted

"Heavy insider selling" appears as a criterion in both Smart Money (primary home) AND Risk score 1-2. A stock with >$10M insider selling gets:
1. Smart Money score capped at 4 (or pushed to 1-2)
2. Risk score pushed toward 1-2 (if combined with other Risk negatives)

These are two separate dimensions both penalizing the same signal. Smart Money is weighted 13%, Risk is weighted 12%. A stock with heavy insider selling is penalized on 25% of its composite weight for a single signal.

**However**, the Risk criteria says "heavy insider selling" as part of a compound requirement (alongside extreme beta, RSI extreme, IV/HV >2.0, etc.). It's a contributing factor, not a sole trigger. So the double-counting is real but moderated by the compound nature of the Risk criteria.

**Proposed fix:** Remove "heavy insider selling" from Risk score criteria. It belongs in Smart Money. Risk should focus on market-derived risk metrics (beta, volatility, IV, extension from SMA). Alternatively, if kept in Risk, explicitly state: "When insider selling is already penalized in Smart Money at 3 or below, do not additionally penalize in Risk for the same insider activity."

---

## 6. ADX-CONDITIONAL RSI FIX GAP ANALYSIS

The ADX-conditional RSI fix (scoring-rubrics.md lines 38-47) states:

> | ADX > 35 | +DI > 2x -DI | Momentum CONFIRMATION -- no penalty | **No cap from RSI** | **0.5x (halve penalty)** |

And synthesize.md (lines 126-132) implements Override 1 with:

> - If ADX > 35 AND +DI > 2x -DI: **multiply overbought penalty by 0.5x**
> - RSI 80-85: base subtract 10 x ADX_multiplier

**Analysis of the gap:**

When ADX > 35:
- **Technical score cap:** Removed ("No cap from RSI") -- Technical score can be 7-8+ despite RSI > 75. GOOD.
- **Override 1:** Still fires but at 0.5x. RSI 82 with ADX 45 would subtract 10 * 0.5 = **5 points** from composite. Still a material penalty.

**Is this intentional or a gap?**

The rubric says RSI > 75 with ADX > 35 is "Momentum CONFIRMATION -- no penalty" in the Technical score, but then Override 1 still applies a 5-point composite penalty (halved from 10). The language "no penalty" and "momentum confirmation" in the Technical cap column implies the system believes this RSI reading is NOT a negative signal. Yet Override 1 still penalizes it, just less severely.

**This is a design contradiction.** If RSI overbought with ADX > 35 is genuinely "momentum confirmation," then Override 1 should not fire at all (0.0x multiplier, not 0.5x). The current 0.5x is a hedge -- "we think it's probably fine but let's still penalize a bit" -- which undercuts the stated rationale.

Additionally, the Risk score (Location B from Section 1 above) has no ADX awareness at all, so RSI overbought still pushes Risk toward 3-4 even when ADX confirms the trend. This is a triple contradiction: the system says RSI > 75 is "momentum confirmation" in Technical, applies a halved penalty in Override 1, and applies full penalty in Risk.

**Proposed fix options:**
- **Option A (Conservative):** Keep Override 1 at 0.5x but add ADX awareness to Risk score: "RSI overbought with ADX > 35 and +DI > 2x -DI: do not penalize RSI in Risk scoring."
- **Option B (Consistent with stated rationale):** Set Override 1 multiplier to 0.0x when ADX > 35 (truly treat as confirmation), AND add Risk exception as in Option A.

---

## 7. CONCRETE WALKTHROUGH: RSI 82, ADX 45, 1M +65%, Earnings in 3 Days, Beta 2.1, VIX 22

Assume +DI > 2x -DI (required for ADX > 35 exception), and for completeness: EBP = 70% (decent beat history), IV/HV = 1.4, 3M = +85%, 6M = +50%, no insider selling.

### Step 1: Dimension Scoring

**Technical Score:**
- 4/5 timeframes aligned (assumed), MACD positive, ADX 45 (strong trend), RSI 82
- ADX > 35 with +DI > 2x -DI: "No cap from RSI" -- Technical NOT capped at 5-6 for overbought
- Base score: 7-8 range (strong trend). Say **7**.
- Stochastic > 80 at highs: -1 modifier. Technical = **6**.
- Volume Direction: neutral (no extreme volume day). No modifier.

**Risk Score:**
- Beta 2.1: pushes toward 3-4 ("Beta >2.0")
- RSI 82: "RSI overbought" -- pushes toward 3-4 (NO ADX exception in Risk rubric)
- IV/HV 1.4: pushes toward 5-6
- Earnings in 3 days: "earnings imminent" -- pushes toward 3-4
- Three negatives (beta, RSI, earnings) align with the 3-4 criteria. Risk = **3**.

**Fundamental, Valuation, Smart Money, Macro, Sentiment, Backtest:** Assume reasonable scores for walkthrough: F=7, V=6, SM=6, Macro=6, Sent=6, BT=6.

### Step 2: Weight Application

Earnings in 3 days triggers **Pre-Earnings Weight Switch**:

| Dimension | Score | Pre-Earnings Weight | Weighted |
|-----------|-------|-------------------|----------|
| Technical | 6 | 12% | 0.72 |
| Fundamental | 7 | 22% | 1.54 |
| Valuation | 6 | 12% | 0.72 |
| Sentiment | 6 | 20% | 1.20 |
| Smart Money | 6 | 13% | 0.78 |
| Macro | 6 | 8% | 0.48 |
| Risk | 3 | 10% | 0.30 |
| Backtest | 6 | 3% | 0.18 |

Sum of weighted scores: 5.92 / 1.00 = 5.92. Composite = 5.92 * 10 = **59.2** (raw).

### Step 3: Apply Overrides (in order)

**Override 1 -- Overbought (ADX-Conditional):**
- RSI 82 falls in 80-85 band: base penalty = subtract 10
- ADX 45 > 35 with +DI > 2x -DI: multiplier = 0.5x
- Penalty = 10 * 0.5 = **subtract 5**
- Composite: 59.2 - 5 = **54.2**

**Override 2 -- VIX Panic:**
- VIX 22 is NOT > 35. Does not fire.

**Override 3 -- Cross-Dimension Conflicts:**
- Technical (6) vs Fundamental (7): divergence = 1. Not >= 5. Does not fire.
- Risk (3) <= 2? No (Risk = 3). Does not fire on the "Risk <= 2" rule.
- Data completeness: assumed adequate. Does not fire.

**Override 4 -- R:R Check:**
- Assume R:R >= 1.5. Does not fire.

**Override 5 -- Momentum Extension:**
- 1M = +65%: >= 60%. Category = **EXTREME**. Base penalty = subtract 5.
- 3M = +85%: also confirms EXTREME (1M >= 40% AND 3M >= 90%? 85% < 90%, so this secondary criterion doesn't trigger, but 1M >= 60% alone = EXTREME).
- 6M = +50% (positive): Recovery exception? 6M > 0, so no recovery exception.
- **Non-stacking rule:** Override 1 already applied -5. Override 5 also wants -5. Rule says "use the LARGER of the two penalties, not both." Both are -5, so use -5. **Override 5 does NOT add additional penalty.**
- Composite stays at **54.2**.

**Override 6 -- Earnings Catalyst:**
- Earnings in 3 days (within 7). EBP = 70% (>= 65%): **add +1**.
- Composite: 54.2 + 1 = **55.2**

**Override 7 -- Sell-the-News:**
- Not applicable (pre-earnings, not post-earnings).

### Step 4: Final Signal

Composite = **55.2** -- falls in 40-59 range = **HOLD**.

### Summary of ALL Penalties Fired

| Mechanism | Signal Source | Penalty | Stacking? |
|-----------|-------------|---------|-----------|
| Technical score: Stoch >80 modifier | RSI/momentum related | -1 to Technical (6 instead of 7) | Independent |
| Risk score: "RSI overbought" | RSI 82 | Risk pushed to 3 (from ~5-6) | **DOUBLE-COUNT #1 with Override 1** |
| Risk score: "Beta >2.0" | Beta 2.1 | Risk pushed to 3 | Independent (appropriate) |
| Risk score: "earnings imminent" | Earnings in 3d | Risk pushed to 3 | **Stacks with Override 6** |
| Pre-Earnings weight switch | Earnings in 3d | Risk weight drops 12%->10% (minor mitigation) | Interacts with Override 6 |
| Override 1: RSI overbought | RSI 82 | -5 from composite | **DOUBLE-COUNT #1 with Risk score RSI** |
| Override 5: Extension EXTREME | 1M +65% | -5 (BUT non-stacking: absorbed by Override 1) | Correctly handled |
| Override 6: Earnings Catalyst | EBP 70% | +1 to composite | Partially offsets Risk earnings penalty |

### Quantified Double-Counting Impact

**RSI double-count (Risk + Override 1):**
- Without RSI penalty in Risk, Risk score might be 5 (from beta 2.1 + earnings alone, without RSI). With pre-earnings weight (10%), this changes the composite by approximately (5 - 3) * 0.10 * 10 = **+2.0 points** that are unfairly deducted.
- Override 1 also deducts 5 points.
- Total RSI penalty: ~7 points of composite impact from a signal that the system itself calls "momentum confirmation" for ADX > 35.

**Earnings double-count (Risk + Override 6 for low-EBP):**
- In this example, Override 6 is positive (+1) so it partially offsets. But if EBP were < 50%, the stock would get Risk penalty (earnings imminent -> score 3-4) AND Override 6 penalty (-2), compounding.

---

## COMPREHENSIVE FIX PROPOSALS

### Fix 1: RSI in Risk Score -- Add ADX Awareness
In scoring-rubrics.md, Risk Score criteria (lines 253-258), add:

> **ADX exception for RSI in Risk:** When ADX > 35 with +DI > 2x -DI, do not count "RSI overbought" as a Risk factor. RSI in a strong trend reflects momentum, not risk. Only penalize RSI overbought in Risk when ADX < 25 (exhaustion context).

### Fix 2: Override 1 Multiplier for ADX > 35 -- Reduce to 0.0x or 0.25x
In scoring-rubrics.md, the ADX-conditional table (line 42):

Change `0.5x (halve penalty)` to `0.0x (no penalty)` for ADX > 35 with +DI > 2x -DI. If "momentum CONFIRMATION" means what it says, the override should not fire at all. At minimum, reduce to 0.25x for strong trends and keep 0.5x only for ADX 25-35.

### Fix 3: Insider Selling in Risk Score -- Remove or Gate
In scoring-rubrics.md, Risk Score 1-2 criteria (line 259), remove "heavy insider selling" or add:

> When Smart Money score is already <= 3 due to insider selling, do not additionally penalize insider selling in Risk. Risk should measure market-structure risk (beta, volatility, extension), not duplicate fundamental signals.

### Fix 4: Earnings Proximity in Risk -- Quality-Gate
In scoring-rubrics.md, Risk Score criteria, add:

> **Earnings quality gate:** When earnings are within 14 days but EBP >= 80% (serial beater with positive revisions), do not penalize below Risk 6 for earnings proximity alone. High beat probability reduces event risk.

### Fix 5: Volume in Technical -- Sole Mechanism Clause
In scoring-rubrics.md, Technical Score section, add:

> Volume's impact on Technical score is captured **exclusively** through the Volume Direction Modifier (+1/-1/-2). Do not additionally factor volume strength into the base Technical tier selection (9-10, 7-8, etc.). Scanner data (smart_volume_scanner, volume_confirmation_analysis) informs whether the modifier triggers but does not create a separate scoring adjustment.

### Fix 6: Override 1 / Override 5 Non-Stacking with Technical Cap -- Clarify Scope
The non-stacking rule between Override 1 and Override 5 is well-stated, but it should explicitly note that the Technical score cap (Location A) is a **separate, pre-composite adjustment** that is NOT part of the non-stacking rule. Currently this is implicit but could confuse implementation. Add:

> **Clarification:** The non-stacking rule applies only to Override 1 and Override 5 composite penalties. The Technical score cap (ADX-conditional RSI) and the Risk score are dimension-level adjustments that apply independently before the composite is calculated.

This doesn't fix the double-counting -- it just makes the existing behavior explicit so it can be evaluated intentionally.

---

## SEVERITY RANKING

| Issue | Severity | Impact (est. composite points) |
|-------|----------|-------------------------------|
| RSI triple-counted (Technical + Risk + Override 1) | **CRITICAL** | 5-12 points over-penalized, especially when ADX confirms trend |
| ADX fix inconsistency (says "no penalty" but Override 1 still fires at 0.5x, Risk has no ADX awareness) | **HIGH** | 5-7 points of contradiction with stated design intent |
| Insider selling double-counted (Smart Money + Risk) | **MEDIUM** | 2-4 points on 25% of weight |
| Earnings proximity stacking (Risk + Override 6 for low-EBP) | **MEDIUM** | 2-4 points for low-beat-probability stocks |
| Volume potential double-counting in Technical | **LOW** | 1-2 points, depends on scorer discipline |
| Beta double-counting (Risk + VIX Override) | **LOW** | Only fires when VIX > 35 (rare), and acts as circuit breaker |