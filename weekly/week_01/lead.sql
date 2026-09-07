-- Shipment Transit Funnel & Status Transition Durations
-- Business Scenario:
-- The logistics team wants to track delivery event sequences for each shipment.
-- For every delivery event, find the NEXT event type and the NEXT event timestamp to measure how long the package stayed in each state before progressing.

-- Tables to use:
-- logistics.delivery_events

-- Required Output Columns:
-- shipment_id
-- event_type AS current_status
-- event_timestamp AS status_started_at
-- next_status
-- next_status_at
-- duration_minutes_in_status

-- Solution 1: WITHOUT Window Functions (Correlated Subquery)

SELECT
    e1.shipment_id,
    e1.event_type AS current_status,
    e1.event_timestamp AS status_started_at,
    (
        SELECT e2.event_type
        FROM logistics.delivery_events e2
        WHERE
            e2.shipment_id = e1.shipment_id
            AND e2.event_timestamp > e1.event_timestamp
        ORDER BY e2.event_timestamp ASC
        LIMIT 1
    ) AS next_status,
    (
        SELECT e2.event_timestamp
        FROM logistics.delivery_events e2
        WHERE
            e2.shipment_id = e1.shipment_id
            AND e2.event_timestamp > e1.event_timestamp
        ORDER BY e2.event_timestamp ASC
        LIMIT 1
    ) AS next_status_at,
    ROUND(
        EXTRACT(
            EPOCH
            FROM (
                    (
                        SELECT e2.event_timestamp
                        FROM logistics.delivery_events e2
                        WHERE
                            e2.shipment_id = e1.shipment_id
                            AND e2.event_timestamp > e1.event_timestamp
                        ORDER BY e2.event_timestamp ASC
                        LIMIT 1
                    ) - e1.event_timestamp
                )
        ) / 60.0,
        2
    ) AS duration_minutes_in_status
FROM logistics.delivery_events e1
ORDER BY e1.shipment_id, e1.event_timestamp ASC;

-- Solution 2: WITH Window Functions (LEAD)

WITH
    event_transitions AS (
        SELECT
            shipment_id,
            event_type AS current_status,
            event_timestamp AS status_started_at,
            LEAD(event_type) OVER (
                PARTITION BY
                    shipment_id
                ORDER BY event_timestamp ASC
            ) AS next_status,
            LEAD(event_timestamp) OVER (
                PARTITION BY
                    shipment_id
                ORDER BY event_timestamp ASC
            ) AS next_status_at
        FROM logistics.delivery_events
    )
SELECT
    shipment_id,
    current_status,
    status_started_at,
    next_status,
    next_status_at,
    ROUND(
        EXTRACT(
            EPOCH
            FROM (
                    next_status_at - status_started_at
                )
        ) / 60.0,
        2
    ) AS duration_minutes_in_status
FROM event_transitions
ORDER BY shipment_id, status_started_at ASC;

-- Explanation: How LEAD() Works

-- 1. LEAD(column, offset, default_value) fetches a column value from a row `offset` steps AFTER (below) the current row within the partition.
-- 2. Parameters:
--    - column: the field to fetch (e.g. event_type or event_timestamp).
--    - offset (optional, default = 1): how many rows forward to look.
--    - default_value (optional, default = NULL): what to return for the final row of the partition.
-- 3. PARTITION BY shipment_id guarantees that LEAD() will NEVER look ahead into another shipment's data.
-- 4. In the non-window query, 3 separate correlated subqueries were required for each row (causing extreme performance degradation).
--    LEAD() computes both forward values in a single linear pass over each partition.