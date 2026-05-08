# Full Analysis: $ARGUMENTS

Run the complete 16-phase analysis pipeline on the given symbol. This is the orchestrator — it executes ALL phases in a single conversation with file-based context management.

**This command runs Phases 0-16b sequentially.** After each phase group, results are saved to `reports/` so that raw tool responses can be compressed without losing critical data.

**Expected: ~55-73 tool calls across 4 MCP servers + WebSearch/WebFetch. Budget: 33-34 FMP calls.**

**MANDATORY:** Read and follow `_shared/no-skip-policy.md`. Every step must be ATTEMPTED — silent skipping is a pipeline violation.

---

## Setup

1. Read `_shared/no-skip-policy.md` (no-skip enforcement rules)
2. Read the strategy config from `rules.json` in the project root (if it exists) for risk parameters
3. Create `reports/` directory if it doesn't exist
4. Note the current date for all report filenames

---

## Phase Group 1: Technical (Phases 0, 1, 3, 4, 5, 6)

Execute ALL instructions from `.claude/commands/analyze-technical.md` with symbol=$ARGUMENTS.

After completion: verify `reports/{SYMBOL}_technical.md` is written with all data. This file MUST contain: asset type, price, beta, RSI, MACD, support/resistance, bid/ask spread, volume data, timeframe alignment.

---

## Phase Group 2: Fundamental (Phases 2, 7, 8, 9)

Execute ALL instructions from `.claude/commands/analyze-fundamental.md` with symbol=$ARGUMENTS.

**Session caching:** If this is the 2nd+ stock analyzed in this session, reuse cached values for: `getTreasuryRates`, `getStockPriceChange` (sector ETF — only if same sector), `getIndexQuote` (VIX), `getMarketRiskPremium`. This saves ~4 FMP calls.

**Asset routing:** Check the asset type from `reports/{SYMBOL}_technical.md`:
- Crypto: SKIP Phase Group 2 entirely
- ETF: Phase 7 uses fund tools instead
- ADR/OTC/Stock: Run normally

After completion: verify `reports/{SYMBOL}_fundamental.md` is written with all data. This file MUST contain: VIX value, treasury rates, financial scores, revenue growth rate, DCF values (all 3), analyst targets, earnings beat/miss history.

---

## Phase Group 3: Sentiment & Options (Phases 10, 11, 12, 13, 14)

Execute ALL instructions from `.claude/commands/analyze-sentiment.md` with symbol=$ARGUMENTS.

**Asset routing:** Check asset type:
- Crypto: Modified Phase 11 (no insider/congressional), skip Phase 12-13
- ETF: Skip Phase 12-13

After completion: verify `reports/{SYMBOL}_sentiment.md` is written with all data. This file MUST contain: options metrics (P/C ratio, IV/HV, max pain, net delta, unusual activity, premium trend), sentiment by platform, insider activity, institutional data, backtest results.

---

## Phase Group 4: Synthesis (Phases 15, 16, 16b)

Execute ALL instructions from `.claude/commands/synthesize.md` with symbol=$ARGUMENTS.

This phase reads the 3 report files and produces the final scored recommendation. It:
1. Reads all phase reports from `reports/`
2. Reads scoring rubrics from `_shared/scoring-rubrics.md`
3. Calls Alpaca for account info + existing position
4. Calls WebSearch for estimate revisions
5. Computes position sizing, stop/target, R:R ratio
6. Scores all 8 dimensions
7. Calculates weighted composite with overrides
8. Annotates TradingView chart (if Desktop running)
9. Saves final report and appends to scores.csv
10. Displays compact card

---

## Error Recovery

If any phase group fails completely:
- Log the failure
- Continue with remaining phase groups
- The synthesize phase will handle missing data (reduced completeness %)
- Per `_shared/error-handling.md`: <60% completeness = force HOLD

If a single tool call fails within a phase group:
- Log it, set that component to N/A
- Continue with remaining tools in the phase
- Per `_shared/error-handling.md`: standard error protocol

---

## Session Caching Reference

These calls can be cached and reused across multiple /analyze runs in the same session:
| Call | Cache Key | TTL |
|------|-----------|-----|
| `get_clock` | "market_status" | Entire session |
| `getTreasuryRates` | "treasury" | Entire session |
| `getIndexQuote` (VIX) | "vix" | Entire session |
| `getMarketRiskPremium` | "mrp" | Entire session |
| `getStockPriceChange` (sector ETF) | "sector_{ETF}" | Per sector, entire session |

On 2nd+ stock: ~29-30 FMP calls (save ~4).

---

## Completion Audit (MANDATORY — run before displaying compact card)

Before displaying the compact card, perform the completion audit defined in `_shared/no-skip-policy.md`:

1. **Phase Group 1 (Technical):** Verify `reports/{SYMBOL}_technical.md` exists and contains: RSI, ADX, MACD, support/resistance, regime classification
2. **Phase Group 2 (Fundamental):** Verify `reports/{SYMBOL}_fundamental.md` exists (or N/A for crypto) and contains: Piotroski, Z-Score, DCF values (all 3+), XBRL data attempt, Beneish M-Score
3. **Phase Group 3 (Sentiment):** Verify `reports/{SYMBOL}_sentiment.md` exists and contains: options flow, insider trades with 10b5-1 status, news NLP, backtest results
4. **Phase Group 4 (Synthesis):** Verify all 8 dimensions scored, all 8 overrides evaluated, Scenario DCF attempted (Track A) or logged as skipped (Track B)
5. **Compact Card:** Verify all 16 sections present per `_shared/output-formats.md`

**If any mandatory step was silently skipped (no COMPLETED/FAILED/N/A log), go back and execute it before proceeding.**

Display the audit summary in the report footer:
```
Pipeline: {PASS/VIOLATION} | Phases: {N}/4 complete | Overrides: {N}/8 evaluated | Data: {X}%
```

---

## Post-Analysis

After the compact card is displayed:
- Offer: "Run `/project:research $ARGUMENTS` for deep web research (Twitter/StockTwits/full article NLP)"
- Offer: "Run `/project:trade buy $ARGUMENTS {amount}` to paper trade"
- If Desktop running: note chart annotations (stop/target lines and price alerts are set)
