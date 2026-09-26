-- WEEK 2: TOPIC 2 — Recursive CTEs

-- Description:
-- Recursive CTEs allow traversing self-referencing tables (trees/graphs)
-- and generating series/sequences directly in SQL.

-- ----------------------------------------------------------------------------
-- PROBLEM 1: Top-Down Category Hierarchy & Breadcrumbs
-- Task: Starting from root categories (parent_category_id IS NULL), build the full
--       taxonomy tree showing level depth, category path, and direct subcategory count.
-- ----------------------------------------------------------------------------


WITH RECURSIVE category_tree AS (
    -- 1. Anchor Member: Root categories
    SELECT 
        category_id,
        category_name,
        parent_category_id,
        1 AS level_depth,
        category_name::TEXT AS path_breadcrumbs
    FROM catalog.categories
    WHERE parent_category_id IS NULL

    UNION ALL

-- 2. Recursive Member: Children joined with parent records in category_tree
SELECT 
        child.category_id,
        child.category_name,
        child.parent_category_id,
        parent.level_depth + 1 AS level_depth,
        parent.path_breadcrumbs || ' > ' || child.category_name AS path_breadcrumbs
    FROM catalog.categories child
    INNER JOIN category_tree parent 
        ON child.parent_category_id = parent.category_id
)
SELECT 
    category_id,
    REPEAT('  ', level_depth - 1) || category_name AS visual_tree,
    level_depth,
    path_breadcrumbs
FROM category_tree
ORDER BY path_breadcrumbs;

-- ----------------------------------------------------------------------------
-- PROBLEM 2: Bottom-Up Ancestor Lookup
-- Task: Given a specific leaf product category, trace all ancestor categories
--       up to the root parent.
-- ----------------------------------------------------------------------------


WITH RECURSIVE category_ancestors AS (
    -- Anchor: The target category
    SELECT 
        category_id,
        category_name,
        parent_category_id,
        1 AS step_back
    FROM catalog.categories
    WHERE category_name = 'Smartphones'

    UNION ALL

-- Recursive: Fetch the parent of current step
SELECT 
        parent.category_id,
        parent.category_name,
        parent.parent_category_id,
        ca.step_back + 1
    FROM catalog.categories parent
    INNER JOIN category_ancestors ca 
        ON parent.category_id = ca.parent_category_id
)
SELECT 
    step_back,
    category_name,
    category_id
FROM category_ancestors
ORDER BY step_back;

-- ----------------------------------------------------------------------------
-- PROBLEM 3: Calendar / Date Gap-Filling Sequence Generator
-- Task: In metrics reporting, days with 0 sales are omitted by GROUP BY.
--       Use a Recursive CTE to generate all dates between two dates and join
--       with sales to guarantee continuous time-series data.
-- ----------------------------------------------------------------------------

WITH RECURSIVE
    date_range AS (
        -- Anchor: Start date
        SELECT '2026-01-01'::DATE AS report_date
        UNION ALL
        -- Recursive: Add 1 day until end date
        SELECT (
                report_date + INTERVAL '1 day'
            )::DATE
        FROM date_range
        WHERE
            report_date < '2026-01-31'::DATE
    ),
    daily_sales AS (
        SELECT
            DATE (order_timestamp) AS order_date,
            COUNT(order_id) AS orders_count,
            SUM(total_amount) AS revenue
        FROM orders.orders
        WHERE
            order_status = 'delivered'
        GROUP BY
            DATE (order_timestamp)
    )
SELECT
    d.report_date,
    COALESCE(s.orders_count, 0) AS total_orders,
    COALESCE(s.revenue, 0.00) AS total_revenue
FROM date_range d
    LEFT JOIN daily_sales s ON d.report_date = s.order_date
ORDER BY d.report_date;

-- ----------------------------------------------------------------------------
-- PROBLEM 4: Production Cycle-Safe Guardrail (Universal SQL)
-- Task: Prevent infinite loops if dirty data introduces cyclic parent-child links.
-- ----------------------------------------------------------------------------

WITH RECURSIVE
    safe_tree AS (
        SELECT
            category_id,
            category_name,
            parent_category_id,
            1 AS depth,
            ARRAY[category_id] AS visited_ids
        FROM catalog.categories
        WHERE
            parent_category_id IS NULL
        UNION ALL
        SELECT c.category_id, c.category_name, c.parent_category_id, st.depth + 1, st.visited_ids || c.category_id
        FROM catalog.categories c
            JOIN safe_tree st ON c.parent_category_id = st.category_id
            -- Guardrails: Stop if ID is already visited OR depth exceeds 10
        WHERE
            NOT (
                c.category_id = ANY (st.visited_ids)
            )
            AND st.depth < 10
    )
SELECT
    category_id,
    category_name,
    depth,
    visited_ids
FROM safe_tree;