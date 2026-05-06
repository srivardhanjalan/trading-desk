# Adversarial Audit: Extension Override Calibration
## Date: 2026-05-06

I'll start by reading the required files to understand the current scoring system and stock data.

---

Now let me read the individual stock reports for the EXTREME extension stocks.

---

Now let me also check the adversarial audit file for relevant context on previous findings.

---

Now I have enough data to conduct the full calibration audit. Let me read one more section of the adversarial audit for completeness on prior fixes.

---

Now I have a comprehensive understanding of the full system. Let me also check the INFQ report for the recovery exception analysis.

---

Now I have all the data I need. Here is my complete calibration audit.

---

## EXTENSION OVERRIDE CALIBRATION AUDIT

### Stocks Examined

| Stock | 1M Change | 3M Change | 6M Change | 12M Change | Market Cap | Price | Extension Category |
|-------|--------:|--------:|--------:|--------:|--------:|------:|-----------|
| AMD | +63.7% | +80.1% | +44.2% | +258.4% | ~$230B | $360.54 | EXTREME (-5) |
| BE | +115.2% | +97.2% | +125.1% | +1,680% | ~$68B | $290.52 | EXTREME (-5) |
| CRDO | +80.0% | +90.2% | +12.3% | +278.7% | ~$34B | $184.38 | EXTREME (-5) |
| ALMU | +117.9% | +73.3% | +64.9% | +130.9% | ~$67M | $25.58 | EXTREME (-5) |
| FLTCF | +83.0% | +92.8% | +187.5% | +272.7% | ~$934M | $5.03 | EXTREME (-5) |
| INFQ | +18.8% | -2.2% | -25.4% | N/A | ~$2.6B | $12.41 | LOW (recovery + IPO exceptions) |

---

### CALIBRATION ISSUE 1: Should Extension Be Market-Cap-Adjusted?

**Current rule:** Absolute percentage thresholds (EXTREME >= 60% 1M). A $5 stock moving +60% ($3 move) is treated identically to a $500 stock moving +60% ($300 move).

**Evidence from the data:**

- ALMU at $25.58 with $67M market cap moved +118% in 1M. This is a micro-cap with 9.9M free float shares, 23% daily turnover, and negative beta (-1.33). Micro-caps routinely move 50-100% on single catalysts. Applying the same EXTREME threshold to ALMU as to AMD ($230B) is treating structurally different volatility regimes identically.

- FLTCF at $5.03 is an OTC stock with ~50K average volume. Its +83% 1M move included a single +29.7% day. OTC micro-caps are inherently more volatile -- the same percentage move carries different mean-reversion probability depending on the liquidity and institutional ownership of the stock.

- AMD at $360.54 with $230B market cap moved +63.7% in 1M. For a mega-cap semiconductor stock, this magnitude of move is genuinely unusual and driven by multiple fundamental catalysts. The mean-reversion probability here is actually LOWER than for the micro-caps because the move is supported by institutional rebalancing (626 new positions, +60.4M shares accumulated).

- BE at $290.52 with ~$68B market cap moved +115% in 1M. Mid-cap industrial transitioning to AI data center power. Institutional holders grew +28%. This is a regime change, not noise.

**Assessment:** The current thresholds are NOT correctly calibrated for market-cap differences. Micro-caps have higher baseline volatility, so the SAME percentage move carries less mean-reversion signal. For mega-caps, a 60% monthly move is much rarer and arguably carries MORE signal (either fundamentally driven or truly parabolic).

**Proposed fix -- Market-Cap-Tiered Thresholds:**

| Category | Mega-Cap (>$100B) | Large-Cap ($10-100B) | Mid-Cap ($2-10B) | Small/Micro (<$2B) |
|----------|------------------:|---------------------:|-----------------:|-------------------:|
| EXTREME | 1M >= 50% | 1M >= 60% | 1M >= 80% | 1M >= 100% |
| HIGH | 1M >= 25% | 1M >= 30% | 1M >= 45% | 1M >= 60% |
| MEDIUM | 1M >= 12% | 1M >= 15% | 1M >= 25% | 1M >= 35% |

**Impact on current watchlist:**
- AMD ($230B): 1M +63.7% vs 50% threshold still EXTREME. No change.
- CRDO ($34B): 1M +80% vs 60% threshold still EXTREME. No change.
- BE ($68B): 1M +115% vs 60% threshold still EXTREME. No change.
- ALMU ($67M): 1M +118% vs 100% threshold still EXTREME. No change (but just barely).
- FLTCF ($934M): 1M +83% vs 80% threshold. Stays EXTREME, but barely. If the move had been +78%, it would have dropped to HIGH (-2 instead of -5), a 3-point swing reflecting appropriate micro-cap calibration.

The tiered thresholds would primarily affect future cases where a small-cap bounces 60-80% (currently EXTREME, would become HIGH) -- a common and often sustainable move in low-float names.

---

### CALIBRATION ISSUE 2: Should Multiple Catalysts Reduce by More Than One Tier?

**Current rule:** Fundamental-Catalyst Exception reduces extension category by ONE tier, regardless of catalyst count.

**AMD data -- 5 distinct catalysts in 60 days:**
1. Meta $100B AI accelerator deal (revenue impact >> 10% of annual)
2. DA Davidson upgrade to Buy, PT $375 (from $220)
3. Intel competitive collapse (12% AMD surge on Intel CPU issues)
4. Bernstein estimate revisions higher ($9.8B to $9.9B Q1 rev, $1.25 to $1.27 EPS)
5. France multi-year AI infrastructure agreement

Each of these individually qualifies under the Catalyst Exception criteria: (a) major contract >10% annual revenue, (b) >= 3 analyst upgrades in 30 days, (c) revenue growth acceleration, (d) major partnership. AMD satisfies at least 3 of the 4 sub-criteria.

**With single-tier reduction:** EXTREME -> HIGH (-2). Composite 44 - 2 = 42 HOLD. This is actually the correct output per the previous audit's Fix 4. AMD at 42 HOLD is defensible.

**With double-tier reduction:** EXTREME -> MEDIUM (0 penalty). Composite stays at 44 HOLD. Difference of 2 points. Still HOLD either way.

**Assessment:** A double-tier reduction for multiple catalysts is theoretically justified but practically unnecessary in AMD's case because both outcomes produce HOLD. However, consider a hypothetical stock with raw composite 57 (high HOLD, near BUY):
- Single tier: EXTREME -> HIGH (-2) = 55 HOLD.
- Double tier: EXTREME -> MEDIUM (0) = 57 HOLD.
- Neither crosses the 60 BUY threshold.

The real question is: can a stock with 5 fundamental catalysts AND a 60%+ monthly run ever justify a BUY? Arguably yes, but only if the composite is already above 60 pre-extension. In that case, the extension override is the marginal factor, and the catalyst count matters.

**Proposed fix -- Graduated Catalyst Exception:**

| Catalyst Count | Tier Reduction | Rationale |
|---------------:|---------------:|-----------|
| 1 catalyst | -1 tier | Current rule |
| 3+ catalysts from distinct categories | -2 tiers | Multiple independent drivers confirm fundamental re-rating |
| Cap | Cannot reduce below MEDIUM | Even fundamentally driven, 60%+ monthly moves carry pullback risk |

**The cap at MEDIUM is critical.** Even AMD with 5 catalysts experienced a 53% extension above its 50-day SMA. Fundamental catalysts explain WHY the stock moved but do not eliminate the mean-reversion risk from extreme momentum stretching. A stock that rallied 60% in a month WILL pull back at some point, regardless of how many catalysts drove it. The question is whether you should penalize entry timing, not whether the business is good.

---

### CALIBRATION ISSUE 3: Is the Recovery Exception Threshold Too Strict?

**Current rule:** 6M return negative AND 1M positive -> reduce category by one tier.

**INFQ data:**
- 6M: -25.4% (qualifies -- clearly negative)
- 1M: +18.8%
- The recovery exception was applied. INFQ went from MEDIUM (1M +18.8%) to LOW (no penalty).

**KLTR data (from watchlist ranking):**
- Listed as "MED*" with recovery exception applied
- The asterisk indicates 6M was slightly negative and 1M was positive, reducing from HIGH to MEDIUM or MEDIUM to LOW.

**The question is about stocks that were FLAT for 6M then surged.** If INFQ had been 6M -0.5% (essentially flat) and then bounced +35% in 1M:
- 6M < 0 (technically) -> recovery exception fires
- But is a -0.5% 6M decline really a "recovery"? The stock was flat, not beaten down.

Conversely, if 6M was +2% (barely positive) and 1M was +35%:
- 6M > 0 -> recovery exception does NOT fire
- But the stock was essentially flat -- there is no "extension from a sustained uptrend" to penalize.

**Assessment:** The strict binary of "6M negative vs positive" creates a cliff effect. A stock at 6M -0.1% gets the exception; a stock at 6M +0.1% does not. The spirit of the exception is "a stock recovering from a decline should not be penalized for bouncing." But a stock that was essentially flat (6M between -5% and +5%) is also not "extended from a sustained uptrend."

**Proposed fix -- Expanded Recovery Exception:**

```
Recovery Exception triggers when:
  (a) 6M < 0 AND 1M > 0 (current rule, OR
  (b) 6M < +5% AND 1M > 30% AND (1M gain > 6 * abs(6M change))
```

Condition (b) captures: "The stock was essentially flat for 6 months, then surged. The surge is the dominant move, not an extension of a prior trend."

The multiplier (1M > 6x the 6M magnitude) ensures the monthly move is genuinely disproportionate to the 6M context, not just a continuation of modest gains.

**Impact:** This would be a marginal change affecting edge cases. In the current watchlist, no stock would change category because all recovery candidates already have 6M < 0. But it prevents future false positives where a flat-to-slightly-positive 6M stock surges 40% in a month and gets hammered with EXTREME when it is clearly not "extended from a sustained uptrend."

---

### CALIBRATION ISSUE 4: Is -3 (EXTREME with Catalyst Exception) Sufficient for Parabolic Fundamentally-Driven Moves?

**Hypothetical: AMD with 1M +90% (instead of +63.7%).**

Under current rules + Catalyst Exception:
- 1M +90% -> EXTREME (-5)
- Catalyst Exception reduces by 1 tier -> HIGH (-2)
- Composite: 49 (raw) - 5 (Override 1 overbought, larger penalty) = 44. Wait -- non-stacking rule means use the LARGER of Override 1 (-5) and Override 5 (-2, after catalyst exception). So the -5 from Override 1 applies, not the -2.

This reveals a perverse interaction: when the Catalyst Exception reduces extension from EXTREME (-5) to HIGH (-2), but Override 1 (RSI overbought) is still -5, the catalyst exception has ZERO effect because the non-stacking rule always takes the larger penalty. AMD had RSI 79.84 (Override 1 = -5). With the catalyst exception, Override 5 becomes -2. But -5 > -2, so the -5 applies regardless.

**The catalyst exception is completely nullified by overbought RSI.** This is a fundamental design flaw.

Now layer on Fix 1 from the previous audit (ADX-conditional RSI): AMD had ADX 47.99, so Override 1 multiplier becomes 0.5x, yielding -2.5 (rounded to -3). Now Override 5 after catalyst exception is -2. Non-stacking rule takes the larger: -3.

So with both fixes applied: composite 49 - 3 = 46 HOLD. The catalyst exception contributes nothing because the halved RSI penalty (-3) is still larger than the reduced extension penalty (-2).

**For truly parabolic moves (1M +90%):**
- Raw composite would likely be lower (worse Risk score, worse Valuation) -- maybe 46-47 raw
- Override 1 (halved): -3
- Override 5 (catalyst exception): -2 (EXTREME -> HIGH)
- Non-stacking takes -3
- Result: 43-44 HOLD

**Assessment:** The non-stacking rule between Override 1 and Override 5 effectively makes the Catalyst Exception useless whenever RSI is also overbought -- which it ALWAYS will be when 1M is +60%+. These two conditions are almost perfectly correlated: stocks up 60%+ in a month will virtually always have RSI > 75.

**Proposed fix -- Independent Application with Reduced Total:**

Instead of "use the larger penalty," apply both penalties but with a correlation discount:

```
IF Override 1 AND Override 5 both apply:
    Combined penalty = max(O1, O5) + 0.3 * min(O1, O5)
    # The smaller penalty adds 30% of its value on top of the larger
    # Reflects partial correlation -- they measure overlapping but not identical risks
```

Under this model with AMD (ADX-halved RSI -3, catalyst-reduced extension -2):
- Combined = max(3, 2) + 0.3 * min(3, 2) = 3 + 0.6 = -3.6, rounded to -4
- The catalyst exception now has marginal effect (reducing total from -5 no-catalyst to -4 with catalyst)

For parabolic +90% move (no catalyst exception, full EXTREME -5, halved RSI -3):
- Combined = max(5, 3) + 0.3 * min(5, 3) = 5 + 0.9 = -5.9, rounded to -6
- Appropriately more punishing than a fundamentally-driven +63% move

This preserves the intent (don't double-count correlated risks) while allowing the catalyst exception to actually matter.

---

### CALIBRATION ISSUE 5: Can BE, Up 21x in 12 Months, Ever Be "Not Extended"?

**BE's data:**
- 1M: +115.2%, 3M: +97.2%, 6M: +125.1%, 12M: +1,680%
- Fundamental: 7/10 (Piotroski 7, Rev +37%, beats 7/8 quarters)
- Oracle 2.8GW deal, $5B Brookfield partnership, FY2026 guidance raised to $3.4-3.8B revenue (+80% YoY)
- PSG: 0.76 (attractive growth valuation)
- Still FY net income negative (-$88M)
- Insider selling: $25.6M, NOT verified as 10b5-1

**The philosophical question:** BE was ~$16 a year ago. It is now $290. The company fundamentally re-rated from "money-losing fuel cell company" to "AI data center power infrastructure play." The Oracle deal alone transforms the revenue trajectory. Is the stock "extended" from its prior base, or has its prior base been permanently re-rated upward?

**Assessment:** The answer is BOTH. BE has genuinely re-rated (new business model, new contracts, new revenue trajectory), AND it is extended from any reasonable moving average (65% above SMA50, 12M return of 1,680%). The two are not mutually exclusive.

The Catalyst Exception should apply (Oracle 2.8GW deal is a major contract >> 10% annual revenue, 6 analyst PT raises in a month >= 3 upgrades). So EXTREME -> HIGH (-2). But even with that, the composite drops from 42 to 40 -- still HOLD, not SELL.

**However, the rubric has no concept of "regime change."** A 21x move in 12 months is not "extension" in the same way a 60% move in 1 month is. The 12M return is not a factor in the extension thresholds (which only look at 1M and 3M). This is actually correct by design -- the extension override is about SHORT-TERM mean-reversion risk, not long-term re-rating assessment. The 12M return is captured in the Valuation dimension (PSG reflects the 12M re-rating) and the Backtest dimension (B&H +1,667% destroys all strategies).

**Proposed fix:** No change to the extension thresholds is needed for regime-change stocks. The 12M return is not and should not be an extension trigger. However, the Catalyst Exception should be explicitly documented to apply to BE (Oracle deal, analyst upgrades). With EXTREME -> HIGH (-2), BE goes from 37 to 40 HOLD. This is the correct output: acknowledge the fundamental re-rating (don't SELL), but warn about short-term pullback risk (don't BUY either).

---

### CALIBRATION ISSUE 6: Downward Extension -- Is It Ever a BUY Signal?

**Current rule:** Extension override only penalizes UPWARD extension. 1M +60% = EXTREME (-5). 1M -60% = no extension modifier at all.

**Evidence:** INFQ had 6M -25.4%. No extension modifier was applied (correctly -- downward extension is not penalized). But what about a stock that drops 60% in a month? Under the current rubric, it receives no extension modifier. The Oversold Override (Override 1) covers RSI < 25 (+5) and RSI < 20 (+10), but RSI can be at 30-40 even after a 60% drop if the decline is gradual.

**Assessment:** Downward extension is conceptually different from upward extension. A stock down 60% in a month is NOT a symmetric mirror of one up 60%. Downward extension signals:
- Potential value trap (falling knife -- do not catch)
- Potential oversold bounce (mean reversion opportunity)
- Potential distress (business fundamentally impaired)

The correct treatment depends on the REASON for the decline:
- Earnings miss / guidance cut -> likely further downside (not a buy)
- Sector rotation / macro selloff -> potential bounce (possible buy)
- Fraud / regulatory action -> avoid entirely

**Proposed fix -- Downward Extension as Context Signal (Not Automatic BUY):**

```
DOWNWARD EXTENSION (Advisory, no automatic composite modifier):
- 1M <= -40%: Flag "SEVERE DECLINE: -{X}% in 1M. Investigate cause before entry."
- 1M <= -60%: Flag "EXTREME DECLINE: -{X}% in 1M. Falling knife risk. Require catalyst for entry."
- If Fundamental >= 7 AND 1M <= -30%: Note "QUALITY DECLINE: Strong fundamentals + sharp drop. Potential opportunity if decline is sector/macro, not company-specific."
```

This avoids the error of treating downward extension as an automatic buy signal while surfacing it as relevant context. The system already has the Oversold Override for RSI-based buy signals, which is the appropriate mechanism.

---

### CALIBRATION ISSUE 7: Non-Stacking Rule Makes RSI Fix Irrelevant Under EXTREME Extension

**Current rule:** Override 1 and Override 5 do not stack. Use the LARGER penalty.

**With ADX-conditional RSI (Fix 1):** AMD had ADX 47.99, so Override 1 multiplier = 0.5x. RSI 79.84 (75-80 band) = base -5, halved to -2.5.
- Override 5 EXTREME = -5.
- Non-stacking takes -5 (the larger).
- The RSI fix (reducing from -5 to -2.5) has ZERO effect because extension is still -5.

**Is this intended?**

Partially. The original rationale for non-stacking is sound: "RSI overbought and momentum extension are correlated signals measuring the same underlying risk." If a stock is up 60% in a month, it will be overbought. Penalizing both is double-counting.

But the ADX-conditional RSI fix was designed to recognize that overbought in a strong trend is less bearish. If ADX confirms the trend, the overbought penalty should be reduced. This reduction is rendered meaningless by the non-stacking rule whenever extension is EXTREME.

**Assessment:** This IS a problem. The ADX-conditional RSI fix only has practical effect when:
1. Extension is LOW/MEDIUM (no Override 5 penalty), OR
2. Extension is HIGH (-2) and RSI penalty would be -5 (now halved to -2.5, -2.5 > -2 so RSI penalty applies instead, but at reduced level).

For case 2, the ADX fix actually matters: without it, Override 1 = -5 (takes priority over extension -2). With it, Override 1 = -2.5, which is still larger than -2, so it takes priority -- but at -2.5 instead of -5. A 2.5-point improvement.

For EXTREME extension, the ADX fix is indeed dead. This is partially acceptable because EXTREME extension (+60% 1M) is genuinely concerning even in a strong trend. But it's worth noting for the record that the fix architecture has this gap.

**Proposed fix:** Use the combined penalty formula from Issue 4 (max + 0.3 * min) instead of the pure max. This allows the ADX-reduced RSI to provide partial benefit even under EXTREME extension.

---

### CALIBRATION ISSUE 8: The 59.9% vs 60.0% Cliff Effect

**Current thresholds:**
- HIGH: 1M >= 30% -> -2
- EXTREME: 1M >= 60% -> -5

A stock with 1M +59.9% gets HIGH (-2). A stock with 1M +60.0% gets EXTREME (-5). A 0.1% difference in monthly return creates a 3-point composite swing. For a $100 stock, this is $0.10 worth of price movement causing a 3-point scoring difference.

**Evidence from the watchlist:**

AMD at +63.7% is just 3.7% above the EXTREME threshold. If AMD's rally had stalled 4 days earlier, it might have been +58% (HIGH, -2) instead of +64% (EXTREME, -5). The difference: composite 42 HOLD vs 39 SELL. A 4-day timing difference in when the analysis was run would have changed the signal.

FLTCF at +83% is solidly EXTREME. No cliff issue here.

CRDO at +80% is solidly EXTREME. No cliff issue here.

**Assessment:** The cliff effect at 60% IS too sharp. A 3-point swing from 0.1% monthly return difference is disproportionate. However, this is inherent to ALL threshold-based systems. The fix is to create a graduated penalty rather than a step function.

**Proposed fix -- Graduated EXTREME Penalty:**

Replace the binary EXTREME (-5) with a linear interpolation:

| 1M Range | Penalty | Formula |
|----------|--------:|---------|
| 30-44% | -2 | HIGH (flat) |
| 45-59% | -2 to -3 | LINEAR: -2 - (1M - 45) / 15 |
| 60-79% | -3 to -4 | LINEAR: -3 - (1M - 60) / 20 |
| 80-99% | -4 to -5 | LINEAR: -4 - (1M - 80) / 20 |
| >= 100% | -5 | EXTREME cap |

Under this model:
- AMD at +63.7%: penalty = -3 - (63.7 - 60) / 20 = -3.19, rounded to -3. Composite: 44 - 3 = 41 HOLD (was 39 SELL under cliff).
- CRDO at +80.0%: penalty = -4 - (80 - 80) / 20 = -4. Composite: 60 - 4 = 56 HOLD (was 55 under cliff, minimal change).
- BE at +115.2%: penalty = -5 (capped). Composite: 42 - 5 = 37 SELL (unchanged).
- ALMU at +117.9%: penalty = -5 (capped). Unchanged.
- FLTCF at +83.0%: penalty = -4 - (83 - 80) / 20 = -4.15, rounded to -4. Composite: 48 - 4 = 44 HOLD (was 43, minimal change).

**Key benefit:** AMD moves from 39 SELL to 41 HOLD. The cliff effect at exactly 60% is eliminated. Stocks right at the boundary get intermediate penalties rather than sudden jumps.

**Complexity cost:** Linear interpolation is slightly harder to implement and explain than simple thresholds. But the 3-point cliff effect at 60% is a calibration failure that produces materially wrong signals for stocks near the boundary.

---

### SUMMARY OF FINDINGS

| Issue | Current State | Correctly Calibrated? | Proposed Change |
|-------|--------------|:---------------------:|-----------------|
| 1. Market-cap adjustment | Same % thresholds all caps | NO | Tiered thresholds by market cap (micro-caps need higher threshold) |
| 2. Multiple catalyst reduction | Single tier max | MARGINAL | Allow 2-tier reduction for 3+ catalysts from distinct categories, cap at MEDIUM |
| 3. Recovery exception strictness | Binary 6M < 0 | NO | Expand to include 6M < +5% when 1M > 6x abs(6M) |
| 4. Parabolic moves with catalysts | -3 after catalyst exception | DESIGN FLAW | Non-stacking rule makes catalyst exception dead under overbought RSI; use combined penalty formula |
| 5. Regime-change stocks (BE 21x) | Same extension rules | ACCEPTABLE | No change needed; 12M not an extension trigger by design |
| 6. Downward extension | Not considered | ACCEPTABLE as-is | Add advisory flags, no automatic modifier |
| 7. RSI fix nullified by EXTREME | ADX fix dies under EXTREME | DESIGN FLAW | Combined penalty formula (max + 0.3*min) instead of pure max |
| 8. Cliff at 60% threshold | 3-point swing on 0.1% | NO | Graduated penalty via linear interpolation |

**Highest priority fixes:** Issues 4, 7, and 8. The non-stacking rule (Issues 4 and 7) creates a structural dead zone where the ADX-conditional RSI fix and the Catalyst Exception both provide ZERO benefit whenever extension is EXTREME. Since EXTREME extension virtually guarantees overbought RSI, these two fixes -- which were specifically designed in the previous audit to address AMD's false SELL -- are architecturally nullified by the non-stacking rule. The cliff effect at 60% (Issue 8) directly caused AMD's SELL signal instead of HOLD, making it the most immediately impactful calibration failure.