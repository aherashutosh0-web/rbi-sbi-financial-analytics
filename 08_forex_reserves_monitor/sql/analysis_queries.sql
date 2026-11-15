--------------------------------------------------------------------------------
-- P08 · ANALYTIC QUERY PACK — India Forex Reserves Monitor (Annual · Monthly · Weekly)
-- Business question: How strong is the reserve buffer — composition, trend and import cover — and what does it imply for rupee stability?
-- SQL focus: composition share shifts, WoW/MoM momentum, drawdown/accumulation regimes
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'forex_annual'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM forex_annual;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM forex_annual
 WHERE period = (SELECT MAX(period) FROM forex_annual);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       sdr_inr_crore,
       LAG(sdr_inr_crore, 12) OVER (ORDER BY period)           AS sdr_inr_crore_12p_ago,
       ROUND(100.0 * (sdr_inr_crore - LAG(sdr_inr_crore, 12) OVER (ORDER BY period))
             / NULLIF(LAG(sdr_inr_crore, 12) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM forex_annual
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, sdr_inr_crore,
           AVG(sdr_inr_crore) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM forex_annual)
SELECT period, sdr_inr_crore, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(sdr_inr_crore - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN sdr_inr_crore > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(sdr_inr_crore) OVER (ORDER BY period) AS base_val, period, sdr_inr_crore
      FROM forex_annual)
SELECT period, sdr_inr_crore,
       ROUND(100.0 * sdr_inr_crore / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(sdr_inr_crore) AS mu, SQRT(MAX(0.0, (SUM(sdr_inr_crore*sdr_inr_crore) - SUM(sdr_inr_crore)*SUM(sdr_inr_crore)/COUNT(sdr_inr_crore)) / NULLIF(COUNT(sdr_inr_crore)-1, 0))) AS sd FROM forex_annual)
SELECT t.period, t.sdr_inr_crore,
       CASE
         WHEN t.sdr_inr_crore > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.sdr_inr_crore > s.mu        THEN 'ABOVE average'
         WHEN t.sdr_inr_crore > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM forex_annual t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, sdr_inr_crore,
       RANK()       OVER (ORDER BY sdr_inr_crore DESC) AS rank_high,
       RANK()       OVER (ORDER BY sdr_inr_crore ASC)  AS rank_low
  FROM forex_annual
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (sdr_inr_crore - LAG(sdr_inr_crore, 12) OVER (ORDER BY period))
           / NULLIF(LAG(sdr_inr_crore, 12) OVER (ORDER BY period), 0) AS growth_pct
      FROM forex_annual)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       sdr_inr_crore, sdr_usd_mn, gold_inr_crore, gold_usd_mn,
       ROUND(100.0 * (sdr_inr_crore) / NULLIF((NULLIF(SUM(sdr_inr_crore), 0) + NULLIF(SUM(sdr_usd_mn), 0) + NULLIF(SUM(gold_inr_crore), 0) + NULLIF(SUM(gold_usd_mn), 0)), 0), 2) AS sdr_inr_crore_share_pct
  FROM forex_annual
 WHERE period = (SELECT MAX(period) FROM forex_annual)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: forex_annual × forex_monthly on period ═════════════════════════════════
SELECT a.period,
       a.sdr_inr_crore                            AS forex_annual_sdr_inr_crore,
       b.sdr_inr_crore                            AS forex_monthly_sdr_inr_crore,
       ROUND(1.0 * a.sdr_inr_crore / NULLIF(b.sdr_inr_crore, 0), 4) AS ratio_sdr_inr_crore_to_sdr_inr_crore
  FROM forex_annual a
  JOIN forex_monthly b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, sdr_inr_crore,
       sdr_inr_crore - LAG(sdr_inr_crore) OVER (ORDER BY period) AS absolute_delta,
       ROUND(sdr_inr_crore - AVG(sdr_inr_crore) OVER (), 2)     AS deviation_from_mean
  FROM forex_annual
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'sdr_inr_crore' AS column_name,
       SUM(CASE WHEN sdr_inr_crore IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN sdr_inr_crore < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM forex_annual
UNION ALL
SELECT 'sdr_usd_mn' AS column_name,
       SUM(CASE WHEN sdr_usd_mn IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN sdr_usd_mn < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM forex_annual
UNION ALL
SELECT 'gold_inr_crore' AS column_name,
       SUM(CASE WHEN gold_inr_crore IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN gold_inr_crore < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM forex_annual
UNION ALL
SELECT 'gold_usd_mn' AS column_name,
       SUM(CASE WHEN gold_usd_mn IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN gold_usd_mn < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM forex_annual
UNION ALL
SELECT 'fca_inr_crore' AS column_name,
       SUM(CASE WHEN fca_inr_crore IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN fca_inr_crore < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM forex_annual;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(sdr_inr_crore), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(sdr_inr_crore*sdr_inr_crore) - SUM(sdr_inr_crore)*SUM(sdr_inr_crore)/COUNT(sdr_inr_crore)) / NULLIF(COUNT(sdr_inr_crore)-1, 0))), 2) AS std_val,
       MIN(sdr_inr_crore)             AS min_val,
       MAX(sdr_inr_crore)             AS max_val,
       (SELECT period FROM forex_annual ORDER BY sdr_inr_crore ASC  LIMIT 1) AS min_period,
       (SELECT period FROM forex_annual ORDER BY sdr_inr_crore DESC LIMIT 1) AS max_period
  FROM forex_annual;

-- ═══ Q14 · Project-specific analytic: composition share shifts, WoW/MoM momentum, drawdown/accumulation regimes ══════════════════════════════
-- analytic intent: composition share shifts, WoW/MoM momentum, drawdown/accumulation regimes
WITH d AS (
    SELECT period, sdr_inr_crore,
           sdr_inr_crore - LAG(sdr_inr_crore) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (sdr_inr_crore - LAG(sdr_inr_crore) OVER (ORDER BY period))
                 / NULLIF(LAG(sdr_inr_crore) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM forex_annual)
SELECT period, sdr_inr_crore, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
