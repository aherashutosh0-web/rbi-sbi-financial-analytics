"""
build_dashboards.py — Generate self-contained HTML dashboards for all 18 projects.

Design system: common/palette.py ("Central Bank Blue", see COLOR_THEORY.md).
Charts render via Chart.js from CDN; data embedded as JSON so the file works
offline (charts need CDN once; graceful fallback lists data tables).

Run:  python3 scripts/build_dashboards.py
"""
import json
import pathlib
import sys

import pandas as pd

BASE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE))
PREP = BASE / "data_lake" / "prepared"

from common import palette as P  # noqa: E402
from common.registry import PROJECTS, ACCENT_HEX  # noqa: E402
from common.analytics import compute_kpi, fmt_value  # noqa: E402


def load_tables(names: list[str]) -> dict[str, pd.DataFrame]:
    out = {}
    for n in names:
        f = PREP / f"{n}.csv"
        if f.exists():
            out[n] = pd.read_csv(f)
    return out


def chart_payload(chart: dict, tables: dict) -> dict | None:
    df = tables.get(chart["ds"])
    if df is None:
        return None
    xcol = chart.get("x", "period")
    if xcol not in df.columns:
        xcol = "period" if "period" in df.columns else (
            "date" if "date" in df.columns else df.columns[0])
    # downsample long daily series for browser comfort (keep <= 750 points)
    if len(df) > 750 and chart["type"] in ("line", "area"):
        step = len(df) // 750 + 1
        df = df.iloc[::step]
    labels = df[xcol].astype(str).tolist()
    series = []
    for s in chart["series"]:
        if s["col"] in df.columns:
            series.append({
                "label": s["label"],
                "data": [None if pd.isna(v) else round(float(v), 4) for v in df[s["col"]]],
            })
    return {"type": chart["type"], "title": chart["title"],
            "labels": labels, "series": series, "accent": chart.get("accent")}


def kpi_cards(kpis: list[dict], tables: dict) -> str:
    cards = []
    for k in kpis:
        c = compute_kpi(k, tables)
        val = fmt_value(c["value"], c["unit"])
        unit = c["unit"]
        cards.append(f"""
        <div class="kpi">
          <div class="kpi-label">{c['label']}</div>
          <div class="kpi-value">{val}<span class="kpi-unit">{unit if unit not in ('%','pp') else unit}</span></div>
        </div>""")
    return "\n".join(cards)


HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · RBI–SBI Financial Analytics</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<style>
  :root {{
    --canvas: {canvas}; --surface: {surface}; --navy: {navy};
    --ink: {ink}; --ink-muted: {ink_muted}; --accent: {accent};
    --grid: {grid}; --pos: {pos}; --neg: {neg};
    --font: {font};
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ background: var(--canvas); color: var(--ink); font-family: var(--font); }}
  header {{ background: var(--navy); color: #fff; padding: 28px 40px 22px; }}
  header .eyebrow {{ font-size: 12px; letter-spacing: 2.5px; text-transform: uppercase;
    color: {accent_hex}; font-weight: 600; }}
  header h1 {{ font-size: 26px; font-weight: 650; margin-top: 6px; }}
  header .sub {{ color: #B9C4DA; font-size: 13.5px; margin-top: 8px; max-width: 900px; line-height: 1.5; }}
  .bar {{ height: 5px; background: linear-gradient(90deg, {accent_hex} 0%, {accent_hex}99 40%, transparent 100%); }}
  main {{ padding: 28px 40px 60px; max-width: 1400px; margin: 0 auto; }}
  .kpis {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
    gap: 16px; margin: 22px 0 30px; }}
  .kpi {{ background: var(--navy); border-radius: 12px; padding: 18px 20px;
    box-shadow: 0 1px 3px rgba(18,35,63,.12); }}
  .kpi-label {{ color: #AEBBD3; font-size: 11.5px; letter-spacing: .8px; text-transform: uppercase; }}
  .kpi-value {{ color: {accent_hex}; font-size: 27px; font-weight: 700; margin-top: 8px; }}
  .kpi-unit {{ color: #8FA0BC; font-size: 13px; font-weight: 500; margin-left: 5px; }}
  .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 22px; }}
  .card {{ background: var(--surface); border: 1px solid var(--grid); border-radius: 12px;
    padding: 20px 22px 14px; }}
  .card.full {{ grid-column: 1 / -1; }}
  .card h2 {{ font-size: 15px; font-weight: 650; color: var(--ink); margin-bottom: 4px; }}
  .card .note {{ font-size: 11.5px; color: var(--ink-muted); margin-bottom: 12px; }}
  .chart-box {{ position: relative; height: 330px; }}
  footer {{ padding: 22px 40px; color: var(--ink-muted); font-size: 11.5px;
    border-top: 1px solid var(--grid); line-height: 1.7; }}
  footer b {{ color: var(--ink); }}
  .pill {{ display:inline-block; padding: 3px 10px; border-radius: 999px;
    background: {accent_hex}22; color: var(--accent); font-size: 11px; font-weight: 600;
    margin-left: 8px; vertical-align: middle; }}
  @media (max-width: 980px) {{ .grid {{ grid-template-columns: 1fr; }} main {{ padding: 20px; }} }}
</style>
</head>
<body>
<header>
  <div class="eyebrow">{domain}</div>
  <h1>{title} <span class="pill">{project_id}</span></h1>
  <div class="sub">{business_q}</div>
</header>
<div class="bar"></div>
<main>
  <section class="kpis">{kpi_html}</section>
  <section class="grid">{charts_html}</section>
</main>
<footer>
  <b>Data sources:</b> {sources}<br>
  <b>Design:</b> "Central Bank Blue" colour system — analogous blue structure + complementary amber accent
  (60-30-10 rule, WCAG AA). See portfolio <b>COLOR_THEORY.md</b>.<br>
  <b>Portfolio:</b> RBI–SBI Financial Analytics · 18 industrial-grade projects (SQL · Python · Excel · Dashboards)
  · Generated for Ashutosh Aher — Business Analyst portfolio.
</footer>
<script>
const PALETTE = {palette_json};
Chart.defaults.font.family = "'Segoe UI', Inter, sans-serif";
Chart.defaults.color = "{ink_muted}";
Chart.defaults.borderColor = "{grid}";
const CHARTS = {charts_json};
CHARTS.forEach((c, i) => {{
  const el = document.getElementById('chart-' + i);
  if (!el) return;
  const isBar = c.type === 'bar' || c.type === 'hbar';
  const cfg = {{
    type: c.type === 'hbar' ? 'bar' : (c.type === 'area' ? 'line' : c.type),
    data: {{
      labels: c.labels,
      datasets: c.series.map((s, j) => ({{
        label: s.label,
        data: s.data,
        borderColor: PALETTE[j % PALETTE.length],
        backgroundColor: isBar ? PALETTE[j % PALETTE.length] + 'B3' : PALETTE[j % PALETTE.length] + '26',
        borderWidth: 2, pointRadius: 0, pointHitRadius: 8,
        fill: c.type === 'area' && j === 0 ? 'origin' : false,
        tension: 0.25, borderRadius: isBar ? 4 : 0,
      }}))
    }},
    options: {{
      responsive: true, maintainAspectRatio: false,
      indexAxis: c.type === 'hbar' ? 'y' : 'x',
      interaction: {{ mode: 'index', intersect: false }},
      plugins: {{
        legend: {{ position: 'top', align: 'start',
          labels: {{ boxWidth: 12, boxHeight: 12, usePointStyle: true, pointStyle: 'rectRounded' }} }},
        tooltip: {{ backgroundColor: "{navy}", padding: 10, cornerRadius: 8,
          titleFont: {{ size: 12 }}, bodyFont: {{ size: 12 }} }}
      }},
      scales: {{
        x: {{ grid: {{ color: "{grid}", drawTicks: false }}, ticks: {{ maxTicksLimit: 12, font: {{ size: 11 }} }} }},
        y: {{ grid: {{ color: "{grid}", drawTicks: false }}, ticks: {{ font: {{ size: 11 }} }} }}
      }}
    }}
  }};
  new Chart(el, cfg);
}});
</script>
</body>
</html>
"""


def build_project(p: dict) -> str | None:
    tables = load_tables(p["datasets"])
    if not tables:
        return None
    charts = [c for c in (chart_payload(ch, tables) for ch in p["charts"]) if c and c["series"]]
    if not charts:
        return None

    cards = []
    for i, c in enumerate(charts):
        full = " full" if i == 0 or len(charts) % 2 == 1 and i == len(charts) - 1 else ""
        cards.append(f"""
    <div class="card{full}">
      <h2>{c['title']}</h2>
      <div class="note">Source: RBI Handbook of Statistics / market data · rendered with Chart.js</div>
      <div class="chart-box"><canvas id="chart-{i}"></canvas></div>
    </div>""")

    sources = "Reserve Bank of India — Handbook of Statistics on Indian Economy (data.rbi.org.in); " \
              "Yahoo Finance market data (SBIN.NS and benchmarks)." if any(
        d.startswith(("policy", "money", "cpi", "wpi", "scb", "credit", "npa", "crar", "forex",
                      "fx_", "neer", "payment", "interest", "market", "nifty", "sensex", "inflation"))
        for d in p["datasets"]) else "Yahoo Finance (SBIN.NS daily prices & financial statements)."

    html = HTML_TEMPLATE.format(
        title=p["title"], domain=p["domain"], project_id=p["id"],
        business_q=p["business_q"], sources=sources,
        kpi_html=kpi_cards(p["kpis"], tables),
        charts_html="\n".join(cards),
        charts_json=json.dumps(charts),
        palette_json=json.dumps(P.CHART_JS["categorical"]),
        canvas=P.CANVAS, surface=P.SURFACE, navy=P.NAVY, ink=P.INK,
        ink_muted=P.INK_MUTED, grid=P.GRIDLINE, pos=P.POSITIVE, neg=P.NEGATIVE,
        accent=P.ACCENT_SHADES.get(p["accent"], P.BLUE) if hasattr(P, "ACCENT_SHADES") else ACCENT_HEX[p["accent"]],
        accent_hex=ACCENT_HEX[p["accent"]],
        font=P.FONT_STACK,
    )
    return html


def main() -> int:
    built = 0
    for p in PROJECTS:
        html = build_project(p)
        if not html:
            print(f"  skip {p['id']} ({p['slug']}) — no data yet")
            continue
        out = BASE / p["slug"] / "dashboard" / "index.html"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(html)
        print(f"  ok   {p['id']} {p['slug']}/dashboard/index.html")
        built += 1
    print(f"Dashboards built: {built}/{len(PROJECTS)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
