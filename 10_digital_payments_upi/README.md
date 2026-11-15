# P10 — Digital Payments & UPI Transformation Tracker

> **Domain:** Banking Sector · Payments  ·  **Accent colour:** `TEAL` (#2A9D8F) — see portfolio
> `COLOR_THEORY.md`

## Business Question
How fast is the payments ecosystem digitising —UPI, cards, NEFT/RTGS—and what does volume/value growth mean for transaction banking?

## Data Sources (real, downloaded)
Reserve Bank of India — *Handbook of Statistics on Indian Economy* (2025-26). Real XLSX tables downloaded from `rbidocs.rbi.org.in` (HBS table numbers cited in `data_lake/rbi_hbs_index.json`).

| Dataset | Grain | Rows |
|---|---|---|
| `payment_systems` | RBI HBS Table **58** | annual | 3 |

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
channel mix shift, growth contribution, digital adoption S-curve tracking

## Key Figures (computed from data)
- **UPI Volume (mn txn)** — n/a mn txn
- **UPI Value (₹ cr)** — n/a ₹ cr
- **UPI Volume YoY** — n/a %
- **Digital Txn CAGR 5Y** — n/a %

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
