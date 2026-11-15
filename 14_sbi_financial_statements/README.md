# P14 — SBI Financial Statement Analysis (Consolidated)

> **Domain:** SBI · Financial Performance  ·  **Accent colour:** `BLUE` (#2D4E8F) — see portfolio
> `COLOR_THEORY.md`

## Business Question
How are SBI's revenue, profitability, balance-sheet strength and shareholder returns evolving year over year?

## Data Sources (real, downloaded)
Yahoo Finance — SBIN.NS (State Bank of India, NSE) daily OHLCV 2010–2026 and reported financial statements; peer & global bank financials; NIFTY/SENSEX/S&P 500 benchmarks; USD/INR, USD/JPY.

| Dataset | Grain | Rows |
|---|---|---|
| `fin_sbin_annual` | Yahoo Finance (market lake) | annual | 5 |
| `px_sbin` | Yahoo Finance (market lake) | daily | 4163 |

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
growth rates, margin decomposition, leverage and return ratios, EPS/valuation bridge

## Key Figures (computed from data)
- **Total Revenue (₹)** — 2,602,451,277,000 ₹
- **Net Income (₹)** — 832,987,824,000 ₹
- **Total Assets (₹)** — 83,215,685,742,000 ₹
- **ROE** — 13.97 %

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
