-- ============================================================================
-- WEEK 4: TOPIC 06 — Covering Indexes & Index-Only Scans
-- Description:
-- In a standard Index Scan, the engine traverses the B-Tree to find matching keys,
-- grabs their `ctid` pointers, and then jumps to the Heap table to read the
-- remaining row columns.
--
-- A Covering Index includes all columns required by the query (via the `INCLUDE` clause).
-- When every requested column exists inside the index, PostgreSQL can perform an
-- `Index Only Scan`, bypassing the heap table entirely!
--
-- Key Concepts Covered:
-- 1. Syntax: `CREATE INDEX ... ON ... (key_cols) INCLUDE (payload_cols)`.
-- 2. Index Scan vs. Index-Only Scan comparison.
-- 3. The Visibility Map: Why `Heap Fetches: 0` requires a clean/vacuumed table.
-- 4. Buffer I/O reduction: Measuring shared hits dropping from 20+ down to 2.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SETUP: QUERY REQUIRING FILTER + PAYLOAD COLUMNS
-- ----------------------------------------------------------------------------
-- Business query:
-- "For a given product, calculate the total quantity ordered and revenue generated."
-- Filter column: `product_id`
-- Payload columns: `quantity`, `line_total`

DROP INDEX IF EXISTS orders.idx_order_items_product_covering;
DROP INDEX IF EXISTS orders.idx_order_items_product_standard;

-- ----------------------------------------------------------------------------
-- 2. STAGE 1: STANDARD (NON-COVERING) INDEX SCAN
-- ----------------------------------------------------------------------------
-- Create standard index on only the filter column:
CREATE INDEX idx_order_items_product_standard 
ON orders.order_items (product_id);

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    product_id,
    SUM(quantity) AS total_units,
    SUM(line_total) AS total_revenue
FROM orders.order_items
WHERE product_id = 'ffeb4a39-33f6-49a8-9a51-bbfdf4761d2f'
GROUP BY product_id;

-- Examine the execution plan:
-- - Plan node: "Bitmap Index Scan" or "Index Scan using idx_order_items_product_standard"
-- - Followed by: Accessing the heap table to retrieve `quantity` and `line_total`.
-- - Notice the buffer count: Shared hit includes both index pages AND heap data pages!

DROP INDEX IF EXISTS orders.idx_order_items_product_standard;

-- ----------------------------------------------------------------------------
-- 3. STAGE 2: COVERING INDEX (WITH INCLUDE CLAUSE)
-- ----------------------------------------------------------------------------
-- `product_id` is the search key (sorted inside the B-Tree).
-- `quantity` and `line_total` are payload columns (stored only in the leaf nodes).
-- Because they are NOT in the B-Tree sort key, they do NOT increase B-tree tree height
-- and do NOT incur sorting overhead!

CREATE INDEX idx_order_items_product_covering 
ON orders.order_items (product_id) 
INCLUDE (quantity, line_total);

-- ----------------------------------------------------------------------------
-- 4. ENSURE VISIBILITY MAP IS UP TO DATE VIA VACUUM
-- ----------------------------------------------------------------------------
-- PostgreSQL indexes do NOT contain MVCC transaction visibility data (`xmin`/`xmax`).
-- To confirm that an index entry represents an active, committed row without
-- visiting the heap, PostgreSQL checks the table's "Visibility Map".
-- If a page has been VACUUMed and marked "all-visible", PostgreSQL skips the heap entirely!
-- In production/CLI, run `VACUUM orders.order_items;` in autocommit mode.
ANALYZE orders.order_items;
-- VACUUM ANALYZE orders.order_items;

-- ----------------------------------------------------------------------------
-- 5. BENCHMARK THE COVERING INDEX (INDEX-ONLY SCAN)
-- ----------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    product_id,
    SUM(quantity) AS total_units,
    SUM(line_total) AS total_revenue
FROM orders.order_items
WHERE product_id = 'ffeb4a39-33f6-49a8-9a51-bbfdf4761d2f'
GROUP BY product_id;

-- Examine the output:
-- - Plan node: "Index Only Scan using idx_order_items_product_covering on order_items"
-- - "Heap Fetches: 0"  <-- CRITICAL INDICATOR!
-- - Buffers: shared hit dropped dramatically because ZERO heap data pages were read!

-- ----------------------------------------------------------------------------
-- 6. DEMONSTRATING HEAP FETCHES WHEN VISIBILITY MAP IS DIRTY
-- ----------------------------------------------------------------------------
-- When new rows are inserted or updated, their pages are marked dirty in the
-- visibility map. Watch what happens when we insert a row:

BEGIN;
INSERT INTO orders.order_items (
    order_item_id, order_id, product_id, quantity, unit_price, discount_amount, line_total
) VALUES (
    gen_random_uuid(),
    (SELECT order_id FROM orders.orders LIMIT 1),
    'ffeb4a39-33f6-49a8-9a51-bbfdf4761d2f',
    1, 99.00, 0.00, 99.00
);

-- Query the table before vacuuming:
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    product_id,
    SUM(quantity) AS total_units,
    SUM(line_total) AS total_revenue
FROM orders.order_items
WHERE product_id = 'ffeb4a39-33f6-49a8-9a51-bbfdf4761d2f'
GROUP BY product_id;

-- Notice: "Heap Fetches: 1" or more!
-- PostgreSQL had to physically check the heap to verify the newly inserted row's visibility.

ROLLBACK; -- Clean up our test insert

-- ----------------------------------------------------------------------------
-- 7. CLEANUP
-- ----------------------------------------------------------------------------
DROP INDEX IF EXISTS orders.idx_order_items_product_covering;
