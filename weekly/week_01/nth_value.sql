-- Identify the 2nd Most Expensive (Runner-Up) Product in Each Category
-- Business Scenario:
-- The sales team wants to see the 2nd highest priced product (the runner-up price tier) in each category to set mid-tier promotional pricing.
-- Display each product along with the name and price of the 2nd most expensive product in that category. If a category has fewer than 2 products, return NULL.

-- Tables to use:
-- catalog.products

-- Required Output Columns:
-- category_id
-- product_name
-- cost_price
-- second_most_expensive_product
-- second_highest_price

-- Solution 1: WITHOUT Window Functions (Subquery with OFFSET / LIMIT)

WITH
    second_highest_per_category AS (
        SELECT
            c.category_id,
            (
                SELECT p.product_name
                FROM catalog.products p
                WHERE
                    p.category_id = c.category_id
                ORDER BY p.cost_price DESC, p.product_id ASC
                OFFSET
                    1
                LIMIT 1
            ) AS second_product,
            (
                SELECT p.cost_price
                FROM catalog.products p
                WHERE
                    p.category_id = c.category_id
                ORDER BY p.cost_price DESC, p.product_id ASC
                OFFSET
                    1
                LIMIT 1
            ) AS second_price
        FROM (
                SELECT DISTINCT
                    category_id
                FROM catalog.products
            ) c
    )
SELECT
    p.category_id,
    p.product_name,
    p.cost_price,
    sh.second_product AS second_most_expensive_product,
    sh.second_price AS second_highest_price
FROM
    catalog.products p
    JOIN second_highest_per_category sh ON p.category_id = sh.category_id
ORDER BY p.category_id, p.cost_price DESC;

-- Solution 2: WITH Window Functions (NTH_VALUE with Explicit Frame)

SELECT
    category_id,
    product_name,
    cost_price,
    NTH_VALUE(product_name, 2) OVER (
        PARTITION BY
            category_id
        ORDER BY cost_price DESC ROWS BETWEEN UNBOUNDED PRECEDING
            AND UNBOUNDED FOLLOWING
    ) AS second_most_expensive_product,
    NTH_VALUE(cost_price, 2) OVER (
        PARTITION BY
            category_id
        ORDER BY cost_price DESC ROWS BETWEEN UNBOUNDED PRECEDING
            AND UNBOUNDED FOLLOWING
    ) AS second_highest_price
FROM catalog.products
ORDER BY category_id, cost_price DESC;

-- Explanation: How NTH_VALUE() Works

-- 1. NTH_VALUE(expression, n) returns the value evaluated at the n-th row of the window frame (1-indexed).
-- 2. If the window frame has fewer than n rows, it gracefully returns NULL.
-- 3. Frame Sensitivity: Like LAST_VALUE(), NTH_VALUE(expression, n) requires the frame to extend at least up to row n.
--    By adding `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`, the window function can see every row in the partition regardless of the current row position.
-- 4. Cleanliness & Performance: The non-window approach requires 2 subqueries with OFFSET 1 LIMIT 1 for every category, whereas NTH_VALUE() processes all rows seamlessly in a single pass.