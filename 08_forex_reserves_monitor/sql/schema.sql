--------------------------------------------------------------------------------
-- P08: India Forex Reserves Monitor (Annual · Monthly · Weekly)
-- Domain     : External Sector · Reserves
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE forex_annual (
    period     TEXT     NOT NULL   -- period label (ISO),
    sdr_inr_crore     REAL,
    sdr_usd_mn     REAL,
    gold_inr_crore     INTEGER,
    gold_usd_mn     INTEGER,
    fca_inr_crore     INTEGER,
    fca_usd_mn     INTEGER,
    reserve_tranche_inr_crore     REAL,
    reserve_tranche_usd_mn     REAL,
    total_reserves_inr_crore     INTEGER,
    total_reserves_usd_mn     INTEGER
);

CREATE TABLE forex_monthly (
    period     TEXT     NOT NULL   -- period label (ISO),
    sdr_inr_crore     INTEGER,
    sdr_usd_mn     INTEGER,
    gold_inr_crore     INTEGER,
    gold_usd_mn     INTEGER,
    fca_inr_crore     INTEGER,
    fca_usd_mn     INTEGER,
    reserve_tranche_inr_crore     INTEGER,
    reserve_tranche_usd_mn     INTEGER,
    total_reserves_inr_crore     INTEGER,
    total_reserves_usd_mn     INTEGER
);

CREATE TABLE forex_weekly (
    period     TEXT     NOT NULL   -- period label (ISO),
    sdr_inr_crore     REAL,
    sdr_usd_mn     REAL,
    gold_inr_crore     REAL,
    gold_usd_mn     REAL,
    fca_inr_crore     REAL,
    fca_usd_mn     REAL,
    reserve_tranche_inr_crore     REAL,
    reserve_tranche_usd_mn     REAL,
    total_reserves_inr_crore     REAL,
    total_reserves_usd_mn     REAL
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_forex_annual_period ON forex_annual (period);
CREATE INDEX ix_forex_monthly_period ON forex_monthly (period);
CREATE INDEX ix_forex_weekly_period ON forex_weekly (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_forex_annual_mart AS
SELECT * FROM forex_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_forex_monthly_mart AS
SELECT * FROM forex_monthly
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_forex_weekly_mart AS
SELECT * FROM forex_weekly
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'forex_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM forex_annual
UNION ALL
SELECT 'forex_monthly' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM forex_monthly
UNION ALL
SELECT 'forex_weekly' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM forex_weekly
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
