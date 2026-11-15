--------------------------------------------------------------------------------
-- P11 · ANALYTIC QUERY PACK — Interest Rate Structure & Transmission Analysis
-- Business question: How are deposit and lending rates distributed across maturities and borrower classes, and how complete is policy transmission?
-- SQL focus: term structure spreads, transmission lag correlation with policy_rates, pricing pressure index
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'interest_structure'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM interest_structure;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM interest_structure
 WHERE period = (SELECT MAX(period) FROM interest_structure);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       call_money_rate,
       LAG(call_money_rate, 1) OVER (ORDER BY period)           AS call_money_rate_1p_ago,
       ROUND(100.0 * (call_money_rate - LAG(call_money_rate, 1) OVER (ORDER BY period))
             / NULLIF(LAG(call_money_rate, 1) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM interest_structure
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, call_money_rate,
           AVG(call_money_rate) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM interest_structure)
SELECT period, call_money_rate, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(call_money_rate - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN call_money_rate > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(call_money_rate) OVER (ORDER BY period) AS base_val, period, call_money_rate
      FROM interest_structure)
SELECT period, call_money_rate,
       ROUND(100.0 * call_money_rate / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(call_money_rate) AS mu, SQRT(MAX(0.0, (SUM(call_money_rate*call_money_rate) - SUM(call_money_rate)*SUM(call_money_rate)/COUNT(call_money_rate)) / NULLIF(COUNT(call_money_rate)-1, 0))) AS sd FROM interest_structure)
SELECT t.period, t.call_money_rate,
       CASE
         WHEN t.call_money_rate > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.call_money_rate > s.mu        THEN 'ABOVE average'
         WHEN t.call_money_rate > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM interest_structure t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, call_money_rate,
       RANK()       OVER (ORDER BY call_money_rate DESC) AS rank_high,
       RANK()       OVER (ORDER BY call_money_rate ASC)  AS rank_low
  FROM interest_structure
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (call_money_rate - LAG(call_money_rate, 1) OVER (ORDER BY period))
           / NULLIF(LAG(call_money_rate, 1) OVER (ORDER BY period), 0) AS growth_pct
      FROM interest_structure)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       call_money_rate, savings_rate, term_deposit_1_3y, term_deposit_3_5y,
       ROUND(100.0 * (call_money_rate) / NULLIF((NULLIF(SUM(call_money_rate), 0) + NULLIF(SUM(savings_rate), 0) + NULLIF(SUM(term_deposit_1_3y), 0) + NULLIF(SUM(term_deposit_3_5y), 0)), 0), 2) AS call_money_rate_share_pct
  FROM interest_structure
 WHERE period = (SELECT MAX(period) FROM interest_structure)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: interest_structure × policy_rates on period ═════════════════════════════════
SELECT a.period,
       a.call_money_rate                            AS interest_structure_call_money_rate,
       b.bank_rate                            AS policy_rates_bank_rate,
       ROUND(1.0 * a.call_money_rate / NULLIF(b.bank_rate, 0), 4) AS ratio_call_money_rate_to_bank_rate
  FROM interest_structure a
  JOIN policy_rates b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, call_money_rate,
       call_money_rate - LAG(call_money_rate) OVER (ORDER BY period) AS absolute_delta,
       ROUND(call_money_rate - AVG(call_money_rate) OVER (), 2)     AS deviation_from_mean
  FROM interest_structure
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'call_money_rate' AS column_name,
       SUM(CASE WHEN call_money_rate IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN call_money_rate < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM interest_structure
UNION ALL
SELECT 'savings_rate' AS column_name,
       SUM(CASE WHEN savings_rate IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN savings_rate < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM interest_structure
UNION ALL
SELECT 'term_deposit_1_3y' AS column_name,
       SUM(CASE WHEN term_deposit_1_3y IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN term_deposit_1_3y < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM interest_structure
UNION ALL
SELECT 'term_deposit_3_5y' AS column_name,
       SUM(CASE WHEN term_deposit_3_5y IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN term_deposit_3_5y < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM interest_structure
UNION ALL
SELECT 'term_deposit_above_5y' AS column_name,
       SUM(CASE WHEN term_deposit_above_5y IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN term_deposit_above_5y < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM interest_structure;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(call_money_rate), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(call_money_rate*call_money_rate) - SUM(call_money_rate)*SUM(call_money_rate)/COUNT(call_money_rate)) / NULLIF(COUNT(call_money_rate)-1, 0))), 2) AS std_val,
       MIN(call_money_rate)             AS min_val,
       MAX(call_money_rate)             AS max_val,
       (SELECT period FROM interest_structure ORDER BY call_money_rate ASC  LIMIT 1) AS min_period,
       (SELECT period FROM interest_structure ORDER BY call_money_rate DESC LIMIT 1) AS max_period
  FROM interest_structure;

-- ═══ Q14 · Project-specific analytic: term structure spreads, transmission lag correlation with policy_rates, pricing pressure index ══════════════════════════════
-- analytic intent: term structure spreads, transmission lag correlation with policy_rates, pricing pressure index
WITH d AS (
    SELECT period, call_money_rate,
           call_money_rate - LAG(call_money_rate) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (call_money_rate - LAG(call_money_rate) OVER (ORDER BY period))
                 / NULLIF(LAG(call_money_rate) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM interest_structure)
SELECT period, call_money_rate, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
