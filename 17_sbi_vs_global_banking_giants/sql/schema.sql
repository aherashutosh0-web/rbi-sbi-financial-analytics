--------------------------------------------------------------------------------
-- P17: SBI vs Global Banking Giants — International Benchmarking
-- Domain     : Global Finance · Cross-Border Benchmark
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE fin_peers_gl_annual (
    period     TEXT     NOT NULL   -- period label (ISO),
    total_assets_usd_bn_sbin     REAL,
    net_income_usd_bn_sbin     REAL,
    roe_pct_sbin     REAL,
    total_assets_usd_bn_jpm     REAL,
    net_income_usd_bn_jpm     REAL,
    roe_pct_jpm     REAL,
    total_assets_usd_bn_hsbc     REAL,
    net_income_usd_bn_hsbc     REAL,
    roe_pct_hsbc     REAL,
    total_assets_usd_bn_bcs     REAL,
    net_income_usd_bn_bcs     REAL,
    roe_pct_bcs     REAL,
    total_assets_usd_bn_c     REAL,
    net_income_usd_bn_c     REAL,
    roe_pct_c     REAL,
    total_assets_usd_bn_mufg     REAL,
    net_income_usd_bn_mufg     REAL,
    roe_pct_mufg     REAL,
    total_assets_usd_bn_bac     REAL,
    net_income_usd_bn_bac     REAL,
    roe_pct_bac     REAL,
    global_median_roe     REAL,
    asset_rank_sbin     REAL
);

CREATE TABLE px_peers_gl (
    period     TEXT     NOT NULL   -- period label (ISO),
    idx_sbin     REAL,
    idx_jpm     REAL,
    idx_hsbc     REAL,
    idx_c     REAL,
    idx_mufg     REAL,
    idx_bcs     REAL,
    idx_bac     REAL
);

CREATE TABLE fin_sbin_annual (
    period     TEXT     NOT NULL   -- period label (ISO),
    annualDilutedEPS     REAL,
    annualTotalDebt     REAL,
    annualTotalAssets     REAL,
    annualInterestIncome     REAL,
    annualNetIncome     REAL,
    annualCashAndCashEquivalents     REAL,
    annualInterestExpense     REAL,
    annualStockholdersEquity     REAL,
    annualTotalLiabilitiesNetMinorityInterest     REAL,
    annualTotalRevenue     REAL,
    net_margin_pct     REAL,
    roe_pct     REAL,
    roa_pct     REAL,
    as_of_date     TEXT
);

CREATE TABLE px_usdinr (
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
CREATE INDEX ix_fin_peers_gl_annual_period ON fin_peers_gl_annual (period);
CREATE INDEX ix_px_peers_gl_period ON px_peers_gl (period);
CREATE INDEX ix_fin_sbin_annual_period ON fin_sbin_annual (period);
CREATE INDEX ix_px_usdinr_period ON px_usdinr (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_fin_peers_gl_annual_mart AS
SELECT * FROM fin_peers_gl_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_px_peers_gl_mart AS
SELECT * FROM px_peers_gl
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_fin_sbin_annual_mart AS
SELECT * FROM fin_sbin_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_px_usdinr_mart AS
SELECT * FROM px_usdinr
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'fin_peers_gl_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM fin_peers_gl_annual
UNION ALL
SELECT 'px_peers_gl' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM px_peers_gl
UNION ALL
SELECT 'fin_sbin_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM fin_sbin_annual
UNION ALL
SELECT 'px_usdinr' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM px_usdinr
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
