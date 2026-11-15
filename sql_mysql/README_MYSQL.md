# Running the project in MySQL Workbench

All SQL in this project targets **MySQL 8.0**. This guide walks through loading the data, building the analysis table and running the queries.

| File | What it does | Run it in |
|---|---|---|
| `01_load.sql` | Template: creates the `olist` database and tables, and loads the CSVs | don't run directly |
| `01_load_local.sql` | Same as above with **your folder path** filled in (created by step 1) | Workbench |
| `02_order_facts.sql` | Builds the clean one-row-per-order table (about 30 seconds) | Workbench |
| `03_analysis.sql` | The six analysis queries | Workbench |
| `04_export.sql` | Dashboard summary queries | run by `python/export_dashboard.py` |

## Before you start (once)

1. **MySQL Server 8.0 running**, with a connection to it in Workbench. The project creates its own database called `olist`, so your other databases are untouched.
2. **Python packages:** `pip install pandas numpy statsmodels pymysql`
3. **The Olist CSVs** downloaded from Kaggle into `data/` (unzip any `.csv.zip` files; the folder must be called lowercase `data`).
4. **Raise Workbench's query timeout**, otherwise `02_order_facts.sql` may fail with *"Lost connection to MySQL server during query"*:
   Workbench menu → **Settings** (Windows: **Edit → Preferences**) → **SQL Editor** → set **DBMS connection read timeout** to **600** → OK, then reconnect.

## Step 1: prepare the data (about 1 minute)

From the project folder:
```bash
python python/prepare_mysql_data.py
```
This shrinks the CSVs (drops review comments, reduces 1 million geolocation rows to 19,015 zip-code centres) and writes `sql_mysql/01_load_local.sql` with your own folder path inside. That file is git-ignored so your path never goes on GitHub.

## Step 2: load the data

**In Workbench:** open your connection → **File → Open SQL Script…** → choose `sql_mysql/01_load_local.sql` → click **Run**. It takes about 25 seconds. The last result should show these counts:

| orders | order_items | order_reviews | customers | sellers | products | category_names | zip_centroids |
|---|---|---|---|---|---|---|---|
| 99,441 | 112,650 | 99,224 | 99,441 | 3,095 | 32,951 | 71 | 19,015 |

**If you get an error like "Loading local data is disabled" (error 3948 or 2068):** MySQL blocks `LOAD DATA LOCAL` unless both sides allow it. You have two ways round it:

- **Easiest: load from Python instead.** It runs the same statements and needs no Workbench settings:
  ```bash
  python python/load_mysql.py
  ```
  (It asks for your MySQL password, or uses `~/.my.cnf` if you have one. The password is not shown or saved.)
- **Or change Workbench:** on the Workbench home screen, **right-click your connection → Edit Connection → Advanced** tab and add `OPT_LOCAL_INFILE=1` in the **Others** box. Save, reconnect, and run `01_load_local.sql` again.

## Step 3: build the clean table

**File → Open SQL Script…** → `sql_mysql/02_order_facts.sql` → **Run**. Wait about 30 seconds. The result should be:

| orders_in_facts | distinct_orders | pct_late | avg_score | pct_bad_reviews |
|---|---|---|---|---|
| 94,563 | 94,563 | 6.7 | 4.17 | 12.3 |

## Step 4: run the analysis

Open `sql_mysql/03_analysis.sql`. You have two choices:

- **Run everything:** click **Run**. Workbench shows one result tab per query (*Result #1* to *#6*), so read them one by one.
- **Run one query at a time (clearer to read):** click anywhere inside a query, then click the small **arrow next to Run** and choose **Run current statement** (the option that runs only the statement under the cursor).

The six results answer: late vs on time, delay bands, share of bad reviews that were late, worst routes, monthly trend, and seller concentration. The expected numbers are in the key-findings table in the main [README](../README.md).

## Step 5: dashboard files and the regression

Workbench's own CSV export is unavailable in some versions, so Python does the exports:
```bash
python python/export_dashboard.py     # writes the 6 summary CSVs into ./dashboard
python python/analysis.py             # regression + "bad reviews avoided", writes 2 more CSVs
```
Run both from the project folder. They connect to the `olist` database using a password prompt, `~/.my.cnf`, or the `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER` and `MYSQL_PASSWORD` environment variables.

## If something goes wrong

| Symptom | Fix |
|---|---|
| `Error 1046: No database selected` | Run `USE olist;` first, or double-click the `olist` schema in the left panel to make it the default |
| `Error 2013: Lost connection` while running step 3 | Set the timeout described in "Before you start", item 4 |
| `Error 1290: ... --secure-file-priv` | You used `LOAD DATA INFILE` without `LOCAL`; use the files as given, or `python python/load_mysql.py` |
| Counts don't match the table above | Re-run step 1, then step 2: the load script starts by dropping and recreating every table, so it is safe to repeat |
| Python asks for a password every time | Create `~/.my.cnf` with a `[client]` section (user, password, host), or set the `MYSQL_PASSWORD` environment variable for that terminal session |
