# Adversarial Audit: Sentiment Calibration
## Date: 2026-05-06

I'll start by reading all the relevant files to conduct this audit.

---

Now let me read the PLTR sentiment report and find other sentiment reports.

---

Now let me also look at a couple more reports to get broader patterns.

---

Now I have comprehensive data from the rubrics, the command file, and four actual sentiment reports. Let me compile the full audit.

---

# Adversarial Audit: Sentiment Scoring Calibration

## FLAW 1: Reddit Subreddit Mixing Without Separation

**Rubric text (scoring-rubrics.md, line 150):**
> `Reddit | market_sentiment | 0.30 | Direct % bullish. >60% = bullish, <40% = bearish`

**Command text (analyze-sentiment.md, line 70):**
> `mcp__tradingview-analysis__market_sentiment with symbol=$ARGUMENTS, market="stocks" — Reddit sentiment across r/stocks, r/wsb, r/investing, r/options`

**Evidence from reports:**
- PLTR report (line 129): "Sources: r/stocks, r/investing, r/wallstreetbets, r/StockMarket, r/ValueInvesting" -- all lumped into a single score of -0.133 (Bearish, 20% bullish / 60% bearish).
- AMD report (line 27): "Posts analyzed: 25 across r/stocks, r/investing, r/wallstreetbets, r/StockMarket, r/ValueInvesting" -- single score of 0.133 (Bullish), but described as "Low engagement on AMD-specific posts; sentiment tool returned tangential results. The 20% bullish vs 20% bearish split is essentially neutral."
- BBAI report (line 37): "market_sentiment tool returned mostly irrelevant posts -- low signal quality"

**Impact:** There is **zero separation** between subreddits. The `market_sentiment` MCP tool returns a single blended score across all subreddits. This is deeply problematic:

1. **r/wallstreetbets** skews contrarian/speculative -- bullish sentiment there often means retail FOMO at tops, and bearish sentiment sometimes precedes squeezes. Studies show WSB sentiment has weak or inverse predictive power for 30+ day horizons.
2. **r/investing** and **r/ValueInvesting** skew conservative and long-term -- bearish sentiment there is a different signal entirely (usually valuation-driven, not momentum-driven).
3. **r/options** users have directional AND non-directional strategies -- a bearish post there might just be someone describing a put credit spread (actually bullish).
4. The AMD report demonstrates the core problem: the tool returns "tangential results" that are "essentially neutral" despite being labeled "Bullish." This noise propagates at 0.30 weight -- the highest single platform weight.

**Proposed fix:**
- Request subreddit-level breakdown from `market_sentiment` if the tool supports it (check its API schema).
- If breakdown is unavailable, implement a **confidence discount**: when the tool reports fewer than 10 on-topic posts for the specific symbol, reduce Reddit weight to 0.15 and redistribute 0.15 to News NLP (which at least processes symbol-specific content).
- Add a rubric rule: "If Reddit posts analyzed < 10 AND symbol-specific posts < 5, note 'LOW REDDIT SIGNAL QUALITY' and halve Reddit weight."
- Long-term: Add a WSB-specific contrarian inversion flag. If >70% of WSB posts are bullish on a stock that has already run 30%+ in 1M, treat as a bearish signal (retail piling in at top).

---

## FLAW 2: 40% Weight on Second-Hand Social Sentiment Data

**Rubric text (scoring-rubrics.md, lines 151-153):**
> `Twitter/X | WebSearch | 0.20 | Claude classifies top 5-10 results. Login walls -> redistribute`
> `StockTwits | WebSearch | 0.20 | Extract bull/bear ratio if available. Unavailable -> redistribute`

**Command text (analyze-sentiment.md, lines 77-78):**
> `"$ARGUMENTS stock twitter sentiment" — Twitter/X sentiment (fastest-moving platform)`
> `"$ARGUMENTS site:stocktwits.com" — StockTwits sentiment (has built-in bullish/bearish tagging)`

The data provenance note on line 78 correctly states:
> `WebSearch for Twitter/StockTwits returns articles ABOUT platform sentiment, not actual platform data.`

**Evidence from reports:**
- PLTR Twitter/X (line 134): "Estimated Score: 60% bullish / 40% bearish" -- this is an *estimate* from news articles, not measured data.
- PLTR StockTwits (line 140): "Shifted from 'Bearish' to 'Extremely Bullish' post-earnings" -- sourced from editorial summary.
- AMD Twitter/X (line 33): "Sentiment score: 77/100 (AltIndex aggregate)" -- a third-party aggregator's number, not Twitter data.
- AMD StockTwits (line 38): "via editorial summary"
- CRDO StockTwits (line 31): "Bull/Bear ratio: ~70% bulls (estimated from editorial coverage)" -- the tilde and "estimated" reveal this is a guess.
- BBAI Twitter/X (line 42): "19 bearish vs 7 bullish technical signals" -- sourced from TimothySykes, a single commentator.

**Impact:** 40% of the sentiment dimension's weight rests on data that is:
1. **Time-lagged:** Articles about Twitter sentiment may reference data hours or days old.
2. **Selection-biased:** Articles covering sentiment tend to cherry-pick extreme views for engagement.
3. **Unverifiable:** There is no way to confirm "60% bullish" when it's estimated from an editorial.
4. **Inconsistent methodology:** AMD uses "AltIndex aggregate," PLTR uses Claude's classification of search results, CRDO uses "estimated from editorial coverage." Each report derives these numbers differently.

This is not 40% weight on sentiment data. It is 40% weight on **Claude's interpretation of journalists' interpretations of platform sentiment** -- two layers of telephone game.

**Proposed fix:**
- Reduce combined Twitter/StockTwits weight from 0.40 to 0.20 when data is exclusively from WebSearch (no direct API).
- Redistribute 0.20 to: News NLP (+0.10, which uses actual article text), and Reddit (+0.05) and Analyst Events (+0.05).
- Add a "data quality multiplier" to each platform: **Direct API = 1.0x**, **Via news reports = 0.5x**, **Unavailable = 0x (redistribute)**. The current rubric acknowledges redistribution on unavailability but not on quality degradation.
- Revised weights when all social is second-hand:

| Platform | Current Weight | Proposed Weight |
|----------|:---:|:---:|
| Reddit (1st party) | 0.30 | 0.35 |
| Twitter/X (2nd hand) | 0.20 | 0.10 |
| StockTwits (2nd hand) | 0.20 | 0.10 |
| News NLP (1st party) | 0.20 | 0.30 |
| Analyst Events (1st party) | 0.10 | 0.15 |

---

## FLAW 3: Multi-Agent Analysis Buried in 7% Sentiment Dimension

**Rubric text (scoring-rubrics.md, line 141):**
> Multi-agent analysis appears only in Sentiment scoring criteria: "multi-agent BUY high confidence" contributes to 9-10 Sentiment.

**Command text (analyze-sentiment.md, line 71):**
> `mcp__tradingview-analysis__multi_agent_analysis — 3-agent debate: Technical + Sentiment + Risk Manager`

**Evidence from reports:**
- PLTR (line 160-165): Multi-agent consensus was **STRONG SELL, net score -6, high confidence bearish across all three agents**. Yet this result is buried inside a Sentiment dimension worth 7% of the composite. The PLTR composite sentiment summary assigned the multi-agent result a weight of only 10% *within* the sentiment section (line 366), meaning its effective weight on the final composite is 7% x 10% = **0.7% of the total score**.
- AMD (line 83-86): Multi-agent consensus was BUY (net +2, medium confidence).
- CRDO (line 47-50): "multi_agent_analysis returned JSON parsing error from MCP server. Data unavailable." -- silently skipped with no scoring penalty.
- GEV (line 52-55): "N/A (Sunday -- tool unavailable)" -- silently skipped.
- BBAI (line 66-69): "multi_agent_analysis failed" -- silently skipped.

**Impact:** This is the most structurally significant flaw in the scoring framework.

The multi-agent analysis synthesizes Technical, Sentiment, AND Risk perspectives into a unified verdict. It is the only tool that performs cross-dimensional analysis. When three independent agents unanimously agree on STRONG SELL at -6, that should be a significant signal. Instead:

1. At 0.7% effective composite weight, a unanimous STRONG SELL is mathematically irrelevant.
2. When the tool fails (3 of 5 reports examined), it is simply marked N/A with no fallback and no weight redistribution. The rubric has no rule for "multi-agent unavailable."
3. The adversarial audit question notes this was identified before. It was not implemented.

**Proposed fix:**
- Create a new **Override 8: Multi-Agent Consensus Override**:
  - If all 3 agents agree on SELL/STRONG SELL (net score <= -4): subtract 3 from composite. Note "MULTI-AGENT CONSENSUS: All agents bearish. Net score {X}."
  - If all 3 agents agree on BUY/STRONG BUY (net score >= +4): add 2 to composite. (Asymmetric because downside protection is more valuable than upside confirmation.)
  - If 2/3 agents agree with net score <= -2 or >= +2: subtract/add 1.
  - If tool fails: no override. Note "MULTI-AGENT UNAVAILABLE -- no override applied."
- Do NOT keep it inside Sentiment. It is a cross-dimensional signal and belongs in the override chain.

---

## FLAW 4: News NLP Weight Not Reduced When Articles Are Paywalled

**Rubric text (scoring-rubrics.md, line 153):**
> `News NLP | WebFetch articles | 0.20 | Per-article: positive/negative/neutral + impact. Tier 1 (Reuters, Bloomberg, WSJ) = 1.0x, Tier 2 (CNBC, Yahoo) = 0.8x, Tier 3 (blogs) = 0.5x`

**Command text (analyze-sentiment.md, lines 104-108):**
> Compliance checklist item 4: `If WebFetch returns 403/paywall, note 'PAYWALLED — sentiment from headline only (lower confidence)'`
> Item 5: `At least 1 Tier 1 source (Reuters, Bloomberg, WSJ) sought via WebSearch`

**Evidence from reports:**
- PLTR (line 148-151): CNBC returned 403 (paywalled). Only 2 of 3 articles were fetched. Bloomberg was not attempted. The 0.20 weight was applied in full.
- AMD (line 63): "CNBC: PAYWALLED -- sentiment from headline only (lower confidence)." Bloomberg was paywalled. Both Tier 2 articles that were accessible were from StockTwits editorial -- effectively Tier 3 quality. Full 0.20 weight applied.
- GEV (line 41-42): "Seeking Alpha article: PAYWALLED," "Motley Fool article: 404 Not Found." Only 2 articles successfully fetched, both Tier 2. Marked "NEWS NLP: PARTIAL."
- CRDO (line 39): "NEWS NLP: INCOMPLETE -- fewer than 3 of 5 compliance items fully met (no Tier 1 source obtained, limited WebFetch success on paywalled articles)."

**Impact:** When 3 of 3 articles are paywalled:
1. The rubric says "note PAYWALLED" but continues to apply the full 0.20 weight based on **headline-only sentiment**.
2. Headlines are explicitly called out as unreliable: "Headlines are often clickbait" (line 112). Yet the rubric provides no mechanism to reduce the weight when forced to rely on them.
3. Tier 1 sources (Bloomberg, WSJ, Reuters) are almost always paywalled. The compliance checklist requires "at least 1 Tier 1 source sought" but not "obtained." Seeking is meaningless if 100% of Tier 1 is paywalled.
4. The "NEWS NLP: INCOMPLETE" warning is noted in the report but has no scoring consequence.

**Proposed fix:**
- Add a **paywall discount schedule** to the rubric:

| Articles Successfully Fetched | Effective News NLP Weight |
|:---:|:---:|
| 3+ (full text) | 0.20 (full) |
| 2 (full text) + 1 paywalled | 0.15 |
| 1 (full text) + 2 paywalled | 0.10 |
| 0 (all paywalled/failed) | 0.05 (headline-only floor) |

- Redistribute lost weight proportionally to Reddit and Analyst Events (both first-party data).
- Add a "HEADLINE-ONLY CONFIDENCE" tag to the Sentiment dimension score when >50% of articles are paywalled, which should trigger a cap of 6 on the Sentiment dimension (cannot be confident about 7+ scores on headline-only data).
- Consider adding `getPressReleases` and `searchStockNews` (FMP) as alternative full-text sources that are not paywalled. These are already called in Phase 11 Step 1 but are not used as News NLP inputs.

---

## FLAW 5: Analyst Events Underweighted at 0.10

**Rubric text (scoring-rubrics.md, line 154):**
> `Analyst events | getStockGradeNews | 0.10 | Upgrades +1, downgrades -1. This week = 2x, this month = 1x, older = 0.5x`

**Evidence from reports:**
- PLTR (line 153-155): HSBC downgraded to Hold, DA Davidson cut PT from $180 to $165. These occurred same-week as earnings -- 2x recency multiplier. Yet at 0.10 weight within a 7% dimension, the effective composite contribution is 7% x 10% = **0.7%**.
- AMD (line 76-80): 3 upgrades vs 1 downgrade, including DA Davidson upgrading to Buy with 70% PT raise and Goldman initiating. At 0.7% effective weight, this strong bullish signal is nearly invisible.
- CRDO (line 42-43): 5 upgrades, 0 downgrades, Goldman Sachs initiated Buy. 0.7% effective weight.

**Impact:**
1. The adversarial question correctly notes that analyst PT revision *acceleration* is one of the strongest pre-earnings signals. Academic research (Loh & Stulz 2011, Bradshaw et al. 2012) finds that analyst revision velocity has significant predictive power for post-earnings drift.
2. The pre-earnings weight switch (scoring-rubrics.md, lines 336-348) increases Sentiment from 7% to 20%, which helps, but analyst events remain at 0.10 within that 20%. This gives analyst events an effective weight of 20% x 10% = **2%** pre-earnings -- still too low given the signal quality.
3. The rubric captures recency (this week = 2x) but not acceleration (3 upgrades in 2 weeks vs 3 upgrades spread over 6 months). Both score identically.

**Proposed fix:**
- Increase Analyst Events weight from 0.10 to 0.20 within the Sentiment dimension. This is first-party, verifiable, professional data from analysts who stake their reputation on the call.
- Reduce StockTwits from 0.20 to 0.10 (second-hand data, as argued in Flaw 2) to fund this rebalancing.
- Add an **analyst revision acceleration** modifier:
  - 3+ upgrades in 14 days with no downgrades: +1 to Sentiment. "UPGRADE CLUSTER: {N} upgrades in {days} days."
  - 3+ downgrades in 14 days: -1 to Sentiment. "DOWNGRADE CLUSTER."
  - PT raises averaging >20% across 2+ analysts in 30 days: +1. "PT ACCELERATION: Avg +{X}% across {N} analysts."

---

## FLAW 6: Divergence Cap Has No Numerical Threshold

**Rubric text (scoring-rubrics.md, line 158):**
> `Divergence cap: If platforms disagree strongly, cap Sentiment at 5 and note "SENTIMENT DIVERGENCE."`

**Evidence from reports:**
- PLTR: Reddit = Bearish (20% bullish), StockTwits = "Extremely Bullish," Twitter/X = "60% bullish." This is a massive divergence: Reddit at 20% bullish vs StockTwits at "Extremely Bullish." The PLTR report did NOT apply the divergence cap. The composite sentiment summary (line 355) does not mention "SENTIMENT DIVERGENCE" anywhere.
- This means the cap was either (a) not triggered because there is no defined threshold, or (b) was overlooked.

**Impact:** "Disagree strongly" is subjective. Without a numerical threshold:
1. The rule is unenforceable and inconsistently applied.
2. The PLTR case is a textbook example where it should trigger -- one platform at 20% bullish and another at "Extremely Bullish" is as divergent as it gets.
3. The scenario in the question (Reddit +0.8, StockTwits -0.5) would also clearly qualify, but the rubric gives no way to confirm.

**Proposed fix:**
Add explicit divergence criteria to the rubric:

```
Divergence triggers (ANY one triggers the cap):
1. Two platforms differ by >= 40 percentage points in bullish% 
   (e.g., Reddit 20% bullish, StockTwits 70% bullish = 50pp gap -> TRIGGERED)
2. One platform classified "Bullish/Very Bullish" AND another 
   classified "Bearish/Very Bearish"
3. Weighted platform sentiment spread: highest platform score - 
   lowest platform score >= 0.6 on [-1, +1] scale

When triggered: Cap Sentiment dimension at 5. Note: "SENTIMENT 
DIVERGENCE: {Platform A} = {score}, {Platform B} = {score}. 
Gap: {N}pp. Capped at 5."
```

This would have triggered for PLTR (Reddit 20% bullish vs StockTwits "Extremely Bullish" = gap well over 40pp).

---

## FLAW 7: Earnings Whisper WebSearch Returns Paid Sites Without Fallback

**Command text (analyze-sentiment.md, line 76):**
> `WebSearch query: "$ARGUMENTS earnings whisper estimate {current_year}" — whisper numbers (buy-side expectations). Often higher than published consensus. If actual beats whisper, reaction is more positive than just beating consensus.`

**Evidence from reports:**
- None of the four reports I reviewed (PLTR, AMD, CRDO, BBAI) mention whisper numbers in their output. The data point was called in Phase 11 Step 1 but does not appear in any report section. There is no dedicated "Earnings Whisper" field in the output template (analyze-sentiment.md, lines 169-250).
- The output template has no whisper number field at all.

**Impact:**
1. The WebSearch for "earnings whisper" typically returns earningswhispers.com (subscription required), estimize.com (freemium with limited data), and occasional analyst blog posts with informal estimates.
2. Even when whisper numbers are obtained, there is no scoring rule for them. The rubric's Earnings Catalyst Modifier (scoring-rubrics.md, lines 298-315) uses beat_history, estimate revisions, and surprise magnitude -- but none reference whisper numbers.
3. This is a data collection step with no downstream consumption. The API call burns context window budget for no scoring impact.

**Proposed fix:**
- Either integrate whisper numbers into the Earnings Catalyst Modifier (Override 6):
  ```
  If whisper number is available AND actual > whisper: EBP +5%
  If whisper number is available AND actual < whisper but > consensus: EBP -5%
  If whisper number is available AND actual < whisper AND < consensus: EBP -10%
  ```
  And add a field to the output template: `Whisper estimate: $X.XX (source: {source}) | vs Consensus: {higher/lower by $Y}`
- Or remove the WebSearch call entirely to save context budget. Half-implemented data collection is worse than none -- it creates false completeness.

---

## FLAW 8: After-Hours Data Collected But Not Scored

**Command text (analyze-sentiment.md, lines 89-90):**
> `getAftermarketQuote — after-hours bid/ask, price, volume. Critical for earnings reaction detection.`
> `getAftermarketTrade — AH trade prices, sizes, timestamps. Large block trades in AH = institutional conviction.`

**Evidence from reports:**
- PLTR report: No after-hours section exists in the output. The after-hours data, if collected, does not appear anywhere.
- AMD report: No after-hours section. AMD was analyzed pre-earnings (May 4 for May 5 earnings), but `getAftermarketQuote` and `getAftermarketTrade` are called unconditionally.
- The output template (analyze-sentiment.md, lines 169-250) has **no field** for after-hours data. There is no `## After-Hours Activity` section.
- The scoring rubric has **no rule** that references after-hours price movement. The command text says "Critical for earnings reaction detection" but the rubric has no mechanism to consume this data.

**Impact:**
1. Two API calls are made per analysis for data that has no scoring pathway and no output field.
2. The command text describes after-hours data as "critical" -- but critical for what? There is no rule like "AH move > +10%: EBP +15%" or "AH move < -5%: Risk -1."
3. AH data is most valuable for same-day post-earnings analysis (the stock reported tonight, what does AH tell us?). But the analysis pipeline doesn't distinguish pre-earnings vs. post-earnings runs of the command.

**Proposed fix:**
- Add a conditional trigger: Only call `getAftermarketQuote` and `getAftermarketTrade` when earnings were reported within the last 2 trading days (same condition as the Sell-the-News Detector, Override 7).
- Add scoring rules to the rubric:

```
After-Hours Reaction Modifier (triggers when earnings reported within 2 trading days):

| AH Move | AH Volume vs 30d Avg | Modifier |
|---------|---------------------|----------|
| > +10% | > 2x avg | Sentiment +2. "STRONG AH REACTION: +{X}%." |
| > +5% | > 1.5x avg | Sentiment +1. |
| -5% to +5% | Any | No modifier (normal range). |
| < -5% | > 1.5x avg | Sentiment -1. |
| < -10% | > 2x avg | Sentiment -2. "SEVERE AH SELLOFF: {X}%." |

AH Block Trade Signal:
- 3+ block trades (>10K shares) at increasing prices: +1 to Smart Money.
- 3+ block trades at decreasing prices: -1 to Smart Money.
```

- Add an `## After-Hours Reaction` section to the output template:
```markdown
## After-Hours Reaction (post-earnings only)
- AH Price: $X (+/-Y%)
- AH Volume: X shares (Zx avg)
- Block Trades: X trades > 10K shares
- Direction: {Accumulation/Distribution/Neutral}
```

---

## Summary of Cross-Cutting Issues

Beyond the 8 individual flaws, three systemic patterns emerge:

1. **Data collection without scoring rules.** Whisper numbers and after-hours data are collected but have no scoring pathway. This violates a basic principle: every data point should either influence the score or not be collected. The pipeline spends API calls and context window on dead-end data.

2. **Weight inertia on degraded data.** When data quality degrades (paywalled articles, second-hand social data, low Reddit signal), the rubric maintains full weight. The only adjustment is binary redistribution when a platform is completely unavailable. There is no continuous quality discount. This systematically overstates confidence.

3. **The 7% sentiment dimension is a dumping ground.** It contains: social media sentiment (3 platforms), news NLP, analyst events, multi-agent cross-dimensional analysis, and implicitly feeds from whisper numbers and AH data. These are fundamentally different signal types with different time horizons, reliability profiles, and predictive values. Cramming them all into 7% ensures none of them can meaningfully influence the composite.

The most impactful fixes, in priority order:
1. Extract multi-agent analysis into an override (Flaw 3) -- structural change, high impact.
2. Implement quality-weighted platform scoring (Flaw 2) -- accuracy improvement.
3. Define the divergence cap numerically (Flaw 6) -- enforcement fix; PLTR is already miscalibrated.
4. Add AH scoring rules (Flaw 8) -- wasted data without them.
5. Increase analyst events weight (Flaw 5) -- undervalued first-party signal.