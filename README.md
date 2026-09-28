# Retail Sales Analysis — UCI Online Retail

End-to-end SQL + Streamlit analytics on **541,909 real e-commerce transactions**
from a UK-based online gift retailer (Dec 2010 – Dec 2011).

## Business questions

1. **Revenue trends** — how did revenue move month to month?
2. **Top products** — which products drive the most revenue?
3. **Regional performance** — which countries contribute the most revenue?
4. **Customer segments** — one-time vs repeat vs loyal: who drives revenue? (+ top customers)

## Key findings

| Question | Finding |
|---|---|
| Trend | Revenue runs **£8.91M** over 13 months with strong Q4 seasonality — it nearly **doubles from £645K (Aug 2011) to £1.16M (Nov 2011)**, the peak month (2,657 orders) |
| Products | **Paper Craft "Little Birdie"** leads at £168K — but from a single 81K-unit bulk order. The real workhorse is the **Regency Cakestand 3 Tier**: £143K across 1,703 orders |
| Regions | The **UK drives 82.0% of revenue** (£7.31M). Next best — Netherlands (3.2%), EIRE (3.0%), Germany (2.6%) — are rounding errors. Growth opportunity is geographic diversification |
| Segments | **Loyal buyers (6+ orders)** are just 20% of customers (872 of 4,338) yet drive **66.3% of revenue** (£5.91M). One-time buyers (1,493) contribute only 6.9% |
| Top customer | Customer **14646 (Netherlands)** — 73 orders, **£280K revenue** |

## Dataset

- **Name:** UCI Online Retail (Chen, D., 2015)
- **Source:** [UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/352/online+retail) — loaded from the public CSV mirror
  `https://raw.githubusercontent.com/databricks/Spark-The-Definitive-Guide/master/data/retail-data/all/online-retail-dataset.csv` (vendored in `data/`)
- **Rows:** 541,909 transaction lines × 8 columns: `InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country`
- **License:** CC BY 4.0

## Data model

`fact_sales` (397,884 clean order lines) + `dim_date`, `dim_product`, `dim_customer`, with raw rows preserved in `staging_raw` for audit.

### Cleaning (all in `sql/cleaning.sql`)

| Excluded | Rows | Reason |
|---|---|---|
| Cancelled invoice lines (`InvoiceNo` like `C%`) | 9,288 | cancellations aren't revenue |
| Non-positive quantities | 1,336 | returns / data errors |
| Non-positive unit prices | 1,181 | data errors |
| Missing `CustomerID` | 132,220 | revenue can't be attributed |

Timestamps were parsed explicitly as **month-first** (`12/1/2010 8:26` = Dec 1, 2010) — parsed day-first, the dates land outside the known Dec 2010 – Dec 2011 window, which is how the bug was caught.

## Project structure

```
retail-sales-analysis/
├── data/online_retail.csv        # raw dataset (vendored, ~45 MB)
├── sql/
│   ├── schema.sql                # DDL: staging + star schema
│   ├── cleaning.sql              # quality checks + dimension/fact build
│   └── analysis_queries.sql      # the 5 business questions, one query each
├── scripts/
│   ├── load_to_sqlite.py         # CSV -> SQLite pipeline (runs schema + cleaning)
│   └── export_query_results.py   # executes each query, saves CSVs to outputs/
├── outputs/                      # every result set as CSV (regenerate any time)
├── db/                           # retail.db — generated, gitignored
├── app.py                        # Streamlit dashboard
├── requirements.txt
├── .gitignore
└── PUSH_TO_GITHUB.md             # exact commands to publish this repo
```

## Reproduce

```bash
python3 -m venv .venv && source .venv/bin/activate   # macOS/Linux
pip install -r requirements.txt

python scripts/load_to_sqlite.py      # build db/retail.db from the raw CSV
python scripts/export_query_results.py # run all queries -> outputs/*.csv
streamlit run app.py                   # launch the dashboard
```

## Skills demonstrated

- **SQL:** CTEs, window functions (`SUM() OVER ()` for share-of-total), `CASE` segmentation, star-schema modeling, data-quality auditing with reconciliation checks
- **Python:** pandas ETL (explicit datetime parsing, type coercion), `sqlite3` pipelines, query/result export automation
- **Streamlit:** KPI cards, line/bar charts, interactive tables, cached DB queries
