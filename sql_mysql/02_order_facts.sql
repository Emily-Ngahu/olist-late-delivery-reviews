-- One clean row per delivered, single-seller order, with delay, review score,
--     route (seller state -> customer state) and distance. Everything else builds on this.

USE olist;

DROP TABLE IF EXISTS order_facts;

CREATE TABLE order_facts AS
WITH single_seller AS (
    SELECT order_id,
           MIN(seller_id)       AS seller_id,
           COUNT(*)             AS n_items,
           SUM(price)           AS item_value,
           SUM(freight_value)   AS freight_value
    FROM order_items
    GROUP BY order_id
    HAVING COUNT(DISTINCT seller_id) = 1
),
main_item AS (                       -- the most expensive item decides the order's category
    SELECT order_id, product_id AS main_product_id
    FROM (SELECT order_id, product_id,
                 ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY price DESC, order_item_id) AS rn
          FROM order_items) ranked_items
    WHERE rn = 1
),
review_per_order AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
)
SELECT o.order_id,
       DATE(o.order_purchase_timestamp)                                       AS purchase_date,
       CAST(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS DATE)      AS purchase_month,
       c.customer_state,
       sl.seller_id,
       sl.seller_state,
       CONCAT(sl.seller_state, ' -> ', c.customer_state)                      AS route,
       COALESCE(cn.product_category_name_english, p.product_category_name, 'unknown') AS category,
       ss.n_items,
       ss.item_value,
       ss.freight_value,
       CAST(ss.freight_value AS DOUBLE) / NULLIF(ss.item_value, 0)            AS freight_ratio,
       DATEDIFF(DATE(o.order_delivered_customer_date),
                DATE(o.order_estimated_delivery_date))                        AS days_vs_estimate,
       DATEDIFF(DATE(o.order_delivered_customer_date),
                DATE(o.order_purchase_timestamp))                             AS days_to_deliver,
       DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date) AS is_late,
       r.review_score,
       r.review_score <= 2                                                    AS is_bad_review,
       2 * 6371 * ASIN(SQRT(
           POW(SIN(RADIANS(cz.lat - sz.lat) / 2), 2)
         + COS(RADIANS(sz.lat)) * COS(RADIANS(cz.lat))
           * POW(SIN(RADIANS(cz.lng - sz.lng) / 2), 2)))                      AS distance_km
FROM orders o
JOIN single_seller ss        ON ss.order_id = o.order_id
JOIN customers c             ON c.customer_id = o.customer_id
JOIN sellers sl              ON sl.seller_id = ss.seller_id
JOIN review_per_order r      ON r.order_id = o.order_id
LEFT JOIN main_item mi       ON mi.order_id = o.order_id
LEFT JOIN products p         ON p.product_id = mi.main_product_id
LEFT JOIN category_names cn  ON cn.product_category_name = p.product_category_name
LEFT JOIN zip_centroids cz   ON cz.zip_prefix = c.customer_zip_code_prefix
LEFT JOIN zip_centroids sz   ON sz.zip_prefix = sl.seller_zip_code_prefix
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;

-- Sanity checks: row count, one row per order, nothing silly in the key columns
-- (expected: 94563 orders, 6.7% late, average score 4.17, 12.3% bad reviews)
SELECT COUNT(*)                         AS orders_in_facts,
       COUNT(DISTINCT order_id)         AS distinct_orders,
       ROUND(100.0 * SUM(is_late) / COUNT(*), 1)     AS pct_late,
       ROUND(AVG(review_score), 2)      AS avg_score,
       ROUND(100.0 * SUM(is_bad_review) / COUNT(*), 1) AS pct_bad_reviews
FROM order_facts;
