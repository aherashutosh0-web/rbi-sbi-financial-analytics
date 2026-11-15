--------------------------------------------------------------------------------
-- P01: RBI Monetary Policy & Reserve Requirements Tracker
-- Domain     : Macro-Finance · Monetary Policy
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE policy_rates (
    period     TEXT     NOT NULL   -- period label (ISO),
    bank_rate     REAL,
    repo_rate     REAL,
    reverse_repo_rate     REAL,
    sdf_rate     REAL,
    msf_rate     REAL,
    crr     REAL,
    slr     REAL
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_policy_rates_period ON policy_rates (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_policy_rates_mart AS
SELECT * FROM policy_rates
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'policy_rates' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM policy_rates
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
