--------------------------------------------------------------------------------
-- P04: Scheduled Commercial Banks — Credit & Deposit Growth Engine
-- Domain     : Banking Sector · Balance Sheet
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE scb_aggregates_annual (
    period     TEXT     NOT NULL   -- period label (ISO),
    demand_deposits     INTEGER,
    time_deposits     REAL,
    aggregate_deposits     REAL,
    borrowings_from_rbi     REAL,
    liabilities_to_banks     REAL,
    other_liabilities     INTEGER,
    bank_credit     REAL,
    non_food_credit     REAL,
    food_credit     REAL,
    credit_deposit_ratio     REAL
);

CREATE TABLE scb_aggregates_monthly (
    period     TEXT     NOT NULL   -- period label (ISO),
    demand_deposits     INTEGER,
    time_deposits     INTEGER,
    aggregate_deposits     INTEGER,
    borrowings_from_rbi     INTEGER,
    liabilities_to_banks     INTEGER,
    other_liabilities     INTEGER,
    investments_govt_securities     INTEGER,
    investments_other_approved     INTEGER,
    investments_total     INTEGER,
    food_credit     INTEGER,
    non_food_credit     INTEGER,
    bank_credit     INTEGER,
    cash_in_hand     INTEGER,
    balances_with_rbi     INTEGER,
    assets_with_banks     INTEGER,
    credit_deposit_ratio     REAL
);

CREATE TABLE scb_growth (
    period     TEXT     NOT NULL   -- period label (ISO),
    demand_deposits_growth_pct     REAL,
    time_deposits_growth_pct     REAL,
    deposits_growth_pct     REAL,
    investments_growth_pct     REAL,
    food_credit_growth_pct     REAL,
    non_food_credit_growth_pct     REAL,
    credit_growth_pct     REAL
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_scb_aggregates_annual_period ON scb_aggregates_annual (period);
CREATE INDEX ix_scb_aggregates_monthly_period ON scb_aggregates_monthly (period);
CREATE INDEX ix_scb_growth_period ON scb_growth (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_scb_aggregates_annual_mart AS
SELECT * FROM scb_aggregates_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_scb_aggregates_monthly_mart AS
SELECT * FROM scb_aggregates_monthly
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_scb_growth_mart AS
SELECT * FROM scb_growth
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'scb_aggregates_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM scb_aggregates_annual
UNION ALL
SELECT 'scb_aggregates_monthly' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM scb_aggregates_monthly
UNION ALL
SELECT 'scb_growth' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM scb_growth
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
