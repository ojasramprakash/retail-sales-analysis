"""Streamlit dashboard for the Retail Sales Analysis project.

Run:  streamlit run app.py
Data: db/retail.db (build it with `python scripts/load_to_sqlite.py`)
"""

from pathlib import Path
import sqlite3

import pandas as pd
import streamlit as st

DB = Path(__file__).parent / "db" / "retail.db"

st.set_page_config(page_title="Retail Sales Dashboard", layout="wide")


@st.cache_data
def query(sql: str) -> pd.DataFrame:
    with sqlite3.connect(DB) as con:
        return pd.read_sql(sql, con)


if not DB.exists():
    st.error("Database not found — run `python scripts/load_to_sqlite.py` first.")
    st.stop()

st.title("Retail Sales Dashboard")
st.caption(
    "UCI Online Retail · UK-based gift retailer · Dec 2010 – Dec 2011 · "
    "397,884 clean order lines (144,025 cancelled / invalid / unattributed "
    "rows excluded — see `sql/cleaning.sql`)"
)

# -- KPI cards ----------------------------------------------------------------
kpi = query(
    "SELECT COUNT(DISTINCT invoice_no) AS orders, "
    "COUNT(DISTINCT customer_id) AS customers, "
    "ROUND(SUM(revenue), 2) AS revenue FROM fact_sales"
).iloc[0]
c1, c2, c3, c4 = st.columns(4)
c1.metric("Total revenue", f"£{kpi['revenue']:,.0f}")
c2.metric("Orders", f"{kpi['orders']:,}")
c3.metric("Customers", f"{kpi['customers']:,}")
c4.metric("Avg order value", f"£{kpi['revenue'] / kpi['orders']:,.2f}")

# -- Revenue trend -------------------------------------------------------------
st.subheader("Monthly revenue trend")
monthly = query(
    "SELECT d.year_month, ROUND(SUM(f.revenue), 2) AS revenue "
    "FROM fact_sales f JOIN dim_date d ON d.date = f.order_date "
    "GROUP BY d.year_month ORDER BY d.year_month"
)
st.line_chart(monthly.set_index("year_month")["revenue"])
st.caption("Strong Q4 seasonality — revenue nearly doubles between August and "
           "November 2011, then falls back in December.")

# -- Products & geography ------------------------------------------------------
col1, col2 = st.columns(2)
with col1:
    st.subheader("Top 10 products by revenue")
    top = query(
        "SELECT p.description, ROUND(SUM(f.revenue), 2) AS revenue "
        "FROM fact_sales f JOIN dim_product p ON p.product_key = f.product_key "
        "GROUP BY p.description ORDER BY revenue DESC LIMIT 10"
    )
    st.bar_chart(top.set_index("description")["revenue"])
with col2:
    st.subheader("Revenue by country (top 10)")
    cty = query(
        "SELECT country, ROUND(SUM(revenue), 2) AS revenue "
        "FROM fact_sales GROUP BY country ORDER BY revenue DESC LIMIT 10"
    )
    st.bar_chart(cty.set_index("country")["revenue"])
st.caption("The UK drives 82% of revenue — the business is overwhelmingly domestic.")

# -- Customers -----------------------------------------------------------------
st.subheader("Customer segments")
seg = query(
    "WITH cust AS (SELECT customer_id, COUNT(DISTINCT invoice_no) AS orders, "
    "SUM(revenue) AS revenue FROM fact_sales GROUP BY customer_id) "
    "SELECT CASE WHEN orders = 1 THEN 'One-time buyer' "
    "WHEN orders <= 5 THEN 'Repeat (2-5 orders)' "
    "ELSE 'Loyal (6+ orders)' END AS segment, "
    "COUNT(*) AS customers, ROUND(SUM(revenue), 2) AS revenue "
    "FROM cust GROUP BY segment ORDER BY revenue DESC"
)
st.bar_chart(seg.set_index("segment")["revenue"])
st.caption("Just 20% of customers (loyal, 6+ orders) drive 66% of all revenue.")

st.subheader("Top 10 customers by revenue")
st.dataframe(
    query(
        "SELECT customer_id, country, COUNT(DISTINCT invoice_no) AS orders, "
        "ROUND(SUM(revenue), 2) AS revenue FROM fact_sales "
        "GROUP BY customer_id, country ORDER BY revenue DESC LIMIT 10"
    ),
    use_container_width=True,
)

st.divider()
st.caption("All figures come from the SQL analysis in `sql/analysis_queries.sql`; "
           "result sets are saved under `outputs/`.")
