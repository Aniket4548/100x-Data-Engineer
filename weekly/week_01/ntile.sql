-- Segment Products into 4 Price Tiers (Quartiles) per Category
-- Business Scenario:
-- The merchandising team wants to categorize products in each catalog category into 4 balanced pricing tiers:
-- Bucket 1: Budget
-- Bucket 2: Economy
-- Bucket 3: Premium
-- Bucket 4: Luxury

-- Tables to use:
-- catalog.products

-- Required Output Columns:
-- category_id
-- product_name
-- cost_price
-- price_tier (1 to 4)
-- tier_label (Budget, Economy, Premium, Luxury)

-- Solution 1: WITHOUT Window Functions (Subquery with Math / Integer Division)

WITH
    product_positions AS (
        SELECT
            p1.category_id,
            p1.product_name,
            p1.cost_price,
            -- Row number without window function:
            (
                SELECT COUNT(*)
                FROM catalog.products p2
                WHERE
                    p2.category_id = p1.category_id
                    AND (
                        p2.cost_price < p1.cost_price
                        OR (
                            p2.cost_price = p1.cost_price
                            AND p2.product_id <= p1.product_id
                        )
                    )
            ) AS row_num,
            -- Category total count:
            (
                SELECT COUNT(*)
                FROM catalog.products p3
                WHERE
                    p3.category_id = p1.category_id
            ) AS total_count
        FROM catalog.products p1
    ),
    bucketed_products AS (
        SELECT
            category_id,
            product_name,
            cost_price,
            -- NTILE(4) math without window functions:
            LEAST(
                4,
                FLOOR(
                    (
                        (row_num - 1)::numeric * 4.0 / total_count::numeric
                    )
                )::integer + 1
            ) AS price_tier
        FROM product_positions
    )
SELECT
    category_id,
    product_name,
    cost_price,
    price_tier,
    CASE price_tier
        WHEN 1 THEN 'Budget'
        WHEN 2 THEN 'Economy'
        WHEN 3 THEN 'Premium'
        WHEN 4 THEN 'Luxury'
    END AS tier_label
FROM bucketed_products
ORDER BY category_id, cost_price ASC;

-- Solution 2: WITH Window Functions (NTILE)

WITH
    bucketed_products AS (
        SELECT
            category_id,
            product_name,
            cost_price,
            NTILE(4) OVER (
                PARTITION BY
                    category_id
                ORDER BY cost_price ASC
            ) AS price_tier
        FROM catalog.products
    )
SELECT
    category_id,
    product_name,
    cost_price,
    price_tier,
    CASE price_tier
        WHEN 1 THEN 'Budget'
        WHEN 2 THEN 'Economy'
        WHEN 3 THEN 'Premium'
        WHEN 4 THEN 'Luxury'
    END AS tier_label
FROM bucketed_products
ORDER BY category_id, cost_price ASC;

-- Explanation: How NTILE() Works

-- 1. NTILE(num_buckets) divides an ordered partition as equally as possible into integer-numbered buckets from 1 to num_buckets.
-- 2. If the total number of rows (N) is not cleanly divisible by num_buckets, earlier buckets receive the extra rows.
--    Example: 10 rows into NTILE(4):
--       Bucket 1: 3 rows
--       Bucket 2: 3 rows
--       Bucket 3: 2 rows
--       Bucket 4: 2 rows
-- 3. Common Data Engineering Use Cases:
--    - Quartiles (NTILE(4)): 25% splits.
--    - Deciles (NTILE(10)): 10% splits (e.g., credit risk deciles).
--    - Percentiles (NTILE(100)): 1% splits.
--    - Parallel batch processing: partitioning workload evenly among worker nodes.