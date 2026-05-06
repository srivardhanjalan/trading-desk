# Adversarial Audit: Peer Comparison Methodology
## Date: 2026-05-06

I'll start by reading the command files and reports to understand the peer comparison methodology.

---

Now let me read the AMD and PLTR reports.

---

Now let me also read the full analysis reports to see how peer comparison feeds into scoring.

---

Now let me check if there are any other relevant files, like the orchestrator command or any peer override logic.

---

Now let me check the CRDO report for the geographic peer selection question.

---

Now I have all the evidence I need. Let me compile the comprehensive audit.

---

# Adversarial Audit: Peer Comparison Methodology

## Flaw 1: No Validation of Peer Quality -- FMP Returns Irrelevant Peers

**Evidence:** AMD's FMP peer list (`getStockPeers`) returned:
`AMAT, ARM, ASML, KLAC, LRCX, MU, PLTR, QCOM, SAP, TXN`

This list includes PLTR (defense/AI software, P/S 60x, net margin 44%, no hardware) and SAP (enterprise ERP, completely different business model). It also includes AMAT, KLAC, LRCX -- these are semiconductor *equipment* companies, not semiconductor *designers*. AMD designs CPUs, GPUs, and AI accelerators. Its true competitors are NVDA, INTC, QCOM, MRVL, and AVGO, none of which (except QCOM) appear in FMP's list.

The report's author silently corrected this: the "Direct Competitor Comparison" table in `AMD_fundamental.md` (line 154) compares AMD to NVDA, INTC, and QCOM -- none of which came from `getStockPeers`. This manual override happened ad hoc, with no documented rationale or process.

**Current pipeline behavior:** Phase 8 in `analyze-fundamental.md` (line 64) says "Take top 3-4 by relevance" but provides zero criteria for what "relevance" means. There is no validation step.

**Fix:** Add a peer validation layer to Phase 8:

1. **Manual override map** in a new file `.claude/commands/_shared/peer-overrides.json`:
```json
{
  "AMD": ["NVDA", "INTC", "QCOM", "MRVL", "AVGO"],
  "PLTR": ["SNOW", "DDOG", "MDB", "NOW", "PANW"],
  "CRDO": ["ALAB", "MRVL", "AVGO", "CIEN"],
  ...
}
```
2. **Validation heuristic** when no override exists: Reject peers where sector or industry classification differs from the target. Reject peers where market cap differs by more than 10x. Reject peers with revenue model mismatch (hardware vs software, product vs services).

3. **Document the override** in the report: "Peers: FMP returned [X, Y, Z]. Overridden to [A, B, C] because [reason]."

---

## Flaw 2: Peer Comparison Table Lacks Valuation Ratios -- Only Price and Market Cap

**Evidence:** Phase 8 calls `getBatchQuotes` (line 68 of `analyze-fundamental.md`), which returns price, change%, marketCap, 50SMA, 200SMA. The AMD peer table (lines 154-162 of `AMD_fundamental.md`) confirms this -- it shows Price, Market Cap, 52W Range, % from 52W High, 50D MA Premium, and "Momentum." There is **no P/E, no margins, no EV/EBITDA, no growth rate** for any peer.

PLTR's report (lines 140-153 of `PLTR_fundamental.md`) is different: it includes Gross Margin, Net Margin, Rev Growth, P/S, and P/E for peers. But these were manually assembled by the report author -- they are not sourced from any API call in the pipeline. The pipeline instruction says "For deeper valuation comparison, use the main stock's ratiosTTM data from Phase 7" but this only has ratios for the *target stock*, not peers.

**Impact:** The peer comparison table in AMD's report is functionally useless for valuation scoring. Knowing that NVDA trades at $198 and AMD at $360 tells you nothing about relative value without P/E, EV/EBITDA, or margins.

**Fix:** Add `getFinancialRatiosTTM` calls for each peer in Phase 8, Step 2. Change the instruction to:

```
Step 2 (parallel):
- Call getBatchQuotes with symbols=$ARGUMENTS + top 3 peers
- Call getFinancialRatiosTTM for each peer (3 parallel calls)

Build peer comparison table with: Price, Market Cap, P/E, EV/EBITDA, 
Gross Margin, Operating Margin, Revenue Growth, ROE, D/E.
```

This adds 3 API calls (one per peer) but enables actual valuation comparison.

---

## Flaw 3: Peer P/E Referenced in Scoring Rubric But Never Computed

**Evidence:** The Valuation Track A rubric (`scoring-rubrics.md`, lines 87-88) explicitly requires peer P/E comparison:

- Score 9-10: "P/E below peer median"
- Score 7-8: "P/E near peer median"
- Score 5-6: "P/E at peer median"
- Score 3-4: "P/E above peer median"
- Score 1-2: "P/E >2x peer median"

But the pipeline never fetches peer P/E ratios. `getBatchQuotes` does not return P/E. `getFinancialRatiosTTM` is only called for the target stock (Phase 7, line 33). The peer median P/E is therefore **unknowable** with the current data pipeline.

**Consequence:** For Track A stocks, the Valuation score cannot be properly computed. The rubric has a hard dependency on a data point the pipeline does not collect. AMD and PLTR both route to Track B (PEG-based), so this gap did not surface in these specific reports. But any value stock going through Track A will have an ungroundable Valuation score.

**Fix:** Either:
(a) Add `getFinancialRatiosTTM` for peers as described in Flaw 2, making peer P/E available, OR
(b) Replace "peer median P/E" in the Track A rubric with "industry P/E from `getIndustryPESnapshot`" (which is already called in Phase 2, line 23). Industry P/E is a reasonable proxy and requires no additional calls.

Option (b) is simpler and already has data flowing. The rubric should be updated:
```
9-10: P/E below industry median (from getIndustryPESnapshot)
```

---

## Flaw 4: No Fallback When Peers Are Empty or Irrelevant

**Evidence:** Phase 8 (line 65) says: "If empty: note 'No peer data available', skip to Phase 9." There is no fallback mechanism for computing peer-relative valuation when peers are unavailable.

PLTR is a borderline case. FMP returned CRM, CRWD, PANW as peers (visible in `PLTR_fundamental.md` line 140). These are reasonable enterprise software peers, but PLTR's actual competitive moat is in defense/intelligence AI platforms where it has no true public-market peer. The report author acknowledged this: "PLTR's growth profile is in a different league from these peers -- it is growing 2-6x faster" (line 153).

For truly unique companies (SpaceX proxies, defense AI, quantum computing), `getStockPeers` will either return nothing or return irrelevant results. The Valuation rubric for Track A depends on peer P/E median, creating an unscoreable dimension.

**Fix:**
1. When peer list is empty or all peers fail relevance validation, use **industry-level benchmarks** from `getIndustryPESnapshot` and `getHistoricalIndustryPE` (already called in Phase 2) as the peer substitute.
2. Add a "peer confidence" flag: HIGH (verified relevant peers), MEDIUM (FMP peers, partially validated), LOW (no peers, industry benchmark used). Report this flag and adjust the weight of peer comparison in scoring accordingly.
3. For Track A, the rubric should have an explicit "no peer available" path: "If no peer P/E available, use industry P/E from Phase 2. If industry P/E also unavailable, cap peer-related component at 5 (neutral)."

---

## Flaw 5: Sample Size of 3-4 Peers Creates Statistical Noise

**Evidence:** Phase 8 (line 64) says "Take top 3-4 by relevance." AMD's report compares against 3 peers (NVDA, INTC, QCOM). PLTR compares against 3 (CRM, CRWD, PANW). CRDO compares against 3 (ALAB, CIEN, SMCI).

With 3 peers, a single outlier can skew the median dramatically. In AMD's case, INTC has a P/E ~10-15 while NVDA has a P/E ~55. Adding or removing one peer shifts the "peer median" by 50%+. This makes any peer-relative scoring (Track A "P/E below peer median") essentially arbitrary.

For large-cap semiconductors, there are 15+ comparable companies (NVDA, INTC, QCOM, MRVL, AVGO, TXN, MU, ARM, LSCC, MCHP, ON, NXPI, ADI, XLNX-now-AMD). Using only 3 introduces sample selection bias.

**Fix:**
1. Increase the peer count to 5-8 for large-cap stocks (market cap > $50B). The additional `getFinancialRatiosTTM` calls (5-8 instead of 3) are worth the improved statistical reliability.
2. For mid/small-cap stocks where fewer peers exist, keep 3-4 but note "small peer sample."
3. Report both peer median AND range: "Peer P/E: median 45x (range 15-430x, n=5)."

---

## Flaw 6: No Sub-Industry Context in Peer Selection

**Evidence:** AMD is classified as "Semiconductors" but operates across four distinct sub-markets: CPUs (vs Intel), GPUs/AI accelerators (vs NVIDIA), FPGAs (vs Lattice, Xilinx-legacy), and embedded (vs NXP, Microchip). Each sub-segment has vastly different valuation norms:

- AI accelerator companies: P/E 50-70x (NVDA)
- Legacy CPU: P/E 15-25x (INTC when profitable)
- Embedded: P/E 20-30x (MCHP, NXPI)

AMD's Data Center segment (48% of revenue, line 124 of `AMD_fundamental.md`) is the growth driver and competes with NVDA. But the "Semiconductors" peer group mixes in AMAT (equipment, P/E 25x), TXN (analog, P/E 35x), and MU (memory, cyclical P/E 5-50x). These sub-industry mismatches make aggregate peer comparison misleading.

**Fix:** Add sub-industry context to Phase 8:
1. After getting peer list, check the target's revenue segment breakdown from Phase 7 (`getRevenueProductSegmentation`).
2. Weight peers by segment similarity. If AMD is 48% Data Center, peers should be weighted toward data center-exposed companies (NVDA, MRVL, AVGO) rather than analog/memory players.
3. Add a note in the report: "Primary competitive segment: Data Center (48% of revenue). Peer selection weighted toward data center-exposed semiconductors."

---

## Flaw 7: Geographic Peer Selection Is US-Centric

**Evidence:** CRDO derives 74.1% of revenue from China + Hong Kong (lines 31-38 of `CRDO_fundamental.md`). Its FMP peers are ALAB, CIEN, SMCI -- all US-listed companies. There is no consideration of Chinese semiconductor/connectivity companies that compete in CRDO's primary market (e.g., Montage Technology, UNISOC, Loongson).

This matters because:
- CRDO's valuation multiples should be compared against companies with similar geographic revenue exposure and regulatory risk
- A US peer trading at 30x P/S with 15% China exposure is not comparable to CRDO at 30x P/S with 74% China exposure
- Export control risk (Entity List, CHIPS Act restrictions) affects CRDO and its Chinese competitors differently than it affects US-domestic-revenue peers

**Fix:**
1. When geographic concentration > 50% in a single non-US region (flagged by Phase 7's `getRevenueGeographicSegmentation`), add a note: "GEOGRAPHIC PEER MISMATCH: {stock} derives {X}% revenue from {region}. US-centric peer list may not reflect comparable regulatory/market risk."
2. Apply a **geographic risk discount** to peer comparison scores: if the target has >50% revenue from a geopolitically sensitive region but peers do not, note this asymmetry and adjust the Risk score rather than the Valuation score (which is already handled by the geographic concentration modifier in Risk scoring).
3. Optionally, use `searchCompaniesByName` or `stockScreener` filtered by geographic exposure to find more relevant peers.

---

## Flaw 8: Peer Comparison Output Has No Explicit Score Mapping

**Evidence:** Phase 8 runs peer comparison and produces a table, but the scoring rubrics in `scoring-rubrics.md` never say "peer comparison feeds into Dimension X with weight Y." The mapping is implicit and inconsistent:

- **Valuation Track A** references "P/E below peer median" (lines 87-88) -- so peers feed into Valuation
- **No other dimension** explicitly references peer data
- The synthesize command (`synthesize.md`) does not mention peer comparison in any of its 8 dimension scoring checklists (lines 89-97)
- In practice, the AMD report's Valuation score (3/10) was computed entirely from PEG ratios, DCF, and analyst targets -- peer data was not referenced at all
- The PLTR report's Valuation score (4/10) similarly uses PEG, DCF, and analyst targets -- the peer table is informational only

**Impact:** Phase 8 produces data that nobody uses for scoring. It is descriptive context but not a scoring input. This wastes API calls and creates a false sense of rigor.

**Fix:** Explicitly map peer comparison to scoring dimensions:
1. **Valuation (Track A):** "Compute peer median P/E from Phase 8. Compare target P/E to peer median. This is one of three inputs (alongside DCF and analyst targets)."
2. **Valuation (Track B):** "Compute peer median PEG or P/S. If target PEG is below peer median PEG, add +0.5 to Valuation score."
3. **Fundamental:** "If target's margin profile (gross, operating) exceeds all peers, add +0.5 to Fundamental. If below all peers, subtract 0.5."
4. Update the scoring checklist in `synthesize.md` to include: "Valuation: ... Peer median P/E or PEG from Phase 8 peer table."

---

## Summary of Recommended Changes

| Flaw | File to Modify | Change |
|------|---------------|--------|
| 1. No peer validation | `analyze-fundamental.md` Phase 8 + new `peer-overrides.json` | Add override map + validation criteria |
| 2. No peer ratios | `analyze-fundamental.md` Phase 8 Step 2 | Add `getFinancialRatiosTTM` for each peer |
| 3. Rubric references uncomputed data | `scoring-rubrics.md` Track A or Phase 8 | Either fetch peer P/E or use industry P/E |
| 4. No empty-peer fallback | `analyze-fundamental.md` Phase 8 | Add industry benchmark fallback + confidence flag |
| 5. Small sample size | `analyze-fundamental.md` Phase 8 | Increase to 5-8 peers for large caps |
| 6. No sub-industry context | `analyze-fundamental.md` Phase 8 | Weight peers by revenue segment similarity |
| 7. US-centric peers | `analyze-fundamental.md` Phase 8 | Flag geographic mismatch when target has non-US concentration |
| 8. No score mapping | `scoring-rubrics.md` + `synthesize.md` | Explicitly map peer data to Valuation and Fundamental scores |

The most critical fix is Flaw 3 (rubric references data the pipeline never fetches), because it means Track A Valuation scores are currently ungrounded. The quickest fix is to replace "peer median P/E" in the rubric with "industry P/E" from the already-collected `getIndustryPESnapshot` data in Phase 2.