--------------------------------------------------------------------------------
-- P12 · ANALYTIC QUERY PACK — Indian Capital Market Context — SENSEX & NIFTY
-- Business question: What is the equity-market backdrop — levels, returns and volatility—against which SBI's valuation must be judged?
-- SQL focus: benchmark returns, drawdowns, monthly momentum, valuation regime classification
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'market_indices_annual'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM market_indices_annual;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM market_indices_annual
 WHERE period = (SELECT MAX(period) FROM market_indices_annual);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       sensex_avg,
       LAG(sensex_avg, 12) OVER (ORDER BY period)           AS sensex_avg_12p_ago,
       ROUND(100.0 * (sensex_avg - LAG(sensex_avg, 12) OVER (ORDER BY period))
             / NULLIF(LAG(sensex_avg, 12) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM market_indices_annual
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, sensex_avg,
           AVG(sensex_avg) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM market_indices_annual)
SELECT period, sensex_avg, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(sensex_avg - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN sensex_avg > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(sensex_avg) OVER (ORDER BY period) AS base_val, period, sensex_avg
      FROM market_indices_annual)
SELECT period, sensex_avg,
       ROUND(100.0 * sensex_avg / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(sensex_avg) AS mu, SQRT(MAX(0.0, (SUM(sensex_avg*sensex_avg) - SUM(sensex_avg)*SUM(sensex_avg)/COUNT(sensex_avg)) / NULLIF(COUNT(sensex_avg)-1, 0))) AS sd FROM market_indices_annual)
SELECT t.period, t.sensex_avg,
       CASE
         WHEN t.sensex_avg > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.sensex_avg > s.mu        THEN 'ABOVE average'
         WHEN t.sensex_avg > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM market_indices_annual t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, sensex_avg,
       RANK()       OVER (ORDER BY sensex_avg DESC) AS rank_high,
       RANK()       OVER (ORDER BY sensex_avg ASC)  AS rank_low
  FROM market_indices_annual
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (sensex_avg - LAG(sensex_avg, 12) OVER (ORDER BY period))
           / NULLIF(LAG(sensex_avg, 12) OVER (ORDER BY period), 0) AS growth_pct
      FROM market_indices_annual)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       sensex_avg, bse100_avg, rbi_index_avg, market_cap_bse_crore,
       ROUND(100.0 * (sensex_avg) / NULLIF((NULLIF(SUM(sensex_avg), 0) + NULLIF(SUM(bse100_avg), 0) + NULLIF(SUM(rbi_index_avg), 0) + NULLIF(SUM(market_cap_bse_crore), 0)), 0), 2) AS sensex_avg_share_pct
  FROM market_indices_annual
 WHERE period = (SELECT MAX(period) FROM market_indices_annual)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: market_indices_annual × nifty_monthly on period ═════════════════════════════════
SELECT a.period,
       a.sensex_avg                            AS market_indices_annual_sensex_avg,
       b.nifty_avg                            AS nifty_monthly_nifty_avg,
       ROUND(1.0 * a.sensex_avg / NULLIF(b.nifty_avg, 0), 4) AS ratio_sensex_avg_to_nifty_avg
  FROM market_indices_annual a
  JOIN nifty_monthly b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, sensex_avg,
       sensex_avg - LAG(sensex_avg) OVER (ORDER BY period) AS absolute_delta,
       ROUND(sensex_avg - AVG(sensex_avg) OVER (), 2)     AS deviation_from_mean
  FROM market_indices_annual
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'sensex_avg' AS column_name,
       SUM(CASE WHEN sensex_avg IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN sensex_avg < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM market_indices_annual
UNION ALL
SELECT 'bse100_avg' AS column_name,
       SUM(CASE WHEN bse100_avg IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN bse100_avg < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM market_indices_annual
UNION ALL
SELECT 'rbi_index_avg' AS column_name,
       SUM(CASE WHEN rbi_index_avg IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN rbi_index_avg < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM market_indices_annual
UNION ALL
SELECT 'market_cap_bse_crore' AS column_name,
       SUM(CASE WHEN market_cap_bse_crore IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN market_cap_bse_crore < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM market_indices_annual
UNION ALL
SELECT 'market_cap_allindia_crore' AS column_name,
       SUM(CASE WHEN market_cap_allindia_crore IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN market_cap_allindia_crore < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM market_indices_annual;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(sensex_avg), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(sensex_avg*sensex_avg) - SUM(sensex_avg)*SUM(sensex_avg)/COUNT(sensex_avg)) / NULLIF(COUNT(sensex_avg)-1, 0))), 2) AS std_val,
       MIN(sensex_avg)             AS min_val,
       MAX(sensex_avg)             AS max_val,
       (SELECT period FROM market_indices_annual ORDER BY sensex_avg ASC  LIMIT 1) AS min_period,
       (SELECT period FROM market_indices_annual ORDER BY sensex_avg DESC LIMIT 1) AS max_period
  FROM market_indices_annual;

-- ═══ Q14 · Project-specific analytic: benchmark returns, drawdowns, monthly momentum, valuation regime classification ══════════════════════════════
-- analytic intent: benchmark returns, drawdowns, monthly momentum, valuation regime classification
WITH d AS (
    SELECT period, sensex_avg,
           sensex_avg - LAG(sensex_avg) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (sensex_avg - LAG(sensex_avg) OVER (ORDER BY period))
                 / NULLIF(LAG(sensex_avg) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM market_indices_annual)
SELECT period, sensex_avg, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
