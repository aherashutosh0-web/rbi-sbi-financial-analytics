#!/usr/bin/env python3
"""
run_all.py — One-command rebuild of the full RBI–SBI analytics portfolio.
Safe to re-run; every stage is idempotent.
"""
import pathlib
import subprocess
import sys
import time

BASE = pathlib.Path(__file__).resolve().parent.parent

STAGES = [
    ("fetch_rbi_browser.py", "Download RBI HBS XLSX (browser engine)"),
    ("fetch_market.py", "Download Yahoo Finance market lake"),
    ("prepare_data.py", "Build tidy analytical datasets"),
    ("build_warehouse.py", "Load SQLite analytical warehouse"),
    ("build_sql.py", "Generate per-project SQL suites"),
    ("run_sql.py", "Execute & verify all analytic queries"),
    ("build_python.py", "Generate & run project analyses"),
    ("build_excel.py", "Build formatted Excel workbooks"),
    ("build_dashboards.py", "Build colour-theory HTML dashboards"),
    ("build_readme.py", "Generate project READMEs"),
]


def main() -> int:
    t0 = time.time()
    for script, label in STAGES:
        print(f"\n━━ [{script}] {label}")
        r = subprocess.run([sys.executable, str(BASE / "scripts" / script)])
        if r.returncode != 0:
            print(f"STAGE FAILED: {script} (rc={r.returncode})")
            return r.returncode
    print(f"\n✅ Portfolio build complete in {time.time() - t0:.0f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
