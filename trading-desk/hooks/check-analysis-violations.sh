#!/bin/bash
# trading-desk: Stop hook that enforces no-skip-policy on /analyze runs.
#
# Triggers when an /analyze sentinel file (reports/.analyze-active-{SYMBOL}) exists,
# meaning an analysis run is in flight or just finished. Checks the synthesis report
# for forbidden rationalizations and structural completeness. Exits 2 to feed
# violations back to the model so it fixes them; exits 0 otherwise.
#
# Re-entrancy break: a per-symbol attempt counter prevents infinite-fix loops.
# After MAX_ATTEMPTS, the hook exits 0 with a stderr note so the run can complete.
#
# Adversarial-review fixes incorporated:
#   - Sentinel file (not mtime) for run detection
#   - Max-retry break for re-entrancy
#   - Anchored regex, excludes <!-- POLICY_QUOTE --> blocks
#   - Structural manifest count check (rephrasing-resistant)
#   - No `set -e` (would mask the intended exit-2 semantics)
#   - macOS BSD find compatible

# --- Step 0: detect whether this turn-end is for an /analyze run ----
# Look for any sentinel file. If none, this is some other Claude Code turn — exit fast.
SENTINEL=$(ls reports/.analyze-active-* 2>/dev/null | head -1)
if [ -z "$SENTINEL" ]; then
    exit 0
fi

# Extract the symbol from the sentinel filename: reports/.analyze-active-AAPL → AAPL
SYMBOL=$(basename "$SENTINEL" | sed 's/^\.analyze-active-//')
if [ -z "$SYMBOL" ]; then
    exit 0
fi

# --- Step 1: re-entrancy break ----
# Each time the hook fires for a given symbol, increment a counter.
# After MAX_ATTEMPTS, exit 0 so the run can finish even if violations remain.
ATTEMPTS_FILE="reports/.analyze-attempts-${SYMBOL}"
MAX_ATTEMPTS=3
if [ -f "$ATTEMPTS_FILE" ]; then
    ATTEMPTS=$(cat "$ATTEMPTS_FILE" 2>/dev/null || echo 0)
else
    ATTEMPTS=0
fi
ATTEMPTS=$((ATTEMPTS + 1))
echo "$ATTEMPTS" > "$ATTEMPTS_FILE"

if [ "$ATTEMPTS" -gt "$MAX_ATTEMPTS" ]; then
    {
        echo "[trading-desk Stop hook] Max retries ($MAX_ATTEMPTS) exceeded for $SYMBOL."
        echo "Letting the run complete with residual violations."
        echo "Review reports/${SYMBOL}_synthesis.md manually."
    } >&2
    rm -f "$ATTEMPTS_FILE"
    rm -f "$SENTINEL"
    exit 0
fi

# --- Step 2: locate the synthesis report ----
SYNTH="reports/${SYMBOL}_synthesis.md"
if [ ! -f "$SYNTH" ]; then
    # Sentinel exists but synthesis report doesn't — analysis is mid-run, not at synthesis yet.
    # Don't trigger; let the run continue.
    exit 0
fi

# --- Step 3: prepare scrubbed copy that excludes legitimate policy-quote blocks ----
# Any block delimited by <!-- POLICY_QUOTE --> ... <!-- /POLICY_QUOTE --> is excluded
# from the regex scan, since faithful pipeline-audit narration may quote the banned phrases.
SCRUBBED=$(mktemp)
trap 'rm -f "$SCRUBBED"' EXIT

awk '
    /<!-- POLICY_QUOTE -->/ { skip=1; next }
    /<!-- \/POLICY_QUOTE -->/ { skip=0; next }
    !skip { print }
' "$SYNTH" > "$SCRUBBED"

# --- Step 4: forbidden-phrase scan (anchored to status-line context) ----
# Match phrases ONLY when they appear next to status markers (FAILED/SKIPPED/N/A/manifest cells)
# or as bullet/list-item rationale. Avoids false positives in narrative paragraphs that
# discuss the policy itself.
FORBIDDEN_REGEX='(FAILED|SKIPPED|N/A|skipped|gap)[^|]{0,80}(token budget|skipped per budget|skipped to save|data gaps \(skipped|likely low signal|context already large|skipped — context|covered by another tool|skipped for brevity|skipped — pipeline degradation|skipped — budget)'

VIOLATIONS=$(grep -inE "$FORBIDDEN_REGEX" "$SCRUBBED" || true)

# --- Step 5: structural manifest check ----
# Each phase report must have an API Call Manifest with a minimum number of entries.
# This catches rephrasing-based skips that get past the regex.
# (Using case statement instead of `declare -A` for macOS bash 3.2 compatibility.)

min_rows_for_phase() {
    case "$1" in
        technical)   echo 10 ;;
        fundamental) echo 15 ;;
        sentiment)   echo 20 ;;
        *)           echo 0  ;;
    esac
}

STRUCTURAL_FAILS=""
for phase in technical fundamental sentiment; do
    REPORT="reports/${SYMBOL}_${phase}.md"
    if [ ! -f "$REPORT" ]; then
        # Crypto skips fundamental — accept N/A stub
        if [ "$phase" = "fundamental" ] && grep -qi "not applicable for crypto" "$SYNTH" 2>/dev/null; then
            continue
        fi
        STRUCTURAL_FAILS="${STRUCTURAL_FAILS}- ${REPORT}: file missing\n"
        continue
    fi
    # Count rows in the API Call Manifest table (lines that start with `|` and contain a status string)
    ROWS=$(grep -cE '^\|.*(OK|OK \(fallback\)|EMPTY|402|FAILED|N/A) *\|' "$REPORT" 2>/dev/null || echo 0)
    MIN=$(min_rows_for_phase "$phase")
    if [ "$ROWS" -lt "$MIN" ]; then
        STRUCTURAL_FAILS="${STRUCTURAL_FAILS}- ${REPORT}: API Call Manifest has only ${ROWS} status rows (expected ≥${MIN}).\n"
    fi
done

# --- Step 6: emit violations or pass ----
if [ -n "$VIOLATIONS" ] || [ -n "$STRUCTURAL_FAILS" ]; then
    {
        echo "═══ trading-desk pipeline violation (attempt $ATTEMPTS/$MAX_ATTEMPTS) ═══"
        echo ""
        if [ -n "$VIOLATIONS" ]; then
            echo "FORBIDDEN RATIONALIZATIONS in $SYNTH:"
            echo "$VIOLATIONS"
            echo ""
        fi
        if [ -n "$STRUCTURAL_FAILS" ]; then
            echo "STRUCTURAL GAPS:"
            printf '%b' "$STRUCTURAL_FAILS"
            echo ""
        fi
        echo "Per lib/no-skip-policy.md: each violation must be resolved by calling the actual tool, not by rewording the excuse."
        echo ""
        echo "Action required:"
        echo "  1. For each forbidden phrase: identify the missing tool, call it, replace the rationalization with the real outcome."
        echo "  2. For each structural gap: re-spawn the corresponding sub-agent (td-{technical|fundamental|sentiment}-analyst) to fill the missing manifest rows."
        echo "  3. Re-render the compact card from the literal template in lib/output-formats.md."
        echo "  4. The hook will re-check on next turn-end."
    } >&2
    exit 2
fi

# Clean run — remove sentinel and counter so future /analyze invocations start clean.
rm -f "$SENTINEL"
rm -f "$ATTEMPTS_FILE"
exit 0
