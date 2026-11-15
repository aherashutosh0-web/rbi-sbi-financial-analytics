# UAT Plan & Test Cases
## RBI–SBI Financial Analytics Platform · v1.0

**UAT entry criteria:** all builds green (warehouse, SQL, Python, Excel, dashboards)
**Exit criteria:** 20/20 test cases pass; defects triaged

| TC ID | Test Case | Steps | Expected Result | Status |
|---|---|---|---|---|
| TC-01 | Source authenticity | inspect `data_lake/rbi/*.xlsx` magic bytes | all 37 files start with `PK` (real XLSX) | ✅ |
| TC-02 | Source freshness | check latest periods in `policy_rates`, `forex_weekly` | ≥ 2025 data present | ✅ |
| TC-03 | Warehouse load | `build_warehouse.py` | 42 tables, catalog row counts match CSVs | ✅ |
| TC-04 | SQL suite execution | `run_sql.py` | 252/252 queries PASS | ✅ |
| TC-05 | SQL evidence | open any `sql/query_results/Q03.csv` | non-empty result set | ✅ |
| TC-06 | KPI parity | compare `analysis.json` KPI vs Excel "KPI Summary" vs dashboard card | identical values | ✅ |
| TC-07 | Period-aware YoY | P03 CPI KPI (monthly) | computed vs 12-months-ago value | ✅ |
| TC-08 | Derived QA column | `scb_balance_sheet.total_liabilities_check` vs `total_liabilities` | equal within rounding | ✅ |
| TC-09 | FX normalisation | P17 SBI assets US$ bn | ≈ INR assets ÷ USD/INR ÷ 1e9 | ✅ |
| TC-10 | JPY conversion | P17 MUFG assets US$ bn | ≈ ¥ assets ÷ USDJPY ÷ 1e9 (2.6–2.8 tn scale) | ✅ |
| TC-11 | Excel opens cleanly | open any workbook | sheets: Read Me, KPI Summary, Data, Analysis, Charts | ✅ |
| TC-12 | Excel charts native | check Charts sheet | ≥2 openpyxl charts with palette colours | ✅ |
| TC-13 | Dashboard renders | open `dashboard/index.html` | KPI cards + 3 charts visible | ✅ |
| TC-14 | Colour theory applied | inspect dashboard CSS vars | palette tokens from `common/palette.py` | ✅ |
| TC-15 | Contrast (WCAG AA) | `palette.contrast_ratio()` on text pairs | ≥ 4.5:1 body, ≥ 3:1 display | ✅ |
| TC-16 | Reproducibility | rerun `prepare_data.py` | deterministic outputs (row counts stable) | ✅ |
| TC-17 | README completeness | open each project README | business question, sources, KPIs, reproduce steps | ✅ |
| TC-18 | SQL quality | review `analysis_queries.sql` | CTEs, window functions, CASE regimes, DQ checks | ✅ |
| TC-19 | Data dictionary | `data_dictionary.md` covers delivered columns | unit suffixes consistent (`_pct`, `_usd_mn`, `_inr_crore`) | ✅ |
| TC-20 | BA artefacts | BRD/RTM/UAT present and consistent | traceability complete | ✅ |

**Defects raised during UAT (closed):**
1. D-01 RBI CDN returns HTML JS-challenge instead of XLSX → mitigated by real-browser downloader
2. D-02 SQLite lacks `STDEV` → portable stddev expression in SQL generator
3. D-03 openpyxl rejects NaN/6-hex colours → cell sanitiser + aRGB helper

**Sign-off:** _pending reviewer_
