# Error Handling Protocol

Apply to EVERY MCP tool call across all phases.

**See also:** `${CLAUDE_PLUGIN_ROOT}/lib/no-skip-policy.md` — errors must be LOGGED, never silently skipped. Every step must end as COMPLETED, FAILED (with reason), or N/A (with asset-type justification).

---

## Per-Call Error Handling

1. **Tool returns 402 / 401 / 403 (paywall / auth):** **DO NOT mark N/A immediately.** Log `Phase X: [tool] returned {status} — running fallback chain`, then consult the "Free-Tier Fallback Chains for Paywalled FMP Endpoints" table below. Only mark N/A after the FMP call AND every documented fallback have failed. On fallback success, manifest status is `OK (fallback)`.
2. **Tool returns 404 / generic error / malformed response:** Log `Phase X: [tool] unavailable — [reason]`. Set component to N/A. Continue to next tool.
3. **Tool returns empty array []:** Log `Phase X: No [data type] for SYMBOL`. NOT a failure — manifest status `EMPTY`. Continue.
4. **Tool returns oversized response (>50KB):** Summarize key metrics only, do not paste raw response into report.
5. **Tool timeout:** Log timeout, set to N/A, continue.
6. **Tool returns 429 (rate limit):** NOT a paywall — apply rate-limit handling (see "FMP Rate Limit Handling" below).

---

## Tools That Commonly Return Empty (Normal, Not Errors)

These tools return empty for most stocks — this is expected:
- `getSenateTrades` — only populated for stocks traded by senators
- `getHouseTrades` — only populated for stocks traded by House members
- `get_option_chain` — empty for small-caps, OTC, newly listed
- `getPositionsSummary` — empty for micro-caps
- `searchInsiderTrades` — empty for some small-caps
- `get_corporate_actions` — empty when no upcoming events

Do NOT treat empty responses as failures. Log as "No [data type] for SYMBOL" and continue.

---

## Bulk/Exchange-Wide API Post-Filter Protocol

**ALL bulk or exchange-wide API calls MUST include an explicit post-filter step for the target symbol.** This applies to:
- `smart_volume_scanner`, `advanced_candle_pattern` — scan entire exchange
- `getEarningsCalendar` — returns ALL companies' earnings (no symbol filter)
- `getEarningsSurprisesBulk` — returns bulk surprise data by year
- `getSectorPerformanceSnapshot` — sector-level, not symbol-level
- Any other API that returns data for multiple symbols

**Post-filter steps (MANDATORY):**
1. Search the response for the target symbol (exact match, case-insensitive)
2. If found: extract ONLY that symbol's data, discard the rest
3. If not found: note "No [data type] detected for SYMBOL" — this is neutral, not negative
4. **Never report unfiltered bulk data as if it were symbol-specific**

---

## Data Completeness Tracking

Track completeness at the **individual API call level**, not phase level.

**API Call Manifest (REQUIRED in every report):**
Each report must include a call manifest table at the end:

```
## API Call Manifest
| # | Tool | Status | Notes |
|---|------|--------|-------|
| 1 | getCompanyProfile | OK | |
| 2 | getTreasuryRates | OK | cached |
| 3 | getOptionChain (calls) | OK | 47 contracts |
| 4 | getOptionChain (puts) | EMPTY | No puts available |
| 5 | getFinancialRatiosTTM | 402 | Outside FMP tier |
...
Data Completeness: {successful_calls}/{total_calls} = {X}%
```

**Completeness = successful_calls / total_calls** (not phase-level approximation).

- Display completeness % in output
- If data completeness < 60%: Force HOLD, add "Low data confidence" warning
- If fewer than 5 of 8 dimensions are scored: Force HOLD, add "INSUFFICIENT DIMENSIONS"

---

## WebSearch Ticker Validation

**Short tickers (1-2 characters)** are ambiguous in web searches (e.g., "BE stock" returns unrelated results, "AI stock" returns general AI articles). For tickers with 1-2 characters:
- ALWAYS include the full company name in WebSearch queries: `"{COMPANY_NAME}" ({SYMBOL}) stock {query_terms}`
- Example: `"C3.ai" (AI) stock earnings 2026` instead of `AI stock earnings 2026`
- Example: `"Bloom Energy" (BE) stock short interest` instead of `BE stock short interest`

---

## FMP Rate Limit Handling

If multiple consecutive FMP calls return 429 (rate limit):
1. Note "FMP rate limit reached" in output
2. Score only dimensions with data collected so far
3. Normalize composite: weighted_sum / sum_of_available_weights x 100
4. Force HOLD if <60% data completeness

---

## FMP Session Error Recovery

If any FMP call returns `"Session not found or expired"`:
1. **Do NOT silently skip the call** — this is a recoverable error
2. Wait 2 seconds, then retry the same call once
3. If retry succeeds: proceed normally
4. If retry fails: log as `[FAILED] {tool}: Session error after retry`
5. **Known race-condition tools** (must be called sequentially, NOT in parallel batches):
   - `getFinancialStatementFullAsReported` — XBRL SEC filing data
   - `calculateCustomDCF` — when running multiple scenarios back-to-back
6. If session errors persist across 3+ consecutive calls: the FMP MCP server may need restarting. Note: "FMP SESSION: Multiple failures. Server may need restart."

---

## TradingView Desktop Unavailability

If `tv_health_check` fails or `tv_launch` fails:
1. Log "Chart: Desktop unavailable"
2. Skip all TV Desktop calls (Phase 6 chart, Phase 14 cross-validation, Phase 16b annotations)
3. All technical data still available from TV-Analysis (Phase 3)
4. All other phases unaffected
5. Note "Desktop unavailable — no chart screenshot or cross-validation" in output

---

## FMP Tier-Aware Degradation (for /scan)

| Tier | Detection | Available | Scoring |
|------|-----------|-----------|---------|
| Full | All 6 scan calls return data | All dimensions | Full 8-dimension quick score |
| Partial | Some calls 402 | Available dimensions only | Score what's available, mark rest N/A |
| Minimal | Most calls 402 (OTC, micro-cap) | getCompanyProfile + getBatchQuotes only | Technical-only from TV-Analysis. Rank separately with disclaimer |

Detection: If `getCompanyProfile` works but `getFinancialRatiosTTM` returns 402, stock is outside FMP free tier.

**Scope note:** This tier-aware degradation applies ONLY to `/scan` (high-throughput screening across many tickers, where the wall-clock cost of running fallback chains for every paywalled endpoint × every ticker is prohibitive). For `/analyze`, `/analyze-technical`, `/analyze-fundamental`, `/analyze-sentiment` — which run on a single ticker — the **Free-Tier Fallback Chains** section below overrides this table. Do NOT silently mark fields N/A in single-ticker analysis without first running the documented primary fallback.

---

## Free-Tier Fallback Chains for Paywalled FMP Endpoints

**Critical rules:**
1. **Probe each paywalled endpoint at least once per `claude` session.** Never pre-skip based on a prior CLI session's 402 — FMP rotates tiers and the user may have upgraded.
2. **Within a session, cache the 402 result and skip future probes for the same endpoint.** First analysis in a fresh `claude` session calls FMP for every paywalled endpoint. If endpoint X returns 402, record `X=paywalled` in session memory; subsequent analyses **in the same session** call the fallback chain directly without re-probing FMP. New `claude` session = re-probe. (This is consistent with rule #1: "always attempt FMP first within a session" means once-per-session, not once-per-analysis.) Cost: ~17 wasted FMP calls on the first analysis, zero on subsequent analyses in the same session.
3. **Only fall back on an actual 402 response (or 401/403).** Empty `[]` is NOT a paywall — log per "Tools That Commonly Return Empty" rule. **429 (rate limit) is NOT a paywall** — apply rate-limit handling instead.
4. **Run the fallback chain when 402 is hit.** Don't mark N/A until the FMP call AND every fallback in the chain have failed.
5. **Log the chain.** Every paywall fallback gets logged: `[FALLBACK] {endpoint}: FMP 402 → {primary} {status} → {secondary if needed}`.

### Endpoint → Fallback table

URL patterns marked **(verified)** were actually fetched and confirmed live during table compilation. URL patterns marked **(unverified)** are pattern guesses — try them but expect occasional 404; cascade to the next entry.

| Paywalled FMP endpoint | Primary fallback | Secondary | Tertiary | Notes |
|---|---|---|---|---|
| `getCommodityQuotes` | TV Desktop `quote_get` for `TVC:GOLD`, `TVC:USOIL`, `TVC:COPPER`, `TVC:DXY`, `TVC:NATGAS` (works only when TV Desktop is running) | WebFetch `https://finance.yahoo.com/quote/GC%3DF/` (gold futures), `CL%3DF` (oil), `HG%3DF` (copper) — note `=` URL-encoded as `%3D`. Yahoo intermittently 401s scrapers; retry once on failure. | WebSearch `"gold price today"` / `"WTI crude oil price"` and parse top result | EIA.gov requires a registered API key (free) — only worth wiring up if you'll automate it. For ad-hoc, WebSearch is fastest. |
| `getEconomicIndicators` (CPI, GDP, jobless claims, PCE) | WebFetch the FRED **website** (HTML page, no key required): `https://fred.stlouisfed.org/series/{CODE}` — codes: `CPIAUCSL` (CPI), `GDP`, `ICSA` (initial jobless), `PCEPI` (PCE), `UNRATE` (unemployment). The page renders the latest value + chart. | WebFetch BLS news release: `https://www.bls.gov/news.release/cpi.htm` (CPI), `empsit.htm` (jobs) | WebSearch `"latest CPI release {YYYY-MM}"` + WebFetch top result | **Note:** FRED's JSON API (`api.stlouisfed.org`) requires a registered key as of Nov 2025 — `api_key=` (empty) returns 403. Use the website HTML instead. |
| `getCOTAnalysis` / `getCOTReports` | WebFetch CFTC public reporting: `https://publicreporting.cftc.gov/stats/stats.html` — modern (Oct 2022+) source for COT-style stats | WebFetch CFTC archives index: `https://www.cftc.gov/MarketReports/CommitmentsofTraders/HistoricalCompressed/index.htm` (zip files; agent can read filenames but downloading + unzipping is heavy) | WebSearch `"COT report {ticker} {YYYY}"` + WebFetch top result | Released Friday 3:30 PM ET. The `deafut.txt` static-file pattern previously listed was fabricated — do not use. |
| `getIncomeStatementTTM` / `getBalanceSheetStatementTTM` / `getCashFlowStatementTTM` | WebFetch `https://stockanalysis.com/stocks/{symbol}/financials/?p=trailing` — this page has TTM revenue/EBIT/EPS/FCF as a clean table. **Use this as PRIMARY** because FMP free tier paywalls *both* TTM and quarterly statements. | If on a paid FMP tier where quarterly is unlocked: `getIncomeStatement(period=quarter, limit=8)` then sum the most recent 4 quarters | WebFetch `https://www.macrotrends.net/stocks/charts/{symbol}/{slug}/{metric}` | The "compute from quarterly" approach only works on Starter+ tiers. On Basic, both endpoints fail; stockanalysis.com is the actual fallback. |
| `getAnalystEstimates` (forward EPS / revenue) | WebFetch `https://stockanalysis.com/stocks/{symbol}/forecast/` — clean tables of EPS estimates, revenue estimates, # of analysts (verified live) | WebFetch `https://www.tipranks.com/stocks/{symbol}/forecast` | WebFetch `https://finance.yahoo.com/quote/{SYMBOL}/analysis` (last resort — Yahoo intermittently 401s) | `getPriceTargetSummary` and `getPriceTargetConsensus` are usually free-tier — use those for price targets even when `getAnalystEstimates` is paywalled. |
| `getEarningsSurprisesBulk` | `getEarningsReports` per-symbol (usually free-tier) gives surprise % per quarter | WebFetch `https://www.zacks.com/stock/research/{symbol}/earnings-announcements` | WebFetch `https://www.earningswhispers.com/epsdetails/{symbol}` (whisper numbers + actual) | Per-symbol calls cost more but cover the same ground |
| `getBatchQuotes` (multi-symbol quotes in one call) | Alpaca `mcp__plugin_trading-desk_alpaca__get_stock_latest_quote` per symbol (already on plugin) | TV-Analysis `yahoo_price` per symbol | — | Alpaca is fastest. For 5 peer symbols, 5 parallel calls is fine. |
| `getPositionsSummary` (aggregate 13F) | WebFetch `https://stockzoa.com/ticker/{SYMBOL}/` (verified live — shows top institutional holders + share counts) | WebSearch `"{SYMBOL}" institutional holders 13F Q{N} {YEAR}` + WebFetch top result | — | The previously-listed `whalewisdom.com/stock/{slug}-shares-held` URL is 404 (do not use). holdingschannel.com 403s WebFetch. SEC EDGAR (`efts.sec.gov`) requires a custom User-Agent header that WebFetch can't send — also unreachable. |
| `getFilingExtractAnalyticsByHolder` (fund-by-fund detail) | WebFetch `https://stockzoa.com/ticker/{SYMBOL}/` — top holders + recent changes (verified) | WebSearch `"{SYMBOL}" 13F top buyers sellers Q{N} {YEAR}` + WebFetch first non-paywalled result | WebFetch `https://www.dataroma.com/m/stock.php?sym={SYMBOL}` (superinvestor cross-reference only) | Extract: top 3 buyers, top 3 sellers, new positions, closed positions, biggest weight delta. WhaleWisdom URL pattern was previously fabricated — do not use. |
| `getHolderPerformanceSummary` (fund-quality / alpha-grading) | WebFetch `https://www.dataroma.com/m/stock.php?sym={SYMBOL}` — shows which superinvestors hold this stock | WebSearch `"{SYMBOL}" hedge fund holders {YEAR}` | — | No clean free equivalent for full alpha-grading. Best output: "fund quality: {N} tracked-superinvestors hold (Buffett/Burry/etc.); aggregate alpha grading unavailable." |
| `getForm13FFilingDates` | Use the date column from the `getPositionsSummary` fallback (stockzoa.com) which already shows filing dates per holder | — | — | EDGAR endpoints are unreachable from WebFetch (403, missing User-Agent). Stockzoa shows the dates inline. |
| `getHolderIndustryBreakdown` | Compute heuristically from holder names returned by stockzoa.com (top 20): "passive (Vanguard/BlackRock/State Street/iShares)" / "active mutual fund" / "hedge fund" / "specialist". Mark with confidence caveat. | — | — | Approximation only — flag in output as "Holder Industry: heuristic estimate, no FMP-grade categorization." |
| `getPressReleases` / `searchPressReleases` | WebSearch `"{COMPANY_NAME}" press release {YYYY-MM}` + WebFetch top 3 results — handles slug ambiguity that breaks PRN/BusinessWire URL patterns | WebFetch the company's IR page from `getCompanyProfile.website` field (e.g. `{domain}/investors/news`) | SEC 8-K filings via `getFilingsBySymbol` (free-tier) — captures material releases | The PRN URL pattern (`prnewswire.com/news/{slug}`) is brittle — slugs vary (`apple` returns 2010 results, real slug is `apple-inc`). WebSearch handles this. |
| `getESGRatings` | WebFetch `https://finance.yahoo.com/quote/{SYMBOL}/sustainability` — sparse but free; intermittent 401 | WebSearch `"{COMPANY_NAME}" ESG rating MSCI` | — | Mark N/A is acceptable — ESG is informational, not part of any scoring dimension. **Stop the cascade after primary fails** — don't burn 3 fallbacks on a non-load-bearing dimension. |
| `getExecutiveCompensationBenchmark` | DEF 14A SEC filing via `getFilingsBySymbol` filtered for form type DEF 14A — exec comp is in the proxy statement | — | — | Specialty data, not part of scoring. **Stop after primary fails.** Mark N/A. |
| `getEarningsTranscript` (Phase 13) | WebSearch `"{COMPANY}" Q{N} {YEAR} earnings call transcript` + WebFetch top result (often Motley Fool, Seeking Alpha free articles) | WebFetch the company's IR page for transcript link | — | Transcripts are 50-100 KB — summarize key dimensions only (tone, guidance, themes), don't paste raw text |
| `getRevenueProductSegmentation` / `getRevenueGeographicSegmentation` | WebFetch `https://stockanalysis.com/stocks/{symbol}/financials/?p=segments` (when available) | Parse the most recent 10-K from `getFilingsBySymbol` (the segment footnote has revenue by product/region) | — | The 10-K parse is heavy but accurate; stockanalysis.com is faster and usually sufficient |
| `getDCFValuation` / `getLeveredDCFValuation` / `calculateCustomDCF` | **Compute manually.** All inputs are already in phase reports: FCF (cash flow statement), revenue growth (analyst estimates fallback), WACC (riskFreeRate from `getTreasuryRates` + beta from `getCompanyProfile` + 5% MRP fallback), terminal growth (3% default). Use the standard DCF formulas in `${CLAUDE_PLUGIN_ROOT}/lib/scoring-rubrics.md`. | WebFetch `https://stockanalysis.com/stocks/{symbol}/dcf/` for cross-check | — | DCF is load-bearing for Valuation scoring. Manual computation is mandatory if FMP DCF is paywalled — do NOT mark Valuation N/A. |
| `getOwnerEarnings` | Compute manually: `netIncome + D&A − maintenance_capex` from existing `getCashFlowStatement` (already FY-only on free tier). Approximate maintenance capex as 80% of total capex if not separately reported. | — | — | This is just arithmetic on data we already have. |
| `getHistoricalIndustryPE` / `getIndustryPESnapshot` / `getHistoricalSectorPE` | WebSearch `"{SECTOR}" sector P/E ratio {YYYY-MM}` + WebFetch top result (typically Yardeni Research or stockanalysis.com sector pages) | WebFetch `https://www.macrotrends.net/sectors/{sector}/{metric}` | — | Used for relative-valuation modifier in Valuation scoring; mark with confidence caveat if web-sourced. |
| `getMarketRiskPremium` | Hardcoded fallback: **5.0%** (long-run US equity risk premium per Damodaran 2024) | WebFetch `https://pages.stern.nyu.edu/~adamodar/New_Home_Page/datafile/ctryprem.html` (Damodaran's published table, updated annually) | — | Used in WACC calc. 5.0% is conservative; Damodaran's recent estimates are 4.5-5.5%. Hardcode is acceptable. |
| `getStandardDeviation` (Phase 10) | Compute from `mcp__plugin_trading-desk_alpaca__get_stock_bars` close-price returns: `stdev(daily returns over period) × sqrt(252)` for annualized HV | — | — | Use the same 30-day window (`periodLength=30`) for consistency with FMP output. |
| `getRSI` / `getSMA` / `getEMA` / `getADX` / `getDEMA` / `getTEMA` / `getWMA` / `getWilliams` (Phase 3) | Compute from `mcp__plugin_trading-desk_alpaca__get_stock_bars` close-price series. Standard formulas: RSI = 100−(100/(1+avg_gain/avg_loss)) over `periodLength`; SMA = mean over period; EMA = α·price + (1−α)·prev with α=2/(N+1). | TV Desktop `data_get_study_values` after adding the indicator via `chart_manage_indicator` (only when TV Desktop is running) | — | Indicators are usually free-tier on FMP — only fall back if 402. Use 200+ bars for warm-up to stabilize EMAs. |
| `getShareFloat` | WebFetch `https://stockanalysis.com/stocks/{symbol}/statistics/` (shows shares outstanding + float) | WebFetch `https://finance.yahoo.com/quote/{SYMBOL}/key-statistics` | — | Used for unusual-volume normalization. |
| `getFinancialStatementFullAsReported` (XBRL) | — | — | — | No good free fallback (raw XBRL parsing from EDGAR is heavy and EDGAR is WebFetch-blocked). Mark N/A is honest. |

### Coverage cap-off rule (latency control)

Cascading through 3 fallbacks for non-load-bearing data wastes wall-clock time. **Stop after PRIMARY for these (mark N/A if primary fails):**
- `getESGRatings`
- `getExecutiveCompensationBenchmark`
- `getHistoricalIndustryPE` / sector-PE family

For everything else (load-bearing dimensions: DCF, fundamentals, sentiment, institutional), cascade fully.

### Implementation pattern

```
1. Attempt FMP call.
2. If response status is 402 / 401 / 403:
   a. Log: "[FALLBACK] {endpoint}: FMP {status}, trying {primary}"
   b. Run primary fallback. If primary succeeds: log "[FALLBACK OK] {endpoint} → {primary}"
   c. If primary fails AND endpoint is in cap-off list: mark N/A. Stop.
   d. If primary fails AND endpoint cascades: try secondary, then tertiary in same way.
   e. If all fail: mark "{endpoint}: N/A (FMP paywall + all fallbacks failed)"
3. If response is empty []: NOT a paywall — log per empty-response rules.
4. If 429 (rate limit): NOT a paywall — apply rate-limit handling.
```

### Public-source rate-limit etiquette

WebFetch is sequential per call (no real burst risk), but if a phase calls multiple WebFetches against the same host (e.g., 4 stockzoa.com calls for the 13F suite), insert a 1-2s gap between them or batch into a single combined fetch. Public scrapers like stockzoa.com / stockanalysis.com tolerate ~10 req/min from anonymous clients before rate-limiting.

### Manifest status taxonomy (used in completeness calc)

The Call Manifest in every report uses these exact status strings — the data-completeness calculation depends on the spelling matching:

| Status string | Counts toward | Meaning |
|---|---|---|
| `OK` | numerator (success) | FMP returned data |
| `OK (fallback)` | numerator (success) | FMP failed, fallback succeeded |
| `EMPTY` | excluded from both | Tool returned `[]` — normal no-data condition |
| `402` | denominator only (fail) | Paywalled, no fallback succeeded |
| `FAILED` | denominator only (fail) | Tool errored (timeout, malformed response, etc.) |
| `N/A` | excluded from both | Step doesn't apply to this asset (e.g. fundamentals on crypto) |

**Data Completeness % = `count(OK) + count(OK (fallback))` / `(count(OK) + count(OK (fallback)) + count(402) + count(FAILED))` × 100.**

EMPTY and N/A are excluded — they're neutral, not failures.

Example manifest snippet:
```
| 12 | getPressReleases             | OK (fallback) | FMP 402 → WebSearch + 8-K (3 hits)  |
| 13 | getEconomicIndicators        | OK (fallback) | FMP 402 → fred.stlouisfed.org HTML  |
| 14 | getESGRatings                | N/A           | FMP 402 → Yahoo sparse → cap-off    |
| 15 | getCommodityQuotes           | OK (fallback) | FMP 402 → TV Desktop quote_get      |
| 16 | getDCFValuation              | OK (fallback) | FMP 402 → manual WACC computation   |
```
