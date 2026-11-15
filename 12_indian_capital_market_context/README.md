# P12 — Indian Capital Market Context — SENSEX & NIFTY

> **Domain:** Capital Markets · Benchmarks  ·  **Accent colour:** `VIOLET` (#7E57C2) — see portfolio
> `COLOR_THEORY.md`

## Business Question
What is the equity-market backdrop — levels, returns and volatility—against which SBI's valuation must be judged?

## Data Sources (real, downloaded)
Reserve Bank of India — *Handbook of Statistics on Indian Economy* (2025-26). Real XLSX tables downloaded from `rbidocs.rbi.org.in` (HBS table numbers cited in `data_lake/rbi_hbs_index.json`).

Yahoo Finance — SBIN.NS (State Bank of India, NSE) daily OHLCV 2010–2026 and reported financial statements; peer & global bank financials; NIFTY/SENSEX/S&P 500 benchmarks; USD/INR, USD/JPY.

| Dataset | Grain | Rows |
|---|---|---|
| `market_indices_annual` | RBI HBS Table **85** | annual | 29 |
| `nifty_monthly` | RBI HBS Table **182** | monthly | 99 |
| `sensex_monthly` | RBI HBS Table **183** | monthly | 63 |
| `px_nifty` | Yahoo Finance (market lake) | daily | 4142 |
| `px_sensex` | Yahoo Finance (market lake) | daily | 4147 |

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
benchmark returns, drawdowns, monthly momentum, valuation regime classification

## Key Figures (computed from data)
- **NIFTY 50 (latest)** — 25,144.30 index
- **SENSEX (latest)** — 81,592.45 index
- **NIFTY 1Y Return** — -0.01 %
- **Avg Market Cap (₹ cr)** — 24,946,852 ₹ cr

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
