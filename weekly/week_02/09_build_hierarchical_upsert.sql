-- WEEK 2: CAPSTONE BUILD
-- Hierarchical Category Revenue Rollup + Production Incremental Upsert Pipeline

-- Objective:
-- 1. Hierarchical Rollup: Calculate both direct revenue and rolled-up revenue
--    across parent-child category hierarchies (including all subcategories).
-- 2. Incremental Staging Pipeline: Simulate incoming CDC event batch, deduplicate
--    latest records using ROW_NUMBER(), and execute an idempotent upsert into target.

-- PART 1: HIERARCHICAL CATEGORY REVENUE ROLLUP


WITH RECURSIVE category_tree AS (
    -- Anchor: Base mapping of every category to itself (depth 0)
    SELECT 
        category_id AS ancestor_id,
        category_id AS descendant_id,
        0 AS relative_depth
    FROM catalog.categories

    UNION ALL

-- Recursive: Link each ancestor to its subcategories' children
SELECT 
        ct.ancestor_id,
        c.category_id AS descendant_id,
        ct.relative_depth + 1
    FROM category_tree ct
    JOIN catalog.categories c ON ct.descendant_id = c.parent_category_id
),
direct_category_revenue AS (
    -- Revenue directly tied to the specific category
    SELECT 
        p.category_id,
        COUNT(DISTINCT oi.order_id) AS direct_orders,
        COALESCE(SUM(oi.line_total), 0) AS direct_revenue
    FROM catalog.products p
    LEFT JOIN orders.order_items oi ON p.product_id = oi.product_id
    GROUP BY p.category_id
),
rolled_up_metrics AS (
    -- Join tree mappings with direct revenues to accumulate child revenues to ancestors
    SELECT 
        ct.ancestor_id AS category_id,
        SUM(dcr.direct_orders) AS total_orders_rollup,
        SUM(dcr.direct_revenue) AS total_revenue_rollup
    FROM category_tree ct
    JOIN direct_category_revenue dcr ON ct.descendant_id = dcr.category_id
    GROUP BY ct.ancestor_id
)
SELECT 
    c.category_id,
    c.category_name,
    c.parent_category_id,
    COALESCE(dcr.direct_revenue, 0.00) AS direct_revenue,
    COALESCE(rum.total_revenue_rollup, 0.00) AS total_rolled_up_revenue,
    ROUND(
        CASE 
            WHEN rum.total_revenue_rollup > 0 
            THEN (dcr.direct_revenue / rum.total_revenue_rollup) * 100.0 
            ELSE 0.0 
        END, 
        2
    ) AS direct_revenue_share_pct
FROM catalog.categories c
LEFT JOIN direct_category_revenue dcr ON c.category_id = dcr.category_id
LEFT JOIN rolled_up_metrics rum ON c.category_id = rum.category_id
ORDER BY total_rolled_up_revenue DESC;

-- PART 2: PRODUCTION INCREMENTAL UPSERT PIPELINE (ELT PATTERN)

-- Step A: Target Analytics Aggregate Table
CREATE TABLE IF NOT EXISTS analytics_daily_product_summary (
    summary_date DATE NOT NULL,
    product_id UUID NOT NULL,
    units_sold INTEGER NOT NULL DEFAULT 0,
    gross_revenue NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    last_updated_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (summary_date, product_id)
);

-- Step B: Raw Staging Batch (Simulating ingestion lake landing zone with dirty duplicates)
CREATE TEMP TABLE stg_sales_cdc_stream (
    event_id UUID,
    event_timestamp TIMESTAMPTZ,
    order_date DATE,
    product_id UUID,
    quantity INTEGER,
    line_total NUMERIC(14, 2)
);

-- Seed staging batch with duplicate incoming updates (e.g. at-least-once message delivery)
INSERT INTO
    stg_sales_cdc_stream
VALUES (
        gen_random_uuid (),
        '2026-09-10 10:00:00+00',
        '2026-09-10',
        '00000000-0000-0000-0000-000000000001',
        2,
        50.00
    ),
    (
        gen_random_uuid (),
        '2026-09-10 10:05:00+00',
        '2026-09-10',
        '00000000-0000-0000-0000-000000000001',
        3,
        75.00
    ), -- Later update
    (
        gen_random_uuid (),
        '2026-09-10 10:02:00+00',
        '2026-09-10',
        '00000000-0000-0000-0000-000000000002',
        1,
        120.00
    );

-- Step C: Deduplicated Staging -> Target Upsert using CTE + ON CONFLICT
WITH
    deduplicated_batch AS (
        -- Step 1: Group and aggregate clean metrics for the current batch
        SELECT
            order_date AS summary_date,
            product_id,
            SUM(quantity) AS batch_units,
            SUM(line_total) AS batch_revenue,
            MAX(event_timestamp) AS latest_event_time
        FROM stg_sales_cdc_stream
        GROUP BY
            order_date,
            product_id
    )
    -- Step 2: Atomic Incremental Upsert into target table
INSERT INTO
    analytics_daily_product_summary (
        summary_date,
        product_id,
        units_sold,
        gross_revenue,
        last_updated_at
    )
SELECT
    summary_date,
    product_id,
    batch_units,
    batch_revenue,
    latest_event_time
FROM deduplicated_batch
ON CONFLICT (summary_date, product_id) DO
UPDATE
SET
    units_sold = analytics_daily_product_summary.units_sold + EXCLUDED.units_sold,
    gross_revenue = analytics_daily_product_summary.gross_revenue + EXCLUDED.gross_revenue,
    last_updated_at = EXCLUDED.last_updated_at;

-- Step D: Verification Query
SELECT * FROM analytics_daily_product_summary;

-- Clean up
DROP TABLE stg_sales_cdc_stream;