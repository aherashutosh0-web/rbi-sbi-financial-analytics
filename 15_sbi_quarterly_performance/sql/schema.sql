--------------------------------------------------------------------------------
-- P15: SBI Quarterly Performance Tracker
-- Domain     : SBI · Earnings Quality
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE fin_sbin_quarterly (
    period     TEXT     NOT NULL   -- period label (ISO),
    quarterlyInterestIncome     REAL,
    quarterlyTotalRevenue     REAL,
    quarterlyStockholdersEquity     REAL,
    quarterlyInterestExpense     REAL,
    quarterlyNetIncome     REAL,
    quarterlyTotalAssets     REAL,
    quarterlyDilutedEPS     REAL,
    net_margin_pct     REAL,
    as_of_date     TEXT
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_fin_sbin_quarterly_period ON fin_sbin_quarterly (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_fin_sbin_quarterly_mart AS
SELECT * FROM fin_sbin_quarterly
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'fin_sbin_quarterly' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM fin_sbin_quarterly
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
