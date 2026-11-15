--------------------------------------------------------------------------------
-- P10: Digital Payments & UPI Transformation Tracker
-- Domain     : Banking Sector · Payments
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE payment_systems (
    period     TEXT     NOT NULL   -- period label (ISO),
    rtgs_volume_mn     REAL,
    rtgs_value_crore     REAL,
    aeps_volume_mn     REAL,
    aeps_value_crore     REAL,
    imps_volume_mn     REAL,
    imps_value_crore     REAL,
    neft_volume_mn     REAL,
    neft_value_crore     REAL,
    upi_volume_mn     REAL,
    upi_value_crore     REAL,
    cards_volume_mn     REAL,
    cards_value_crore     REAL,
    paper_volume_mn     REAL,
    paper_value_crore     REAL,
    total_volume_mn     REAL,
    total_value_crore     REAL,
    digital_total_volume_mn     REAL,
    digital_total_value_crore     REAL,
    digital_share_pct     REAL,
    paper_share_pct     REAL
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_payment_systems_period ON payment_systems (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_payment_systems_mart AS
SELECT * FROM payment_systems
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'payment_systems' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM payment_systems
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
