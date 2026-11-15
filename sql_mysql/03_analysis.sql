USE olist;

-- Q1. Headline: do late orders get worse reviews?
SELECT is_late,
       COUNT(*)                                  AS orders,
       ROUND(AVG(review_score), 2)               AS avg_score,
       ROUND(100.0 * SUM(is_bad_review) / COUNT(*), 1)        AS pct_bad_reviews
FROM order_facts
GROUP BY is_late
ORDER BY is_late;

-- Q2. How bad does it get as the delay grows?
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

-- Q3. What share of all bad reviews comes from late deliveries?
SELECT SUM(is_bad_review)                                                   AS bad_reviews,
       SUM(is_bad_review AND is_late)                                       AS bad_and_late,
       ROUND(100.0 * SUM(is_bad_review AND is_late)
                   / NULLIF(SUM(is_bad_review), 0), 1)                      AS pct_of_bad_reviews_that_were_late,
       ROUND(100.0 * SUM(is_late) / COUNT(*), 1)                                       AS pct_of_all_orders_late
FROM order_facts;

-- Q4. Which routes (seller state -> customer state) are the problem?
--     Only routes with enough orders to trust (100+).
SELECT route,
       COUNT(*)                                  AS orders,
       ROUND(100.0 * SUM(is_late) / COUNT(*), 1)              AS pct_late,
       ROUND(AVG(days_to_deliver), 1)            AS avg_days_to_deliver,
       ROUND(AVG(review_score), 2)               AS avg_score,
       SUM(is_late AND is_bad_review)            AS late_bad_reviews,
       RANK() OVER (ORDER BY SUM(is_late AND is_bad_review) DESC) AS rank_by_late_bad_reviews
FROM order_facts
GROUP BY route
HAVING COUNT(*) >= 100
ORDER BY late_bad_reviews DESC
LIMIT 15;

-- Q5. Monthly trend with a 3-month rolling average (window function).
WITH monthly AS (
    SELECT purchase_month,
           COUNT(*)                               AS orders,
           100.0 * SUM(is_late) / COUNT(*)                     AS pct_late,
           AVG(review_score)                      AS avg_score
    FROM order_facts
    GROUP BY purchase_month
    HAVING COUNT(*) >= 200
)
SELECT purchase_month,
       orders,
       ROUND(pct_late, 1)                                                          AS pct_late,
       ROUND(AVG(pct_late) OVER (ORDER BY purchase_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS pct_late_3m_avg,
       ROUND(avg_score, 2)                                                         AS avg_score
FROM monthly
ORDER BY purchase_month;

-- Q6. Seller scorecard: do a few sellers cause most of the late-delivery bad reviews? (Pareto)
WITH seller_stats AS (
    SELECT seller_id,
           seller_state,
           COUNT(*)                               AS orders,
           ROUND(100.0 * SUM(is_late) / COUNT(*), 1)           AS pct_late,
           SUM(is_late AND is_bad_review)         AS late_bad_reviews
    FROM order_facts
    GROUP BY seller_id, seller_state
    HAVING COUNT(*) >= 30
),
ranked AS (
    SELECT *,
           SUM(late_bad_reviews) OVER (ORDER BY late_bad_reviews DESC, seller_id
                                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
           SUM(late_bad_reviews) OVER ()                                                 AS grand_total,
           ROW_NUMBER() OVER (ORDER BY late_bad_reviews DESC, seller_id)                 AS seller_rank,
           COUNT(*) OVER ()                                                              AS n_sellers
    FROM seller_stats
)
SELECT seller_rank,
       seller_id,
       seller_state,
       orders,
       pct_late,
       late_bad_reviews,
       ROUND(100.0 * running_total / NULLIF(grand_total, 0), 1) AS cumulative_pct_of_late_bad_reviews,
       ROUND(100.0 * seller_rank / n_sellers, 1)                AS pct_of_sellers_so_far
FROM ranked
ORDER BY seller_rank
LIMIT 25;
