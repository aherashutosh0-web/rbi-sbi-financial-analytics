# P07 — Asset Quality Dashboard — NPAs & Capital Adequacy (CRAR)

> **Domain:** Banking Sector · Risk & Regulation  ·  **Accent colour:** `CORAL` (#E76F51) — see portfolio
> `COLOR_THEORY.md`

## Business Question
How healthy are bank assets across ownership groups, and is the system's capital buffer distribution improving?

## Data Sources (real, downloaded)
Reserve Bank of India — *Handbook of Statistics on Indian Economy* (2025-26). Real XLSX tables downloaded from `rbidocs.rbi.org.in` (HBS table numbers cited in `data_lake/rbi_hbs_index.json`).

| Dataset | Grain | Rows |
|---|---|---|
| `npa_bank_group` | RBI HBS Table **50** | annual | 12 |
| `crar_distribution` | RBI HBS Table **51** | annual | 13 |

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
NPA deterioration/improvement flags, bank-group ranking, provisioning coverage gaps

## Key Figures (computed from data)
- **System Gross NPA %** — 2.60 %
- **System Net NPA %** — 0.50 %
- **SBI Group Gross NPA %** — n/a %
- **Banks above 10% CRAR** — 77.00 count

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
