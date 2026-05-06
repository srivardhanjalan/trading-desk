# Adversarial Audit: Boundary Conditions & Edge Cases
## Date: 2026-05-06

I'll start by reading both files to understand the scoring system thoroughly.

---

Now I have both files. Let me do a thorough boundary analysis for each of the 13 items.

---

## ADVERSARIAL BOUNDARY AUDIT REPORT

### 1. Composite 39 vs 40 (SELL vs HOLD)

**Exact threshold text (scoring-rubrics.md, lines 425-429):**
```
>= 75 → STRONG BUY
60-74 → BUY
40-59 → HOLD
25-39 → SELL
< 25  → STRONG SELL
```

**Flaw:** The notation "60-74" and "40-59" and "25-39" is ambiguous about whether these are integer-only ranges or continuous ranges. The composite is computed as `sum(dimension_score * weight) / sum(weights) * 10` and scaled to 0-100, which produces continuous (non-integer) values. A composite of exactly 39.5 falls between "25-39" (SELL) and "40-59" (HOLD). The dash notation does not specify inclusive/exclusive. Is 39.5 a SELL or a HOLD?

Additionally, there is **no hysteresis mechanism** anywhere in either file. A stock hovering at 39.9 could flip between SELL and HOLD on trivially small data changes (e.g., a single dimension shifting by 0.1 points). This creates unstable signal oscillation for borderline stocks.

**What tiny change flips the signal?** A single dimension scored at, say, 5 instead of 5.1 in a 22%-weighted dimension changes the composite by ~0.22 points. At the 39/40 boundary, that is enough to flip SELL to HOLD. There is no buffer zone, cooling period, or "confirm for N days" mechanism.

**Verdict: FLAW.** No specification of whether the boundary values are inclusive to the upper or lower bucket. No hysteresis.

---

### 2. Composite 59 vs 60 (HOLD vs BUY)

**Same issue as #1.** The thresholds are "40-59 → HOLD" and "60-74 → BUY". A composite of exactly 59.5 is unspecified. The ">= 75" notation for STRONG BUY explicitly uses `>=`, but the mid-range buckets use dash notation which is ambiguous.

**What tiny change flips the signal?** In a pre-earnings weight config, Sentiment has 20% weight. Changing Sentiment from 6 to 7 (one point) adds 2.0 to the composite. At composite 58.5, that would flip to 60.5 (HOLD to BUY). A single Reddit poll shifting from 58% bullish to 62% bullish (crossing the ">60% = bullish" threshold) could cascade.

**Verdict: FLAW.** Same ambiguity as #1. The only unambiguous threshold in the whole table is ">= 75" and "< 25".

---

### 3. PEG exactly 0.8, 1.2, 2.0, 3.0 — which bucket?

**Exact threshold text (scoring-rubrics.md, lines 103-108):**
```
9-10: PEG <0.8
7-8:  PEG 0.8-1.2
5-6:  PEG 1.2-2.0
3-4:  PEG 2.0-3.0
1-2:  PEG >3.0
```

**Analysis:**
- **PEG = 0.8:** The 9-10 tier requires `PEG < 0.8` (exclusive — the `<` is explicit). The 7-8 tier says `PEG 0.8-1.2`. So PEG exactly 0.8 falls into the **7-8 tier** — the `<0.8` excludes it from 9-10, and 0.8 is the start of the 0.8-1.2 range. This is **implicitly** consistent but relies on the assumption that the dash notation is lower-inclusive.

- **PEG = 1.2:** Belongs to BOTH "0.8-1.2" (7-8) and "1.2-2.0" (5-6). Which bucket? **Ambiguous.** The 7-8 tier says "0.8-1.2" and the 5-6 tier says "1.2-2.0". The value 1.2 appears at both boundaries.

- **PEG = 2.0:** Same overlap problem between "1.2-2.0" (5-6) and "2.0-3.0" (3-4). **Ambiguous.**

- **PEG = 3.0:** The 3-4 tier says "2.0-3.0" and the 1-2 tier says `PEG >3.0` (exclusive). So PEG = 3.0 would fall in the **3-4 tier** since `>3.0` excludes it. This is consistent but not explicitly stated.

**Verdict: FLAW at 1.2 and 2.0.** These boundary values belong to two tiers simultaneously. The spec does not state whether dash ranges are lower-inclusive/upper-exclusive or lower-inclusive/upper-inclusive. The 0.8 and 3.0 boundaries happen to be unambiguous only because adjacent tiers use `<` and `>` respectively, but the middle boundaries at 1.2 and 2.0 have overlapping dash notation.

---

### 4. RSI exactly 75, 80, 85 — which penalty tier?

**Exact threshold text (scoring-rubrics.md, lines 272-274 and synthesize.md lines 130-132):**
```
RSI 75-80:  subtract 5 × ADX_multiplier
RSI 80-85:  subtract 10 × ADX_multiplier
RSI > 85:   cap at 55
```

**Analysis:**
- **RSI = 75:** Falls in "75-80" tier — subtract 5. But is the lower bound inclusive? The dash notation doesn't say. If it's exclusive, then RSI exactly 75 gets no penalty at all, which would be a gap between "no penalty" (RSI 74.99) and "-5" (RSI 75.01). The synthesize.md version is identical. **Likely intended as inclusive, but not explicitly stated.**

- **RSI = 80:** Belongs to BOTH "75-80" (-5) and "80-85" (-10). **Ambiguous.** Is it the end of the -5 tier or the start of the -10 tier? A difference of 5 composite points hangs on this.

- **RSI = 85:** The "80-85" tier would include it (upper bound), but "RSI > 85" uses strict greater-than, which excludes 85 exactly. So RSI = 85 falls in the **80-85 tier** (subtract 10). This is unambiguous due to the `>` operator.

**Verdict: FLAW at RSI = 80.** Overlapping boundary. RSI = 75 is technically ambiguous but probably intended as inclusive. RSI = 85 is unambiguous. RSI = 80 is a **critical ambiguity** where the penalty doubles from 5 to 10.

---

### 5. ADX exactly 25, 35 — which RSI interpretation?

**Exact threshold text (scoring-rubrics.md, lines 42-45):**
```
ADX > 35:    Momentum CONFIRMATION — 0.5x multiplier
ADX 25-35:   Partial penalty — 0.6x multiplier
ADX < 25:    Full penalty — 1.0x multiplier
```

**Analysis:**
- **ADX = 35:** The first tier requires `ADX > 35` (exclusive). So ADX exactly 35 does NOT qualify for 0.5x. It falls in the "25-35" tier (0.6x). **Unambiguous** due to `>` operator — but the dash notation for 25-35 makes it unclear whether 35 is included in this range. Since `>35` excludes it from the first tier, it must be here. Consistent but fragile.

- **ADX = 25:** The third tier requires `ADX < 25` (exclusive). So ADX exactly 25 does NOT qualify for 1.0x full penalty. It falls in the "25-35" tier (0.6x). **Unambiguous** due to `<` operator.

**Verdict: CLEAN (barely).** The explicit `>` and `<` operators on adjacent tiers resolve the boundary values by exclusion. The dash notation "25-35" is implicitly inclusive on both ends because the neighboring tiers use strict inequalities. However, this consistency is accidental rather than deliberate — the spec never states this principle.

---

### 6. 1M return exactly 15%, 30%, 60% — which extension category?

**Exact threshold text (scoring-rubrics.md, lines 387-391):**
```
EXTREME: 1M >= 60%
HIGH:    1M >= 30%
MEDIUM:  1M >= 15%
LOW:     1M < 15%
```

**Analysis:** These use `>=` operators, which are explicit. The evaluation order matters:
- **1M = 60%:** Satisfies `>= 60%` → EXTREME. Also satisfies `>= 30%` and `>= 15%`, but EXTREME takes priority (listed first). **Unambiguous** if evaluated top-down.
- **1M = 30%:** Satisfies `>= 30%` → HIGH. Also satisfies `>= 15%`. HIGH takes priority. **Unambiguous** if evaluated top-down.
- **1M = 15%:** Satisfies `>= 15%` → MEDIUM. **Unambiguous.**

**However**, the spec does not explicitly state "evaluate top-down, first match wins." If someone evaluates bottom-up or checks all conditions simultaneously, 1M=60% would match EXTREME, HIGH, and MEDIUM. The implicit assumption is cascading priority.

**Verdict: MOSTLY CLEAN.** The `>=` operators are explicit and unambiguous. The priority ordering is implicit but strongly implied by the table layout (EXTREME first, LOW last). A pedantic reading could still find ambiguity since no explicit "first match wins" rule is stated.

---

### 7. Trade count exactly 5, 10, 15 — which backtest cap?

**Exact threshold text (scoring-rubrics.md, lines 222-225):**
```
<5 trades:    cap at 2
5-9 trades:   cap at 4
10-14 trades: cap at 6
15+ trades:   no cap
```

**Analysis:**
- **5 trades:** `<5` is exclusive, so 5 is NOT in the first tier. "5-9" includes 5. → Cap at 4. **Unambiguous.**
- **10 trades:** "5-9" excludes 10. "10-14" includes 10. → Cap at 6. **Unambiguous.**
- **15 trades:** "10-14" excludes 15. "15+" includes 15. → No cap. **Unambiguous.**

The Adaptive Backtest Weighting table (lines 237-240) uses the same breakpoints:
```
< 5:   2% weight
5-9:   5% weight
10-14: 8% weight
>= 15: 10% weight
```

Here `< 5` and `>= 15` are explicit. The middle ranges use dash notation, but the explicit boundaries on the extremes resolve them.

**Verdict: CLEAN.** The `<5` and `15+`/`>=15` explicit operators create unambiguous boundaries. The dash ranges are fully constrained.

---

### 8. B&H return exactly 50%, 100% — which penalty rule?

**Exact threshold text (scoring-rubrics.md, lines 228-231):**
```
B&H return > 100%:  Penalty WAIVED
B&H return > 50% AND best strategy > 0: Penalty reduced to -1
B&H return > 0% AND best strategy < 0: Full -2 penalty
B&H return < 0% AND best strategy > 0: BONUS +2
```

**Analysis:**
- **B&H = 100%:** `> 100%` is exclusive. So B&H exactly 100% does NOT get penalty waived. It falls to `> 50%` — penalty reduced to -1. **Unambiguous but potentially surprising.** A return of 100.0% gets penalized while 100.01% does not.

- **B&H = 50%:** `> 50%` is exclusive. So B&H exactly 50% does NOT get the reduced penalty. It falls to `> 0%` — which would apply the full -2 penalty (if best strategy < 0). **Unambiguous but again, the boundary creates a discontinuity.**

- **B&H = 0%:** Falls between `> 0%` and `< 0%`. Neither condition matches. **Gap — B&H exactly 0% has no specified rule.** This is a genuine **hole in the specification.**

**Verdict: FLAW at B&H = 0%.** There is a gap — the rules cover `>0%`, `<0%`, and `>50%`, `>100%`, but exactly 0% is unspecified. The `>` operators are explicit but create an undocumented gap at the zero boundary. Additionally, the mutual exclusivity of the four rules is not clearly stated — can both "B&H > 50%" and "B&H > 0% AND best strategy < 0" apply simultaneously? (Presumably not, since `>50%` implies `>0%`, so the first matching rule takes priority, but this is not stated.)

---

### 9. Quality Score exactly 60 — does the quality floor fire?

**Exact threshold text (synthesize.md, lines 173-174):**
```
if composite < 40 (SELL territory) BUT Quality Score >= 60: OVERRIDE to HOLD (40).
```

**And from scoring-rubrics.md, line 374:**
```
Critical rule: NEVER produce SELL when Quality >= 60
```

**And the Quality-Timing Signal Matrix (scoring-rubrics.md, lines 365-373):**
```
>= 60   >= 60   → STRONG BUY
>= 60   40-59   → HOLD
>= 60   < 40    → HOLD
40-59   >= 60   → CAUTIOUS BUY
40-59   < 40    → AVOID
< 40    Any     → SELL
```

**Analysis:** Quality Score exactly 60 satisfies `>= 60`. The quality floor fires. **Unambiguous.** The `>=` operator is explicit.

**Verdict: CLEAN.** The `>=` operator is consistent across all three locations where this rule appears.

---

### 10. Tech vs Fund gap exactly 5 — consistency check

**Exact threshold text:**

scoring-rubrics.md, line 284:
```
Technical vs Fundamental diverge by >=5 points: subtract 3 from composite. Do NOT force HOLD.
```

synthesize.md, line 143:
```
Technical vs Fundamental diverge by >=5 points: subtract 3
```

**Analysis:** Both files use `>=5`, which is explicit and consistent. A gap of exactly 5 triggers the -3 penalty. **Consistent across both files.**

**Verdict: CLEAN.** Both files agree on `>=5` (inclusive).

---

### 11. EBP exactly 30%, 50%, 65%, 80% — which modifier?

**Exact threshold text (scoring-rubrics.md, lines 308-313, and synthesize.md, lines 163-164):**
```
EBP >= 80%: +3
EBP >= 65%: +1
EBP < 50%: -2
EBP < 30%: -4
```

**Analysis:**
- **EBP = 80%:** `>= 80%` → +3. **Unambiguous.**
- **EBP = 65%:** `>= 65%` → +1. Also satisfies neither `>=80%` nor `<50%`. **Unambiguous** (assuming top-down precedence; but since `>=80%` is stricter and 65% doesn't satisfy it, this is clean).
- **EBP = 50%:** Does NOT satisfy `<50%` (exclusive). Does NOT satisfy `>=65%`. **Falls in a GAP.** There is no rule for EBP in the range [50%, 65%). No modifier is specified. **This is a gap in the spec.**
- **EBP = 30%:** Does NOT satisfy `<30%` (exclusive). Satisfies `<50%` → -2. **Unambiguous.**

**Additional issue:** The evaluation order matters. EBP = 85% satisfies BOTH `>=80%` (→ +3) and `>=65%` (→ +1). The spec does not say "first match wins" or "use highest tier." It's implied but not stated.

**Verdict: FLAW.** There is a specification gap for EBP in the range [50%, 65%). A stock with a 55% beat probability gets no modifier, despite being just barely above coin-flip odds. This also creates an awkward discontinuity: EBP = 49.9% gets -2 penalty, but EBP = 50.0% gets nothing. That is a +2 point jump in composite from a 0.1% EBP change.

---

### 12. Two overrides both wanting to be "the larger penalty" when equal

**Exact threshold text (scoring-rubrics.md, lines 291-292):**
```
EXTREME (1M >= 60%): subtract 5. Does NOT stack with Override 1 — use larger penalty.
HIGH (1M >= 30%): subtract 2. Does NOT stack with Override 1 — use larger penalty.
```

**synthesize.md, lines 154-156:**
```
Does NOT stack with Override 1 (overbought). If both apply, use the LARGER penalty only.
  - Example: RSI 78 = -5 (Override 1) + EXTREME extension = -5 (Override 5). Use -5, not -10.
```

**Analysis:** The example explicitly shows the equal-penalty case: Override 1 = -5, Override 5 = -5. The answer is "Use -5, not -10." So when both are equal, you apply the penalty once (value = -5). **This is explicitly specified by example.**

However, the wording says "use the LARGER of the two penalties" — when both are -5, which is "larger"? Mathematically, -5 = -5, so "the larger" is -5. The example confirms: apply -5, not -10. The language is slightly awkward ("larger" implies strict ordering), but the example resolves it.

**Verdict: CLEAN (by example, not by rule text).** The rule text alone ("use larger") is technically ambiguous when equal, but the worked example at synthesize.md line 155 resolves it explicitly. If someone reads only scoring-rubrics.md without synthesize.md, they could be confused.

---

### 13. Negative 1M return — does the extension override handle it?

**Exact threshold text (scoring-rubrics.md, lines 387-391):**
```
EXTREME: 1M >= 60% OR (1M >= 40% AND 3M >= 90%)
HIGH:    1M >= 30% OR (1M >= 20% AND 3M >= 60%)
MEDIUM:  1M >= 15% OR 3M >= 30%
LOW:     1M < 15% AND 3M < 30%
```

**Analysis with 1M = -20%:**
- EXTREME: -20% >= 60%? No. -20% >= 40%? No. → Not EXTREME.
- HIGH: -20% >= 30%? No. -20% >= 20%? No. → Not HIGH.
- MEDIUM: -20% >= 15%? No. Need to check 3M. If 3M >= 30%, then MEDIUM. If 3M < 30%, then not MEDIUM.
- LOW: -20% < 15%? Yes. If 3M < 30%? If yes → LOW.

**So a negative 1M return correctly falls to LOW (no penalty)** in most cases. The `>=` operators work correctly with negative values — a negative number is always less than any of the positive thresholds.

**However, there is one edge case:** The **recovery stock exception** says "if 6M < 0 AND 1M > 0, reduce category by one tier." A stock with 1M = -20% does NOT trigger this exception (since 1M is not > 0). But what about 1M = -20% and 3M = +35%? That gives MEDIUM (from 3M >= 30%). This is a stock that went up significantly over 3 months but dropped 20% in the last month — the extension penalty treats it as MEDIUM (no modifier) which is correct since the 3M trend is still up.

**What about 1M = -20% and 3M = -50%?** Both conditions for LOW are met (-20% < 15% AND -50% < 30%). Correctly classified as LOW.

**Verdict: CLEAN.** Negative 1M values are handled correctly by the `>=` comparisons. The classification logic works as intended for all negative values tested. No accidental misclassification.

---

## SUMMARY OF FINDINGS

| # | Boundary | Status | Severity |
|---|----------|--------|----------|
| 1 | Composite 39/40 (SELL/HOLD) | **FLAW** — no inclusive/exclusive spec, no hysteresis | HIGH |
| 2 | Composite 59/60 (HOLD/BUY) | **FLAW** — same as #1 | HIGH |
| 3 | PEG 1.2 and 2.0 | **FLAW** — overlapping dash ranges at boundaries | MEDIUM |
| 4 | RSI = 80 | **FLAW** — overlapping tiers (-5 vs -10) | HIGH |
| 5 | ADX 25, 35 | Clean (resolved by `>` and `<` on adjacent tiers) | — |
| 6 | 1M return 15%, 30%, 60% | Mostly clean (`>=` explicit, priority implied) | LOW |
| 7 | Trade count 5, 10, 15 | Clean (resolved by `<5` and `15+` explicit operators) | — |
| 8 | B&H return 0% | **FLAW** — gap at exactly 0% (neither `>0%` nor `<0%`) | MEDIUM |
| 9 | Quality Score = 60 | Clean (`>=60` explicit and consistent) | — |
| 10 | Tech/Fund gap = 5 | Clean (`>=5` consistent across both files) | — |
| 11 | EBP 50%-65% range | **FLAW** — no rule for this range; discontinuity at 50% | HIGH |
| 12 | Equal override penalties | Clean (resolved by worked example in synthesize.md) | — |
| 13 | Negative 1M return | Clean (negative values correctly fall below all `>=` thresholds) | — |

### Critical Issues Requiring Fixes

1. **Composite decision thresholds (#1, #2):** Should use explicit notation: `>= 75`, `>= 60 AND < 75`, `>= 40 AND < 60`, `>= 25 AND < 40`, `< 25`. Consider adding a 1-2 point hysteresis band to prevent signal oscillation.

2. **PEG boundaries (#3):** Change to explicit half-open intervals: `[0.8, 1.2)`, `[1.2, 2.0)`, `[2.0, 3.0]`. Currently PEG = 1.2 and PEG = 2.0 are double-claimed.

3. **RSI = 80 (#4):** Change tiers to `[75, 80)` and `[80, 85]` or equivalent explicit notation. Currently RSI = 80 could incur either -5 or -10 penalty — a 5-point composite swing on a rounding difference.

4. **B&H = 0% (#8):** Add a rule for B&H exactly 0%: either "no penalty, no bonus" or merge it with one of the adjacent rules by changing `>0%` to `>=0%`.

5. **EBP gap at 50%-65% (#11):** Add a rule for EBP in [50%, 65%): either "no modifier" (making the gap intentional) or add a -1 modifier for this range. The current spec creates a +2 discontinuity at exactly EBP = 50% (from -2 to 0).