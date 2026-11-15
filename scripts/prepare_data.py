#!/usr/bin/env python3
"""
prepare_data.py — RBI HBS XLSX -> tidy analytical datasets + market derivatives.

Every dataset below is written to data_lake/prepared/<name>.csv with canonical
column names consumed by the SQL warehouse, Excel workbooks, HTML dashboards
and Python analyses (see common/registry.py).

Conventions
  period      : 'YYYY-YY' (fiscal year), 'YYYY-MM', or ISO date
  *_pct       : per cent        *_inr_crore : ₹ crore      *_usd_mn : US$ million
  '-' / '..'  : RBI's not-available markers -> NULL

Run:  python3 scripts/prepare_data.py
"""
import glob
import pathlib
import re
import sys
import warnings

import numpy as np
import pandas as pd

warnings.filterwarnings("ignore")
BASE = pathlib.Path(__file__).resolve().parent.parent
RBI = BASE / "data_lake" / "rbi"
MKT = BASE / "data_lake" / "market"
OUT = BASE / "data_lake" / "prepared"

MONTHS = {"jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
          "june": 6, "jul": 7, "july": 7, "aug": 8, "august": 8, "sep": 9,
          "sept": 9, "september": 9, "oct": 10, "october": 10, "nov": 11,
          "november": 11, "dec": 12, "december": 12}


# ────────────────────────── low-level helpers ──────────────────────────────
def table(no: int) -> pd.DataFrame:
    """Load a table across ALL sheets (RBI puts '(Continued)' pages in extra
    sheets); parser row-filters tolerate the repeated title/header blocks."""
    f = glob.glob(str(RBI / f"table_{no:03d}_*.xlsx"))[0]
    xl = pd.ExcelFile(f)
    frames = [pd.read_excel(xl, sheet_name=s, header=None) for s in xl.sheet_names]
    if len(frames) == 1:
        return frames[0]
    return pd.concat(frames, ignore_index=True)


def num(v):
    if isinstance(v, str):
        v = v.strip().replace(",", "")
        if v in ("-", "..", "", "NA", "n.a."):
            return np.nan
        try:
            return float(v)
        except ValueError:
            return np.nan
    return v if isinstance(v, (int, float, np.number)) else np.nan


def nums(df: pd.DataFrame) -> pd.DataFrame:
    return df.applymap(num) if hasattr(df, "applymap") else df.map(num)


def is_period_label(v) -> bool:
    """True for '2013-14', '2023', '2026-01-01 00:00:00', datetime, '2023-24*'."""
    if isinstance(v, (pd.Timestamp, np.datetime64)):
        return True
    s = str(v).strip()
    return bool(re.fullmatch(r"\d{4}(-\d{2}(-\d{2})?)?(\s00:00:00)?\*?", s))


def per_label(v) -> str:
    if isinstance(v, (pd.Timestamp, np.datetime64)):
        return pd.Timestamp(v).strftime("%Y-%m-%d")
    s = str(v).strip().rstrip("*")
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}\s00:00:00", s):
        return s[:10]
    return s


def month_label(year: str, mon: str) -> str | None:
    m = MONTHS.get(str(mon).strip().rstrip(".").lower())
    if not m:
        return None
    y = str(year).strip()
    if re.fullmatch(r"\d{4}-\d{2}", y):           # fiscal year block 2022-23
        y0 = int(y[:4])
        # fiscal year Apr(y0)..Mar(y0+1): Apr-Dec belong to y0, Jan-Mar to y0+1
        y = str(y0 if m >= 4 else y0 + 1)
    return f"{y}-{m:02d}"


def write(name: str, df: pd.DataFrame):
    df = df.dropna(how="all").reset_index(drop=True)
    OUT.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUT / f"{name}.csv", index=False)
    print(f"  {name:32s} {len(df):5d} rows × {len(df.columns):2d} cols")


# ────────────────────────── RBI table parsers ──────────────────────────────
def p_policy_rates():
    """T40 — policy rates; rates carry forward from their effective date."""
    raw = table(40)
    rows = []
    for _, r in raw.iterrows():
        if not is_period_label(r[1]):
            continue
        rows.append([per_label(r[1])] + [num(r[c]) for c in range(2, 9)])
    df = pd.DataFrame(rows, columns=[
        "period", "bank_rate", "repo_rate", "reverse_repo_rate",
        "sdf_rate", "msf_rate", "crr", "slr"])
    df = df.sort_values("period").ffill()      # rates are step functions
    write("policy_rates", df)


def p_money_stock():
    """T36 / T165 — components of money stock (annual + monthly)."""
    cols = ["period", "currency_in_circulation", "cash_with_banks",
            "currency_with_public", "others_deposits_with_rbi",
            "bankers_deposits_with_rbi", "demand_deposits", "time_deposits",
            "reserve_money", "m1", "m3"]
    raw = table(36)
    rows = [[per_label(r[1])] + [num(r[c]) for c in range(2, 12)]
            for _, r in raw.iterrows() if is_period_label(r[1])]
    write("money_stock_annual", pd.DataFrame(rows, columns=cols))

    raw = table(165)
    rows, fy = [], None
    for _, r in raw.iterrows():
        if is_period_label(r[1]):
            fy = per_label(r[1])                       # year block header
        elif fy and isinstance(r[1], str) and r[1].strip().lower().rstrip(".") in MONTHS:
            lab = month_label(fy, r[1])
            if lab:
                rows.append([lab] + [num(r[c]) for c in range(2, 12)])
    write("money_stock_monthly", pd.DataFrame(rows, columns=cols))


def p_money_sources():
    """T37 — sources of money stock."""
    cols = ["period", "net_rbi_credit_to_government", "net_rbi_credit_to_banks",
            "other_banks_investment_in_govt", "net_bank_credit_to_government",
            "rbi_credit_to_commercial_sector",
            "other_banks_credit_to_commercial_sector",
            "bank_credit_to_commercial_sector"]
    raw = table(37)
    rows = [[per_label(r[1])] + [num(r[c]) for c in range(2, 9)]
            for _, r in raw.iterrows() if is_period_label(r[1])]
    write("money_sources", pd.DataFrame(rows, columns=cols))


def p_inflation():
    """T34/T33 annual indices, T163/T162 monthly, T235/T236 variations."""
    # T34 CPI annual — keep only the newest base block (rows after last '(Base')
    raw = table(34)
    rows = []
    for _, r in raw.iterrows():
        if is_period_label(r[1]):
            rows.append([per_label(r[1])] + [num(r[c]) for c in range(2, 8)])
    df = pd.DataFrame(rows, columns=[
        "period", "cpi_iw", "cpi_iw_food", "cpi_al",
        "cpi_rural", "cpi_urban", "cpi_combined"])
    df["period"] = df["period"].str[:7]
    write("cpi_annual", df.drop_duplicates("period", keep="last"))

    # T33 WPI annual
    raw = table(33)
    rows = []
    for _, r in raw.iterrows():
        if is_period_label(r[1]):
            rows.append([per_label(r[1])] + [num(r[c]) for c in range(2, 8)])
    df = pd.DataFrame(rows, columns=[
        "period", "wpi_all_commodities", "wpi_primary_articles",
        "wpi_food_articles", "wpi_non_food_articles", "wpi_fuel_power",
        "wpi_manufactured_products"])
    write("wpi_annual", df.drop_duplicates("period", keep="last"))

    # T163 CPI monthly — sections in col1 (Rural/Urban/Combined); months in
    # columns Apr..Mar; year rows; multiple base blocks (keep the FIRST base
    # block per section to avoid chain breaks in the index).
    raw = table(163)
    month_cols = ["Apr", "May", "Jun", "Jul", "Aug", "Sep",
                  "Oct", "Nov", "Dec", "Jan", "Feb", "Mar"]
    section, base_seen, out = None, {}, {}
    for _, r in raw.iterrows():
        label = str(r[1]).strip() if pd.notna(r[1]) else ""
        new_sec = None
        if re.match(r"CPI\s*(Combined|Overall)", label, re.I) or \
                re.match(r"CPI\s*\(?Combined", label, re.I):
            new_sec = "cpi_index"
        elif re.match(r"CPI\s*Rural", label, re.I):
            new_sec = "cpi_rural"
        elif re.match(r"CPI\s*Urban", label, re.I):
            new_sec = "cpi_urban"
        if new_sec:
            section, base_seen[new_sec] = new_sec, 0
        if isinstance(r[2], str) and "base" in r[2].lower():      # base marker
            if section:
                base_seen[section] += 1
            continue
        if section and is_period_label(r[1]) and base_seen.get(section, 0) <= 1:
            fy = per_label(r[1])[:7]
            for i, mon in enumerate(month_cols):
                v = num(r[2 + i])
                lab = month_label(fy, mon)
                if lab and v == v:
                    out.setdefault(lab, {})[section] = v
    df = pd.DataFrame.from_dict(out, orient="index").reset_index()
    df.columns = ["period"] + list(df.columns[1:])
    if "cpi_index" not in df.columns and "cpi_combined" in df.columns:
        df["cpi_index"] = df["cpi_combined"]
    write("cpi_monthly", df)

    # T162 WPI monthly — sections (All commodities, Primary articles, ...) in
    # col1; year rows; months in columns Apr..Mar
    raw = table(162)
    section, out = None, {}
    for _, r in raw.iterrows():
        label = str(r[1]).strip() if pd.notna(r[1]) else ""
        if re.match(r"All commodities", label, re.I):
            section = "wpi_index"
        elif re.match(r"(Primary articles|Fuel|Manufactured|Food articles|Non-food)",
                      label, re.I):
            section = None
        if section and is_period_label(r[1]):
            fy = per_label(r[1])[:7]
            for i, mon in enumerate(month_cols):
                v = num(r[2 + i])
                lab = month_label(fy, mon)
                if lab and v == v:
                    out.setdefault(lab, {})[section] = v
    df = pd.DataFrame.from_dict(out, orient="index").reset_index()
    df.columns = ["period"] + list(df.columns[1:])
    write("wpi_monthly", df)

    # T235 WPI annual variation + T236 CPI annual variation -> one dataset
    raw = table(235)
    wpi_v = {per_label(r[1])[:7]: num(r[2]) for _, r in raw.iterrows()
             if is_period_label(r[1])}
    raw = table(236)
    cpi_v = {}
    for _, r in raw.iterrows():
        if is_period_label(r[1]):
            cpi_v[per_label(r[1])[:7]] = num(r[7]) if pd.notna(num(r[7])) else num(r[4])
    periods = sorted(set(wpi_v) | set(cpi_v))
    df = pd.DataFrame({
        "period": periods,
        "wpi_variation_pct": [wpi_v.get(p) for p in periods],
        "cpi_variation_pct": [cpi_v.get(p) for p in periods]})
    df["cpi_wpi_gap"] = df["cpi_variation_pct"] - df["wpi_variation_pct"]
    write("inflation_variations", df)


def p_scb_aggregates():
    """T41 annual + T167 monthly + T232 growth rates."""
    cols = ["period", "demand_deposits", "time_deposits", "aggregate_deposits",
            "borrowings_from_rbi", "liabilities_to_banks", "other_liabilities"]
    raw = table(41)
    rows = [[per_label(r[1])] + [num(r[c]) for c in range(2, 8)]
            for _, r in raw.iterrows() if is_period_label(r[1])]
    ann = pd.DataFrame(rows, columns=cols)
    ann["period"] = ann["period"].str[:7]
    ann = ann.drop_duplicates("period", keep="last")

    mcols = ["period", "demand_deposits", "time_deposits", "aggregate_deposits",
             "borrowings_from_rbi", "liabilities_to_banks", "other_liabilities",
             "investments_govt_securities", "investments_other_approved",
             "investments_total", "food_credit", "non_food_credit",
             "bank_credit", "cash_in_hand", "balances_with_rbi", "assets_with_banks"]
    raw = table(167)
    rows, yr = [], None
    for _, r in raw.iterrows():
        if is_period_label(r[1]):
            yr = per_label(r[1])
        elif yr and isinstance(r[1], str) and r[1].strip().lower().rstrip(".") in MONTHS:
            lab = month_label(yr, r[1])
            if lab:
                rows.append([lab] + [num(r[c]) for c in range(2, 17)])
    mon = pd.DataFrame(rows, columns=mcols)
    mon = mon[mon["bank_credit"].notna() | mon["aggregate_deposits"].notna()]
    mon["credit_deposit_ratio"] = 100 * mon["bank_credit"] / mon["aggregate_deposits"]

    # enrich annual with March-snapshot bank credit + CD ratio
    mar = mon[mon["period"].str.endswith("-03")][
        ["period", "bank_credit", "non_food_credit", "food_credit"]].copy()
    mar["fy"] = mar["period"].str[:4].astype(int).astype(str) + "-" + \
        (mar["period"].str[:4].astype(int) + 1).astype(str).str[-2:]
    ann = ann.merge(mar[["fy", "bank_credit", "non_food_credit", "food_credit"]],
                    left_on="period", right_on="fy", how="left").drop(columns=["fy"])
    ann["credit_deposit_ratio"] = 100 * ann["bank_credit"] / ann["aggregate_deposits"]
    write("scb_aggregates_annual", ann)
    write("scb_aggregates_monthly", mon)

    raw = table(232)
    g = raw[raw[1].apply(is_period_label)]
    df = pd.DataFrame({
        "period": [per_label(r[1])[:7] for _, r in g.iterrows()],
        "demand_deposits_growth_pct": [num(r[2]) for _, r in g.iterrows()],
        "time_deposits_growth_pct": [num(r[3]) for _, r in g.iterrows()],
        "deposits_growth_pct": [num(r[4]) for _, r in g.iterrows()],
        "investments_growth_pct": [num(r[7]) for _, r in g.iterrows()],
        "food_credit_growth_pct": [num(r[8]) for _, r in g.iterrows()],
        "non_food_credit_growth_pct": [num(r[9]) for _, r in g.iterrows()],
        "credit_growth_pct": [num(r[10]) for _, r in g.iterrows()]})
    write("scb_growth", df.drop_duplicates("period", keep="last"))


def _sectoral(no: int, dates_from_header: bool) -> pd.DataFrame:
    raw = table(no)
    if dates_from_header:                      # T168/T169: cols are dates
        hdr = []
        for c in range(2, raw.shape[1]):
            v = raw.iloc[4][c]
            try:
                hdr.append(pd.Timestamp(v).strftime("%Y-%m-%d"))
            except Exception:
                hdr.append(per_label(v))
    else:                                      # T42/T43: cols are FY labels
        hdr = [per_label(raw.iloc[4][c])[:7] for c in range(2, raw.shape[1])]
    rows = []
    for _, r in raw.iterrows():
        lab = str(r[1]).strip() if pd.notna(r[1]) else ""
        if not lab or lab in ("nan",) or re.match(r"^\(?(Note|Source|Also)", lab):
            continue
        if lab.replace(".", "").replace(" ", "").isdigit():   # column-number row
            continue
        rows.append([re.sub(r"^\d+(\.\d+)*\s*", "", lab).strip()] +
                    [num(r[c]) for c in range(2, raw.shape[1])])
    df = pd.DataFrame(rows, columns=["sector"] + hdr)
    return df


def _wide_sector(df: pd.DataFrame, colmap: dict, total_kw: str, name: str):
    """Pivot sector rows to columns; periods become rows."""
    df = df[~df["sector"].duplicated()]
    d = df.set_index("sector")
    out = pd.DataFrame({"period": [c for c in d.columns]})
    for canon, kw in colmap.items():
        hit = [i for i in d.index if re.search(kw, i, re.I)]
        out[canon] = [d.loc[hit[0], c] for c in d.columns] if hit else np.nan
    tot = [i for i in d.index if re.search(total_kw, i, re.I)]
    out["total_non_food_credit"] = [d.loc[tot[0], c] for c in d.columns] if tot else np.nan
    for s in colmap:
        out[f"{s}_share_pct"] = 100 * out[s] / out["total_non_food_credit"]
    write(name, out)


def p_credit_sectoral():
    _wide_sector(_sectoral(42, False), {
        "agriculture": r"agriculture", "industry": r"^industry",
        "services": r"^services", "retail": r"personal|retail"},
        r"non[- ]food credit", "credit_sectoral_annual")
    _wide_sector(_sectoral(168, True), {
        "agriculture": r"agriculture", "industry": r"^industry",
        "services": r"^services", "retail": r"personal|retail"},
        r"non[- ]food credit", "credit_sectoral_monthly")
    _wide_sector(_sectoral(43, False), {
        "mining": r"mining", "food_processing": r"food process",
        "textiles": r"textile", "chemicals": r"chemical",
        "infrastructure": r"infrastructure", "basic_metal": r"basic metal|iron & steel"},
        r"industries \(2", "credit_industry_annual")
    _wide_sector(_sectoral(169, True), {
        "mining": r"mining", "food_processing": r"food process",
        "textiles": r"textile", "chemicals": r"chemical",
        "infrastructure": r"infrastructure", "basic_metal": r"basic metal|iron & steel"},
        r"industries \(2", "credit_industry_monthly")


def p_scb_balance_sheet():
    """T49 — consolidated balance sheet of SCBs (liabilities side).
    Positional mapping of RBI columns (1) Year .. (7) Total."""
    raw = table(49)
    names = ["period", "capital", "reserves_surplus", "deposits", "borrowings",
             "other_liabilities", "other_items", "total_liabilities"]
    rows = []
    for _, r in raw.iterrows():
        if is_period_label(r[1]):
            vals = [num(r[c]) for c in range(2, 9)]
            vals = (vals + [np.nan] * 7)[:7]      # pad/truncate to 7 data cols
            rows.append([per_label(r[1])[:7]] + vals)
    df = pd.DataFrame(rows, columns=names)
    df = df.drop_duplicates("period", keep="last")
    # cross-check: reported total vs component sum (QA column kept transparent)
    comp = df[["capital", "reserves_surplus", "deposits",
               "borrowings", "other_liabilities", "other_items"]].sum(axis=1)
    df["total_liabilities_check"] = comp
    write("scb_balance_sheet", df)


def p_scb_ratios():
    """T233 — SCB intermediation ratios (%)."""
    raw = table(233)
    rows = [[per_label(r[1])[:7]] + [num(r[c]) for c in range(2, 9)]
            for _, r in raw.iterrows() if is_period_label(r[1])]
    df = pd.DataFrame(rows, columns=[
        "period", "credit_to_deposit_pct", "investments_to_deposit_pct",
        "govt_sec_to_deposit_pct", "credit_to_workfund_pct",
        "investments_to_workfund_pct", "govt_sec_to_workfund_pct",
        "aggregate_deposit_share_pct"])
    write("scb_ratios", df.drop_duplicates("period", keep="last"))


def p_npa_crar():
    """T50 — gross/net NPAs by bank group (pivoted wide); T51 — CRAR bands."""
    raw = table(50)
    group, rows = None, []
    for _, r in raw.iterrows():
        lab = str(r[1]).strip() if pd.notna(r[1]) else ""
        if re.match(r"Scheduled Comm", lab, re.I):
            group = "all"
        elif re.search(r"State Bank", lab, re.I):
            group = "sbi_group"
        elif re.search(r"Nationalised", lab, re.I):
            group = "nationalised"
        elif re.search(r"Private Sector", lab, re.I):
            group = "private"
        elif re.search(r"Foreign", lab, re.I):
            group = "foreign"
        elif is_period_label(r[1]):
            rows.append([per_label(r[1])[:7], group] + [num(r[c]) for c in range(2, 10)])
    long = pd.DataFrame(rows, columns=[
        "period", "bank_group", "advances_gross", "advances_net",
        "gross_npa_amount", "gross_npa_to_advances_pct", "gross_npa_to_total_assets_pct",
        "net_npa_amount", "net_npa_to_advances_pct", "net_npa_to_total_assets_pct"])
    long = long.dropna(subset=["bank_group"])
    long = long.drop_duplicates(["period", "bank_group"], keep="last")
    out = pd.DataFrame({"period": sorted(long["period"].unique())})
    for g in ("all", "sbi_group", "nationalised", "private", "foreign"):
        sub = long[long["bank_group"] == g].set_index("period")
        for m in ("gross_npa_amount", "gross_npa_to_advances_pct",
                  "net_npa_amount", "net_npa_to_advances_pct",
                  "advances_gross", "advances_net"):
            out[f"{m}_{g}"] = out["period"].map(sub[m])
    write("npa_bank_group", out)

    raw = table(51)
    yr, rows = None, []
    for _, r in raw.iterrows():
        if is_period_label(r[1]):
            yr = per_label(r[1])[:7]
        band_lab = str(r[2]).strip() if pd.notna(r[2]) else ""
        if yr and re.search(r"(Below|Between|Above)", band_lab):
            band = ("below_9pct" if re.search(r"Below 9", band_lab) else
                    "9_to_10pct" if re.search(r"9-10", band_lab) else
                    "10_to_12pct" if re.search(r"10-12", band_lab) else
                    "above_12pct" if re.search(r"Above 12", band_lab) else
                    "above_10pct" if re.search(r"Above 10", band_lab) else None)
            if band:
                rows.append([yr, band, num(r[8]), num(r[9])])
    long = pd.DataFrame(rows, columns=["period", "band", "banks_total", "weighted_avg_crar"])
    out = pd.DataFrame({"period": sorted(long["period"].unique())})
    for b in ("below_9pct", "9_to_10pct", "10_to_12pct", "above_10pct", "above_12pct"):
        sub = long[long["band"] == b].set_index("period")
        out[f"banks_{b}"] = out["period"].map(sub["banks_total"])
    out = out.fillna(0)
    w = long.dropna(subset=["weighted_avg_crar"]).drop_duplicates("period", keep="last")
    out["weighted_avg_crar"] = out["period"].map(w.set_index("period")["weighted_avg_crar"])
    write("crar_distribution", out)


def _reserves(no: int, name: str, block: bool):
    raw = table(no)
    rows, blk = [], None
    for _, r in raw.iterrows():
        if is_period_label(r[1]):
            v = per_label(r[1])
            if re.fullmatch(r"\d{4}", v) and block:      # year block (monthly)
                blk = v
                continue
            rows.append([v] + [num(r[c]) for c in range(2, 12)])
        elif block and isinstance(r[1], str) and r[1].strip().lower().rstrip(".") in MONTHS and blk:
            lab = month_label(blk, r[1])
            if lab:
                rows.append([lab] + [num(r[c]) for c in range(2, 12)])
    df = pd.DataFrame(rows, columns=[
        "period", "sdr_inr_crore", "sdr_usd_mn", "gold_inr_crore", "gold_usd_mn",
        "fca_inr_crore", "fca_usd_mn", "reserve_tranche_inr_crore",
        "reserve_tranche_usd_mn", "total_reserves_inr_crore", "total_reserves_usd_mn"])
    df = df[df["total_reserves_usd_mn"].notna() | df["total_reserves_inr_crore"].notna()]
    if name != "forex_weekly":
        df["period"] = df["period"].str[:7]
    write(name, df.drop_duplicates("period", keep="last"))


def p_forex():
    _reserves(144, "forex_annual", block=False)
    _reserves(210, "forex_monthly", block=True)
    _reserves(215, "forex_weekly", block=False)


def p_fx():
    """T132 annual rates, T223 daily rates (two side-by-side blocks), T207 NEER/REER."""
    raw = table(132)
    rows = [[per_label(r[1])[:4], num(r[3]), num(r[2]), num(r[4]), num(r[5]), num(r[6])]
            for _, r in raw.iterrows() if is_period_label(r[1])]
    df = pd.DataFrame(rows, columns=[
        "period", "usd_inr", "sdr_inr", "gbp_inr", "jpy_inr", "eur_inr"])
    write("fx_rates_annual", df.drop_duplicates("period", keep="last"))

    raw = table(223)
    rows = []
    for _, r in raw.iterrows():
        for off in (1, 6):                       # two blocks: cols 1-5 and 6-10
            if is_period_label(r[off]):
                rows.append([per_label(r[off])[:10], num(r[off + 1]), num(r[off + 2]),
                             num(r[off + 3]), num(r[off + 4])])
    df = pd.DataFrame(rows, columns=["period", "usd_inr", "gbp_inr", "eur_inr", "jpy_inr"])
    write("fx_rates_daily", df.drop_duplicates("period", keep="last"))

    raw = table(207)
    rows = []
    yr_state = {1: None, 6: None}          # per-block year marker
    for _, r in raw.iterrows():
        for off in (1, 6):
            lab = str(r[off]).strip() if pd.notna(r[off]) else ""
            if re.fullmatch(r"\d{4}", lab):
                yr_state[off] = lab
            elif lab.lower().rstrip(".") in MONTHS and yr_state[off]:
                rows.append([month_label(yr_state[off], lab), num(r[off + 1]),
                             num(r[off + 2]), num(r[off + 3]), num(r[off + 4])])
    df = pd.DataFrame(rows, columns=["period", "neer_index", "reer_index",
                                     "neer_export_index", "reer_export_index"])
    write("neer_reer", df.drop_duplicates("period", keep="last"))


def p_payments():
    """T58 — payment system indicators (FY columns × instrument rows)."""
    raw = table(58)
    years = []
    for c in range(2, raw.shape[1]):
        v = raw.iloc[3][c]
        if isinstance(v, str) and re.fullmatch(r"\d{4}-\d{2}", v.strip()):
            years.append((c, v.strip()))
    rows = {}
    for _, r in raw.iterrows():
        lab = str(r[1]).strip() if pd.notna(r[1]) else ""
        key = ("upi" if re.search(r"Unified Payment|UPI", lab, re.I) else
               "neft" if re.search(r"NEFT", lab, re.I) else
               "rtgs" if re.search(r"RTGS", lab, re.I) else
               "imps" if re.search(r"IMPS", lab, re.I) else
               "cards" if re.search(r"card", lab, re.I) else
               "paper" if re.search(r"paper|cheque|ECCS", lab, re.I) else
               "aeps" if re.search(r"AePS", lab, re.I) else
               "total" if re.search(r"Total Payments", lab, re.I) else
               "digital_total" if re.search(r"Total Digital", lab, re.I) else None)
        if key:
            for c, fy in years:
                rows.setdefault(fy, {})[f"{key}_volume_mn"] = num(r[c]) / 10 if num(r[c]) == num(r[c]) else num(r[c])
                rows[fy][f"{key}_value_crore"] = num(r[c + 1])
    df = pd.DataFrame.from_dict(rows, orient="index").reset_index()
    df = df.rename(columns={"index": "period"})
    if "digital_total_volume_mn" in df.columns and "total_volume_mn" in df.columns:
        df["digital_share_pct"] = 100 * df["digital_total_volume_mn"] / df["total_volume_mn"]
        df["paper_share_pct"] = 100 - df["digital_share_pct"]
    write("payment_systems", df)


def p_interest_structure():
    """T59 — structure of interest rates (deposit/lending/MCLR/WALR)."""
    raw = table(59)
    rows = []
    for _, r in raw.iterrows():
        if is_period_label(r[1]):
            rows.append([per_label(r[1])[:4]] + [num(r[c]) for c in range(2, 13)])
    df = pd.DataFrame(rows, columns=[
        "period", "call_money_rate", "savings_rate", "term_deposit_1_3y",
        "term_deposit_3_5y", "term_deposit_above_5y", "lending_rate",
        "mclr_1y", "walr_outstanding_pct", "walr_fresh_pct",
        "mclr_1y_wtd_pct", "wadtdr_outstanding_pct"])
    write("interest_structure", df.drop_duplicates("period", keep="last"))


def p_market_indices():
    """T85 annual averages, T182 NIFTY monthly, T183 SENSEX monthly."""
    raw = table(85)
    rows = [[per_label(r[1])[:7], num(r[2]), num(r[3]), num(r[4]), num(r[5]), num(r[6])]
            for _, r in raw.iterrows() if is_period_label(r[1])]
    write("market_indices_annual", pd.DataFrame(rows, columns=[
        "period", "sensex_avg", "bse100_avg", "rbi_index_avg",
        "market_cap_bse_crore", "market_cap_allindia_crore"]))

    for no, name, col in ((182, "nifty_monthly", "nifty_avg"),
                          (183, "sensex_monthly", "sensex_avg")):
        raw = table(no)
        rows = []
        for _, r in raw.iterrows():
            if is_period_label(r[1]):
                fy = per_label(r[1])[:7]
                for i, mon in enumerate(["Apr", "May", "Jun", "Jul", "Aug", "Sep",
                                         "Oct", "Nov", "Dec", "Jan", "Feb", "Mar"]):
                    v = num(r[2 + i])
                    if v == v:
                        rows.append([month_label(fy, mon), v])
        write(name, pd.DataFrame(rows, columns=["period", col]))


# ────────────────────────── market lake derivatives ────────────────────────
def m_prices():
    """Daily prices + technical/risk derivatives for SBI and benchmarks."""
    def load(name):
        return pd.read_csv(MKT / name, parse_dates=["date"])

    sb = load("px_SBIN.NS.csv")
    sb["ma_50"] = sb["close"].rolling(50).mean()
    sb["ma_200"] = sb["close"].rolling(200).mean()
    ret = sb["close"].pct_change()
    sb["volatility_60d"] = ret.rolling(60).std() * np.sqrt(252) * 100
    sb["annual_volatility_pct"] = ret.rolling(252).std() * np.sqrt(252) * 100
    sb["drawdown_pct"] = 100 * (sb["close"] / sb["close"].cummax() - 1)
    sb["max_drawdown_pct"] = sb["drawdown_pct"].cummin()
    sb["var_95_pct"] = [
        float(np.percentile(ret.iloc[max(0, i - 252):i + 1].dropna(), 5)) * 100
        if i >= 60 else np.nan for i in range(len(sb))]
    sb["cum_sbin"] = 100 * sb["close"] / sb["close"].iloc[0]
    nifty = load("px_IDX_NSEI.csv")[["date", "close"]].rename(columns={"close": "nifty_close"})
    sb = sb.merge(nifty, on="date", how="left")
    sb["cum_nifty"] = 100 * sb["nifty_close"] / sb["nifty_close"].iloc[0]
    cov = ret.rolling(252).cov(sb["nifty_close"].pct_change())
    var = sb["nifty_close"].pct_change().rolling(252).var()
    sb["beta_nifty"] = cov / var
    # monthly return stamped on each month's last trading row
    sb["period"] = sb["date"].dt.strftime("%Y-%m")
    mret = sb.groupby("period")["close"].agg(["first", "last"])
    mret["monthly_return_pct"] = 100 * (mret["last"] / mret["first"] - 1)
    sb["monthly_return_pct"] = sb["period"].map(mret["monthly_return_pct"])
    sb.loc[sb.duplicated("period", keep="last"), "monthly_return_pct"] = np.nan
    sb["date"] = sb["date"].dt.strftime("%Y-%m-%d")
    sb = sb.drop(columns=["nifty_close", "period"])
    sb["period"] = sb["date"]          # unified period key for charts/SQL
    write("px_sbin", sb)

    for src, dst in (("px_IDX_NSEI.csv", "px_nifty"), ("px_IDX_BSESN.csv", "px_sensex"),
                     ("px_IDX_GSPC.csv", "px_sp500"), ("px_INR-X.csv", "px_usdinr")):
        df = load(src)
        df["date"] = df["date"].dt.strftime("%Y-%m-%d")
        df["period"] = df["date"]
        write(dst, df[["period", "date", "open", "high", "low", "close",
                       "adjclose", "volume"]])


def _indexed(files: dict, out_name: str):
    frames = []
    for sym, f in files.items():
        df = pd.read_csv(MKT / f, parse_dates=["date"])[["date", "close"]]
        df = df.rename(columns={"close": f"idx_{sym}"})
        df[f"idx_{sym}"] = 100 * df[f"idx_{sym}"] / df[f"idx_{sym}"].iloc[0]
        frames.append(df)
    out = frames[0]
    for f in frames[1:]:
        out = out.merge(f, on="date", how="outer")
    out = out.sort_values("date").ffill()
    out["period"] = out["date"].dt.strftime("%Y-%m-%d")
    write(out_name, out.drop(columns=["date"]))


def m_peers_px():
    _indexed({"sbin": "px_SBIN.NS.csv", "hdfc": "px_HDFCBANK.NS.csv",
              "icici": "px_ICICIBANK.NS.csv", "kotak": "px_KOTAKBANK.NS.csv",
              "axis": "px_AXISBANK.NS.csv"}, "px_peers_in")
    _indexed({"sbin": "px_SBIN.NS.csv", "jpm": "px_JPM.csv", "hsbc": "px_HSBC.csv",
              "c": "px_C.csv", "mufg": "px_MUFG.csv", "bcs": "px_BCS.csv",
              "bac": "px_BAC.csv"}, "px_peers_gl")


def _fin(sym: str, kind: str) -> pd.DataFrame:
    return pd.read_csv(MKT / f"fin_{kind}_{sym}.csv")


def m_financials():
    sb = _fin("SBIN.NS", "annual")
    sb["net_margin_pct"] = 100 * sb["annualNetIncome"] / sb["annualTotalRevenue"]
    sb["roe_pct"] = 100 * sb["annualNetIncome"] / sb["annualStockholdersEquity"]
    sb["roa_pct"] = 100 * sb["annualNetIncome"] / sb["annualTotalAssets"]
    sb["period"] = sb["as_of_date"]
    write("fin_sbin_annual", sb)

    sq = _fin("SBIN.NS", "quarterly")
    sq["net_margin_pct"] = 100 * sq["quarterlyNetIncome"] / sq["quarterlyTotalRevenue"]
    sq["period"] = sq["as_of_date"]
    write("fin_sbin_quarterly", sq)

    # Indian peers — wide, one column family per bank
    banks = {"sbin": "SBIN.NS", "hdfc": "HDFCBANK.NS", "icici": "ICICIBANK.NS",
             "kotak": "KOTAKBANK.NS", "axis": "AXISBANK.NS"}
    out = None
    for key, sym in banks.items():
        df = _fin(sym, "annual").set_index("as_of_date")
        df = df.rename(columns={c: f"{c.split('annual')[-1].lower()}_{key}"
                                for c in df.columns if c != "as_of_date"})
        out = df if out is None else out.join(df, how="outer")
    out = out.reset_index().rename(columns={"as_of_date": "period"}).sort_values("period")
    asset_cols = [c for c in out.columns if c.startswith("totalassets_")]
    ni_cols = [c for c in out.columns if c.startswith("netincome_")]
    out["asset_share_pct_sbin"] = 100 * out["totalassets_sbin"] / out[asset_cols].sum(axis=1)
    out["net_margin_pct_sbin"] = 100 * out["netincome_sbin"] / out["totalrevenue_sbin"]
    for key in banks:
        eq = f"stockholdersequity_{key}"
        if eq in out.columns:
            out[f"roe_pct_{key}"] = 100 * out[f"netincome_{key}"] / out[eq]
    roe_cols = [c for c in out.columns if c.startswith("roe_pct_") and c != "roe_pct_sbin"]
    out["peer_median_roe"] = out[roe_cols].median(axis=1)
    out["revenue_rank_sbin"] = out[[c for c in out.columns
                                    if c.startswith("totalrevenue_")]].rank(
        axis=1, ascending=False)["totalrevenue_sbin"]
    write("fin_peers_in_annual", out)

    # Global peers — assets/net income converted to US$ bn at FY-end FX rates.
    # SBIN reports in INR, MUFG in JPY, the rest in USD; match fiscal periods by
    # nearest reporting date (Indian FY Mar-close vs US/EU Dec-close).
    def fx_rate(symbol_file, target):
        try:
            s = pd.read_csv(MKT / symbol_file, parse_dates=["date"]).set_index("date")["close"]
            i = s.index.get_indexer([pd.Timestamp(target)], method="nearest")[0]
            return float(s.iloc[i]) if abs((s.index[i] - pd.Timestamp(target)).days) < 250 else None
        except Exception:
            return None

    sb_inr = _fin("SBIN.NS", "annual").set_index("as_of_date")
    gl_banks = {"jpm": ("JPM", "usd"), "hsbc": ("HSBC", "usd"), "bcs": ("BCS", "usd"),
                "c": ("C", "usd"), "mufg": ("MUFG", "jpy"), "bac": ("BAC", "usd")}
    gl_fin = {k: _fin(sym, "annual").copy() for k, (sym, _) in gl_banks.items()}
    rows = []
    for p in sorted(sb_inr.index):
        row = {"period": p}
        rate = fx_rate("px_INR-X.csv", p)
        if rate:
            row["total_assets_usd_bn_sbin"] = float(sb_inr.loc[p, "annualTotalAssets"]) / rate / 1e9
            row["net_income_usd_bn_sbin"] = float(sb_inr.loc[p, "annualNetIncome"]) / rate / 1e9
            eq = float(sb_inr.loc[p, "annualStockholdersEquity"])
            if eq:
                row["roe_pct_sbin"] = 100 * float(sb_inr.loc[p, "annualNetIncome"]) / eq
        for key, (_, ccy) in gl_banks.items():
            df = gl_fin[key]
            if df.empty:
                continue
            cand = df.iloc[(pd.to_datetime(df["as_of_date"]) - pd.Timestamp(p)).abs().argsort()[:1]]
            days = abs((pd.to_datetime(cand["as_of_date"]).iloc[0] - pd.Timestamp(p)).days)
            if days > 250:
                continue
            div = 1.0
            if ccy == "jpy":
                jpy = fx_rate("px_JPY-X.csv", p)
                if not jpy:
                    continue
                div = jpy
            assets = float(cand["annualTotalAssets"].iloc[0]) / div / 1e9
            ni = float(cand["annualNetIncome"].iloc[0]) / div / 1e9
            eq = float(cand["annualStockholdersEquity"].iloc[0])
            row[f"total_assets_usd_bn_{key}"] = assets
            row[f"net_income_usd_bn_{key}"] = ni
            if eq:
                row[f"roe_pct_{key}"] = 100 * float(cand["annualNetIncome"].iloc[0]) / eq
        rows.append(row)
    out = pd.DataFrame(rows)
    asset_c = [c for c in out.columns if c.startswith("total_assets_usd_bn_")]
    roe_c = [c for c in out.columns if c.startswith("roe_pct_") and c != "roe_pct_sbin"]
    out["global_median_roe"] = out[roe_c].median(axis=1)
    out["asset_rank_sbin"] = out[asset_c].rank(axis=1, ascending=False)[
        "total_assets_usd_bn_sbin"]
    write("fin_peers_gl_annual", out)


def main():
    print("RBI HBS tables -> tidy datasets")
    p_policy_rates(); p_money_stock(); p_money_sources(); p_inflation()
    p_scb_aggregates(); p_credit_sectoral(); p_scb_balance_sheet(); p_scb_ratios()
    p_npa_crar(); p_forex(); p_fx(); p_payments(); p_interest_structure()
    p_market_indices()
    print("market lake -> derived datasets")
    m_prices(); m_peers_px(); m_financials()
    print("Done.")


if __name__ == "__main__":
    sys.exit(main())
