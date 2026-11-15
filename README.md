# RBI–SBI Financial Analytics Portfolio
### 18 industry-grade data projects · Real RBI + SBI data · SQL · Python · Excel · Dashboards

**Prepared for:** Ashutosh Aher — Business Analyst / Business Analytics portfolio (Nov 2026)
**Data provenance:** 100% real, downloaded data — no synthetic series.

| Source | What | How it was downloaded |
|---|---|---|
| **Reserve Bank of India** — Handbook of Statistics on Indian Economy (2025-26) | 37 published XLSX tables (monetary policy, money stock, inflation, bank credit & deposits, NPAs/CRAR, forex reserves, FX rates, NEER/REER, payments, interest rates, capital markets) | `scripts/fetch_rbi_browser.py` — real Chromium against `rbidocs.rbi.org.in` (the CDN fronts an F5 JS challenge) |
| **Yahoo Finance** — SBIN.NS (State Bank of India, NSE/BSE) | 16 years of daily OHLCV (2010–2026), dividends, reported annual & quarterly financials; peers (HDFC, ICICI, Kotak, Axis, BoB, PNB); global banks (JPMorgan, HSBC, Barclays, Citi, MUFG, BofA); NIFTY/SENSEX/S&P 500; USD/INR & USD/JPY | `scripts/fetch_market.py` — chart & fundamentals-timeseries APIs |

**Verification at a glance**
- 37/37 RBI files authentic XLSX · 42 warehouse tables · 31,000+ rows
- **252/252 SQL analytic queries executed & passing** (see each `sql/verification.log`)
- 18 Python analyses executed (`python/output/analysis.json`)
- 18 formatted Excel workbooks (native charts, colour-theory styling)
- 18 HTML dashboards — one design system ("Central Bank Blue", WCAG AA) documented
  in [`COLOR_THEORY.md`](COLOR_THEORY.md)

---

## Project Index

| # | Project | Domain | Accent |
|---|---|---|---|
| P01 | [RBI Monetary Policy & Reserve Requirements Tracker](01_rbi_monetary_policy_rates/) | Monetary policy | 🔵 Blue |
| P02 | [Money Stock & Monetary Aggregates (M1–M3)](02_money_stock_monetary_aggregates/) | Monetary economics | 🔵 Blue |
| P03 | [Inflation Monitor — CPI & WPI](03_inflation_monitor_cpi_wpi/) | Prices | 🟢 Teal |
| P04 | [SCB Credit & Deposit Growth Engine](04_scb_credit_deposit_growth/) | Bank balance sheets | 🔵 Blue |
| P05 | [Sectoral Deployment of Bank Credit](05_sectoral_credit_deployment/) | Credit allocation | 🟢 Teal |
| P06 | [SCB Balance Sheet & Intermediation Ratios](06_scb_balance_sheet_efficiency/) | Financial health | 🔵 Blue |
| P07 | [Asset Quality — NPAs & CRAR](07_asset_quality_npa_crar/) | Risk & regulation | 🟠 Coral |
| P08 | [Forex Reserves Monitor](08_forex_reserves_monitor/) | External sector | 🟡 Amber |
| P09 | [INR Exchange Rate & NEER/REER Analytics](09_inr_exchange_rate_neer_reer/) | FX | 🟡 Amber |
| P10 | [Digital Payments & UPI Tracker](10_digital_payments_upi/) | Payments | 🟢 Teal |
| P11 | [Interest Rate Structure & Transmission](11_interest_rate_structure/) | Rates | 🟣 Violet |
| P12 | [Indian Capital Market Context](12_indian_capital_market_context/) | Benchmarks | 🟣 Violet |
| P13 | [SBI Stock Price & Technical Analysis](13_sbi_stock_technical_analysis/) | SBI equity | 🟡 Amber |
| P14 | [SBI Financial Statement Analysis](14_sbi_financial_statements/) | SBI performance | 🔵 Blue |
| P15 | [SBI Quarterly Performance Tracker](15_sbi_quarterly_performance/) | Earnings quality | 🟡 Amber |
| P16 | [Indian Banking Peer Benchmarking](16_indian_banking_peer_benchmarking/) | Competition | 🟢 Teal |
| P17 | [SBI vs Global Banking Giants](17_sbi_vs_global_banking_giants/) | Global benchmarking | 🟤 Sand |
| P18 | [SBI Risk & Portfolio Analytics](18_sbi_risk_portfolio_analytics/) | Market risk | 🟠 Coral |

## Standard Project Structure
```
<project>/
├── README.md              business question, data sources, computed KPIs, reproduce steps
├── data/                  tidy CSV extracts (analysis-ready)
├── sql/
│   ├── schema.sql         warehouse DDL, project marts (views), data-quality gate
│   ├── analysis_queries.sql   14 analytic queries (CTEs, window fns, YoY, regimes)
│   ├── query_results/     Q01..Q14 result CSVs (evidence)
│   └── verification.log   PASS/FAIL execution log
├── python/
│   ├── analysis.py        KPIs + series diagnostics (reproducible)
│   ├── requirements.txt
│   └── output/            analysis.json + summary.md
├── excel/                 formatted workbook: Read Me · KPIs · Data · Analysis · Charts
└── dashboard/index.html   colour-theory dashboard (Chart.js)
```

## Portfolio-Level Artefacts
- [`00_documentation/`](00_documentation/) — BRD, Requirements Traceability Matrix, UAT plan (20 test cases)
- [`data_dictionary.md`](data_dictionary.md) — every dataset & column, units, derivations
- [`COLOR_THEORY.md`](COLOR_THEORY.md) — dashboard design system & accessibility maths
- [`warehouse/rbi_sbi_warehouse.db`](warehouse/) — SQLite analytical warehouse (42 tables)
- [`scripts/`](scripts/) — fetch · prepare · build · verify pipeline

## Reproduce Everything
```bash
python3 scripts/fetch_rbi_browser.py   # 37 RBI HBS XLSX (browser bypasses JS challenge)
python3 scripts/fetch_market.py        # Yahoo Finance market lake
python3 scripts/prepare_data.py        # tidy datasets
python3 scripts/build_warehouse.py     # SQLite warehouse
python3 scripts/build_sql.py           # SQL suites
python3 scripts/run_sql.py             # execute & verify 252 queries
python3 scripts/build_python.py        # generate + run 18 analyses
python3 scripts/build_excel.py         # 18 workbooks
python3 scripts/build_dashboards.py    # 18 dashboards
python3 scripts/build_readme.py        # project READMEs
# or simply:
python3 scripts/run_all.py
```

## Business-Analysis Methodology Note
Each project is delivered the way a BA deliverable should be: a stated business
question, cited data sources with lineage (RBI table numbers), machine-verified
evidence (query logs, analysis JSON, QA reconciliation columns), traceability
(`00_documentation/RTM.md`) and acceptance-tested outputs (`UAT_plan.md`).
