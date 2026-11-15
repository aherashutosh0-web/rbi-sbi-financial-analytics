--------------------------------------------------------------------------------
-- P03 · ANALYTIC QUERY PACK — Inflation Monitor — CPI & WPI Analytics
-- Business question: What is the inflation trajectory and CPI–WPI divergence, and how should it inform pricing, provisioning and rate expectations?
-- SQL focus: inflation momentum, regime detection (high/moderate/low), CPI–WPI spread analysis
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'cpi_annual'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM cpi_annual;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM cpi_annual
 WHERE period = (SELECT MAX(period) FROM cpi_annual);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       cpi_iw,
       LAG(cpi_iw, 12) OVER (ORDER BY period)           AS cpi_iw_12p_ago,
       ROUND(100.0 * (cpi_iw - LAG(cpi_iw, 12) OVER (ORDER BY period))
             / NULLIF(LAG(cpi_iw, 12) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM cpi_annual
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, cpi_iw,
           AVG(cpi_iw) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM cpi_annual)
SELECT period, cpi_iw, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(cpi_iw - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN cpi_iw > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(cpi_iw) OVER (ORDER BY period) AS base_val, period, cpi_iw
      FROM cpi_annual)
SELECT period, cpi_iw,
       ROUND(100.0 * cpi_iw / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(cpi_iw) AS mu, SQRT(MAX(0.0, (SUM(cpi_iw*cpi_iw) - SUM(cpi_iw)*SUM(cpi_iw)/COUNT(cpi_iw)) / NULLIF(COUNT(cpi_iw)-1, 0))) AS sd FROM cpi_annual)
SELECT t.period, t.cpi_iw,
       CASE
         WHEN t.cpi_iw > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.cpi_iw > s.mu        THEN 'ABOVE average'
         WHEN t.cpi_iw > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM cpi_annual t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, cpi_iw,
       RANK()       OVER (ORDER BY cpi_iw DESC) AS rank_high,
       RANK()       OVER (ORDER BY cpi_iw ASC)  AS rank_low
  FROM cpi_annual
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (cpi_iw - LAG(cpi_iw, 12) OVER (ORDER BY period))
           / NULLIF(LAG(cpi_iw, 12) OVER (ORDER BY period), 0) AS growth_pct
      FROM cpi_annual)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       cpi_iw, cpi_iw_food, cpi_al, cpi_rural,
       ROUND(100.0 * (cpi_iw) / NULLIF((NULLIF(SUM(cpi_iw), 0) + NULLIF(SUM(cpi_iw_food), 0) + NULLIF(SUM(cpi_al), 0) + NULLIF(SUM(cpi_rural), 0)), 0), 2) AS cpi_iw_share_pct
  FROM cpi_annual
 WHERE period = (SELECT MAX(period) FROM cpi_annual)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: cpi_annual × cpi_monthly on period ═════════════════════════════════
SELECT a.period,
       a.cpi_iw                            AS cpi_annual_cpi_iw,
       b.cpi_rural                            AS cpi_monthly_cpi_rural,
       ROUND(1.0 * a.cpi_iw / NULLIF(b.cpi_rural, 0), 4) AS ratio_cpi_iw_to_cpi_rural
  FROM cpi_annual a
  JOIN cpi_monthly b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, cpi_iw,
       cpi_iw - LAG(cpi_iw) OVER (ORDER BY period) AS absolute_delta,
       ROUND(cpi_iw - AVG(cpi_iw) OVER (), 2)     AS deviation_from_mean
  FROM cpi_annual
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'cpi_iw' AS column_name,
       SUM(CASE WHEN cpi_iw IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN cpi_iw < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM cpi_annual
UNION ALL
SELECT 'cpi_iw_food' AS column_name,
       SUM(CASE WHEN cpi_iw_food IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN cpi_iw_food < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM cpi_annual
UNION ALL
SELECT 'cpi_al' AS column_name,
       SUM(CASE WHEN cpi_al IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN cpi_al < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM cpi_annual
UNION ALL
SELECT 'cpi_rural' AS column_name,
       SUM(CASE WHEN cpi_rural IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN cpi_rural < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM cpi_annual
UNION ALL
SELECT 'cpi_urban' AS column_name,
       SUM(CASE WHEN cpi_urban IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN cpi_urban < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM cpi_annual;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(cpi_iw), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(cpi_iw*cpi_iw) - SUM(cpi_iw)*SUM(cpi_iw)/COUNT(cpi_iw)) / NULLIF(COUNT(cpi_iw)-1, 0))), 2) AS std_val,
       MIN(cpi_iw)             AS min_val,
       MAX(cpi_iw)             AS max_val,
       (SELECT period FROM cpi_annual ORDER BY cpi_iw ASC  LIMIT 1) AS min_period,
       (SELECT period FROM cpi_annual ORDER BY cpi_iw DESC LIMIT 1) AS max_period
  FROM cpi_annual;

-- ═══ Q14 · Project-specific analytic: inflation momentum, regime detection (high/moderate/low), CPI–WPI spread analysis ══════════════════════════════
-- analytic intent: inflation momentum, regime detection (high/moderate/low), CPI–WPI spread analysis
WITH d AS (
    SELECT period, cpi_iw,
           cpi_iw - LAG(cpi_iw) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (cpi_iw - LAG(cpi_iw) OVER (ORDER BY period))
                 / NULLIF(LAG(cpi_iw) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM cpi_annual)
SELECT period, cpi_iw, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
