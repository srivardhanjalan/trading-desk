# Trading Desk

A [Claude Code](https://claude.ai/code) plugin for institutional-grade equity analysis and Alpaca paper trading. Connects 4 MCP servers (FMP, Alpaca, TradingView Analysis, optional TradingView Desktop) into a 16-phase analysis pipeline that produces an 8-dimension composite score with a BUY/SELL/HOLD recommendation and position sizing.

```
/trading-desk:analyze AMD          → 73 score, BUY, $250 position, 6.4 R/R
/trading-desk:portfolio            → live Alpaca dashboard with risk flags
/trading-desk:scan watchlist       → score 23 stocks, ranked daily
```

---

## Install (30 seconds)

In **any** Claude Code session, in **any** directory:

```
/plugin marketplace add srivardhanjalan/trading-desk
/plugin install trading-desk@srivardhanjalan
/trading-desk:setup
```

The `/trading-desk:setup` skill walks you through:

1. Asks (in chat) for your **FMP** key, **Alpaca** key + secret, and **whether to install TradingView Desktop integration** (macOS only, opt-in — the skill handles the brew install + clone + auto-launch wiring for you)
2. Writes them to `~/workspace/secrets/trading-desk/.env` (kept outside the plugin install dir, survives plugin updates)
3. Detects and backs up any conflicting MCP configs in `~/.claude/.mcp.json` or your cwd's `.mcp.json` so the plugin's tools register cleanly
4. Installs the FMP MCP server and starts it on `:8080`
5. If you opted in: `brew install --cask tradingview`, clones the MCP server, launches the app with CDP, and enables a SessionStart hook that auto-launches it on every future claude session
6. Verifies both keys against the live Alpaca/FMP endpoints

When it's done, restart claude once:

```
/quit
claude
```

That's the only restart needed — and **you do not need to source any env file in your shell**. The plugin ships a wrapper script (`bin/launch-alpaca.sh`) that loads your `.env` whenever Claude spawns the Alpaca MCP server.

If you opted in for TradingView Desktop, the SessionStart hook (`bin/ensure-tv-desktop.sh`) auto-launches the app with `--remote-debugging-port=9222` on every session — no manual launch step. The hook is gated by `TD_TV_ENABLED` in `.env`, so opting out (or changing your mind later) is a one-line edit.

### Get the API keys (both free)

| Service | What for | Sign up |
|---|---|---|
| **Financial Modeling Prep** | Fundamentals, DCF, earnings, insiders, macro | [financialmodelingprep.com/developer](https://financialmodelingprep.com/developer) |
| **Alpaca Paper Trading** | Portfolio, options chains, paper trading | [app.alpaca.markets/signup](https://app.alpaca.markets/signup) |

Free tiers are enough for daily use. Alpaca paper trading gives you $100k–$200k of fake money — no real funds at risk.

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Node.js | 18+ | [nodejs.org](https://nodejs.org) |
| Python | 3.10+ | [python.org](https://python.org) |
| Claude Code | latest | `npm install -g @anthropic-ai/claude-code` |
| `uvx` | any | Auto-installed by the setup skill if missing |
| Homebrew | optional | macOS only — needed only if you want the setup skill to auto-install TradingView Desktop. Get it at [brew.sh](https://brew.sh). |
| TradingView Desktop | optional | macOS only — adds chart screenshots + order book data + Pine Script. The setup skill auto-installs via Homebrew if you opt in. Analysis works fine without it. |

---

## Commands

| Command | What it does | ~Tool calls |
|---|---|---|
| `/trading-desk:morning-brief` | VIX, sector rotation, watchlist deltas, top movers | 32 |
| `/trading-desk:portfolio` | Alpaca dashboard with risk flags + earnings warnings | 12+ |
| `/trading-desk:analyze SYMBOL` | **Full 16-phase deep dive + recommendation (incl. M&A check, fund-level institutional flow, moat assessment)** | 58–76 |
| `/trading-desk:analyze-technical SYMBOL` | Technical phase only (price, indicators, volume, chart) | 9–21 |
| `/trading-desk:analyze-fundamental SYMBOL` | Fundamentals (macro, financials, DCF) | 23 |
| `/trading-desk:analyze-sentiment SYMBOL` | Options, insiders, social sentiment, backtests | 24–30 |
| `/trading-desk:synthesize SYMBOL` | Re-score from saved phase reports (no new MCP calls) | 3–8 |
| `/trading-desk:scan watchlist` | Score every stock in `watchlist.csv` | ~131 |
| `/trading-desk:scan discover` | FMP screener → score top 10 candidates | ~64 |
| `/trading-desk:scan AAPL,MSFT,NVDA` | Score specific symbols | varies |
| `/trading-desk:compare AMD NVDA` | Side-by-side scoring across all 8 dimensions | 18 |
| `/trading-desk:trade buy AMD 1000` | Paper trade with pre-trade safety checks | 6 |
| `/trading-desk:setup` | First-run bootstrap (rerun anytime to reset config) | 0 (interactive) |

---

## How analysis works

### The 16 phases

`/trading-desk:analyze SYMBOL` runs phases sequentially in a single conversation, writing intermediate results to `reports/` so context survives compression.

| # | Phase | Source |
|---|---|---|
| 0 | Asset classification + market clock | Alpaca |
| 1 | Price, identity, bid/ask spread | FMP profile + Alpaca snapshot |
| 2 | Macro: sector ETF, VIX, treasury rates | FMP + TV-Analysis |
| 3 | Multi-timeframe technicals (5 timeframes) | TV-Analysis + FMP indicators |
| 4 | Volume + smart-money signals | FMP float + TV-Analysis |
| 5 | Candle pattern recognition | TV-Analysis |
| 6 | TradingView Desktop chart + screenshot | TV Desktop *(optional)* |
| 7 | Fundamentals: Piotroski, Z-Score, FCF | FMP (10 parallel) |
| 8 | Peer comparison | FMP peers + batch quotes |
| 9 | Valuation: 3 DCFs + PEG + analyst targets | FMP DCF / levered DCF / custom DCF |
| 10 | Options flow: 10 derived metrics | Alpaca options chain + bars |
| 11 | Sentiment + news NLP + M&A check | TV-Analysis + FMP search + WebSearch + WebFetch |
| 12 | Institutional ownership (13F) — aggregate + fund-level flow | FMP positions + filing extract by holder |
| 13 | Earnings transcript NLP *(when available)* | FMP transcripts |
| 14 | Strategy backtest + cross-validation | TV-Analysis + TV Desktop |
| 15 | Risk quantification + position sizing | Alpaca account |
| 16 | Synthesis: competitive moat + 8-dimension composite + recommendation | Scoring rubrics + qualitative reasoning |

### Scoring → action

Eight dimensions, each scored 1–10, weighted into a 0–100 composite:

| Dimension | Weight | What feeds it |
|---|---:|---|
| Technical | 22% | Multi-TF alignment, RSI, MACD, ADX, candles |
| Fundamental | 15% | Revenue growth, margins, Z-Score, Piotroski |
| Valuation | 15% | 3 DCF models, PEG (growth stocks), analyst targets |
| Smart Money | 13% | Insiders, congress trades, institutional, options flow |
| Risk | 12% | Beta, IV/HV, earnings proximity, bid/ask spread |
| Backtest | 10% | Strategy win rate, Sharpe, walk-forward validation |
| Sentiment | 7% | Reddit, Twitter, StockTwits, news NLP |
| Macro | 6% | Sector rotation, VIX, treasury rates |

| Composite | Signal | Action |
|---:|---|---|
| ≥ 75 | **STRONG BUY** | Aggressive sizing |
| 60–74 | **BUY** | Standard sizing |
| 40–59 | **HOLD** | No new position |
| 25–39 | **SELL** | Reduce / exit |
| < 25 | **STRONG SELL** | Exit immediately |

**Safety overrides** layer on top: graduated overbought penalty (RSI 78 = warning, RSI 88 = block), beta-conditional VIX panic, cross-dimension conflict detection, R:R ratio gate, and a data completeness floor (< 60% completeness forces HOLD).

### Two valuation tracks

The pipeline auto-classifies stocks into a valuation track based on growth + multiple:

- **Track A (Value)** — Revenue growth ≤ 20% AND P/E ≤ 40 → 3 DCF models (`getDCFValuation`, `getLeveredDCFValuation`, `calculateCustomDCF` with bull/base/bear scenarios)
- **Track B (Growth)** — Revenue growth > 20% OR P/E > 40 → PEG ratio + analyst targets (DCF marked N/A with justification)

### Asset coverage

| Type | Detection | Behavior |
|---|---|---|
| Stock | Default | Full 16 phases |
| Crypto | Symbol ends in `USDT`/`USD` | Reduced to 5 scoring dimensions |
| ETF | `isEtf=true` | Fund holdings + sector weighting instead of financials |
| ADR | `isAdr=true` | Adds FX risk assessment |
| OTC | Pink Sheets exchange | Warns limited data, blocks trading |

### No-skip policy

Every analysis step ends in one of three states — silent skipping is a pipeline violation:

- **COMPLETED** — ran successfully with data
- **FAILED** — attempted but errored (reason logged)
- **N/A** — doesn't apply to this asset type (justification logged)

A completion audit runs before final output, e.g.:
```
Pipeline: PASS | Phases: 4/4 complete | Overrides: 8/8 evaluated | Data: 95%
```

---

## Watchlist

The default watchlist ships at `examples/watchlist.csv`. To customize:

- **Plugin users:** create `watchlist.csv` in the directory where you launch claude. Commands look there first.
- **Want to edit the default:** copy from `~/.claude/plugins/marketplaces/srivardhanjalan/trading-desk/examples/watchlist.csv` to your cwd.

Default watchlist (23 stocks):
```
ALMU, AMD, AMPX, ASX, BBAI, BE, CDNS, CRDO, FIX, FLTCF, GEV,
INFQ, KGS, KLTR, LAW, NOK, NOW, NVT, OTLK, PLTR, RBLX, SATS, VXRT
```

`examples/rules.json` holds risk/strategy parameters (max position size, stop-loss thresholds). Same override pattern: drop a `rules.json` in your cwd to override defaults.

---

## Daily automation (optional)

`scripts/daily-analysis.sh` runs `/trading-desk:analyze` on every watchlist stock via `claude -p` (headless mode), with:

- TradingView Desktop auto-launched with CDP for chart screenshots
- FMP server checked + restarted if needed
- Per-stock budget cap (`--max-budget-usd 8`)
- Composite score + signal extracted from each run
- Daily summary report generated by Sonnet at the end

**Precondition:** the plugin must be **globally installed** (`/plugin install trading-desk@srivardhanjalan`). The script verifies this and fails loudly if not — using `--plugin-dir` for headless mode would cause MCP-prefix translation overhead, which is unwanted in unattended automation.

**Schedule via macOS launchd (12:15 AM daily, catches up missed runs):**
```bash
cp scripts/com.tradingdesk.daily-analysis.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.tradingdesk.daily-analysis.plist
```

**Logs:** `reports/logs/analysis_YYYY-MM-DD.log`

**Uninstall:**
```bash
launchctl unload ~/Library/LaunchAgents/com.tradingdesk.daily-analysis.plist
rm ~/Library/LaunchAgents/com.tradingdesk.daily-analysis.plist
```

---

## MCP servers

| Server | Type | Lifecycle | What it does |
|---|---|---|---|
| [TradingView Desktop](https://github.com/tradesdontlie/tradingview-mcp) | stdio (Node, via wrapper) | spawned by Claude per session | Chart control, Pine Script, screenshots, order book. App auto-launched by SessionStart hook if `TD_TV_ENABLED=true`. |
| [TradingView Analysis](https://pypi.org/project/tradingview-mcp-server/) | stdio (uvx) | spawned by Claude per session | Screener, multi-TF analysis, candle patterns, backtests |
| [Financial Modeling Prep](https://github.com/imbenrabi/Financial-Modeling-Prep-MCP-Server) | HTTP `:8080` | long-running (started by setup skill) | Fundamentals, DCF, earnings, insiders, macro |
| [Alpaca](https://pypi.org/project/alpaca-mcp-server/) | stdio (uvx via wrapper) | spawned by Claude per session | Paper trading, options, portfolio, market data |

**Alpaca wrapper:** the plugin's `.mcp.json` invokes `${CLAUDE_PLUGIN_ROOT}/bin/launch-alpaca.sh` instead of `uvx alpaca-mcp-server` directly. The wrapper sources `~/workspace/secrets/trading-desk/.env` at MCP-spawn time, so your keys are loaded without you needing to `source .env` in your shell.

**TradingView wrapper:** `${CLAUDE_PLUGIN_ROOT}/bin/launch-tradingview.sh` execs the real TV MCP if you installed it (via the setup skill's opt-in step), otherwise responds to MCP protocol with an empty tool list — so users who skipped TV Desktop never see startup errors. The TV Desktop phase in `/trading-desk:analyze` gracefully marks itself N/A when no tools are available.

**TradingView SessionStart hook:** `${CLAUDE_PLUGIN_ROOT}/bin/ensure-tv-desktop.sh` runs on every claude session start. If `TD_TV_ENABLED=true` in your `.env` and macOS, it auto-launches the TV Desktop app with `--remote-debugging-port=9222` — no manual `open -a TradingView` step. Gated, async, silent no-op if disabled.

### Known issue: FMP session race

A few FMP tools (`getFinancialStatementFullAsReported`, `calculateCustomDCF`) intermittently fail with "Session not found" when batched alongside many parallel calls. The pipeline handles this by calling these tools **sequentially** after the parallel batch completes, with a one-shot retry on session errors.

---

## Troubleshooting

### `Plugin errors: financial-modeling-prep skipped — same command/URL`

You have a duplicate MCP config conflicting with the plugin. Likely sources:

- `~/.claude/.mcp.json` (user-level) — from a previous manual setup
- `<repo>/.mcp.json` (project-level) — the trading-desk repo's own legacy file from `setup.sh`

**Fix:** rerun `/trading-desk:setup` — Step 0 detects and backs up conflicting files automatically. Or manually:
```bash
mv ~/.claude/.mcp.json ~/.claude/.mcp.json.preplugin.bak
# and if cd'd in trading-desk repo:
mv .mcp.json .mcp.json.preplugin.bak
```
Then `/quit` and relaunch claude.

### Commands don't appear in autocompletion

- Confirm `/plugin` shows `trading-desk@srivardhanjalan` enabled
- Restart claude — plugin commands are loaded once at session start

### MCP servers report `401`/`403` (authentication failed)

The wrapper script needs `~/workspace/secrets/trading-desk/.env` to exist with valid keys. Check:
```bash
ls -l ~/workspace/secrets/trading-desk/.env
head ~/workspace/secrets/trading-desk/.env       # should show `export ...` lines
```
If the file is missing or wrong, rerun `/trading-desk:setup`.

### `Hook load failed: expected record, received undefined` (FSI plugins)

Unrelated to trading-desk — it's a bug in Anthropic's `financial-services-plugins` (their `hooks.json` ships as `[]` instead of `{"hooks": {}}`). The setup skill auto-patches this on first run. To patch manually:
```bash
python3 -c "
import json, os, glob
for root in [os.path.expanduser(p) for p in [
    '~/.claude/plugins/marketplaces/financial-services-plugins',
    '~/.claude/plugins/cache/financial-services-plugins']]:
    for path in glob.glob(f'{root}/**/hooks.json', recursive=True):
        try:
            d = json.load(open(path))
            if isinstance(d, list) or (isinstance(d, dict) and 'hooks' not in d):
                json.dump({'hooks': {}}, open(path, 'w'))
                print('patched', path)
        except: pass
"
```
The patch reverts on `/plugin update` of FSI — file an issue at https://github.com/anthropics/financial-services-plugins for a permanent fix.

### `"Session not found or expired"` on FMP calls

Known FMP MCP race condition. The pipeline retries automatically; transient errors are normal and don't break analysis.

### `"402 Payment Required"` on some FMP calls

Some small-cap / OTC stocks are outside FMP's free tier. The pipeline handles this gracefully — scores available dimensions, marks the rest N/A with normalized weighting.

### TradingView Desktop tools fail

Open the TradingView Desktop app first, with CDP enabled (the daily script handles this; for interactive use, launch with `--remote-debugging-port=9222`). It's optional — analysis works without it.

### Rate limit errors

FMP free tier is ~250 calls/day. A full `/analyze` uses ~35 calls. Either upgrade FMP, spread requests across the day, or stick to `/portfolio`/`/morning-brief` (lighter touch). Reference budget:

| Action | FMP calls |
|---|---:|
| 1 full `/trading-desk:analyze` | 35–36 |
| 2nd stock (cached session) | 29–30 |
| `/scan watchlist` (23 stocks) | ~164 |
| `/morning-brief` | 25 |

### Daily automation not running

Check the launchd plist is loaded: `launchctl list | grep tradingdesk`. Review `reports/logs/analysis_YYYY-MM-DD.log` for errors. Most common cause: plugin not globally installed — the script will say so and exit.

---

## Alternative install: clone-and-run (developers)

If you want to hack on commands locally without going through `/plugin install`:

```bash
git clone https://github.com/srivardhanjalan/trading-desk.git
cd trading-desk
./setup.sh           # installs everything into mcp-servers/, prompts for keys
./start.sh           # starts FMP server on :8080
claude               # open from this directory
```

This generates a project-local `.mcp.json` and clones MCP servers into `mcp-servers/`. Slash commands work the same — `/trading-desk:analyze AMD` etc. — but commands resolve from `<repo>/trading-desk/commands/` (the plugin source), so any edits show up immediately without `/plugin update`.

Note: if you've also globally installed the plugin, the project-level `.mcp.json` will conflict — pick one path or remove the other's config.

---

## Project structure

```
trading-desk/                                  # repo = MARKETPLACE
├── .claude-plugin/marketplace.json            # marketplace name: srivardhanjalan
│
├── trading-desk/                              # PLUGIN — name: trading-desk
│   ├── .claude-plugin/plugin.json
│   ├── .mcp.json                              # 4 MCPs, ${ENV_VAR} + ${CLAUDE_PLUGIN_ROOT} substitution
│   ├── bin/
│   │   ├── launch-alpaca.sh                   # sources .env, execs uvx alpaca-mcp-server
│   │   ├── launch-tradingview.sh              # execs TV MCP if installed, else no-op MCP server
│   │   └── ensure-tv-desktop.sh               # SessionStart hook: auto-launch TV app if TD_TV_ENABLED=true
│   ├── hooks/hooks.json                       # SessionStart hook wiring (ensure-tv-desktop.sh)
│   ├── commands/                              # 11 /trading-desk:* slash commands
│   ├── lib/                                   # reference docs (loaded via ${CLAUDE_PLUGIN_ROOT}/lib)
│   │   ├── scoring-rubrics.md
│   │   ├── asset-classifier.md
│   │   ├── error-handling.md
│   │   ├── output-formats.md
│   │   ├── no-skip-policy.md
│   │   └── analysis-checklist.md
│   └── skills/setup/SKILL.md                  # /trading-desk:setup — first-run bootstrap (incl. brew install of TV)
│
├── scripts/                                   # daily automation (uses globally-installed plugin)
│   ├── daily-analysis.sh
│   └── com.tradingdesk.daily-analysis.plist   # macOS launchd schedule
├── examples/                                  # user-overridable templates
│   ├── watchlist.csv
│   └── rules.json
├── reports/                                   # analysis output (gitignored, cwd-relative)
├── setup.sh, start.sh                         # legacy clone-and-run path
├── .env.example                               # API key template (uses `export` prefix)
└── .gitignore
```

The repo is structured as a **marketplace** with a single plugin today. Future plugins (e.g. `trading-desk-hooks`, additional skill packs) drop in as siblings of `trading-desk/` with one entry added to `marketplace.json`.

---

## Architecture (one screen)

- **Single-conversation orchestration** — `/trading-desk:analyze` runs all 16 phases inside one Claude Code conversation, with phase results saved to `reports/` so the synthesize step survives context compression.
- **Plugin-prefixed MCP tools** — Claude sees `mcp__plugin_trading-desk_alpaca__*` etc., so commands reference tools by their fully-qualified name and never collide with other plugins.
- **`.env` outside the install dir** — keys live at `~/workspace/secrets/trading-desk/.env`, untouched by `/plugin update`.
- **Wrapper-script credentials** — Alpaca MCP launches via `bin/launch-alpaca.sh`, which sources `.env` itself. No "did you remember to source X?" failure mode.
- **Two-track valuation** — value stocks use DCF + scenario analysis, growth stocks use PEG (auto-detected via revenue growth + P/E gates).
- **Graduated overrides** — overrides aren't binary caps; severity scales (RSI 78 → warning, RSI 88 → block).
- **No-skip enforcement** — every step must complete, fail with a reason, or be marked N/A with justification. Silent skipping triggers a pipeline violation.
- **Completion audit** — pre-output validation checks all phases, all 8 safety overrides, and data coverage before any recommendation reaches you.

---

## License

MIT — see commit history for contributors.

For Claude Code plugin docs: [code.claude.com/docs/en/plugins.md](https://code.claude.com/docs/en/plugins.md)
