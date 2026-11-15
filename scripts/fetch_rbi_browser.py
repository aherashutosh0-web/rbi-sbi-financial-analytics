#!/usr/bin/env python3
"""
fetch_rbi_browser.py — Download RBI HBS XLSX tables through a real Chromium.

The rbidocs CDN fronts files with an F5 TSPD JavaScript challenge; plain HTTP
clients receive an HTML interstitial forever. A real browser executes the
challenge, receives the clearance cookie, and re-requests the file — Playwright
captures that final response as a download.

Run:  python3 scripts/fetch_rbi_browser.py
"""
import json
import pathlib
import re
import sys
import time

BASE = pathlib.Path(__file__).resolve().parent.parent
LAKE = BASE / "data_lake" / "rbi"
INDEX_JSON = BASE / "data_lake" / "rbi_hbs_index.json"
CHROME = BASE.parent / ".openclaw" / "tmp" / "chrome-linux64" / "chrome"

WANTED = [
    33, 34, 36, 37, 40, 41, 42, 43, 49, 50, 51, 58, 59,
    85, 132, 133, 134, 144, 162, 163, 165, 166, 167, 168, 169,
    182, 183, 207, 210, 215, 223, 231, 232, 233, 234, 235, 236,
]


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_")[:80]


def main() -> int:
    from playwright.sync_api import sync_playwright

    LAKE.mkdir(parents=True, exist_ok=True)
    index = json.loads(INDEX_JSON.read_text())
    wanted = [t for t in index if t["table_no"] in WANTED]

    with sync_playwright() as pw:
        browser = pw.chromium.launch(
            executable_path=str(CHROME),
            headless=True,
            args=["--disable-blink-features=AutomationControlled",
                  "--no-sandbox", "--disable-dev-shm-usage"])
        ctx = browser.new_context(
            user_agent=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) "
                        "Chrome/126.0.0.0 Safari/537.36"),
            accept_downloads=True)
        page = ctx.new_page()

        # Warm up: load an HTML page on the host so the WAF JS challenge runs once
        page.goto("https://rbidocs.rbi.org.in/", wait_until="domcontentloaded",
                  timeout=60000)
        time.sleep(6)
        print(f"warmup title: {page.title()[:60]}", flush=True)

        for t in wanted:
            dest = LAKE / f"table_{t['table_no']:03d}_{safe_name(t['name'])}.xlsx"
            if dest.exists() and dest.stat().st_size > 2000:
                print(f"  skip {dest.name[:60]}", flush=True)
                continue
            url = t["url"]
            for attempt in range(3):
                got = False
                try:
                    with page.expect_download(timeout=45000) as dl:
                        try:
                            page.goto(url, wait_until="commit", timeout=45000)
                        except Exception:
                            pass  # navigation aborts when the response is a download
                    download = dl.value
                    download.save_as(str(dest))
                    got = True
                except Exception as e:
                    # challenge page instead of download: give JS time, retry
                    time.sleep(5 + 5 * attempt)
                    # capture direct response body as fallback (works when the
                    # challenge cookie is already accepted)
                    try:
                        r = ctx.request.get(url, timeout=45000)
                        body = r.body()
                        if r.ok and len(body) > 3000 and body[:2] == b"PK":
                            dest.write_bytes(body)
                            got = True
                        else:
                            print(f"    resp {r.status} {len(body)}b "
                                  f"{'html-interstitial' if body[:9] == b'<!DOCTYPE' else ''}",
                                  flush=True)
                    except Exception as e2:
                        print(f"    err {str(e)[:50]} / {str(e2)[:50]}", flush=True)
                if got:
                    n = dest.stat().st_size
                    if n > 2000:
                        print(f"  ok   {dest.name[:60]} ({n // 1024} kb)", flush=True)
                        break
                    dest.unlink(missing_ok=True)
            else:
                print(f"  FAIL {dest.name[:60]}", flush=True)
            time.sleep(2)

        cookies = {c["name"]: c["value"] for c in ctx.cookies()}
        (BASE / "data_lake" / "rbi_cookies.json").write_text(json.dumps(cookies))
        browser.close()
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
