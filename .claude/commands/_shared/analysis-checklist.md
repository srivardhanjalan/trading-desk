# Analysis Pipeline — Master Checklist

Complete 16-phase stock analysis pipeline. ~100-143 tool calls across 4 MCP servers + WebSearch/WebFetch.

---

## Setup
- [ ] Read `rules.json` (if exists) for custom risk parameters
- [ ] Ensure `reports/` directory exists
- [ ] Note current date for filenames

---

## PHASE GROUP 1: TECHNICAL (Phases 0, 1, 3, 4, 5, 6)

### Phase 0: Market Clock & Asset Classification
- [ ] `Alpaca: get_clock` — market open/closed, next open/close (cacheable)

### Phase 1: Price & Identity (3 parallel calls)
- [ ] `FMP: getCompanyProfile` — price, change, volume, marketCap, beta, sector, industry, isEtf, isAdr, country
- [ ] `FMP: getStockPriceChange` — 1D%, 5D%, 1M%, 3M%, 6M%, 1Y% momentum
- [ ] `Alpaca: get_stock_snapshot` — bid/ask prices/sizes, compute spread %
- [ ] **Asset classification:** Stock / Crypto / ETF / ADR / OTC (determines routing for all later phases)

### Phase 3: Multi-Timeframe Technicals (2 TV-Analysis + 9 FMP always-on + 3 market context)
- [ ] `TV-Analysis: multi_timeframe_analysis` — Weekly/Daily/4H/1H/15m alignment
- [ ] `TV-Analysis: coin_analysis` (timeframe=1D) — RSI, MACD, Stochastic, ADX, Bollinger, SMAs/EMAs, support/resistance
- [ ] **Record:** RSI value, ADX value, +DI/-DI ratio (needed for overrides)

**FMP Technical Indicators (ALWAYS-ON — 5 core + 4 extended, parallel):**
- [ ] `FMP: getRSI` (14, 1day, 60d) — cross-validate with TV RSI
- [ ] `FMP: getSMA` (50, 1day, 60d) — cross-validate with TV SMA50
- [ ] `FMP: getSMA` (200, 1day, 300d) — cross-validate with TV SMA200
- [ ] `FMP: getEMA` (20, 1day, 60d) — Bollinger midline proxy
- [ ] `FMP: getADX` (14, 1day, 60d) — ADX + regime detection (60-day average)
- [ ] `FMP: getDEMA` (20, 1day, 60d) — Double EMA, faster trend detection
- [ ] `FMP: getTEMA` (20, 1day, 60d) — Triple EMA, early momentum shift warning
- [ ] `FMP: getWMA` (20, 1day, 60d) — Weighted MA, slope confirms trend
- [ ] `FMP: getWilliams` (14, 1day, 60d) — Williams %R, confirms RSI
- [ ] **Cross-validation:** RSI divergence >10pts = flag + average. SMA >3% = flag data quality.
- [ ] **Regime detection:** ADX avg >25 = TRENDING, 18-25 = TRANSITIONAL, <18 = MEAN-REVERTING

**Market Context (3 parallel):**
- [ ] `TV-Analysis: market_snapshot` — broad market direction, sector performance
- [ ] `TV-Analysis: top_gainers` — daily leaders (check if symbol is top gainer)
- [ ] `TV-Analysis: top_losers` — daily laggards (check if symbol is top loser)
- [ ] **Relative strength:** Compare stock 1D% vs market snapshot direction

**FMP-only fallback (if BOTH TV-Analysis calls fail — OTC stocks):** FMP data becomes PRIMARY. Apply -1 data gap penalty.

### Phase 4: Volume & Float (5 parallel calls)
- [ ] `FMP: getShareFloat` — float size, short interest %, short ratio
- [ ] `TV-Analysis: smart_volume_scanner` — unusual volume (POST-FILTER for symbol)
- [ ] `TV-Analysis: volume_confirmation_analysis` — volume-confirmed advance/decline
- [ ] `TV-Analysis: consecutive_candles_scan` — consecutive candle count (POST-FILTER for symbol)
- [ ] `TV-Analysis: volume_breakout_scanner` — volume breakouts (POST-FILTER for symbol)

### Phase 5: Candle Patterns & Bollinger (2 parallel calls)
- [ ] `TV-Analysis: advanced_candle_pattern` — active patterns (POST-FILTER for symbol)
- [ ] `TV-Analysis: bollinger_scan` — Bollinger Walk/Squeeze (POST-FILTER for symbol)

### Phase 6: TradingView Desktop Chart
- [ ] `TV: tv_health_check` — check connection (if fail, try `tv_launch`)
- [ ] `TV: chart_set_symbol` — set to target symbol
- [ ] `TV: chart_set_timeframe` — set to Daily
- [ ] `TV: chart_manage_indicator` — add: RSI, MACD, Bollinger Bands, EMA(50), SMA(200), Volume
- [ ] `TV: data_get_study_values` — read all indicator values
- [ ] `TV: data_get_pine_labels` — custom indicator labels (support/resistance)
- [ ] `TV: depth_get` — order book depth (bid/ask walls)
- [ ] `TV: draw_shape` — draw support/resistance lines
- [ ] `TV: capture_screenshot` — save chart image
- [ ] **Save:** `reports/{SYMBOL}_technical.md`

---

## PHASE GROUP 2: FUNDAMENTAL (Phases 2, 7, 8, 9)

### Phase 2: Macro & Sector Context (15 parallel calls, all cacheable)
- [ ] `FMP: getTreasuryRates` — 2Y, 5Y, 10Y, 30Y yields; yield curve shape
- [ ] `FMP: getStockPriceChange` with sector ETF — sector momentum (use sector→ETF mapping)
- [ ] `FMP: getIndexQuote` (^VIX) — fear gauge (<15 calm, 15-20 normal, 20-25 elevated, 25-30 fear, >30 PANIC)
- [ ] `FMP: getSectorPerformanceSnapshot` — real-time sector momentum (fallback for ETF)
- [ ] `FMP: getHistoricalIndustryPE` — industry P/E history
- [ ] `FMP: getHistoricalSectorPerformance` — 3-month sector trend
- [ ] `FMP: getIndustryPESnapshot` — current industry P/E
- [ ] `FMP: getEconomicCalendar` (next 14 days) — FOMC, CPI, jobs data
- [ ] `FMP: getESGRatings` — ESG score (environmental, social, governance), institutional divestment risk
- [ ] `FMP: getCommodityQuotes` — copper, oil, gold prices (copper/gold ratio for macro regime)
- [ ] `FMP: getForexQuote` (USDX) — DXY / USD strength (headwind/tailwind for multinationals)
- [ ] `FMP: getEconomicIndicators` (GDP) — GDP growth trend for macro regime classification
- [ ] `FMP: getEconomicIndicators` (CPI) — CPI trend for inflation regime
- [ ] `FMP: getCOTAnalysis` — Commitment of Traders positioning (commercial hedger signals)
- [ ] `FMP: getCOTReports` — detailed COT data for sector-related commodities
- [ ] `FMP: getHistoricalSectorPE` — sector P/E history for relative valuation context

### Phase 7: Financial Health (22 parallel FMP calls)
- [ ] `getFinancialRatiosTTM` — P/E, P/B, EV/EBITDA, margins, D/E, FCF ratios
- [ ] `getKeyMetricsTTM` — ROE, ROIC, EV/Sales, Graham number (26 fields)
- [ ] `getIncomeStatement` (FY, limit=5) — revenue, net income, EPS, R&D, SBC (5Y for moat/forensics/capital allocation)
- [ ] `getIncomeStatementTTM` — trailing twelve months run-rate
- [ ] `getIncomeStatementGrowth` (quarter, limit=4) — QoQ growth acceleration
- [ ] `getFinancialStatementGrowth` (FY, limit=2) — YoY growth + 3Y/5Y/10Y CAGR
- [ ] `getCashFlowStatementGrowth` (quarter, limit=4) — FCF growth trajectory
- [ ] `getBalanceSheetStatement` (FY, limit=5) — cash, debt, equity, working capital (5Y for forensics trends)
- [ ] `getBalanceSheetStatementTTM` — current cash/debt snapshot
- [ ] `getCashFlowStatement` (FY, limit=1) — operating CF, capex, FCF, D&A
- [ ] `getFinancialScores` — Altman Z-Score, Piotroski F-Score
- [ ] `getRatios` (quarter, limit=4) — quarterly ratio trends
- [ ] `getRevenueProductSegmentation` — product/segment breakdown
- [ ] `getRevenueGeographicSegmentation` — geographic mix, concentration risk
- [ ] `getHistoricalMarketCap` (1Y, limit=252) — re-rating/de-rating trend
- [ ] `getOwnerEarnings` — Buffett-style owner earnings
- [ ] `getHistoricalEmployeeCount` — workforce growth (leading indicator)
- [ ] `getExecutiveCompensation` — exec salary vs stock awards, SBC check
- [ ] `getCashFlowStatementTTM` — trailing cash flow for most current FCF snapshot
- [ ] `getCompanyNotes` — footnotes, off-balance-sheet obligations, contingent liabilities
- [ ] `getEmployeeCount` — current headcount snapshot (cross-ref with historical)
- [ ] `getExecutiveCompensationBenchmark` — exec comp vs peers (agency risk flag)

### Phase 8: Peer Comparison (sequential then parallel)
- [ ] `FMP: getStockPeers` — identify top 3-5 peers
- [ ] `FMP: getBatchQuotes` — price, change%, marketCap for stock + peers
- [ ] `FMP: getFinancialRatiosTTM` × 3 peers — P/E, EV/EBITDA, margins, ROE (or `getRatiosTTMBulk` for efficiency)
- [ ] **Build peer comparison table:** P/E, EV/EBITDA, Gross Margin, Op Margin, Revenue Growth

### Phase 9: Valuation & Analyst Targets (5 + 11 parallel calls)

**Valuation Models (5 parallel):**
- [ ] `FMP: getDCFValuation` — standard (unlevered) DCF
- [ ] `FMP: getLeveredDCFValuation` — levered DCF
- [ ] `FMP: calculateCustomDCF` — custom DCF with real growth inputs from Phase 7
- [ ] `FMP: calculateCustomLeveredDCF` — custom levered DCF (debt-adjusted custom valuation)
- [ ] `FMP: getMarketRiskPremium` — equity risk premium (cacheable)
- [ ] **Validate custom DCFs:** if >10x price or <0, discard as INVALID

**Analyst Sentiment (11 parallel):**
- [ ] `FMP: getPriceTargetSummary` — consensus target + analyst count + std dev
- [ ] `FMP: getPriceTargetConsensus` — high/low/median/consensus targets
- [ ] `FMP: getPriceTargetLatestNews` — recent PT changes with analyst names
- [ ] `FMP: getHistoricalStockGrades` (limit=10) — monthly rating counts trend
- [ ] `FMP: getStockGradeNews` — recent upgrade/downgrade events
- [ ] `FMP: getStockGradeSummary` — aggregated Buy/Hold/Sell counts
- [ ] `FMP: getEarningsReports` — last 8 quarters EPS actual vs estimated
- [ ] `FMP: getAnalystEstimates` (quarter, limit=4) — forward EPS/revenue estimates
- [ ] `FMP: getEarningsSurprisesBulk` (year) — batch surprise data (POST-FILTER)
- [ ] `FMP: getPriceTargetNews` — PT revision acceleration
- [ ] `FMP: getHistoricalRatings` — rating drift detection (consensus trend over 6-12 months)
- [ ] **Determine Track:** Revenue growth >20% OR P/E >40 → Track B (PEG). Else Track A (DCF).
- [ ] **Save:** `reports/{SYMBOL}_fundamental.md`

---

## PHASE GROUP 3: SENTIMENT & OPTIONS (Phases 10, 11, 12, 13, 14)

### Phase 10: Options Flow & IV (3 parallel + 1 sequential)

**Step 1 — Chain data (3 parallel):**
- [ ] `Alpaca: get_option_chain` (calls, ATM ±10%, next 45 days, limit=50)
- [ ] `Alpaca: get_option_chain` (puts, same filters)
- [ ] `FMP: getStandardDeviation` (30d, 1day) — historical volatility

**Step 2 — Premium trending (sequential after Step 1):**
- [ ] Identify top 3 contracts by volume
- [ ] `Alpaca: get_option_bars` (top 3 symbols, 7-day, 1Day) — premium trend

**Step 3 — Compute 10 derived metrics (no calls):**
- [ ] Put/Call Volume Ratio
- [ ] Put/Call OI Ratio (if OI available)
- [ ] IV Skew (put IV - call IV at ATM)
- [ ] Max Pain (if OI available)
- [ ] IV vs HV ratio
- [ ] Expected Move (ATM straddle price + IV-based calc + historical calibration)
- [ ] Unusual Activity (volume > 5x OI)
- [ ] Most Active Strikes (top 3 calls + puts by volume)
- [ ] Premium Trend (7-day % change)
- [ ] Net Delta Exposure (volume-weighted delta skew)

### Phase 11: Sentiment & Insider Activity (~35 parallel calls)

**Multi-platform sentiment:**
- [ ] `TV-Analysis: market_sentiment` — Reddit sentiment
- [ ] `TV-Analysis: multi_agent_analysis` — 3-agent debate (Tech + Sentiment + Risk)
- [ ] `TV-Analysis: financial_news` (symbol, limit=10) — real-time RSS feeds (Reuters, CoinDesk)
- [ ] `FMP: getStockNews` (limit=10) — headlines with URLs
- [ ] `WebSearch:` "{SYMBOL} stock twitter sentiment {year}"
- [ ] `WebSearch:` "{SYMBOL} site:stocktwits.com"
- [ ] `WebSearch:` "{SYMBOL} short interest FINRA {year}"
- [ ] `WebSearch:` "{SYMBOL} earnings whisper estimate {year}"
- [ ] `WebSearch:` "{SYMBOL} dark pool ATS FINRA volume {year}" — dark pool activity proxy
- [ ] `WebSearch:` "{SYMBOL} Google Trends interest {year}" — retail interest trend
- [ ] `WebSearch:` "{SYMBOL} web traffic SimilarWeb {year}" — web traffic as alt data proxy

**Insider activity:**
- [ ] `FMP: searchInsiderTrades` (limit=10) — insider buys/sells with $ amounts
- [ ] `FMP: getInsiderTradeStatistics` — net insider ratio
- [ ] `FMP: getLatestInsiderTrading` (limit=5) — most recent transactions
- [ ] `WebSearch:` "{SYMBOL} {INSIDER_NAME} 10b5-1 plan SEC Form 4" — verify 10b5-1 status

**Congressional activity:**
- [ ] `FMP: getSenateTrades` — Senate trading activity
- [ ] `FMP: getHouseTrades` — House trading activity

**Corporate & news:**
- [ ] `FMP: getPressReleases` (limit=10) — official press releases
- [ ] `FMP: getPriceTargetNews` (symbol, limit=10) — analyst price target changes with reasoning
- [ ] `FMP: getStockGradeNews` (symbol, limit=10) — analyst rating changes (upgrade/downgrade/initiation)
- [ ] `FMP: getEarningsCalendar` (next 30 days) — POST-FILTER for symbol
- [ ] `Alpaca: get_corporate_actions` — splits, dividends, mergers
- [ ] `FMP: getAftermarketQuote` — AH price (ONLY when market CLOSED)
- [ ] `FMP: getAftermarketTrade` — AH trades (ONLY when market CLOSED)
- [ ] `FMP: searchStockNews` (limit=10) — symbol-specific news
- [ ] `WebSearch:` "{SYMBOL} stock news {year}" — **MANDATORY companion to searchStockNews. ALWAYS use BOTH.**
- [ ] `FMP: searchPressReleases` (limit=10) — symbol-specific press releases
- [ ] `FMP: getFilingsBySymbol` (limit=10) — recent SEC filings (8-K, 10-Q)
- [ ] `FMP: getDividends` — dividend history and yield trend
- [ ] `FMP: getDividendsCalendar` (next 30 days) — upcoming ex-div dates (POST-FILTER)
- [ ] `FMP: getStockSplitCalendar` (next 60 days) — upcoming splits (POST-FILTER)
- [ ] `FMP: searchEquityOfferings` — recent equity/debt offerings (dilution risk)
- [ ] `FMP: getLatest8KFilings` — material event filings (POST-FILTER for symbol)

**News NLP (sequential after Step 1):**
- [ ] `WebFetch` article 1 — extract: key facts, sentiment, impact, time horizon
- [ ] `WebFetch` article 2 — same analysis
- [ ] `WebFetch` article 3 — same analysis
- [ ] `WebFetch` article 4 — same analysis (if available)
- [ ] `WebFetch` article 5 — same analysis (if available, prioritize Tier 1 sources)
- [ ] Assign source credibility tiers: Tier 1 (Reuters/Bloomberg/WSJ) = 1.0x, Tier 2 (CNBC/Yahoo) = 0.8x, Tier 3 = 0.5x
- [ ] Cross-reference analyst grade/price target news with article sentiment

### Phase 12: Institutional Ownership (4 parallel calls)
- [ ] `FMP: getPositionsSummary` (adjusted quarter for 13F lag) — holders, share changes
- [ ] `FMP: getHolderPerformanceSummary` — institutional holder quality (alpha)
- [ ] `FMP: getForm13FFilingDates` — exact filing dates, stale vs fresh data detection
- [ ] `FMP: getHolderIndustryBreakdown` — holder industry concentration (correlated selling risk)
- [ ] **13F lag check:** Use most recent quarter where (Q_end + 45 days) < today

### Phase 13: Earnings Transcript (conditional)
- [ ] `FMP: getEarningsTranscript` — ONLY if earnings within 30 days or analyzing most recent quarter
- [ ] Analyze: tone, key themes, forward guidance, risk flags, management confidence

### Phase 14: Backtesting (3 sequential + 2 conditional)

**Step 1 — TV-Analysis backtests:**
- [ ] `TV-Analysis: compare_strategies` (period=1y) — rank all 6 strategies
- [ ] `TV-Analysis: backtest_strategy` (best strategy) — win rate, Sharpe, drawdown, trade count
- [ ] `TV-Analysis: walk_forward_backtest_strategy` (best strategy, period=2y) — overfit validation
- [ ] **Extract:** B&H return for benchmark comparison

**Step 2 — Desktop cross-validation (if Desktop available):**
- [ ] `TV: data_get_strategy_results` — Strategy Tester results
- [ ] `TV: data_get_equity` — equity curve, drawdown analysis
- [ ] **Cross-validation:** If TV-Analysis and Desktop diverge >20% → flag OVERFIT WARNING
- [ ] **Save:** `reports/{SYMBOL}_sentiment.md`

---

## PHASE GROUP 4: SYNTHESIS (Phases 15, 16, 16b)

### Phase 15: Risk Quantification & Position Sizing (9 parallel calls)
- [ ] `Alpaca: get_account_info` — equity, buying power, cash
- [ ] `Alpaca: get_open_position` (symbol) — existing position P&L, quantity
- [ ] `Alpaca: get_all_positions` — all positions for portfolio-level risk (sector concentration, aggregate beta, correlation)
- [ ] `Alpaca: get_portfolio_history` (3M, 1D) — portfolio equity curve, drawdown tracking
- [ ] `FMP: getStockPriceChange` — multi-period momentum (if not already cached)
- [ ] `FMP: getFullChart` (1Y daily) — daily OHLCV for historical VaR/CVaR (252 trading days)
- [ ] `WebSearch:` "{SYMBOL} earnings estimate revisions {year}" — revision trend

**Derived calculations:**
- [ ] Momentum Extension Risk category (EXTREME/SEVERE/HIGH/MODERATE/LOW/NONE)
- [ ] Apply market cap scaling to thresholds
- [ ] Check recovery exception (6M negative + 1M positive)
- [ ] Check IPO exception (<100 trading days)
- [ ] Check Fundamental-Catalyst Exception
- [ ] Historical VaR (95%): 5th percentile of 1Y daily returns × position_value
- [ ] CVaR (Expected Shortfall): average of returns below 5th percentile × position_value
- [ ] Volatility-scaled position sizing: risk_pct = 2% × (15 / VIX), capped [0.5%, 3%]
- [ ] Drawdown-adjusted sizing: >10% drawdown = halve size, >15% = block new positions
- [ ] Existing holdings check: subtract from 20% cap
- [ ] Sector concentration check: warn >30%, block >40%
- [ ] Kelly Criterion: half-Kelly vs fixed-fractional (use smaller)
- [ ] Stop loss: support level or entry - 2×ATR or entry × 0.97
- [ ] Take profit: resistance or analyst target (minimum R:R 2:1)
- [ ] Gap risk adjustment: if earnings <3 days + expected move > 2x stop = block entry
- [ ] Trailing stop: TRENDING = 3×ATR, MEAN-REVERTING = 5% fixed, TRANSITIONAL = 2.5×ATR
- [ ] Portfolio aggregate beta check: warn if >1.5
- [ ] Correlation risk check: warn if >3 positions in same sector

### Phase 16: Synthesis & Scoring

**Step 0 — Earnings Regime (MANDATORY GATE):**
- [ ] Determine: earnings within 7 days → PRE-EARNINGS WEIGHTS
- [ ] Check: within 2 trading days AFTER → Sell-the-News flag
- [ ] Log: "WEIGHTS: {NORMAL/PRE-EARNINGS}"

**Step 1 — Score all 8 dimensions (1-10 each):**

| Dimension | Key Inputs to Check |
|-----------|-------------------|
| Technical | RSI, Stochastic, MACD, ADX, TF alignment, ADX-conditional RSI, Volume Direction Modifier, FMP cross-validation (RSI/SMA/ADX), regime detection, Williams %R, DEMA/TEMA/WMA, relative strength vs market |
| Fundamental | Piotroski, Z-Score, revenue growth, earnings history (min 6/8), SBC Margin Adjustment, Economic Moat modifier, Financial Statement Forensics (Beneish M-Score, accruals, receivables, inventory) |
| Valuation | Revenue PEG + EPS PEG, EPS-PEG Divergence Adjustment, DCF range, analyst consensus, Industry P/E, bear-case DCF stress test, margin of safety, implied growth rate, TAM (Track B) |
| Smart Money | Insiders (+ 10b5-1), congressional, institutional, options flow, Insider-Inst Divergence Resolution, fund quality weighting, dark pool proxy, quality gate (cap at 6 if Fund <=3), 13F staleness |
| Risk | Beta (mcap-adjusted), RSI (ADX-conditional, anti-stacking with O1), IV/HV (earnings-scaled), earnings proximity (EBP gate), extension (anti-stacking with O5/SM), geographic, bid/ask (market hours only) |
| Backtest | Trade count gate, B&H waiver check, adaptive weighting, walk-forward robustness, statistical significance t-test |
| Sentiment | 5 platforms × mcap-scaled weights, News NLP paywall discount, consensus crowding indicator, multi-agent Override 8 |
| Macro | VIX (graduated by beta), rates, sector ETF, per-stock sensitivity (beta/intl rev/D:E), economic calendar, yield curve flat, global indicators (copper/gold, oil, DXY, GDP, CPI, COT), macro regime quadrant |

**Step 2 — Weighted composite:**
- [ ] Check earnings regime → select weight table
- [ ] Apply adaptive backtest weighting (trade count → effective weight)
- [ ] Compute: composite = sum(score × weight) / sum(weights) × 10
- [ ] Compute Quality Score = (Fund×0.30 + Val×0.25 + SM_quality×0.25 + Macro×0.20) × 10
- [ ] Compute Timing Score = (Tech×0.35 + Risk×0.25 + Sent×0.20 + BT×0.20) × 10

**Step 3 — Apply ALL 8 overrides (in order, ALL mandatory):**
- [ ] **O1: Overbought/Oversold** — RSI thresholds × ADX multiplier (0.5x/0.6x/1.0x)
- [ ] **O2: VIX Panic** — VIX >35 + beta >1.0 + composite >=60 → force HOLD
- [ ] **O3: Cross-Dimension Conflict** — Tech vs Fund >=5 divergence (-3), Risk <=2 + composite >=60 → HOLD, data <60% → HOLD
- [ ] **O4: R:R Check** — R:R <1.5 → force HOLD
- [ ] **O5: Momentum Extension** — category penalty with mcap scaling, combined formula with O1
- [ ] **O6: Earnings Catalyst** — EBP computation, +3/+1/0/-2/-4 modifier
- [ ] **O7: Sell-the-News** — EPS beat >10% + Rev beat >3% + stock <-5% + P/S>30 → -5
- [ ] **O8: Multi-Agent Consensus** — unanimous SELL (-3) or BUY (+2)
- [ ] **Quality Floor check:** if composite <40 but Quality >=60 + all quality dims >=4 → override to HOLD

**Step 4 — Signal determination:**
- [ ] >=75 STRONG BUY, 60-74 BUY, 40-59 HOLD, 25-39 SELL, <25 STRONG SELL
- [ ] Position-aware translation (no position: BUY/WAIT/AVOID; existing: ADD/MAINTAIN/EXIT)

**Step 5 — Data completeness:**
- [ ] Count successful_calls / total_calls = X%
- [ ] <60% → force HOLD

**Step 6 — Delta from prior analysis:**
- [ ] Check `reports/scores.csv` for prior scores
- [ ] Report score change and signal change

### Phase 16b: Chart Annotations (if Desktop available)
- [ ] `TV: draw_shape` — stop loss line (red)
- [ ] `TV: draw_shape` — take profit line (green)
- [ ] `TV: alert_create` — stop loss alert
- [ ] `TV: alert_create` — take profit alert

### Final Output

**Step 1 — Save files:**
- [ ] Save `reports/{SYMBOL}_technical.md` — technical analysis detail
- [ ] Save `reports/{SYMBOL}_fundamental.md` — fundamental analysis detail
- [ ] Save `reports/{SYMBOL}_sentiment.md` — sentiment, options, insider, backtest detail
- [ ] Save `reports/{SYMBOL}_{DATE}.md` — full compact card (all 16 sections)
- [ ] Append to `reports/scores.csv` — date, symbol, composite, signal, all 8 scores, completeness, price_at_scoring, quality_score, timing_score

**Step 2 — Display to user (MANDATORY — do NOT skip):**
- [ ] Display the COMPLETE Compact Card in conversation (all 16 sections from `output-formats.md`)
- [ ] Verify against 16-section checklist below before displaying

**Step 3 — 16-Section Display Verification:**
- [ ] Section 1: Header (symbol, price, score, confidence, data, market) ✓
- [ ] Section 2: Scores Table (8 dimensions + composite with bars/weights/drivers) ✓
- [ ] Section 3: Quality vs Timing (dual score + matrix signal) ✓
- [ ] Section 4: Momentum & Extension (6-period table + category) ✓
- [ ] Section 5: Valuation (track, PEG, DCF, analyst, earnings) ✓
- [ ] Section 6: Sentiment (5 platform signals) ✓
- [ ] Section 7: Options Flow (8 metrics: P/C, OI, IV/HV, skew, EM, MP, unusual, delta) ✓
- [ ] Section 8: Insider Activity (trades + 10b5-1 status for each) ✓
- [ ] Section 9: Institutional Ownership (holders, shares, ownership + staleness row) ✓
- [ ] Section 10: Congressional Activity (Senate + House, or "None detected") ✓
- [ ] Section 11: Backtest (strategy, B&H, walk-forward + adaptive weight note) ✓
- [ ] Section 12: Trade Setup (entry, stop, TP, R:R, spread, size + signal note) ✓
- [ ] Section 13: Warnings (severity-coded, minimum 3 warnings) ✓
- [ ] Section 14: Risks & Catalysts (balanced two-column, minimum 4 rows) ✓
- [ ] Section 15: Override Log (ALL 8 overrides O1-O8, no omissions) ✓
- [ ] Section 16: Footer & API Manifest (corporate, delta, sources, position, tool list) ✓

**CRITICAL: If ANY section is missing, do NOT display — go back and add it. Partial output is a pipeline violation.**

---

## TOOL CALL COUNTS BY SERVER

| Server | Calls | Notes |
|--------|------:|-------|
| **FMP** | ~90 | Bulk of data; many cacheable per session. Includes 9 always-on technical indicators + 6 macro additions |
| **TV-Analysis** | ~16 | Screeners, backtests, sentiment, market context (snapshot + gainers + losers + volume breakout) |
| **TV-Desktop** | ~13 | Chart setup, indicators, screenshot, annotations |
| **Alpaca** | ~10 | Market clock, options chain, account, positions, all_positions, portfolio history |
| **WebSearch** | ~9 | Sentiment, short interest, 10b5-1, estimate revisions, dark pool, Google Trends, SimilarWeb |
| **WebFetch** | ~5 | News article NLP (4-5 articles) |
| **Total** | **~143** | Reduced to ~100-120 with caching and conditionals |

---

## PARALLELIZATION GUIDE

| Batch | Calls | Phase |
|-------|-------|-------|
| 1 | get_clock + getCompanyProfile + getStockPriceChange + get_stock_snapshot | 0, 1 |
| 2 | multi_timeframe + coin_analysis + 9 FMP indicators + 3 market context | 3 |
| 3 | getShareFloat + smart_volume + volume_confirmation + consecutive_candles + volume_breakout | 4 |
| 4 | advanced_candle_pattern + bollinger_scan | 5 |
| 5 | tv_health_check → chart_set_symbol → chart_set_timeframe → add indicators → read data → screenshot | 6 |
| 6 | All 15 macro/sector/global calls | 2 |
| 7 | All 22 financial health calls | 7 |
| 8 | getStockPeers → getBatchQuotes + 3× peer ratios | 8 |
| 9 | 4 DCF/valuation + 10 analyst calls | 9 |
| 10 | 2 option chains + getStandardDeviation → get_option_bars | 10 |
| 11 | All ~35 sentiment/insider/news calls | 11 |
| 12 | 2 institutional calls | 12 |
| 13 | getEarningsTranscript (conditional) | 13 |
| 14 | compare_strategies → backtest → walk_forward → desktop cross-val | 14 |
| 15 | get_account_info + get_open_position + get_all_positions + get_portfolio_history + getStockPriceChange + getFullChart + WebSearch | 15 |
| 16 | Score → composite → overrides → signal → save → display | 16 |
| 17 | draw_shape × 2 + alert_create × 2 | 16b |

**Max parallelism:** Batches 6-9 (Phases 2, 7, 8, 9) can run simultaneously. Batches 10-14 (Phases 10-14) can overlap with batch 5 (Phase 6).

---

## VERIFICATION GATES

These are values that MUST be confirmed from actual data before being used in scoring. Never estimate or infer — read from the tool output.

### Phase 1 Verifications (before any scoring)
- [ ] **Beta:** Read exact value from `getCompanyProfile`. Record: "Beta = {X}". Used in: Risk score, Macro sensitivity, VIX override, position sizing.
- [ ] **Market Cap:** Read exact value. Record: "MCap = ${X}B". Used in: Extension threshold scaling, insider magnitude thresholds, beta threshold adjustment, peer count.
- [ ] **Sector/Industry:** Read exact value. Used in: Sector ETF mapping, industry P/E comparison, geographic risk.

### Phase 3 Verifications (before Technical scoring)
- [ ] **ADX exact value:** Read from `coin_analysis` output. Record: "ADX = {X}". If not returned, try `data_get_study_values` from Desktop.
- [ ] **+DI and -DI values:** Read from `coin_analysis`. Record: "+DI = {X}, -DI = {Y}". Compute ratio: "+DI/-DI = {Z}". Required for ADX-conditional RSI interpretation.
- [ ] **RSI exact value:** Read from `coin_analysis` AND cross-check with `data_get_study_values`. If they diverge, use Desktop value. Record: "RSI = {X}".
- [ ] **Stochastic %K/%D:** Read from `coin_analysis`. Record values. Used for Stochastic modifier in Technical scoring.

### Phase 7 Verifications (before Fundamental/Valuation scoring)
- [ ] **SBC/Revenue ratio:** Compute from `getIncomeStatement` (SBC line item) / revenue. Record: "SBC/Rev = {X}%". If >10%, MUST apply SBC Margin Adjustment. If SBC not in income statement, check `getExecutiveCompensation` for total stock awards.
- [ ] **Piotroski F-Score:** Read exact value from `getFinancialScores`. Record: "Piotroski = {X}/9".
- [ ] **Altman Z-Score:** Read exact value from `getFinancialScores`. Record: "Z-Score = {X}". Classify: >3 safe, 1.8-3 grey, <1.8 distress.
- [ ] **Revenue growth rate (FY YoY):** Compute from `getIncomeStatement` (FY, limit=2): (current_rev - prior_rev) / prior_rev × 100. Record: "Rev Growth = {X}%". This determines Track A vs Track B routing.
- [ ] **EPS growth rate (YoY):** Compute from earnings data. Record: "EPS Growth = {X}% (adjusted), {Y}% (GAAP)". Used for EPS-PEG divergence.
- [ ] **Earnings beat count:** Count from `getEarningsReports`. Record: "{X}/8 beats". If <6/8 quarters available, do NOT apply beat/miss modifier.

### Phase 9 Verifications (before Valuation scoring)
- [ ] **Track determination:** Revenue growth >20% OR P/E >40 → Track B. Log: "TRACK: {A/B}. Reason: rev growth {X}%, P/E {Y}x."
- [ ] **Trailing P/E:** Compute from price / TTM EPS (from `getFinancialRatiosTTM` or `getIncomeStatementTTM`). Record exact value.
- [ ] **Forward P/E:** Compute from price / forward EPS estimate (from `getAnalystEstimates`). If 402, use WebSearch consensus. Record exact value or "N/A (no forward estimates)".
- [ ] **Trailing PEG:** Compute: Trailing P/E / FY revenue growth %. Record: "Trailing PEG = {X}".
- [ ] **Forward PEG:** Compute: Forward P/E / forward revenue growth %. Record: "Forward PEG = {X}".
- [ ] **PEG divergence check:** If trailing PEG / forward PEG > 2x, flag: "PEG DIVERGENCE: trailing {X} vs forward {Y}."
- [ ] **EPS-PEG divergence:** If Revenue PEG > 2.0 AND EPS PEG < 1.0, compute divergence ratio. Record adjustment applied.
- [ ] **Custom DCF validation:** If custom DCF > 10x price OR < 0 → discard. Log: "CUSTOM DCF INVALID."
- [ ] **Analyst target count:** Record number of analysts. If large-cap with <5 analysts, cap analyst-based valuation at 6.
- [ ] **Analyst target age:** Verify targets are within 6 months. Flag stale targets.

### Phase 10 Verifications (before Options Flow / Smart Money scoring)
- [ ] **OI availability:** Check if `get_option_chain` response contains open_interest > 0 for any contract. If all OI = 0: mark P/C OI Ratio, Max Pain, Unusual Activity (5x OI), OI-based Net Delta as "N/A — OI not available".
- [ ] **P/C Volume Ratio:** Compute from actual chain volume data, not from last trade sizes. If volume not in snapshot, use prior session ratio with note "P/C from prior session".
- [ ] **IV/HV Ratio:** Compute: ATM IV (from chain) / HV (from `getStandardDeviation`). Record: "IV/HV = {X}". Apply earnings proximity scaling for threshold.
- [ ] **Expected Move:** Compute from ATM straddle mid-price. Cross-check with IV-based: Price × ATM_IV × sqrt(DTE/365). Record both. Pull last 8 earnings for historical calibration.

### Phase 11 Verifications (before Smart Money scoring)
- [ ] **10b5-1 status for EACH insider:** Run WebSearch: "{SYMBOL} {INSIDER_FULL_NAME} 10b5-1 SEC Form 4 {year}". Record one of:
  - "CONFIRMED 10b5-1 (adopted {DATE})" — reduces severity by 1 tier
  - "DISCRETIONARY (no 10b5-1 found)" — full severity
  - "NOT VERIFIED (inconclusive search)" — treat as discretionary but flag
- [ ] **Insider trade dates:** Verify all trades are within 60-day window. Discard older trades from scoring.
- [ ] **Insider trade recency weighting:** Apply: 30d=1.0x, 31-90d=0.7x, 91-180d=0.4x.
- [ ] **13F quarter validation:** Confirm the quarter used is the most recent COMPLETE quarter (Q_end + 45 days < today). Log: "Using Q{X} {YEAR} 13F data ({N} days old)".
- [ ] **13F staleness weight:** Apply: <=60d=1.0x, 61-90d=0.7x, 91-120d=0.5x, >120d=0.3x.
- [ ] **Earnings date (next):** Confirm from `getEarningsCalendar` POST-FILTERED for symbol. If not found in calendar, cross-check with `getEarningsReports` last date + ~90 days estimate. Record: "Next earnings: {DATE} ({N} days)".
- [ ] **News NLP compliance:** Verify: >=2 articles WebFetched, per-article sentiment assigned, source tiers assigned, >=1 Tier 1 source attempted. If <3/5 completed: flag "NEWS NLP: INCOMPLETE".

### Phase 15-16 Verifications (before final scoring)
- [ ] **Earnings regime:** BEFORE any scoring, confirm: "Earnings in {N} days. Using {NORMAL/PRE-EARNINGS} weights." This is a MANDATORY GATE.
- [ ] **Extension category:** Confirm 1M% and 3M% from `getStockPriceChange`. Apply market cap factor. Log: "Extension: {CATEGORY} (1M +{X}%, 3M +{Y}%, mcap {Z}x). Modifier: {-N}."
- [ ] **All 8 overrides evaluated:** Each override MUST have a log line: "OVERRIDE {N}: {APPLIED — details / NOT TRIGGERED — reason}". Missing evaluations = checklist violation.
- [ ] **Quality Floor dimension gate:** If Quality >=60 and composite <40, verify ALL quality sub-dimensions >=4 before applying floor.
- [ ] **Position sizing existing holdings:** If `get_open_position` returns a position, subtract from 20% cap before sizing new.
- [ ] **Sector concentration:** After sizing, verify sector exposure across `get_all_positions` does not exceed 30% (warn) / 40% (block).

---

## ERROR HANDLING QUICK REFERENCE

| Error | Action |
|-------|--------|
| Tool returns 402/404 | Log, set component to N/A, continue |
| Tool returns empty [] | Log "No {data} for SYMBOL", continue |
| Tool returns >50KB | Summarize key metrics only |
| Tool timeout | Log, set to N/A, continue |
| Bulk API (no symbol filter) | POST-FILTER for target symbol |
| <60% data completeness | Force HOLD |
| <5 of 8 dimensions scored | Force HOLD |
| FMP rate limit (429) | Note, score available dimensions only |
| Desktop unavailable | Skip chart calls, all data from TV-Analysis |
