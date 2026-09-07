-- Month-over-Month (MoM) Revenue Growth & Variance
-- Business Scenario:
-- The finance team needs to track monthly company revenue alongside the previous month's revenue and the MoM dollar growth.
-- Include only confirmed/completed orders (exclude cancelled and refunded orders).

-- Tables to use:
-- orders.orders

-- Required Output Columns:
-- order_month (format YYYY-MM)
-- current_month_revenue
-- prev_month_revenue (default to 0 for the first month)
-- mom_growth_amount
-- mom_growth_percentage (rounded to 2 decimal places)

-- Solution 1: WITHOUT Window Functions (Self-Join on Date Intervals)

WITH
    monthly_revenue AS (
        SELECT
            DATE_TRUNC('month', order_timestamp)::date AS month_date,
            TO_CHAR(order_timestamp, 'YYYY-MM') AS order_month,
            SUM(total_amount) AS current_month_revenue
        FROM orders.orders
        WHERE
            order_status NOT IN ('cancelled', 'refunded')
        GROUP BY
            DATE_TRUNC('month', order_timestamp)::date,
            TO_CHAR(order_timestamp, 'YYYY-MM')
    )
SELECT
    curr.order_month,
    curr.current_month_revenue,
    COALESCE(
        prev.current_month_revenue,
        0.00
    ) AS prev_month_revenue,
    curr.current_month_revenue - COALESCE(
        prev.current_month_revenue,
        0.00
    ) AS mom_growth_amount,
    CASE
        WHEN prev.current_month_revenue IS NULL
        OR prev.current_month_revenue = 0 THEN NULL
        ELSE ROUND(
            (
                (
                    curr.current_month_revenue - prev.current_month_revenue
                ) / prev.current_month_revenue
            ) * 100.0,
            2
        )
    END AS mom_growth_percentage
FROM
    monthly_revenue curr
    LEFT JOIN monthly_revenue prev ON prev.month_date = (
        curr.month_date - INTERVAL '1 month'
    )::date
ORDER BY curr.order_month ASC;

-- Solution 2: WITH Window Functions (LAG)

WITH
    monthly_revenue AS (
        SELECT
            TO_CHAR(order_timestamp, 'YYYY-MM') AS order_month,
            SUM(total_amount) AS current_month_revenue
        FROM orders.orders
        WHERE
            order_status NOT IN ('cancelled', 'refunded')
        GROUP BY
            TO_CHAR(order_timestamp, 'YYYY-MM')
    ),
    revenue_with_lag AS (
        SELECT
            order_month,
            current_month_revenue,
            LAG(
                current_month_revenue,
                1,
                0.00
            ) OVER (
                ORDER BY order_month ASC
            ) AS prev_month_revenue
        FROM monthly_revenue
    )
SELECT
    order_month,
    current_month_revenue,
    prev_month_revenue,
    current_month_revenue - prev_month_revenue AS mom_growth_amount,
    CASE
        WHEN prev_month_revenue = 0 THEN NULL
        ELSE ROUND(
            (
                (
                    current_month_revenue - prev_month_revenue
                ) / prev_month_revenue
            ) * 100.0,
            2
        )
    END AS mom_growth_percentage
FROM revenue_with_lag
ORDER BY order_month ASC;

-- Explanation: How LAG() Works

-- 1. LAG(column, offset, default_value) accesses a column value from a row `offset` steps prior within the partition.
-- 2. Parameters:
--    - column: the field to fetch (e.g. current_month_revenue).
--    - offset (optional, default = 1): how many rows backwards to look.
--    - default_value (optional, default = NULL): what to return if there is no previous row (e.g., for row 1).
-- 3. Why LAG() is better than a Self-Join:
--    - Self-joins fail if there are missing months in the dataset (e.g., jumping from March to May).
--    - LAG() operates on the sequential logical order of rows without requiring exact calendar date arithmetic.
--    - LAG() requires only 1 table scan vs 2 table scans for self-joins.