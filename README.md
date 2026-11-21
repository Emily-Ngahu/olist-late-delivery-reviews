# Why do marketplace customers leave bad reviews?

**[View the live dashboard](https://datastudio.google.com/reporting/ce8ecbfe-ef2d-4d99-a470-be971c6401d8)** · [PDF copy of the report](Report/Olist_Report.pdf)

> **Finding in one sentence:** late deliveries are only **6.7%** of Olist orders but account for **34%** of all bad reviews, and the damage escalates quickly with delay. Even so, **two thirds of bad reviews come from orders that arrived on time**, so delivery is a big part of the problem, not all of it.

## The problem
A marketplace's review scores are falling and the founders suspect poor sellers. Before money goes on seller-quality programmes, three questions need answers:

1. How much of the bad-review problem is simply **late delivery**?
2. **Where** does it happen: which routes, states, categories and sellers?
3. If delivery were fixed, **how many bad reviews would disappear**?

## Data
[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle): about 100,000 orders from 2016 to 2018 across 9 linked tables. Licence **CC BY-NC-SA 4.0** (non-commercial, with credit). The data is **not included** in this repository: download it from Kaggle and place the CSVs in `data/`.

A "bad review" is a score of 1 or 2. An order is "late" if it was delivered after the date promised to the customer.

## Approach
1. **SQL** builds one clean row per order (`order_facts`): delivered orders with a single seller and a review, with days late, route, product category and seller-to-customer distance. 94,563 of 99,441 orders qualify. Six queries then answer the questions above using CTEs, window functions (`RANK`, rolling averages, running totals) and conditional aggregation.
2. **Python (statsmodels)** fits a logistic regression for bad reviews with delay band, distance, freight ratio, price, category and customer state, and estimates how many bad reviews on-time delivery would have avoided.
3. **A [Data Studio dashboard](https://datastudio.google.com/reporting/ce8ecbfe-ef2d-4d99-a470-be971c6401d8)** is built from the summary tables in `dashboard/`.

All SQL is written for **MySQL 8.0** (`sql_mysql/`).

## Key findings
| | |
|---|---|
| Late orders | **6.7%** of orders, but **34.1%** of bad reviews (3,970 of 11,640) |
| Bad-review rate | **8.7%** on time, then **32.1%** (1-3 days late), **67.5%** (4-7 days), **79.2%** (8+ days) |
| After controls (distance, price, category, state) | odds of a bad review are about **5×**, **21×** and **39×** those of an on-time order for the three late bands |
| If every order had arrived on time | about **3,364** of 11,587 bad reviews (**29%**) would have been avoided |
| Worst route | **SP → RJ**: 838 late bad reviews, with 14.1% of its orders late |
| When | late rates peak in **Nov 2017** (12.4%) and **Feb-Mar 2018** (14.1% and 18.9%) |
| Where | the north-eastern states (AL, MA, SE, PI, CE) have 14-21% late orders |
| Sellers | the 25 worst sellers (about 4%) cause a third of late bad reviews: concentrated, but not an 80/20 pattern |

## Recommendations
- Fix delivery on the worst routes first (SP → RJ and the north-eastern states) and plan capacity for the November and February-March peaks.
- Treat delivery as roughly a third of the review problem. Investigate the two thirds of bad reviews on on-time orders (product and seller quality) separately; the review comments are a starting point.
- Report bad reviews by delivery status and route, not as a single average score.

## Limitations
- The regression shows association, not proof of cause. Late orders may also differ in ways not measured (for example fragile or bulky items).
- Reviews are self-selected: unhappy customers are more likely to write one.
- Orders that were cancelled, undelivered or shipped by several sellers (about 5% of orders) are excluded, and 469 orders without coordinates are left out of the regression only.
- "Late" is measured against the promised date, so an unrealistic promise counts as lateness even if the seller shipped quickly.
- One country, 2016-2018: patterns may not hold today.

## Repository
```
sql_mysql/      MySQL 8.0: load, order_facts, analysis, export, plus README_MYSQL.md (Workbench guide)
python/         data prep, MySQL loader and exporter, regression (analysis.py)
dashboard/      summary tables that feed the dashboard
Report/         PDF copy of the Data Studio dashboard
```

## How to reproduce
```bash
pip install -r requirements.txt
# download the 9 Olist CSVs from Kaggle into ./data
```
You need a running MySQL 8.0 server (details and troubleshooting in [`sql_mysql/README_MYSQL.md`](sql_mysql/README_MYSQL.md)):
```bash
python python/prepare_mysql_data.py
python python/load_mysql.py          # or run sql_mysql/01_load_local.sql in MySQL Workbench
# run sql_mysql/02_order_facts.sql and 03_analysis.sql in Workbench
python python/export_dashboard.py
python python/analysis.py
```

## Credits
Data: Olist, published on Kaggle (CC BY-NC-SA 4.0).
