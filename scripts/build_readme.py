"""
build_readme.py — Generate per-project README.md files with data-driven
highlights (KPI values pulled from the executed python analyses).

Run:  python3 scripts/build_readme.py
"""
import json
import pathlib
import sys

BASE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE))

from common.registry import PROJECTS, DATASETS, ACCENT_HEX  # noqa: E402

TPL = """# {pid} — {title}

> **Domain:** {domain}  ·  **Accent colour:** `{accent}` ({hex}) — see portfolio
> `COLOR_THEORY.md`

## Business Question
{business_q}

## Data Sources (real, downloaded)
{sources}

| Dataset | Grain | Rows |
|---|---|---|
{ds_rows}

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
{sql_focus}

## Key Figures (computed from data)
{kpis}

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
"""

SRC_RBI = ("Reserve Bank of India — *Handbook of Statistics on Indian Economy* "
           "(2025-26). Real XLSX tables downloaded from `rbidocs.rbi.org.in` "
           "(HBS table numbers cited in `data_lake/rbi_hbs_index.json`).")
SRC_MKT = ("Yahoo Finance — SBIN.NS (State Bank of India, NSE) daily OHLCV "
           "2010–2026 and reported financial statements; peer & global bank "
           "financials; NIFTY/SENSEX/S&P 500 benchmarks; USD/INR, USD/JPY.")


def ds_rows(p: dict) -> str:
    rows = []
    for d in p["datasets"]:
        meta = DATASETS.get(d, {})
        f = BASE / "data_lake" / "prepared" / f"{d}.csv"
        n = sum(1 for _ in open(f)) - 1 if f.exists() else 0
        src = ("RBI HBS Table " + ", ".join(f"**{t}**" for t in meta.get("rbi_tables", []))
               if "rbi_tables" in meta else "Yahoo Finance (market lake)")
        rows.append(f"| `{d}` | {meta.get('freq', '—')} | {n} |")
        rows_src = f"| `{d}` | {src} | {meta.get('freq', '—')} | {n} |"
        rows[-1] = rows_src
    return "\n".join(rows)


def kpi_lines(p: dict) -> str:
    out = []
    f = BASE / p["slug"] / "python" / "output" / "analysis.json"
    if f.exists():
        ins = json.loads(f.read_text())
        for k in ins.get("kpis", []):
            v = k.get("value")
            v = "n/a" if v is None else (f"{v:,.2f}" if abs(v) < 1e6 else f"{v:,.0f}")
            out.append(f"- **{k['label']}** — {v} {k.get('unit', '')}")
    return "\n".join(out) or "_run `python/analysis.py` to compute_"


def main() -> int:
    for p in PROJECTS:
        ds_meta = DATASETS.get(p["datasets"][0], {})
        src = SRC_RBI if "rbi_tables" in ds_meta else SRC_MKT
        srcs = SRC_RBI + "\n\n" + SRC_MKT if len(p["datasets"]) > 3 else src
        md = TPL.format(
            pid=p["id"], title=p["title"], domain=p["domain"],
            accent=p["accent"], hex=ACCENT_HEX[p["accent"]],
            business_q=p["business_q"], sources=srcs,
            ds_rows=ds_rows(p), sql_focus=p["sql_focus"], kpis=kpi_lines(p))
        out = BASE / p["slug"] / "README.md"
        out.write_text(md)
        print(f"  ok   {p['slug']}/README.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
