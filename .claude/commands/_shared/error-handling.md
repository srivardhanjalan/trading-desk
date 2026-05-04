# Error Handling Protocol

Apply to EVERY MCP tool call across all phases.

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

## Exchange-Wide Scanner Post-Filtering

`smart_volume_scanner` and `advanced_candle_pattern` scan the entire exchange, not per-symbol. After receiving results:
1. Search the response for the target symbol
2. If found: extract and report that symbol's data
3. If not found: note "No unusual volume/pattern detected for SYMBOL" — this is neutral, not negative

---

## Data Completeness Tracking

Track: `successful_with_data / total_attempted` for each phase group.

- Display completeness % in output
- If data completeness < 60%: Force HOLD, add "Low data confidence" warning
- If fewer than 5 of 8 dimensions are scored: Force HOLD, add "INSUFFICIENT DIMENSIONS"

---

## FMP Rate Limit Handling

If multiple consecutive FMP calls return 429 (rate limit):
1. Note "FMP rate limit reached" in output
2. Score only dimensions with data collected so far
3. Normalize composite: weighted_sum / sum_of_available_weights x 100
4. Force HOLD if <60% data completeness

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
