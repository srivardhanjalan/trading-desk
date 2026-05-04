# Asset Classifier Reference

Determines stock vs crypto vs ETF vs ADR vs OTC and routes phases accordingly.

---

## Detection Logic

Run after `getCompanyProfile` response is available (Phase 1):

1. **Crypto**: Symbol ends in USDT or USD AND matches crypto pattern (BTCUSDT, ETHUSDT, etc.)
2. **ETF**: `companyProfile.isEtf = true`
3. **ADR**: `companyProfile.isAdr = true` OR `companyProfile.country != "US"`
4. **OTC**: Exchange = OTC, Pink Sheets, or OTCQX/OTCQB
5. **Stock** (default): Everything else on major exchanges (NYSE, NASDAQ, AMEX)

---

## Phase Routing

### Stock (default) — All 16 phases, all tools

### Crypto
- Phase 1: `getCryptocurrencyQuote` + `getCryptocurrencyHistoricalLightChart` + `Alpaca: get_crypto_snapshot` instead of stock equivalents
- **Skip Phases:** 2 (Macro/Sector), 7 (Fundamentals), 8 (Peers), 9 DCF portion, 12 (Institutional), 13 (Earnings)
- Phase 9: Skip DCF/custom DCF. Use price target only if available
- Phase 10: Crypto options if available, else skip
- Phase 11: `market_sentiment` + `multi_agent_analysis` + `searchCryptoNews` + `WebSearch` Twitter. Skip insider/congressional/corporate actions
- **Scoring:** Use crypto weight redistribution (Technical 35%, Smart Money 25%, Risk 20%, Backtest 12%, Sentiment 8%)
- **Crypto Smart Money signals:** Exchange volume (smart_volume_scanner), options flow if available, WebSearch whale wallet movements, funding rate

### ETF
- Phase 7: Replace with `getFundHoldings` + `getFundSectorWeighting` + `getFundInfo`
- **Skip Phases:** 8 (Peers), 12 (Institutional), 13 (Earnings)
- Phase 9: Skip DCF. Use price target only if available
- Phase 2: The ETF IS the sector — compare to SPY instead

### ADR
- All phases run normally
- Phase 15: Add FX risk assessment (currency exposure based on home country)
- Risk modifier: currency volatility adds to position sizing calculation

### OTC
- Warn: "OTC stock — limited data expected, higher risk"
- Block `/trade` command (no paper trading OTC)
- All phases still called — handle empty responses per error protocol
- Likely "Minimal" tier in FMP (many calls will 402)
