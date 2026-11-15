"""
run_sql.py — Execute every project's analytic query pack against the SQLite
warehouse, persist results, and write a verification log (industry QA step).

Output per project:
  sql/query_results/Q01.csv ... Q14.csv
  sql/verification.log
"""
import pathlib
import re
import sqlite3
import sys
import traceback

import pandas as pd

BASE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE))
DB = BASE / "warehouse" / "rbi_sbi_warehouse.db"

from common.registry import PROJECTS  # noqa: E402


def split_queries(sql: str) -> list[tuple[str, str]]:
    """Split on the '═══ QNN ·' banners, returning (name, statement)."""
    parts = re.split(r"-- ═══ (Q\d+)[^\n]*\n", sql)
    out = []
    for i in range(1, len(parts), 2):
        name, body = parts[i], parts[i + 1]
        # strip comment lines then take the single statement
        stmt = "\n".join(l for l in body.splitlines()
                         if not l.strip().startswith("--")).strip()
        stmt = stmt.rstrip(";").strip() + ";"
        out.append((name, stmt))
    return out


def main() -> int:
    if not DB.exists():
        print("Warehouse missing — run scripts/build_warehouse.py first.")
        return 1
    con = sqlite3.connect(DB)
    total, ok, fail = 0, 0, 0
    for p in PROJECTS:
        sql_file = BASE / p["slug"] / "sql" / "analysis_queries.sql"
        if not sql_file.exists():
            continue
        res_dir = BASE / p["slug"] / "sql" / "query_results"
        res_dir.mkdir(parents=True, exist_ok=True)
        log = [f"verification — {p['id']} {p['title']}", "=" * 90]
        for name, stmt in split_queries(sql_file.read_text()):
            total += 1
            try:
                df = pd.read_sql_query(stmt, con)
                df.to_csv(res_dir / f"{name}.csv", index=False)
                log.append(f"  PASS {name}  ({len(df)} rows × {len(df.columns)} cols)")
                ok += 1
            except Exception as e:
                log.append(f"  FAIL {name}: {type(e).__name__}: {str(e)[:120]}")
                log.append("        " + stmt.splitlines()[0][:110])
                fail += 1
        (sql_file.parent / "verification.log").write_text("\n".join(log) + "\n")
        print(f"  {p['id']}: {'OK ' if not any('FAIL' in l for l in log) else 'CHECK'} "
              f"{len(log) - 2} queries")
    con.close()
    print(f"\nSQL verification: {ok}/{total} passed, {fail} failed")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
