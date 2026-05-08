# Trading Desk

Institutional-grade stock analysis and paper trading system powered by [Claude Code](https://claude.ai/code) project commands. Connects 4 MCP servers to deliver a 16-phase analysis pipeline with 8-dimension scoring, position sizing, and actionable BUY/SELL/HOLD recommendations.

## Quick Start

```bash
git clone https://github.com/srivardhanjalan/trading-desk.git
cd trading-desk
./setup.sh          # installs everything, prompts for API keys
./start.sh          # starts FMP server (run before each session)
claude               # open Claude Code
```

Then try:
```
/project:morning-brief
/project:analyze AMD
/project:scan watchlist
```

## Prerequisites

| Requirement | Version | How to Install |
|-------------|---------|----------------|
| Node.js | 18+ | [nodejs.org](https://nodejs.org) |
| Python | 3.10+ | [python.org](https://python.org) |
| Claude Code | latest | `npm install -g @anthropic-ai/claude-code` |

`setup.sh` automatically installs [uv](https://docs.astral.sh/uv/) (Python package manager) if missing.

## API Keys (Free)

You need 2 API keys — both are free:

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
| `/project:analyze SYMBOL` | Full 16-phase analysis with 8-dimension scoring | 55-73 |
| `/project:analyze-technical SYMBOL` | Technical only (price, indicators, volume, chart) | 9-21 |
| `/project:analyze-fundamental SYMBOL` | Fundamental only (macro, financials, valuation) | 23 |
| `/project:analyze-sentiment SYMBOL` | Sentiment, options, insiders, backtesting | 24-30 |
| `/project:synthesize SYMBOL` | Score and recommend (reads phase reports) | 3-8 |
| `/project:scan watchlist` | Scan default 16-stock watchlist | ~131 |
| `/project:scan discover` | Find new stocks via FMP screener | ~64 |
| `/project:scan AAPL,MSFT,NVDA` | Scan specific symbols | varies |
| `/project:portfolio` | Alpaca portfolio dashboard + risk flags | 12+ |
| `/project:trade buy AMD 1000` | Paper trade with safety checks | 6 |
| `/project:morning-brief` | Daily market briefing | 32 |
| `/project:research SYMBOL` | Deep web research (social, NLP, M&A) | 15 |
| `/project:compare AMD NVDA` | Side-by-side comparison | 18 |

## The 16-Phase Pipeline

`/project:analyze SYMBOL` runs these phases in a single conversation:

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

## MCP Servers

| Server | Type | Managed By | What It Does |
|--------|------|-----------|--------------|
| [TradingView Desktop](https://github.com/tradesdontlie/tradingview-mcp) | stdio | Claude Code | Chart control, Pine Script, screenshots, order book |
| [TradingView Analysis](https://pypi.org/project/tradingview-mcp-server/) | stdio | Claude Code | Screener, multi-TF analysis, sentiment, backtesting |
| [Financial Modeling Prep](https://github.com/imbenrabi/Financial-Modeling-Prep-MCP-Server) | HTTP | `./start.sh` | Fundamentals, ratios, DCF, insiders, congress, macro |
| [Alpaca](https://pypi.org/project/alpaca-mcp-server/) | stdio | Claude Code | Paper trading, options chains, portfolio, corporate actions |

TradingView Desktop is **optional** — the analysis works without it. If TradingView Desktop app is open, you get chart screenshots, order book data, and strategy cross-validation. Otherwise those phases are skipped gracefully.

## Asset Support

| Type | Detection | Behavior |
|------|-----------|----------|
| Stock | Default | Full 16 phases |
| Crypto | Symbol ends in USDT/USD | Reduced to 5 scoring dimensions |
| ETF | `isEtf=true` | Fund holdings/sector weighting instead of financials |
| ADR | `isAdr=true` | Adds FX risk assessment |
| OTC | Pink Sheets exchange | Warns limited data, blocks trading |

## Watchlist

Default 23 stocks: `ALMU, AMD, AMPX, ASX, BBAI, BE, CDNS, CRDO, FIX, FLTCF, GEV, INFQ, KGS, KLTR, LAW, NOK, NOW, NVT, OTLK, PLTR, RBLX, SATS, VXRT`

## FMP Budget

Free tier: ~250 calls/day.

| Usage | FMP Calls |
|-------|-----------|
| 1 full `/analyze` | 33-34 |
| 2nd stock (cached session) | 29-30 |
| `/scan watchlist` (16 stocks) | 99 |
| `/morning-brief` | 25 |
| Typical day | ~210 |

## Project Structure

```
trading-desk/
├── .claude/commands/           # Claude Code project commands
│   ├── analyze.md              # /project:analyze — full 16-phase orchestrator
│   ├── analyze-technical.md    # /project:analyze-technical
│   ├── analyze-fundamental.md  # /project:analyze-fundamental
│   ├── analyze-sentiment.md    # /project:analyze-sentiment
│   ├── synthesize.md           # /project:synthesize
│   ├── scan.md                 # /project:scan
│   ├── portfolio.md            # /project:portfolio
│   ├── trade.md                # /project:trade
│   ├── morning-brief.md        # /project:morning-brief
│   ├── research.md             # /project:research
│   ├── compare.md              # /project:compare
│   └── _shared/                # Reference files read by commands
│       ├── scoring-rubrics.md
│       ├── asset-classifier.md
│       ├── error-handling.md
│       └── output-formats.md
├── reports/                    # Analysis output (gitignored)
│   └── scores.csv              # Score history
├── mcp-servers/                # Installed by setup.sh (gitignored)
├── setup.sh                    # One-command setup
├── start.sh                    # Start/stop FMP server
├── .env.example                # API key template
├── .mcp.json.example           # MCP config template
├── rules.json                  # Trading strategy config
├── PLAN.md                     # Full implementation plan (v5)
└── README.md
```

## Troubleshooting

**Commands don't appear in Claude Code:**
Make sure you're running Claude Code from the `trading-desk/` directory. Commands show as `/project:analyze`, etc.

**FMP tools return errors:**
Run `./start.sh --status` to check if the FMP server is running. Run `./start.sh` to start it.

**"402 Payment Required" on some FMP calls:**
Some small-cap/OTC stocks are outside FMP's free tier. The system handles this gracefully — it scores available dimensions and marks others N/A.

**TradingView Desktop tools fail:**
Open TradingView Desktop app first. It's optional — analysis works without it.

**Rate limit errors:**
FMP free tier allows ~250 calls/day. A full `/analyze` uses 33-34 calls. Spread usage across the day or upgrade your FMP plan.

## Architecture

- **Single-conversation model:** `/project:analyze` runs all 16 phases in one Claude Code conversation
- **File-based context management:** Each phase group writes results to `reports/`. The synthesize phase reads these files, surviving context compression.
- **Session caching:** VIX, treasury rates, and market risk premium are cached across multiple analyses in a session
- **Two-track valuation:** Value stocks use DCF, growth stocks use PEG ratio (auto-detected)
- **Graduated overrides:** No binary caps — RSI 78 gets a warning, RSI 88 gets blocked
