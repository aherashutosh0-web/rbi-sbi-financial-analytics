--------------------------------------------------------------------------------
-- P06: SCB Consolidated Balance Sheet & Efficiency Ratios
-- Domain     : Banking Sector · Financial Health
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE scb_balance_sheet (
    period     TEXT     NOT NULL   -- period label (ISO),
    capital     INTEGER,
    reserves_surplus     INTEGER,
    deposits     INTEGER,
    borrowings     INTEGER,
    other_liabilities     INTEGER,
    other_items     REAL,
    total_liabilities     REAL,
    total_liabilities_check     REAL
);

CREATE TABLE scb_ratios (
    period     TEXT     NOT NULL   -- period label (ISO),
    credit_to_deposit_pct     REAL,
    investments_to_deposit_pct     REAL,
    govt_sec_to_deposit_pct     REAL,
    credit_to_workfund_pct     REAL,
    investments_to_workfund_pct     REAL,
    govt_sec_to_workfund_pct     REAL,
    aggregate_deposit_share_pct     REAL
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_scb_balance_sheet_period ON scb_balance_sheet (period);
CREATE INDEX ix_scb_ratios_period ON scb_ratios (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_scb_balance_sheet_mart AS
SELECT * FROM scb_balance_sheet
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_scb_ratios_mart AS
SELECT * FROM scb_ratios
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'scb_balance_sheet' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM scb_balance_sheet
UNION ALL
SELECT 'scb_ratios' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM scb_ratios
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
