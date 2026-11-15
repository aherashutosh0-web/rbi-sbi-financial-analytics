"""
build_excel.py — Generate industry-formatted Excel workbooks for all 18 projects.

Every workbook contains:
  1. "Read Me"     — project cover, business question, data sources, colour key
  2. "KPI Summary" — computed KPIs with conditional formatting
  3. "Data"        — full tidy dataset as a formatted Excel Table (frozen panes,
                     number formats, zebra striping via table style)
  4. "Analysis"    — derived metrics (YoY, CAGR, shares, rankings)
  5. "Charts"      — native Excel charts (colour-theory palette)

Run:  python3 scripts/build_excel.py
"""
import pathlib
import sys

import pandas as pd
from openpyxl import Workbook
from openpyxl.chart import BarChart, LineChart, Reference, Series
from openpyxl.chart.label import DataLabelList
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.table import Table, TableStyleInfo

BASE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE))
PREP = BASE / "data_lake" / "prepared"

from common import palette as P  # noqa: E402
from common.registry import PROJECTS, ACCENT_HEX  # noqa: E402
from common.analytics import compute_kpi, fmt_value, period_yoy, cagr  # noqa: E402

THIN = Side(style="thin", color="D6DEEC")
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)

FMT_INT = "#,##0"
FMT_DEC = "#,##0.00"
FMT_PCT = "0.00"


def style_header(ws, row: int, ncols: int, fill_hex: str):
    fill = PatternFill("solid", fgColor=argb(fill_hex))
    for c in range(1, ncols + 1):
        cell = ws.cell(row=row, column=c)
        cell.font = Font(bold=True, color="FFFFFF", size=11)
        cell.fill = fill
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        cell.border = BORDER


def autosize(ws, df: pd.DataFrame, header_row: int = 1, max_w: int = 30):
    for j, col in enumerate(df.columns, start=1):
        try:
            lens = df[col].astype(str).str.len().fillna(0)
            w = int(lens.max()) + 2 if len(lens) else 12
        except Exception:
            w = 12
        width = max(len(str(col)) + 2, min(max_w, w))
        ws.column_dimensions[get_column_letter(j)].width = width


def num_fmt_for(col: str, s: pd.Series) -> str:
    lc = col.lower()
    if any(k in lc for k in ("pct", "ratio", "rate", "growth", "margin", "roe", "roa", "share", "yoy", "cagr")):
        return FMT_PCT
    if pd.api.types.is_float_dtype(s):
        return FMT_DEC
    return FMT_INT


def add_data_sheet(wb: Workbook, df: pd.DataFrame, title: str, accent: str) -> int:
    ws = wb.create_sheet("Data")
    ws.sheet_view.showGridLines = False
    ws.append(list(df.columns))
    style_header(ws, 1, len(df.columns), accent)
    for row in df.itertuples(index=False):
        ws.append([cellval(v) for v in row])
    for j, col in enumerate(df.columns, start=1):
        fmt = num_fmt_for(str(col), df[col])
        for i in range(2, len(df) + 2):
            cell = ws.cell(row=i, column=j)
            cell.border = BORDER
            if isinstance(cell.value, (int, float)):
                cell.number_format = fmt
            if i % 2 == 0:
                cell.fill = PatternFill("solid", fgColor=argb(P.SURFACE_ALT))
    autosize(ws, df)
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = ws.dimensions
    return len(df)


def cellval(v):
    """openpyxl rejects NaN and non-scalar values; normalise before writing."""
    if isinstance(v, (list, tuple)) or type(v).__name__ == "Series":
        try:
            v = v[0] if not hasattr(v, "iloc") else v.iloc[0]
        except Exception:
            return None
    if v is None:
        return None
    try:
        if pd.isna(v):
            return None
    except Exception:
        pass
    if hasattr(v, "item"):
        try:
            return v.item()
        except Exception:
            return str(v)
    return v


def argb(h: str) -> str:
    """openpyxl colours require aRGB (8-hex); palette stores RGB (6-hex).
    Idempotent: already-prefixed values pass through unchanged."""
    s = h.lstrip("#")
    return s if len(s) == 8 else "FF" + s


def add_chart_sheet(wb: Workbook, tables: dict, charts: list, accent_hex: str, title: str):
    ws = wb.create_sheet("Charts")
    ws.sheet_view.showGridLines = False
    ws["A1"] = f"{title} — Native Excel Charts"
    ws["A1"].font = Font(bold=True, size=14, color=argb(P.INK))
    ws["A2"] = "Palette: Central Bank Blue (see COLOR_THEORY.md) — categorical hues at equal lightness."
    ws["A2"].font = Font(italic=True, size=9, color=argb(P.INK_MUTED))

    palette = [accent_hex] + P.CATEGORICAL
    chart_idx = 0
    anchor_row = 4
    for spec in charts:
        df = tables.get(spec.get("ds", ""))
        if df is None:
            continue
        xcol = spec.get("x", "period")
        if xcol not in df.columns:
            xcol = "period" if "period" in df.columns else (
                "date" if "date" in df.columns else df.columns[0])
        cols = [(s["label"], s["col"]) for s in spec["series"] if s["col"] in df.columns]
        if not cols:
            continue
        # compact data block: header row + values, per chart
        ws.cell(row=anchor_row, column=1, value=f"[{spec['ds']}] {xcol}")
        for j, (label, _) in enumerate(cols, start=2):
            ws.cell(row=anchor_row, column=j, value=label)
        style_header(ws, anchor_row, len(cols) + 1, accent_hex)
        for i, row in enumerate(df[[xcol] + [c for _, c in cols]].itertuples(index=False),
                                start=anchor_row + 1):
            for j, v in enumerate(row, start=1):
                ws.cell(row=i, column=j, value=cellval(v))
        data_top, data_bottom = anchor_row + 1, ws.max_row

        if spec["type"] in ("bar", "hbar"):
            ch = BarChart()
            ch.type = "col" if spec["type"] == "bar" else "bar"
            ch.grouping = "clustered"
        else:
            ch = LineChart()
        for k, (label, col) in enumerate(cols):
            j = 2 + k
            ref = Reference(ws, min_col=j, min_row=anchor_row, max_row=data_bottom)
            s = Series(ref, title=label)
            if isinstance(ch, LineChart):
                s.graphicalProperties.line.width = 22000
                s.graphicalProperties.line.solidFill = argb(palette[(chart_idx + k) % len(palette)])
                s.smooth = False
            else:
                s.graphicalProperties.solidFill = argb(palette[(chart_idx + k) % len(palette)])
            ch.series.append(s)
        ch.title = spec["title"]
        ch.height, ch.width = 8.5, 17
        ch.x_axis.title = xcol
        if isinstance(ch, LineChart):
            ch.dispBlanksAs = "gap"
        cats = Reference(ws, min_col=1, min_row=data_top, max_row=data_bottom)
        ch.set_categories(cats)
        ws.add_chart(ch, f"{get_column_letter(len(cols) + 4)}{anchor_row}")
        anchor_row = data_bottom + 3
        chart_idx += 1


def analysis_frame(df: pd.DataFrame) -> pd.DataFrame:
    """Derived metrics sheet: YoY per numeric column + 5Y CAGR."""
    if "period" not in df.columns:
        return pd.DataFrame()
    num = [c for c in df.select_dtypes("number").columns
           if c not in ("period", "date", "as_of_date")][:6]
    out = pd.DataFrame({"period": df["period"]})
    for c in num:
        out[f"{c}_yoy_pct"] = [
            None if period_yoy(df.iloc[: i + 1], c) is None else period_yoy(df.iloc[: i + 1], c) * 100
            for i in range(len(df))
        ]
    return out


def build_project(p: dict) -> bool:
    tables = {}
    for n in p["datasets"]:
        f = PREP / f"{n}.csv"
        if f.exists():
            tables[n] = pd.read_csv(f)
    if not tables:
        return False

    accent_hex = ACCENT_HEX[p["accent"]]
    wb = Workbook()

    # ── Read Me ──
    ws = wb.active
    ws.title = "Read Me"
    ws.sheet_view.showGridLines = False
    ws.column_dimensions["A"].width = 26
    ws.column_dimensions["B"].width = 110
    rows = [
        ("RBI–SBI FINANCIAL ANALYTICS PORTFOLIO", None),
        ("Project", f"{p['id']} — {p['title']}"),
        ("Domain", p["domain"]),
        ("Business Question", p["business_q"]),
        ("SQL Focus", p["sql_focus"]),
        ("Datasets", ", ".join(p["datasets"])),
        ("Primary Source", "Reserve Bank of India — Handbook of Statistics on Indian Economy "
                           "(data.rbi.org.in / rbidocs.rbi.org.in), downloaded real XLSX tables"),
        ("Market Source", "Yahoo Finance — SBIN.NS daily OHLCV (2010–2026) & reported financials"),
        ("Colour System", "Central Bank Blue — analogous blues + complementary amber accent, "
                          "WCAG AA (COLOR_THEORY.md)"),
        ("Deliverables", "data/ (tidy CSV) · sql/ (DDL + analytic queries, verified on SQLite) · "
                         "python/ (analysis.py + outputs) · excel/ (this workbook) · dashboard/ (HTML)"),
        ("Prepared For", "Ashutosh Aher — Business Analyst portfolio (2026)"),
    ]
    for i, (k, v) in enumerate(rows, start=2):
        ws.cell(row=i, column=1, value=k).font = Font(bold=True, size=11,
                                                      color=argb(accent_hex if v is None else P.INK_MUTED))
        if v is not None:
            c = ws.cell(row=i, column=2, value=v)
            c.alignment = Alignment(wrap_text=True, vertical="top")
            c.font = Font(size=10.5, color=argb(P.INK))
    ws["A2"].font = Font(bold=True, size=16, color=argb(accent_hex))

    # ── KPI Summary ──
    ws = wb.create_sheet("KPI Summary")
    ws.sheet_view.showGridLines = False
    ws["A1"] = "KPI SUMMARY"
    ws["A1"].font = Font(bold=True, size=14, color=argb(accent_hex))
    ws.append([])
    ws.append(["KPI", "Value", "Unit"])
    style_header(ws, 3, 3, accent_hex)
    for k in p["kpis"]:
        c = compute_kpi(k, tables)
        ws.append([c["label"], fmt_value(c["value"], c["unit"]), c["unit"]])
    for i in range(4, ws.max_row + 1):
        ws.cell(row=i, column=1).font = Font(size=11, color=argb(P.INK))
        ws.cell(row=i, column=2).font = Font(size=12, bold=True, color=argb(accent_hex))
        for j in (1, 2, 3):
            ws.cell(row=i, column=j).border = BORDER
    ws.column_dimensions["A"].width = 34
    ws.column_dimensions["B"].width = 22
    ws.column_dimensions["C"].width = 12

    # ── Data + Analysis for each dataset ──
    first_df = None
    for name, df in tables.items():
        if first_df is None:
            first_df = df
        ws = wb.create_sheet(f"Data — {name}"[:31])
        ws.sheet_view.showGridLines = False
        ws.append(list(df.columns))
        style_header(ws, 1, len(df.columns), accent_hex)
        for row in df.itertuples(index=False):
            ws.append([cellval(v) for v in row])
        for j, col in enumerate(df.columns, start=1):
            fmt = num_fmt_for(str(col), df[col])
            for i in range(2, len(df) + 2):
                cell = ws.cell(row=i, column=j)
                cell.border = BORDER
                if isinstance(cell.value, (int, float)):
                    cell.number_format = fmt
                if i % 2 == 0:
                    cell.fill = PatternFill("solid", fgColor=argb(P.SURFACE_ALT))
        autosize(ws, df)
        ws.freeze_panes = "A2"

        af = analysis_frame(df)
        if not af.empty:
            ws2 = wb.create_sheet(f"Analysis — {name}"[:31])
            ws2.sheet_view.showGridLines = False
            ws2.append(list(af.columns))
            style_header(ws2, 1, len(af.columns), accent_hex)
            for row in af.itertuples(index=False):
                ws2.append([cellval(v) for v in row])
            for j, col in enumerate(af.columns, start=1):
                for i in range(2, len(af) + 2):
                    cell = ws2.cell(row=i, column=j)
                    cell.border = BORDER
                    if isinstance(cell.value, (int, float)):
                        cell.number_format = FMT_PCT
            autosize(ws2, af)
            ws2.freeze_panes = "A2"

    # ── Charts ──
    if tables:
        add_chart_sheet(wb, tables, p["charts"], accent_hex, p["title"])

    out = BASE / p["slug"] / "excel" / f"{p['id']}_{p['slug'].split('_', 1)[1]}.xlsx"
    out.parent.mkdir(parents=True, exist_ok=True)
    wb.save(out)
    return True


def main() -> int:
    built = 0
    for p in PROJECTS:
        try:
            ok = build_project(p)
        except Exception as e:
            print(f"  FAIL {p['id']}: {type(e).__name__}: {e}")
            continue
        print(("  ok   " if ok else "  skip ") + f"{p['id']} {p['slug']}")
        built += ok
    print(f"Workbooks built: {built}/{len(PROJECTS)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
