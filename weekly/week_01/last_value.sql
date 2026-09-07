-- Identify the Most Expensive (Flagship) Product in Each Category
-- Business Scenario:
-- For catalog analysis, the merchandising team wants to compare every product against the HIGHEST priced (flagship) item in its category.
-- Retrieve each product alongside the name and price of the most expensive product in that category.

-- Tables to use:
-- catalog.products

-- Required Output Columns:
-- category_id
-- product_name
-- cost_price
-- flagship_product_name
-- flagship_product_price
-- discount_from_flagship (flagship_price - cost_price)

-- Solution 1: WITHOUT Window Functions (Subquery / Self-Join)

WITH
    max_category_prices AS (
        SELECT category_id, MAX(cost_price) AS max_price
        FROM catalog.products
        GROUP BY
            category_id
    ),
    flagship_products AS (
        SELECT DISTINCT
            ON (p.category_id) p.category_id,
            p.product_name AS flagship_product_name,
            p.cost_price AS flagship_price
        FROM
            catalog.products p
            JOIN max_category_prices m ON p.category_id = m.category_id
            AND p.cost_price = m.max_price
        ORDER BY p.category_id, p.product_name ASC
    )
SELECT
    p.category_id,
    p.product_name,
    p.cost_price,
    fp.flagship_product_name,
    fp.flagship_price,
    fp.flagship_price - p.cost_price AS discount_from_flagship
FROM catalog.products p
    JOIN flagship_products fp ON p.category_id = fp.category_id
ORDER BY p.category_id, p.cost_price ASC;

-- Solution 2: WITH Window Functions (LAST_VALUE with Explicit Frame)

SELECT
    category_id,
    product_name,
    cost_price,
    LAST_VALUE(product_name) OVER (
        PARTITION BY
            category_id
        ORDER BY cost_price ASC ROWS BETWEEN UNBOUNDED PRECEDING
            AND UNBOUNDED FOLLOWING
    ) AS flagship_product_name,
    LAST_VALUE(cost_price) OVER (
        PARTITION BY
            category_id
        ORDER BY cost_price ASC ROWS BETWEEN UNBOUNDED PRECEDING
            AND UNBOUNDED FOLLOWING
    ) AS flagship_price,
    LAST_VALUE(cost_price) OVER (
        PARTITION BY
            category_id
        ORDER BY cost_price ASC ROWS BETWEEN UNBOUNDED PRECEDING
            AND UNBOUNDED FOLLOWING
    ) - cost_price AS discount_from_flagship
FROM catalog.products
ORDER BY category_id, cost_price ASC;

-- Explanation: How LAST_VALUE() Works & The Critical Default Frame Trap!

-- 1. LAST_VALUE(expression) returns the value at the LAST row of the window frame.
-- 2. THE NUMBER ONE GOTCHA IN SQL WINDOW FUNCTIONS:
--    When you add ORDER BY, PostgreSQL automatically sets the default frame to:
--        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--    Under this default frame, the frame ENDS at the CURRENT ROW.
--    Therefore, LAST_VALUE() just returns the CURRENT ROW'S own value instead of the true last row of the partition!
-- 3. The Fix:
--    You MUST explicitly expand the frame to cover the entire partition:
--        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
-- 4. Alternative: You could also use FIRST_VALUE() with ORDER BY cost_price DESC to avoid frame expansion, but mastering the explicit frame clause is essential for Data Engineers.