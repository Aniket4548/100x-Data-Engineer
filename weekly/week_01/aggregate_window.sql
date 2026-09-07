-- Cumulative Running Total, Rolling Average & Percentage of Lifetime Spend
-- Business Scenario:
-- The financial analytics team wants an order audit for every customer.
-- For every order, display:
-- 1. Order ID, Customer ID, Order Timestamp, and Order Amount.
-- 2. The customer's cumulative running total revenue up to that order.
-- 3. The customer's rolling 3-order moving average amount.
-- 4. The customer's total lifetime spend.
-- 5. The percentage contribution of this single order towards their total lifetime spend.

-- Tables to use:
-- orders.orders

-- Required Output Columns:
-- customer_id
-- order_id
-- order_timestamp
-- total_amount
-- running_total_spend
-- rolling_3_order_avg
-- lifetime_total_spend
-- pct_of_lifetime_spend (rounded to 2 decimal places)

-- Solution 1: WITHOUT Window Functions (Correlated Subqueries & CTEs)

WITH
    customer_lifetime AS (
        SELECT
            customer_id,
            SUM(total_amount) AS lifetime_total_spend
        FROM orders.orders
        GROUP BY
            customer_id
    )
SELECT
    o1.customer_id,
    o1.order_id,
    o1.order_timestamp,
    o1.total_amount,
    -- Running total via correlated subquery:
    (
        SELECT SUM(o2.total_amount)
        FROM orders.orders o2
        WHERE
            o2.customer_id = o1.customer_id
            AND (
                o2.order_timestamp < o1.order_timestamp
                OR (
                    o2.order_timestamp = o1.order_timestamp
                    AND o2.order_id <= o1.order_id
                )
            )
    ) AS running_total_spend,
    -- Rolling 3-order average via subquery:
    (
        SELECT ROUND(AVG(sub.total_amount), 2)
        FROM (
                SELECT o3.total_amount
                FROM orders.orders o3
                WHERE
                    o3.customer_id = o1.customer_id
                    AND o3.order_timestamp <= o1.order_timestamp
                ORDER BY o3.order_timestamp DESC
                LIMIT 3
            ) sub
    ) AS rolling_3_order_avg,
    cl.lifetime_total_spend,
    ROUND(
        (
            o1.total_amount / cl.lifetime_total_spend
        ) * 100.0,
        2
    ) AS pct_of_lifetime_spend
FROM orders.orders o1
    JOIN customer_lifetime cl ON o1.customer_id = cl.customer_id
ORDER BY o1.customer_id, o1.order_timestamp ASC;

-- Solution 2: WITH Window Functions (SUM, AVG with OVER, PARTITION & Frames)

SELECT
    customer_id,
    order_id,
    order_timestamp,
    total_amount,
    -- 1. Running Total: From start of partition up to current row
    SUM(total_amount) OVER (
        PARTITION BY
            customer_id
        ORDER BY order_timestamp ASC ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
    ) AS running_total_spend,
    -- 2. Rolling 3-Order Moving Average: Current row + 2 prior rows
    ROUND(
        AVG(total_amount) OVER (
            PARTITION BY
                customer_id
            ORDER BY order_timestamp ASC ROWS BETWEEN 2 PRECEDING
                AND CURRENT ROW
        ),
        2
    ) AS rolling_3_order_avg,
    -- 3. Lifetime Spend: Whole partition total (no ORDER BY clause)
    SUM(total_amount) OVER (
        PARTITION BY
            customer_id
    ) AS lifetime_total_spend,
    -- 4. Percentage of Lifetime Spend
    ROUND(
        (
            total_amount / SUM(total_amount) OVER (
                PARTITION BY
                    customer_id
            )
        ) * 100.0,
        2
    ) AS pct_of_lifetime_spend
FROM orders.orders
ORDER BY customer_id, order_timestamp ASC;

-- Explanation: How Ordinary Aggregates Function as Window Functions
-- 1. Any regular SQL aggregate (SUM, AVG, COUNT, MIN, MAX) turns into a window function when followed by OVER().
-- 2. Aggregate OVER (PARTITION BY col):
--    - Without ORDER BY, the window is the ENTIRE partition.
--    - It broadcasts the overall group sum/average to EVERY individual row without collapsing rows (e.g. lifetime_total_spend).
-- 3. Aggregate OVER (PARTITION BY col ORDER BY col):
--    - Adding ORDER BY introduces a running/cumulative sliding frame (default: UNBOUNDED PRECEDING to CURRENT ROW).
-- 4. Precision Window Framing:
--    - `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` creates a precise 3-row moving calculation window (ideal for moving averages and smoothing volatility).