"""Run every query in sql/analysis_queries.sql and save result sets as CSVs.

Each query block in analysis_queries.sql is headed by a comment of the form:
    -- Q1 | q1_some_slug | The business question?
The slug becomes the output filename: outputs/q1_some_slug.csv

Usage:
    python scripts/export_query_results.py
"""

import re
import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
# resolved at runtime: the .db file is the only *.db in db/
DB = next((ROOT / "db").glob("*.db"), None)
SQL_FILE = ROOT / "sql" / "analysis_queries.sql"
OUT_DIR = ROOT / "outputs"


def parse_queries(text: str):
    """Split the SQL file into (number, slug, title, sql) blocks."""
    blocks = re.split(r"(?m)^-- ={10,}\s*$", text)
    queries = []
    for block in blocks:
        m = re.search(r"--\s*Q(\d+)\s*\|\s*([\w_]+)\s*\|\s*(.+)", block)
        if not m:
            continue
        num, slug, title = m.groups()
        sql_lines = [ln for ln in block.splitlines()
                     if not ln.strip().startswith("--")]
        sql = "\n".join(sql_lines).strip().rstrip(";").strip()
        assert sql, f"empty SQL for Q{num}"
        queries.append((num, slug, title.strip(), sql))
    return queries


def main() -> None:
    assert DB is not None and DB.exists(), \
        f"database not found in {ROOT / 'db'} — run scripts/load_to_sqlite.py first"
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    queries = parse_queries(SQL_FILE.read_text(encoding="utf-8"))
    assert queries, "no queries parsed from analysis_queries.sql"

    con = sqlite3.connect(DB)
    for num, slug, title, sql in queries:
        df = pd.read_sql(sql, con)
        assert len(df) > 0, f"Q{num} returned no rows"
        out = OUT_DIR / f"{slug}.csv"
        df.to_csv(out, index=False)
        check = pd.read_csv(out)  # round-trip: the CSV must be valid
        assert check.shape == df.shape, f"CSV mismatch for Q{num}"
        print(f"Q{num}: {title}\n     -> {out.name} "
              f"{df.shape[0]} rows x {df.shape[1]} cols")
    con.close()
    print(f"\nOK: {len(queries)} result sets exported to outputs/")


if __name__ == "__main__":
    main()
