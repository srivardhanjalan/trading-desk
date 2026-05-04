# Trading Desk

Institutional-grade stock analysis and paper trading system powered by Claude Code project commands with 4 MCP servers.

## Commands

| Command | Description | Tool Calls |
|---------|-------------|------------|
| `/project:analyze SYMBOL` | Full 16-phase analysis pipeline with 8-dimension scoring | ~55-73 |
| `/project:analyze-technical SYMBOL` | Technical analysis only (Phases 0,1,3,4,5,6) | ~9-21 |
| `/project:analyze-fundamental SYMBOL` | Fundamental analysis only (Phases 2,7,8,9) | ~23 |
| `/project:analyze-sentiment SYMBOL` | Sentiment, options, backtesting (Phases 10-14) | ~24-30 |
| `/project:synthesize SYMBOL` | Score and recommend (reads phase reports) | ~3-8 |
| `/project:scan watchlist` | Scan 16-stock watchlist, ranked table | ~131 |
| `/project:scan discover` | Find new stocks via screener | ~64 |
| `/project:portfolio` | Alpaca portfolio dashboard with risk flags | ~12+ |
| `/project:trade buy SYMBOL AMOUNT` | Paper trade with safety checks | ~6 |
| `/project:morning-brief` | Daily market briefing | ~32 |
| `/project:research SYMBOL` | Deep web research (social, NLP, M&A) | ~15 |
| `/project:compare SYM1 SYM2` | Side-by-side comparison | ~18 |

## MCP Servers Required

1. **TradingView Desktop** — 78 tools for chart control, Pine Script, screenshots, replay
2. **TradingView Analysis** — Server-side screener, multi-timeframe analysis, sentiment, backtesting
3. **Financial Modeling Prep (FMP)** — Fundamentals, ratios, DCF, peers, insiders, congress, earnings, macro
4. **Alpaca** — Paper trading ($100K), positions, orders, option chains, portfolio history

## Scoring System

8 dimensions scored 1-10, weighted composite 0-100:

| Dimension | Weight | Source |
|-----------|--------|--------|
| Technical | 22% | Multi-TF alignment, RSI, MACD, ADX, candles |
| Fundamental | 15% | Revenue growth, margins, Z-Score, Piotroski |
| Valuation | 15% | DCF (3 models), PEG, analyst targets |
| Smart Money | 13% | Insiders, congress, institutional, options flow |
| Risk | 12% | Beta, IV/HV, earnings proximity, spread |
| Backtest | 10% | Strategy win rate, Sharpe, walk-forward |
| Sentiment | 7% | Reddit, Twitter, StockTwits, news NLP |
| Macro | 6% | Sector rotation, VIX, treasury rates |

### Signals

| Score | Signal |
|-------|--------|
| >= 75 | STRONG BUY |
| 60-74 | BUY |
| 40-59 | HOLD |
| 25-39 | SELL |
| < 25 | STRONG SELL |

## Setup

1. Clone this repo
2. Configure MCP servers in your Claude Code settings (see `.claude/settings.json` or `mcp_config.json`)
3. Set environment variables for API keys (FMP, Alpaca)
4. Open Claude Code in this directory
5. Run `/project:morning-brief` to verify everything works

## Watchlist

Default 16 stocks: ALMU, AMD, CRDO, FIX, ASX, KLTR, FLTCF, NVT, CDNS, AMPX, BBAI, LAW, SATS, GEV, BE, KGS

## Architecture

- **Single-conversation model:** `/project:analyze` runs all 16 phases in one conversation
- **File-based context management:** Phase results saved to `reports/` — survives context compression
- **Asset routing:** Auto-detects stock/crypto/ETF/ADR/OTC and adjusts phases accordingly
- **Session caching:** VIX, treasury rates, market risk premium cached across multiple analyses
- **FMP budget:** ~33-34 calls per full analysis, ~250/day free tier
