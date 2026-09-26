-- WEEK 2: TOPIC 6 — Conditional Aggregation

-- Description:
-- Conditional aggregation computes granular subset metrics in a single pass
-- across data, eliminating redundant self-joins and enabling dynamic pivoting.

-- ----------------------------------------------------------------------------
-- PROBLEM 1: Single-Pass Multi-Metric Executive KPI Dashboard
-- Task: For each country, calculate in a single scan:
--       - Total orders
--       - Gross revenue (all orders)
--       - Net delivered revenue
--       - Cancelled order rate (%)
--       - Refunded order count
-- ----------------------------------------------------------------------------

-- Standard SQL CASE WHEN Approach
SELECT
    c.country,
    COUNT(o.order_id) AS total_orders,
    SUM(o.total_amount) AS gross_revenue,
    SUM(
        CASE
            WHEN o.order_status = 'delivered' THEN o.total_amount
            ELSE 0
        END
    ) AS net_delivered_revenue,
    ROUND(
        100.0 * COUNT(
            CASE
                WHEN o.order_status = 'cancelled' THEN 1
            END
        ) / COUNT(o.order_id),
        2
    ) AS cancellation_rate_pct,
    COUNT(
        CASE
            WHEN o.order_status = 'refunded' THEN 1
        END
    ) AS refunded_orders_count
FROM customer.customers c
    JOIN orders.orders o ON c.customer_id = o.customer_id
GROUP BY
    c.country
ORDER BY net_delivered_revenue DESC;

-- ----------------------------------------------------------------------------
-- PROBLEM 2: Modern PostgreSQL FILTER (WHERE ...) Clause
-- Task: Re-implement the previous KPI logic using PostgreSQL's clean FILTER clause.
-- ----------------------------------------------------------------------------

SELECT
    c.country,
    COUNT(o.order_id) AS total_orders,
    SUM(o.total_amount) AS gross_revenue,
    SUM(o.total_amount) FILTER (
        WHERE
            o.order_status = 'delivered'
    ) AS net_delivered_revenue,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE
                o.order_status = 'cancelled'
        ) / COUNT(o.order_id),
        2
    ) AS cancellation_rate_pct,
    COUNT(*) FILTER (
        WHERE
            o.order_status = 'refunded'
    ) AS refunded_orders_count
FROM customer.customers c
    JOIN orders.orders o ON c.customer_id = o.customer_id
GROUP BY
    c.country
ORDER BY net_delivered_revenue DESC;

-- ----------------------------------------------------------------------------
-- PROBLEM 3: Matrix Pivoting (Rows to Columns)
-- Task: Build a financial summary showing monthly sales broken down by payment method
--       as columns (credit_card, upi, debit_card, net_banking, wallet).
-- ----------------------------------------------------------------------------

SELECT
    TO_CHAR(o.order_timestamp, 'YYYY-MM') AS sales_month,
    COUNT(o.order_id) AS total_transactions,
    ROUND(
        COALESCE(
            SUM(p.amount) FILTER (
                WHERE
                    p.payment_method = 'credit_card'
            ),
            0
        ),
        2
    ) AS credit_card_amount,
    ROUND(
        COALESCE(
            SUM(p.amount) FILTER (
                WHERE
                    p.payment_method = 'upi'
            ),
            0
        ),
        2
    ) AS upi_amount,
    ROUND(
        COALESCE(
            SUM(p.amount) FILTER (
                WHERE
                    p.payment_method = 'debit_card'
            ),
            0
        ),
        2
    ) AS debit_card_amount,
    ROUND(
        COALESCE(
            SUM(p.amount) FILTER (
                WHERE
                    p.payment_method = 'net_banking'
            ),
            0
        ),
        2
    ) AS net_banking_amount,
    ROUND(
        COALESCE(
            SUM(p.amount) FILTER (
                WHERE
                    p.payment_method = 'wallet'
            ),
            0
        ),
        2
    ) AS wallet_amount
FROM orders.orders o
    JOIN orders.payments p ON o.order_id = p.order_id
WHERE
    p.payment_status = 'successful'
GROUP BY
    TO_CHAR(o.order_timestamp, 'YYYY-MM')
ORDER BY sales_month;