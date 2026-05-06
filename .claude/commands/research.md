# Deep Research: $ARGUMENTS

Web-augmented deep dive for information not available through financial APIs. Covers social media sentiment beyond Reddit, full article NLP, M&A activity, institutional flow details, and earnings transcript analysis.

**Use this when:** `/project:analyze` has been run and you want deeper context, OR for qualitative research that APIs can't provide.

---

## Step 1: Social Media Deep Dive (3-4 WebSearch calls, parallel)

- `WebSearch` query: "$ARGUMENTS stock analysis {current_year}" — recent analysis posts, blog coverage, YouTube summaries
- `WebSearch` query: "$ARGUMENTS stock twitter sentiment {current_year}" — Twitter/X hot takes, analyst commentary, activist short reports
- `WebSearch` query: "$ARGUMENTS site:stocktwits.com" — StockTwits bull/bear ratio, trending messages
- `WebSearch` query: "$ARGUMENTS institutional flow dark pool {current_year}" — dark pool activity reports from public sources (approximation)

For each result set: classify sentiment (bullish/bearish/neutral), extract key themes, note credibility of sources.

---

## Step 2: Full Article NLP (4-5 WebFetch calls, sequential)

- `mcp__financial-modeling-prep__getStockNews` with symbol=$ARGUMENTS, limit=10 — get article URLs
- `mcp__financial-modeling-prep__searchStockNews` with symbols=$ARGUMENTS, limit=10 — symbol-specific news (more targeted)
- `mcp__financial-modeling-prep__getPriceTargetNews` with symbol=$ARGUMENTS, limit=10 — analyst price target changes with reasoning
- `mcp__financial-modeling-prep__getStockGradeNews` with symbol=$ARGUMENTS, limit=10 — analyst rating changes (upgrade/downgrade/initiation)
- `mcp__tradingview-analysis__financial_news` with symbol=$ARGUMENTS, category="stocks", limit=10 — real-time RSS feeds (Reuters, CoinDesk)
- `WebSearch` query: "$ARGUMENTS stock news {current_year}" — **MANDATORY companion to FMP news calls.** Captures analyst initiations, blog commentary, and breaking news that FMP may not index. **ALWAYS use BOTH FMP news tools AND WebSearch — never one without the other.**
- `WebFetch` the top 4-5 article URLs for full text (deduplicate, prioritize Tier 1 sources)

For each article analyze:
- **Key facts:** What happened? What numbers are cited?
- **Sentiment:** Positive, negative, or neutral toward the stock?
- **Impact magnitude:** High (earnings miss, regulatory action), Medium (analyst note, product launch), Low (opinion piece)
- **Time horizon:** Immediate (this week), Short-term (1-3 months), Long-term (1+ year)
- **Source credibility:** Tier 1 (Reuters, Bloomberg, WSJ, FT), Tier 2 (CNBC, Yahoo Finance, Barron's), Tier 3 (Seeking Alpha, blogs, unknown)

---

## Step 3: Company Press Releases (1 FMP call)

- `mcp__financial-modeling-prep__getPressReleases` with symbol=$ARGUMENTS, limit=15 — official company announcements

Analyze for: product launches, partnerships, guidance updates, executive changes, legal matters.

---

## Step 4: M&A Activity (2 calls, parallel)

- `mcp__financial-modeling-prep__searchMergersAcquisitions` with name={company name from profile} — check for M&A activity
- `WebSearch` query: "$ARGUMENTS acquisition merger {current_year}" — breaking M&A news not yet in filings

Flag: active acquirer (growth by acquisition risk), takeover target (potential premium), or no activity.

---

## Step 5: Institutional Deep Dive (1 FMP call)

- `mcp__financial-modeling-prep__getFilingExtractAnalyticsByHolder` with symbol=$ARGUMENTS, year={current}, quarter={adjusted per 13F lag} — which specific funds bought/sold, portfolio weight changes, new positions vs exits

Note: This is the detailed fund-by-fund analysis that the main /analyze pipeline defers to /research (main pipeline uses `getPositionsSummary` for the overview).

---

## Step 6: Earnings Transcript Analysis (1 FMP call, if not already done)

- `mcp__financial-modeling-prep__getEarningsTranscript` with symbol=$ARGUMENTS, year={most recent}, quarter={most recent}

Full NLP analysis:
- **Management tone:** Confident/cautious/defensive? Count hedging language ("uncertain", "challenging", "headwinds") vs confidence language ("strong", "accelerating", "exceeding")
- **Forward guidance:** Raised/maintained/lowered? Specific numbers or vague?
- **Key themes:** What did management emphasize? What questions did analysts push on?
- **Risk flags:** Unusual executive departures, accounting language changes, litigation mentions
- **Competitive positioning:** How did management discuss competitors?

---

## Step 7: Competitive Moat Assessment

Based on all collected data, assess:
- **Moat type:** Network effects, switching costs, cost advantages, intangible assets (brand/IP), efficient scale
- **Moat durability:** Widening, stable, or narrowing?
- **Key risks to moat:** Technology disruption, regulatory, competitive entry, customer concentration
- **Supply chain:** Any mentions of supply chain issues, single-source dependencies, geographic risks?

---

## Output

```
=== Deep Research: {SYMBOL} === {DATE} ===

## Social Sentiment (Beyond Reddit)
### Twitter/X
- Overall: {bullish/bearish/neutral}
- Key voices: {notable analysts, influencers, or institutions posting}
- Themes: {what's being discussed}

### StockTwits
- Bull/Bear: {X}% / {Y}%
- Trending: {yes/no}
- Volume: {high/normal/low message volume}

### Analyst Blogs & YouTube
- Coverage: {summary of analysis content}
- Consensus: {bullish/bearish/mixed}

## News Deep Dive
| # | Source | Headline | Sentiment | Impact | Credibility |
|---|--------|----------|-----------|--------|-------------|
| 1 | ... | ... | ... | ... | Tier X |
Key finding: {most important article summary}

## Press Releases (last 10)
- {date}: {summary of each key release}
Most significant: {analysis of impact}

## M&A Activity
- Status: {active acquirer / takeover target / no activity}
- Details: {any deals, rumors, or filings}

## Institutional Flow (Detailed)
- Top buyers: {fund names, share counts, portfolio weights}
- Top sellers: {fund names, share counts}
- New positions: {funds initiating positions}
- Exits: {funds closing positions}
- Dark pool proxy: {any public reporting found}

## Earnings Transcript Analysis
- Tone: {confident/cautious/defensive}
- Forward guidance: {raised/maintained/lowered}
- Key themes: {bullet points}
- Risk flags: {any concerns}
- Analyst focus: {what analysts pushed on}

## Competitive Moat
- Type: {moat classification}
- Durability: {widening/stable/narrowing}
- Key risks: {bullet points}

## Supply Chain & Geographic Risk
- Dependencies: {single-source, geographic concentration}
- Risks: {identified supply chain or geopolitical risks}
```
