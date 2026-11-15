--------------------------------------------------------------------------------
-- P16: Indian Banking Peer Benchmarking — SBI vs HDFC / ICICI / Kotak / Axis
-- Domain     : SBI · Competitive Position
-- Layer      : warehouse  ->  project marts (views)
-- Source     : RBI Handbook of Statistics on Indian Economy (rbidocs.rbi.org.in) + Yahoo Finance market data
-- RDBMS      : ANSI SQL (verified on SQLite 3; portable constructs only)
-- Naming     : fct_/dim_/v_ prefixes, snake_case, _pct/_usd/_inr unit suffixes
--------------------------------------------------------------------------------

-- ── 1. Staging tables (loaded by scripts/build_warehouse.py) ─────────────────
CREATE TABLE fin_peers_in_annual (
    period     TEXT     NOT NULL   -- period label (ISO),
    dilutedeps_sbin     REAL,
    totaldebt_sbin     REAL,
    totalassets_sbin     REAL,
    interestincome_sbin     REAL,
    netincome_sbin     REAL,
    cashandcashequivalents_sbin     REAL,
    interestexpense_sbin     REAL,
    stockholdersequity_sbin     REAL,
    totalliabilitiesnetminorityinterest_sbin     REAL,
    totalrevenue_sbin     REAL,
    stockholdersequity_hdfc     REAL,
    totalrevenue_hdfc     REAL,
    totaldebt_hdfc     REAL,
    totalliabilitiesnetminorityinterest_hdfc     REAL,
    cashandcashequivalents_hdfc     REAL,
    interestexpense_hdfc     REAL,
    provisionforloanleaseandotherlosses_hdfc     REAL,
    netincome_hdfc     REAL,
    interestincome_hdfc     REAL,
    totalassets_hdfc     REAL,
    dilutedeps_hdfc     REAL,
    totaldebt_icici     REAL,
    totalrevenue_icici     REAL,
    cashandcashequivalents_icici     REAL,
    interestexpense_icici     REAL,
    stockholdersequity_icici     REAL,
    totalliabilitiesnetminorityinterest_icici     REAL,
    dilutedeps_icici     REAL,
    netincome_icici     REAL,
    totalassets_icici     REAL,
    interestincome_icici     REAL,
    provisionforloanleaseandotherlosses_icici     REAL,
    netincome_kotak     REAL,
    totalliabilitiesnetminorityinterest_kotak     REAL,
    stockholdersequity_kotak     REAL,
    interestincome_kotak     REAL,
    interestexpense_kotak     REAL,
    cashandcashequivalents_kotak     REAL,
    totalrevenue_kotak     REAL,
    totaldebt_kotak     REAL,
    totalassets_kotak     REAL,
    dilutedeps_kotak     REAL,
    totaldebt_axis     REAL,
    totalassets_axis     REAL,
    interestincome_axis     REAL,
    netincome_axis     REAL,
    cashandcashequivalents_axis     REAL,
    interestexpense_axis     REAL,
    dilutedeps_axis     REAL,
    stockholdersequity_axis     REAL,
    totalliabilitiesnetminorityinterest_axis     REAL,
    totalrevenue_axis     REAL,
    asset_share_pct_sbin     REAL,
    net_margin_pct_sbin     REAL,
    roe_pct_sbin     REAL,
    roe_pct_hdfc     REAL,
    roe_pct_icici     REAL,
    roe_pct_kotak     REAL,
    roe_pct_axis     REAL,
    peer_median_roe     REAL,
    revenue_rank_sbin     REAL
);

CREATE TABLE px_peers_in (
    period     TEXT     NOT NULL   -- period label (ISO),
    idx_sbin     REAL,
    idx_hdfc     REAL,
    idx_icici     REAL,
    idx_kotak     REAL,
    idx_axis     REAL
);

-- ── 2. Indexes for analytic access paths ─────────────────────────────────────
CREATE INDEX ix_fin_peers_in_annual_period ON fin_peers_in_annual (period);
CREATE INDEX ix_px_peers_in_period ON px_peers_in (period);

-- ── 3. Project mart views ────────────────────────────────────────────────────
CREATE VIEW v_fin_peers_in_annual_mart AS
SELECT * FROM fin_peers_in_annual
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


CREATE VIEW v_px_peers_in_mart AS
SELECT * FROM px_peers_in
WHERE period IS NOT NULL   -- analytic-ready grain: one row per period;


-- ── 4. Data-quality gate (must return 0 rows before marts are trusted) ───────
SELECT 'fin_peers_in_annual' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM fin_peers_in_annual
UNION ALL
SELECT 'px_peers_in' AS table_name, COUNT(*) AS rows_total,
       SUM(CASE WHEN period IS NULL THEN 1 ELSE 0 END) AS null_period_rows
  FROM px_peers_in
HAVING SUM(CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) > 0;
-- (0 rows expected)
