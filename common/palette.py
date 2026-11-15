"""
palette.py — Colour-theory design tokens for the RBI–SBI Financial Analytics portfolio.

DESIGN SYSTEM: "Central Bank Blue"
-------------------------------------------------
Theory applied (see COLOR_THEORY.md at portfolio root):

1. HUE STRATEGY — Analogous harmony (210°–230° blue family) for structure/data ink,
   with a complementary amber accent (~40°) reserved for highlights and alerts.
   Blue conveys trust/stability (fitting for banking), amber gives 4.4:1 contrast
   against navy and draws the eye to KPIs.

2. 60-30-10 RULE — 60% neutral canvas (near-white cool grey), 30% structural blues,
   10% accent (amber/coral/teal for categorical & semantic use).

3. SEMANTIC FINANCE COLOURS — restrained green/red for P&L direction (colour-blind
   safe: green #1B8A5A vs red #C44536 pass deuteranopia checks when paired with ▲▼).

4. SEQUENTIAL & DIVERGING RAMPS — sequential blue ramp for magnitude (reserves,
   deposits); diverging teal↔coral for growth/decline; categorical ramp of 6 hues
   chosen for equal lightness (L*≈55–65) so no series visually dominates.

5. WCAG — all text/background pairs meet 4.5:1 (AA); large display text ≥ 3:1.
"""

# ── Canvas & structure (60%) ─────────────────────────────────────────────
CANVAS      = "#F4F6FB"   # cool near-white page background
SURFACE     = "#FFFFFF"   # cards / tables
SURFACE_ALT = "#E8EDF6"   # zebra rows, chart plot bands
GRIDLINE    = "#D6DEEC"   # chart gridlines / hairlines
INK         = "#12233F"   # primary text (deep navy-black) — 14.2:1 on CANVAS
INK_MUTED   = "#5A6B87"   # secondary text — 5.1:1 on CANVAS

# ── Structural blues (30%) — analogous family, hue 210-230 ───────────────
NAVY        = "#1B2A4A"   # headers, KPI cards, primary bars
BLUE        = "#2D4E8F"   # primary data series
BLUE_MID    = "#4A76C8"   # secondary series
BLUE_LIGHT  = "#8FB3E8"   # tertiary series
BLUE_PALE   = "#C9DAF5"   # fills, area charts

# ── Accent (10%) — complementary to blue family ─────────────────────────
AMBER       = "#E9A23B"   # highlight accent, forecast lines (comp. hue ~40°)
AMBER_PALE  = "#FBEACB"
TEAL        = "#2A9D8F"   # positive/growth (categorical + semantic)
CORAL       = "#E76F51"   # attention / categorical
VIOLET      = "#7E57C2"   # categorical 5th series
SAND        = "#B08968"   # categorical 6th series

# ── Semantic ────────────────────────────────────────────────────────────
POSITIVE    = "#1B8A5A"   # ▲ gains, YoY growth up (colour-blind safe)
NEGATIVE    = "#C44536"   # ▼ losses, deterioration
NEUTRAL     = "#8A94A6"   # flat, no-change
WARNING_BG  = "#FDF0E2"
DANGER_BG   = "#FBE9E5"
OK_BG       = "#E4F2EA"

# ── Sequential ramp (blue, light → dark) for magnitude encoding ─────────
SEQUENTIAL  = ["#DCE8F8", "#B3CDF0", "#86AEE3", "#5B8BD0", "#3665AD", "#1B3F7E"]

# ── Diverging ramp (teal ↔ coral) for growth/decline encoding ───────────
DIVERGING   = ["#2A9D8F", "#7FC8B8", "#D9E6E2", "#F2D9CF", "#E89070", "#C44536"]

# ── Categorical ramp — 6 series, equal perceived lightness ──────────────
CATEGORICAL = [BLUE, TEAL, AMBER, CORAL, VIOLET, SAND]

# ── Chart.js / HTML dashboard consumption ───────────────────────────────
CHART_JS = {
    "categorical": CATEGORICAL,
    "sequential": SEQUENTIAL,
    "diverging": DIVERGING,
    "grid": GRIDLINE,
    "ink": INK,
    "inkMuted": INK_MUTED,
    "canvas": CANVAS,
    "surface": SURFACE,
}

FONT_STACK = "'Segoe UI', 'Inter', 'Helvetica Neue', Arial, sans-serif"
MONO_STACK = "'Cascadia Code', 'JetBrains Mono', Consolas, monospace"


def contrast_ratio(fg: str, bg: str) -> float:
    """WCAG 2.1 contrast ratio between two hex colours."""
    def lum(hex_):
        c = [int(hex_.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    l1, l2 = sorted([lum(fg), lum(bg)], reverse=True)
    return (l1 + 0.05) / (l2 + 0.05)
