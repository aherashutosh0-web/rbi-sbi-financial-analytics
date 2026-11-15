# P03 — Inflation Monitor — CPI & WPI Analytics

> **Domain:** Macro-Finance · Prices  ·  **Accent colour:** `TEAL` (#2A9D8F) — see portfolio
> `COLOR_THEORY.md`

## Business Question
What is the inflation trajectory and CPI–WPI divergence, and how should it inform pricing, provisioning and rate expectations?

## Data Sources (real, downloaded)
Reserve Bank of India — *Handbook of Statistics on Indian Economy* (2025-26). Real XLSX tables downloaded from `rbidocs.rbi.org.in` (HBS table numbers cited in `data_lake/rbi_hbs_index.json`).

Yahoo Finance — SBIN.NS (State Bank of India, NSE) daily OHLCV 2010–2026 and reported financial statements; peer & global bank financials; NIFTY/SENSEX/S&P 500 benchmarks; USD/INR, USD/JPY.

| Dataset | Grain | Rows |
|---|---|---|
| `cpi_annual` | RBI HBS Table **34** | annual | 33 |
| `cpi_monthly` | RBI HBS Table **163** | monthly | 27 |
| `wpi_annual` | RBI HBS Table **33** | annual | 46 |
| `wpi_monthly` | RBI HBS Table **162** | monthly | 39 |
| `inflation_variations` | RBI HBS Table **235**, **236** | annual | 46 |

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
inflation momentum, regime detection (high/moderate/low), CPI–WPI spread analysis

## Key Figures (computed from data)
- **Latest CPI (Index)** — 107.30 index
- **CPI YoY** — 0.04 %
- **Latest WPI (Index)** — 110.20 index
- **CPI–WPI Gap (pp)** — 2.90 pp

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
