# No-Skip Policy — Mandatory Execution Rules

**This policy overrides all other instructions.** When a conflict exists between convenience and completeness, completeness wins.

---

## Core Rule

**Every analysis step listed in the pipeline MUST be attempted.** If a step fails, it MUST be logged with the failure reason. Silent skipping is a pipeline violation.

---

## Four Valid Outcomes for Every Step

Each analysis step can only have one of these outcomes:

1. **COMPLETED** — Tool called, data collected, used in scoring (manifest status `OK`)
2. **COMPLETED via fallback** — FMP returned 402/401/403, but a documented fallback in `error-handling.md` succeeded (manifest status `OK (fallback)`). Counts toward completeness as success.
3. **FAILED** — Tool called, error received, AND any documented fallbacks also failed. Logged as `N/A` with reason. (manifest status `402` if paywall, `FAILED` if other error)
4. **NOT APPLICABLE** — Step does not apply to this asset type (e.g., crypto has no fundamentals) (manifest status `N/A`)

**There is no fifth option.** "Skipped because it seemed optional" or "skipped to save time" are NOT valid outcomes.

**Critical:** On a 402 paywall, you have NOT failed until the fallback chain in `${CLAUDE_PLUGIN_ROOT}/lib/error-handling.md` has been attempted. Marking a step FAILED without running the documented primary fallback is a pipeline violation.

---

## Forbidden Rationalizations (HARD BAN)

The following phrases — and any equivalent reasoning — MUST NEVER appear as a justification for not calling a mandatory tool:

| Forbidden phrase | Why it's banned |
|------------------|-----------------|
| "skipped — token budget" | Token cost is not a valid skip reason. Every mandatory tool's cost is already accepted by the pipeline design. |
| "skipped — context size" / "context already large" | The pipeline writes phase outputs to `reports/` precisely so context can be compressed. Skipping the call defeats this. |
| "skipped — pipeline degradation" | "Pipeline degradation" describes what happens to the OUTPUT when tools fail, not a mode where you preemptively don't call them. |
| "data gaps (skipped — ...)" | Data gaps are caused by tools FAILING, not by tools NOT BEING CALLED. The gap label is reserved for actual failures. |
| "skipped — likely low signal" / "skipped — probably empty" | You don't know it's low signal until you've called it. `EMPTY` is a valid outcome that documents this; "skipped" is not. |
| "skipped to save time" / "skipped for brevity" | Wall-clock time is not a valid skip reason for tools the user has marked mandatory. |
| "covered by another tool" (without explicit cross-reference rule) | Each mandatory tool is mandatory in its own right. If the pipeline intends fallback substitution, it says so explicitly. |

**If you find yourself reaching for one of these phrases, STOP and call the tool instead.** The rationalization is the failure mode — not the missing data.

**Self-check before writing the report:** scan your draft for the strings above. If any appear, every instance is a pipeline violation that must be fixed (by actually running the call) before the report is delivered.

A genuine failure looks like this — and ONLY this:
```
[FAILED] {tool_name}: {actual error string returned by the tool}. Impact: {what score/metric is degraded}.
```
If the "error string" is your own reasoning (e.g. "didn't seem useful"), the step has not failed — it has not been attempted. That is a violation, not a failure.

---

## Mandatory Failure Logging Format

When a step fails, log it in the report as:

```
[FAILED] {tool_name}: {error_message}. Impact: {which score/metric is degraded}.
```

When a step is not applicable, log it as:

```
[N/A] {step_name}: Not applicable for {asset_type}. Reason: {why}.
```

---

## Steps That Are NEVER Optional

These steps MUST always be attempted for their applicable asset types, regardless of perceived difficulty or prior failures:

### For ALL Stocks (not crypto/ETF)
| Step | Phase | Why It's Mandatory |
|------|-------|--------------------|
| Custom DCF (base case) | 9 | Core valuation — without it, Valuation score is incomplete |
| Custom DCF (bear case) | 9 | Stress test — required for margin of safety |
| Scenario DCF (bull/base/bear) | 15 | Required for Track A position sizing. Track B MUST log skip reason |
| XBRL filing data | 7 | Revenue durability assessment (RPO, customer concentration) |
| Beneish M-Score | 7 | Earnings manipulation detection |
| All 8 overrides evaluation | 16 | Each override MUST have a log line — no silent omissions |
| 10b5-1 verification | 11 | Required for every insider with sales >$1M |
| News NLP (WebFetch articles) | 11 | Minimum 2 articles required |
| Peer comparison | 8 | Required for relative valuation context |

### For ALL Assets (including crypto)
| Step | Phase | Why It's Mandatory |
|------|-------|--------------------|
| Multi-timeframe analysis | 3 | Core technical scoring |
| Backtest + walk-forward | 14 | Required for Backtest dimension |
| Position sizing calculations | 15 | Required for trade setup |
| VaR/CVaR computation | 15 | Required for risk quantification |
| Data completeness tracking | 16 | Required in every report |
| Full compact card display | 16 | All 16 sections, no partial output |

---

## Scenario DCF Safeguard

The Scenario DCF (bull/base/bear probability-weighted) in Phase 15 has specific rules:

### Track A Stocks (Value: revenue growth <=20% AND P/E <=40)
- **MUST RUN** all 3 scenarios using `calculateCustomDCF`
- Call sequentially if batching causes session errors
- If all 3 fail: log failure, note "Scenario DCF: FAILED — {reason}", use Phase 9 DCFs as fallback
- **Never silently skip**

### Track B Stocks (Growth: revenue growth >20% OR P/E >40)
- Skip is valid BUT must be explicitly logged:
  ```
  SCENARIO DCF: SKIPPED — Track B stock (rev growth {X}%, P/E {Y}x). 
  PEG ratio used as primary valuation metric instead.
  ```

### Unknown Track (data insufficient to classify)
- **Default to running Scenario DCF** — err on the side of more analysis
- Log: "SCENARIO DCF: RUN (track classification uncertain)"

---

## Sequential Call Safeguard

These tools have known session race conditions and MUST be called sequentially (after other parallel batches complete):

1. `getFinancialStatementFullAsReported` — XBRL SEC filing data
2. `calculateCustomDCF` scenarios (when running 3 back-to-back) — space calls to avoid session collision

If a sequential call fails with "Session not found":
1. Wait 2 seconds
2. Retry once
3. If retry fails: log as FAILED, continue pipeline

---

## Post-Analysis Completion Audit

After every `/analyze` run, before displaying the compact card, perform this audit:

```
=== COMPLETION AUDIT ===
Phase Group 1 (Technical):  [COMPLETE/PARTIAL/FAILED] — {N}/{M} calls succeeded
Phase Group 2 (Fundamental): [COMPLETE/PARTIAL/FAILED/N/A] — {N}/{M} calls succeeded
Phase Group 3 (Sentiment):  [COMPLETE/PARTIAL/FAILED] — {N}/{M} calls succeeded
Phase Group 4 (Synthesis):  [COMPLETE/PARTIAL/FAILED] — {N}/{M} calls succeeded

Scenario DCF: [COMPLETED/SKIPPED-TRACK-B/FAILED] — {reason}
XBRL Data:   [COMPLETED/FAILED] — {reason}
All 8 Overrides: [ALL EVALUATED/MISSING: O{N}]
Compact Card: [ALL 16 SECTIONS/MISSING: {sections}]

Data Completeness: {X}%
Pipeline Status: {PASS/VIOLATION — {reason}}
```

If Pipeline Status = VIOLATION:
- Do NOT suppress the violation — display it prominently
- Still display the compact card (with degraded completeness)
- Note which steps need re-running

---

## What This Policy Does NOT Restrict

- **Caching:** Reusing cached data within a session is fine
- **Graceful degradation:** Setting failed components to N/A is correct behavior
- **Asset routing:** Skipping fundamentals for crypto is correct, not a violation
- **Conditional phases:** Phase 13 (earnings transcript) being conditional on earnings proximity is fine
- **Desktop availability:** Skipping chart annotations when Desktop is unavailable is fine

The policy targets **silent omission of applicable analysis steps**, not legitimate routing or degradation.
