# P02 — Money Stock & Monetary Aggregates Analytics (M1–M4)

> **Domain:** Macro-Finance · Monetary Economics  ·  **Accent colour:** `BLUE` (#2D4E8F) — see portfolio
> `COLOR_THEORY.md`

## Business Question
How is India's money supply expanding, and which components drive broad-money growth relevant to bank balance-sheet planning?

## Data Sources (real, downloaded)
Reserve Bank of India — *Handbook of Statistics on Indian Economy* (2025-26). Real XLSX tables downloaded from `rbidocs.rbi.org.in` (HBS table numbers cited in `data_lake/rbi_hbs_index.json`).

| Dataset | Grain | Rows |
|---|---|---|
| `money_stock_annual` | RBI HBS Table **36** | annual | 54 |
| `money_stock_monthly` | RBI HBS Table **165** | monthly | 33 |
| `money_sources` | RBI HBS Table **37** | annual | 104 |

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
monetary growth decomposition, contribution analysis, momentum indicators

## Key Figures (computed from data)
- **M3 (₹ cr)** — 31,453,126 ₹ cr
- **M3 YoY Growth** — 2.30 %
- **Currency in Circulation** — 4,065,488 ₹ cr
- **Avg M3 Growth 5Y** — 10.79 %

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
