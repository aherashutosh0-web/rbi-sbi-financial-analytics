#!/usr/bin/env python3
"""
fetch_rbi.py — Download real RBI Handbook of Statistics on Indian Economy (HBS) tables.

Source: Reserve Bank of India, Handbook of Statistics on Indian Economy (2025-26 edition)
        https://www.rbi.org.in/Scripts/AnnualPublications.aspx?head=Handbook+of+Statistics+on+Indian+Economy
        Actual XLSX files hosted at https://rbidocs.rbi.org.in/rdocs/Publications/DOCs/*.XLSX

This script downloads the curated subset of tables used by the portfolio projects.
Run:  python3 scripts/fetch_rbi.py
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

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Referer": "https://www.rbi.org.in/",
}

# Table numbers we consume (HBS numbering)
WANTED = [
    33, 34, 36, 37, 40, 41, 42, 43, 49, 50, 51, 58, 59,
    85, 132, 133, 134, 144, 162, 163, 165, 166, 167, 168, 169,
    182, 183, 207, 210, 215, 223, 231, 232, 233, 234, 235, 236,
]


def fetch_index(session) -> list:
    """Parse the HBS landing page for table name -> XLSX URL mappings."""
    import requests
    url = ("https://www.rbi.org.in/Scripts/AnnualPublications.aspx"
           "?head=Handbook+of+Statistics+on+Indian+Economy")
    r = session.get(url, timeout=60)
    r.raise_for_status()
    rows = re.findall(
        r"<a class='link2' href=PublicationsView\.aspx\?id=(\d+)>([^<]+)</a>(.*?)"
        r"(?=<a class='link2'|</table>)",
        r.text, re.S)
    out = []
    for rid, name, chunk in rows:
        m = re.search(
            r"href='(https://rbidocs\.rbi\.org\.in/rdocs/Publications/DOCs/[^']+\.XLSX)'",
            chunk, re.I)
        if m:
            num = re.match(r"\s*Table\s*(\d+)", name)
            out.append({
                "pub_id": rid,
                "table_no": int(num.group(1)) if num else None,
                "name": name.strip(),
                "url": m.group(1),
                "source": "RBI Handbook of Statistics on Indian Economy",
            })
    return out


def safe_name(name: str) -> str:
    s = re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_")
    return s[:80]


def curl_get(url: str, dest: pathlib.Path) -> int:
    """Download via curl -4: the rbidocs CDN drops Python-urllib TLS handshakes
    (JA3 filtering) but accepts curl. Returns bytes written."""
    r = subprocess.run(
        ["curl", "-4", "-sS", "--fail", "--max-time", "90", "--retry", "2",
         "--retry-delay", "3", "-A", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
         
         "-o", str(dest), "-w", "%{http_code}", url],
        capture_output=True, text=True)
    if r.returncode != 0 or not dest.exists():
        raise RuntimeError(f"curl rc={r.returncode} {r.stderr[:80]}")
    return dest.stat().st_size


def main() -> int:
    LAKE.mkdir(parents=True, exist_ok=True)
    if INDEX_JSON.exists():
        index = json.loads(INDEX_JSON.read_text())
        print(f"Index: {len(index)} tables (cached)")
    else:
        import requests
        with requests.Session() as s:
            s.headers.update(HEADERS)
            index = fetch_index(s)
        INDEX_JSON.write_text(json.dumps(index, indent=1))
        print(f"Index: {len(index)} tables found")

    wanted = [t for t in index if t["table_no"] in WANTED]
    print(f"Downloading {len(wanted)} curated tables...")
    for t in wanted:
        fname = f"table_{t['table_no']:03d}_{safe_name(t['name'])}.xlsx"
        dest = LAKE / fname
        if dest.exists() and dest.stat().st_size > 2000:
            print(f"  skip {fname}")
            continue
        for attempt in range(4):
            try:
                n = curl_get(t["url"], dest)
                if n < 1000:
                    raise ValueError(f"suspiciously small body ({n} b)")
                print(f"  ok   {fname}  ({n // 1024} kb)")
                break
            except Exception as e:
                wait = 3 * (attempt + 1)
                print(f"  retry {fname} (wait {wait}s): {str(e)[:80]}")
                time.sleep(wait)
        else:
            print(f"  FAIL {fname}")
        time.sleep(1)
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
