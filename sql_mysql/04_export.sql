-- 04 (MySQL 8.0)  Summary tables for the dashboard.
--
-- Workbench can't export these results in some versions, so the easy way is to run
--     python python/export_dashboard.py
-- which runs every query below and saves it as a CSV in ./dashboard.
-- Each "-- file:" line says which CSV the query below it is saved as.

USE olist;

-- file: by_delay_band.csv
SELECT CASE WHEN days_vs_estimate <= 0 THEN '1. On time or early'
            WHEN days_vs_estimate <= 3 THEN '2. 1-3 days late'
            WHEN days_vs_estimate <= 7 THEN '3. 4-7 days late'
            ELSE                            '4. 8+ days late' END AS delay_band,
       COUNT(*)                                  AS orders,
       ROUND(AVG(review_score), 2)               AS avg_score,
       ROUND(100.0 * SUM(is_bad_review) / COUNT(*), 1)        AS pct_bad_reviews
FROM order_facts
GROUP BY delay_band
ORDER BY delay_band;

-- file: monthly_trend.csv
SELECT purchase_month,
       COUNT(*)                                  AS orders,
       ROUND(100.0 * SUM(is_late) / COUNT(*), 1)              AS pct_late,
       ROUND(AVG(review_score), 2)               AS avg_score
FROM order_facts
GROUP BY purchase_month
HAVING COUNT(*) >= 200
ORDER BY purchase_month;

-- file: route_summary.csv
SELECT seller_state,
       customer_state,
       route,
       COUNT(*)                                  AS orders,
       ROUND(100.0 * SUM(is_late) / COUNT(*), 1)              AS pct_late,
       ROUND(AVG(review_score), 2)               AS avg_score,
       SUM(is_late AND is_bad_review)            AS late_bad_reviews
FROM order_facts
GROUP BY seller_state, customer_state, route
HAVING COUNT(*) >= 100
ORDER BY late_bad_reviews DESC, route;

-- file: customer_state_summary.csv
SELECT customer_state,
       COUNT(*)                                  AS orders,
       ROUND(100.0 * SUM(is_late) / COUNT(*), 1)              AS pct_late,
       ROUND(AVG(days_to_deliver), 1)            AS avg_days_to_deliver,
       ROUND(AVG(review_score), 2)               AS avg_score
FROM order_facts
GROUP BY customer_state
ORDER BY pct_late DESC, customer_state;

-- file: category_summary.csv
SELECT category,
       COUNT(*)                                  AS orders,
       ROUND(100.0 * SUM(is_late) / COUNT(*), 1)              AS pct_late,
       ROUND(AVG(review_score), 2)               AS avg_score
FROM order_facts
GROUP BY category
HAVING COUNT(*) >= 200
ORDER BY orders DESC, category;

-- file: seller_scorecard.csv
SELECT seller_id,
       seller_state,
       COUNT(*)                                  AS orders,
       ROUND(100.0 * SUM(is_late) / COUNT(*), 1)              AS pct_late,
       SUM(is_late AND is_bad_review)            AS late_bad_reviews
FROM order_facts
GROUP BY seller_id, seller_state
HAVING COUNT(*) >= 30
ORDER BY late_bad_reviews DESC, seller_id;
