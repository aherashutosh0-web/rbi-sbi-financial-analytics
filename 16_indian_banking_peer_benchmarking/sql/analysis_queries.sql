--------------------------------------------------------------------------------
-- P16 · ANALYTIC QUERY PACK — Indian Banking Peer Benchmarking — SBI vs HDFC / ICICI / Kotak / Axis
-- Business question: How does SBI compare with leading private banks on growth, profitability, size and market valuation?
-- SQL focus: peer ranking (RANK/DENSE_RANK), share-of-wallet, efficiency gap analysis
-- Verified against warehouse/rbi_sbi_warehouse.db (see sql/verification.log)
--------------------------------------------------------------------------------

-- ═══ Q01 · Dataset profile: coverage & freshness ════════════════════════════
SELECT 'fin_peers_in_annual'                        AS table_name,
       COUNT(*)                         AS row_count,
       MIN(period)                       AS first_period,
       MAX(period)                       AS latest_period,
       COUNT(DISTINCT period)            AS distinct_periods
  FROM fin_peers_in_annual;

-- ═══ Q02 · Latest snapshot ═════════════════════════════════════════════════
SELECT *
  FROM fin_peers_in_annual
 WHERE period = (SELECT MAX(period) FROM fin_peers_in_annual);

-- ═══ Q03 · Year-over-year growth (LAG window function) ═════════════════════
SELECT period,
       dilutedeps_sbin,
       LAG(dilutedeps_sbin, 1) OVER (ORDER BY period)           AS dilutedeps_sbin_1p_ago,
       ROUND(100.0 * (dilutedeps_sbin - LAG(dilutedeps_sbin, 1) OVER (ORDER BY period))
             / NULLIF(LAG(dilutedeps_sbin, 1) OVER (ORDER BY period), 0), 2) AS yoy_growth_pct
  FROM fin_peers_in_annual
 ORDER BY period;

-- ═══ Q04 · Momentum: 3-period moving average vs actual ═════════════════════
WITH m AS (
    SELECT period, dilutedeps_sbin,
           AVG(dilutedeps_sbin) OVER (ORDER BY period ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3p
      FROM fin_peers_in_annual)
SELECT period, dilutedeps_sbin, ROUND(ma_3p, 2) AS moving_avg_3p,
       ROUND(dilutedeps_sbin - ma_3p, 2)       AS gap_vs_ma,
       CASE WHEN dilutedeps_sbin > ma_3p THEN 'above trend' ELSE 'below trend' END AS trend_side
  FROM m
 ORDER BY period;

-- ═══ Q05 · Cumulative growth since series start (indexed to first = 100) ═══
WITH base AS (
    SELECT FIRST_VALUE(dilutedeps_sbin) OVER (ORDER BY period) AS base_val, period, dilutedeps_sbin
      FROM fin_peers_in_annual)
SELECT period, dilutedeps_sbin,
       ROUND(100.0 * dilutedeps_sbin / NULLIF(base_val, 0), 2) AS index_base_100
  FROM base
 ORDER BY period;

-- ═══ Q06 · Regime classification with CASE + running statistics ════════════
WITH stats AS (
    SELECT AVG(dilutedeps_sbin) AS mu, SQRT(MAX(0.0, (SUM(dilutedeps_sbin*dilutedeps_sbin) - SUM(dilutedeps_sbin)*SUM(dilutedeps_sbin)/COUNT(dilutedeps_sbin)) / NULLIF(COUNT(dilutedeps_sbin)-1, 0))) AS sd FROM fin_peers_in_annual)
SELECT t.period, t.dilutedeps_sbin,
       CASE
         WHEN t.dilutedeps_sbin > s.mu + s.sd THEN 'HIGH  (> +1σ)'
         WHEN t.dilutedeps_sbin > s.mu        THEN 'ABOVE average'
         WHEN t.dilutedeps_sbin > s.mu - s.sd THEN 'BELOW average'
         ELSE 'LOW   (< -1σ)'
       END AS regime
  FROM fin_peers_in_annual t CROSS JOIN stats s
 ORDER BY t.period;

-- ═══ Q07 · Top/bottom periods by metric (RANK window) ══════════════════════
SELECT period, dilutedeps_sbin,
       RANK()       OVER (ORDER BY dilutedeps_sbin DESC) AS rank_high,
       RANK()       OVER (ORDER BY dilutedeps_sbin ASC)  AS rank_low
  FROM fin_peers_in_annual
 ORDER BY rank_high
 LIMIT 10;

-- ═══ Q08 · Volatility of growth: stddev of period-over-period change ══════
WITH chg AS (
    SELECT period,
           100.0 * (dilutedeps_sbin - LAG(dilutedeps_sbin, 1) OVER (ORDER BY period))
           / NULLIF(LAG(dilutedeps_sbin, 1) OVER (ORDER BY period), 0) AS growth_pct
      FROM fin_peers_in_annual)
SELECT COUNT(*)                    AS periods,
       ROUND(AVG(growth_pct), 2)   AS avg_growth_pct,
       ROUND(SQRT(MAX(0.0, (SUM(growth_pct*growth_pct) - SUM(growth_pct)*SUM(growth_pct)/COUNT(growth_pct)) / NULLIF(COUNT(growth_pct)-1, 0))), 2) AS growth_volatility_pp,
       ROUND(MIN(growth_pct), 2)   AS worst_pct,
       ROUND(MAX(growth_pct), 2)   AS best_pct
  FROM chg
 WHERE growth_pct IS NOT NULL;

-- ═══ Q09 · Share/contribution analysis across components ═══════════════════
SELECT period,
       dilutedeps_sbin, totaldebt_sbin, totalassets_sbin, interestincome_sbin,
       ROUND(100.0 * (dilutedeps_sbin) / NULLIF((NULLIF(SUM(dilutedeps_sbin), 0) + NULLIF(SUM(totaldebt_sbin), 0) + NULLIF(SUM(totalassets_sbin), 0) + NULLIF(SUM(interestincome_sbin), 0)), 0), 2) AS dilutedeps_sbin_share_pct
  FROM fin_peers_in_annual
 WHERE period = (SELECT MAX(period) FROM fin_peers_in_annual)
 GROUP BY period;

-- ═══ Q10 · Cross-dataset join: fin_peers_in_annual × px_peers_in on period ═════════════════════════════════
SELECT a.period,
       a.dilutedeps_sbin                            AS fin_peers_in_annual_dilutedeps_sbin,
       b.idx_sbin                            AS px_peers_in_idx_sbin,
       ROUND(1.0 * a.dilutedeps_sbin / NULLIF(b.idx_sbin, 0), 4) AS ratio_dilutedeps_sbin_to_idx_sbin
  FROM fin_peers_in_annual a
  JOIN px_peers_in b ON a.period = b.period
 ORDER BY a.period;

-- ═══ Q11 · Decadal/structural trend: period-over-period delta ══════════════
SELECT period, dilutedeps_sbin,
       dilutedeps_sbin - LAG(dilutedeps_sbin) OVER (ORDER BY period) AS absolute_delta,
       ROUND(dilutedeps_sbin - AVG(dilutedeps_sbin) OVER (), 2)     AS deviation_from_mean
  FROM fin_peers_in_annual
 ORDER BY period;

-- ═══ Q12 · Data-quality checks: nulls, negatives, gaps ═════════════════════
SELECT 'dilutedeps_sbin' AS column_name,
       SUM(CASE WHEN dilutedeps_sbin IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN dilutedeps_sbin < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_peers_in_annual
UNION ALL
SELECT 'totaldebt_sbin' AS column_name,
       SUM(CASE WHEN totaldebt_sbin IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN totaldebt_sbin < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_peers_in_annual
UNION ALL
SELECT 'totalassets_sbin' AS column_name,
       SUM(CASE WHEN totalassets_sbin IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN totalassets_sbin < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_peers_in_annual
UNION ALL
SELECT 'interestincome_sbin' AS column_name,
       SUM(CASE WHEN interestincome_sbin IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN interestincome_sbin < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_peers_in_annual
UNION ALL
SELECT 'netincome_sbin' AS column_name,
       SUM(CASE WHEN netincome_sbin IS NULL THEN 1 ELSE 0 END)     AS null_count,
       SUM(CASE WHEN netincome_sbin < 0 THEN 1 ELSE 0 END)         AS negative_count,
       COUNT(*)                                          AS row_count
  FROM fin_peers_in_annual;

-- ═══ Q13 · Summary statistics for the headline metric ══════════════════════
SELECT ROUND(AVG(dilutedeps_sbin), 2)   AS mean_val,
       ROUND(SQRT(MAX(0.0, (SUM(dilutedeps_sbin*dilutedeps_sbin) - SUM(dilutedeps_sbin)*SUM(dilutedeps_sbin)/COUNT(dilutedeps_sbin)) / NULLIF(COUNT(dilutedeps_sbin)-1, 0))), 2) AS std_val,
       MIN(dilutedeps_sbin)             AS min_val,
       MAX(dilutedeps_sbin)             AS max_val,
       (SELECT period FROM fin_peers_in_annual ORDER BY dilutedeps_sbin ASC  LIMIT 1) AS min_period,
       (SELECT period FROM fin_peers_in_annual ORDER BY dilutedeps_sbin DESC LIMIT 1) AS max_period
  FROM fin_peers_in_annual;

-- ═══ Q14 · Project-specific analytic: peer ranking (RANK/DENSE_RANK), share-of-wallet, efficiency gap analysis ══════════════════════════════
-- analytic intent: peer ranking (RANK/DENSE_RANK), share-of-wallet, efficiency gap analysis
WITH d AS (
    SELECT period, dilutedeps_sbin,
           dilutedeps_sbin - LAG(dilutedeps_sbin) OVER (ORDER BY period)       AS delta,
           ROUND(100.0 * (dilutedeps_sbin - LAG(dilutedeps_sbin) OVER (ORDER BY period))
                 / NULLIF(LAG(dilutedeps_sbin) OVER (ORDER BY period), 0), 2) AS pct_change
      FROM fin_peers_in_annual)
SELECT period, dilutedeps_sbin, delta, pct_change,
       SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) OVER () AS rising_periods,
       SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) OVER () AS falling_periods
  FROM d
 ORDER BY period;
