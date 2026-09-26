-- Active: 1787306461498@@127.0.0.1@5432@100x

-- K 2: TOPIC 3 — Correlated Subqueries & Query Rewrites

-- Description:
-- A correlated subquery relies on values from the outer query row.
-- While intuitive, they can kill performance on large tables. This file demonstrates
-- how they work and how Data Engineers rewrite them to Window Functions or Joins.

-- ----------------------------------------------------------------------------
-- PROBLEM 1: Correlated Subquery in WHERE
-- Task: Find all products that cost more than the average cost of all products
--       in their SAME category.
-- ----------------------------------------------------------------------------

-- Approach 1: Correlated Subquery (Evaluated once per outer row)
SELECT p.product_id, p.product_name, p.category_id, p.cost_price
FROM catalog.products p
WHERE
    p.cost_price > (
        SELECT AVG(sub.cost_price)
        FROM catalog.products sub
        WHERE
            sub.category_id = p.category_id -- Correlation link!
    )
ORDER BY p.category_id, p.cost_price DESC;

-- Approach 2: High-Performance Rewrite using Window Functions
-- (Single pass through the products table with no nested loops!)
WITH
    products_with_cat_avg AS (
        SELECT
            product_id,
            product_name,
            category_id,
            cost_price,
            AVG(cost_price) OVER (
                PARTITION BY
                    category_id
            ) AS category_avg_cost
        FROM catalog.products
    )
SELECT
    product_id,
    product_name,
    category_id,
    cost_price,
    ROUND(category_avg_cost, 2) AS category_avg_cost
FROM products_with_cat_avg
WHERE
    cost_price > category_avg_cost
ORDER BY category_id, cost_price DESC;

-- ----------------------------------------------------------------------------
-- PROBLEM 2: Correlated Subquery in SELECT
-- Task: For each customer, retrieve their latest order total and timestamp.
-- ----------------------------------------------------------------------------

-- Approach 1: Correlated Subquery in SELECT (Antipattern on large tables)
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    (
        SELECT o.order_timestamp
        FROM orders.orders o
        WHERE
            o.customer_id = c.customer_id
        ORDER BY o.order_timestamp DESC
        LIMIT 1
    ) AS latest_order_time,
    (
        SELECT o.total_amount
        FROM orders.orders o
        WHERE
            o.customer_id = c.customer_id
        ORDER BY o.order_timestamp DESC
        LIMIT 1
    ) AS latest_order_amount
FROM customer.customers c;

-- Approach 2: Production DE Rewrite using CTE + Window Function / DISTINCT ON
-- (PostgreSQL DISTINCT ON or ROW_NUMBER is vastly faster!)
WITH
    latest_orders AS (
        SELECT DISTINCT
            ON (customer_id) customer_id,
            order_timestamp AS latest_order_time,
            total_amount AS latest_order_amount
        FROM orders.orders
        ORDER BY customer_id, order_timestamp DESC
    )
SELECT c.customer_id, c.first_name, c.last_name, lo.latest_order_time, lo.latest_order_amount
FROM customer.customers c
    LEFT JOIN latest_orders lo ON c.customer_id = lo.customer_id;