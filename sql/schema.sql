-- ============================================================================
-- schema.sql — DDL for the UCI Online Retail SQLite warehouse
--
-- Staging holds the raw CSV (types lightly coerced by the loader);
-- cleaning.sql builds the star schema from it.
--
-- Run:  sqlite3 db/retail.db < sql/schema.sql
-- (scripts/load_to_sqlite.py runs this for you.)
-- ============================================================================

DROP TABLE IF EXISTS staging_raw;
CREATE TABLE staging_raw (
    invoice_no   TEXT,
    stock_code   TEXT,
    description  TEXT,
    quantity     INTEGER,
    invoice_date TEXT,   -- ISO 'YYYY-MM-DD HH:MM' (parsed by the loader)
    unit_price   REAL,
    customer_id  TEXT,   -- NULL when missing in the source
    country      TEXT
);

DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date (
    date       TEXT PRIMARY KEY,  -- YYYY-MM-DD
    year       INTEGER NOT NULL,
    quarter    INTEGER NOT NULL,  -- 1-4
    month      INTEGER NOT NULL,  -- 1-12
    month_name TEXT    NOT NULL,
    year_month TEXT    NOT NULL   -- YYYY-MM
);

DROP TABLE IF EXISTS dim_product;
CREATE TABLE dim_product (
    product_key INTEGER PRIMARY KEY,
    stock_code  TEXT NOT NULL,
    description TEXT NOT NULL
);

DROP TABLE IF EXISTS dim_customer;
CREATE TABLE dim_customer (
    customer_id TEXT PRIMARY KEY,
    country     TEXT NOT NULL
);

DROP TABLE IF EXISTS fact_sales;
CREATE TABLE fact_sales (
    invoice_no   TEXT    NOT NULL,
    invoice_date TEXT    NOT NULL,  -- full timestamp
    order_date   TEXT    NOT NULL REFERENCES dim_date(date),
    product_key  INTEGER NOT NULL REFERENCES dim_product(product_key),
    customer_id  TEXT    NOT NULL REFERENCES dim_customer(customer_id),
    country      TEXT    NOT NULL,
    quantity     INTEGER NOT NULL,
    unit_price   REAL    NOT NULL,
    revenue      REAL    NOT NULL   -- quantity * unit_price
);

CREATE INDEX IF NOT EXISTS idx_fact_order_date ON fact_sales(order_date);
CREATE INDEX IF NOT EXISTS idx_fact_product    ON fact_sales(product_key);
CREATE INDEX IF NOT EXISTS idx_fact_customer   ON fact_sales(customer_id);
CREATE INDEX IF NOT EXISTS idx_fact_invoice    ON fact_sales(invoice_no);
