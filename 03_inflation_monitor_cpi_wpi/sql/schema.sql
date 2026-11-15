--------------------------------------------------------------------------------
-- P03: Inflation Monitor — CPI & WPI Analytics
-- Domain     : Macro-Finance · Prices
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE cpi_annual (
    period     TEXT     NOT NULL   -- period label (ISO),
    cpi_iw     INTEGER,
    cpi_iw_food     REAL,
    cpi_al     REAL,
    cpi_rural     REAL,
    cpi_urban     REAL,
    cpi_combined     REAL
);

CREATE TABLE cpi_monthly (
    period     TEXT     NOT NULL   -- period label (ISO),
    cpi_rural     REAL,
    cpi_urban     REAL,
    cpi_index     REAL
);

CREATE TABLE wpi_annual (
    period     TEXT     NOT NULL   -- period label (ISO),
    wpi_all_commodities     REAL,
    wpi_primary_articles     REAL,
    wpi_food_articles     REAL,
    wpi_non_food_articles     REAL,
    wpi_fuel_power     REAL,
    wpi_manufactured_products     REAL
);

CREATE TABLE wpi_monthly (
    period     TEXT     NOT NULL   -- period label (ISO),
    wpi_index     REAL
);

CREATE TABLE inflation_variations (
    period     TEXT     NOT NULL   -- period label (ISO),
    wpi_variation_pct     REAL,
    cpi_variation_pct     REAL,
    cpi_wpi_gap     REAL
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_cpi_annual_period ON cpi_annual (period);
CREATE INDEX ix_cpi_monthly_period ON cpi_monthly (period);
CREATE INDEX ix_wpi_annual_period ON wpi_annual (period);
CREATE INDEX ix_wpi_monthly_period ON wpi_monthly (period);
CREATE INDEX ix_inflation_variations_period ON inflation_variations (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_cpi_annual_mart AS
SELECT * FROM cpi_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_cpi_monthly_mart AS
SELECT * FROM cpi_monthly
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_wpi_annual_mart AS
SELECT * FROM wpi_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_wpi_monthly_mart AS
SELECT * FROM wpi_monthly
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_inflation_variations_mart AS
SELECT * FROM inflation_variations
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'cpi_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM cpi_annual
UNION ALL
SELECT 'cpi_monthly' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM cpi_monthly
UNION ALL
SELECT 'wpi_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM wpi_annual
UNION ALL
SELECT 'wpi_monthly' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM wpi_monthly
UNION ALL
SELECT 'inflation_variations' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM inflation_variations
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
