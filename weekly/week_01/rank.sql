-- Rank Carriers by Total Completed Deliveries (Competition Leaderboard with Gaps)
-- Business Scenario:
-- The operations team wants a performance leaderboard ranking shipping carriers by their total count of successful deliveries.
-- If carriers tie with the exact same delivery count, they should share the same rank, and subsequent ranks should be skipped (e.g., 1, 1, 3).

-- Tables to use:
-- logistics.shipments

-- Required Output Columns:
-- carrier
-- successful_deliveries
-- carrier_rank

-- Solution 1: WITHOUT Window Functions (Self-Join / Correlated Subquery)

WITH
    carrier_counts AS (
        SELECT
            carrier,
            COUNT(*) AS successful_deliveries
        FROM logistics.shipments
        WHERE
            shipment_status = 'delivered'
        GROUP BY
            carrier
    )
SELECT c1.carrier, c1.successful_deliveries, 1 + (
        SELECT COUNT(*)
        FROM carrier_counts c2
        WHERE
            c2.successful_deliveries > c1.successful_deliveries
    ) AS carrier_rank
FROM carrier_counts c1
ORDER BY carrier_rank ASC, c1.carrier;

-- Solution 2: WITH Window Functions (RANK)

WITH
    carrier_counts AS (
        SELECT
            carrier,
            COUNT(*) AS successful_deliveries
        FROM logistics.shipments
        WHERE
            shipment_status = 'delivered'
        GROUP BY
            carrier
    )
SELECT
    carrier,
    successful_deliveries,
    RANK() OVER (
        ORDER BY successful_deliveries DESC
    ) AS carrier_rank
FROM carrier_counts
ORDER BY carrier_rank ASC, carrier;

-- Explanation: How RANK() Works

-- 1. RANK() assigns ranks based on the specified ORDER BY column.
-- 2. When ties occur, all tied rows receive the same rank number.
-- 3. Crucially, RANK() leaves GAPS after ties: the next rank equals (current rank + count of tied rows).
--    Example: If two carriers tie at Rank 1, the next carrier gets Rank 3 (Rank 2 is skipped).
-- 4. Formula under the hood: Rank of row = 1 + (Number of rows with higher value).
-- 5. Comparison:
--    - ROW_NUMBER(): Never ties (1, 2, 3, 4).
--    - RANK(): Ties with gaps (1, 1, 3, 4).
--    - DENSE_RANK(): Ties without gaps (1, 1, 2, 3).