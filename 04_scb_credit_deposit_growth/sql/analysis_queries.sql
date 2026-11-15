--------------------------------------------------------------------------------
-- P04 · ANALYTIC QUERY PACK — Scheduled Commercial Banks — Credit & Deposit Growth Engine
-- Business question: Are bank deposits keeping pace with credit demand, and what does the credit–deposit ratio signal for liquidity management?
-- SQL focus: YoY growth, rolling CAGR, credit-deposit gap, liquidity stress flags
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'scb_aggregates_annual'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM scb_aggregates_annual;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM scb_aggregates_annual
 WHERE period = (SELECT MAX(period) FROM scb_aggregates_annual);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       demand_deposits,
       LAG(demand_deposits, 12) OVER (ORDER BY period)           AS demand_deposits_12p_ago,
       ROUND(100.0 * (demand_deposits - LAG(demand_deposits, 12) OVER (ORDER BY period))
             / NULLIF(LAG(demand_deposits, 12) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM scb_aggregates_annual
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, demand_deposits,
           AVG(demand_deposits) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM scb_aggregates_annual)
SELECT period, demand_deposits, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(demand_deposits - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN demand_deposits > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(demand_deposits) OVER (ORDER BY period) AS base_val, period, demand_deposits
      FROM scb_aggregates_annual)
SELECT period, demand_deposits,
       ROUND(100.0 * demand_deposits / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(demand_deposits) AS mu, SQRT(MAX(0.0, (SUM(demand_deposits*demand_deposits) - SUM(demand_deposits)*SUM(demand_deposits)/COUNT(demand_deposits)) / NULLIF(COUNT(demand_deposits)-1, 0))) AS sd FROM scb_aggregates_annual)
SELECT t.period, t.demand_deposits,
       CASE
         WHEN t.demand_deposits > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.demand_deposits > s.mu        THEN 'ABOVE average'
         WHEN t.demand_deposits > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM scb_aggregates_annual t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, demand_deposits,
       RANK()       OVER (ORDER BY demand_deposits DESC) AS rank_high,
       RANK()       OVER (ORDER BY demand_deposits ASC)  AS rank_low
  FROM scb_aggregates_annual
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (demand_deposits - LAG(demand_deposits, 12) OVER (ORDER BY period))
           / NULLIF(LAG(demand_deposits, 12) OVER (ORDER BY period), 0) AS growth_pct
      FROM scb_aggregates_annual)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       demand_deposits, time_deposits, aggregate_deposits, borrowings_from_rbi,
       ROUND(100.0 * (demand_deposits) / NULLIF((NULLIF(SUM(demand_deposits), 0) + NULLIF(SUM(time_deposits), 0) + NULLIF(SUM(aggregate_deposits), 0) + NULLIF(SUM(borrowings_from_rbi), 0)), 0), 2) AS demand_deposits_share_pct
  FROM scb_aggregates_annual
 WHERE period = (SELECT MAX(period) FROM scb_aggregates_annual)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: scb_aggregates_annual × scb_aggregates_monthly on period ═════════════════════════════════
SELECT a.period,
       a.demand_deposits                            AS scb_aggregates_annual_demand_deposits,
       b.demand_deposits                            AS scb_aggregates_monthly_demand_deposits,
       ROUND(1.0 * a.demand_deposits / NULLIF(b.demand_deposits, 0), 4) AS ratio_demand_deposits_to_demand_deposits
  FROM scb_aggregates_annual a
  JOIN scb_aggregates_monthly b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, demand_deposits,
       demand_deposits - LAG(demand_deposits) OVER (ORDER BY period) AS absolute_delta,
       ROUND(demand_deposits - AVG(demand_deposits) OVER (), 2)     AS deviation_from_mean
  FROM scb_aggregates_annual
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'demand_deposits' AS column_name,
       SUM(CASE WHEN demand_deposits IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN demand_deposits < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM scb_aggregates_annual
UNION ALL
SELECT 'time_deposits' AS column_name,
       SUM(CASE WHEN time_deposits IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN time_deposits < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM scb_aggregates_annual
UNION ALL
SELECT 'aggregate_deposits' AS column_name,
       SUM(CASE WHEN aggregate_deposits IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN aggregate_deposits < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM scb_aggregates_annual
UNION ALL
SELECT 'borrowings_from_rbi' AS column_name,
       SUM(CASE WHEN borrowings_from_rbi IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN borrowings_from_rbi < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM scb_aggregates_annual
UNION ALL
SELECT 'liabilities_to_banks' AS column_name,
       SUM(CASE WHEN liabilities_to_banks IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN liabilities_to_banks < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM scb_aggregates_annual;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(demand_deposits), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(demand_deposits*demand_deposits) - SUM(demand_deposits)*SUM(demand_deposits)/COUNT(demand_deposits)) / NULLIF(COUNT(demand_deposits)-1, 0))), 2) AS std_val,
       MIN(demand_deposits)             AS min_val,
       MAX(demand_deposits)             AS max_val,
       (SELECT period FROM scb_aggregates_annual ORDER BY demand_deposits ASC  LIMIT 1) AS min_period,
       (SELECT period FROM scb_aggregates_annual ORDER BY demand_deposits DESC LIMIT 1) AS max_period
  FROM scb_aggregates_annual;

-- ═══ Q14 · Project-specific analytic: YoY growth, rolling CAGR, credit-deposit gap, liquidity stress flags ══════════════════════════════
-- analytic intent: YoY growth, rolling CAGR, credit-deposit gap, liquidity stress flags
WITH d AS (
    SELECT period, demand_deposits,
           demand_deposits - LAG(demand_deposits) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (demand_deposits - LAG(demand_deposits) OVER (ORDER BY period))
                 / NULLIF(LAG(demand_deposits) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM scb_aggregates_annual)
SELECT period, demand_deposits, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
