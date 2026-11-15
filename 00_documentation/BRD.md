# Business Requirements Document (BRD)
## RBI–SBI Financial Analytics Platform
**Version** 1.0 · **Date** November 2026 · **Prepared by** Ashutosh Aher (Business Analyst)
**Status** Baseline

---

## 1. Purpose
Establish a governed, reproducible analytics platform that turns **real RBI and SBI
market data** into 18 industrial-grade analysis projects (SQL · Python · Excel ·
dashboards) usable for banking-domain decision support, reporting and portfolio
demonstration.

## 2. Business Objectives
| ID | Objective | Measure of Success |
|---|---|---|
| BO-1 | Single source of truth for RBI macro/banking + SBI market data | 100% datasets versioned in `data_lake/` with source citations |
| BO-2 | Analysis ready for stakeholder consumption | 18 projects each shipping SQL + Python + Excel + dashboard |
| BO-3 | Query logic provably correct | Every SQL query executed against a warehouse (252/252 pass) |
| BO-4 | Consistent, accessible visual language | One colour system (WCAG AA) across all 18 dashboards |
| BO-5 | Reproducibility | One-command rebuild via `scripts/run_all.py` |

## 3. Stakeholders
- **Primary:** Portfolio reviewers / hiring managers (Business Analyst roles)
- **Secondary:** Banking analytics teams, risk & treasury consumers
- **Data owners:** Reserve Bank of India (HBS publications); Yahoo Finance (market data)

## 4. Scope
### In scope
- Download of 37 RBI Handbook of Statistics tables (real XLSX) and 17+ market series
- ETL to tidy analytical datasets; SQLite analytical warehouse
- 18 projects: monetary policy, money stock, inflation, credit & deposits, sectoral
  credit, balance-sheet ratios, NPAs & CRAR, forex reserves, FX & NEER/REER, digital
  payments, interest-rate structure, capital markets, SBI stock analytics, SBI
  financial statements, SBI quarterly performance, Indian peer benchmarking,
  global banking benchmarking, SBI risk analytics
- Per project: SQL suite (DDL + 14 analytic queries), Python analysis, formatted
  Excel workbook, HTML dashboard

### Out of scope
- Real-time streaming / intrustry feeds
- Credit-risk model development, IFRS9 provisioning engines
- Regulatory submissions

## 5. Requirements Summary (MoSCoW)
### Must have
- M1 Data lineage: every dataset records source table numbers and frequency
- M2 SQL layer: star-flavoured warehouse, marts as views, data-quality gates
- M3 KPI layer: computed figures identical across Python, Excel and dashboard
- M4 Dashboards: colour-theory palette, KPI cards, ≥3 charts each
- M5 Verification artefacts: query logs, analysis JSON, QA columns

### Should have
- S1 Derived risk metrics (VaR, beta, drawdowns) for SBI
- S2 Cross-market currency normalisation for global benchmarking
- S3 BA documentation set (BRD/RTM/UAT) demonstrating lifecycle coverage

### Could have
- C1 Automated nightly refresh via scheduler
- C2 Power BI .pbix templates mirroring the HTML dashboards

## 6. Assumptions & Constraints
- RBI HBS tables are periodic publications; datasets reflect publication vintage
- Yahoo fundamentals are limited to ~5 annual and ~5–7 quarterly periods per symbol
  (source API constraint, documented per project)
- The rbidocs CDN serves an F5 JS challenge; automated downloads use a real browser
  engine (`scripts/fetch_rbi_browser.py`)

## 7. Business Data Dictionary (extract — full list in `data_dictionary.md`)
| Field | Unit | Example | Source |
|---|---|---|---|
| `period` | FY `YYYY-YY` / `YYYY-MM` / ISO date | `2024-25` | all datasets |
| `repo_rate` | % | 5.25 | RBI HBS T40 |
| `m3` | ₹ crore | 2,55,00,000 | RBI HBS T36 |
| `gross_npa_to_advances_pct_sbi_group` | % | 1.5 | RBI HBS T50 |
| `total_reserves_usd_mn` | US$ mn | 6,72,587 | RBI HBS T215 |
| `upi_volume_mn` | million txns | 1,31,129 | RBI HBS T58 |
| `close` | ₹ / index points | 812.4 | Yahoo Finance SBIN.NS |
| `var_95_pct` | % daily return | -2.31 | derived (historical VaR) |

## 8. Acceptance Criteria (summary)
- AC-1 All 37 RBI source files are real XLSX (magic `PK`) with sizes recorded
- AC-2 `run_sql.py` reports 252/252 queries PASS
- AC-3 Each project folder contains `data/ sql/ python/ excel/ dashboard/ README.md`
- AC-4 Dashboards render with `COLOR_THEORY.md` palette and pass contrast checks
- AC-5 Rebuild from scratch reproduces outputs within published tolerances

## 9. Sign-off
| Role | Name | Date |
|---|---|---|
| Business Analyst | Ashutosh Aher | 2026-11-14 |
| (Reviewer) | _pending_ | |
