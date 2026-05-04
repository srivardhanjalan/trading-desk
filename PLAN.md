# Trading Desk — Complete Implementation Plan (v5 FINAL)

## Context
We have 4 MCP servers (TradingView Desktop, TradingView Analysis, FMP, Alpaca) plus WebSearch/WebFetch. v5 integrates findings from 7 adversarial audits: deep options analysis (10 derived metrics), custom DCF with real growth inputs (6 of 18 parameters populated from collected data), earnings beat/miss history, VIX fear gauge (beta-conditional panic override), multi-platform sentiment (Reddit + Twitter/X + StockTwits with defined methodology and weights), full-text news NLP, graduated overbought override (not binary cap), crypto weight redistribution, tiered backtest trade gates, bid/ask spread and order book depth in scoring, geographic concentration risk, Smart Money conflict priority ordering, analyst event detection + estimate revision tracking, corporate actions, Desktop chart annotations + alerts + strategy cross-validation, after-hours pricing for morning-brief, and stock screener discovery mode. All phases run in a single conversation with file-based context management. **33-34 FMP calls per /analyze. ~55-73 total tool calls across all MCPs.**

---

## Architecture: Project Commands (NOT Plugin)

**Why not a plugin:** Plugins require marketplace registration via `~/.claude/settings.json`. Project-local `.claude-plugin/plugin.json` is NOT auto-discovered. We use `.claude/commands/*.md` which appear as `/project:command-name` slash commands.

### Execution Model
**`/project:analyze SYMBOL` runs ALL phases in a SINGLE conversation.** Claude Code commands are prompt templates, not scripts — they cannot invoke other commands programmatically. The `analyze.md` orchestrator contains instructions for all 16 phases, executed sequentially within one conversation. File-based handoff (`reports/SYMBOL_*.md`) manages context: after each batch of phases, key data is written to disk so raw tool responses can be compressed without losing critical metrics.

The sub-commands (`analyze-technical`, `analyze-fundamental`, `analyze-sentiment`, `synthesize`) exist as **standalone commands** for when the user wants to run just one phase group. They are NOT invoked by the orchestrator — they are alternative entry points.

**Context management strategy:** With 50-68 tool calls, context will be tight. Each phase batch writes a structured summary to `reports/`. Claude Code automatically compresses earlier messages as context fills. The synthesize phase reads the report files (not raw tool responses) ensuring all scoring data survives compression.

### Directory Structure
```
trading-view/
├── .claude/
│   └── commands/
│       ├── analyze.md              # /project:analyze AAPL → orchestrator
│       ├── analyze-technical.md    # /project:analyze-technical AAPL
│       ├── analyze-fundamental.md  # /project:analyze-fundamental AAPL
│       ├── analyze-sentiment.md    # /project:analyze-sentiment AAPL
│       ├── synthesize.md           # /project:synthesize AAPL → reads phase files, scores, recommends
│       ├── scan.md                 # /project:scan watchlist
│       ├── portfolio.md            # /project:portfolio
│       ├── trade.md                # /project:trade buy AAPL 500
│       ├── morning-brief.md        # /project:morning-brief
│       ├── research.md             # /project:research AAPL
│       └── compare.md             # /project:compare AMD NVDA
│   └── _shared/
│       ├── scoring-rubrics.md      # Explicit scoring thresholds for all 8 dimensions
│       ├── asset-classifier.md     # Detect stock vs crypto vs ETF vs ADR vs OTC
│       ├── error-handling.md       # Standard error handling for all phases
│       └── output-formats.md       # Compact card vs full report templates
├── reports/                        # Persisted analysis outputs
│   └── scores.csv                  # Score history for all analyzed stocks
├── bot.js                          # EXISTING — unchanged
├── rules.json                      # EXISTING — unchanged
└── trades.csv                      # EXISTING — unchanged
```

**Total: 15 new files** (11 commands + 4 shared references)

---

## FMP Call Optimization: Combination Strategy

### Principle: Always call everything. Combine calls to reduce count without losing data. **One exception:** `getEarningsTranscript` (Phase 13) is conditionally skipped to manage context size (50-100KB response), not rate limits.

| Combination | What 1 Call Replaces | Data Preserved | Saves |
|---|---|---|---|
| `getCompanyProfile` absorbs `getQuote` | Profile has price, change, volume, range, marketCap, beta, sector, industry, isEtf, isAdr, isFund. SMA50/200 already in `coin_analysis` (Phase 3) | All quote data preserved | 1 |
| ~~`getFinancialStatementGrowth` absorbs `getIncomeStatement`~~ | **REVERTED** — Growth only has % rates, loses absolute $ figures ($34.6B revenue, $2.65 EPS). Critical for valuation and reporting. | **Keep both: getIncomeStatement(FY, limit=2) + getFinancialStatementGrowth(FY, limit=2)** | 0 |
| ~~`getFinancialRatiosTTM` absorbs `getKeyMetricsTTM`~~ | **REVERTED** — KeyMetricsTTM has 26 unique fields: ROE, ROIC, EV/Sales, EV/OCF, netDebt/EBITDA, cash conversion cycle, R&D/revenue, income quality. Complementary datasets, not redundant. | **Keep both** | 0 |
| `getBatchQuotes` (stock+peers) absorbs 4× `getQuote` | One call returns quotes for stock + all peers together | Price, change%, 50SMA, 200SMA for all peers | 3 |
| `searchInsiderTrades` absorbs `getInsiderTradeStatistics` | Raw trades → derive net buy/sell count, total $ volume | Statistics derivable from raw data | 1 |
| `getPositionsSummary` absorbs `getFilingExtractAnalyticsByHolder` | Summary has institutional count + share changes. Detailed fund-by-fund analysis moved to `/research` | Institutional overview preserved. Deep dive in /research | 1 |
| `getStockNews` absorbs `getPressReleases` | News feed includes company announcements. Full PR analysis moved to `/research` | News coverage preserved. Deep PRs in /research | 1 |
| Derive owner earnings from `getCashFlowStatement` | Owner earnings = net income + D&A - maintenance capex. All inputs in cash flow statement | Calculation preserved | 1 |
| ~~`getFinancialScores` absorbs `getBalanceSheetStatement`~~ | **REVERTED** — Loses absolute cash ($5.5B), debt structure ($4.5B), goodwill ($25.1B), inventory, receivables. Needed for debt maturity analysis, working capital trends, asset quality. | **Keep both** | 0 |

**Total saved: 8 calls via combinations. v5 added 8 new FMP tools, net total: 33-34 per /analyze. Zero data loss. 3 combinations reverted after adversarial validation found critical data gaps.**

### Session-Level Caching
These calls return data that doesn't change per stock:
- `getTreasuryRates` — call once, reuse for all stocks in session
- `getStockPriceChange` (sector ETF) — call once per sector
- `getMarketRiskPremium` — call once, reuse for all stocks
- `getIndexQuote` (VIX) — call once, reuse for all stocks
- `Alpaca: get_clock` — call once, reuse for market hours header

**With caching: ~29-30 FMP calls on 2nd+ stock in same session (save ~4 cached calls).**

---

## The Full 16-Phase Pipeline (Split into 4 Sub-Commands)

### Sub-Command 1: `/project:analyze-technical SYMBOL`
**~9-21 tool calls (3 FMP + 4 TV-Analysis + 0-12 TV Desktop + 2 Alpaca)**

#### Phase 0: Asset Classification & Market Status
Read `_shared/asset-classifier.md`:
- `getCompanyProfile` response tells us: `isEtf`, `isAdr`, `isFund`, `country`, `exchange`
- Symbol pattern detection: ends in USDT/USD → crypto
- OTC exchange detection → warn limited data
- Result determines routing for all subsequent phases

| Tool | Data Retrieved | Cache? |
|------|---------------|--------|
| `Alpaca: get_clock` | `is_open`, `next_open`, `next_close` — determines market hours header | Yes — same for all stocks in session |

#### Phase 1: Price & Identity (3 calls: 2 FMP + 1 Alpaca, parallel)
| Tool | Data Retrieved |
|------|---------------|
| `FMP: getCompanyProfile` | Price, change, volume, avgVolume, marketCap, beta, 52W range, sector, industry, CEO, isEtf, isAdr, country, description |
| `FMP: getStockPriceChange` | Returns across 1D/5D/1M/3M/6M/1Y/3Y/5Y (momentum scoring) |
| `Alpaca: get_stock_snapshot` | Real-time bid/ask with sizes (spread = **liquidity signal** unavailable from FMP), latest trade, minute bar, daily bar. Critical for small-cap/illiquid stocks where wide spreads increase slippage risk |
| **Crypto route:** | `FMP: getCryptocurrencyQuote` + `getCryptocurrencyHistoricalLightChart` + `Alpaca: get_crypto_snapshot` instead |

#### Phase 3: Multi-Timeframe Technicals (2 TV-Analysis calls, parallel)
| Tool | Data Retrieved |
|------|---------------|
| `TV-Analysis: multi_timeframe_analysis` (symbol, exchange) | Trend alignment across Weekly → Daily → 4H → 1H → 15m |
| `TV-Analysis: coin_analysis` (symbol, exchange, "1D") | RSI, MACD, Stoch, ADX, BBands, all SMAs/EMAs (incl. SMA50, SMA200), support/resistance, market structure |

#### Phase 4: Volume & Smart Money (2 calls, parallel)
| Tool | Data Retrieved |
|------|---------------|
| `FMP: getShareFloat` | Float size, short interest %, short ratio |
| `TV-Analysis: smart_volume_scanner` (exchange) | **Exchange-wide scanner** — returns top unusual volume stocks on the exchange. Must search results for target symbol. If symbol absent, note "No unusual volume detected for SYMBOL" (neutral, not negative) |

#### Phase 5: Candle Patterns (1 TV-Analysis call)
| Tool | Data Retrieved |
|------|---------------|
| `TV-Analysis: advanced_candle_pattern` (exchange, "1D") | **Exchange-wide scanner** — returns stocks with active candle patterns. Must search results for target symbol. If absent, note "No significant candle patterns for SYMBOL" |

#### Phase 6: Chart — TradingView Desktop (0-9 calls, always attempted)
| Tool | Data Retrieved |
|------|---------------|
| `TV: tv_health_check` | Check if Desktop connected |
| If not running: `TV: tv_launch` | Auto-start Desktop |
| `TV: chart_set_symbol` + `chart_set_timeframe` ("D") | Navigate chart |
| `TV: chart_manage_indicator` | Add "Relative Strength Index", "MACD", "Bollinger Bands", "Exponential Moving Average", "Simple Moving Average", "Volume" (**FULL NAMES required**) |
| `TV: data_get_study_values` | Read all visible indicator numeric values |
| `TV: data_get_pine_labels` | Read custom indicator labels (if any) |
| `TV: depth_get` | **Order book / DOM** — bid/ask walls, order imbalance, spread. Reveals institutional supply/demand levels. Feeds into Smart Money scoring (bid depth > 2× ask = bullish, ask > 2× bid = bearish) |
| `TV: draw_shape` (horizontal_line × 1-2) | **Draw support/resistance from Phase 3** (blue lines). These are available NOW from `coin_analysis` output. Stop loss and take profit are drawn LATER in Phase 16 (synthesize) after they're computed |
| `TV: capture_screenshot` (region="chart") | Visual chart snapshot |
| **If Desktop unavailable:** | Log "Chart: Desktop unavailable", continue. All technical data still available from Phase 3 |

**Note:** `draw_shape` for stop/target levels and `alert_create` for price alerts are in **Phase 16 (Synthesize)**, not here — those levels require position sizing from Phase 15.

**Output:** Write results to `reports/SYMBOL_technical.md`

---

### Sub-Command 2: `/project:analyze-fundamental SYMBOL`
**~23 tool calls (23 FMP + 0 TV-Analysis + 0 Alpaca)**

#### Phase 2: Macro & Sector Context (3 FMP calls — all cached per session)
| Tool | Data Retrieved | Cache? |
|------|---------------|--------|
| `FMP: getTreasuryRates` | Current 2Y/5Y/10Y/30Y yields, yield curve shape | Yes — same for all stocks |
| `FMP: getStockPriceChange` (sector ETF: XLK/SMH/XLF/XLE based on sector) | Sector momentum: 1D/1M/3M/6M/1Y returns | Yes — same per sector |
| `FMP: getIndexQuote` ("^VIX") | **VIX fear gauge** — VIX >30 = high fear (risk-off environment), VIX <15 = complacency, VIX 15-20 = normal. Feeds into Macro and Risk scores | Yes — same for all stocks |
| **Crypto route:** | Skip sector ETF + treasury. VIX still relevant (risk-off affects crypto too) | |
| **ETF route:** | The ETF IS the sector. Compare to SPY instead | |

#### Phase 7: Fundamentals + Financial Health (10 FMP calls, parallel)
| Tool | Data Retrieved |
|------|---------------|
| `FMP: getFinancialRatiosTTM` | P/E, P/B, EV/EBITDA, margins, current ratio, debt/equity, dividend yield, FCF ratios |
| `FMP: getKeyMetricsTTM` | ROE, ROIC, EV/Sales, EV/OCF, netDebt/EBITDA, cash conversion cycle, R&D/revenue, income quality, Graham number |
| `FMP: getIncomeStatement` (period="FY", limit=2) | Absolute revenue ($), net income, EPS, R&D, SGA — needed for reporting and valuation |
| `FMP: getFinancialStatementGrowth` (period="FY", limit=2) | Pre-calculated YoY growth rates + 3Y/5Y/10Y compounded rates |
| `FMP: getBalanceSheetStatement` (period="FY", limit=1) | Cash, debt structure, goodwill, inventory, receivables, working capital, total equity |
| `FMP: getCashFlowStatement` (period="FY", limit=1) | Operating CF, capex, FCF, D&A (derive owner earnings: net income + D&A - capex) |
| `FMP: getFinancialScores` | Altman Z-Score (bankruptcy risk) + Piotroski F-Score (financial strength) |
| `FMP: getRevenueProductSegmentation` (period="annual") | Which products/segments drive revenue, concentration risk |
| `FMP: getRevenueGeographicSegmentation` (period="annual") | **Geographic revenue mix** — 90% China revenue = geopolitical risk. Moved from /research to main pipeline because it directly impacts Risk scoring |
| `FMP: getHistoricalMarketCap` (symbol, **from_date=1y_ago**, limit=252) | **Market cap trajectory** (daily data — sample quarterly: Q-4, Q-3, Q-2, Q-1, now). Shows if market is re-rating (expanding) or de-rating (contracting) the company. Context for Valuation scoring. Note: returns daily data, must sample quarterly manually |
| **Crypto route:** | Skip Phase 7. No traditional fundamentals |
| **ETF route:** | Replace with `getFundHoldings` + `getFundSectorWeighting` + `getFundInfo` |

#### Phase 8: Peer Comparison (2 FMP calls, sequential then parallel)
| Tool | Data Retrieved | Replaces |
|------|---------------|----------|
| `FMP: getStockPeers` | List of peer companies (top 3-4 by market cap) | Unique |
| `FMP: getBatchQuotes` (stock + top 3 peers, comma-separated) | Price, change%, marketCap, 50SMA, 200SMA for stock + all peers in ONE call | Replaces 4× individual getQuote |
| **Peer comparison output:** | Price momentum comparison table. For valuation comparison, use main stock's ratiosTTM vs peers' quick metrics from quote data | |
| **If getStockPeers empty:** | Note "No peer data available", continue | |

#### Phase 9: Valuation & Analyst Targets (8 FMP calls — 7 + 1 cached)

**Step 1 — Valuation models (4 calls, parallel):**
| Tool | Data Retrieved |
|------|---------------|
| `FMP: getDCFValuation` | Standard (unlevered) DCF intrinsic value estimate |
| `FMP: getLeveredDCFValuation` | **Levered DCF** — accounts for debt. For leveraged companies, difference from unlevered can be 20-40%. Both together create a **valuation range** |
| `FMP: calculateCustomDCF` (symbol, **revenueGrowthPct**=actual from Phase 7 `getFinancialStatementGrowth`, **beta**=from Phase 1 `getCompanyProfile`, **marketRiskPremium**=from `getMarketRiskPremium`, **riskFreeRate**=10Y yield from Phase 2 `getTreasuryRates`, **costOfDebt**=interestExpense/totalDebt from Phase 7 `getBalanceSheetStatement`, **taxRate**=from `getIncomeStatement`) | **Custom DCF with real inputs** — the tool accepts 18 optional parameters. We populate 6 key ones from data already collected in earlier phases. Remaining 12 use FMP defaults (reasonable for most stocks). This produces a meaningfully different result from the black-box DCF, especially for growth stocks |
| `FMP: getMarketRiskPremium` | Equity risk premium — input to calculateCustomDCF | Cached per session |

**DCF usage in scoring:**
- **Track A (Value stocks):** Use average of standard DCF and levered DCF as intrinsic value
- **Track B (Growth stocks):** Use custom DCF (with real growth inputs) as the DCF reference. If custom DCF still undervalues significantly, PEG overrides per rubric
- **Always report all 3 DCF values** for transparency: "DCF range: $57 (standard) / $72 (levered) / $145 (custom growth-adjusted)"

**Step 2 — Analyst sentiment (4 calls, parallel):**
| Tool | Data Retrieved |
|------|---------------|
| `FMP: getPriceTargetSummary` | Analyst consensus target + **analyst COUNT** + **standard deviation** + high/low. Replaces getPriceTargetConsensus — "$180 from 3 analysts" vs "$180 from 25 analysts" is completely different confidence |
| `FMP: getHistoricalStockGrades` (limit=10) | Monthly aggregate analyst rating counts (Strong Buy/Buy/Hold/Sell) ��� trend over time |
| `FMP: getStockGradeNews` (symbol) | **Recent upgrade/downgrade EVENTS with dates** — detects "3 downgrades this week" which monthly aggregates structurally cannot see. Feeds into Sentiment and Smart Money scores |
| `FMP: getEarningsReports` (symbol) | **Historical earnings beat/miss data** — actual vs estimated EPS for last 4-8 quarters. Stock that beats 8/8 quarters has fundamentally different risk than a serial misser. Feeds into Fundamental and Risk scores |
| **Crypto/ETF route:** | Skip DCF/custom DCF. Use price target only if available. Skip earnings reports |

**Output:** Write results to `reports/SYMBOL_fundamental.md`

---

### Sub-Command 3: `/project:analyze-sentiment SYMBOL`
**~24-30 tool calls (7-8 FMP + 5-7 TV-Analysis/Desktop + 4 Alpaca + 4-5 Web + 0-2 TV Desktop)**

#### Phase 10: Options Flow & Implied Volatility (4 calls: 3 Alpaca + 1 FMP)

**Step 1 — Pull chain data (3 calls, parallel):**
| Tool | Data Retrieved |
|------|---------------|
| `Alpaca: get_option_chain` (underlying_symbol, type="call", strike_price_gte=**price×0.9**, strike_price_lte=**price×1.1**, expiration_date_gte=today, expiration_date_lte=**today+45d**, limit=50) | Call side ATM ± 10%, near-term: last price, bid/ask, IV, volume, OI, delta, gamma, theta, vega per contract |
| `Alpaca: get_option_chain` (underlying_symbol, type="put", strike_price_gte=**price×0.9**, strike_price_lte=**price×1.1**, expiration_date_gte=today, expiration_date_lte=**today+45d**, limit=50) | Put side ATM ± 10%, near-term: same fields |
| `FMP: getStandardDeviation` (symbol, periodLength=30, timeframe="1day", **from_date=30d_ago, to=today**) | 30-day historical volatility (HV) |

**Why ATM ± 10% and 45-day expiry:** Most liquid contracts with highest signal. Deep OTM options are noise. Near-term expiries reflect current sentiment, not long-dated speculation.

**Step 2 — Trending on most active contracts (1 call, sequential after Step 1):**
| Tool | Data Retrieved |
|------|---------------|
| `Alpaca: get_option_bars` (symbols=**top 3 contracts by volume from Step 1**, timeframe="1Day", start=**7d_ago**) | 7-day daily OHLCV bars for the 3 highest-volume contracts. Shows if premiums are rising (bullish momentum for calls / increasing fear for puts) or falling. |

**Always called.** If no options exist, Alpaca returns empty → note "No options market for this stock", use HV only, set options-derived scores to N/A.

**Step 3 — Derived analysis (computed from chain data, no additional calls):**

| Metric | Calculation | What It Tells You |
|--------|-------------|-------------------|
| **Put/Call Volume Ratio** | Σ put volume ÷ Σ call volume | >1.0 = bearish hedging dominant. <0.7 = bullish conviction. 0.7-1.0 = neutral |
| **Put/Call OI Ratio** | Σ put OI ÷ Σ call OI | More stable than volume ratio. Persistent >1.2 = sustained bearish positioning |
| **IV Skew** | Avg put IV (ATM ± 2 strikes) − avg call IV (ATM ± 2 strikes) | Positive = fear premium (puts cost more). Negative = greed (calls cost more). >5% spread = significant |
| **Max Pain** | Strike where Σ(call OI × max(0, strike−S) + put OI × max(0, S−strike)) is minimized across all strikes S | Price magnet for expiration week. Market makers profit most here. If current price far from max pain, expect pull toward it near expiry |
| **IV vs HV** | Avg chain IV ÷ HV from getStandardDeviation | >1.5 = market expects big move (earnings, catalyst). <0.8 = market complacent (potential surprise). ~1.0 = normal |
| **Expected Move** | ATM call premium + ATM put premium (nearest expiry straddle price) | Dollar amount market expects stock to move by expiration. E.g., "$12.50 expected move = ±7.8% by May 16" |
| **Unusual Activity** | Flag contracts where today's volume > 5× open interest | Large new positions being opened = smart money making a directional bet. Report: strike, expiry, direction, volume/OI ratio |
| **Most Active Strikes** | Top 3 call and top 3 put strikes by volume | Where is money concentrating? Clustering at specific strikes reveals institutional price targets |
| **Premium Trend** | From `get_option_bars`: 7-day price change % for top 3 contracts | Rising call premiums = increasing bullish bets. Rising put premiums = increasing hedging/fear. Falling premiums = fading conviction |
| **Net Delta Exposure** | Σ(call OI × call delta) − Σ(put OI × |put delta|) | Positive = market net long (bullish positioning). Negative = market net short/hedged. Magnitude indicates conviction |

#### Phase 11: Sentiment & Insider/Political Activity (13-15 calls)

**Step 1 — Multi-platform sentiment + news (10-12 calls, parallel):**
| Tool | Data Retrieved |
|------|---------------|
| `TV-Analysis: market_sentiment` (symbol, "stocks") | **Reddit sentiment** across r/stocks, r/wsb, r/investing, r/options etc. |
| `TV-Analysis: multi_agent_analysis` (symbol, exchange, "1D") | 3-agent debate: Technical + Sentiment + Risk Manager |
| `FMP: getStockNews` (symbol, limit=5) | Recent news headlines **with URLs** (URLs used in Step 2) |
| `WebSearch` ("SYMBOL stock twitter sentiment 2026") | **Twitter/X sentiment** — fastest-moving platform. Catches activist short reports, CEO tweets, analyst hot takes before Reddit |
| `WebSearch` ("SYMBOL site:stocktwits.com") | **StockTwits sentiment** — built-in bullish/bearish tagging per message. Quantifiable sentiment ratio |
| `FMP: searchInsiderTrades` (symbol, limit=10) | Insider buys/sells with $ amounts. **Derive net buy/sell ratio from raw data.** |
| `FMP: getSenateTrades` (symbol) | Senate member trades. **Always called.** Empty = "No Senate activity" |
| `FMP: getHouseTrades` (symbol) | House member trades. **Always called.** Empty = "No House activity" |
| `FMP: getEarningsCalendar` (from=today, to=today+30d) | Returns ALL companies' earnings in date range (**no symbol filter** — must search response for target symbol). Alternatively, use `getEarningsReports` from Phase 9 which has per-symbol dates and is already called |
| `Alpaca: get_corporate_actions` (symbol) | **Upcoming splits, dividends, spin-offs, mergers** within 30 days. A reverse split could trigger stop-losses artificially. Feeds into Risk scoring |

**Step 2 — Full-text news NLP (2-3 calls, sequential after Step 1):**
| Tool | Data Retrieved |
|------|---------------|
| `WebFetch` (top 2-3 news article URLs from `getStockNews` response) | **Full article text** for NLP analysis. "Supply chain concerns" headline vs article describing 30% component shortage are categorically different signals. Claude analyzes each article for: key facts, sentiment (+/-/neutral), impact magnitude (high/medium/low), and time horizon |

**Why full-text matters:** Headlines are often clickbait or misleading. A "Stock drops 5%" headline might be about a planned dilution (bad) or profit-taking after +30% run (neutral). Only the article body reveals the actual signal.

| **Crypto route:** | market_sentiment + multi_agent_analysis + searchCryptoNews + WebSearch Twitter. Skip insider/congressional/corporate actions |

#### Phase 12: Institutional Ownership (1 FMP call)
| Tool | Data Retrieved |
|------|---------------|
| `FMP: getPositionsSummary` (symbol, year, quarter) | Number of institutional holders, changes in share count, total investment value. **Filing lag: 13F filings have ~45 day delay.** Use: Jan-Mar → Q3 prev year, Apr-Jun → Q4 prev year, Jul-Sep → Q1 current, Oct-Dec → Q2 current |
| **Always called.** Empty = "No institutional data this quarter" | |

#### Phase 13: Earnings Deep Dive (0-1 FMP call)
| Tool | Data Retrieved | Condition |
|------|---------------|-----------|
| `FMP: getEarningsTranscript` (symbol, year, quarter) | Full earnings call transcript | **Only skip to manage CONTEXT SIZE (50-100KB), not rate limits.** If earnings within 30d (from Phase 11 calendar check) OR most recent quarter: fetch and summarize key themes, tone, forward guidance. Otherwise: skip. |

#### Phase 14: Strategy Backtesting (3-5 calls: 3 TV-Analysis + 0-2 TV Desktop)

**Step 1 — TV-Analysis backtesting (3 calls, sequential):**
| Tool | Data Retrieved |
|------|---------------|
| `TV-Analysis: compare_strategies` (symbol, period="1y") | Ranked leaderboard: RSI, Bollinger, MACD, EMA Cross, Supertrend, Donchian |
| `TV-Analysis: backtest_strategy` (symbol, best_strategy, include_trade_log=false) | Win rate, Sharpe, max drawdown, profit factor for best strategy |
| `TV-Analysis: walk_forward_backtest_strategy` (symbol, best_strategy, period="2y") | Overfit validation on unseen data |

**Step 2 — Desktop strategy tester cross-validation (2 calls, conditional on Desktop running):**
| Tool | Data Retrieved |
|------|---------------|
| `TV: data_get_strategy_results` | **TradingView's native Strategy Tester** results — includes commission/slippage modeling, equity curve shape, max drawdown with dates, individual trade P&L. Higher fidelity than TV-Analysis because it uses real TradingView charting engine data |
| `TV: data_get_equity` | **Equity curve data** — shows drawdown periods, recovery time, consistency of returns. A strategy with 50% win rate but massive drawdown periods is riskier than the numbers suggest |

**Cross-validation rule:** If TV-Analysis backtest return diverges from Desktop Strategy Tester return by >20%, flag **"OVERFIT WARNING"** and cap Backtest score at 5. Divergence indicates the strategy's performance is data-source dependent (unreliable).

**Output:** Write results to `reports/SYMBOL_sentiment.md`

---

### Sub-Command 4: `/project:synthesize SYMBOL`
**~3-8 tool calls (0 FMP + 0-4 TV Desktop + 2 Alpaca + 1 WebSearch)**

#### Read Phase Files
- Read `reports/SYMBOL_technical.md`
- Read `reports/SYMBOL_fundamental.md`
- Read `reports/SYMBOL_sentiment.md`
- Read `_shared/scoring-rubrics.md`

#### Phase 15: Risk Quantification & Position Sizing (2 Alpaca + 1 WebSearch)
| Tool | Data Retrieved |
|------|---------------|
| `Alpaca: get_account_info` | Current equity, buying power, cash |
| `Alpaca: get_open_position` (symbol) | Check if already held, current P&L |
| `WebSearch` ("SYMBOL earnings estimate revisions 2026") | **Analyst estimate revision trend** — Zacks/Yahoo show if EPS estimates are being raised or lowered. One of the strongest price predictors. Fallback for broken `getAnalystEstimates` (402 error) |
| **Derived:** | VaR = price × HV × 1.645. Position size = (equity × 0.02) / (entry - stop). Kelly = win_rate - (loss_rate / avg_win_loss). Stop from support levels or ATR. |

#### Phase 16: Synthesis & Recommendation
- Apply scoring rubrics from `_shared/scoring-rubrics.md` to all phase data
- Score all 8 dimensions (1-10 each)
- Calculate weighted composite (0-100)
- Apply overrides (overbought, VIX panic, conflict resolution)
- Determine BUY/SELL/HOLD per threshold table
- Track data completeness %
- Generate compact card (default) or full report (if --full)

#### Phase 16b: Chart Annotations (0-4 TV Desktop calls, conditional)
| Tool | Data Retrieved |
|------|---------------|
| `TV: draw_shape` (horizontal_line, stop loss, red) | Draw computed stop loss on chart |
| `TV: draw_shape` (horizontal_line, take profit, green) | Draw computed take profit on chart |
| `TV: alert_create` (symbol, price=stop_loss, condition="less_than") | Price alert at stop loss level |
| `TV: alert_create` (symbol, price=take_profit, condition="greater_than") | Price alert at take profit level |
| **If Desktop unavailable:** | Skip — levels still shown in text output |

**Note:** These calls are here (not Phase 6) because stop/target levels require Phase 15's position sizing to be computed first.

#### Persist Results
- Save to `reports/SYMBOL_YYYY-MM-DD.md`
- Append to `reports/scores.csv`
- Show delta from previous run if exists

---

## FMP Call Budget Summary

### Per /analyze (full)
| Sub-Command | FMP Calls | Details |
|-------------|-----------|---------|
| analyze-technical | 3 | getCompanyProfile + getStockPriceChange + getShareFloat |
| analyze-fundamental | 23 | 3 macro (cached: treasury + sector ETF + VIX) + 10 fundamentals + 2 peers + 8 valuation (4 DCF/valuation + 1 cached MRP + 3 analyst/earnings) |
| analyze-sentiment | 7-8 | 1 stddev + 5 sentiment + 1 institutional + 0-1 transcript |
| synthesize | 0 | Reads files + 2 Alpaca calls |
| **Total** | **33-34** | Full depth across all dimensions |
| **With session cache** | **29-30** | VIX + treasury + market risk premium + sector ETF cached |

### Per /scan (16 stocks)
| Component | FMP Calls |
|-----------|-----------|
| Macro (1×, cached: treasury + VIX) | 3 |
| Per stock: getCompanyProfile + getFinancialRatiosTTM + getFinancialScores + getDCFValuation + getPriceTargetSummary + getStockPriceChange | 6 each |
| **Total** | 3 + (16 × 6) = **99** |
| **Discovery mode** | +1 (stockScreener) then scan top 10 = 3 + 1 + (10 × 6) = **64** |

### All Tool Calls Per /analyze (across all MCPs)
| MCP Server | Calls | Details |
|------------|-------|---------|
| FMP | 33-34 | 3 technical + 23 fundamental + 7-8 sentiment |
| TV-Analysis | 9 | multi_timeframe + coin_analysis + smart_volume + candle_pattern + compare_strategies + backtest + walk_forward + market_sentiment + multi_agent |
| TV Desktop | 0-16 | Phase 6: health + launch + symbol + timeframe + indicators + study_values + labels + depth + draw(support) + screenshot = 10. Phase 14: strategy_results + equity = 2. Phase 16b: draw(stop) + draw(target) + alert×2 = 4 |
| Alpaca | 8 | clock + stock_snapshot + option_chain×2 + option_bars + corporate_actions + account_info + open_position |
| WebSearch | 3 | Twitter + StockTwits + estimate revisions |
| WebFetch | 2-3 | Full-text NLP on top news articles |
| **Total** | **~55-73** | Desktop-off minimum: ~55. Desktop-on maximum: ~73 |

### Daily Budget (FMP only — other MCPs have no daily limit)
| Command | FMP Calls | Frequency | Subtotal |
|---------|-----------|-----------|----------|
| /analyze (full) | 34 + 30 (2nd cached) | 2× per day | 64 |
| /scan watchlist | 99 | 1× per day | 99 |
| /morning-brief | ~25 | 1× per day | 25 |
| /portfolio | ~8 | 2× per day | 16 |
| /trade | 1 | as needed | 1 |
| /research | ~5 | as needed | 5 |
| **Typical daily total** | | | **~210** |
| **Budget remaining** | | | **~40 (buffer for retries/extras)** |

---

## Scoring Rubrics (`_shared/scoring-rubrics.md`)

### Technical Score (1-10)
| Score | Criteria |
|-------|----------|
| 9-10 | All 5 TFs aligned bullish/bearish + RSI 40-70 + MACD crossover confirmed + ADX >25 (trending) + Stochastic confirms (not diverging) |
| 7-8 | 4/5 TFs aligned + favorable RSI + positive MACD or ADX >20 + Stochastic aligned |
| 5-6 | Mixed signals: 3/5 TFs aligned, or RSI overbought/oversold, or MACD flat, or Stochastic diverging from price |
| 3-4 | 2/5 TFs aligned, conflicting signals, ADX <20 (no trend) |
| 1-2 | All TFs bearish (for buy) or all bullish (for sell), RSI extreme + ADX declining |

**Stochastic integration:** Use Stochastic %K/%D from `coin_analysis` output. Stochastic >80 with price at highs = potential reversal risk (reduce Technical by 1). Stochastic <20 with price at lows in uptrend = snap-back setup (boost Technical by 1).

### Fundamental Score (1-10)
| Score | Criteria |
|-------|----------|
| 9-10 | Piotroski >=8 + Z-Score >3 + revenue growing >20% YoY + margins expanding + positive growing FCF + **beats earnings ≥6/8 quarters** |
| 7-8 | Piotroski 6-7 + Z-Score >3 + revenue growing >10% + stable/expanding margins + **beats earnings ≥4/8 quarters** |
| 5-6 | Piotroski 4-5 + Z-Score 1.8-3 + revenue flat or <10% growth + **mixed beat/miss history** |
| 3-4 | Piotroski 2-3 + Z-Score 1.1-1.8 (grey zone) + declining revenue or margins + **misses earnings ≥4/8 quarters** |
| 1-2 | Piotroski 0-1 + Z-Score <1.1 (distress) + negative FCF + shrinking revenue + **serial earnings misser** |

**Earnings beat/miss modifier:** From `getEarningsReports`:
- Beats 7-8 of last 8 quarters: +1 to Fundamental score (reliable execution)
- Misses 5+ of last 8 quarters: -1 to Fundamental score (management credibility issue)
- Large surprise magnitude (>10% beat/miss): additional ±0.5

### Valuation Score (1-10)
**Two-track scoring: Value vs Growth**
Detect growth stock: revenue growth >20% YoY OR P/E >40. If growth, use Track B.

**Track A (Value stocks — revenue growth <20%, P/E <40):**
| Score | Criteria |
|-------|----------|
| 9-10 | Price <70% of DCF + below analyst low target + P/E below peer median |
| 7-8 | Price <90% of DCF + below analyst consensus + P/E near peer median |
| 5-6 | Price near DCF + near analyst consensus + P/E at peer median |
| 3-4 | Price >120% of DCF + above analyst consensus + P/E above peer median |
| 1-2 | Price >200% of DCF + above analyst high target + P/E >2x peer median |

**Track B (Growth stocks — revenue growth >20% OR P/E >40):**

**PEG calculation routing:**
- If P/E > 0 and revenue growth > 0: PEG = P/E ÷ revenue growth rate (%)
- If P/E is N/A (negative earnings) but sales growth > 0: Use PSG = Price/Sales ÷ sales growth rate (%). Apply same thresholds as PEG
- If both earnings AND sales growth negative: **Route back to Track A** — broken growth story is a value question, not a growth question
- If P/E is N/A and revenue growth is negative: Score = 1-2 automatically (broken growth story)

| Score | Criteria |
|-------|----------|
| 9-10 | PEG <0.8 + below analyst consensus + revenue acceleration + **beats earnings ≥6/8 quarters** |
| 7-8 | PEG 0.8-1.2 + near analyst consensus + sustained high growth + **beats ≥4/8** |
| 5-6 | PEG 1.2-2.0 + at analyst consensus + growth decelerating |
| 3-4 | PEG 2.0-3.0 + above analyst consensus + growth slowing materially |
| 1-2 | PEG >3.0 OR broken growth story (negative earnings + negative sales growth) |

**Track B earnings execution gate:** If stock misses earnings ≥5/8 quarters, **cap Track B Valuation at 5** regardless of PEG. A low PEG means nothing if the company consistently fails to deliver the growth the PEG ratio assumes.

**Why two tracks:** Raw DCF systematically undervalues growth stocks (discounting >20% growth at a fixed rate produces artificially low intrinsic values). A $320 stock with 80% revenue growth appearing at 5.6x DCF is normal for hypergrowth, not a sign of overvaluation. PEG normalizes for growth rate.

### Sentiment Score (1-10)
| Score | Criteria |
|-------|----------|
| 9-10 | Reddit + Twitter/X + StockTwits all bullish + multi-agent BUY high confidence + positive news (full-text NLP confirms) + recent analyst upgrades |
| 7-8 | 2/3 social platforms bullish + multi-agent BUY + neutral-positive news content + no downgrades |
| 5-6 | Mixed across platforms + multi-agent HOLD + news mixed or neutral |
| 3-4 | 2/3 social platforms bearish + multi-agent SELL + negative news (full-text confirms real issue) + recent downgrades |
| 1-2 | All platforms bearish + multi-agent SELL high confidence + negative news cluster + multiple downgrades this week |

**Multi-platform scoring methodology:**

| Platform | Source | Weight | Scoring Method |
|----------|--------|--------|---------------|
| **Reddit** | `market_sentiment` | 0.30 | Direct % bullish from tool output. >60% = bullish, <40% = bearish |
| **Twitter/X** | `WebSearch` | 0.20 | Claude classifies top 5-10 results as bullish/bearish/neutral. If WebSearch returns login walls or irrelevant results, weight redistributes to other platforms |
| **StockTwits** | `WebSearch` | 0.20 | Extract bull/bear ratio if available (often shown as "X% bullish"). If unavailable, redistribute |
| **News NLP** | `WebFetch` articles | 0.20 | Per-article: positive/negative/neutral + impact magnitude. Source credibility tiers: Tier 1 (Reuters, Bloomberg, WSJ) = 1.0×, Tier 2 (CNBC, Yahoo Finance) = 0.8×, Tier 3 (blogs, unknown) = 0.5× |
| **Analyst events** | `getStockGradeNews` | 0.10 | Upgrades = +1 per event, downgrades = -1. Recency: this week = 2×, this month = 1×, older = 0.5× |

**Weighted sentiment = Σ(platform_score × weight).** Platform scores: bullish = +1, neutral = 0, bearish = -1.
- Weighted sentiment > +0.3 → bullish component of Sentiment score
- Weighted sentiment < -0.3 → bearish component
- Between -0.3 and +0.3 → neutral/mixed

**Sentiment divergence:** If platforms disagree (e.g., Reddit strongly bullish but Twitter strongly bearish), **cap Sentiment score at 5** and note "SENTIMENT DIVERGENCE — platforms disagree." Confidence is low when sources conflict.

**Fallback:** If WebSearch returns unusable results for Twitter/StockTwits (login walls, irrelevant pages), redistribute weight to Reddit + News NLP. Note "Limited social data" in output.

### Smart Money Score (1-10)
| Score | Criteria |
|-------|----------|
| 9-10 | Net insider buying (>$1M) + congressional buying + institutional accumulation + **bullish options flow** (P/C vol ratio <0.7 + positive net delta + unusual call activity + rising call premiums) |
| 7-8 | 3 of 4 smart money signals positive, OR insider buying >$5M (magnitude override), OR **unusual call volume >10x OI at specific strike** (large directional bet) |
| 5-6 | Mixed: some insider buying + selling, neutral institutional, P/C ratio 0.7-1.0, no unusual activity |
| 3-4 | Net insider selling + institutional flat/declining + **bearish options flow** (P/C vol ratio >1.0 + negative net delta + rising put premiums) |
| 1-2 | Heavy insider selling (>$10M) + congressional selling + institutional dumping + **extreme put/call ratio (>1.5)** + unusual put activity + negative IV skew |

**Insider magnitude weighting:** A CEO buying $2M is categorically different from a VP selling $50K of vested options. Weight insider transactions by dollar volume:
- Aggregate net $ bought vs sold from `searchInsiderTrades` response
- Buys >$1M from C-suite = strong signal (boost +1)
- Sales >$10M from multiple insiders = strong negative (reduce -1)
- Routine 10b5-1 plan sales (identifiable by regular cadence) = neutral, do not count

**Smart Money conflict priority** (when signals contradict):
1. **Insider magnitude sets the floor/ceiling:** $15M+ insider buying → floor at 6. $10M+ insider selling → ceiling at 4
2. **Options flow adjusts within the range:** bullish flow +1, bearish -1
3. **Institutional + congressional confirm or moderate:** aligned = no change, contradicting = pull 1 toward neutral (5)
4. This prevents ambiguity: the rubric produces ONE number, not a range

**Order book depth modifier** (from `depth_get`): bid depth > 2× ask depth at key levels = +1 (institutional demand). Ask depth > 2× bid = -1 (supply wall). Only applies when Desktop is available.

### Macro Score (1-10)
| Score | Criteria |
|-------|----------|
| 9-10 | Sector ETF outperforming SPY YTD + falling/stable rates + **VIX <15** (complacency/calm) + sector ETF above 200 SMA |
| 7-8 | Sector ETF inline with SPY + stable rates + **VIX 15-20** (normal) + neutral trend |
| 5-6 | Sector ETF underperforming slightly + rising rates but contained + **VIX 20-25** (elevated) |
| 3-4 | Sector ETF underperforming significantly + rapidly rising rates + **VIX 25-30** (fear) |
| 1-2 | Sector ETF in freefall + yield curve inverting/steepening sharply + **VIX >30** (panic — risk-off environment, reduce all equity exposure) |

**VIX integration:** VIX >30 is a **Macro override** — regardless of sector performance, subtract 2 from Macro score (min 1) when VIX >30. Buying into a fear environment increases the probability of drawdown regardless of individual stock quality.

### Backtest Score (1-10)
| Score | Criteria |
|-------|----------|
| 9-10 | Best strategy >50% win rate + >2.0 profit factor + >2.0 Sharpe + walk-forward validates + **≥20 trades** |
| 7-8 | Best strategy >40% win rate + >1.5 profit factor + >1.0 Sharpe + **≥15 trades** |
| 5-6 | Best strategy >30% win rate + >1.0 profit factor + positive return + **≥10 trades** |
| 3-4 | Best strategy breakeven or slight loss, low Sharpe |
| 1-2 | All strategies lose money, negative Sharpe across the board |

**Minimum trade gate (tiered):**
- <5 total trades: **cap Backtest score at 2** (statistically meaningless — could be 1 lucky trade)
- 5-9 trades: **cap at 4** (suggestive but unreliable)
- 10-14 trades: **cap at 6** (minimum viable sample)
- 15+ trades: no cap (sufficient sample size)

**Buy-and-hold benchmark:** If best strategy total return < buy-and-hold return over same period, **subtract 2** from Backtest score (min 1). A strategy that underperforms passive holding is not worth trading.

**Desktop cross-validation:** If TradingView Desktop is available and `data_get_strategy_results` return diverges from TV-Analysis `backtest_strategy` return by >20%, **cap Backtest score at 5** and flag "OVERFIT WARNING — results are data-source dependent." This catches strategies that look great on one dataset but fail on another.

### Risk Score (1-10) — INVERTED: 10 = lowest risk
| Score | Criteria |
|-------|----------|
| 9-10 | Beta <1.0 + RSI 40-60 + **IV/HV <1.0** (market calm) + no earnings within 14d + position <5% portfolio |
| 7-8 | Beta 1.0-1.5 + RSI not extreme + **IV/HV 1.0-1.3** + no imminent events |
| 5-6 | Beta 1.5-2.0 + RSI approaching extreme OR earnings within 14d + **IV/HV 1.3-1.5** |
| 3-4 | Beta >2.0 + RSI overbought/oversold + **IV/HV >1.5** (market expects big move) + earnings imminent |
| 1-2 | Extreme beta + RSI extreme + **IV/HV >2.0** (IV spike) + expected move >10% + extended >30% from 50 SMA + heavy insider selling |

**Risk modifiers (applied after base score):**
- **Bid/ask spread** (from `get_stock_snapshot`): spread >2% = subtract 1, spread >5% = subtract 2. Wide spreads = illiquidity risk, higher slippage on entry/exit
- **Geographic concentration** (from `getRevenueGeographicSegmentation`): single non-US country >60% of revenue = subtract 1, >80% = subtract 2. Geopolitical/regulatory risk
- **Corporate actions** (from `get_corporate_actions`): upcoming reverse split or delisting risk = subtract 2. Upcoming regular dividend = no change
- Minimum Risk score after modifiers: 1

### Composite Weights
| Dimension | Weight | Rationale |
|-----------|--------|-----------|
| Technical | 22% | Primary trading signal |
| Fundamental | 15% | Quality filter |
| Valuation | 15% | Entry price matters |
| Smart Money | 13% | Institutional edge |
| Risk | 12% | High weight so max-risk stocks lose up to 10.8 pts (prevents buying into blowups) |
| Backtest | 10% | Historical validation |
| Sentiment | 7% | Noisy but additive |
| Macro | 6% | Environmental context |

**Why Risk at 12% (up from 5%):** At 5% weight, a maximum-risk stock (score=1) only penalizes the composite by 4.5 points — easily drowned out by a bullish Technical score. At 12%, a Risk=1 stock loses 10.8 points from composite, making it very hard for a dangerous stock to score above HOLD. This prevents the system from recommending BUY on a stock with extreme volatility, RSI >80, IV spike, and earnings tomorrow.

### Crypto Weight Redistribution
When asset type = Crypto, 3 dimensions are dropped (Fundamental, Valuation, Macro = 36%). Redistribute to remaining 5:
| Dimension | Stock Weight | Crypto Weight | Rationale |
|-----------|-------------|---------------|-----------|
| Technical | 22% | 35% | Primary signal for crypto |
| Smart Money | 13% | 25% | Volume patterns, exchange flows, whale activity (from smart_volume_scanner) |
| Risk | 12% | 20% | Crypto is inherently volatile — risk management critical |
| Backtest | 10% | 12% | Strategy validation still applies |
| Sentiment | 7% | 8% | Reddit/Twitter sentiment particularly influential for crypto |
| **Total** | 64% → 100% | 100% | |

**Crypto Smart Money signals:** Since insider/congressional/institutional signals don't exist for crypto, use: (1) exchange volume (smart_volume_scanner), (2) options flow if available, (3) WebSearch for whale wallet movements, (4) funding rate from exchange data.

### Technical Score Direction Clarification
**All Technical scores are DIRECTIONAL relative to LONG positions** (buying). A perfectly bearish setup (all TFs bearish, RSI extreme low, MACD deeply negative) scores **1-2** because it's terrible for buying. The Technical score answers: "How good is this stock to BUY right now?" not "How strong is the trend?"

### Overrides (applied AFTER composite calculation, in this order)

#### 1. Overbought/Oversold Override (GRADUATED, not binary)
- RSI 75-80: **subtract 5** from composite, append "⚠ OVERBOUGHT — RSI {value}. Timing risk elevated."
- RSI 80-85: **subtract 10** from composite, append "⚠ OVERBOUGHT — RSI {value}. Strong timing risk, consider waiting for pullback."
- RSI > 85: **cap composite at 55**, append "⚠ EXTREME OVERBOUGHT — RSI {value}. Do not enter new position."
- RSI 20-25: **add 5** to composite (only for LONG analysis), append "⚠ OVERSOLD — RSI {value}. Potential snap-back."
- RSI < 20: **add 10** to composite (only for LONG analysis), append "⚠ EXTREME OVERSOLD — RSI {value}. High snap-back probability."
- **Oversold does NOT prevent SELL for existing positions.** A stock can be oversold AND still deserve to be sold if fundamentals are deteriorating.
- **Why graduated:** Binary cap at 55 created a permanent HOLD trap for momentum stocks. Strong trends routinely hold RSI 75-80 for weeks. Graduated penalty allows BUY with a timing warning instead of blanket HOLD.

#### 2. VIX Panic Override (beta-conditional)
- If VIX > 35 AND **beta > 1.0** AND composite ≥ 60: Downgrade to **HOLD**, append "⚠ VIX PANIC ({value}) — market-wide fear is extreme for high-beta stocks."
- If VIX > 35 AND **beta ≤ 1.0**: Append warning only (no score change): "VIX elevated at {value}, but low beta ({beta}) provides relative protection."
- **Why beta-conditional:** Low-beta defensives (JNJ, KO, PG) typically outperform during panics. Forcing HOLD on a beta-0.3 stock during VIX 40 penalizes the exact stocks that benefit from flight-to-safety.

#### 3. Cross-Dimension Conflict Resolution
- If Technical and Fundamental scores diverge by **>5 points** (was 4 — too aggressive): Append "⚠ CONFLICT: Technical ({X}) vs Fundamental ({Y}) diverge" + **subtract 3** from composite. Do NOT force HOLD — momentum trades (Tech 9, Fund 4) and value plays (Tech 3, Fund 8) are both valid strategies.
- If Risk score ≤ 2 AND composite ≥ 60: Downgrade to **HOLD**, append "HIGH RISK OVERRIDE: Score warrants BUY but risk is extreme."
- If data completeness < 60%: Force **HOLD**, append "LOW DATA: Only {X}% of analysis phases returned data."
- If fewer than 5 of 8 dimensions are scored: Force **HOLD**, append "INSUFFICIENT DIMENSIONS: Only {X}/8 scored."

### Decision Thresholds
| Composite | Signal | Action |
|-----------|--------|--------|
| >= 75 | **STRONG BUY** | Aggressive sizing (up to 2× normal) |
| 60-74 | **BUY** | Standard sizing |
| 40-59 | **HOLD** | Also forced by: overrides above |
| 25-39 | **SELL** | Reduce/exit position |
| < 25 | **STRONG SELL** | Exit immediately |

---

## Error Handling Protocol (`_shared/error-handling.md`)

For EVERY MCP tool call:
1. If tool returns error/404/402 → Log "Phase X: [tool] unavailable — [reason]", set component to N/A, continue
2. If tool returns empty array [] → Log "Phase X: No [data type] for SYMBOL", set component to N/A, continue
3. If tool returns oversized response (>50KB) → Summarize key metrics only, do not paste raw
4. **Always called tools that commonly return empty (this is normal, not an error):**
   - getSenateTrades → empty for most stocks
   - getHouseTrades → empty for most stocks
   - get_option_chain → empty for small-caps/OTC
   - getPositionsSummary → empty for micro-caps
5. Track data completeness: successful_with_data / total_attempted
6. If data completeness <60% → Force HOLD, add "Low data confidence" warning
7. Display completeness % in output

---

## Asset Type Routing (`_shared/asset-classifier.md`)

| Asset Type | Detection | Phase Modifications |
|-----------|-----------|---------------------|
| **Stock** (default) | Standard ticker on major exchange | All 16 phases, all tools |
| **Crypto** | Symbol ends in USDT/USD + crypto pattern | Phase 1: getCryptocurrencyQuote. Skip Phases 2, 7, 8, 9(DCF), 12, 13. Reduce to 5 scoring dimensions (Tech, Sentiment, Smart Money via volume, Backtest, Risk) |
| **ETF** | `companyProfile.isEtf=true` | Phase 7: getFundHoldings + getFundSectorWeighting + getFundInfo. Skip 8, 12, 13. Phase 9: skip DCF |
| **ADR** | `companyProfile.isAdr=true` or `country != US` | Add FX risk to Phase 15. All other phases run normally |
| **OTC** | Exchange = OTC/Pink Sheets | Warn: limited data. Block /trade. All phases still called — handle empty responses per error protocol |

---

## FMP Tier-Aware Degradation (`/scan` mode)

**Problem:** FMP free tier returns 402 (Payment Required) on most endpoints for small-cap, OTC, and some non-US stocks. Only `getCompanyProfile` and `getBatchQuotes` work universally.

**Detection:** If `getCompanyProfile` returns but `getFinancialRatiosTTM` returns 402 → stock is outside FMP's free tier coverage.

### Tiered Scan Strategy
| Tier | Detection | FMP Calls Available | Scoring |
|------|-----------|--------------------|---------| 
| **Full** | All 6 scan calls return data | getCompanyProfile + getFinancialRatiosTTM + getFinancialScores + getDCFValuation + getPriceTargetSummary + getStockPriceChange | Full 8-dimension quick score |
| **Partial** | Some calls 402 | getCompanyProfile + getBatchQuotes + whichever calls work | Score available dimensions, mark others N/A, note "Partial data" |
| **Minimal** | Most calls 402 (OTC, micro-cap) | getCompanyProfile + getBatchQuotes only | Technical-only score from TV-Analysis. Fundamental/Valuation = N/A. Rank separately with disclaimer |

### Implementation
1. For each stock in scan, fire all 6 FMP calls in parallel
2. Collect results. Any 402 → mark that dimension as N/A
3. Score only dimensions with data. Normalize: composite = weighted_sum / sum_of_available_weights × 100
4. In output table, add "Coverage" column: Full / Partial / Minimal
5. Sort by composite but group by coverage tier (Full-tier stocks ranked above Partial)

### Affected Watchlist Stocks (known)
From the 16-stock watchlist: ALMU, KLTR, FLTCF likely Minimal tier (OTC/micro-cap). Others likely Full tier. Confirm during first scan run.

---

## Output Formats (`_shared/output-formats.md`)

### Default: Compact Card
```
═══ AMD Analysis ═══ 2026-05-03 ═══ Score: 72/100 ═══
Market OPEN — live data | VIX: 18.2 (normal)
BUY (High Confidence) | Data: 94% complete | Growth Stock (Track B)

Tech: 9/10 | Fund: 8/10 | Val: 8/10 (PEG 0.6) | Sent: 7/10
Smart$: 6/10 | Macro: 7/10 | BT: 7/10 | Risk: 4/10

Valuation: PEG 0.6 (P/E 50 ÷ 80% growth) — deep value for growth rate
         DCF range: $57 (standard) / $72 (levered) / $145 (custom)
         Analyst consensus: $180 (+12%) from 25 analysts (σ=$22)
         Earnings: Beats 7/8 quarters (avg +8.3% surprise)

Sentiment: Reddit bullish (68%) | Twitter mixed | StockTwits 72% bulls
          News NLP: 3 positive, 1 neutral, 1 negative (supply chain)
          Analyst: 2 upgrades, 0 downgrades last 30d

Options: P/C Vol 0.65 (bullish) | IV/HV 1.4 | Expected Move ±$12 (±7.5%)
        Max Pain: $155 | Unusual: 500 calls @ $180 strike (8x OI)
        Net Delta: +12,400 (market positioned long)

Best Strategy: MACD Crossover (40% return, 5.49 Sharpe, 23 trades)
  Desktop cross-validation: 38% return (✓ within 20% — consistent)
Entry: $160 (current) | Stop: $142 (-11%) | TP: $190 (+19%)
  Bid/Ask spread: $0.02 (tight — good liquidity)
Position: 84 shares / $13,440 (13.4% of $100K account)

⚠ OVERBOUGHT — RSI 80. Timing risk elevated, wait for pullback.
Top Risks: RSI 80 | Beta 1.7 | IV/HV 1.4 (elevated) | Earnings May 15
Top Catalysts: DC revenue +80% YoY | 3 senators buying | Piotroski 7/9
Corporate: No splits/dividends/mergers within 30d
Delta: N/A (first analysis)
═══════════════════════════════════════════════════════
```

### Full Mode (--full)
Complete 16-phase detailed report with all data tables, charts, and reasoning.

### Market Hours Header (from `Alpaca: get_clock`)
- If `is_open=true`: "Market OPEN — live data | VIX: {value} ({label})"
- If `is_open=false`: "Market CLOSED (opens {next_open}) — data reflects last close. Volume/options data may be stale. | VIX: {value} ({label})"
- VIX label: <15 = "calm", 15-20 = "normal", 20-25 = "elevated", 25-30 = "fear", >30 = "PANIC"

---

## Additional Commands

### `/project:scan [watchlist | AAPL,MSFT,... | discover]`

**Watchlist mode** (default) — per stock (~6 FMP + 2 TV-Analysis = 8 calls):
`getCompanyProfile` + `getStockPriceChange` + `getFinancialRatiosTTM` + `getFinancialScores` + `getDCFValuation` + `getPriceTargetSummary` + `coin_analysis` + `compare_strategies`

**Discovery mode** (`/project:scan discover`) — find NEW stocks:
- `FMP: stockScreener` (marketCapMoreThan=1B, volumeMoreThan=500000, sector=Technology, betaLessThan=2.5) — **multi-factor screening in ONE call**
- Filter by: sector, market cap range, volume, beta, price, exchange, country
- Returns ranked list → run watchlist-mode analysis on top 10
- Enables finding stocks you don't already know about

**Batch optimization** (if TradingView Desktop is running):
- `TV: batch_run` (symbols=watchlist, action="screenshot") — screenshot all 16 charts in ONE call instead of 16 individual calls

Default watchlist: ALMU, AMD, CRDO, FIX, ASX, KLTR, FLTCF, NVT, CDNS, AMPX, BBAI, LAW, SATS, GEV, BE, KGS

Output: Ranked table sorted by quick composite score. Offer deep-dive on top picks.

### `/project:portfolio`
- `Alpaca: get_account_info` + `get_all_positions` + `get_portfolio_history`(1M) + `get_orders`(closed, 20)
- `Alpaca: get_account_activities` (limit=20) — **fill execution prices, dividend income, interest, fees**. Essential for true P&L attribution (not just market value change)
- `Alpaca: get_corporate_actions` — **check for upcoming splits/dividends/mergers** on held positions
- Per position: `FMP: getQuote` + `TV-Analysis: coin_analysis`
- `FMP: getEarningsCalendar` (next 14d) cross-referenced with positions
- Flags: concentration risk, overbought positions, upcoming earnings, extended positions, **upcoming corporate actions, wide bid/ask spreads (liquidity risk)**

### `/project:trade [buy|sell] SYMBOL [amount]`
5 calls, <10 seconds:
- `FMP: getQuote` + `TV-Analysis: coin_analysis`(1D) + `Alpaca: get_account_info` + `get_all_positions` + `get_open_position`
- Safety blocks: signal contradicts direction, position >20% portfolio, OTC stock, buying power <$100
- Execute: `Alpaca: place_stock_order` (only after user confirmation)

### `/project:morning-brief`
~32 calls total:
- `Alpaca: get_clock` — market status + hours
- `FMP: getIndexQuote` ("^VIX") — fear gauge (cached)
- `TV-Analysis: market_snapshot` — **Global market overview**: S&P, NASDAQ, Dow, BTC, EUR/USD, key ETFs. Answers "how is the overall market doing?" before diving into individual stocks
- `TV-Analysis: top_gainers` + `top_losers` + `volume_breakout_scanner` + `bollinger_scan` + `financial_news`
- `Alpaca: get_account_info` + `get_all_positions` + `get_portfolio_history`(1W)
- `FMP: getBatchAftermarketQuote` (watchlist symbols) — **after-hours/pre-market prices**. Earnings are released AH. A stock up 8% on earnings is invisible without this. Critical for morning briefing
- `FMP: getBatchQuotes` (watchlist, batched) + `getEarningsCalendar`(7d)
- `Alpaca: get_corporate_actions` — splits/dividends this week across portfolio
- Flag >3% movers, earnings this week, portfolio alerts, top scanner picks, **VIX level, after-hours moves, corporate actions**

### `/project:research SYMBOL`
Web-augmented deep dive:
- `WebSearch` "SYMBOL stock analysis 2026" + "SYMBOL StockTwits" + "SYMBOL institutional flow"
- `WebFetch` top results for full-text NLP
- `FMP: getStockNews` → `WebFetch` article URLs for full content analysis
- `FMP: getPressReleases` for company announcements
- `FMP: searchMergersAcquisitions` (company name)
- `FMP: getEarningsTranscript` → Claude NLP for tone, forward guidance, risk language
- `FMP: getFilingExtractAnalyticsByHolder` → detailed fund-by-fund institutional analysis
- `FMP: getRevenueGeographicSegmentation` → geographic risk assessment
- Assess: competitive moat, supply chain risks, social sentiment beyond Reddit

### `/project:compare SYMBOL1 SYMBOL2`
Runs condensed analysis on each symbol in parallel:
- Side-by-side comparison table (all 8 dimensions)
- Winner per metric highlighted
- Overall recommendation: which is the better buy and why

---

## Implementation Order

| Step | File | Description |
|------|------|-------------|
| 1 | `.claude/commands/_shared/scoring-rubrics.md` | Scoring thresholds — blocks everything |
| 2 | `.claude/commands/_shared/asset-classifier.md` | Asset type detection |
| 3 | `.claude/commands/_shared/error-handling.md` | Error handling protocol |
| 4 | `.claude/commands/_shared/output-formats.md` | Output templates |
| 5 | `.claude/commands/analyze-technical.md` | Phases 0, 1, 3, 4, 5, 6 |
| 6 | `.claude/commands/analyze-fundamental.md` | Phases 2, 7, 8, 9 |
| 7 | `.claude/commands/analyze-sentiment.md` | Phases 10, 11, 12, 13, 14 |
| 8 | `.claude/commands/synthesize.md` | Phases 15, 16 + scoring + output |
| 9 | `.claude/commands/analyze.md` | Orchestrator: runs steps 5-8 in sequence |
| 10 | `.claude/commands/scan.md` | Watchlist scanner |
| 11 | `.claude/commands/portfolio.md` | Portfolio dashboard |
| 12 | `.claude/commands/trade.md` | Paper trading with safety |
| 13 | `.claude/commands/morning-brief.md` | Daily briefing |
| 14 | `.claude/commands/research.md` | Deep web research |
| 15 | `.claude/commands/compare.md` | Side-by-side comparison |

---

## Verification Plan

1. Command registration: `/project:analyze` etc. appear in Claude Code
2. `/project:analyze-technical AMD`: ~14-22 calls, saves to reports/, verify get_clock + get_stock_snapshot + depth_get + draw_shape + alert_create
3. `/project:analyze-fundamental AMD`: ~26 calls, verify VIX + custom DCF + levered DCF + earnings reports + grade news + price target summary + geo seg + hist mkt cap
4. `/project:analyze-sentiment AMD`: ~24-30 calls, verify WebSearch Twitter/StockTwits + WebFetch news articles + corporate actions + Desktop cross-validation
5. `/project:synthesize AMD`: reads phase files, scores 8 dimensions, compact card with VIX + earnings history + sentiment platforms + DCF range
6. `/project:analyze AMD`: orchestrator runs all 4 sub-commands
7. `/project:scan watchlist`: 16 stocks, ranked table, budget displayed
8. `/project:scan discover`: stockScreener finds new stocks, runs analysis on top 10
9. `/project:portfolio`: Alpaca data + earnings + corporate actions + account activities
10. `/project:trade buy AMD 1000`: safety checks + confirmation
11. `/project:morning-brief`: verify VIX + market_snapshot + after-hours quotes + corporate actions
12. `/project:compare AMD NVDA`: side-by-side output
13. Edge cases: crypto (BTCUSDT), ETF (SPY), OTC (FLTCF), no-options (BBAI)
14. Error handling: invalid ticker, FMP rate limit, Desktop unavailable (graceful skip of draw/depth/alert/strategy)
15. Persistence: reports/ created, scores.csv appended, delta on re-analysis
16. Market hours: correct header from get_clock, VIX label shown
17. Overrides: verify VIX panic override (>35), overbought RSI cap, cross-dimension conflict
18. Budget: verify daily total stays within 250 FMP calls

---

## Verified Tool Inventory

| MCP Server | Calls Used | Status |
|------------|-----------|--------|
| **FMP** | 33-34 per analyze | Removed 3 broken: getEconomicIndicators(404), getAnalystEstimates(402), getSectorPerformanceSnapshot(empty). New in v5: getIndexQuote(VIX), getHistoricalMarketCap, getRevenueGeographicSegmentation, getLeveredDCFValuation, calculateCustomDCF, getMarketRiskPremium, getPriceTargetSummary, getStockGradeNews, getEarningsReports, getBatchAftermarketQuote, stockScreener |
| **TV-Analysis** | 7-9 per analyze | All tested pass. Excluded volume_confirmation_analysis (buggy for stocks). New in v5: market_snapshot (morning-brief) |
| **TradingView Desktop** | 0-13 per analyze | Auto-launch. Use FULL indicator names. Graceful skip if unavailable. New in v5: depth_get (order book), draw_shape (chart annotations), alert_create (price alerts), data_get_strategy_results + data_get_equity (backtest cross-validation), batch_run (/scan optimization) |
| **Alpaca** | 8 per analyze | New in v5: get_clock (market hours), get_stock_snapshot (bid/ask spread), get_corporate_actions (splits/dividends), get_account_activities (/portfolio) |
| **WebSearch/WebFetch** | 5-6 per analyze | **Now in main /analyze pipeline** (not just /research). WebSearch: Twitter/X + StockTwits + estimate revisions. WebFetch: full-text NLP on top news articles |
| **Total per /analyze** | **~55-73 tool calls** | Desktop-off: ~55. Desktop-on: ~73. Across 4 phase groups in single conversation |
