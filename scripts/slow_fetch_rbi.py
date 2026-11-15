#!/usr/bin/env python3
"""
slow_fetch_rbi.py — Patient downloader for RBI HBS XLSX tables.

The rbidocs CDN blackholes clients that burst requests (any HTTP client). This
fetcher attempts exactly ONE download per cycle with generous spacing, silently
backs off on failure, and keeps going until all files are present.

Run:  nohup python3 -u scripts/slow_fetch_rbi.py > ../.openclaw/tmp/slow_fetch.log 2>&1 &
"""
import json
import pathlib
import re
import subprocess
import sys
import time

BASE = pathlib.Path(__file__).resolve().parent.parent
LAKE = BASE / "data_lake" / "rbi"
INDEX_JSON = BASE / "data_lake" / "rbi_hbs_index.json"

WANTED = [
    33, 34, 36, 37, 40, 41, 42, 43, 49, 50, 51, 58, 59,
    85, 132, 133, 134, 144, 162, 163, 165, 166, 167, 168, 169,
    182, 183, 207, 210, 215, 223, 231, 232, 233, 234, 235, 236,
]

OK_GAP = 25          # seconds between successful downloads
FAIL_GAP = 110       # seconds after a failure (do NOT hammer — bans extend)
MAX_RUNTIME = 4 * 3600


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_")[:80]


def curl_get(url: str, dest: pathlib.Path) -> int:
    r = subprocess.run(
        ["curl", "-4", "-sS", "--fail", "--max-time", "60",
         "-A", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
         
         "-o", str(dest), "-w", "%{http_code}", url],
        capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"curl rc={r.returncode} {r.stderr[:60]}")
    return dest.stat().st_size if dest.exists() else 0


def main() -> int:
    LAKE.mkdir(parents=True, exist_ok=True)
    index = json.loads(INDEX_JSON.read_text())
    wanted = [t for t in index if t["table_no"] in WANTED]
    t0 = time.time()
    log = lambda m: (print(m, flush=True), sys.stdout.flush())

    while time.time() - t0 < MAX_RUNTIME:
        missing = []
        for t in wanted:
            dest = LAKE / f"table_{t['table_no']:03d}_{safe_name(t['name'])}.xlsx"
            if not (dest.exists() and dest.stat().st_size > 2000):
                missing.append((t, dest))
        if not missing:
            log(f"ALL {len(wanted)} FILES PRESENT")
            return 0
        t, dest = missing[0]
        try:
            n = curl_get(t["url"], dest)
            if n < 1000:
                dest.unlink(missing_ok=True)
                raise ValueError(f"tiny body {n}b")
            log(f"ok   table_{t['table_no']:03d} ({n//1024} kb) — {len(missing)-1} to go")
            time.sleep(OK_GAP)
        except Exception as e:
            if dest.exists():
                dest.unlink(missing_ok=True)
            log(f"wait table_{t['table_no']:03d}: {str(e)[:70]} — sleeping {FAIL_GAP}s")
            time.sleep(FAIL_GAP)
    log("TIMEOUT")
    return 1


if __name__ == "__main__":
    sys.exit(main())
