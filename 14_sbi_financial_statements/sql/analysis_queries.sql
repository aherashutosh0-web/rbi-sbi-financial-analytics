--------------------------------------------------------------------------------
-- P14 · ANALYTIC QUERY PACK — SBI Financial Statement Analysis (Consolidated)
-- Business question: How are SBI's revenue, profitability, balance-sheet strength and shareholder returns evolving year over year?
-- SQL focus: growth rates, margin decomposition, leverage and return ratios, EPS/valuation bridge
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'fin_sbin_annual'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM fin_sbin_annual;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM fin_sbin_annual
 WHERE period = (SELECT MAX(period) FROM fin_sbin_annual);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       annualDilutedEPS,
       LAG(annualDilutedEPS, 1) OVER (ORDER BY period)           AS annualDilutedEPS_1p_ago,
       ROUND(100.0 * (annualDilutedEPS - LAG(annualDilutedEPS, 1) OVER (ORDER BY period))
             / NULLIF(LAG(annualDilutedEPS, 1) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM fin_sbin_annual
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, annualDilutedEPS,
           AVG(annualDilutedEPS) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM fin_sbin_annual)
SELECT period, annualDilutedEPS, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(annualDilutedEPS - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN annualDilutedEPS > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(annualDilutedEPS) OVER (ORDER BY period) AS base_val, period, annualDilutedEPS
      FROM fin_sbin_annual)
SELECT period, annualDilutedEPS,
       ROUND(100.0 * annualDilutedEPS / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(annualDilutedEPS) AS mu, SQRT(MAX(0.0, (SUM(annualDilutedEPS*annualDilutedEPS) - SUM(annualDilutedEPS)*SUM(annualDilutedEPS)/COUNT(annualDilutedEPS)) / NULLIF(COUNT(annualDilutedEPS)-1, 0))) AS sd FROM fin_sbin_annual)
SELECT t.period, t.annualDilutedEPS,
       CASE
         WHEN t.annualDilutedEPS > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.annualDilutedEPS > s.mu        THEN 'ABOVE average'
         WHEN t.annualDilutedEPS > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM fin_sbin_annual t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, annualDilutedEPS,
       RANK()       OVER (ORDER BY annualDilutedEPS DESC) AS rank_high,
       RANK()       OVER (ORDER BY annualDilutedEPS ASC)  AS rank_low
  FROM fin_sbin_annual
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (annualDilutedEPS - LAG(annualDilutedEPS, 1) OVER (ORDER BY period))
           / NULLIF(LAG(annualDilutedEPS, 1) OVER (ORDER BY period), 0) AS growth_pct
      FROM fin_sbin_annual)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       annualDilutedEPS, annualTotalDebt, annualTotalAssets, annualInterestIncome,
       ROUND(100.0 * (annualDilutedEPS) / NULLIF((NULLIF(SUM(annualDilutedEPS), 0) + NULLIF(SUM(annualTotalDebt), 0) + NULLIF(SUM(annualTotalAssets), 0) + NULLIF(SUM(annualInterestIncome), 0)), 0), 2) AS annualDilutedEPS_share_pct
  FROM fin_sbin_annual
 WHERE period = (SELECT MAX(period) FROM fin_sbin_annual)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: fin_sbin_annual × px_sbin on period ═════════════════════════════════
SELECT a.period,
       a.annualDilutedEPS                            AS fin_sbin_annual_annualDilutedEPS,
       b.open                            AS px_sbin_open,
       ROUND(1.0 * a.annualDilutedEPS / NULLIF(b.open, 0), 4) AS ratio_annualDilutedEPS_to_open
  FROM fin_sbin_annual a
  JOIN px_sbin b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, annualDilutedEPS,
       annualDilutedEPS - LAG(annualDilutedEPS) OVER (ORDER BY period) AS absolute_delta,
       ROUND(annualDilutedEPS - AVG(annualDilutedEPS) OVER (), 2)     AS deviation_from_mean
  FROM fin_sbin_annual
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'annualDilutedEPS' AS column_name,
       SUM(CASE WHEN annualDilutedEPS IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN annualDilutedEPS < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_sbin_annual
UNION ALL
SELECT 'annualTotalDebt' AS column_name,
       SUM(CASE WHEN annualTotalDebt IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN annualTotalDebt < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_sbin_annual
UNION ALL
SELECT 'annualTotalAssets' AS column_name,
       SUM(CASE WHEN annualTotalAssets IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN annualTotalAssets < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_sbin_annual
UNION ALL
SELECT 'annualInterestIncome' AS column_name,
       SUM(CASE WHEN annualInterestIncome IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN annualInterestIncome < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_sbin_annual
UNION ALL
SELECT 'annualNetIncome' AS column_name,
       SUM(CASE WHEN annualNetIncome IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN annualNetIncome < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_sbin_annual;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(annualDilutedEPS), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(annualDilutedEPS*annualDilutedEPS) - SUM(annualDilutedEPS)*SUM(annualDilutedEPS)/COUNT(annualDilutedEPS)) / NULLIF(COUNT(annualDilutedEPS)-1, 0))), 2) AS std_val,
       MIN(annualDilutedEPS)             AS min_val,
       MAX(annualDilutedEPS)             AS max_val,
       (SELECT period FROM fin_sbin_annual ORDER BY annualDilutedEPS ASC  LIMIT 1) AS min_period,
       (SELECT period FROM fin_sbin_annual ORDER BY annualDilutedEPS DESC LIMIT 1) AS max_period
  FROM fin_sbin_annual;

-- ═══ Q14 · Project-specific analytic: growth rates, margin decomposition, leverage and return ratios, EPS/valuation bridge ══════════════════════════════
-- analytic intent: growth rates, margin decomposition, leverage and return ratios, EPS/valuation bridge
WITH d AS (
    SELECT period, annualDilutedEPS,
           annualDilutedEPS - LAG(annualDilutedEPS) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (annualDilutedEPS - LAG(annualDilutedEPS) OVER (ORDER BY period))
                 / NULLIF(LAG(annualDilutedEPS) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM fin_sbin_annual)
SELECT period, annualDilutedEPS, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
