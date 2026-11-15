--------------------------------------------------------------------------------
-- P07 · ANALYTIC QUERY PACK — Asset Quality Dashboard — NPAs & Capital Adequacy (CRAR)
-- Business question: How healthy are bank assets across ownership groups, and is the system's capital buffer distribution improving?
-- SQL focus: NPA deterioration/improvement flags, bank-group ranking, provisioning coverage gaps
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'npa_bank_group'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM npa_bank_group;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM npa_bank_group
 WHERE period = (SELECT MAX(period) FROM npa_bank_group);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       gross_npa_amount_all,
       LAG(gross_npa_amount_all, 12) OVER (ORDER BY period)           AS gross_npa_amount_all_12p_ago,
       ROUND(100.0 * (gross_npa_amount_all - LAG(gross_npa_amount_all, 12) OVER (ORDER BY period))
             / NULLIF(LAG(gross_npa_amount_all, 12) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM npa_bank_group
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, gross_npa_amount_all,
           AVG(gross_npa_amount_all) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM npa_bank_group)
SELECT period, gross_npa_amount_all, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(gross_npa_amount_all - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN gross_npa_amount_all > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(gross_npa_amount_all) OVER (ORDER BY period) AS base_val, period, gross_npa_amount_all
      FROM npa_bank_group)
SELECT period, gross_npa_amount_all,
       ROUND(100.0 * gross_npa_amount_all / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(gross_npa_amount_all) AS mu, SQRT(MAX(0.0, (SUM(gross_npa_amount_all*gross_npa_amount_all) - SUM(gross_npa_amount_all)*SUM(gross_npa_amount_all)/COUNT(gross_npa_amount_all)) / NULLIF(COUNT(gross_npa_amount_all)-1, 0))) AS sd FROM npa_bank_group)
SELECT t.period, t.gross_npa_amount_all,
       CASE
         WHEN t.gross_npa_amount_all > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.gross_npa_amount_all > s.mu        THEN 'ABOVE average'
         WHEN t.gross_npa_amount_all > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM npa_bank_group t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, gross_npa_amount_all,
       RANK()       OVER (ORDER BY gross_npa_amount_all DESC) AS rank_high,
       RANK()       OVER (ORDER BY gross_npa_amount_all ASC)  AS rank_low
  FROM npa_bank_group
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (gross_npa_amount_all - LAG(gross_npa_amount_all, 12) OVER (ORDER BY period))
           / NULLIF(LAG(gross_npa_amount_all, 12) OVER (ORDER BY period), 0) AS growth_pct
      FROM npa_bank_group)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       gross_npa_amount_all, gross_npa_to_advances_pct_all, net_npa_amount_all, net_npa_to_advances_pct_all,
       ROUND(100.0 * (gross_npa_amount_all) / NULLIF((NULLIF(SUM(gross_npa_amount_all), 0) + NULLIF(SUM(gross_npa_to_advances_pct_all), 0) + NULLIF(SUM(net_npa_amount_all), 0) + NULLIF(SUM(net_npa_to_advances_pct_all), 0)), 0), 2) AS gross_npa_amount_all_share_pct
  FROM npa_bank_group
 WHERE period = (SELECT MAX(period) FROM npa_bank_group)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: npa_bank_group × crar_distribution on period ═════════════════════════════════
SELECT a.period,
       a.gross_npa_amount_all                            AS npa_bank_group_gross_npa_amount_all,
       b.banks_below_9pct                            AS crar_distribution_banks_below_9pct,
       ROUND(1.0 * a.gross_npa_amount_all / NULLIF(b.banks_below_9pct, 0), 4) AS ratio_gross_npa_amount_all_to_banks_below_9pct
  FROM npa_bank_group a
  JOIN crar_distribution b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, gross_npa_amount_all,
       gross_npa_amount_all - LAG(gross_npa_amount_all) OVER (ORDER BY period) AS absolute_delta,
       ROUND(gross_npa_amount_all - AVG(gross_npa_amount_all) OVER (), 2)     AS deviation_from_mean
  FROM npa_bank_group
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'gross_npa_amount_all' AS column_name,
       SUM(CASE WHEN gross_npa_amount_all IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN gross_npa_amount_all < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM npa_bank_group
UNION ALL
SELECT 'gross_npa_to_advances_pct_all' AS column_name,
       SUM(CASE WHEN gross_npa_to_advances_pct_all IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN gross_npa_to_advances_pct_all < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM npa_bank_group
UNION ALL
SELECT 'net_npa_amount_all' AS column_name,
       SUM(CASE WHEN net_npa_amount_all IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN net_npa_amount_all < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM npa_bank_group
UNION ALL
SELECT 'net_npa_to_advances_pct_all' AS column_name,
       SUM(CASE WHEN net_npa_to_advances_pct_all IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN net_npa_to_advances_pct_all < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM npa_bank_group
UNION ALL
SELECT 'advances_gross_all' AS column_name,
       SUM(CASE WHEN advances_gross_all IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN advances_gross_all < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM npa_bank_group;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(gross_npa_amount_all), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(gross_npa_amount_all*gross_npa_amount_all) - SUM(gross_npa_amount_all)*SUM(gross_npa_amount_all)/COUNT(gross_npa_amount_all)) / NULLIF(COUNT(gross_npa_amount_all)-1, 0))), 2) AS std_val,
       MIN(gross_npa_amount_all)             AS min_val,
       MAX(gross_npa_amount_all)             AS max_val,
       (SELECT period FROM npa_bank_group ORDER BY gross_npa_amount_all ASC  LIMIT 1) AS min_period,
       (SELECT period FROM npa_bank_group ORDER BY gross_npa_amount_all DESC LIMIT 1) AS max_period
  FROM npa_bank_group;

-- ═══ Q14 · Project-specific analytic: NPA deterioration/improvement flags, bank-group ranking, provisioning coverage gaps ══════════════════════════════
-- analytic intent: NPA deterioration/improvement flags, bank-group ranking, provisioning coverage gaps
WITH d AS (
    SELECT period, gross_npa_amount_all,
           gross_npa_amount_all - LAG(gross_npa_amount_all) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (gross_npa_amount_all - LAG(gross_npa_amount_all) OVER (ORDER BY period))
                 / NULLIF(LAG(gross_npa_amount_all) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM npa_bank_group)
SELECT period, gross_npa_amount_all, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
