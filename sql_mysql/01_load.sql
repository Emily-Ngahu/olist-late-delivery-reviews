-- Create the olist database and tables, then load the slimmed CSVs.

SET GLOBAL local_infile = 1;

CREATE DATABASE IF NOT EXISTS olist;
USE olist;

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS order_reviews;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS sellers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS category_names;
DROP TABLE IF EXISTS zip_centroids;

CREATE TABLE orders (
    order_id                       CHAR(32) PRIMARY KEY,
    customer_id                    CHAR(32) NOT NULL,
    order_status                   VARCHAR(20) NOT NULL,
    order_purchase_timestamp       DATETIME NOT NULL,
    order_delivered_customer_date  DATETIME NULL,
    order_estimated_delivery_date  DATETIME NULL
);
CREATE TABLE order_items (
    order_id        CHAR(32) NOT NULL,
    order_item_id   INT NOT NULL,
    product_id      CHAR(32) NOT NULL,
    seller_id       CHAR(32) NOT NULL,
    price           DECIMAL(10,2) NOT NULL,
    freight_value   DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);
CREATE TABLE order_reviews (
    review_id     CHAR(32) NOT NULL,
    order_id      CHAR(32) NOT NULL,
    review_score  TINYINT NOT NULL,
    INDEX idx_reviews_order (order_id)
);
CREATE TABLE customers (
    customer_id               CHAR(32) PRIMARY KEY,
    customer_zip_code_prefix  INT NOT NULL,
    customer_state            CHAR(2) NOT NULL
);
CREATE TABLE sellers (
    seller_id               CHAR(32) PRIMARY KEY,
    seller_zip_code_prefix  INT NOT NULL,
    seller_state            CHAR(2) NOT NULL
);
CREATE TABLE products (
    product_id             CHAR(32) PRIMARY KEY,
    product_category_name  VARCHAR(80) NULL
);
CREATE TABLE category_names (
    product_category_name          VARCHAR(80) PRIMARY KEY,
    product_category_name_english  VARCHAR(80) NOT NULL
);
CREATE TABLE zip_centroids (
    zip_prefix  INT PRIMARY KEY,
    lat         DOUBLE NOT NULL,
    lng         DOUBLE NOT NULL
);

LOAD DATA LOCAL INFILE 'DATA_DIR/orders.csv' INTO TABLE orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, customer_id, order_status, order_purchase_timestamp, @delivered, @estimated)
SET order_delivered_customer_date = NULLIF(@delivered, ''),
    order_estimated_delivery_date = NULLIF(@estimated, '');

LOAD DATA LOCAL INFILE 'DATA_DIR/order_items.csv' INTO TABLE order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, order_item_id, product_id, seller_id, price, freight_value);

LOAD DATA LOCAL INFILE 'DATA_DIR/order_reviews.csv' INTO TABLE order_reviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(review_id, order_id, review_score);

LOAD DATA LOCAL INFILE 'DATA_DIR/customers.csv' INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(customer_id, customer_zip_code_prefix, customer_state);

LOAD DATA LOCAL INFILE 'DATA_DIR/sellers.csv' INTO TABLE sellers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(seller_id, seller_zip_code_prefix, seller_state);

LOAD DATA LOCAL INFILE 'DATA_DIR/products.csv' INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(product_id, @category)
SET product_category_name = NULLIF(@category, '');

LOAD DATA LOCAL INFILE 'DATA_DIR/category_names.csv' INTO TABLE category_names
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(product_category_name, product_category_name_english);

LOAD DATA LOCAL INFILE 'DATA_DIR/zip_centroids.csv' INTO TABLE zip_centroids
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(zip_prefix, lat, lng);

-- Row counts to check the load (expected: 99441, 112650, 99224, 99441, 3095, 32951, 71, 19015)
SELECT 'orders' AS tbl, COUNT(*) AS n FROM orders
UNION ALL SELECT 'order_items',   COUNT(*) FROM order_items
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'customers',     COUNT(*) FROM customers
UNION ALL SELECT 'sellers',       COUNT(*) FROM sellers
UNION ALL SELECT 'products',      COUNT(*) FROM products
UNION ALL SELECT 'category_names', COUNT(*) FROM category_names
UNION ALL SELECT 'zip_centroids', COUNT(*) FROM zip_centroids;
