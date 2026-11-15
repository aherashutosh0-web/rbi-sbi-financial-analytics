--------------------------------------------------------------------------------
-- P01 · ANALYTIC QUERY PACK — RBI Monetary Policy & Reserve Requirements Tracker
-- Business question: How have RBI's policy rates and reserve requirements evolved, and what is the current monetary stance for banking operations?
-- SQL focus: rate corridor positioning, regime classification, year-over-year policy shifts
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'policy_rates'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM policy_rates;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM policy_rates
 WHERE period = (SELECT MAX(period) FROM policy_rates);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       bank_rate,
       LAG(bank_rate, 1) OVER (ORDER BY period)           AS bank_rate_1p_ago,
       ROUND(100.0 * (bank_rate - LAG(bank_rate, 1) OVER (ORDER BY period))
             / NULLIF(LAG(bank_rate, 1) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM policy_rates
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, bank_rate,
           AVG(bank_rate) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM policy_rates)
SELECT period, bank_rate, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(bank_rate - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN bank_rate > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(bank_rate) OVER (ORDER BY period) AS base_val, period, bank_rate
      FROM policy_rates)
SELECT period, bank_rate,
       ROUND(100.0 * bank_rate / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(bank_rate) AS mu, SQRT(MAX(0.0, (SUM(bank_rate*bank_rate) - SUM(bank_rate)*SUM(bank_rate)/COUNT(bank_rate)) / NULLIF(COUNT(bank_rate)-1, 0))) AS sd FROM policy_rates)
SELECT t.period, t.bank_rate,
       CASE
         WHEN t.bank_rate > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.bank_rate > s.mu        THEN 'ABOVE average'
         WHEN t.bank_rate > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM policy_rates t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, bank_rate,
       RANK()       OVER (ORDER BY bank_rate DESC) AS rank_high,
       RANK()       OVER (ORDER BY bank_rate ASC)  AS rank_low
  FROM policy_rates
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (bank_rate - LAG(bank_rate, 1) OVER (ORDER BY period))
           / NULLIF(LAG(bank_rate, 1) OVER (ORDER BY period), 0) AS growth_pct
      FROM policy_rates)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       bank_rate, repo_rate, reverse_repo_rate, sdf_rate,
       ROUND(100.0 * (bank_rate) / NULLIF((NULLIF(SUM(bank_rate), 0) + NULLIF(SUM(repo_rate), 0) + NULLIF(SUM(reverse_repo_rate), 0) + NULLIF(SUM(sdf_rate), 0)), 0), 2) AS bank_rate_share_pct
  FROM policy_rates
 WHERE period = (SELECT MAX(period) FROM policy_rates)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: policy_rates self-comparison ═════════════════════════════════
SELECT a.period,
       a.bank_rate                            AS policy_rates_bank_rate,
       b.bank_rate                            AS policy_rates_bank_rate,
       ROUND(1.0 * a.bank_rate / NULLIF(b.bank_rate, 0), 4) AS ratio_bank_rate_to_bank_rate
  FROM policy_rates a
  JOIN policy_rates b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, bank_rate,
       bank_rate - LAG(bank_rate) OVER (ORDER BY period) AS absolute_delta,
       ROUND(bank_rate - AVG(bank_rate) OVER (), 2)     AS deviation_from_mean
  FROM policy_rates
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'bank_rate' AS column_name,
       SUM(CASE WHEN bank_rate IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN bank_rate < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM policy_rates
UNION ALL
SELECT 'repo_rate' AS column_name,
       SUM(CASE WHEN repo_rate IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN repo_rate < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM policy_rates
UNION ALL
SELECT 'reverse_repo_rate' AS column_name,
       SUM(CASE WHEN reverse_repo_rate IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN reverse_repo_rate < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM policy_rates
UNION ALL
SELECT 'sdf_rate' AS column_name,
       SUM(CASE WHEN sdf_rate IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN sdf_rate < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM policy_rates
UNION ALL
SELECT 'msf_rate' AS column_name,
       SUM(CASE WHEN msf_rate IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN msf_rate < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM policy_rates;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(bank_rate), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(bank_rate*bank_rate) - SUM(bank_rate)*SUM(bank_rate)/COUNT(bank_rate)) / NULLIF(COUNT(bank_rate)-1, 0))), 2) AS std_val,
       MIN(bank_rate)             AS min_val,
       MAX(bank_rate)             AS max_val,
       (SELECT period FROM policy_rates ORDER BY bank_rate ASC  LIMIT 1) AS min_period,
       (SELECT period FROM policy_rates ORDER BY bank_rate DESC LIMIT 1) AS max_period
  FROM policy_rates;

-- ═══ Q14 · Project-specific analytic: rate corridor positioning, regime classification, year-over-year policy shifts ══════════════════════════════
-- analytic intent: rate corridor positioning, regime classification, year-over-year policy shifts
WITH d AS (
    SELECT period, bank_rate,
           bank_rate - LAG(bank_rate) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (bank_rate - LAG(bank_rate) OVER (ORDER BY period))
                 / NULLIF(LAG(bank_rate) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM policy_rates)
SELECT period, bank_rate, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
