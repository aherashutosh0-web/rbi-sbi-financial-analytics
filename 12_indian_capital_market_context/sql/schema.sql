--------------------------------------------------------------------------------
-- P12: Indian Capital Market Context — SENSEX & NIFTY
-- Domain     : Capital Markets · Benchmarks
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE market_indices_annual (
    period     TEXT     NOT NULL   -- period label (ISO),
    sensex_avg     REAL,
    bse100_avg     REAL,
    rbi_index_avg     REAL,
    market_cap_bse_crore     INTEGER,
    market_cap_allindia_crore     REAL
);

CREATE TABLE nifty_monthly (
    period     TEXT     NOT NULL   -- period label (ISO),
    nifty_avg     REAL
);

CREATE TABLE sensex_monthly (
    period     TEXT     NOT NULL   -- period label (ISO),
    sensex_avg     REAL
);

CREATE TABLE px_nifty (
    period     TEXT     NOT NULL   -- period label (ISO),
    open     REAL,
    high     REAL,
    low     REAL,
    close     REAL,
    adjclose     REAL,
    volume     REAL,
    date     TEXT
);

CREATE TABLE px_sensex (
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
CREATE INDEX ix_market_indices_annual_period ON market_indices_annual (period);
CREATE INDEX ix_nifty_monthly_period ON nifty_monthly (period);
CREATE INDEX ix_sensex_monthly_period ON sensex_monthly (period);
CREATE INDEX ix_px_nifty_period ON px_nifty (period);
CREATE INDEX ix_px_sensex_period ON px_sensex (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_market_indices_annual_mart AS
SELECT * FROM market_indices_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_nifty_monthly_mart AS
SELECT * FROM nifty_monthly
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_sensex_monthly_mart AS
SELECT * FROM sensex_monthly
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_px_nifty_mart AS
SELECT * FROM px_nifty
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_px_sensex_mart AS
SELECT * FROM px_sensex
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'market_indices_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM market_indices_annual
UNION ALL
SELECT 'nifty_monthly' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM nifty_monthly
UNION ALL
SELECT 'sensex_monthly' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM sensex_monthly
UNION ALL
SELECT 'px_nifty' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM px_nifty
UNION ALL
SELECT 'px_sensex' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM px_sensex
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
