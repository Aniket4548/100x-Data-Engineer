-- Relative Percentile Ranking of Customers by Total Spending
-- Business Scenario:
-- The VIP customer team wants to assign a percentile score (0.0 to 1.0) to each customer based on their total spending.
-- Customers in the highest percentile (close to 1.0) qualify for exclusive rewards and premium support tiers.

-- Tables to use:
-- orders.orders

-- Required Output Columns:
-- customer_id
-- total_spend
-- percentile_rank (scaled 0.0 to 1.0, rounded to 4 decimals)

-- Solution 1: WITHOUT Window Functions (Subquery with Aggregate Counts)

WITH
    customer_spending AS (
        SELECT customer_id, SUM(total_amount) AS total_spend
        FROM orders.orders
        WHERE
            order_status NOT IN ('cancelled', 'refunded')
        GROUP BY
            customer_id
    ),
    customer_ranks AS (
        SELECT c1.customer_id, c1.total_spend,
            -- Rank formula without window function:
            1 + (
                SELECT COUNT(*)
                FROM customer_spending c2
                WHERE
                    c2.total_spend < c1.total_spend
            ) AS rnk, (
                SELECT COUNT(*)
                FROM customer_spending
            ) AS total_rows
        FROM customer_spending c1
    )
SELECT
    customer_id,
    total_spend,
    CASE
        WHEN total_rows = 1 THEN 0.0
        ELSE ROUND(
            (
                (rnk - 1)::numeric / (total_rows - 1)::numeric
            ),
            4
        )
    END AS percentile_rank
FROM customer_ranks
ORDER BY percentile_rank DESC;

-- Solution 2: WITH Window Functions (PERCENT_RANK)

WITH
    customer_spending AS (
        SELECT customer_id, SUM(total_amount) AS total_spend
        FROM orders.orders
        WHERE
            order_status NOT IN ('cancelled', 'refunded')
        GROUP BY
            customer_id
    )
SELECT
    customer_id,
    total_spend,
    ROUND(
        PERCENT_RANK() OVER (
            ORDER BY total_spend ASC
        )::numeric,
        4
    ) AS percentile_rank
FROM customer_spending
ORDER BY percentile_rank DESC;

-- Explanation: How PERCENT_RANK() Works

-- 1. PERCENT_RANK() calculates the relative rank of a row within a partition on a scale from 0.0 to 1.0.
-- 2. Official PostgreSQL Formula:
--       PERCENT_RANK = (RANK - 1) / (Total Rows in Partition - 1)
-- 3. Boundary values:
--    - The very first (lowest) row is ALWAYS 0.0.
--    - The very last (highest) row is ALWAYS 1.0.
-- 4. If a partition has only 1 row, PERCENT_RANK() returns 0.0.
-- 5. Notice ORDER BY total_spend ASC: The lowest spender gets 0.0, and the highest spender gets 1.0.