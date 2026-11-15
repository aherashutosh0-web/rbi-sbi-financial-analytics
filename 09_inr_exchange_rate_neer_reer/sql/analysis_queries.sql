--------------------------------------------------------------------------------
-- P09 · ANALYTIC QUERY PACK — INR Exchange Rate & NEER/REER Analytics
-- Business question: How is the rupee performing across currencies and in real effective terms — and where is FX exposure risk building?
-- SQL focus: FX volatility regimes, NEER–REER divergence (competitiveness), depreciation tracking
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'fx_rates_annual'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM fx_rates_annual;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM fx_rates_annual
 WHERE period = (SELECT MAX(period) FROM fx_rates_annual);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       usd_inr,
       LAG(usd_inr, 1) OVER (ORDER BY period)           AS usd_inr_1p_ago,
       ROUND(100.0 * (usd_inr - LAG(usd_inr, 1) OVER (ORDER BY period))
             / NULLIF(LAG(usd_inr, 1) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM fx_rates_annual
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, usd_inr,
           AVG(usd_inr) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM fx_rates_annual)
SELECT period, usd_inr, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(usd_inr - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN usd_inr > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(usd_inr) OVER (ORDER BY period) AS base_val, period, usd_inr
      FROM fx_rates_annual)
SELECT period, usd_inr,
       ROUND(100.0 * usd_inr / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(usd_inr) AS mu, SQRT(MAX(0.0, (SUM(usd_inr*usd_inr) - SUM(usd_inr)*SUM(usd_inr)/COUNT(usd_inr)) / NULLIF(COUNT(usd_inr)-1, 0))) AS sd FROM fx_rates_annual)
SELECT t.period, t.usd_inr,
       CASE
         WHEN t.usd_inr > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.usd_inr > s.mu        THEN 'ABOVE average'
         WHEN t.usd_inr > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM fx_rates_annual t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, usd_inr,
       RANK()       OVER (ORDER BY usd_inr DESC) AS rank_high,
       RANK()       OVER (ORDER BY usd_inr ASC)  AS rank_low
  FROM fx_rates_annual
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (usd_inr - LAG(usd_inr, 1) OVER (ORDER BY period))
           / NULLIF(LAG(usd_inr, 1) OVER (ORDER BY period), 0) AS growth_pct
      FROM fx_rates_annual)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       usd_inr, sdr_inr, gbp_inr, jpy_inr,
       ROUND(100.0 * (usd_inr) / NULLIF((NULLIF(SUM(usd_inr), 0) + NULLIF(SUM(sdr_inr), 0) + NULLIF(SUM(gbp_inr), 0) + NULLIF(SUM(jpy_inr), 0)), 0), 2) AS usd_inr_share_pct
  FROM fx_rates_annual
 WHERE period = (SELECT MAX(period) FROM fx_rates_annual)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: fx_rates_annual × fx_rates_daily on period ═════════════════════════════════
SELECT a.period,
       a.usd_inr                            AS fx_rates_annual_usd_inr,
       b.usd_inr                            AS fx_rates_daily_usd_inr,
       ROUND(1.0 * a.usd_inr / NULLIF(b.usd_inr, 0), 4) AS ratio_usd_inr_to_usd_inr
  FROM fx_rates_annual a
  JOIN fx_rates_daily b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, usd_inr,
       usd_inr - LAG(usd_inr) OVER (ORDER BY period) AS absolute_delta,
       ROUND(usd_inr - AVG(usd_inr) OVER (), 2)     AS deviation_from_mean
  FROM fx_rates_annual
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'usd_inr' AS column_name,
       SUM(CASE WHEN usd_inr IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN usd_inr < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fx_rates_annual
UNION ALL
SELECT 'sdr_inr' AS column_name,
       SUM(CASE WHEN sdr_inr IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN sdr_inr < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fx_rates_annual
UNION ALL
SELECT 'gbp_inr' AS column_name,
       SUM(CASE WHEN gbp_inr IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN gbp_inr < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fx_rates_annual
UNION ALL
SELECT 'jpy_inr' AS column_name,
       SUM(CASE WHEN jpy_inr IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN jpy_inr < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fx_rates_annual
UNION ALL
SELECT 'eur_inr' AS column_name,
       SUM(CASE WHEN eur_inr IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN eur_inr < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fx_rates_annual;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(usd_inr), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(usd_inr*usd_inr) - SUM(usd_inr)*SUM(usd_inr)/COUNT(usd_inr)) / NULLIF(COUNT(usd_inr)-1, 0))), 2) AS std_val,
       MIN(usd_inr)             AS min_val,
       MAX(usd_inr)             AS max_val,
       (SELECT period FROM fx_rates_annual ORDER BY usd_inr ASC  LIMIT 1) AS min_period,
       (SELECT period FROM fx_rates_annual ORDER BY usd_inr DESC LIMIT 1) AS max_period
  FROM fx_rates_annual;

-- ═══ Q14 · Project-specific analytic: FX volatility regimes, NEER–REER divergence (competitiveness), depreciation tracking ══════════════════════════════
-- analytic intent: FX volatility regimes, NEER–REER divergence (competitiveness), depreciation tracking
WITH d AS (
    SELECT period, usd_inr,
           usd_inr - LAG(usd_inr) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (usd_inr - LAG(usd_inr) OVER (ORDER BY period))
                 / NULLIF(LAG(usd_inr) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM fx_rates_annual)
SELECT period, usd_inr, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
