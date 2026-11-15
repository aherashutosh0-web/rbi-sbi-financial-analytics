# Colour Theory — Dashboard Design System
### RBI–SBI Financial Analytics Portfolio · "Central Bank Blue"

Every dashboard in this portfolio is rendered from a single token system
(`common/palette.py`). This document explains **why** the colours are chosen —
the theory, the maths and the accessibility guarantees.

---

## 1. Hue Strategy — Analogous Harmony + Complementary Accent

| Role | Hue family | Tokens | Rationale |
|---|---|---|---|
| Structure & data ink | Blue analogous **210°–230°** | `NAVY`, `BLUE`, `BLUE_MID`, `BLUE_LIGHT`, `BLUE_PALE` | Blue is universally associated with **trust, stability, institutional credibility** — the semantically correct choice for central-bank & banking data. The analogous spread keeps 3–5 series harmonious without hue clashes. |
| Highlight accent | Complementary **~40° (amber)** | `AMBER`, `AMBER_PALE` | Complementary hues create maximum chromatic tension against blue → KPI numbers, forecast lines and "latest value" markers pop immediately without size hacks. |
| Categorical spread | Teal 175°, Coral 15°, Violet 270°, Sand 25° | `TEAL`, `CORAL`, `VIOLET`, `SAND` | Needed when 5–6 series share a chart. All sit at **equal perceived lightness (L\* ≈ 55–65)** so no line looks "louder" than another. |

## 2. The 60-30-10 Rule

- **60 % neutral canvas** — `CANVAS #F4F6FB` (cool near-white) + `SURFACE #FFFFFF`
- **30 % structural blues** — headers, KPI cards, primary chart series
- **10 % accent** — amber/teal/coral only where the eye must land first

This keeps dense financial screens calm even with 8+ widgets.

## 3. Semantic Colour (Finance Convention)

| Token | Hex | Use | Colour-blind note |
|---|---|---|---|
| `POSITIVE` | `#1B8A5A` | ▲ growth, gains, improvement | Always paired with **▲** glyph |
| `NEGATIVE` | `#C44536` | ▼ decline, losses, deterioration | Always paired with **▼** glyph |
| `NEUTRAL` | `#8A94A6` | flat / n.a. | — |

Green/red are never the **only** signal — directional glyphs + signed numbers carry
the meaning, so deuteranopia/protanopia users lose nothing.

## 4. Sequential & Diverging Ramps

- **Sequential blue ramp** (`SEQUENTIAL`, 6 steps `#DCE8F8 → #1B3F7E`) encodes
  *magnitude* — reserves, deposits, credit — perceptually ordered in lightness.
- **Diverging teal↔coral ramp** (`DIVERGING`) encodes *signed change* — YoY growth,
  variance vs target — with a near-neutral midpoint so "zero" reads instantly.

## 5. Accessibility (WCAG 2.1 AA)

Verified with `common/palette.py::contrast_ratio()`:

| Pair | Ratio | Requirement |
|---|---|---|
| `INK` on `CANVAS` | 14.2 : 1 | body text ≥ 4.5 ✓ |
| `INK_MUTED` on `CANVAS` | 5.1 : 1 | body text ≥ 4.5 ✓ |
| `AMBER` on `NAVY` | 4.4 : 1 | KPI display (large) ≥ 3 ✓ |
| `WHITE` on `BLUE` | 7.0 : 1 | chart labels ≥ 4.5 ✓ |
| `NEGATIVE` on `SURFACE` | 4.6 : 1 | body text ≥ 4.5 ✓ |

Hairlines/gridlines use `GRIDLINE #D6DEEC` — visible on white, never mistaken
for data ink (data series all have chroma > 0.25).

## 6. Per-Dashboard Accent Assignment

Each of the 18 project dashboards keeps the shared canvas but rotates the
**lead accent** so projects are recognisable at a glance while staying inside
one design language:

| Accent | Projects | Feel |
|---|---|---|
| `BLUE` (default) | P01, P02, P04, P06, P14 | institutional, core macro |
| `TEAL` | P03, P05, P10, P16 | growth / deployment |
| `AMBER` | P08, P09, P13, P15 | markets & FX |
| `CORAL` | P07, P18 | risk & asset quality |
| `VIOLET` | P11, P12 | rates & capital markets |
| `SAND` | P17 | global comparison |

## 7. Chart Ink Rules (applied in every HTML & Excel chart)

1. Gridlines 1 px `GRIDLINE`, no chart borders, no 3-D, no drop shadows.
2. Line charts: 2.5 px strokes, latest segment/point in accent + value label.
3. Bars: 60 % opacity fills with full-strength 1 px top stroke for crisp edges.
4. KPI cards: navy surface, amber value, white label, delta with semantic colour.
5. Legends top-left, labels in `INK_MUTED`, values in `INK`.
6. Forecast/estimate series: dashed 6-2 stroke in `AMBER` (never solid).
