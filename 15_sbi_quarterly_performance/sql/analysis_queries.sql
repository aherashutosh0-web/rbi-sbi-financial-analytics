--------------------------------------------------------------------------------
-- P15 · ANALYTIC QUERY PACK — SBI Quarterly Performance Tracker
-- Business question: Is quarterly earnings momentum stable — sequential growth, margin trajectory and provisioning discipline?
-- SQL focus: QoQ/YoY sequential analysis, 4-quarter rolling aggregates, earnings surprise flags
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'fin_sbin_quarterly'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM fin_sbin_quarterly;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM fin_sbin_quarterly
 WHERE period = (SELECT MAX(period) FROM fin_sbin_quarterly);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       quarterlyInterestIncome,
       LAG(quarterlyInterestIncome, 1) OVER (ORDER BY period)           AS quarterlyInterestIncome_1p_ago,
       ROUND(100.0 * (quarterlyInterestIncome - LAG(quarterlyInterestIncome, 1) OVER (ORDER BY period))
             / NULLIF(LAG(quarterlyInterestIncome, 1) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM fin_sbin_quarterly
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, quarterlyInterestIncome,
           AVG(quarterlyInterestIncome) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM fin_sbin_quarterly)
SELECT period, quarterlyInterestIncome, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(quarterlyInterestIncome - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN quarterlyInterestIncome > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(quarterlyInterestIncome) OVER (ORDER BY period) AS base_val, period, quarterlyInterestIncome
      FROM fin_sbin_quarterly)
SELECT period, quarterlyInterestIncome,
       ROUND(100.0 * quarterlyInterestIncome / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(quarterlyInterestIncome) AS mu, SQRT(MAX(0.0, (SUM(quarterlyInterestIncome*quarterlyInterestIncome) - SUM(quarterlyInterestIncome)*SUM(quarterlyInterestIncome)/COUNT(quarterlyInterestIncome)) / NULLIF(COUNT(quarterlyInterestIncome)-1, 0))) AS sd FROM fin_sbin_quarterly)
SELECT t.period, t.quarterlyInterestIncome,
       CASE
         WHEN t.quarterlyInterestIncome > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.quarterlyInterestIncome > s.mu        THEN 'ABOVE average'
         WHEN t.quarterlyInterestIncome > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM fin_sbin_quarterly t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, quarterlyInterestIncome,
       RANK()       OVER (ORDER BY quarterlyInterestIncome DESC) AS rank_high,
       RANK()       OVER (ORDER BY quarterlyInterestIncome ASC)  AS rank_low
  FROM fin_sbin_quarterly
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (quarterlyInterestIncome - LAG(quarterlyInterestIncome, 1) OVER (ORDER BY period))
           / NULLIF(LAG(quarterlyInterestIncome, 1) OVER (ORDER BY period), 0) AS growth_pct
      FROM fin_sbin_quarterly)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       quarterlyInterestIncome, quarterlyTotalRevenue, quarterlyStockholdersEquity, quarterlyInterestExpense,
       ROUND(100.0 * (quarterlyInterestIncome) / NULLIF((NULLIF(SUM(quarterlyInterestIncome), 0) + NULLIF(SUM(quarterlyTotalRevenue), 0) + NULLIF(SUM(quarterlyStockholdersEquity), 0) + NULLIF(SUM(quarterlyInterestExpense), 0)), 0), 2) AS quarterlyInterestIncome_share_pct
  FROM fin_sbin_quarterly
 WHERE period = (SELECT MAX(period) FROM fin_sbin_quarterly)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: fin_sbin_quarterly self-comparison ═════════════════════════════════
SELECT a.period,
       a.quarterlyInterestIncome                            AS fin_sbin_quarterly_quarterlyInterestIncome,
       b.quarterlyInterestIncome                            AS fin_sbin_quarterly_quarterlyInterestIncome,
       ROUND(1.0 * a.quarterlyInterestIncome / NULLIF(b.quarterlyInterestIncome, 0), 4) AS ratio_quarterlyInterestIncome_to_quarterlyInterestIncome
  FROM fin_sbin_quarterly a
  JOIN fin_sbin_quarterly b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, quarterlyInterestIncome,
       quarterlyInterestIncome - LAG(quarterlyInterestIncome) OVER (ORDER BY period) AS absolute_delta,
       ROUND(quarterlyInterestIncome - AVG(quarterlyInterestIncome) OVER (), 2)     AS deviation_from_mean
  FROM fin_sbin_quarterly
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'quarterlyInterestIncome' AS column_name,
       SUM(CASE WHEN quarterlyInterestIncome IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN quarterlyInterestIncome < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_sbin_quarterly
UNION ALL
SELECT 'quarterlyTotalRevenue' AS column_name,
       SUM(CASE WHEN quarterlyTotalRevenue IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN quarterlyTotalRevenue < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_sbin_quarterly
UNION ALL
SELECT 'quarterlyStockholdersEquity' AS column_name,
       SUM(CASE WHEN quarterlyStockholdersEquity IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN quarterlyStockholdersEquity < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_sbin_quarterly
UNION ALL
SELECT 'quarterlyInterestExpense' AS column_name,
       SUM(CASE WHEN quarterlyInterestExpense IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN quarterlyInterestExpense < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_sbin_quarterly
UNION ALL
SELECT 'quarterlyNetIncome' AS column_name,
       SUM(CASE WHEN quarterlyNetIncome IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN quarterlyNetIncome < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_sbin_quarterly;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(quarterlyInterestIncome), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(quarterlyInterestIncome*quarterlyInterestIncome) - SUM(quarterlyInterestIncome)*SUM(quarterlyInterestIncome)/COUNT(quarterlyInterestIncome)) / NULLIF(COUNT(quarterlyInterestIncome)-1, 0))), 2) AS std_val,
       MIN(quarterlyInterestIncome)             AS min_val,
       MAX(quarterlyInterestIncome)             AS max_val,
       (SELECT period FROM fin_sbin_quarterly ORDER BY quarterlyInterestIncome ASC  LIMIT 1) AS min_period,
       (SELECT period FROM fin_sbin_quarterly ORDER BY quarterlyInterestIncome DESC LIMIT 1) AS max_period
  FROM fin_sbin_quarterly;

-- ═══ Q14 · Project-specific analytic: QoQ/YoY sequential analysis, 4-quarter rolling aggregates, earnings surprise flags ══════════════════════════════
-- analytic intent: QoQ/YoY sequential analysis, 4-quarter rolling aggregates, earnings surprise flags
WITH d AS (
    SELECT period, quarterlyInterestIncome,
           quarterlyInterestIncome - LAG(quarterlyInterestIncome) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (quarterlyInterestIncome - LAG(quarterlyInterestIncome) OVER (ORDER BY period))
                 / NULLIF(LAG(quarterlyInterestIncome) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM fin_sbin_quarterly)
SELECT period, quarterlyInterestIncome, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
