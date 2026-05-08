---
description: Fundamental analysis only — macro, financial scores (Piotroski/Z), DCF valuation, peer comps
argument-hint: "[SYMBOL]"
---

# Fundamental Analysis: $ARGUMENTS

Run Phases 2, 7, 8, 9 for the given symbol. This is a standalone entry point for fundamental-only analysis.

**Before starting:** Read `${CLAUDE_PLUGIN_ROOT}/commands/${CLAUDE_PLUGIN_ROOT}/lib/asset-classifier.md`, `${CLAUDE_PLUGIN_ROOT}/commands/${CLAUDE_PLUGIN_ROOT}/lib/error-handling.md`, and `${CLAUDE_PLUGIN_ROOT}/commands/${CLAUDE_PLUGIN_ROOT}/lib/no-skip-policy.md`. If running standalone (not from orchestrator), first call `mcp__plugin_trading-desk_financial-modeling-prep__getCompanyProfile` to classify the asset type.

**MANDATORY:** Every step below MUST be attempted. If a tool fails, log it as FAILED with the error — never silently skip.

**Crypto route:** Skip this entire command — crypto has no traditional fundamentals.
**ETF route:** Phase 7 uses fund-specific tools instead.

---

## Phase 2: Macro & Sector Context

**19 calls, all cacheable per session (parallel):**
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getTreasuryRates` — extract 2Y, 5Y, 10Y, 30Y yields. Check yield curve shape (2Y > 10Y = inverted = recession signal).
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getStockPriceChange` with the sector ETF symbol based on the stock's sector:
  - Technology → XLK, Semiconductors → SMH, Financials → XLF, Energy → XLE, Healthcare → XLV, Consumer Discretionary → XLY, Industrials → XLI, Real Estate → XLRE, Utilities → XLU, Materials → XLB, Comm Services → XLC, Consumer Staples → XLP
  - **Sub-sector mappings:** Use FMP industry field to determine the correct ETF. "Semiconductors" or "Semiconductor Equipment" → SMH. "Communication Equipment", "Electronic Components", "Computer Hardware" → XLK (parent sector, NOT SMH). "Software" → XLK. When in doubt, use parent sector ETF.
  - **ETF route:** Compare to SPY instead (the ETF IS the sector)
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getIndexQuote` with symbol="^VIX" — VIX fear gauge. Labels: <15 = "calm", 15-20 = "normal", 20-25 = "elevated", 25-30 = "fear", >30 = "PANIC"
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getSectorPerformanceSnapshot` — real-time sector momentum. Fallback if sector ETF getStockPriceChange returns 402. Shows whether money is flowing into/out of this stock's sector.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getHistoricalIndustryPE` with industry={stock's industry from Phase 1} — industry P/E history. Contextualizes the stock's P/E vs. industry norm. A stock at P/E 135 in a sector averaging P/E 80 is different from P/E 135 in a sector averaging P/E 20.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getHistoricalSectorPerformance` — 3-month sector trend. Confirms or refutes sector ETF momentum signal.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getIndustryPESnapshot` with industry={stock's industry}, date={today YYYY-MM-DD} — current industry P/E. **Contextualizes valuation:** A P/E of 135 in a sector averaging 80 is very different from P/E 135 in a sector averaging 20.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getEconomicCalendar` with from={today}, to={today + 14 days} — upcoming CPI, FOMC, jobs data. **If major macro event coincides with earnings week, volatility amplifies.** Flag: "MACRO EVENT: {event} on {date} during earnings week."
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getESGRatings` with symbol=$ARGUMENTS — ESG score (environmental, social, governance). Flags regulatory/reputational risk for Risk scoring. Companies with poor ESG increasingly face institutional divestment pressure.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getCommodityQuotes` — real-time commodity prices (oil, gold, copper, natural gas). **Copper is the "doctor" — down >10% in 3 months signals recession for cyclicals.** Oil up >20% in 3M = headwind for transport/consumer, tailwind for energy. Gold up >15% in 3M = flight to safety (bearish for risk assets with beta >1.5).
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getForexQuote` with symbol="USDX" — US Dollar Index. **DXY up >5% in 3 months = earnings headwind for international revenue companies.** Down >5% = tailwind. Cross-reference with geographic revenue segmentation from Phase 7.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getEconomicIndicators` — GDP growth, CPI, unemployment rate, manufacturing PMI. **GDP declining 2+ consecutive quarters = recession warning for cyclicals.** CPI accelerating while rates rising = stagflation risk for long-duration growth stocks.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getCOTAnalysis` — Commitment of Traders data for relevant sector commodities. **Commercial hedgers heavily net long = potential bottom signal.** Speculator positioning >90th percentile long = crowded trade reversal risk.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getCOTReports` — historical COT positioning trends. Confirms or refutes current COT signal with trajectory context.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getHistoricalSectorPE` with sector={stock's sector} — sector P/E history (complement to industry P/E). Shows whether the entire sector is cheap or expensive vs history.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getCompanySECProfile` with symbol=$ARGUMENTS — SIC code (standardized industry classification), ISIN, CUSIP, exact 52-week range, employee count. SIC code is more precise than FMP's internal `industry` field for `getHistoricalIndustryPE` lookup. Also provides ISIN/CUSIP for institutional data cross-referencing.
- `WebSearch` query: "ISM services PMI latest {current_month} {current_year}" — services sector economic indicator. Extract: current PMI reading, prior month, trend (expanding >50 / contracting <50). Scoring: PMI > 55 = +0.5 Macro for services/software stocks. PMI < 50 = -1 Macro for services/software stocks. Only apply to stocks where sector = "Technology" or industry contains "Software" or "Services". **Confidence:** WebSearch returns articles ABOUT PMI releases, not structured data. Always label: "ISM PMI: {X} (WebSearch — approximate)." If no clear PMI number found, skip modifier.
- `WebSearch` query: "Gartner IT spending forecast {current_year}" OR "enterprise software spending growth {current_year}" — IT spending growth context. Extract: total IT spending growth %, software spending growth %, AI/GenAI spending growth %. Compare: company revenue growth vs industry spending growth. If company growth > industry growth + 10pp: "GAINING SHARE" → Fundamental +0.5. If company growth < industry growth - 5pp: "LOSING SHARE" → note in report. Only apply to Technology sector stocks. **Confidence:** WebSearch returns analyst commentary, not raw Gartner data (paywalled). Always label: "IT Spending: ~{X}% growth (WebSearch — approximate)." If no clear number found, skip modifier.
- `WebSearch` query: "Federal Reserve interest rate decision latest {current_year}" — rate environment context. Only if getTreasuryRates shows significant recent changes (>25bps in 30 days).

**If sector ETF data returns 402:** Use `getSectorPerformanceSnapshot` as primary sector signal. If BOTH fail, cap Macro at 6 per scoring rubrics.

---

## Phase 7: Fundamentals + Financial Health

**24 FMP + WebSearch calls, parallel:**
- `mcp__plugin_trading-desk_financial-modeling-prep__getFinancialRatiosTTM` — P/E, P/B, EV/EBITDA, margins (gross, operating, net), current ratio, debt/equity, dividend yield, FCF ratios
- `mcp__plugin_trading-desk_financial-modeling-prep__getKeyMetricsTTM` — ROE, ROIC, EV/Sales, EV/OCF, netDebt/EBITDA, cash conversion cycle, R&D/revenue, income quality, Graham number (26 unique fields)
- `mcp__plugin_trading-desk_financial-modeling-prep__getIncomeStatement` with period="FY", limit=5 — absolute revenue ($), net income, EPS, R&D, SGA, **SBC (stock-based compensation)**. Extended to 5 years for moat assessment (margin stability), capital allocation analysis (shares outstanding trajectory), and financial statement forensics (receivables/revenue growth trending).
- `mcp__plugin_trading-desk_financial-modeling-prep__getIncomeStatementTTM` — trailing twelve months: more current than FY data. Use for run-rate estimates. When most recent quarter shows acceleration, TTM better reflects current earnings power.
- `mcp__plugin_trading-desk_financial-modeling-prep__getIncomeStatementGrowth` with period="quarter", limit=4 — QoQ revenue/EPS growth rates. **Growth ACCELERATION is the #1 earnings prediction signal.** If revenue growth is increasing each quarter, the stock is more likely to beat. Decelerating growth = sell-the-news risk.
- `mcp__plugin_trading-desk_financial-modeling-prep__getFinancialStatementGrowth` with period="FY", limit=2 — pre-calculated YoY growth rates + 3Y/5Y/10Y compounded rates
- `mcp__plugin_trading-desk_financial-modeling-prep__getCashFlowStatementGrowth` with period="quarter", limit=4 — FCF growth trajectory. **Decelerating FCF growth despite revenue growth = margin pressure warning.** Critical for catching PLTR-style sell-the-news setups.
- `mcp__plugin_trading-desk_financial-modeling-prep__getBalanceSheetStatement` with period="FY", limit=5 — cash, total debt, goodwill, inventory, receivables, working capital, total equity. Extended to 5 years for forensics (inventory build, receivables accumulation), capital allocation (buyback/dilution via shares outstanding), and Beneish M-Score computation.
- `mcp__plugin_trading-desk_financial-modeling-prep__getBalanceSheetStatementTTM` — trailing balance sheet for most current snapshot of cash/debt position
- `mcp__plugin_trading-desk_financial-modeling-prep__getCashFlowStatement` with period="FY", limit=1 — operating CF, capex, FCF, D&A. **Derive owner earnings:** net income + D&A - capex
- `mcp__plugin_trading-desk_financial-modeling-prep__getFinancialScores` — Altman Z-Score (bankruptcy risk: >3 safe, 1.8-3 grey, <1.8 distress) + Piotroski F-Score (financial strength: 0-9, higher better)
- `mcp__plugin_trading-desk_financial-modeling-prep__getRatios` with period="quarter", limit=4 — historical quarterly ratios. **Track margin trends over multiple quarters.** Deteriorating operating margin across 3+ quarters = fundamental warning even if absolute numbers look good.
- `mcp__plugin_trading-desk_financial-modeling-prep__getRevenueProductSegmentation` with period="annual" — which products/segments drive revenue, concentration risk
- `mcp__plugin_trading-desk_financial-modeling-prep__getRevenueGeographicSegmentation` with period="annual" — geographic revenue mix. Single non-US country >60% = geopolitical risk modifier for Risk scoring
- `mcp__plugin_trading-desk_financial-modeling-prep__getHistoricalMarketCap` with symbol=$ARGUMENTS, from_date={1 year ago YYYY-MM-DD}, limit=252 — daily market cap data. Sample quarterly (roughly every 63 trading days: Q-4, Q-3, Q-2, Q-1, now) to see if market is re-rating (expanding) or de-rating (contracting)
- `mcp__plugin_trading-desk_financial-modeling-prep__getOwnerEarnings` with symbol=$ARGUMENTS — Buffett-style owner earnings metric (complements manual D&A calculation)
- `mcp__plugin_trading-desk_financial-modeling-prep__getHistoricalEmployeeCount` with symbol=$ARGUMENTS — workforce growth trends. **Hiring leads revenue by 1-2 quarters.** If headcount grows faster than revenue, efficiency is declining. If headcount shrinks while revenue grows, margins will expand.
- `mcp__plugin_trading-desk_financial-modeling-prep__getExecutiveCompensation` with symbol=$ARGUMENTS — exec salary vs stock awards. **Heavy stock-based compensation = management incentive alignment.** Also needed for SBC margin adjustment.
- `mcp__plugin_trading-desk_financial-modeling-prep__getCashFlowStatementTTM` — trailing cash flow for most current FCF snapshot. Complements annual `getCashFlowStatement` when quarter shows material change.
- `mcp__plugin_trading-desk_financial-modeling-prep__getCompanyNotes` with symbol=$ARGUMENTS — footnotes and disclosure items. Catches off-balance-sheet obligations, contingent liabilities, related-party transactions that P&L data misses.
- `mcp__plugin_trading-desk_financial-modeling-prep__getEmployeeCount` with symbol=$ARGUMENTS — current headcount snapshot. Cross-reference with `getHistoricalEmployeeCount` for latest hiring/layoff trajectory.
- `mcp__plugin_trading-desk_financial-modeling-prep__getExecutiveCompensationBenchmark` with symbol=$ARGUMENTS — exec comp relative to peers. Flags excessive compensation (agency risk) or unusually low comp (founder-led alignment).
- **[CALL SEQUENTIALLY — do NOT batch with other FMP calls]** `mcp__plugin_trading-desk_financial-modeling-prep__getFinancialStatementFullAsReported` with symbol=$ARGUMENTS, period="annual", limit=2 — XBRL data from SEC filings. **Known issue:** toolception session race condition causes "Session not found" errors when this call runs in parallel with many other FMP calls. Fire this AFTER the main parallel batch completes. Extract: `revenueremainingperformanceobligation` (RPO — forward revenue visibility), `revenueremainingperformanceobligationpercentage` (RPO recognition timeline), `concentrationriskpercentage1` (customer concentration by CUSTOMER, not product segment), `unrecordedunconditionalpurchaseobligationbalancesheetamount` (purchase obligations), `contractwithcustomerliabilitycurrent` (current deferred revenue), `numberofoperatingsegments` (segment count). **XBRL fallback:** Field names are US GAAP taxonomy tags. Not all companies report all fields. If any field is not found in the response, set that metric to "N/A — not reported in SEC filing." The Revenue Durability section must gracefully degrade — never penalize for missing XBRL data.
- `WebSearch` query: "{COMPANY_NAME} careers open positions {current_year}" OR "{COMPANY_NAME} LinkedIn jobs" — hiring momentum (leading indicator for revenue, 1-2 quarters ahead). Extract: approximate total open positions, whether hiring is "aggressive" (>5% of headcount) or "moderate". Cross-reference with `getHistoricalEmployeeCount` trend. Headcount growing + aggressive hiring = expansion mode (bullish). Headcount flat + few openings = efficiency mode (bullish for margins). Headcount declining + few openings = contraction (bearish). Report: "Hiring Momentum: ~{X} open positions ({aggressive/moderate/minimal})."

**ETF route:** Replace Phase 7 with:
- `mcp__plugin_trading-desk_financial-modeling-prep__getFundHoldings` — top holdings and weights
- `mcp__plugin_trading-desk_financial-modeling-prep__getFundSectorWeighting` — sector allocation
- `mcp__plugin_trading-desk_financial-modeling-prep__getFundInfo` — expense ratio, AUM, inception date, strategy

### Derived Forensics (computed from Phase 7 data, no additional calls)

From the 5-year income statement and balance sheet data, compute:
- **Receivables/Revenue growth ratio:** (receivables_current / receivables_prior) / (revenue_current / revenue_prior). If > 1.5 for 2+ consecutive years: flag "REVENUE QUALITY WARNING."
- **Inventory/Revenue growth ratio:** Same formula with inventory. If > 1.5 for 2+ years: flag "INVENTORY BUILD WARNING."
- **Accruals ratio:** (net_income - operating_cash_flow) / total_assets. If positive and rising over 2+ years: flag "EARNINGS QUALITY WARNING."
- **Beneish M-Score (Full 8-Variable Formula):**
  Using data from getIncomeStatement (limit=5) and getBalanceSheetStatement (limit=5), compute:
  M = -4.84 + 0.92×DSRI + 0.528×GMI + 0.404×AQI + 0.892×SGI + 0.115×DEPI - 0.172×SGAI + 4.679×Accruals - 0.327×LVGI
  Where (using most recent 2 fiscal years, t = current, t-1 = prior):
  1. DSRI = (Receivables_t / Revenue_t) / (Receivables_{t-1} / Revenue_{t-1})
  2. GMI = GrossMargin_{t-1} / GrossMargin_t (note: PRIOR over CURRENT)
  3. AQI = [1 - (CurrentAssets_t + PP&E_t) / TotalAssets_t] / [1 - (CurrentAssets_{t-1} + PP&E_{t-1}) / TotalAssets_{t-1}]
  4. SGI = Revenue_t / Revenue_{t-1}
  5. DEPI = (Depreciation_{t-1} / (Depreciation_{t-1} + PP&E_{t-1})) / (Depreciation_t / (Depreciation_t + PP&E_t))
  6. SGAI = (SGA_t / Revenue_t) / (SGA_{t-1} / Revenue_{t-1})
  7. Accruals = (NetIncome_t - OperatingCashFlow_t) / TotalAssets_t (cash-flow proxy formulation)
  8. LVGI = (LongTermDebt_t + CurrentLiabilities_t) / TotalAssets_t / ((LongTermDebt_{t-1} + CurrentLiabilities_{t-1}) / TotalAssets_{t-1})
  Interpret: M > -1.78 = "HIGH MANIPULATION RISK". M between -2.22 and -1.78 = "GREY ZONE". M < -2.22 = "CLEAN".
  Report all 8 component values alongside M-Score.
- **Capital allocation quality:** Track shares outstanding from balance sheet over 5 years. Compute 3-year buyback yield (shares reduced / avg shares). Rising shares = dilution (-1 Fundamental). Falling shares = buybacks (+1 Fundamental, unless done above intrinsic value).
- **Moat indicators:**
  - Gross margin premium vs. peers (from Phase 8 data) sustained 3+ years = pricing power
  - Revenue concentration from getRevenueProductSegmentation: top segment >70% = fragile
  - Recurring revenue proxy: GM >70% AND expanding AND growth >20% = platform economics

---

## Phase 8: Peer Comparison

**2 calls, sequential then parallel:**

**Step 1:**
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getStockPeers` with symbol=$ARGUMENTS — get list of peer companies. Take top 3-4 by relevance.
- If empty: note "No peer data available", skip to Phase 9.

**Step 2 (parallel calls):**
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getBatchQuotes` with symbols=$ARGUMENTS + top 3 peers (comma-separated, e.g., "AMD,NVDA,INTC,QCOM") — returns price, change%, marketCap, 50SMA, 200SMA for ALL in one call.
- Call `mcp__plugin_trading-desk_financial-modeling-prep__getFinancialRatiosTTM` for each of the top 3 peers (3 parallel calls) — returns P/E, EV/EBITDA, gross margin, operating margin, ROE, D/E for valuation comparison.
- For large-cap stocks (>$50B): expand to top 5 peers for better statistical reliability.
- **Peer validation:** Reject peers with mismatched sector/industry, >10x market cap difference, or revenue model mismatch. If `getStockPeers` returns irrelevant results, fall back to industry P/E from `getIndustryPESnapshot` (already collected in Phase 2).
- **Efficiency option:** Call `mcp__plugin_trading-desk_financial-modeling-prep__getRatiosTTMBulk` to get all peer ratios in a single bulk call instead of individual `getFinancialRatiosTTM` per peer. POST-FILTER for target peers.

**Build peer comparison table:** Compare the stock vs peers on P/E, EV/EBITDA, Gross Margin, Operating Margin, Revenue Growth, ROE, D/E, market cap, and price momentum. This data feeds into Track A Valuation criteria ("P/E below peer median").

---

## Phase 9: Valuation & Analyst Targets

### Step 1 — Valuation models (6 calls, parallel — ALL MUST BE ATTEMPTED per no-skip-policy)

**Every DCF call below is mandatory. If any fails, log: `[FAILED] {tool}: {error}. Valuation score degraded.`**

- `mcp__plugin_trading-desk_financial-modeling-prep__getDCFValuation` with symbol=$ARGUMENTS — standard (unlevered) DCF intrinsic value
- `mcp__plugin_trading-desk_financial-modeling-prep__getLeveredDCFValuation` with symbol=$ARGUMENTS — levered DCF (accounts for debt). For leveraged companies, can differ 20-40% from unlevered. Together they create a valuation range.
- `mcp__plugin_trading-desk_financial-modeling-prep__calculateCustomDCF` with symbol=$ARGUMENTS and these parameters populated from earlier phases:
  - **revenueGrowthPct** = actual revenue growth rate from Phase 7 `getFinancialStatementGrowth`
  - **beta** = from Phase 1 `getCompanyProfile` (read from `reports/{SYMBOL}_technical.md` if running standalone)
  - **marketRiskPremium** = from `getMarketRiskPremium` (this call)
  - **riskFreeRate** = 10Y yield from Phase 2 `getTreasuryRates`
  - **costOfDebt** = interestExpense / totalDebt from Phase 7 `getBalanceSheetStatement` + `getIncomeStatement`
  - **taxRate** = from Phase 7 `getIncomeStatement` (incomeTaxExpense / incomeBeforeTax)
  - Remaining 12 of 18 parameters use FMP defaults (reasonable for most stocks)
- `mcp__plugin_trading-desk_financial-modeling-prep__calculateCustomLeveredDCF` with symbol=$ARGUMENTS — custom levered DCF using same inputs as custom unlevered. Provides debt-adjusted custom valuation. Compare against standard `getLeveredDCFValuation` to assess custom model sensitivity.
- `mcp__plugin_trading-desk_financial-modeling-prep__calculateCustomDCF` (BEAR CASE) with symbol=$ARGUMENTS — **second custom DCF call** with revenue growth at 50% of actual and margins compressed. Uses same framework but stress-tests assumptions. Report: "Bear-case DCF: ${X}."
- `mcp__plugin_trading-desk_financial-modeling-prep__getMarketRiskPremium` — equity risk premium. **Cache per session.**

**DCF usage in scoring (from `${CLAUDE_PLUGIN_ROOT}/lib/scoring-rubrics.md`):**
- Track A (Value): Average of standard DCF and levered DCF
- Track B (Growth): Use custom DCF. If still undervalues, PEG overrides.
- Always report all 3: "DCF range: $X (standard) / $Y (levered) / $Z (custom)"

**Growth detection:** Revenue growth >20% YoY (from Phase 7) OR P/E >40 → Track B.

### Derived Valuation Analysis (computed, no additional calls)

**Margin of Safety:** 
- Compute: margin_of_safety = (avg_DCF - price) / avg_DCF × 100, where avg_DCF = average of valid standard and levered DCF.
- Report: "Margin of Safety: {X}%."

**Implied Growth Rate:**
- Reverse-engineer the DCF: given current price, what growth rate is required to justify it?
- Method: implied_growth = actual_growth × (current_price / custom_DCF_value).
- Report: "Implied Growth: {X}% (market requires this vs actual {Y}%)."
- If implied > 2x actual: "PRICED FOR PERFECTION." If implied < 0.5x actual: "GROWTH DISCOUNT."

**TAM Analysis (Track B stocks only):**
- For Track B stocks (revenue growth >20% OR P/E >40), add WebSearch: "{COMPANY_NAME} total addressable market TAM."
- Compute penetration_rate = annual_revenue / TAM_estimate.
- Report: "TAM: ${X}B | Penetration: {Y}% | Runway: {early(<10%)/mid(10-40%)/late(>40%)}."
- If penetration < 10% AND revenue growth > 30%: Valuation +1 (massive runway).

### Step 2 — Analyst sentiment (11 calls, parallel)

- `mcp__plugin_trading-desk_financial-modeling-prep__getPriceTargetSummary` with symbol=$ARGUMENTS — analyst consensus target + analyst COUNT + standard deviation + high/low. "$180 from 3 analysts" vs "$180 from 25 analysts" is completely different confidence.
- `mcp__plugin_trading-desk_financial-modeling-prep__getPriceTargetConsensus` with symbol=$ARGUMENTS — structured consensus with targetHigh/targetLow/targetMedian/targetConsensus. More reliable than summary for scoring.
- `mcp__plugin_trading-desk_financial-modeling-prep__getPriceTargetLatestNews` with symbol=$ARGUMENTS — recent price target changes with analyst names, firm, date, old PT → new PT. Captures upgrade/downgrade ACCELERATION (e.g., 3 PT raises in 2 weeks = bullish catalyst signal).
- `mcp__plugin_trading-desk_financial-modeling-prep__getHistoricalStockGrades` with symbol=$ARGUMENTS, limit=10 — monthly aggregate analyst rating counts (Strong Buy/Buy/Hold/Sell) trend
- `mcp__plugin_trading-desk_financial-modeling-prep__getStockGradeNews` with symbol=$ARGUMENTS — recent upgrade/downgrade EVENTS with dates. Detects "3 downgrades this week" which monthly aggregates cannot see. Feeds into Sentiment and Smart Money.
- `mcp__plugin_trading-desk_financial-modeling-prep__getStockGradeSummary` with symbol=$ARGUMENTS — aggregated Strong Buy/Buy/Hold/Sell/Strong Sell counts with trend direction. More structured than event-level grade news.
- `mcp__plugin_trading-desk_financial-modeling-prep__getEarningsReports` with symbol=$ARGUMENTS — historical EPS actual vs estimated for last 4-8 quarters. Beat/miss pattern feeds into Fundamental and Risk scores. A stock that beats 8/8 quarters has fundamentally different risk than a serial misser. **Ensure all 8 quarters are retrieved.** If FMP returns 402, fallback to WebSearch for earnings history.
- **Surprise Trend Analysis (extends beat/miss modifier):** Using getEarningsReports last 8 quarters, compute:
  - Surprise trend: slope of surprise magnitudes over 8 quarters (positive = improving execution)
  - Improving trend (surprise magnitude increasing over last 4 quarters): add +0.5 to existing beat/miss modifier
  - Declining trend (surprise magnitude decreasing over last 4 quarters): subtract -0.5 from existing beat/miss modifier
  - Stable/flat: no additional adjustment
  - Report: "Surprise Trend: {improving/stable/declining} (slope: {X}pp per quarter)"
  - Minimum 6 quarters required for trend calculation. If < 6 quarters: skip trend component.
- `mcp__plugin_trading-desk_financial-modeling-prep__getAnalystEstimates` with symbol=$ARGUMENTS, period="quarter", limit=4 — forward EPS/revenue estimates for next 4 quarters. Rising estimates = analysts playing catch-up = bullish. Falling estimates = headwind. **Feeds into Earnings Catalyst Modifier (Override 6).**
- `mcp__plugin_trading-desk_financial-modeling-prep__getEarningsSurprisesBulk` with year={current year} — batch surprise data. **Track surprise MAGNITUDE trend.** If beat margin is INCREASING each quarter (e.g., +2.6% → +7.8% → +23.4%), the stock is accelerating and likely to beat big again. Narrowing beats = sell-the-news risk.
- `mcp__plugin_trading-desk_financial-modeling-prep__getPriceTargetNews` with symbol=$ARGUMENTS — recent PT changes with analyst names, firm, date, old PT → new PT. **Detects PT revision ACCELERATION.** If 3+ analysts raised PTs in 2 weeks before earnings, this is a strong bullish catalyst signal.
- `mcp__plugin_trading-desk_financial-modeling-prep__getHistoricalRatings` with symbol=$ARGUMENTS — time-series of overall rating (Strong Buy/Buy/Hold/Sell) over past 6-12 months. Detects RATING DRIFT: if consensus shifted from Buy to Hold over 6 months, the stock is losing analyst confidence even if individual upgrades exist.

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
- Commodities: Oil ${X} ({change}%) | Copper ${X} ({change}%) | Gold ${X} ({change}%)
- DXY: {X} ({change}% 3M)
- GDP Growth: {X}% | CPI: {X}% | Unemployment: {X}%
- COT Signal: {commercial/speculator positioning for relevant commodity}
- Macro Regime: {REFLATION/GOLDILOCKS/STAGFLATION/DEFLATION}

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

## ESG Profile
- Overall: X | Environmental: X | Social: X | Governance: X
- Flags: {ESG risks, institutional divestment pressure, or "N/A"}

## Debt Maturity & Notes
- Company Notes: {off-balance-sheet items, contingent liabilities, or "None"}
- Key Disclosures: {material footnotes from getCompanyNotes, or "None"}

## Financial Statement Forensics
- Receivables/Revenue Ratio: {X}x ({OK/WARNING})
- Inventory/Revenue Ratio: {X}x ({OK/WARNING})
- Accruals Ratio: {X} ({OK/WARNING})
- Beneish M-Score: {PASS/FAIL}
- Capital Allocation: {buybacks/neutral/dilutive} — shares {+/-X}% over 3 years

## Economic Moat
- Gross Margin Premium: {X}pp above peer median ({strong/weak/none})
- Revenue Concentration: top segment {X}% ({diversified/concentrated})
- Recurring Revenue Proxy: {yes/no — GM%, expanding, growth rate}
- Moat Rating: {WIDE/NARROW/NONE}

## Revenue Durability (SEC Filing Data)
- RPO: ${X} ({Y}x annual revenue) — {strong/moderate/weak} forward visibility
- RPO Recognition: {X}% within 12 months
- Customer Concentration: top customer {X}% ({diversified/concentrated/highly concentrated})
- Purchase Obligations: ${X}
- Deferred Revenue (Current): ${X}
- Operating Segments: {N}
- Source: getFinancialStatementFullAsReported (XBRL)

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

## Stress Test & Implied Value
- Bear-Case DCF: ${X} ({Y}% vs price)
- Margin of Safety: {X}%
- Implied Growth: {X}% (actual: {Y}%)
- TAM: ${X}B | Penetration: {Y}% (Track B only)

## Analyst Activity
- Recent grades: {upgrade/downgrade events}
- Rating distribution: X Strong Buy, X Buy, X Hold, X Sell

## Earnings History
- Beat/Miss: X/8 quarters beat
- Avg Surprise: X%
- Most Recent: {beat/miss by X%}

## Management Credibility
- Beat Rate: {X}/8 quarters ({Y}%)
- Avg Surprise: {X}%
- Surprise Trend: {improving/stable/declining} (slope: {X}pp per quarter)
- Rating: {HIGH (>=7/8 + improving) / GOOD (>=5/8) / LOW (>=3/8) / POOR (<3/8)}

## Hiring Momentum
- Open Positions: ~{X} ({aggressive/moderate/minimal})
- Headcount Trend: {growing/flat/declining}
- Interpretation: {expansion mode/efficiency mode/contraction}

## IT Spending Context (Technology sector only)
- Industry Growth: ~{X}% (WebSearch — approximate)
- Company vs Industry: {GAINING SHARE / INLINE / LOSING SHARE}

## Data Completeness: {X}%
```
