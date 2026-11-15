#!/usr/bin/env python3
"""
distribute_data.py — Copy each project's tidy datasets into its own data/ folder
so every project is self-contained (portfolio structure requirement).
"""
import pathlib
import shutil
import sys

BASE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE))

from common.registry import PROJECTS  # noqa: E402

PREP = BASE / "data_lake" / "prepared"
MKT = BASE / "data_lake" / "market"


def main() -> int:
    for p in PROJECTS:
        ddir = BASE / p["slug"] / "data"
        ddir.mkdir(parents=True, exist_ok=True)
        n = 0
        for d in p["datasets"]:
            src = PREP / f"{d}.csv"
            if src.exists():
                shutil.copy2(src, ddir / src.name)
                n += 1
        # provenance note
        (ddir / "SOURCE.md").write_text(
            f"# Data provenance — {p['id']}\n\n"
            "- RBI series: Reserve Bank of India, *Handbook of Statistics on Indian "
            "Economy* (real XLSX downloads; table numbers in each dataset's registry "
            "entry and in `data_dictionary.md`).\n"
            "- Market series: Yahoo Finance daily prices & reported financials for "
            "SBIN.NS and benchmark/peer instruments.\n"
            "- Files are tidy extracts of `data_lake/prepared/` produced by "
            "`scripts/prepare_data.py`.\n")
        print(f"  {p['id']}: {n} dataset(s) -> {p['slug']}/data/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
