# Data Dictionary — RBI–SBI Financial Analytics Portfolio

**Conventions**
- `period` — time key: fiscal year `YYYY-YY`, month `YYYY-MM`, or ISO date `YYYY-MM-DD`
- Unit suffixes: `_pct` per cent · `_pp` percentage points · `_inr_crore` ₹ crore ·
  `_usd_mn` US$ million · `_usd_bn` US$ billion · `_volume_mn` million transactions ·
  `_value_crore` ₹ crore · `_index` index points
- RBI "not available" markers (`-`, `..`) are loaded as NULL

## 1. Monetary & Macro (RBI Handbook of Statistics on Indian Economy)

| Dataset | RBI HBS Table | Columns (units) |
|---|---|---|
| `policy_rates` | **40** | `period`, `bank_rate`, `repo_rate`, `reverse_repo_rate`, `sdf_rate`, `msf_rate`, `crr`, `slr` (%) — rates carried forward from effective dates |
| `money_stock_annual` | **36** | `currency_in_circulation`, `cash_with_banks`, `currency_with_public`, `others_deposits_with_rbi`, `bankers_deposits_with_rbi`, `demand_deposits`, `time_deposits`, `reserve_money`, `m1`, `m3` (₹ cr) |
| `money_stock_monthly` | **165** | same columns as annual (monthly grain) |
| `money_sources` | **37** | `net_rbi_credit_to_government`, `net_rbi_credit_to_banks`, `other_banks_investment_in_govt`, `net_bank_credit_to_government`, `rbi_credit_to_commercial_sector`, `other_banks_credit_to_commercial_sector`, `bank_credit_to_commercial_sector` (₹ cr) |
| `cpi_annual` | **34** | `cpi_iw`, `cpi_iw_food`, `cpi_al`, `cpi_rural`, `cpi_urban`, `cpi_combined` (index) |
| `cpi_monthly` | **163** | `cpi_index` (combined), `cpi_rural`, `cpi_urban` (index, first base block) |
| `wpi_annual` | **33** | `wpi_all_commodities`, `wpi_primary_articles`, `wpi_food_articles`, `wpi_non_food_articles`, `wpi_fuel_power`, `wpi_manufactured_products` (index) |
| `wpi_monthly` | **162** | `wpi_index` (all commodities) |
| `inflation_variations` | **235 + 236** | `wpi_variation_pct`, `cpi_variation_pct`, `cpi_wpi_gap` (pp) |

## 2. Banking Sector

| Dataset | RBI HBS Table | Columns (units) |
|---|---|---|
| `scb_aggregates_annual` | **41 + 167 (Mar)** | `demand_deposits`, `time_deposits`, `aggregate_deposits`, `borrowings_from_rbi`, `liabilities_to_banks`, `other_liabilities`, `bank_credit`, `non_food_credit`, `food_credit` (₹ cr), `credit_deposit_ratio` (%) |
| `scb_aggregates_monthly` | **167** | + `investments_govt_securities`, `investments_other_approved`, `investments_total`, `cash_in_hand`, `balances_with_rbi`, `assets_with_banks` (₹ cr) |
| `scb_growth` | **232** | `*_growth_pct` for demand/time/aggregate deposits, investments, food & non-food credit, bank credit |
| `credit_sectoral_annual` | **42** | `total_non_food_credit`, `agriculture`, `industry`, `services`, `retail` (₹ cr) + `*_share_pct` |
| `credit_sectoral_monthly` | **168** | same (fortnightly/monthly snapshots, ISO dates) |
| `credit_industry_annual` | **43** | `mining`, `food_processing`, `textiles`, `chemicals`, `infrastructure`, `basic_metal`, `total_industry` (₹ cr) |
| `credit_industry_monthly` | **169** | same (dated snapshots) |
| `scb_balance_sheet` | **49** | `capital`, `reserves_surplus`, `deposits`, `borrowings`, `other_liabilities`, `other_items`, `total_liabilities` (₹ cr), `total_liabilities_check` (QA) |
| `scb_ratios` | **233** | `credit_to_deposit_pct`, `investments_to_deposit_pct`, `govt_sec_to_deposit_pct`, `credit_to_workfund_pct`, `investments_to_workfund_pct`, `govt_sec_to_workfund_pct`, `aggregate_deposit_share_pct` |
| `npa_bank_group` | **50** | pivoted by bank group `all / sbi_group / nationalised / private / foreign`: `advances_gross`, `advances_net`, `gross_npa_amount`, `gross_npa_to_advances_pct`, `net_npa_amount`, `net_npa_to_advances_pct` (₹ cr / %) |
| `crar_distribution` | **51** | `banks_below_9pct`, `banks_9_to_10pct`, `banks_10_to_12pct`, `banks_above_10pct`, `banks_above_12pct` (count), `weighted_avg_crar` (%) |
| `payment_systems` | **58** | per channel (`rtgs/aeps/imps/neft/upi/cards/paper/total/digital_total`): `*_volume_mn`, `*_value_crore`; `digital_share_pct`, `paper_share_pct` |
| `interest_structure` | **59** | `call_money_rate`, `savings_rate`, `term_deposit_1_3y`, `term_deposit_3_5y`, `term_deposit_above_5y`, `lending_rate`, `mclr_1y`, `walr_outstanding_pct`, `walr_fresh_pct`, `mclr_1y_wtd_pct`, `wadtdr_outstanding_pct` (%) |

## 3. External Sector

| Dataset | RBI HBS Table | Columns (units) |
|---|---|---|
| `forex_annual` | **144** | `sdr_*`, `gold_*`, `fca_*`, `reserve_tranche_*`, `total_reserves_*` in `_inr_crore` and `_usd_mn` |
| `forex_monthly` | **210** | same (monthly, year-block months) |
| `forex_weekly` | **215** | same (weekly dates) |
| `fx_rates_annual` | **132** | `usd_inr`, `sdr_inr`, `gbp_inr`, `jpy_inr`, `eur_inr` (₹ per unit) |
| `fx_rates_daily` | **223** | `usd_inr`, `gbp_inr`, `eur_inr`, `jpy_inr` (daily reference rates) |
| `neer_reer` | **207** | `neer_index`, `reer_index`, `neer_export_index`, `reer_export_index` (monthly) |

## 4. Capital Markets

| Dataset | RBI HBS Table | Columns (units) |
|---|---|---|
| `market_indices_annual` | **85** | `sensex_avg`, `bse100_avg`, `rbi_index_avg`, `market_cap_bse_crore`, `market_cap_allindia_crore` |
| `nifty_monthly` | **182** | `nifty_avg` (monthly average) |
| `sensex_monthly` | **183** | `sensex_avg` (monthly average) |

## 5. SBI & Market Lake (Yahoo Finance)

| Dataset | Columns |
|---|---|
| `px_sbin` | daily OHLCV + `dividend`, `ma_50`, `ma_200`, `volatility_60d`, `annual_volatility_pct`, `drawdown_pct`, `max_drawdown_pct`, `var_95_pct`, `cum_sbin`, `cum_nifty`, `beta_nifty`, `monthly_return_pct` |
| `px_nifty` / `px_sensex` / `px_sp500` / `px_usdinr` | daily OHLCV (benchmark series) |
| `px_peers_in` | `idx_sbin`, `idx_hdfc`, `idx_icici`, `idx_kotak`, `idx_axis` (base 100) |
| `px_peers_gl` | `idx_sbin`, `idx_jpm`, `idx_hsbc`, `idx_c`, `idx_mufg`, `idx_bcs`, `idx_bac` |
| `fin_sbin_annual` | reported annuals + `net_margin_pct`, `roe_pct`, `roa_pct` |
| `fin_sbin_quarterly` | reported quarterlies + `net_margin_pct` |
| `fin_peers_in_annual` | wide per-bank (`totalassets_*`, `netincome_*`, `roe_pct_*`, …) + `asset_share_pct_sbin`, `peer_median_roe`, `revenue_rank_sbin` |
| `fin_peers_gl_annual` | `total_assets_usd_bn_*`, `net_income_usd_bn_*`, `roe_pct_*` (USD-converted) + `global_median_roe`, `asset_rank_sbin` |

## 6. Derived-metric definitions
| Metric | Definition |
|---|---|
| `volatility_60d` | 60-day rolling std of daily returns × √252 × 100 |
| `var_95_pct` | trailing 252-day historical 5th percentile of daily returns × 100 |
| `beta_nifty` | 252-day rolling covariance(SBIN, NIFTY) / variance(NIFTY) |
| `drawdown_pct` | close ÷ running peak − 1 (×100) |
| `cum_*` | indexed performance, first observation = 100 |
| `credit_deposit_ratio` | bank credit ÷ aggregate deposits × 100 |
| `total_liabilities_check` | sum of reported components (QA vs reported total) |
