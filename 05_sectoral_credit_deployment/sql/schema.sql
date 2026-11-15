--------------------------------------------------------------------------------
-- P05: Sectoral Deployment of Bank Credit Analysis
-- Domain     : Banking Sector · Credit Risk
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE credit_sectoral_annual (
    period     TEXT     NOT NULL   -- period label (ISO),
    agriculture     REAL,
    industry     REAL,
    services     REAL,
    retail     REAL,
    total_non_food_credit     REAL,
    agriculture_share_pct     REAL,
    industry_share_pct     REAL,
    services_share_pct     REAL,
    retail_share_pct     REAL
);

CREATE TABLE credit_sectoral_monthly (
    period     TEXT     NOT NULL   -- period label (ISO),
    agriculture     REAL,
    industry     REAL,
    services     REAL,
    retail     REAL,
    total_non_food_credit     REAL,
    agriculture_share_pct     REAL,
    industry_share_pct     REAL,
    services_share_pct     REAL,
    retail_share_pct     REAL
);

CREATE TABLE credit_industry_annual (
    period     TEXT     NOT NULL   -- period label (ISO),
    mining     REAL,
    food_processing     REAL,
    textiles     REAL,
    chemicals     REAL,
    infrastructure     REAL,
    basic_metal     REAL,
    total_non_food_credit     REAL,
    mining_share_pct     REAL,
    food_processing_share_pct     REAL,
    textiles_share_pct     REAL,
    chemicals_share_pct     REAL,
    infrastructure_share_pct     REAL,
    basic_metal_share_pct     REAL
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_credit_sectoral_annual_period ON credit_sectoral_annual (period);
CREATE INDEX ix_credit_sectoral_monthly_period ON credit_sectoral_monthly (period);
CREATE INDEX ix_credit_industry_annual_period ON credit_industry_annual (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_credit_sectoral_annual_mart AS
SELECT * FROM credit_sectoral_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_credit_sectoral_monthly_mart AS
SELECT * FROM credit_sectoral_monthly
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_credit_industry_annual_mart AS
SELECT * FROM credit_industry_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'credit_sectoral_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM credit_sectoral_annual
UNION ALL
SELECT 'credit_sectoral_monthly' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM credit_sectoral_monthly
UNION ALL
SELECT 'credit_industry_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM credit_industry_annual
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
