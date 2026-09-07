-- Cumulative Distribution of Order Processing Duration (Fulfillment SLA Analysis)
-- Business Scenario:
-- The warehouse operations team wants to analyze fulfillment speed (hours elapsed between order timestamp and shipment timestamp).
-- They need the cumulative distribution (CUME_DIST) to answer SLA questions like:
-- "What percentage of our orders are shipped within 24 hours? 48 hours?"

-- Tables to use:
-- orders.orders o
-- logistics.shipments s

-- Required Output Columns:
-- order_id
-- tracking_number
-- hours_to_ship (rounded to 2 decimal places)
-- cumulative_distribution (percentage proportion <= current row, rounded to 4 decimal places)

-- Solution 1: WITHOUT Window Functions (Correlated Count Subquery)

WITH
    shipment_durations AS (
        SELECT o.order_id, s.tracking_number, ROUND(
                EXTRACT(
                    EPOCH
                    FROM (
                            s.shipped_at - o.order_timestamp
                        )
                ) / 3600.0, 2
            ) AS hours_to_ship
        FROM orders.orders o
            JOIN logistics.shipments s ON o.order_id = s.order_id
        WHERE
            s.shipped_at IS NOT NULL
    ),
    total_count AS (
        SELECT COUNT(*) AS n
        FROM shipment_durations
    )
SELECT
    sd1.order_id,
    sd1.tracking_number,
    sd1.hours_to_ship,
    ROUND(
        (
            SELECT COUNT(*)
            FROM shipment_durations sd2
            WHERE
                sd2.hours_to_ship <= sd1.hours_to_ship
        )::numeric / tc.n::numeric,
        4
    ) AS cumulative_distribution
FROM
    shipment_durations sd1
    CROSS JOIN total_count tc
ORDER BY sd1.hours_to_ship ASC;

-- Solution 2: WITH Window Functions (CUME_DIST)

WITH
    shipment_durations AS (
        SELECT o.order_id, s.tracking_number, ROUND(
                EXTRACT(
                    EPOCH
                    FROM (
                            s.shipped_at - o.order_timestamp
                        )
                ) / 3600.0, 2
            ) AS hours_to_ship
        FROM orders.orders o
            JOIN logistics.shipments s ON o.order_id = s.order_id
        WHERE
            s.shipped_at IS NOT NULL
    )
SELECT
    order_id,
    tracking_number,
    hours_to_ship,
    ROUND(
        CUME_DIST() OVER (
            ORDER BY hours_to_ship ASC
        )::numeric,
        4
    ) AS cumulative_distribution
FROM shipment_durations
ORDER BY hours_to_ship ASC;

-- Explanation: How CUME_DIST() Works

-- 1. CUME_DIST() calculates the cumulative distribution (relative position) of a value in a group.
-- 2. Official PostgreSQL Formula:
--       CUME_DIST = (Count of rows with value <= Current row value) / (Total rows in partition)
-- 3. Output range: strictly > 0.0 and <= 1.0.
-- 4. Difference between PERCENT_RANK() and CUME_DIST():
--    - PERCENT_RANK() is based on (RANK - 1) / (N - 1) and starts at 0.0.
--    - CUME_DIST() represents the exact fraction of the dataset that is less than or equal to the current value.
--    - If CUME_DIST = 0.85 at 24.0 hours, it means 85% of all shipments took 24 hours or less!