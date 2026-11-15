--------------------------------------------------------------------------------
-- P10 · ANALYTIC QUERY PACK — Digital Payments & UPI Transformation Tracker
-- Business question: How fast is the payments ecosystem digitising —UPI, cards, NEFT/RTGS—and what does volume/value growth mean for transaction banking?
-- SQL focus: channel mix shift, growth contribution, digital adoption S-curve tracking
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'payment_systems'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM payment_systems;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM payment_systems
 WHERE period = (SELECT MAX(period) FROM payment_systems);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       rtgs_volume_mn,
       LAG(rtgs_volume_mn, 12) OVER (ORDER BY period)           AS rtgs_volume_mn_12p_ago,
       ROUND(100.0 * (rtgs_volume_mn - LAG(rtgs_volume_mn, 12) OVER (ORDER BY period))
             / NULLIF(LAG(rtgs_volume_mn, 12) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM payment_systems
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, rtgs_volume_mn,
           AVG(rtgs_volume_mn) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM payment_systems)
SELECT period, rtgs_volume_mn, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(rtgs_volume_mn - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN rtgs_volume_mn > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(rtgs_volume_mn) OVER (ORDER BY period) AS base_val, period, rtgs_volume_mn
      FROM payment_systems)
SELECT period, rtgs_volume_mn,
       ROUND(100.0 * rtgs_volume_mn / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(rtgs_volume_mn) AS mu, SQRT(MAX(0.0, (SUM(rtgs_volume_mn*rtgs_volume_mn) - SUM(rtgs_volume_mn)*SUM(rtgs_volume_mn)/COUNT(rtgs_volume_mn)) / NULLIF(COUNT(rtgs_volume_mn)-1, 0))) AS sd FROM payment_systems)
SELECT t.period, t.rtgs_volume_mn,
       CASE
         WHEN t.rtgs_volume_mn > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.rtgs_volume_mn > s.mu        THEN 'ABOVE average'
         WHEN t.rtgs_volume_mn > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM payment_systems t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, rtgs_volume_mn,
       RANK()       OVER (ORDER BY rtgs_volume_mn DESC) AS rank_high,
       RANK()       OVER (ORDER BY rtgs_volume_mn ASC)  AS rank_low
  FROM payment_systems
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (rtgs_volume_mn - LAG(rtgs_volume_mn, 12) OVER (ORDER BY period))
           / NULLIF(LAG(rtgs_volume_mn, 12) OVER (ORDER BY period), 0) AS growth_pct
      FROM payment_systems)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       rtgs_volume_mn, rtgs_value_crore, aeps_volume_mn, aeps_value_crore,
       ROUND(100.0 * (rtgs_volume_mn) / NULLIF((NULLIF(SUM(rtgs_volume_mn), 0) + NULLIF(SUM(rtgs_value_crore), 0) + NULLIF(SUM(aeps_volume_mn), 0) + NULLIF(SUM(aeps_value_crore), 0)), 0), 2) AS rtgs_volume_mn_share_pct
  FROM payment_systems
 WHERE period = (SELECT MAX(period) FROM payment_systems)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: payment_systems self-comparison ═════════════════════════════════
SELECT a.period,
       a.rtgs_volume_mn                            AS payment_systems_rtgs_volume_mn,
       b.rtgs_volume_mn                            AS payment_systems_rtgs_volume_mn,
       ROUND(1.0 * a.rtgs_volume_mn / NULLIF(b.rtgs_volume_mn, 0), 4) AS ratio_rtgs_volume_mn_to_rtgs_volume_mn
  FROM payment_systems a
  JOIN payment_systems b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, rtgs_volume_mn,
       rtgs_volume_mn - LAG(rtgs_volume_mn) OVER (ORDER BY period) AS absolute_delta,
       ROUND(rtgs_volume_mn - AVG(rtgs_volume_mn) OVER (), 2)     AS deviation_from_mean
  FROM payment_systems
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'rtgs_volume_mn' AS column_name,
       SUM(CASE WHEN rtgs_volume_mn IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN rtgs_volume_mn < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM payment_systems
UNION ALL
SELECT 'rtgs_value_crore' AS column_name,
       SUM(CASE WHEN rtgs_value_crore IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN rtgs_value_crore < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM payment_systems
UNION ALL
SELECT 'aeps_volume_mn' AS column_name,
       SUM(CASE WHEN aeps_volume_mn IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN aeps_volume_mn < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM payment_systems
UNION ALL
SELECT 'aeps_value_crore' AS column_name,
       SUM(CASE WHEN aeps_value_crore IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN aeps_value_crore < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM payment_systems
UNION ALL
SELECT 'imps_volume_mn' AS column_name,
       SUM(CASE WHEN imps_volume_mn IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN imps_volume_mn < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM payment_systems;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(rtgs_volume_mn), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(rtgs_volume_mn*rtgs_volume_mn) - SUM(rtgs_volume_mn)*SUM(rtgs_volume_mn)/COUNT(rtgs_volume_mn)) / NULLIF(COUNT(rtgs_volume_mn)-1, 0))), 2) AS std_val,
       MIN(rtgs_volume_mn)             AS min_val,
       MAX(rtgs_volume_mn)             AS max_val,
       (SELECT period FROM payment_systems ORDER BY rtgs_volume_mn ASC  LIMIT 1) AS min_period,
       (SELECT period FROM payment_systems ORDER BY rtgs_volume_mn DESC LIMIT 1) AS max_period
  FROM payment_systems;

-- ═══ Q14 · Project-specific analytic: channel mix shift, growth contribution, digital adoption S-curve tracking ══════════════════════════════
-- analytic intent: channel mix shift, growth contribution, digital adoption S-curve tracking
WITH d AS (
    SELECT period, rtgs_volume_mn,
           rtgs_volume_mn - LAG(rtgs_volume_mn) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (rtgs_volume_mn - LAG(rtgs_volume_mn) OVER (ORDER BY period))
                 / NULLIF(LAG(rtgs_volume_mn) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM payment_systems)
SELECT period, rtgs_volume_mn, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
