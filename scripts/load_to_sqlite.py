"""Load the UCI Online Retail CSV into SQLite and build the star schema.

Pipeline:
  1. Read data/online_retail.csv and apply minimal type cleaning
     (invoice timestamps parsed explicitly — the source is M/D/YYYY).
  2. Create the database from sql/schema.sql and bulk-load staging_raw
     (raw rows kept, so sql/cleaning.sql can audit exclusions).
  3. Build dimensions + fact table via sql/cleaning.sql — all business
     logic lives in SQL, not here.

Usage:
    python scripts/load_to_sqlite.py
"""

import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "online_retail.csv"
DB = ROOT / "db" / "retail.db"


def main() -> None:
    DB.parent.mkdir(parents=True, exist_ok=True)
    if DB.exists():
        DB.unlink()  # rebuild from scratch for reproducibility

    df = pd.read_csv(DATA, dtype={"InvoiceNo": str, "StockCode": str,
                                  "Description": str, "Country": str})
    df = df.rename(columns={"InvoiceNo": "invoice_no", "StockCode": "stock_code",
                             "Description": "description", "Quantity": "quantity",
                             "InvoiceDate": "invoice_date", "UnitPrice": "unit_price",
                             "CustomerID": "customer_id", "Country": "country"})

    # --- minimal cleaning: types only --------------------------------------
    parsed = pd.to_datetime(df["invoice_date"], format="%m/%d/%Y %H:%M",
                            errors="coerce")
    bad = int(parsed.isna().sum())
    assert bad == 0, f"{bad} unparseable invoice timestamps"
    df["invoice_date"] = parsed.dt.strftime("%Y-%m-%d %H:%M")

    df["quantity"] = df["quantity"].astype(int)
    df["unit_price"] = df["unit_price"].astype(float)
    # CustomerID arrives as float (NaN where missing); keep NULLs as NULL
    df["customer_id"] = df["customer_id"].apply(
        lambda x: None if pd.isna(x) else str(int(x)))
    for col in ("invoice_no", "stock_code", "description", "country"):
        df[col] = df[col].str.strip()

    con = sqlite3.connect(DB)
    con.executescript((ROOT / "sql" / "schema.sql").read_text(encoding="utf-8"))
    df.to_sql("staging_raw", con, if_exists="append", index=False)
    con.executescript((ROOT / "sql" / "cleaning.sql").read_text(encoding="utf-8"))
    con.commit()

    n_stage = con.execute("SELECT COUNT(*) FROM staging_raw").fetchone()[0]
    n_fact = con.execute("SELECT COUNT(*) FROM fact_sales").fetchone()[0]
    assert n_stage == len(df), (n_stage, len(df))
    assert n_fact < n_stage, "expected some rows to be excluded by cleaning"
    con.close()
    print(f"OK: {n_stage:,} staged rows -> {n_fact:,} clean fact rows "
          f"({n_stage - n_fact:,} excluded)")


if __name__ == "__main__":
    main()
