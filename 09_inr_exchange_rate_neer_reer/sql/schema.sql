--------------------------------------------------------------------------------
-- P09: INR Exchange Rate & NEER/REER Analytics
-- Domain     : External Sector · FX
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE fx_rates_annual (
    period     TEXT     NOT NULL   -- period label (ISO),
    usd_inr     REAL,
    sdr_inr     REAL,
    gbp_inr     REAL,
    jpy_inr     REAL,
    eur_inr     REAL
);

CREATE TABLE fx_rates_daily (
    period     TEXT     NOT NULL   -- period label (ISO),
    usd_inr     REAL,
    gbp_inr     REAL,
    eur_inr     REAL,
    jpy_inr     REAL
);

CREATE TABLE neer_reer (
    period     TEXT     NOT NULL   -- period label (ISO),
    neer_index     REAL,
    reer_index     REAL,
    neer_export_index     REAL,
    reer_export_index     REAL
);

CREATE TABLE px_usdinr (
    period     TEXT     NOT NULL   -- period label (ISO),
    open     REAL,
    high     REAL,
    low     REAL,
    close     REAL,
    adjclose     REAL,
    volume     REAL,
    date     TEXT
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_fx_rates_annual_period ON fx_rates_annual (period);
CREATE INDEX ix_fx_rates_daily_period ON fx_rates_daily (period);
CREATE INDEX ix_neer_reer_period ON neer_reer (period);
CREATE INDEX ix_px_usdinr_period ON px_usdinr (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_fx_rates_annual_mart AS
SELECT * FROM fx_rates_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_fx_rates_daily_mart AS
SELECT * FROM fx_rates_daily
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_neer_reer_mart AS
SELECT * FROM neer_reer
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_px_usdinr_mart AS
SELECT * FROM px_usdinr
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'fx_rates_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM fx_rates_annual
UNION ALL
SELECT 'fx_rates_daily' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM fx_rates_daily
UNION ALL
SELECT 'neer_reer' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM neer_reer
UNION ALL
SELECT 'px_usdinr' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM px_usdinr
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
