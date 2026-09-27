-- ============================================================================
-- cleaning.sql — data quality checks + star-schema build
--
-- Cleaning rules (documented, reproducible):
--   * drop cancelled invoices            (invoice_no LIKE 'C%')
--   * drop non-positive quantities       (returns / data errors)
--   * drop non-positive unit prices      (data errors)
--   * drop rows with no customer         (cannot attribute revenue)
--
-- Run:  sqlite3 db/retail.db < sql/cleaning.sql
-- (scripts/load_to_sqlite.py runs schema.sql + this file for you.)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- A. DATA QUALITY CHECKS — audit the raw extract before building anything
-- ----------------------------------------------------------------------------

-- A1. Rows that will be excluded, by reason (informational — not errors).
SELECT 'cancelled_invoice_lines' AS category, COUNT(*) AS rows_excluded
FROM staging_raw WHERE invoice_no LIKE 'C%'
UNION ALL
SELECT 'nonpositive_quantity', COUNT(*)
FROM staging_raw WHERE invoice_no NOT LIKE 'C%' AND quantity <= 0
UNION ALL
SELECT 'nonpositive_unit_price', COUNT(*)
FROM staging_raw WHERE invoice_no NOT LIKE 'C%' AND quantity > 0 AND unit_price <= 0
UNION ALL
SELECT 'missing_customer_id', COUNT(*)
FROM staging_raw
WHERE invoice_no NOT LIKE 'C%' AND quantity > 0 AND unit_price > 0
  AND (customer_id IS NULL OR TRIM(customer_id) = '');

-- A2. Hard data problems that must be zero before the build.
SELECT 'null_invoice_no'  AS check_name, COUNT(*) AS bad_rows FROM staging_raw WHERE invoice_no IS NULL OR TRIM(invoice_no) = ''
UNION ALL
SELECT 'null_invoice_date', COUNT(*) FROM staging_raw WHERE invoice_date IS NULL
UNION ALL
SELECT 'null_stock_code',  COUNT(*) FROM staging_raw WHERE stock_code IS NULL OR TRIM(stock_code) = '';

-- A3. Grain note: (stock_code, description) is the product grain — codes are
--     occasionally reused with a different description in this extract.

-- ----------------------------------------------------------------------------
-- B. BUILD THE STAR SCHEMA (clean rows only)
-- ----------------------------------------------------------------------------

-- B1. Date dimension: one row per distinct order date.
INSERT INTO dim_date (date, year, quarter, month, month_name, year_month)
SELECT DISTINCT
    date(invoice_date) AS date,
    CAST(strftime('%Y', invoice_date) AS INTEGER) AS year,
    CAST((CAST(strftime('%m', invoice_date) AS INTEGER) + 2) / 3 AS INTEGER) AS quarter,
    CAST(strftime('%m', invoice_date) AS INTEGER) AS month,
    CASE CAST(strftime('%m', invoice_date) AS INTEGER)
        WHEN 1 THEN 'January'   WHEN 2 THEN 'February' WHEN 3 THEN 'March'
        WHEN 4 THEN 'April'     WHEN 5 THEN 'May'      WHEN 6 THEN 'June'
        WHEN 7 THEN 'July'      WHEN 8 THEN 'August'   WHEN 9 THEN 'September'
        WHEN 10 THEN 'October'  WHEN 11 THEN 'November' WHEN 12 THEN 'December'
    END AS month_name,
    strftime('%Y-%m', invoice_date) AS year_month
FROM staging_raw
WHERE invoice_no NOT LIKE 'C%'
  AND quantity > 0
  AND unit_price > 0
  AND customer_id IS NOT NULL AND TRIM(customer_id) <> ''
ORDER BY date;

-- B2. Product dimension over the true grain (stock_code, description).
INSERT INTO dim_product (stock_code, description)
SELECT stock_code, description
FROM staging_raw
WHERE invoice_no NOT LIKE 'C%'
  AND quantity > 0
  AND unit_price > 0
  AND customer_id IS NOT NULL AND TRIM(customer_id) <> ''
GROUP BY stock_code, description
ORDER BY stock_code, description;

-- B3. Customer dimension: one row per customer.
INSERT INTO dim_customer (customer_id, country)
SELECT customer_id, MAX(country) AS country
FROM staging_raw
WHERE invoice_no NOT LIKE 'C%'
  AND quantity > 0
  AND unit_price > 0
  AND customer_id IS NOT NULL AND TRIM(customer_id) <> ''
GROUP BY customer_id
ORDER BY customer_id;

-- B4. Sales fact: one row per clean order line.
INSERT INTO fact_sales (
    invoice_no, invoice_date, order_date, product_key, customer_id,
    country, quantity, unit_price, revenue
)
SELECT
    s.invoice_no,
    s.invoice_date,
    date(s.invoice_date),
    p.product_key,
    c.customer_id,
    s.country,
    s.quantity,
    s.unit_price,
    ROUND(s.quantity * s.unit_price, 2)
FROM staging_raw s
JOIN dim_product  p ON p.stock_code = s.stock_code AND p.description = s.description
JOIN dim_customer c ON c.customer_id = s.customer_id
WHERE s.invoice_no NOT LIKE 'C%'
  AND s.quantity > 0
  AND s.unit_price > 0
  AND s.customer_id IS NOT NULL AND TRIM(s.customer_id) <> '';

-- B5. Reconciliation.
SELECT 'staging_rows'          AS tbl, COUNT(*) AS n FROM staging_raw
UNION ALL
SELECT 'fact_rows',            COUNT(*) FROM fact_sales
UNION ALL
SELECT 'excluded_rows',        (SELECT COUNT(*) FROM staging_raw) - (SELECT COUNT(*) FROM fact_sales)
UNION ALL
SELECT 'fact_orphan_product',  COUNT(*) FROM fact_sales WHERE product_key IS NULL
UNION ALL
SELECT 'fact_orphan_customer', COUNT(*) FROM fact_sales WHERE customer_id IS NULL;
