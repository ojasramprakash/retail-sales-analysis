-- ============================================================================
-- analysis_queries.sql — business questions answered in SQL
--
-- Each question is a single, runnable query. Run them all:
--   sqlite3 db/retail.db < sql/analysis_queries.sql
-- Or export every result set to CSV:
--   python scripts/export_query_results.py
-- ============================================================================

-- ===========================================================================
-- Q1 | q1_monthly_trend | How has revenue trended over time (Dec 2010 - Dec 2011)?
SELECT
    d.year_month,
    COUNT(DISTINCT f.invoice_no) AS orders,
    COUNT(DISTINCT f.customer_id) AS active_customers,
    ROUND(SUM(f.revenue), 2)      AS revenue
FROM fact_sales f
JOIN dim_date d ON d.date = f.order_date
GROUP BY d.year_month
ORDER BY d.year_month;

-- ===========================================================================
-- Q2 | q2_top_products | Which products drive the most revenue?
SELECT
    p.stock_code,
    p.description,
    SUM(f.quantity)                AS units_sold,
    COUNT(DISTINCT f.invoice_no)   AS orders,
    ROUND(SUM(f.revenue), 2)       AS revenue
FROM fact_sales f
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY p.stock_code, p.description
ORDER BY revenue DESC
LIMIT 10;

-- ===========================================================================
-- Q3 | q3_country_performance | Which countries contribute the most revenue?
SELECT
    f.country,
    COUNT(DISTINCT f.customer_id)  AS customers,
    COUNT(DISTINCT f.invoice_no)   AS orders,
    ROUND(SUM(f.revenue), 2)       AS revenue,
    ROUND(SUM(f.revenue) * 100.0 / SUM(SUM(f.revenue)) OVER (), 2) AS pct_of_revenue
FROM fact_sales f
GROUP BY f.country
ORDER BY revenue DESC
LIMIT 10;

-- ===========================================================================
-- Q4 | q4_customer_segments | One-time vs repeat vs loyal buyers: who drives revenue?
WITH cust AS (
    SELECT
        customer_id,
        COUNT(DISTINCT invoice_no) AS orders,
        SUM(revenue)               AS revenue
    FROM fact_sales
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN orders = 1 THEN 'One-time buyer'
        WHEN orders <= 5 THEN 'Repeat (2-5 orders)'
        ELSE 'Loyal (6+ orders)'
    END AS segment,
    COUNT(*)                        AS customers,
    ROUND(SUM(revenue), 2)           AS total_revenue,
    ROUND(AVG(revenue), 2)           AS avg_revenue_per_customer,
    ROUND(SUM(revenue) * 100.0 / SUM(SUM(revenue)) OVER (), 1) AS pct_of_revenue
FROM cust
GROUP BY segment
ORDER BY total_revenue DESC;

-- ===========================================================================
-- Q5 | q5_top_customers | Who are the top 10 customers by revenue?
SELECT
    f.customer_id,
    f.country,
    COUNT(DISTINCT f.invoice_no) AS orders,
    ROUND(SUM(f.revenue), 2)     AS revenue
FROM fact_sales f
GROUP BY f.customer_id, f.country
ORDER BY revenue DESC
LIMIT 10;
