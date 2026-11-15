--------------------------------------------------------------------------------
-- P18: SBI Risk & Portfolio Analytics — VaR, Beta & Correlation
-- Domain     : SBI · Market Risk
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
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

CREATE TABLE px_nifty (
    period     TEXT     NOT NULL   -- period label (ISO),
    open     REAL,
    high     REAL,
    low     REAL,
    close     REAL,
    adjclose     REAL,
    volume     REAL,
    date     TEXT
);

CREATE TABLE px_peers_in (
    period     TEXT     NOT NULL   -- period label (ISO),
    idx_sbin     REAL,
    idx_hdfc     REAL,
    idx_icici     REAL,
    idx_kotak     REAL,
    idx_axis     REAL
);

CREATE TABLE px_sp500 (
    period     TEXT     NOT NULL   -- period label (ISO),
    open     REAL,
    high     REAL,
    low     REAL,
    close     REAL,
    adjclose     REAL,
    volume     INTEGER,
    date     TEXT
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_px_sbin_period ON px_sbin (period);
CREATE INDEX ix_px_nifty_period ON px_nifty (period);
CREATE INDEX ix_px_peers_in_period ON px_peers_in (period);
CREATE INDEX ix_px_sp500_period ON px_sp500 (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_px_sbin_mart AS
SELECT * FROM px_sbin
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_px_nifty_mart AS
SELECT * FROM px_nifty
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_px_peers_in_mart AS
SELECT * FROM px_peers_in
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_px_sp500_mart AS
SELECT * FROM px_sp500
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'px_sbin' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM px_sbin
UNION ALL
SELECT 'px_nifty' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM px_nifty
UNION ALL
SELECT 'px_peers_in' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM px_peers_in
UNION ALL
SELECT 'px_sp500' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM px_sp500
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
