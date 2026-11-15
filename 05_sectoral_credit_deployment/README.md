# P05 — Sectoral Deployment of Bank Credit Analysis

> **Domain:** Banking Sector · Credit Risk  ·  **Accent colour:** `TEAL` (#2A9D8F) — see portfolio
> `COLOR_THEORY.md`

## Business Question
Where is bank credit flowing across sectors and industries, and which segments show concentration or acceleration risk?

## Data Sources (real, downloaded)
Reserve Bank of India — *Handbook of Statistics on Indian Economy* (2025-26). Real XLSX tables downloaded from `rbidocs.rbi.org.in` (HBS table numbers cited in `data_lake/rbi_hbs_index.json`).

| Dataset | Grain | Rows |
|---|---|---|
| `credit_sectoral_annual` | RBI HBS Table **42** | annual | 5 |
| `credit_sectoral_monthly` | RBI HBS Table **168** | monthly | 6 |
| `credit_industry_annual` | RBI HBS Table **43** | annual | 5 |

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
sector share shifts, concentration (HHI), acceleration/deceleration ranking

## Key Figures (computed from data)
- **Total Non-Food Credit (₹ cr)** — 21,291,163 ₹ cr
- **Industry Share** — 21.53 %
- **Agriculture Share** — 12.42 %
- **Services Share** — 28.47 %

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
