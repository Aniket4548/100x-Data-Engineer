-- Top 2 Most Expensive Products per Category (Handling Ties)
-- Business Scenario:
-- The merchandising team wants to see the Top 2 most expensive price points for products in each category from catalog.products.
-- If multiple products share the highest price in a category, they should all be included in Rank 1, and the next highest price should be Rank 2.

-- Tables to use:
-- catalog.products (or joined with catalog.categories)

-- Required Output Columns:
-- category_id (or category_name)
-- product_name
-- cost_price

-- Solution 1: WITHOUT Window Functions (Correlated Subquery)

SELECT p.category_id, p.product_name, p.cost_price
FROM catalog.products p
WHERE (
        SELECT COUNT(DISTINCT p2.cost_price)
        FROM catalog.products p2
        WHERE
            p2.category_id = p.category_id
            AND p2.cost_price > p.cost_price
    ) < 2
ORDER BY p.category_id, p.cost_price DESC, p.product_name;

-- Solution 2: WITH Window Functions (DENSE_RANK)

WITH
    ranked_products AS (
        SELECT p.category_id, p.product_name, p.cost_price, DENSE_RANK() OVER (
                PARTITION BY
                    p.category_id
                ORDER BY p.cost_price DESC
            ) AS price_rank
        FROM catalog.products p
    )
SELECT
    category_id,
    product_name,
    cost_price
FROM ranked_products
WHERE
    price_rank <= 2
ORDER BY
    category_id,
    cost_price DESC,
    product_name;

-- Explanation: How DENSE_RANK() Works

-- 1. DENSE_RANK() assigns sequential ranks to rows based on the ORDER BY column.
-- 2. When two or more rows have identical values (ties), they receive the SAME rank.
-- 3. Unlike RANK(), DENSE_RANK() NEVER skips numbers. If two products tie at Rank 1, the next distinct price is strictly Rank 2.
-- 4. PARTITION BY category_id ensures ranking restarts independently for each product category.
-- 5. Performance: The non-window correlated subquery runs in O(N^2) time because it rescans the table for every row.
--    DENSE_RANK() runs in O(N log N) time via a single sort + single linear WindowAgg scan.