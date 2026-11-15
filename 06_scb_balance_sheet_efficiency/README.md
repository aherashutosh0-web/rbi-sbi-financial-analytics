# P06 — SCB Consolidated Balance Sheet & Efficiency Ratios

> **Domain:** Banking Sector · Financial Health  ·  **Accent colour:** `BLUE` (#2D4E8F) — see portfolio
> `COLOR_THEORY.md`

## Business Question
How efficient is the banking system — balance-sheet structure, intermediation ratios and investment mix — and where is it trending?

## Data Sources (real, downloaded)
Reserve Bank of India — *Handbook of Statistics on Indian Economy* (2025-26). Real XLSX tables downloaded from `rbidocs.rbi.org.in` (HBS table numbers cited in `data_lake/rbi_hbs_index.json`).

| Dataset | Grain | Rows |
|---|---|---|
| `scb_balance_sheet` | RBI HBS Table **49** | annual | 20 |
| `scb_ratios` | RBI HBS Table **233** | annual | 62 |

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
ratio trends, structural balance-sheet change, efficiency benchmarking

## Key Figures (computed from data)
- **Total Liabilities (₹ cr)** — 31,218,250 ₹ cr
- **Deposits (₹ cr)** — 7,942,827 ₹ cr
- **Credit–Deposit Ratio** — 81.44 %
- **Investments–Deposit Ratio** — 26.54 %

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
