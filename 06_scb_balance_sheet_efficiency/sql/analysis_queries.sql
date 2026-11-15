--------------------------------------------------------------------------------
-- P06 · ANALYTIC QUERY PACK — SCB Consolidated Balance Sheet & Efficiency Ratios
-- Business question: How efficient is the banking system — balance-sheet structure, intermediation ratios and investment mix — and where is it trending?
-- SQL focus: ratio trends, structural balance-sheet change, efficiency benchmarking
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'scb_balance_sheet'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM scb_balance_sheet;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM scb_balance_sheet
 WHERE period = (SELECT MAX(period) FROM scb_balance_sheet);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       capital,
       LAG(capital, 12) OVER (ORDER BY period)           AS capital_12p_ago,
       ROUND(100.0 * (capital - LAG(capital, 12) OVER (ORDER BY period))
             / NULLIF(LAG(capital, 12) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM scb_balance_sheet
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, capital,
           AVG(capital) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM scb_balance_sheet)
SELECT period, capital, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(capital - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN capital > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(capital) OVER (ORDER BY period) AS base_val, period, capital
      FROM scb_balance_sheet)
SELECT period, capital,
       ROUND(100.0 * capital / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(capital) AS mu, SQRT(MAX(0.0, (SUM(capital*capital) - SUM(capital)*SUM(capital)/COUNT(capital)) / NULLIF(COUNT(capital)-1, 0))) AS sd FROM scb_balance_sheet)
SELECT t.period, t.capital,
       CASE
         WHEN t.capital > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.capital > s.mu        THEN 'ABOVE average'
         WHEN t.capital > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM scb_balance_sheet t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, capital,
       RANK()       OVER (ORDER BY capital DESC) AS rank_high,
       RANK()       OVER (ORDER BY capital ASC)  AS rank_low
  FROM scb_balance_sheet
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (capital - LAG(capital, 12) OVER (ORDER BY period))
           / NULLIF(LAG(capital, 12) OVER (ORDER BY period), 0) AS growth_pct
      FROM scb_balance_sheet)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       capital, reserves_surplus, deposits, borrowings,
       ROUND(100.0 * (capital) / NULLIF((NULLIF(SUM(capital), 0) + NULLIF(SUM(reserves_surplus), 0) + NULLIF(SUM(deposits), 0) + NULLIF(SUM(borrowings), 0)), 0), 2) AS capital_share_pct
  FROM scb_balance_sheet
 WHERE period = (SELECT MAX(period) FROM scb_balance_sheet)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: scb_balance_sheet × scb_ratios on period ═════════════════════════════════
SELECT a.period,
       a.capital                            AS scb_balance_sheet_capital,
       b.credit_to_deposit_pct                            AS scb_ratios_credit_to_deposit_pct,
       ROUND(1.0 * a.capital / NULLIF(b.credit_to_deposit_pct, 0), 4) AS ratio_capital_to_credit_to_deposit_pct
  FROM scb_balance_sheet a
  JOIN scb_ratios b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, capital,
       capital - LAG(capital) OVER (ORDER BY period) AS absolute_delta,
       ROUND(capital - AVG(capital) OVER (), 2)     AS deviation_from_mean
  FROM scb_balance_sheet
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'capital' AS column_name,
       SUM(CASE WHEN capital IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN capital < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM scb_balance_sheet
UNION ALL
SELECT 'reserves_surplus' AS column_name,
       SUM(CASE WHEN reserves_surplus IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN reserves_surplus < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM scb_balance_sheet
UNION ALL
SELECT 'deposits' AS column_name,
       SUM(CASE WHEN deposits IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN deposits < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM scb_balance_sheet
UNION ALL
SELECT 'borrowings' AS column_name,
       SUM(CASE WHEN borrowings IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN borrowings < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM scb_balance_sheet
UNION ALL
SELECT 'other_liabilities' AS column_name,
       SUM(CASE WHEN other_liabilities IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN other_liabilities < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM scb_balance_sheet;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(capital), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(capital*capital) - SUM(capital)*SUM(capital)/COUNT(capital)) / NULLIF(COUNT(capital)-1, 0))), 2) AS std_val,
       MIN(capital)             AS min_val,
       MAX(capital)             AS max_val,
       (SELECT period FROM scb_balance_sheet ORDER BY capital ASC  LIMIT 1) AS min_period,
       (SELECT period FROM scb_balance_sheet ORDER BY capital DESC LIMIT 1) AS max_period
  FROM scb_balance_sheet;

-- ═══ Q14 · Project-specific analytic: ratio trends, structural balance-sheet change, efficiency benchmarking ══════════════════════════════
-- analytic intent: ratio trends, structural balance-sheet change, efficiency benchmarking
WITH d AS (
    SELECT period, capital,
           capital - LAG(capital) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (capital - LAG(capital) OVER (ORDER BY period))
                 / NULLIF(LAG(capital) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM scb_balance_sheet)
SELECT period, capital, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
