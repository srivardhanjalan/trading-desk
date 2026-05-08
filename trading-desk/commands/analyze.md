---
description: Full 16-phase analysis with 8-dimension scoring and BUY/SELL/HOLD recommendation. Runs phase groups 1-3 in parallel sub-agents, then synthesizes.
argument-hint: "[SYMBOL]"
---

# Full Analysis: $ARGUMENTS

You are the **/analyze orchestrator**. You DO NOT execute the technical, fundamental, or sentiment phase groups yourself — they run in parallel sub-agents with fresh contexts so they cannot rationalize skipping mandatory steps. Your jobs are:
1. Resolve asset_type once via Phase 0.
2. Spawn the 3 phase-group agents in parallel.
3. Verify each agent's report file exists and is structurally complete.
4. Run synthesis (Phase Group 4) inline using the 3 report files.
5. Render the compact card from the literal template.

**MANDATORY:** Read `${CLAUDE_PLUGIN_ROOT}/lib/no-skip-policy.md`. Forbidden-rationalization rules apply to you AND to every sub-agent. The Stop hook (`hooks/check-analysis-violations.sh`) will block the turn-end if violations are detected — exit code 2 from the hook is not optional, fix the report before re-rendering.

---

## Step 0 — Setup (orchestrator-only, sequential)

1. `Bash`: `mkdir -p reports && touch reports/.analyze-active-$ARGUMENTS && date +%Y-%m-%d`
   The sentinel file `reports/.analyze-active-{SYMBOL}` tells the Stop hook that an /analyze run is in progress and to check the synthesis report when it appears. The hook uses this instead of mtime, which is unreliable across slow runs.
2. Read these rulebooks once (you'll pass the absolute paths to each sub-agent):
   - `${CLAUDE_PLUGIN_ROOT}/lib/no-skip-policy.md`
   - `${CLAUDE_PLUGIN_ROOT}/lib/error-handling.md`
   - `${CLAUDE_PLUGIN_ROOT}/lib/scoring-rubrics.md`
   - `${CLAUDE_PLUGIN_ROOT}/lib/asset-classifier.md`
3. If `rules.json` exists in the project root, read it for risk parameters. Otherwise use defaults.
4. Capture the absolute plugin root: when you write `${CLAUDE_PLUGIN_ROOT}` in this command body, Claude Code substitutes the absolute path before you see it. Hold that path as a variable in your working memory (e.g. `PLUGIN_ROOT = ${CLAUDE_PLUGIN_ROOT}`). You will pass concrete paths into agent prompts because the `${CLAUDE_PLUGIN_ROOT}` token does NOT auto-expand inside agent message bodies.

---

## Step 1 — Phase 0: Asset Classification (orchestrator-only, sequential)

Sub-agents need asset_type, sector, current_price, beta, and company_name to route correctly. Resolve here so each agent doesn't duplicate the call.

Call in parallel:
- `mcp__plugin_trading-desk_financial-modeling-prep__getCompanyProfile` with symbol=$ARGUMENTS
- `mcp__plugin_trading-desk_alpaca__get_clock` (cached)

From the profile, extract: `asset_type` (apply `lib/asset-classifier.md` rules), `sector`, `current_price`, `beta`, `company_name`, `mcap`, `52w_high`, `52w_low`.

Write `reports/{SYMBOL}_classification.md` with these fields plus the market status (open/closed) and today's date. This is shared input for all 3 sub-agents.

If `getCompanyProfile` fails, you cannot route the sub-agents. Log it, abort the run, tell the user the symbol may be invalid.

---

## Step 2 — Spawn 3 phase-group agents in parallel (single message)

**This is the key step — all 3 Agent calls go in ONE message so they run concurrently.** Use `subagent_type` matching the agent file names (without the `td-` prefix or with full name; see your runtime's spec).

Each spawn prompt must include:
- Absolute paths (no `${CLAUDE_PLUGIN_ROOT}` tokens — they don't expand in agent context)
- The pre-resolved classification fields
- A directive to write to a specific filename and return a one-line summary

### Agent A — Technical
```
Run trading-desk technical phase group for {SYMBOL}.

Inputs:
  SYMBOL = $ARGUMENTS
  ASSET_TYPE = {from classification}
  CURRENT_PRICE = {from classification}
  BETA = {from classification}
  TODAY_DATE = {today}
  INSTRUCTIONS_PATH = ${CLAUDE_PLUGIN_ROOT}/commands/analyze-technical.md
  ERROR_HANDLING_PATH = ${CLAUDE_PLUGIN_ROOT}/lib/error-handling.md
  NO_SKIP_PATH = ${CLAUDE_PLUGIN_ROOT}/lib/no-skip-policy.md
  REPORTS_DIR = {absolute path to ./reports}

Read all rulebook files first. Execute every phase per INSTRUCTIONS_PATH. On 402 run the fallback chain. Write reports/{SYMBOL}_technical.md including the API Call Manifest with canonical statuses (OK / OK (fallback) / EMPTY / 402 / FAILED / N/A). Return a one-line summary.

Forbidden rationalizations are HARD-banned per NO_SKIP_PATH. The Stop hook will block the turn-end if your report contains any of: "token budget", "context already large", "data gaps (skipped", "skipped to save", "likely low signal", "covered by another tool", "skipped per budget", "skipped — pipeline degradation". Just call the tool.
```

### Agent B — Fundamental
Same skeleton, with:
- `INSTRUCTIONS_PATH = ${CLAUDE_PLUGIN_ROOT}/commands/analyze-fundamental.md`
- Add `SECTOR`, `MCAP`
- Add `SCORING_RUBRICS_PATH`, `ASSET_CLASSIFIER_PATH`
- Note crypto routing: if ASSET_TYPE=crypto, write a stub report and exit early.

### Agent C — Sentiment
Same skeleton, with:
- `INSTRUCTIONS_PATH = ${CLAUDE_PLUGIN_ROOT}/commands/analyze-sentiment.md`
- Add `COMPANY_NAME`
- Note crypto/etf routing for phases 12-13.
- Extra emphasis on platform mandatory-call list (Reddit/Twitter/StockTwits/Glassdoor/Google Trends/dark pool/short interest).

---

## Step 3 — Verify agent outputs (orchestrator)

After all 3 agents return, do NOT trust the summary strings — verify the report files. The agent's return string only summarizes; the actual work is in the files.

For each phase group:
1. `Read` `reports/{SYMBOL}_technical.md`, `reports/{SYMBOL}_fundamental.md`, `reports/{SYMBOL}_sentiment.md`.
2. Check structural completeness:
   - Each report MUST contain an `## API Call Manifest` section with ≥10 status rows (technical), ≥15 (fundamental, non-crypto), ≥20 (sentiment).
   - Each report MUST contain the section headers required by the agent's brief (technical: regime, RSI, MACD, S/R, volume; fundamental: Piotroski, Z-Score, DCF base/bull/bear, analyst targets, earnings history; sentiment: options metrics, news NLP, insider, institutional, backtest).
   - The forbidden phrases must NOT appear outside any explicit `<!-- POLICY_QUOTE -->` blocks. (You shouldn't add policy quotes to reports anyway.)
3. If any check fails for an agent, **re-spawn that agent** with the specific gap noted, e.g.: "Your previous report at reports/{SYMBOL}_sentiment.md was missing the News NLP per-article breakdown and contained the phrase 'data gaps (skipped — budget)'. Re-run the missing tools and rewrite the report."

Only proceed to Step 4 once all 3 reports pass verification.

---

## Step 4 — Synthesis (orchestrator-inline; Phase Group 4)

Now run `${CLAUDE_PLUGIN_ROOT}/commands/synthesize.md` instructions. This stays in the orchestrator's context because it (a) needs Alpaca account info, (b) writes scores.csv, (c) annotates the TV Desktop chart, and (d) renders the compact card. Sub-agents cannot push to TV Desktop or modify shared state predictably.

Synthesis steps (per `synthesize.md`):
1. Read all 3 phase reports + classification.
2. Read `${CLAUDE_PLUGIN_ROOT}/lib/scoring-rubrics.md` and `${CLAUDE_PLUGIN_ROOT}/lib/output-formats.md`.
3. Alpaca: `get_account_info`, `get_open_position`, `get_all_positions`, `get_portfolio_history`.
4. WebSearch: estimate revisions direction.
5. FMP: `getStockPriceChange`, `getFullChart` (1y daily for VaR).
6. Compute position sizing, stop/target, R:R, Kelly.
7. Score all 8 dimensions.
8. Evaluate ALL 8 overrides explicitly (each gets a log line: APPLIED or NOT TRIGGERED with reason).
9. Compute composite with overrides.
10. Annotate TradingView Desktop chart (if running).
11. Append to `scores.csv`.
12. Write `reports/{SYMBOL}_synthesis.md` containing the full narrative report AND the compact card rendered from the literal `COMPACT_CARD_TEMPLATE` in `lib/output-formats.md`.
13. Display the compact card to the user.

**Render the compact card from the literal template** in `${CLAUDE_PLUGIN_ROOT}/lib/output-formats.md` (block named `COMPACT_CARD_TEMPLATE`). Do NOT redesign the layout — substitute values into the template verbatim. This is what guarantees consistent output across runs.

---

## Step 5 — Forbidden-rationalization scan (MANDATORY, before turn end)

Before declaring the run complete, run a Bash grep against the 4 report files for forbidden phrases:

```bash
grep -nE "(skipped — token budget|skipped per budget|skipped to save|data gaps \(skipped|likely low signal|context already large|skipped — context|covered by another tool|skipped for brevity|skipped — pipeline degradation)" reports/${SYMBOL}_technical.md reports/${SYMBOL}_fundamental.md reports/${SYMBOL}_sentiment.md reports/${SYMBOL}_synthesis.md 2>/dev/null
```

Each match → call the missing tool now, fix the report, rerun the grep. Only when grep returns nothing may you finish the turn. The Stop hook also runs this check externally as a backstop; if it exits 2, fix the report and continue.

After the scan passes:
```bash
rm -f reports/.analyze-active-${SYMBOL}
```
(Removes the sentinel so the Stop hook stops watching.)

---

## Error Recovery

If any sub-agent fails entirely (returns "BLOCKED" or its file is unwritable):
- Mark that phase group as FAILED in the synthesis report.
- Continue to synthesis with the available reports.
- Per `${CLAUDE_PLUGIN_ROOT}/lib/error-handling.md`: <60% completeness → force HOLD.

If a single tool call fails inside an agent: that agent handles it locally per its brief — log as FAILED with real error, run fallback chain on 402, continue.

---

## Completion Audit (final)

Before displaying the compact card, verify:
1. **Phase Group 1 (Technical):** report exists, contains regime/RSI/MACD/S/R, manifest has ≥10 entries.
2. **Phase Group 2 (Fundamental):** report exists (or N/A stub for crypto), contains Piotroski/Z-Score/DCF/analyst-targets/earnings-history.
3. **Phase Group 3 (Sentiment):** report exists, contains options/news-NLP/insider+10b5-1/institutional/backtest.
4. **Phase Group 4 (Synthesis):** all 8 dimensions scored, ALL 8 overrides have explicit log lines, Scenario DCF attempted (Track A) or skipped with reason (Track B).
5. **Compact Card:** rendered from literal template in `lib/output-formats.md`, all sections present.

Audit summary line in the synthesis-report footer:
```
Pipeline: {PASS/VIOLATION} | Agents: {3/3} | Phases: {N}/4 | Overrides: {N}/8 | Data: {X}%
```

---

## Post-Analysis

- Offer: `Run /trading-desk:trade buy $ARGUMENTS {amount} to paper trade`.
- If Desktop running: note chart annotations are set.
