#!/usr/bin/env python3
"""
fetch_market.py — Download real market & financial-statement data for SBI and benchmarks.

Source: Yahoo Finance public chart & fundamentals-timeseries APIs
        (State Bank of India — NSE: SBIN.NS, listed on BSE/NSE; global peers on NYSE/LSE).

Run:  python3 scripts/fetch_market.py
"""
import json
import pathlib
import sys
import time

import requests
import pandas as pd

BASE = pathlib.Path(__file__).resolve().parent.parent
LAKE = BASE / "data_lake" / "market"
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}

SYMBOLS = {
    # Indian banks
    "SBIN.NS": "State Bank of India (NSE)",
    "HDFCBANK.NS": "HDFC Bank (NSE)",
    "ICICIBANK.NS": "ICICI Bank (NSE)",
    "KOTAKBANK.NS": "Kotak Mahindra Bank (NSE)",
    "AXISBANK.NS": "Axis Bank (NSE)",
    "BANKBARODA.NS": "Bank of Baroda (NSE)",
    "PNB.NS": "Punjab National Bank (NSE)",
    # Global banks
    "JPM": "JPMorgan Chase (NYSE)",
    "BAC": "Bank of America (NYSE)",
    "HSBC": "HSBC Holdings (NYSE)",
    "BCS": "Barclays (NYSE)",
    "C": "Citigroup (NYSE)",
    "MUFG": "Mitsubishi UFJ Financial (NYSE)",
    # Benchmarks / macro
    "^NSEI": "NIFTY 50 Index",
    "^BSESN": "BSE SENSEX",
    "^GSPC": "S&P 500 Index",
    "INR=X": "USD/INR Exchange Rate",
}

FUNDAMENTAL_TYPES_ANNUAL = [
    "annualTotalRevenue", "annualNetIncome", "annualTotalAssets",
    "annualTotalLiabilitiesNetMinorityInterest", "annualStockholdersEquity",
    "annualOperatingIncome", "annualInterestExpense", "annualInterestIncome",
    "annualProvisionForLoanLeaseAndOtherLosses",
    "annualTotalDebt", "annualCashAndCashEquivalents",
    "annualCommonStockDividendsPerShare", "annualDilutedEPS",
]
FUNDAMENTAL_TYPES_QUARTERLY = [
    "quarterlyTotalRevenue", "quarterlyNetIncome", "quarterlyTotalAssets",
    "quarterlyStockholdersEquity", "quarterlyOperatingIncome",
    "quarterlyInterestExpense", "quarterlyInterestIncome",
    "quarterlyProvisionForLoanLeaseAndOtherLosses", "quarterlyDilutedEPS",
]


def get_json(session, url, retries=3):
    for i in range(retries):
        try:
            r = session.get(url, timeout=45)
            r.raise_for_status()
            return r.json()
        except Exception as e:
            print(f"    retry {i+1}: {e}")
            time.sleep(2 + 2 * i)
    return None


def fetch_ohlcv(session, symbol: str, range_=None, period1=None, period2=None) -> pd.DataFrame:
    if period1 is not None:
        u = (f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}"
             f"?period1={period1}&period2={period2}&interval=1d&events=div,split")
    else:
        u = (f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}"
             f"?range={range_}&interval=1d&events=div,split")
    d = get_json(session, u)
    if not d:
        return pd.DataFrame()
    try:
        res = d["chart"]["result"][0]
        ts = res["timestamp"]
        q = res["indicators"]["quote"][0]
        adj = res["indicators"].get("adjclose", [{}])[0].get("adjclose", q["close"])
        dates = pd.to_datetime(pd.Series(ts), unit="s").dt.strftime("%Y-%m-%d")
        df = pd.DataFrame({
            "date": dates.values,
            "open": q["open"], "high": q["high"], "low": q["low"],
            "close": q["close"], "adjclose": adj, "volume": q["volume"],
        })
        df = df.dropna(subset=["close"])
        # dividends / splits events
        ev = res.get("events", {})
        if ev.get("dividends"):
            div = pd.DataFrame(ev["dividends"].values())
            div["date"] = pd.to_datetime(pd.Series(div["date"]), unit="s").dt.strftime("%Y-%m-%d").values
            df = df.merge(div[["date", "amount"]].rename(columns={"amount": "dividend"}),
                          on="date", how="left")
            df["dividend"] = df["dividend"].fillna(0.0)
        else:
            df["dividend"] = 0.0
        return df
    except Exception as e:
        print(f"    parse error {symbol}: {e}")
        return pd.DataFrame()


def fetch_fundamentals(session, symbol: str, types: list) -> pd.DataFrame:
    """Fetch fundamentals across several time windows to extend history beyond
    the 4 periods the API returns for a single wide window."""
    windows = [
        (1262304000, 1451606400),  # 2010-01-01 .. 2016-01-01
        (1451606400, 1577836800),  # 2016-01-01 .. 2020-01-01
        (1577836800, 1672531200),  # 2020-01-01 .. 2023-01-01
        (1672531200, 1900000000),  # 2023-01-01 .. future
    ]
    rows = {}
    for p1, p2 in windows:
        u = (f"https://query1.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/"
             f"timeseries/{symbol}?symbol={symbol}&type={','.join(types)}"
             f"&period1={p1}&period2={p2}")
        d = get_json(session, u)
        if not d:
            continue
        for item in d.get("timeseries", {}).get("result", []):
            for key, values in item.items():
                if key in ("meta", "timestamp") or not values:
                    continue
                for v in values:
                    date = v.get("asOfDate")
                    val = v.get("reportedValue", {}).get("raw")
                    if date is not None and val is not None:
                        rows.setdefault(date, {})[key] = val
        time.sleep(0.4)
    if not rows:
        return pd.DataFrame()
    df = pd.DataFrame.from_dict(rows, orient="index").sort_index()
    df.index.name = "as_of_date"
    return df.reset_index()


def main() -> int:
    LAKE.mkdir(parents=True, exist_ok=True)
    with requests.Session() as s:
        s.headers.update(HEADERS)

        print("== OHLCV price histories (10 years daily) ==")
        for sym, name in SYMBOLS.items():
            dest = LAKE / f"px_{sym.replace('^','IDX_').replace('=','-')}.csv"
            if dest.exists():
                print(f"  skip {dest.name}")
                continue
            print(f"  {sym} ({name})")
            df = fetch_ohlcv(s, sym, period1=1262304000, period2=1900000000)  # 2010-01-01 -> now
            if df.empty:
                df = fetch_ohlcv(s, sym, range_="10y")
            if not df.empty:
                df.to_csv(dest, index=False)
                print(f"    ok {dest.name}: {len(df)} rows")

        print("\n== Financial statements ==")
        stmt_syms = ["SBIN.NS", "HDFCBANK.NS", "ICICIBANK.NS", "KOTAKBANK.NS",
                     "AXISBANK.NS", "JPM", "HSBC", "BCS", "C", "MUFG", "BAC"]
        for sym in stmt_syms:
            for kind, types in (("annual", FUNDAMENTAL_TYPES_ANNUAL),
                                ("quarterly", FUNDAMENTAL_TYPES_QUARTERLY)):
                dest = LAKE / f"fin_{kind}_{sym.replace('=','-')}.csv"
                if dest.exists():
                    print(f"  skip {dest.name}")
                    continue
                print(f"  {sym} {kind}")
                df = fetch_fundamentals(s, sym, types)
                if not df.empty:
                    df.to_csv(dest, index=False)
                    print(f"    ok {dest.name}: {len(df)} rows")

    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
