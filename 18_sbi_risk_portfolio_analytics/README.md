# P18 — SBI Risk & Portfolio Analytics — VaR, Beta & Correlation

> **Domain:** SBI · Market Risk  ·  **Accent colour:** `CORAL` (#E76F51) — see portfolio
> `COLOR_THEORY.md`

## Business Question
What is SBI's risk profile — volatility, downside risk (VaR), market beta and diversification behaviour vs peers and global markets?

## Data Sources (real, downloaded)
Reserve Bank of India — *Handbook of Statistics on Indian Economy* (2025-26). Real XLSX tables downloaded from `rbidocs.rbi.org.in` (HBS table numbers cited in `data_lake/rbi_hbs_index.json`).

Yahoo Finance — SBIN.NS (State Bank of India, NSE) daily OHLCV 2010–2026 and reported financial statements; peer & global bank financials; NIFTY/SENSEX/S&P 500 benchmarks; USD/INR, USD/JPY.

| Dataset | Grain | Rows |
|---|---|---|
| `px_sbin` | Yahoo Finance (market lake) | daily | 4163 |
| `px_nifty` | Yahoo Finance (market lake) | daily | 4142 |
| `px_peers_in` | Yahoo Finance (market lake) | daily | 4163 |
| `px_sp500` | Yahoo Finance (market lake) | daily | 4243 |

## Deliverables
| Artefact | Path | Notes |
|---|---|---|
| Tidy data | `data/` | analysis-ready CSV extracts |
| SQL suite | `sql/schema.sql` | warehouse DDL, project marts, DQ gate |
| SQL analytics | `sql/analysis_queries.sql` | 14 verified queries (CTE, window, YoY, regimes) |
| Query evidence | `sql/query_results/` + `sql/verification.log` | every query executed on SQLite warehouse |
| Python analysis | `python/analysis.py` | KPIs, diagnostics, regime statistics |
| Analysis outputs | `python/output/` | `analysis.json`, `summary.md` |
| Excel workbook | `excel/*.xlsx` | cover, KPIs, data, derived analysis, native charts |
| Dashboard | `dashboard/index.html` | colour-theory HTML dashboard (Chart.js) |

## SQL Focus
return distributions, volatility clustering, correlation matrix vs peers, risk-adjusted returns

## Key Figures (computed from data)
- **Annualised Volatility** — 24.20 %
- **Beta vs NIFTY** — 0.88 x
- **95% Daily VaR** — -2.19 %
- **Max Drawdown (10Y)** — -59.49 %

## How to Reproduce
```bash
# from the portfolio root (financial_projects/)
python3 scripts/fetch_rbi.py        # RBI Handbook of Statistics XLSX tables
python3 scripts/fetch_market.py     # Yahoo Finance market & financials
python3 scripts/prepare_data.py     # tidy datasets
python3 scripts/build_warehouse.py  # SQLite warehouse
python3 scripts/build_sql.py        # per-project SQL suites
python3 scripts/run_sql.py          # execute & verify every query
python3 scripts/build_python.py     # generate + run project analyses
python3 scripts/build_excel.py      # formatted workbooks
python3 scripts/build_dashboards.py # HTML dashboards
python3 scripts/build_readme.py     # this file
```

---
Part of the **RBI–SBI Financial Analytics** portfolio (18 projects) prepared for
Ashutosh Aher — Business Analyst portfolio, 2026.
