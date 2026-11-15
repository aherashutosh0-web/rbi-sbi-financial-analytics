--------------------------------------------------------------------------------
-- P17 · ANALYTIC QUERY PACK — SBI vs Global Banking Giants — International Benchmarking
-- Business question: Where does SBI stand among global banking majors (JPM, HSBC, Barclays, Citi, MUFG, BofA) on scale, profitability and valuation?
-- SQL focus: cross-market ranking, currency-normalised comparison, scale-efficiency frontier
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'fin_peers_gl_annual'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM fin_peers_gl_annual;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM fin_peers_gl_annual
 WHERE period = (SELECT MAX(period) FROM fin_peers_gl_annual);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       total_assets_usd_bn_sbin,
       LAG(total_assets_usd_bn_sbin, 1) OVER (ORDER BY period)           AS total_assets_usd_bn_sbin_1p_ago,
       ROUND(100.0 * (total_assets_usd_bn_sbin - LAG(total_assets_usd_bn_sbin, 1) OVER (ORDER BY period))
             / NULLIF(LAG(total_assets_usd_bn_sbin, 1) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM fin_peers_gl_annual
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, total_assets_usd_bn_sbin,
           AVG(total_assets_usd_bn_sbin) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM fin_peers_gl_annual)
SELECT period, total_assets_usd_bn_sbin, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(total_assets_usd_bn_sbin - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN total_assets_usd_bn_sbin > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(total_assets_usd_bn_sbin) OVER (ORDER BY period) AS base_val, period, total_assets_usd_bn_sbin
      FROM fin_peers_gl_annual)
SELECT period, total_assets_usd_bn_sbin,
       ROUND(100.0 * total_assets_usd_bn_sbin / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(total_assets_usd_bn_sbin) AS mu, SQRT(MAX(0.0, (SUM(total_assets_usd_bn_sbin*total_assets_usd_bn_sbin) - SUM(total_assets_usd_bn_sbin)*SUM(total_assets_usd_bn_sbin)/COUNT(total_assets_usd_bn_sbin)) / NULLIF(COUNT(total_assets_usd_bn_sbin)-1, 0))) AS sd FROM fin_peers_gl_annual)
SELECT t.period, t.total_assets_usd_bn_sbin,
       CASE
         WHEN t.total_assets_usd_bn_sbin > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.total_assets_usd_bn_sbin > s.mu        THEN 'ABOVE average'
         WHEN t.total_assets_usd_bn_sbin > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM fin_peers_gl_annual t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, total_assets_usd_bn_sbin,
       RANK()       OVER (ORDER BY total_assets_usd_bn_sbin DESC) AS rank_high,
       RANK()       OVER (ORDER BY total_assets_usd_bn_sbin ASC)  AS rank_low
  FROM fin_peers_gl_annual
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (total_assets_usd_bn_sbin - LAG(total_assets_usd_bn_sbin, 1) OVER (ORDER BY period))
           / NULLIF(LAG(total_assets_usd_bn_sbin, 1) OVER (ORDER BY period), 0) AS growth_pct
      FROM fin_peers_gl_annual)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       total_assets_usd_bn_sbin, net_income_usd_bn_sbin, roe_pct_sbin, total_assets_usd_bn_jpm,
       ROUND(100.0 * (total_assets_usd_bn_sbin) / NULLIF((NULLIF(SUM(total_assets_usd_bn_sbin), 0) + NULLIF(SUM(net_income_usd_bn_sbin), 0) + NULLIF(SUM(roe_pct_sbin), 0) + NULLIF(SUM(total_assets_usd_bn_jpm), 0)), 0), 2) AS total_assets_usd_bn_sbin_share_pct
  FROM fin_peers_gl_annual
 WHERE period = (SELECT MAX(period) FROM fin_peers_gl_annual)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: fin_peers_gl_annual × px_peers_gl on period ═════════════════════════════════
SELECT a.period,
       a.total_assets_usd_bn_sbin                            AS fin_peers_gl_annual_total_assets_usd_bn_sbin,
       b.idx_sbin                            AS px_peers_gl_idx_sbin,
       ROUND(1.0 * a.total_assets_usd_bn_sbin / NULLIF(b.idx_sbin, 0), 4) AS ratio_total_assets_usd_bn_sbin_to_idx_sbin
  FROM fin_peers_gl_annual a
  JOIN px_peers_gl b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, total_assets_usd_bn_sbin,
       total_assets_usd_bn_sbin - LAG(total_assets_usd_bn_sbin) OVER (ORDER BY period) AS absolute_delta,
       ROUND(total_assets_usd_bn_sbin - AVG(total_assets_usd_bn_sbin) OVER (), 2)     AS deviation_from_mean
  FROM fin_peers_gl_annual
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'total_assets_usd_bn_sbin' AS column_name,
       SUM(CASE WHEN total_assets_usd_bn_sbin IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN total_assets_usd_bn_sbin < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_peers_gl_annual
UNION ALL
SELECT 'net_income_usd_bn_sbin' AS column_name,
       SUM(CASE WHEN net_income_usd_bn_sbin IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN net_income_usd_bn_sbin < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_peers_gl_annual
UNION ALL
SELECT 'roe_pct_sbin' AS column_name,
       SUM(CASE WHEN roe_pct_sbin IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN roe_pct_sbin < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_peers_gl_annual
UNION ALL
SELECT 'total_assets_usd_bn_jpm' AS column_name,
       SUM(CASE WHEN total_assets_usd_bn_jpm IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN total_assets_usd_bn_jpm < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_peers_gl_annual
UNION ALL
SELECT 'net_income_usd_bn_jpm' AS column_name,
       SUM(CASE WHEN net_income_usd_bn_jpm IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN net_income_usd_bn_jpm < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_peers_gl_annual;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(total_assets_usd_bn_sbin), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(total_assets_usd_bn_sbin*total_assets_usd_bn_sbin) - SUM(total_assets_usd_bn_sbin)*SUM(total_assets_usd_bn_sbin)/COUNT(total_assets_usd_bn_sbin)) / NULLIF(COUNT(total_assets_usd_bn_sbin)-1, 0))), 2) AS std_val,
       MIN(total_assets_usd_bn_sbin)             AS min_val,
       MAX(total_assets_usd_bn_sbin)             AS max_val,
       (SELECT period FROM fin_peers_gl_annual ORDER BY total_assets_usd_bn_sbin ASC  LIMIT 1) AS min_period,
       (SELECT period FROM fin_peers_gl_annual ORDER BY total_assets_usd_bn_sbin DESC LIMIT 1) AS max_period
  FROM fin_peers_gl_annual;

-- ═══ Q14 · Project-specific analytic: cross-market ranking, currency-normalised comparison, scale-efficiency frontier ══════════════════════════════
-- analytic intent: cross-market ranking, currency-normalised comparison, scale-efficiency frontier
WITH d AS (
    SELECT period, total_assets_usd_bn_sbin,
           total_assets_usd_bn_sbin - LAG(total_assets_usd_bn_sbin) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (total_assets_usd_bn_sbin - LAG(total_assets_usd_bn_sbin) OVER (ORDER BY period))
                 / NULLIF(LAG(total_assets_usd_bn_sbin) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM fin_peers_gl_annual)
SELECT period, total_assets_usd_bn_sbin, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
