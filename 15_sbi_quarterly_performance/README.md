# P15 — SBI Quarterly Performance Tracker

> **Domain:** SBI · Earnings Quality  ·  **Accent colour:** `AMBER` (#E9A23B) — see portfolio
> `COLOR_THEORY.md`

## Business Question
Is quarterly earnings momentum stable — sequential growth, margin trajectory and provisioning discipline?

## Data Sources (real, downloaded)
Yahoo Finance — SBIN.NS (State Bank of India, NSE) daily OHLCV 2010–2026 and reported financial statements; peer & global bank financials; NIFTY/SENSEX/S&P 500 benchmarks; USD/INR, USD/JPY.

| Dataset | Grain | Rows |
|---|---|---|
| `fin_sbin_quarterly` | Yahoo Finance (market lake) | quarterly | 6 |

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
QoQ/YoY sequential analysis, 4-quarter rolling aggregates, earnings surprise flags

## Key Figures (computed from data)
- **Latest Quarterly Revenue (₹)** — 705,974,800,000 ₹
- **Latest Quarterly Net Income (₹)** — 253,611,600,000 ₹
- **QoQ Revenue Growth** — -0.02 %
- **Avg Quarterly Net Margin** — 32.06 %

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
