--------------------------------------------------------------------------------
-- P14: SBI Financial Statement Analysis (Consolidated)
-- Domain     : SBI · Financial Performance
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
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

CREATE TABLE px_sbin (
    period     TEXT     NOT NULL   -- period label (ISO),
    open     REAL,
    high     REAL,
    low     REAL,
    close     REAL,
    adjclose     REAL,
    volume     REAL,
    dividend     REAL,
    ma_50     REAL,
    ma_200     REAL,
    volatility_60d     REAL,
    annual_volatility_pct     REAL,
    drawdown_pct     REAL,
    max_drawdown_pct     REAL,
    var_95_pct     REAL,
    cum_sbin     REAL,
    cum_nifty     REAL,
    beta_nifty     REAL,
    monthly_return_pct     REAL,
    date     TEXT
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_fin_sbin_annual_period ON fin_sbin_annual (period);
CREATE INDEX ix_px_sbin_period ON px_sbin (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_fin_sbin_annual_mart AS
SELECT * FROM fin_sbin_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_px_sbin_mart AS
SELECT * FROM px_sbin
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'fin_sbin_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM fin_sbin_annual
UNION ALL
SELECT 'px_sbin' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM px_sbin
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
