# Trading Desk

Institutional-grade stock analysis and paper trading, packaged as a [Claude Code](https://claude.ai/code) plugin. Connects 4 MCP servers to deliver a 16-phase analysis pipeline with 8-dimension scoring, position sizing, and actionable BUY/SELL/HOLD recommendations.

## Quick Start (recommended — plugin install)

In any Claude Code session:

```
/plugin marketplace add srivardhanjalan/trading-desk
/plugin install trading-desk@srivardhanjalan
/trading-desk:setup
```

The `setup` skill prompts for your FMP and Alpaca keys, writes them to `~/workspace/secrets/trading-desk/.env`, clones the optional TradingView Desktop MCP into `${CLAUDE_PLUGIN_DATA}`, and starts the FMP server.

Then in a new shell:
```bash
source ~/workspace/secrets/trading-desk/.env
claude
```

And try:
```
/trading-desk:morning-brief
/trading-desk:analyze AMD
/trading-desk:scan watchlist
```

## Alternative: clone-and-run (no plugin)

```bash
git clone https://github.com/srivardhanjalan/trading-desk.git
cd trading-desk
./setup.sh          # installs everything, prompts for API keys
./start.sh          # starts FMP server (run before each session)
claude              # open Claude Code from this directory
```

Slash commands work the same — `/trading-desk:analyze AMD` etc. Use this path if you want to hack on commands locally without installing a plugin.

## Prerequisites

| Requirement | Version | How to Install |
|-------------|---------|----------------|
| Node.js | 18+ | [nodejs.org](https://nodejs.org) |
| Python | 3.10+ | [python.org](https://python.org) |
| Claude Code | latest | `npm install -g @anthropic-ai/claude-code` |

`setup.sh` automatically installs [uv](https://docs.astral.sh/uv/) (Python package manager) if missing.

## API Keys (Free)

You need 2 API keys — both have free tiers:

| Service | What For | Sign Up |
|---------|----------|---------|
| **Financial Modeling Prep** | Fundamentals, DCF, earnings, insiders, macro | [financialmodelingprep.com/developer](https://financialmodelingprep.com/developer) |
| **Alpaca** | Paper trading, options chains, portfolio | [app.alpaca.markets/signup](https://app.alpaca.markets/signup) |

`setup.sh` will prompt for these, or you can pre-fill `.env`:
```bash
cp .env.example .env
# edit .env with your keys
./setup.sh --from-env
```

## What `setup.sh` Does

1. Checks Node.js, Python, and uv are installed
2. Installs uv if missing
3. Clones [TradingView Desktop MCP](https://github.com/tradesdontlie/tradingview-mcp) and runs `npm install`
4. Pre-fetches Python MCP packages (TradingView Analysis, Alpaca)
5. Installs FMP MCP server via npm
6. Prompts for API keys (or reads from `.env`)
7. Generates `.mcp.json` (project-level MCP config for Claude Code)
8. Creates `reports/` directory for analysis output

After setup, 3 of 4 MCP servers are auto-managed by Claude Code (started on demand). Only the FMP server needs to be started manually with `./start.sh`.

## Commands

| Command | Description | ~Tool Calls |
|---------|-------------|-------------|
| `/trading-desk:analyze SYMBOL` | Full 16-phase analysis with 8-dimension scoring | 55-73 |
| `/trading-desk:analyze-technical SYMBOL` | Technical only (price, indicators, volume, chart) | 9-21 |
| `/trading-desk:analyze-fundamental SYMBOL` | Fundamental only (macro, financials, valuation) | 23 |
| `/trading-desk:analyze-sentiment SYMBOL` | Sentiment, options, insiders, backtesting | 24-30 |
| `/trading-desk:synthesize SYMBOL` | Score and recommend (reads phase reports) | 3-8 |
| `/trading-desk:scan watchlist` | Scan all stocks in `watchlist.csv` | ~131 |
| `/trading-desk:scan discover` | Find new stocks via FMP screener | ~64 |
| `/trading-desk:scan AAPL,MSFT,NVDA` | Scan specific symbols | varies |
| `/trading-desk:portfolio` | Alpaca portfolio dashboard + risk flags | 12+ |
| `/trading-desk:trade buy AMD 1000` | Paper trade with safety checks | 6 |
| `/trading-desk:morning-brief` | Daily market briefing | 32 |
| `/trading-desk:research SYMBOL` | Deep web research (social, NLP, M&A) | 15 |
| `/trading-desk:compare AMD NVDA` | Side-by-side comparison | 18 |

## The 16-Phase Pipeline

`/trading-desk:analyze SYMBOL` runs these phases in a single conversation:

| Phase | What | Key Tools |
|-------|------|-----------|
| 0 | Asset classification + market status | Alpaca clock |
| 1 | Price, identity, bid/ask spread | FMP profile, Alpaca snapshot |
| 2 | Macro: sector, rates, VIX | FMP treasury, sector ETF, VIX |
| 3 | Multi-timeframe technicals | TV-Analysis: 5 timeframes + daily indicators |
| 4 | Volume + smart money signals | FMP float, TV-Analysis smart volume |
| 5 | Candle pattern recognition | TV-Analysis candle patterns |
| 6 | TradingView Desktop chart + screenshot | TV Desktop (optional) |
| 7 | Fundamentals: Piotroski, Z-Score, FCF | FMP: 10 parallel calls |
| 8 | Peer comparison | FMP peers + batch quotes |
| 9 | Valuation: 3 DCF models + PEG + analysts | FMP: DCF, levered DCF, custom DCF |
| 10 | Options flow: 10 derived metrics | Alpaca options chain + bars |
| 11 | Sentiment: Reddit + Twitter + StockTwits + news NLP | TV-Analysis + WebSearch + WebFetch |
| 12 | Institutional ownership (13F) | FMP positions summary |
| 13 | Earnings transcript NLP (conditional) | FMP transcript |
| 14 | Strategy backtesting + cross-validation | TV-Analysis + TV Desktop |
| 15 | Risk quantification + position sizing | Alpaca account + derived calcs |
| 16 | Synthesis: 8 dimensions, weighted composite, recommendation | Scoring rubrics |

### Track A vs Track B Valuation

Stocks are automatically classified into valuation tracks:

- **Track A (Value):** Revenue growth ≤20% and P/E ≤40 → uses DCF valuation with 3 scenario models (bull/base/bear) via `calculateCustomDCF`
- **Track B (Growth):** Revenue growth >20% or P/E >40 → uses PEG ratio instead of DCF

Track A stocks always receive a Scenario DCF analysis with probability-weighted bull, base, and bear cases using varying revenue growth, terminal growth, and tax rates.

## Scoring System

8 dimensions scored 1-10, weighted composite 0-100:

| Dimension | Weight | Source |
|-----------|--------|--------|
| Technical | 22% | Multi-TF alignment, RSI, MACD, ADX, candles |
| Fundamental | 15% | Revenue growth, margins, Z-Score, Piotroski |
| Valuation | 15% | 3 DCF models, PEG (growth stocks), analyst targets |
| Smart Money | 13% | Insiders, congress, institutional, options flow |
| Risk | 12% | Beta, IV/HV, earnings proximity, bid/ask spread |
| Backtest | 10% | Strategy win rate, Sharpe, walk-forward validation |
| Sentiment | 7% | Reddit, Twitter, StockTwits, news NLP |
| Macro | 6% | Sector rotation, VIX, treasury rates |

| Score | Signal | Action |
|-------|--------|--------|
| >= 75 | STRONG BUY | Aggressive sizing |
| 60-74 | BUY | Standard sizing |
| 40-59 | HOLD | No new position |
| 25-39 | SELL | Reduce/exit |
| < 25 | STRONG SELL | Exit immediately |

Safety overrides: graduated overbought penalty, beta-conditional VIX panic, cross-dimension conflict detection, R:R ratio check, data completeness gate.

## No-Skip Policy

Every analysis step must end in one of three states — silent skipping is a pipeline violation:

| Status | Meaning |
|--------|---------|
| **COMPLETED** | Step ran successfully with data |
| **FAILED** | Step was attempted but errored (reason logged) |
| **N/A** | Step doesn't apply to this asset type (justification logged) |

The pipeline enforces this across all phases. Steps that are **never optional** include:
- Custom DCF + Scenario DCF (Track A) or PEG (Track B)
- XBRL data extraction (`getFinancialStatementFullAsReported`)
- Beneish M-Score calculation
- All 8 safety overrides
- 10b5-1 plan verification for insider trades
- News NLP sentiment scoring
- Peer comparison

A **completion audit** runs before final output, verifying all phases completed and logging any violations:
```
Pipeline: PASS | Phases: 4/4 complete | Overrides: 8/8 evaluated | Data: 95%
```

## MCP Servers

| Server | Type | Managed By | What It Does |
|--------|------|-----------|--------------|
| [TradingView Desktop](https://github.com/tradesdontlie/tradingview-mcp) | stdio | Claude Code | Chart control, Pine Script, screenshots, order book |
| [TradingView Analysis](https://pypi.org/project/tradingview-mcp-server/) | stdio | Claude Code | Screener, multi-TF analysis, sentiment, backtesting |
| [Financial Modeling Prep](https://github.com/imbenrabi/Financial-Modeling-Prep-MCP-Server) | HTTP | `./start.sh` | Fundamentals, ratios, DCF, insiders, congress, macro |
| [Alpaca](https://pypi.org/project/alpaca-mcp-server/) | stdio | Claude Code | Paper trading, options chains, portfolio, corporate actions |

TradingView Desktop is **optional** — the analysis works without it. If the TradingView Desktop app is open, you get chart screenshots, order book data, and strategy cross-validation. Otherwise those phases are skipped gracefully.

### Known Issue: FMP Session Race Condition

Some FMP tools (`getFinancialStatementFullAsReported`, `calculateCustomDCF`) fail with "Session not found" when batched with many parallel calls due to a toolception v0.6.3 LRU cache collision. The pipeline handles this by calling these tools **sequentially** after other FMP calls complete, with a retry-once protocol on session errors.

## Asset Support

| Type | Detection | Behavior |
|------|-----------|----------|
| Stock | Default | Full 16 phases |
| Crypto | Symbol ends in USDT/USD | Reduced to 5 scoring dimensions |
| ETF | `isEtf=true` | Fund holdings/sector weighting instead of financials |
| ADR | `isAdr=true` | Adds FX risk assessment |
| OTC | Pink Sheets exchange | Warns limited data, blocks trading |

## Watchlist

The default watchlist ships at `examples/watchlist.csv` (one symbol per line). To customize:

- **Plugin users:** copy it to your working directory: `cp ~/.claude/plugins/marketplaces/srivardhanjalan/trading-desk/examples/watchlist.csv ./watchlist.csv` (or just create `watchlist.csv` in the dir where you launch claude). Commands look for `watchlist.csv` in cwd.
- **Clone-and-run users:** edit `examples/watchlist.csv` directly (or create your own at the repo root).

Default watchlist (23 stocks):
```
ALMU, AMD, AMPX, ASX, BBAI, BE, CDNS, CRDO, FIX, FLTCF, GEV,
INFQ, KGS, KLTR, LAW, NOK, NOW, NVT, OTLK, PLTR, RBLX, SATS, VXRT
```

## Daily Automation

The `scripts/` directory contains automation for nightly analysis:

### `daily-analysis.sh`

Runs a full `/trading-desk:analyze` on every stock in `watchlist.csv` using `claude -p` (non-interactive mode).

- Launches TradingView Desktop with CDP (port 9222) for chart screenshots
- Starts FMP server via `start.sh`
- Analyzes each stock sequentially with `--max-budget-usd 8` per stock
- Extracts composite score and signal from each analysis
- Generates a daily summary report using Sonnet
- Cleans up TradingView and FMP server if it started them

### `com.tradingdesk.daily-analysis.plist`

macOS launchd plist that schedules `daily-analysis.sh` to run at **12:15 AM** daily. Catches up on missed runs if the Mac was asleep.

**Install:**
```bash
cp scripts/com.tradingdesk.daily-analysis.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.tradingdesk.daily-analysis.plist
```

**Uninstall:**
```bash
launchctl unload ~/Library/LaunchAgents/com.tradingdesk.daily-analysis.plist
rm ~/Library/LaunchAgents/com.tradingdesk.daily-analysis.plist
```

**Logs:** `reports/logs/analysis_YYYY-MM-DD.log`

## FMP Budget

| Plan | Rate Limit | Daily Cap |
|------|-----------|-----------|
| Free | ~5 calls/sec | ~250 calls/day |
| Paid | 300 calls/min | No daily cap |

| Usage | FMP Calls |
|-------|-----------|
| 1 full `/analyze` | 33-34 |
| 2nd stock (cached session) | 29-30 |
| `/scan watchlist` (23 stocks) | ~164 |
| `/morning-brief` | 25 |

On the free tier, spread usage across the day. The paid tier has no daily cap — the nightly automation script runs comfortably under the 300/min rate limit.

## Project Structure

```
trading-desk/                                  # repo root = MARKETPLACE
├── .claude-plugin/
│   └── marketplace.json                       # marketplace name: "srivardhanjalan"
│
├── trading-desk/                              # PLUGIN — name: "trading-desk"
│   ├── .claude-plugin/plugin.json
│   ├── .mcp.json                              # 4 MCP servers, ${ENV_VAR} substitution
│   ├── commands/                              # /trading-desk:* slash commands
│   │   ├── analyze.md                         # /trading-desk:analyze — orchestrator
│   │   ├── analyze-technical.md
│   │   ├── analyze-fundamental.md
│   │   ├── analyze-sentiment.md
│   │   ├── synthesize.md
│   │   ├── scan.md
│   │   ├── portfolio.md
│   │   ├── trade.md
│   │   ├── morning-brief.md
│   │   ├── research.md
│   │   └── compare.md
│   ├── lib/                                   # reference docs (loaded via ${CLAUDE_PLUGIN_ROOT}/lib)
│   │   ├── scoring-rubrics.md                 # 8-dimension scoring definitions
│   │   ├── asset-classifier.md                # Stock/crypto/ETF/ADR detection
│   │   ├── error-handling.md                  # FMP tier-aware degradation + retry
│   │   ├── output-formats.md                  # Templates for all output types
│   │   ├── no-skip-policy.md                  # Pipeline completeness enforcement
│   │   └── analysis-checklist.md              # Pre-output completion audit
│   └── skills/setup/SKILL.md                  # /trading-desk:setup — first-run bootstrap
│
├── scripts/                                   # Automation (used by clone-and-run path)
│   ├── daily-analysis.sh                      # Nightly full-watchlist analysis
│   └── com.tradingdesk.daily-analysis.plist   # macOS launchd schedule
├── examples/                                  # User-overridable templates
│   ├── watchlist.csv                          # Default watchlist (one symbol per line)
│   └── rules.json                             # Default trading strategy config
├── reports/                                   # Analysis output (gitignored, cwd-relative)
│   ├── scores.csv                             # Score history across runs
│   └── logs/                                  # Daily automation logs
├── setup.sh                                   # Legacy (clone-and-run) install
├── start.sh                                   # Start/stop FMP server (legacy path)
├── .env.example                               # API key template
└── .gitignore
```

**Two install modes coexist:**
- **Plugin install** (`/plugin install trading-desk@srivardhanjalan`) — clean, updates via `/plugin update`. The setup skill writes `.env` to `~/workspace/secrets/trading-desk/.env` and the plugin's MCP servers read keys via `${ALPACA_API_KEY}` etc. from your shell env at startup.
- **Clone-and-run** (`./setup.sh`) — for hacking on commands locally. Uses repo-local `.mcp.json` and `mcp-servers/` clones.

## Troubleshooting

**Commands don't appear in Claude Code:**
- Plugin install: confirm with `/plugin` that `trading-desk@srivardhanjalan` is enabled. Try `/plugin install trading-desk@srivardhanjalan` again.
- Clone-and-run: launch claude from inside the cloned `trading-desk/` directory (the new `commands/` lives under `trading-desk/`, not `.claude/`).

**MCP servers report missing keys (`401`/`403`):**
The plugin reads `${ALPACA_API_KEY}` etc. from shell env at startup (not at tool-call time). Source `.env` in the shell that launches claude:
```bash
source ~/workspace/secrets/trading-desk/.env
claude
```

**Important:** the `.env` file must use `export KEY=value` syntax (not plain `KEY=value`) — otherwise plain `source` only sets shell vars, not env vars, and subprocess MCP servers won't see them. The setup skill / `setup.sh` writes `.env` correctly. If you have an old `.env` without `export`, regenerate it OR source with `set -a; source .env; set +a`.

**FMP tools return errors:**
Run `./start.sh --status` (clone-and-run path) or check `${CLAUDE_PLUGIN_DATA}/fmp.log` (plugin path). Re-run `/trading-desk:setup` if needed.

**"Session not found or expired" on FMP calls:**
This is a known race condition with toolception's LRU cache. The pipeline handles it automatically by retrying once after 2 seconds and calling affected tools sequentially.

**"402 Payment Required" on some FMP calls:**
Some small-cap/OTC stocks are outside FMP's free tier. The system handles this gracefully — it scores available dimensions and marks others N/A with normalized weighting.

**TradingView Desktop tools fail:**
Open the TradingView Desktop app first. It's optional — analysis works without it.

**Rate limit errors:**
FMP free tier allows ~250 calls/day. A full `/analyze` uses 33-34 calls. Upgrade your FMP plan for unlimited daily usage, or spread requests across the day.

**Automation not running:**
Check that the launchd plist is loaded: `launchctl list | grep tradingdesk`. Review logs at `reports/logs/`.

## Architecture

- **Single-conversation model:** `/trading-desk:analyze` runs all 16 phases in one Claude Code conversation
- **File-based context management:** Each phase group writes results to `reports/`. The synthesize phase reads these files, surviving context compression
- **Session caching:** VIX, treasury rates, and market risk premium are cached across multiple analyses in a session
- **Two-track valuation:** Value stocks use DCF with scenario analysis; growth stocks use PEG ratio (auto-detected)
- **Graduated overrides:** No binary caps — RSI 78 gets a warning, RSI 88 gets blocked
- **No-skip enforcement:** Every step must complete, fail with a reason, or be marked N/A with justification — silent skipping triggers a pipeline violation
- **Completion audit:** Pre-output validation checks all phases, overrides, and data coverage before generating the final recommendation
