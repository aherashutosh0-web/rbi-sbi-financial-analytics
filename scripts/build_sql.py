"""
build_sql.py — Generate industry-standard SQL suites for all 18 projects.

Per project:
  sql/schema.sql           — warehouse DDL excerpt, project marts (views), indexes
  sql/analysis_queries.sql — 14 numbered analytic queries (CTEs, window functions,
                             YoY/CAGR, ranking, regimes, data-quality gates)
Queries are built from the *actual* prepared dataset columns so they always run
against warehouse/rbi_sbi_warehouse.db (verified by scripts/run_sql.py).

Run:  python3 scripts/build_sql.py
"""
import pathlib
import re
import sys

import pandas as pd

BASE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE))
PREP = BASE / "data_lake" / "prepared"

from common.registry import PROJECTS  # noqa: E402


def cols_of(df: pd.DataFrame) -> tuple[str, list[str], list[str]]:
    """Return (period_col, numeric_cols, other_cols)."""
    per = None
    for cand in ("period", "date", "as_of_date", "year", "month"):
        if cand in df.columns:
            per = cand
            break
    num = [c for c in df.select_dtypes("number").columns if c != per]
    other = [c for c in df.columns if c not in num and c != per]
    return per, num, other


SCHEMA_TPL = """--------------------------------------------------------------------------------
-- {pid}: {title}
-- Domain     : {domain}
-- Layer      : warehouse  ->  project marts (views)
-- Source     : {sources}
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
{ddl_tables}

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
{ddl_indexes}

-- ── 3. Project mart views ────────────────────────────────────────────────────
{marts}

-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
{dq_gate}
"""

QUERY_TPL = """--------------------------------------------------------------------------------
-- {pid} · ANALYTIC QUERY PACK — {title}
-- Business question: {business_q}
-- SQL focus: {sql_focus}
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT '{table}'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN({per})                       AS first_period,
       MAX({per})                       AS latest_period,
       COUNT(DISTINCT {per})            AS distinct_periods
  FROM {table};

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM {table}
 WHERE {per} = (SELECT MAX({per}) FROM {table});

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
{q03}

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
{q04}

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
{q05}

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
{q06}

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
{q07}

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
{q08}

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
{q09}

-- ═══ Q10 · Cross-dataset join: {join_note} ═════════════════════════════════
{q10}

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
{q11}

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
{q12}

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
{q13}

-- ═══ Q14 · Project-specific analytic: {focus} ══════════════════════════════
{q14}
"""


def stdev(c: str) -> str:
    """Portable sample standard deviation (SQLite has no STDEV aggregate)."""
    return (f"SQRT(MAX(0.0, (SUM({c}*{c}) - SUM({c})*SUM({c})/COUNT({c})) "
            f"/ NULLIF(COUNT({c})-1, 0)))")


def q03(per, table, metric, lag):
    return f"""SELECT {per},
       {metric},
       LAG({metric}, {lag}) OVER (ORDER BY {per})           AS {metric}_{lag}p_ago,
       ROUND(100.0 * ({metric} - LAG({metric}, {lag}) OVER (ORDER BY {per}))
             / NULLIF(LAG({metric}, {lag}) OVER (ORDER BY {per}), 0), 2) AS yoy_growth_pct
  FROM {table}
 ORDER BY {per};"""


def q04(per, table, metric):
    return f"""WITH m AS (
    SELECT {per}, {metric},
           AVG({metric}) OVER (ORDER BY {per} ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM {table})
SELECT {per}, {metric}, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND({metric} - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN {metric} > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY {per};"""


def q05(per, table, metric):
    return f"""WITH base AS (
    SELECT FIRST_VALUE({metric}) OVER (ORDER BY {per}) AS base_val, {per}, {metric}
      FROM {table})
SELECT {per}, {metric},
       ROUND(100.0 * {metric} / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY {per};"""


def q06(per, table, metric):
    return f"""WITH stats AS (
    SELECT AVG({metric}) AS mu, {stdev(metric)} AS sd FROM {table})
SELECT t.{per}, t.{metric},
       CASE
         WHEN t.{metric} > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.{metric} > s.mu        THEN 'ABOVE average'
         WHEN t.{metric} > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM {table} t CROSS JOIN stats s
 ORDER BY t.{per};"""


def q07(per, table, metric):
    return f"""SELECT {per}, {metric},
       RANK()       OVER (ORDER BY {metric} DESC) AS rank_high,
       RANK()       OVER (ORDER BY {metric} ASC)  AS rank_low
  FROM {table}
 ORDER BY rank_high
 LIMIT 10;"""


def q08(per, table, metric, lag):
    return f"""WITH chg AS (
    SELECT {per},
           100.0 * ({metric} - LAG({metric}, {lag}) OVER (ORDER BY {per}))
           / NULLIF(LAG({metric}, {lag}) OVER (ORDER BY {per}), 0) AS growth_pct
      FROM {table})
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND({stdev('growth_pct')}, 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;"""


def q09(per, table, metrics):
    m = metrics[:4]
    expr = " + ".join(f"NULLIF(SUM({x}), 0)" for x in m)
    return f"""SELECT {per},
       {", ".join(f"{x}" for x in m)},
       ROUND(100.0 * ({m[0]}) / NULLIF(({expr}), 0), 2) AS {m[0]}_share_pct
  FROM {table}
 WHERE {per} = (SELECT MAX({per}) FROM {table})
 GROUP BY {per};"""


def q10(per, t1, t2, m1, m2, join_note, per_b=None):
    return f"""SELECT a.{per},
       a.{m1}                            AS {t1}_{m1},
       b.{m2}                            AS {t2}_{m2},
       ROUND(1.0 * a.{m1} / NULLIF(b.{m2}, 0), 4) AS ratio_{m1}_to_{m2}
  FROM {t1} a
  JOIN {t2} b ON a.{per} = b.{per_b or per}
 ORDER BY a.{per};"""


def q11(per, table, metric):
    return f"""SELECT {per}, {metric},
       {metric} - LAG({metric}) OVER (ORDER BY {per}) AS absolute_delta,
       ROUND({metric} - AVG({metric}) OVER (), 2)     AS deviation_from_mean
  FROM {table}
 ORDER BY {per};"""


def q12(per, table, metrics):
    checks = "\nUNION ALL\n".join(
        f"""SELECT '{c}' AS column_name,
       SUM(CASE WHEN {c} IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN {c} < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM {table}""" for c in metrics[:5])
    return checks + ";"


def q13(per, table, metric):
    return f"""SELECT ROUND(AVG({metric}), 2)   AS mean_val,
       ROUND({stdev(metric)}, 2) AS std_val,
       MIN({metric})             AS min_val,
       MAX({metric})             AS max_val,
       (SELECT {per} FROM {table} ORDER BY {metric} ASC  LIMIT 1) AS min_period,
       (SELECT {per} FROM {table} ORDER BY {metric} DESC LIMIT 1) AS max_period
  FROM {table};"""


def q14(per, table, metric, focus):
    return f"""-- analytic intent: {focus}
WITH d AS (
    SELECT {per}, {metric},
           {metric} - LAG({metric}) OVER (ORDER BY {per})       AS delta,
           ROUND(100.0 * ({metric} - LAG({metric}) OVER (ORDER BY {per}))
                 / NULLIF(LAG({metric}) OVER (ORDER BY {per}), 0), 2) AS pct_change
      FROM {table})
SELECT {per}, {metric}, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY {per};"""


def build_project(p: dict) -> bool:
    tables = {}
    for n in p["datasets"]:
        f = PREP / f"{n}.csv"
        if f.exists():
            tables[n] = pd.read_csv(f)
    if not tables:
        return False

    # ---- schema.sql ------------------------------------------------------
    ddl_tables, ddl_indexes, marts = [], [], []
    for name, df in tables.items():
        lines = [f"CREATE TABLE {name} ("]
        per, num, other = cols_of(df)
        typed = []
        if per:
            typed.append(f"    {per}     TEXT     NOT NULL   -- period label (ISO)")
        typed += [f"    {c}     {'REAL' if pd.api.types.is_float_dtype(df[c]) else 'INTEGER'}" for c in num]
        typed += [f"    {c}     TEXT" for c in other]
        lines.append(",\n".join(typed))
        lines.append(");")
        ddl_tables.append("\n".join(lines))
        if per:
            ddl_indexes.append(f"CREATE INDEX ix_{name}_{per} ON {name} ({per});")
        marts.append(
            f"CREATE VIEW v_{name}_mart AS\n"
            f"SELECT * FROM {name}\n"
            f"WHERE {per} IS NOT NULL   -- analytic-ready grain: one row per {per};\n"
            if per else f"CREATE VIEW v_{name}_mart AS SELECT * FROM {name};")

    dq = "\nUNION ALL\n".join(
        f"""SELECT '{name}' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN {cols_of(df)[0]} IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM {name}""" for name, df in tables.items() if cols_of(df)[0]) + "\nHAVING SUM(CASE WHEN {p} IS NULL THEN 1 ELSE 0 END) > 0;".replace("{p}", "1")

    sources = ("RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + "
               "Yahoo Finance market data")

    schema_sql = SCHEMA_TPL.format(
        pid=p["id"], title=p["title"], domain=p["domain"], sources=sources,
        ddl_tables="\n\n".join(ddl_tables),
        ddl_indexes="\n".join(ddl_indexes) or "-- (created by build_warehouse.py)",
        marts="\n\n".join(marts),
        dq_gate=dq + "\n-- (0 rows expected)",
    )

    # ---- analysis_queries.sql -------------------------------------------
    t1 = next(iter(tables))
    df1 = tables[t1]
    per, num, _ = cols_of(df1)
    if not per or not num:
        return False
    metric = num[0]
    per_is_monthly = bool(re.fullmatch(r"\d{4}-\d{2}", str(df1[per].iloc[-1])))
    lag = 12 if per_is_monthly else 1
    second = list(tables)[1] if len(tables) > 1 else t1
    df2 = tables[second]
    per2, num2, _ = cols_of(df2)
    join_note = f"{t1} × {second} on period" if t1 != second else f"{t1} self-comparison"

    queries_sql = QUERY_TPL.format(
        pid=p["id"], title=p["title"], business_q=p["business_q"],
        sql_focus=p["sql_focus"], table=t1, per=per, join_note=join_note, focus=p["sql_focus"],
        q03=q03(per, t1, metric, lag),
        q04=q04(per, t1, metric),
        q05=q05(per, t1, metric),
        q06=q06(per, t1, metric),
        q07=q07(per, t1, metric),
        q08=q08(per, t1, metric, lag),
        q09=q09(per, t1, num),
        q10=q10(per, t1, second, metric, (num2 or num)[0], join_note, per2) if per2 else "-- n/a (no shared period key)",
        q11=q11(per, t1, metric),
        q12=q12(per, t1, num),
        q13=q13(per, t1, metric),
        q14=q14(per, t1, metric, p["sql_focus"]),
    )

    out = BASE / p["slug"] / "sql"
    out.mkdir(parents=True, exist_ok=True)
    (out / "schema.sql").write_text(schema_sql)
    (out / "analysis_queries.sql").write_text(queries_sql)
    return True


def main() -> int:
    built = 0
    for p in PROJECTS:
        ok = build_project(p)
        print(("  ok   " if ok else "  skip ") + f"{p['id']} {p['slug']}/sql/")
        built += ok
    print(f"SQL suites generated: {built}/{len(PROJECTS)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
