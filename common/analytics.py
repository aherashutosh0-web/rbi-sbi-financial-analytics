"""
analytics.py — Shared computation helpers used by every project's analysis.py.

All functions are pure (DataFrame in → DataFrame/series/scalar out) so project
scripts stay declarative.
"""
from __future__ import annotations

import json
import pathlib
import re

import numpy as np
import pandas as pd


# ── generic series helpers ────────────────────────────────────────────────────
def to_period_str(s: pd.Series) -> pd.Series:
    """Normalise a period column to string labels (YYYY or YYYY-MM)."""
    if np.issubdtype(s.dtype, np.number):
        return s.astype("Int64").astype(str)
    return s.astype(str).str.strip()


def yoy(series: pd.Series) -> pd.Series:
    return series.pct_change(4) if _is_quarterly(series) else series.pct_change(12) if _is_monthly(series) else series.pct_change(1)


def _is_monthly(series: pd.Series) -> bool:
    return str(series.index.dtype).startswith("period[M]") or (
        isinstance(series.index, pd.PeriodIndex) and series.index.freqstr and "M" in series.index.freqstr)


def _is_quarterly(series: pd.Series) -> bool:
    return isinstance(series.index, pd.PeriodIndex) and series.index.freqstr and "Q" in series.index.freqstr


def cagr(series: pd.Series, years: int | None = None) -> float | None:
    s = series.dropna()
    if len(s) < 2:
        return None
    if years is not None and len(s) > years + 1:
        s = s.iloc[-(years + 1):]
    first, last = float(s.iloc[0]), float(s.iloc[-1])
    n = len(s) - 1
    if first <= 0 or last <= 0:
        return None
    return (last / first) ** (1 / n) - 1


def yoy_pct(series: pd.Series) -> float | None:
    s = series.dropna()
    if len(s) < 2:
        return None
    first, last = float(s.iloc[-2]), float(s.iloc[-1])
    if first == 0:
        return None
    return (last / first) - 1


def qoq_pct(series: pd.Series) -> float | None:
    return yoy_pct(series)


def rolling_volatility(close: pd.Series, window: int = 60, annualise: int = 252) -> pd.Series:
    ret = close.pct_change()
    return ret.rolling(window).std() * np.sqrt(annualise) * 100


def drawdown(close: pd.Series) -> pd.Series:
    peak = close.cummax()
    return (close / peak - 1) * 100


def max_drawdown(close: pd.Series) -> float:
    return float(drawdown(close).min())


def historical_var(close: pd.Series, level: float = 0.95) -> float:
    """Historical Value-at-Risk on daily returns, in %."""
    ret = close.pct_change().dropna()
    return float(np.percentile(ret, (1 - level) * 100) * 100)


def beta(stock: pd.Series, market: pd.Series) -> float | None:
    df = pd.concat([stock.pct_change(), market.pct_change()], axis=1).dropna()
    if len(df) < 30:
        return None
    cov = np.cov(df.iloc[:, 0], df.iloc[:, 1])
    var = cov[1, 1]
    return float(cov[0, 1] / var) if var else None


def ann_return(close: pd.Series, years: float = 1.0) -> float | None:
    s = close.dropna()
    if len(s) < 2:
        return None
    total = float(s.iloc[-1]) / float(s.iloc[0])
    return total ** (1 / years) - 1


# ── KPI engine (registry-driven) ─────────────────────────────────────────────
def period_yoy(df: pd.DataFrame, col: str) -> float | None:
    """YoY aware of period granularity: monthly compares to 12 rows back,
    quarterly to 4 rows back, otherwise to previous row."""
    if col in ("period", "date", "as_of_date") or col not in df.columns:
        return None
    per_col = "period" if "period" in df.columns else None
    s = df[[per_col, col]].dropna() if per_col else df[[col]].dropna()
    if len(s) < 2:
        return None
    per = str(s["period"].iloc[-1]) if "period" in s.columns else ""
    lag = 12 if re.fullmatch(r"\d{4}-\d{2}", per) else 4 if re.fullmatch(r"\d{4}-Q\d", per) else 1
    if len(s) <= lag:
        return None
    first, last = float(s[col].iloc[-1 - lag]), float(s[col].iloc[-1])
    return (last / first - 1) if first else None


def compute_kpi(kpi: dict, tables: dict[str, pd.DataFrame]) -> dict:
    df = tables.get(kpi["ds"])
    out = {"label": kpi["label"], "unit": kpi.get("unit", ""), "value": None}
    if df is None or kpi["col"] not in df.columns:
        return out
    s = df[kpi["col"]].dropna()
    if s.empty:
        return out
    agg = kpi.get("agg", "last")
    if agg == "last":
        out["value"] = float(s.iloc[-1])
    elif agg == "first":
        out["value"] = float(s.iloc[0])
    elif agg == "avg":
        out["value"] = float(s.mean())
    elif agg == "max":
        out["value"] = float(s.max())
    elif agg == "min":
        out["value"] = float(s.min())
    elif agg == "yoy":
        out["value"] = period_yoy(df, kpi["col"])
    elif agg == "qoq":
        out["value"] = qoq_pct(s)
    elif agg == "cagr5":
        out["value"] = cagr(s, years=5)
        if out["value"] is not None:
            out["value"] *= 100
    elif agg == "cagr10":
        out["value"] = cagr(s, years=10)
        if out["value"] is not None:
            out["value"] *= 100
    elif agg == "max52w":
        tail = df[kpi["col"]].dropna().iloc[-252:]
        out["value"] = float(tail.max())
    return out


def fmt_value(v, unit: str = "") -> str:
    if v is None:
        return "n/a"
    if unit in ("%", "pp"):
        return f"{v:.2f}"
    if unit in ("₹ cr", "US$ mn", "mn txn"):
        return f"{v:,.0f}"
    if unit == "₹":
        return f"{v:,.0f}"
    if unit == "x":
        return f"{v:.2f}"
    return f"{v:,.2f}"


def write_outputs(out_dir: pathlib.Path, insights: dict, summary_md: str):
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "analysis.json").write_text(json.dumps(insights, indent=2, default=str))
    (out_dir / "summary.md").write_text(summary_md)
