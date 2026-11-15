--------------------------------------------------------------------------------
-- P02: Money Stock & Monetary Aggregates Analytics (M1–M4)
-- Domain     : Macro-Finance · Monetary Economics
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE money_stock_annual (
    period     TEXT     NOT NULL   -- period label (ISO),
    currency_in_circulation     INTEGER,
    cash_with_banks     INTEGER,
    currency_with_public     INTEGER,
    others_deposits_with_rbi     INTEGER,
    bankers_deposits_with_rbi     INTEGER,
    demand_deposits     INTEGER,
    time_deposits     INTEGER,
    reserve_money     INTEGER,
    m1     INTEGER,
    m3     INTEGER
);

CREATE TABLE money_stock_monthly (
    period     TEXT     NOT NULL   -- period label (ISO),
    currency_in_circulation     INTEGER,
    cash_with_banks     INTEGER,
    currency_with_public     INTEGER,
    others_deposits_with_rbi     INTEGER,
    bankers_deposits_with_rbi     INTEGER,
    demand_deposits     INTEGER,
    time_deposits     INTEGER,
    reserve_money     INTEGER,
    m1     INTEGER,
    m3     INTEGER
);

CREATE TABLE money_sources (
    period     TEXT     NOT NULL   -- period label (ISO),
    net_rbi_credit_to_government     INTEGER,
    net_rbi_credit_to_banks     INTEGER,
    other_banks_investment_in_govt     INTEGER,
    net_bank_credit_to_government     INTEGER,
    rbi_credit_to_commercial_sector     INTEGER,
    other_banks_credit_to_commercial_sector     INTEGER,
    bank_credit_to_commercial_sector     INTEGER
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_money_stock_annual_period ON money_stock_annual (period);
CREATE INDEX ix_money_stock_monthly_period ON money_stock_monthly (period);
CREATE INDEX ix_money_sources_period ON money_sources (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_money_stock_annual_mart AS
SELECT * FROM money_stock_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_money_stock_monthly_mart AS
SELECT * FROM money_stock_monthly
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_money_sources_mart AS
SELECT * FROM money_sources
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'money_stock_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM money_stock_annual
UNION ALL
SELECT 'money_stock_monthly' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM money_stock_monthly
UNION ALL
SELECT 'money_sources' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM money_sources
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
