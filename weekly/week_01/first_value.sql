-- Compare Each Product Against the Cheapest Entry in its Category
-- Business Scenario:
-- The pricing strategy team wants to evaluate price positioning.
-- For every product in catalog.products, display its details along with the name and cost price of the CHEAPEST product in its category, and the price premium over the baseline.

-- Tables to use:
-- catalog.products

-- Required Output Columns:
-- category_id
-- product_name
-- cost_price
-- cheapest_product_in_category
-- cheapest_price_in_category
-- price_premium (cost_price - cheapest_price)

-- Solution 1: WITHOUT Window Functions (Subquery / Self-Join)

WITH
    min_category_prices AS (
        SELECT category_id, MIN(cost_price) AS min_price
        FROM catalog.products
        GROUP BY
            category_id
    ),
    cheapest_products AS (
        SELECT DISTINCT
            ON (p.category_id) p.category_id,
            p.product_name AS cheapest_product_name,
            p.cost_price AS cheapest_price
        FROM
            catalog.products p
            JOIN min_category_prices m ON p.category_id = m.category_id
            AND p.cost_price = m.min_price
        ORDER BY p.category_id, p.product_name ASC
    )
SELECT
    p.category_id,
    p.product_name,
    p.cost_price,
    cp.cheapest_product_name AS cheapest_product_in_category,
    cp.cheapest_price AS cheapest_price_in_category,
    p.cost_price - cp.cheapest_price AS price_premium
FROM catalog.products p
    JOIN cheapest_products cp ON p.category_id = cp.category_id
ORDER BY p.category_id, p.cost_price ASC;

-- Solution 2: WITH Window Functions (FIRST_VALUE)

SELECT
    category_id,
    product_name,
    cost_price,
    FIRST_VALUE(product_name) OVER (
        PARTITION BY
            category_id
        ORDER BY cost_price ASC
    ) AS cheapest_product_in_category,
    FIRST_VALUE(cost_price) OVER (
        PARTITION BY
            category_id
        ORDER BY cost_price ASC
    ) AS cheapest_price_in_category,
    cost_price - FIRST_VALUE(cost_price) OVER (
        PARTITION BY
            category_id
        ORDER BY cost_price ASC
    ) AS price_premium
FROM catalog.products
ORDER BY category_id, cost_price ASC;

-- Explanation: How FIRST_VALUE() Works

-- 1. FIRST_VALUE(expression) returns the value evaluated at the first row of the window frame.
-- 2. When ORDER BY cost_price ASC is specified, the first row of the partition is guaranteed to be the lowest priced item.
-- 3. Unlike GROUP BY + MIN(), which collapses all product rows into 1 category summary row, FIRST_VALUE() allows every product to retain its own row while accessing the category minimum.
-- 4. Default Frame: The default frame `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` works fine for FIRST_VALUE() because the first row of the frame is always row 1 (the partition minimum).