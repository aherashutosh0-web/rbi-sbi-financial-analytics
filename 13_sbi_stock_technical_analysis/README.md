# P13 — SBI Stock Price & Technical Analysis (SBIN.NS)

> **Domain:** SBI · Equity Markets  ·  **Accent colour:** `AMBER` (#E9A23B) — see portfolio
> `COLOR_THEORY.md`

## Business Question
What are SBI stock's return, trend and volatility characteristics over 16 years, and where does momentum stand today?

## Data Sources (real, downloaded)
Yahoo Finance — SBIN.NS (State Bank of India, NSE) daily OHLCV 2010–2026 and reported financial statements; peer & global bank financials; NIFTY/SENSEX/S&P 500 benchmarks; USD/INR, USD/JPY.

| Dataset | Grain | Rows |
|---|---|---|
| `px_sbin` | Yahoo Finance (market lake) | daily | 4163 |
| `px_nifty` | Yahoo Finance (market lake) | daily | 4142 |

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
| Dashboard build | `scripts/build_dashboards.py` | optional local HTML output; not committed |

## SQL Focus
returns, moving-average crossovers, 52-week extremes, drawdown events, volume spikes

## Key Figures (computed from data)
- **SBIN Close (latest)** — 1,080.00 ₹
- **SBIN 1Y Return** — -0.01 %
- **52W High** — 1,234.70 ₹
- **10Y CAGR** — 1.06 %

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
python3 scripts/build_dashboards.py # optional local HTML output (ignored by Git)
python3 scripts/build_readme.py     # this file
```

---
Part of the **RBI–SBI Financial Analytics** portfolio (18 projects) prepared for
Ashutosh Aher — Business Analyst portfolio, 2026.
