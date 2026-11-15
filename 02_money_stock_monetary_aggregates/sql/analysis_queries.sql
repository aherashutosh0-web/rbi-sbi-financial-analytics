--------------------------------------------------------------------------------
-- P02 · ANALYTIC QUERY PACK — Money Stock & Monetary Aggregates Analytics (M1–M4)
-- Business question: How is India's money supply expanding, and which components drive broad-money growth relevant to bank balance-sheet planning?
-- SQL focus: monetary growth decomposition, contribution analysis, momentum indicators
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'money_stock_annual'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM money_stock_annual;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM money_stock_annual
 WHERE period = (SELECT MAX(period) FROM money_stock_annual);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       currency_in_circulation,
       LAG(currency_in_circulation, 12) OVER (ORDER BY period)           AS currency_in_circulation_12p_ago,
       ROUND(100.0 * (currency_in_circulation - LAG(currency_in_circulation, 12) OVER (ORDER BY period))
             / NULLIF(LAG(currency_in_circulation, 12) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM money_stock_annual
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, currency_in_circulation,
           AVG(currency_in_circulation) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM money_stock_annual)
SELECT period, currency_in_circulation, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(currency_in_circulation - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN currency_in_circulation > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(currency_in_circulation) OVER (ORDER BY period) AS base_val, period, currency_in_circulation
      FROM money_stock_annual)
SELECT period, currency_in_circulation,
       ROUND(100.0 * currency_in_circulation / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(currency_in_circulation) AS mu, SQRT(MAX(0.0, (SUM(currency_in_circulation*currency_in_circulation) - SUM(currency_in_circulation)*SUM(currency_in_circulation)/COUNT(currency_in_circulation)) / NULLIF(COUNT(currency_in_circulation)-1, 0))) AS sd FROM money_stock_annual)
SELECT t.period, t.currency_in_circulation,
       CASE
         WHEN t.currency_in_circulation > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.currency_in_circulation > s.mu        THEN 'ABOVE average'
         WHEN t.currency_in_circulation > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM money_stock_annual t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, currency_in_circulation,
       RANK()       OVER (ORDER BY currency_in_circulation DESC) AS rank_high,
       RANK()       OVER (ORDER BY currency_in_circulation ASC)  AS rank_low
  FROM money_stock_annual
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (currency_in_circulation - LAG(currency_in_circulation, 12) OVER (ORDER BY period))
           / NULLIF(LAG(currency_in_circulation, 12) OVER (ORDER BY period), 0) AS growth_pct
      FROM money_stock_annual)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       currency_in_circulation, cash_with_banks, currency_with_public, others_deposits_with_rbi,
       ROUND(100.0 * (currency_in_circulation) / NULLIF((NULLIF(SUM(currency_in_circulation), 0) + NULLIF(SUM(cash_with_banks), 0) + NULLIF(SUM(currency_with_public), 0) + NULLIF(SUM(others_deposits_with_rbi), 0)), 0), 2) AS currency_in_circulation_share_pct
  FROM money_stock_annual
 WHERE period = (SELECT MAX(period) FROM money_stock_annual)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: money_stock_annual × money_stock_monthly on period ═════════════════════════════════
SELECT a.period,
       a.currency_in_circulation                            AS money_stock_annual_currency_in_circulation,
       b.currency_in_circulation                            AS money_stock_monthly_currency_in_circulation,
       ROUND(1.0 * a.currency_in_circulation / NULLIF(b.currency_in_circulation, 0), 4) AS ratio_currency_in_circulation_to_currency_in_circulation
  FROM money_stock_annual a
  JOIN money_stock_monthly b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, currency_in_circulation,
       currency_in_circulation - LAG(currency_in_circulation) OVER (ORDER BY period) AS absolute_delta,
       ROUND(currency_in_circulation - AVG(currency_in_circulation) OVER (), 2)     AS deviation_from_mean
  FROM money_stock_annual
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'currency_in_circulation' AS column_name,
       SUM(CASE WHEN currency_in_circulation IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN currency_in_circulation < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM money_stock_annual
UNION ALL
SELECT 'cash_with_banks' AS column_name,
       SUM(CASE WHEN cash_with_banks IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN cash_with_banks < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM money_stock_annual
UNION ALL
SELECT 'currency_with_public' AS column_name,
       SUM(CASE WHEN currency_with_public IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN currency_with_public < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM money_stock_annual
UNION ALL
SELECT 'others_deposits_with_rbi' AS column_name,
       SUM(CASE WHEN others_deposits_with_rbi IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN others_deposits_with_rbi < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM money_stock_annual
UNION ALL
SELECT 'bankers_deposits_with_rbi' AS column_name,
       SUM(CASE WHEN bankers_deposits_with_rbi IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN bankers_deposits_with_rbi < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM money_stock_annual;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(currency_in_circulation), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(currency_in_circulation*currency_in_circulation) - SUM(currency_in_circulation)*SUM(currency_in_circulation)/COUNT(currency_in_circulation)) / NULLIF(COUNT(currency_in_circulation)-1, 0))), 2) AS std_val,
       MIN(currency_in_circulation)             AS min_val,
       MAX(currency_in_circulation)             AS max_val,
       (SELECT period FROM money_stock_annual ORDER BY currency_in_circulation ASC  LIMIT 1) AS min_period,
       (SELECT period FROM money_stock_annual ORDER BY currency_in_circulation DESC LIMIT 1) AS max_period
  FROM money_stock_annual;

-- ═══ Q14 · Project-specific analytic: monetary growth decomposition, contribution analysis, momentum indicators ══════════════════════════════
-- analytic intent: monetary growth decomposition, contribution analysis, momentum indicators
WITH d AS (
    SELECT period, currency_in_circulation,
           currency_in_circulation - LAG(currency_in_circulation) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (currency_in_circulation - LAG(currency_in_circulation) OVER (ORDER BY period))
                 / NULLIF(LAG(currency_in_circulation) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM money_stock_annual)
SELECT period, currency_in_circulation, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
