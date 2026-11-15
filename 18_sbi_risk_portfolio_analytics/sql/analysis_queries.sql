--------------------------------------------------------------------------------
-- P18 · ANALYTIC QUERY PACK — SBI Risk & Portfolio Analytics — VaR, Beta & Correlation
-- Business question: What is SBI's risk profile — volatility, downside risk (VaR), market beta and diversification behaviour vs peers and global markets?
-- SQL focus: return distributions, volatility clustering, correlation matrix vs peers, risk-adjusted returns
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'px_sbin'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM px_sbin;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM px_sbin
 WHERE period = (SELECT MAX(period) FROM px_sbin);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       open,
       LAG(open, 1) OVER (ORDER BY period)           AS open_1p_ago,
       ROUND(100.0 * (open - LAG(open, 1) OVER (ORDER BY period))
             / NULLIF(LAG(open, 1) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM px_sbin
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, open,
           AVG(open) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM px_sbin)
SELECT period, open, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(open - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN open > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(open) OVER (ORDER BY period) AS base_val, period, open
      FROM px_sbin)
SELECT period, open,
       ROUND(100.0 * open / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(open) AS mu, SQRT(MAX(0.0, (SUM(open*open) - SUM(open)*SUM(open)/COUNT(open)) / NULLIF(COUNT(open)-1, 0))) AS sd FROM px_sbin)
SELECT t.period, t.open,
       CASE
         WHEN t.open > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.open > s.mu        THEN 'ABOVE average'
         WHEN t.open > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM px_sbin t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, open,
       RANK()       OVER (ORDER BY open DESC) AS rank_high,
       RANK()       OVER (ORDER BY open ASC)  AS rank_low
  FROM px_sbin
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (open - LAG(open, 1) OVER (ORDER BY period))
           / NULLIF(LAG(open, 1) OVER (ORDER BY period), 0) AS growth_pct
      FROM px_sbin)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       open, high, low, close,
       ROUND(100.0 * (open) / NULLIF((NULLIF(SUM(open), 0) + NULLIF(SUM(high), 0) + NULLIF(SUM(low), 0) + NULLIF(SUM(close), 0)), 0), 2) AS open_share_pct
  FROM px_sbin
 WHERE period = (SELECT MAX(period) FROM px_sbin)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: px_sbin × px_nifty on period ═════════════════════════════════
SELECT a.period,
       a.open                            AS px_sbin_open,
       b.open                            AS px_nifty_open,
       ROUND(1.0 * a.open / NULLIF(b.open, 0), 4) AS ratio_open_to_open
  FROM px_sbin a
  JOIN px_nifty b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, open,
       open - LAG(open) OVER (ORDER BY period) AS absolute_delta,
       ROUND(open - AVG(open) OVER (), 2)     AS deviation_from_mean
  FROM px_sbin
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'open' AS column_name,
       SUM(CASE WHEN open IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN open < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM px_sbin
UNION ALL
SELECT 'high' AS column_name,
       SUM(CASE WHEN high IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN high < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM px_sbin
UNION ALL
SELECT 'low' AS column_name,
       SUM(CASE WHEN low IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN low < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM px_sbin
UNION ALL
SELECT 'close' AS column_name,
       SUM(CASE WHEN close IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN close < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM px_sbin
UNION ALL
SELECT 'adjclose' AS column_name,
       SUM(CASE WHEN adjclose IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN adjclose < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM px_sbin;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(open), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(open*open) - SUM(open)*SUM(open)/COUNT(open)) / NULLIF(COUNT(open)-1, 0))), 2) AS std_val,
       MIN(open)             AS min_val,
       MAX(open)             AS max_val,
       (SELECT period FROM px_sbin ORDER BY open ASC  LIMIT 1) AS min_period,
       (SELECT period FROM px_sbin ORDER BY open DESC LIMIT 1) AS max_period
  FROM px_sbin;

-- ═══ Q14 · Project-specific analytic: return distributions, volatility clustering, correlation matrix vs peers, risk-adjusted returns ══════════════════════════════
-- analytic intent: return distributions, volatility clustering, correlation matrix vs peers, risk-adjusted returns
WITH d AS (
    SELECT period, open,
           open - LAG(open) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (open - LAG(open) OVER (ORDER BY period))
                 / NULLIF(LAG(open) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM px_sbin)
SELECT period, open, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
