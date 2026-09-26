-- WEEK 2: TOPIC 1 — Common Table Expressions (CTEs)

-- Description:
-- CTEs (WITH clauses) provide modular, readable step-by-step transformations.
-- This file demonstrates multi-step pipelines, reusing CTEs across multiple joins,
-- and controlling the PostgreSQL 12+ optimizer with MATERIALIZED / NOT MATERIALIZED.

-- ----------------------------------------------------------------------------
-- PROBLEM 1: Multi-Step Modular Revenue Pipeline
-- Task: Find customers who are in the top 10% by total lifetime spending,
--       and for each, compute their preferred payment method and average order value.
-- ----------------------------------------------------------------------------

WITH
    customer_spend_summary AS (
        -- Step 1: Calculate aggregate spending per customer
        SELECT
            o.customer_id,
            COUNT(o.order_id) AS total_orders,
            SUM(o.total_amount) AS lifetime_spend,
            AVG(o.total_amount) AS avg_order_value
        FROM orders.orders o
        WHERE
            o.order_status IN ('delivered', 'shipped')
        GROUP BY
            o.customer_id
    ),
    customer_percentiles AS (
        -- Step 2: Rank customers into percentiles
        SELECT
            customer_id,
            total_orders,
            lifetime_spend,
            avg_order_value,
            NTILE(10) OVER (
                ORDER BY lifetime_spend DESC
            ) AS spend_decile
        FROM customer_spend_summary
    ),
    customer_fav_payment AS (
        -- Step 3: Find each customer's most frequently used payment method
        SELECT o.customer_id, p.payment_method, ROW_NUMBER() OVER (
                PARTITION BY
                    o.customer_id
                ORDER BY COUNT(*) DESC
            ) AS method_rank
        FROM orders.orders o
            JOIN orders.payments p ON o.order_id = p.order_id
        WHERE
            p.payment_status = 'successful'
        GROUP BY
            o.customer_id,
            p.payment_method
    )
    -- Step 4: Final Join assembling the clean dimension
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    cp.lifetime_spend,
    ROUND(cp.avg_order_value, 2) AS avg_order_val,
    cp.total_orders,
    fp.payment_method AS preferred_payment_method
FROM
    customer_percentiles cp
    JOIN customer.customers c ON cp.customer_id = c.customer_id
    JOIN customer_fav_payment fp ON cp.customer_id = fp.customer_id
    AND fp.method_rank = 1
WHERE
    cp.spend_decile = 1 -- Top 10%
ORDER BY cp.lifetime_spend DESC;

-- ----------------------------------------------------------------------------
-- PROBLEM 2: PostgreSQL 12+ Optimizer Fence — MATERIALIZED vs NOT MATERIALIZED
-- Task: Contrast when to force materialization vs allow optimizer inlining.
-- ----------------------------------------------------------------------------

-- Scenario A: NOT MATERIALIZED (Default single-use inlining)
-- The planner pushes "order_timestamp >= '2026-01-01'" into the orders scan.
EXPLAIN
ANALYZE
WITH
    recent_orders AS NOT MATERIALIZED (
        SELECT
            order_id,
            customer_id,
            order_timestamp,
            total_amount
        FROM orders.orders
    )
SELECT customer_id, SUM(total_amount) AS recent_spend
FROM recent_orders
WHERE
    order_timestamp >= '2026-01-01 00:00:00+00'
GROUP BY
    customer_id;

-- Scenario B: MATERIALIZED (Caching an expensive result used multiple times)
-- Without MATERIALIZED, referencing a complex CTE twice may trigger two full evaluations.
EXPLAIN
ANALYZE
WITH
    product_stats AS MATERIALIZED (
        SELECT
            product_id,
            COUNT(order_item_id) AS units_sold,
            SUM(line_total) AS total_revenue
        FROM orders.order_items
        GROUP BY
            product_id
    ),
    overall_avg AS (
        SELECT AVG(total_revenue) AS threshold
        FROM product_stats
    )
SELECT p.product_name, ps.units_sold, ps.total_revenue, ps.total_revenue - oa.threshold AS diff_from_average
FROM
    product_stats ps
    CROSS JOIN overall_avg oa
    JOIN catalog.products p ON ps.product_id = p.product_id
WHERE
    ps.total_revenue > oa.threshold
ORDER BY ps.total_revenue DESC;