# Fundamental Analysis: $ARGUMENTS

Run Phases 2, 7, 8, 9 for the given symbol. This is a standalone entry point for fundamental-only analysis.

**Before starting:** Read `.claude/commands/_shared/asset-classifier.md` and `.claude/commands/_shared/error-handling.md`. If running standalone (not from orchestrator), first call `mcp__financial-modeling-prep__getCompanyProfile` to classify the asset type.

**Crypto route:** Skip this entire command — crypto has no traditional fundamentals.
**ETF route:** Phase 7 uses fund-specific tools instead.

---

## Phase 2: Macro & Sector Context

**6 calls, all cacheable per session (parallel):**
- Call `mcp__financial-modeling-prep__getTreasuryRates` — extract 2Y, 5Y, 10Y, 30Y yields. Check yield curve shape (2Y > 10Y = inverted = recession signal).
- Call `mcp__financial-modeling-prep__getStockPriceChange` with the sector ETF symbol based on the stock's sector:
  - Technology → XLK, Semiconductors → SMH, Financials → XLF, Energy → XLE, Healthcare → XLV, Consumer Discretionary → XLY, Industrials → XLI, Real Estate → XLRE, Utilities → XLU, Materials → XLB, Comm Services → XLC, Consumer Staples → XLP
  - **ETF route:** Compare to SPY instead (the ETF IS the sector)
- Call `mcp__financial-modeling-prep__getIndexQuote` with symbol="^VIX" — VIX fear gauge. Labels: <15 = "calm", 15-20 = "normal", 20-25 = "elevated", 25-30 = "fear", >30 = "PANIC"
- Call `mcp__financial-modeling-prep__getSectorPerformanceSnapshot` — real-time sector momentum. Fallback if sector ETF getStockPriceChange returns 402. Shows whether money is flowing into/out of this stock's sector.
- Call `mcp__financial-modeling-prep__getHistoricalIndustryPE` with industry={stock's industry from Phase 1} — industry P/E history. Contextualizes the stock's P/E vs. industry norm. A stock at P/E 135 in a sector averaging P/E 80 is different from P/E 135 in a sector averaging P/E 20.
- Call `mcp__financial-modeling-prep__getHistoricalSectorPerformance` — 3-month sector trend. Confirms or refutes sector ETF momentum signal.
- Call `mcp__financial-modeling-prep__getIndustryPESnapshot` with industry={stock's industry}, date={today YYYY-MM-DD} — current industry P/E. **Contextualizes valuation:** A P/E of 135 in a sector averaging 80 is very different from P/E 135 in a sector averaging 20.
- Call `mcp__financial-modeling-prep__getEconomicCalendar` with from={today}, to={today + 14 days} — upcoming CPI, FOMC, jobs data. **If major macro event coincides with earnings week, volatility amplifies.** Flag: "MACRO EVENT: {event} on {date} during earnings week."

**If sector ETF data returns 402:** Use `getSectorPerformanceSnapshot` as primary sector signal. If BOTH fail, cap Macro at 6 per scoring rubrics.

---

## Phase 7: Fundamentals + Financial Health

**18 FMP calls, parallel:**
- `mcp__financial-modeling-prep__getFinancialRatiosTTM` — P/E, P/B, EV/EBITDA, margins (gross, operating, net), current ratio, debt/equity, dividend yield, FCF ratios
- `mcp__financial-modeling-prep__getKeyMetricsTTM` — ROE, ROIC, EV/Sales, EV/OCF, netDebt/EBITDA, cash conversion cycle, R&D/revenue, income quality, Graham number (26 unique fields)
- `mcp__financial-modeling-prep__getIncomeStatement` with period="FY", limit=2 — absolute revenue ($), net income, EPS, R&D, SGA, **SBC (stock-based compensation)**. Needed for valuation, SBC margin adjustment, and reporting.
- `mcp__financial-modeling-prep__getIncomeStatementTTM` — trailing twelve months: more current than FY data. Use for run-rate estimates. When most recent quarter shows acceleration, TTM better reflects current earnings power.
- `mcp__financial-modeling-prep__getIncomeStatementGrowth` with period="quarter", limit=4 — QoQ revenue/EPS growth rates. **Growth ACCELERATION is the #1 earnings prediction signal.** If revenue growth is increasing each quarter, the stock is more likely to beat. Decelerating growth = sell-the-news risk.
- `mcp__financial-modeling-prep__getFinancialStatementGrowth` with period="FY", limit=2 — pre-calculated YoY growth rates + 3Y/5Y/10Y compounded rates
- `mcp__financial-modeling-prep__getCashFlowStatementGrowth` with period="quarter", limit=4 — FCF growth trajectory. **Decelerating FCF growth despite revenue growth = margin pressure warning.** Critical for catching PLTR-style sell-the-news setups.
- `mcp__financial-modeling-prep__getBalanceSheetStatement` with period="FY", limit=1 — cash, total debt, goodwill, inventory, receivables, working capital, total equity
- `mcp__financial-modeling-prep__getBalanceSheetStatementTTM` — trailing balance sheet for most current snapshot of cash/debt position
- `mcp__financial-modeling-prep__getCashFlowStatement` with period="FY", limit=1 — operating CF, capex, FCF, D&A. **Derive owner earnings:** net income + D&A - capex
- `mcp__financial-modeling-prep__getFinancialScores` — Altman Z-Score (bankruptcy risk: >3 safe, 1.8-3 grey, <1.8 distress) + Piotroski F-Score (financial strength: 0-9, higher better)
- `mcp__financial-modeling-prep__getRatios` with period="quarter", limit=4 — historical quarterly ratios. **Track margin trends over multiple quarters.** Deteriorating operating margin across 3+ quarters = fundamental warning even if absolute numbers look good.
- `mcp__financial-modeling-prep__getRevenueProductSegmentation` with period="annual" — which products/segments drive revenue, concentration risk
- `mcp__financial-modeling-prep__getRevenueGeographicSegmentation` with period="annual" — geographic revenue mix. Single non-US country >60% = geopolitical risk modifier for Risk scoring
- `mcp__financial-modeling-prep__getHistoricalMarketCap` with symbol=$ARGUMENTS, from_date={1 year ago YYYY-MM-DD}, limit=252 — daily market cap data. Sample quarterly (roughly every 63 trading days: Q-4, Q-3, Q-2, Q-1, now) to see if market is re-rating (expanding) or de-rating (contracting)
- `mcp__financial-modeling-prep__getOwnerEarnings` with symbol=$ARGUMENTS — Buffett-style owner earnings metric (complements manual D&A calculation)
- `mcp__financial-modeling-prep__getHistoricalEmployeeCount` with symbol=$ARGUMENTS — workforce growth trends. **Hiring leads revenue by 1-2 quarters.** If headcount grows faster than revenue, efficiency is declining. If headcount shrinks while revenue grows, margins will expand.
- `mcp__financial-modeling-prep__getExecutiveCompensation` with symbol=$ARGUMENTS — exec salary vs stock awards. **Heavy stock-based compensation = management incentive alignment.** Also needed for SBC margin adjustment.

**ETF route:** Replace Phase 7 with:
- `mcp__financial-modeling-prep__getFundHoldings` — top holdings and weights
- `mcp__financial-modeling-prep__getFundSectorWeighting` — sector allocation
- `mcp__financial-modeling-prep__getFundInfo` — expense ratio, AUM, inception date, strategy

---

## Phase 8: Peer Comparison

**2 calls, sequential then parallel:**

**Step 1:**
- Call `mcp__financial-modeling-prep__getStockPeers` with symbol=$ARGUMENTS — get list of peer companies. Take top 3-4 by relevance.
- If empty: note "No peer data available", skip to Phase 9.

**Step 2:**
- Call `mcp__financial-modeling-prep__getBatchQuotes` with symbols=$ARGUMENTS + top 3 peers (comma-separated, e.g., "AMD,NVDA,INTC,QCOM") — returns price, change%, marketCap, 50SMA, 200SMA for ALL in one call. This replaces 4 individual getQuote calls.

**Build peer comparison table:** Compare the stock vs peers on price momentum, market cap, and quick valuation metrics. For deeper valuation comparison, use the main stock's ratiosTTM data from Phase 7.

---

## Phase 9: Valuation & Analyst Targets

### Step 1 — Valuation models (4 calls, parallel)

- `mcp__financial-modeling-prep__getDCFValuation` with symbol=$ARGUMENTS — standard (unlevered) DCF intrinsic value
- `mcp__financial-modeling-prep__getLeveredDCFValuation` with symbol=$ARGUMENTS — levered DCF (accounts for debt). For leveraged companies, can differ 20-40% from unlevered. Together they create a valuation range.
- `mcp__financial-modeling-prep__calculateCustomDCF` with symbol=$ARGUMENTS and these parameters populated from earlier phases:
  - **revenueGrowthPct** = actual revenue growth rate from Phase 7 `getFinancialStatementGrowth`
  - **beta** = from Phase 1 `getCompanyProfile` (read from `reports/{SYMBOL}_technical.md` if running standalone)
  - **marketRiskPremium** = from `getMarketRiskPremium` (this call)
  - **riskFreeRate** = 10Y yield from Phase 2 `getTreasuryRates`
  - **costOfDebt** = interestExpense / totalDebt from Phase 7 `getBalanceSheetStatement` + `getIncomeStatement`
  - **taxRate** = from Phase 7 `getIncomeStatement` (incomeTaxExpense / incomeBeforeTax)
  - Remaining 12 of 18 parameters use FMP defaults (reasonable for most stocks)
- `mcp__financial-modeling-prep__getMarketRiskPremium` — equity risk premium. **Cache per session.**

**DCF usage in scoring (from `_shared/scoring-rubrics.md`):**
- Track A (Value): Average of standard DCF and levered DCF
- Track B (Growth): Use custom DCF. If still undervalues, PEG overrides.
- Always report all 3: "DCF range: $X (standard) / $Y (levered) / $Z (custom)"

**Growth detection:** Revenue growth >20% YoY (from Phase 7) OR P/E >40 → Track B.

### Step 2 — Analyst sentiment (8 calls, parallel)

- `mcp__financial-modeling-prep__getPriceTargetSummary` with symbol=$ARGUMENTS — analyst consensus target + analyst COUNT + standard deviation + high/low. "$180 from 3 analysts" vs "$180 from 25 analysts" is completely different confidence.
- `mcp__financial-modeling-prep__getPriceTargetConsensus` with symbol=$ARGUMENTS — structured consensus with targetHigh/targetLow/targetMedian/targetConsensus. More reliable than summary for scoring.
- `mcp__financial-modeling-prep__getPriceTargetLatestNews` with symbol=$ARGUMENTS — recent price target changes with analyst names, firm, date, old PT → new PT. Captures upgrade/downgrade ACCELERATION (e.g., 3 PT raises in 2 weeks = bullish catalyst signal).
- `mcp__financial-modeling-prep__getHistoricalStockGrades` with symbol=$ARGUMENTS, limit=10 — monthly aggregate analyst rating counts (Strong Buy/Buy/Hold/Sell) trend
- `mcp__financial-modeling-prep__getStockGradeNews` with symbol=$ARGUMENTS — recent upgrade/downgrade EVENTS with dates. Detects "3 downgrades this week" which monthly aggregates cannot see. Feeds into Sentiment and Smart Money.
- `mcp__financial-modeling-prep__getStockGradeSummary` with symbol=$ARGUMENTS — aggregated Strong Buy/Buy/Hold/Sell/Strong Sell counts with trend direction. More structured than event-level grade news.
- `mcp__financial-modeling-prep__getEarningsReports` with symbol=$ARGUMENTS — historical EPS actual vs estimated for last 4-8 quarters. Beat/miss pattern feeds into Fundamental and Risk scores. A stock that beats 8/8 quarters has fundamentally different risk than a serial misser. **Ensure all 8 quarters are retrieved.** If FMP returns 402, fallback to WebSearch for earnings history.
- `mcp__financial-modeling-prep__getAnalystEstimates` with symbol=$ARGUMENTS, period="quarter", limit=4 — forward EPS/revenue estimates for next 4 quarters. Rising estimates = analysts playing catch-up = bullish. Falling estimates = headwind. **Feeds into Earnings Catalyst Modifier (Override 6).**
- `mcp__financial-modeling-prep__getEarningsSurprisesBulk` with year={current year} — batch surprise data. **Track surprise MAGNITUDE trend.** If beat margin is INCREASING each quarter (e.g., +2.6% → +7.8% → +23.4%), the stock is accelerating and likely to beat big again. Narrowing beats = sell-the-news risk.
- `mcp__financial-modeling-prep__getPriceTargetNews` with symbol=$ARGUMENTS — recent PT changes with analyst names, firm, date, old PT → new PT. **Detects PT revision ACCELERATION.** If 3+ analysts raised PTs in 2 weeks before earnings, this is a strong bullish catalyst signal.

**Crypto/ETF route:** Skip DCF/custom DCF. Use price target only if available. Skip earnings reports.

---

## Output

Write all collected data to `reports/{SYMBOL}_fundamental.md` with this structure:

```markdown
# {SYMBOL} Fundamental Analysis — {DATE}

## Macro & Sector
- Treasury Yields: 2Y X% | 5Y X% | 10Y X% | 30Y X%
- Yield Curve: {normal/flat/inverted}
- VIX: X ({calm/normal/elevated/fear/PANIC})
- Sector ETF ({XLK}): 1D X% | 1M X% | 3M X% | 1Y X%

## Financial Health
- Piotroski F-Score: X/9
- Altman Z-Score: X ({safe/grey/distress})
- Revenue (FY): $X → $X (YoY: X%)
- Net Income: $X | EPS: $X
- Margins: Gross X% | Operating X% | Net X%
- FCF: $X | Owner Earnings: $X
- Debt/Equity: X | Current Ratio: X
- ROE: X% | ROIC: X%

## Revenue Segments
- Product: {breakdown}
- Geographic: {breakdown with concentration risk flag}

## Market Cap Trajectory
- Q-4: $X → Q-3: $X → Q-2: $X → Q-1: $X → Now: $X
- Trend: {expanding/contracting/stable}

## Peer Comparison
| Metric | {SYMBOL} | Peer 1 | Peer 2 | Peer 3 |
|--------|----------|--------|--------|--------|
| Price | ... | ... | ... | ... |
| Market Cap | ... | ... | ... | ... |
| P/E | ... | ... | ... | ... |

## Valuation
- Growth Stock: {Yes/No} (revenue growth X%, P/E X)
- Track: {A (Value) / B (Growth)}
- Standard DCF: $X ({X% vs price})
- Levered DCF: $X ({X% vs price})
- Custom DCF: $X ({X% vs price}) — inputs: growth X%, beta X, MRP X%, Rf X%
- PEG Ratio: X (if Track B)
- Analyst Consensus: $X ({X% upside}) from X analysts (s=$X)
- Analyst High/Low: $X / $X

## Analyst Activity
- Recent grades: {upgrade/downgrade events}
- Rating distribution: X Strong Buy, X Buy, X Hold, X Sell

## Earnings History
- Beat/Miss: X/8 quarters beat
- Avg Surprise: X%
- Most Recent: {beat/miss by X%}

## Data Completeness: {X}%
```
