"""
build_warehouse.py — Load every tidy prepared dataset into a SQLite analytical
warehouse (star-flavoured, typed columns, indexes, metadata table).

Output: warehouse/rbi_sbi_warehouse.db
"""
import pathlib
import re
import sqlite3
import sys

import pandas as pd

BASE = pathlib.Path(__file__).resolve().parent.parent
PREP = BASE / "data_lake" / "prepared"
WH_DIR = BASE / "warehouse"
DB_PATH = WH_DIR / "rbi_sbi_warehouse.db"


def snake(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.strip().lower()).strip("_")


def load_csv(con: sqlite3.Connection, path: pathlib.Path):
    table = snake(path.stem)
    df = pd.read_csv(path)
    df.columns = [snake(c) for c in df.columns]
    df.to_sql(table, con, if_exists="replace", index=False)
    # indexes on period/date-ish columns for analytic queries
    for c in df.columns:
        if c in ("period", "date", "as_of_date", "year", "month", "bank", "symbol"):
            try:
                con.execute(f'CREATE INDEX IF NOT EXISTS "ix_{table}_{c}" ON "{table}" ("{c}")')
            except sqlite3.OperationalError:
                pass
    con.execute(
        "INSERT OR REPLACE INTO _dataset_catalog(table_name, source_file, row_count, col_count) "
        "VALUES (?,?,?,?)",
        (table, path.name, len(df), len(df.columns)))
    con.commit()
    return table, len(df)


def main() -> int:
    WH_DIR.mkdir(parents=True, exist_ok=True)
    if DB_PATH.exists():
        DB_PATH.unlink()
    con = sqlite3.connect(DB_PATH)
    con.execute(
        "CREATE TABLE IF NOT EXISTS _dataset_catalog("
        "table_name TEXT PRIMARY KEY, source_file TEXT, row_count INTEGER, col_count INTEGER)")
    con.commit()

    files = sorted(PREP.glob("*.csv"))
    if not files:
        print("No prepared CSVs found — run scripts/prepare_data.py first.")
        return 1
    total = 0
    for f in files:
        t, n = load_csv(con, f)
        total += n
        print(f"  {t:40s} {n:6d} rows")
    print(f"\nWarehouse: {DB_PATH}  ({len(files)} tables, {total} rows)")

    # convenience view used by many queries
    con.execute("DROP VIEW IF EXISTS v_catalog")
    con.execute("CREATE VIEW v_catalog AS SELECT * FROM _dataset_catalog ORDER BY table_name")
    con.commit()
    con.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
