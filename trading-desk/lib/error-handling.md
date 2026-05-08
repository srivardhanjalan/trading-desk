# Error Handling Protocol

Apply to EVERY MCP tool call across all phases.

**See also:** `${CLAUDE_PLUGIN_ROOT}/lib/no-skip-policy.md` — errors must be LOGGED, never silently skipped. Every step must end as COMPLETED, FAILED (with reason), or N/A (with asset-type justification).

---

## Per-Call Error Handling

1. **Tool returns error/404/402:** Log `Phase X: [tool] unavailable — [reason]`. Set component to N/A. Continue to next tool.
2. **Tool returns empty array []:** Log `Phase X: No [data type] for SYMBOL`. Set component to N/A. Continue.
3. **Tool returns oversized response (>50KB):** Summarize key metrics only, do not paste raw response into report.
4. **Tool timeout:** Log timeout, set to N/A, continue.

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
