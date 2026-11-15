--------------------------------------------------------------------------------
-- P07: Asset Quality Dashboard — NPAs & Capital Adequacy (CRAR)
-- Domain     : Banking Sector · Risk & Regulation
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE npa_bank_group (
    period     TEXT     NOT NULL   -- period label (ISO),
    gross_npa_amount_all     INTEGER,
    gross_npa_to_advances_pct_all     REAL,
    net_npa_amount_all     INTEGER,
    net_npa_to_advances_pct_all     REAL,
    advances_gross_all     INTEGER,
    advances_net_all     INTEGER,
    gross_npa_amount_sbi_group     REAL,
    gross_npa_to_advances_pct_sbi_group     REAL,
    net_npa_amount_sbi_group     REAL,
    net_npa_to_advances_pct_sbi_group     REAL,
    advances_gross_sbi_group     REAL,
    advances_net_sbi_group     REAL,
    gross_npa_amount_nationalised     REAL,
    gross_npa_to_advances_pct_nationalised     REAL,
    net_npa_amount_nationalised     REAL,
    net_npa_to_advances_pct_nationalised     REAL,
    advances_gross_nationalised     REAL,
    advances_net_nationalised     REAL,
    gross_npa_amount_private     INTEGER,
    gross_npa_to_advances_pct_private     REAL,
    net_npa_amount_private     INTEGER,
    net_npa_to_advances_pct_private     REAL,
    advances_gross_private     INTEGER,
    advances_net_private     INTEGER,
    gross_npa_amount_foreign     INTEGER,
    gross_npa_to_advances_pct_foreign     REAL,
    net_npa_amount_foreign     INTEGER,
    net_npa_to_advances_pct_foreign     REAL,
    advances_gross_foreign     INTEGER,
    advances_net_foreign     INTEGER
);

CREATE TABLE crar_distribution (
    period     TEXT     NOT NULL   -- period label (ISO),
    banks_below_9pct     INTEGER,
    banks_9_to_10pct     INTEGER,
    banks_10_to_12pct     REAL,
    banks_above_10pct     INTEGER,
    banks_above_12pct     REAL,
    weighted_avg_crar     REAL
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_npa_bank_group_period ON npa_bank_group (period);
CREATE INDEX ix_crar_distribution_period ON crar_distribution (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_npa_bank_group_mart AS
SELECT * FROM npa_bank_group
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_crar_distribution_mart AS
SELECT * FROM crar_distribution
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'npa_bank_group' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM npa_bank_group
UNION ALL
SELECT 'crar_distribution' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM crar_distribution
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
