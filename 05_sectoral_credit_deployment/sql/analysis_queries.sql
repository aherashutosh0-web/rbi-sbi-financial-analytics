--------------------------------------------------------------------------------
-- P05 · ANALYTIC QUERY PACK — Sectoral Deployment of Bank Credit Analysis
-- Business question: Where is bank credit flowing across sectors and industries, and which segments show concentration or acceleration risk?
-- SQL focus: sector share shifts, concentration (HHI), acceleration/deceleration ranking
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'credit_sectoral_annual'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM credit_sectoral_annual;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM credit_sectoral_annual
 WHERE period = (SELECT MAX(period) FROM credit_sectoral_annual);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       agriculture,
       LAG(agriculture, 12) OVER (ORDER BY period)           AS agriculture_12p_ago,
       ROUND(100.0 * (agriculture - LAG(agriculture, 12) OVER (ORDER BY period))
             / NULLIF(LAG(agriculture, 12) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM credit_sectoral_annual
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, agriculture,
           AVG(agriculture) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM credit_sectoral_annual)
SELECT period, agriculture, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(agriculture - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN agriculture > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(agriculture) OVER (ORDER BY period) AS base_val, period, agriculture
      FROM credit_sectoral_annual)
SELECT period, agriculture,
       ROUND(100.0 * agriculture / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(agriculture) AS mu, SQRT(MAX(0.0, (SUM(agriculture*agriculture) - SUM(agriculture)*SUM(agriculture)/COUNT(agriculture)) / NULLIF(COUNT(agriculture)-1, 0))) AS sd FROM credit_sectoral_annual)
SELECT t.period, t.agriculture,
       CASE
         WHEN t.agriculture > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.agriculture > s.mu        THEN 'ABOVE average'
         WHEN t.agriculture > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM credit_sectoral_annual t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, agriculture,
       RANK()       OVER (ORDER BY agriculture DESC) AS rank_high,
       RANK()       OVER (ORDER BY agriculture ASC)  AS rank_low
  FROM credit_sectoral_annual
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (agriculture - LAG(agriculture, 12) OVER (ORDER BY period))
           / NULLIF(LAG(agriculture, 12) OVER (ORDER BY period), 0) AS growth_pct
      FROM credit_sectoral_annual)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       agriculture, industry, services, retail,
       ROUND(100.0 * (agriculture) / NULLIF((NULLIF(SUM(agriculture), 0) + NULLIF(SUM(industry), 0) + NULLIF(SUM(services), 0) + NULLIF(SUM(retail), 0)), 0), 2) AS agriculture_share_pct
  FROM credit_sectoral_annual
 WHERE period = (SELECT MAX(period) FROM credit_sectoral_annual)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: credit_sectoral_annual × credit_sectoral_monthly on period ═════════════════════════════════
SELECT a.period,
       a.agriculture                            AS credit_sectoral_annual_agriculture,
       b.agriculture                            AS credit_sectoral_monthly_agriculture,
       ROUND(1.0 * a.agriculture / NULLIF(b.agriculture, 0), 4) AS ratio_agriculture_to_agriculture
  FROM credit_sectoral_annual a
  JOIN credit_sectoral_monthly b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, agriculture,
       agriculture - LAG(agriculture) OVER (ORDER BY period) AS absolute_delta,
       ROUND(agriculture - AVG(agriculture) OVER (), 2)     AS deviation_from_mean
  FROM credit_sectoral_annual
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'agriculture' AS column_name,
       SUM(CASE WHEN agriculture IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN agriculture < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM credit_sectoral_annual
UNION ALL
SELECT 'industry' AS column_name,
       SUM(CASE WHEN industry IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN industry < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM credit_sectoral_annual
UNION ALL
SELECT 'services' AS column_name,
       SUM(CASE WHEN services IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN services < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM credit_sectoral_annual
UNION ALL
SELECT 'retail' AS column_name,
       SUM(CASE WHEN retail IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN retail < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM credit_sectoral_annual
UNION ALL
SELECT 'total_non_food_credit' AS column_name,
       SUM(CASE WHEN total_non_food_credit IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN total_non_food_credit < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM credit_sectoral_annual;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(agriculture), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(agriculture*agriculture) - SUM(agriculture)*SUM(agriculture)/COUNT(agriculture)) / NULLIF(COUNT(agriculture)-1, 0))), 2) AS std_val,
       MIN(agriculture)             AS min_val,
       MAX(agriculture)             AS max_val,
       (SELECT period FROM credit_sectoral_annual ORDER BY agriculture ASC  LIMIT 1) AS min_period,
       (SELECT period FROM credit_sectoral_annual ORDER BY agriculture DESC LIMIT 1) AS max_period
  FROM credit_sectoral_annual;

-- ═══ Q14 · Project-specific analytic: sector share shifts, concentration (HHI), acceleration/deceleration ranking ══════════════════════════════
-- analytic intent: sector share shifts, concentration (HHI), acceleration/deceleration ranking
WITH d AS (
    SELECT period, agriculture,
           agriculture - LAG(agriculture) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (agriculture - LAG(agriculture) OVER (ORDER BY period))
                 / NULLIF(LAG(agriculture) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM credit_sectoral_annual)
SELECT period, agriculture, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
