# P04 — Scheduled Commercial Banks — Credit & Deposit Growth Engine

> **Domain:** Banking Sector · Balance Sheet  ·  **Accent colour:** `BLUE` (#2D4E8F) — see portfolio
> `COLOR_THEORY.md`

## Business Question
Are bank deposits keeping pace with credit demand, and what does the credit–deposit ratio signal for liquidity management?

## Data Sources (real, downloaded)
Reserve Bank of India — *Handbook of Statistics on Indian Economy* (2025-26). Real XLSX tables downloaded from `rbidocs.rbi.org.in` (HBS table numbers cited in `data_lake/rbi_hbs_index.json`).

| Dataset | Grain | Rows |
|---|---|---|
| `scb_aggregates_annual` | RBI HBS Table **41** | annual | 60 |
| `scb_aggregates_monthly` | RBI HBS Table **167** | monthly | 51 |
| `scb_growth` | RBI HBS Table **232** | annual | 55 |

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
YoY growth, rolling CAGR, credit-deposit gap, liquidity stress flags

## Key Figures (computed from data)
- **Aggregate Deposits (₹ cr)** — 6,961,120 ₹ cr
- **Bank Credit (₹ cr)** — 18,243,972 ₹ cr
- **Credit–Deposit Ratio** — 262.08 %
- **Deposit Growth 5Y CAGR** — 9.30 %

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
