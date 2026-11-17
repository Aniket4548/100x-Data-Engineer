-- ============================================================================
-- WEEK 4: TOPIC 01 — PostgreSQL Storage Internals & Page Inspection
-- Description:
-- Before optimizing indexes, you must understand how PostgreSQL physically
-- stores data on disk.
--
-- Key Concepts Covered:
-- 1. The fundamental unit of I/O: The 8 KB (8192 byte) Page/Block.
-- 2. CTID (Current Tuple ID): The physical pointer (Block Number, Offset).
-- 3. Direct CTID row lookups — the fastest possible O(1) physical access.
-- 4. Page density: How many tuples fit per page.
-- 5. Relation size telemetry: Table heap size vs. Index size.
-- 6. Shared buffer cache hits vs. disk reads.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. VERIFY POSTGRESQL BLOCK SIZE & I/O PARAMETERS
-- ----------------------------------------------------------------------------
-- PostgreSQL reads and writes data in fixed-size blocks (default: 8192 bytes).
-- Every sequential scan or index scan operates on whole pages, never individual bytes.

SHOW block_size;               -- Default: 8192 (8 KB)
SHOW shared_buffers;           -- RAM allocated for PostgreSQL buffer cache
SHOW seq_page_cost;            -- Planner estimate for sequential block fetch (1.0)
SHOW random_page_cost;         -- Planner estimate for random block fetch (4.0 or 1.1 on SSD)

-- ----------------------------------------------------------------------------
-- 2. INSPECTING PHYSICAL ROW ADDRESSES: THE `ctid` SYSTEM COLUMN
-- ----------------------------------------------------------------------------
-- Every row in a PostgreSQL heap table has a hidden system column called `ctid`.
-- `ctid` format: `(block_number, offset_number)`
--   - block_number: 0-indexed page inside the physical data file.
--   - offset_number: 1-indexed item pointer on that specific page.

SELECT 
    ctid,
    order_id,
    customer_id,
    order_status,
    total_amount,
    order_timestamp
FROM orders.orders
ORDER BY ctid
LIMIT 15;

-- Notice how `ctid` advances: (0,1), (0,2), ..., until page 0 fills up,
-- then moves to (1,1), (1,2)...

-- ----------------------------------------------------------------------------
-- 3. DIRECT CTID LOOKUP (THE FOUNDATION OF HOW INDEXES WORK)
-- ----------------------------------------------------------------------------
-- When an index finds a matching key, it retrieves the `ctid` of the row.
-- It then uses that `ctid` to jump directly to the target heap page!
-- We can simulate this manual pointer dereference directly in SQL:

EXPLAIN (ANALYZE, BUFFERS)
SELECT * 
FROM orders.orders 
WHERE ctid = '(0, 5)';

-- Review the execution plan:
-- Plan node: "Tid Scan on orders"
-- Execution time is typically < 0.05 ms, reading exactly 1 page buffer (shared hit=1)!
-- This is what an Index Scan does under the hood for each matching entry.

-- ----------------------------------------------------------------------------
-- 4. COMPUTING PAGE DENSITY & HEAP BLOCK STATISTICS
-- ----------------------------------------------------------------------------
-- Let's inspect how many pages `orders.orders` occupies and average rows per page.

SELECT 
    schemaname,
    relname AS table_name,
    n_live_tup AS estimated_row_count,
    -- PostgreSQL system function to retrieve block count
    pg_relation_size(quote_ident(schemaname) || '.' || quote_ident(relname)) / current_setting('block_size')::int AS total_pages,
    ROUND(
        n_live_tup::numeric / 
        NULLIF(pg_relation_size(quote_ident(schemaname) || '.' || quote_ident(relname)) / current_setting('block_size')::int, 0),
        2
    ) AS avg_tuples_per_page
FROM pg_stat_user_tables
WHERE schemaname IN ('orders', 'customer', 'catalog', 'dwh')
ORDER BY n_live_tup DESC;

-- ----------------------------------------------------------------------------
-- 5. MEASURING TABLE HEAP SIZE VS. INDEX SIZE ON DISK
-- ----------------------------------------------------------------------------
-- Understanding relation sizes is crucial for index design. Indexes take RAM
-- in the buffer cache and consume disk space.

SELECT 
    relname AS table_name,
    pg_size_pretty(pg_relation_size(c.oid)) AS heap_table_size,
    pg_size_pretty(pg_indexes_size(c.oid)) AS total_index_size,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS grand_total_size,
    ROUND(
        100.0 * pg_indexes_size(c.oid) / NULLIF(pg_total_relation_size(c.oid), 0), 
        1
    ) AS index_overhead_pct
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'orders' 
  AND c.relkind = 'r'
ORDER BY pg_total_relation_size(c.oid) DESC;

-- Notice:
-- If `index_overhead_pct` exceeds 50%, your indexes consume MORE storage
-- than the actual operational data!

-- ----------------------------------------------------------------------------
-- 6. INSPECTING PHYSICAL CLUSTERING & FRAGMENTATION
-- ----------------------------------------------------------------------------
-- Do orders with similar dates sit together on the same physical pages?
-- Let's see the page range distribution for orders over time:

SELECT 
    (ctid::text::point)[0]::int AS page_number,
    COUNT(*) AS tuples_in_page,
    MIN(order_timestamp) AS earliest_order,
    MAX(order_timestamp) AS latest_order
FROM orders.orders
GROUP BY page_number
ORDER BY page_number
LIMIT 10;

-- Key Takeaway:
-- In an append-only or chronological insert pattern, physical pages naturally
-- correlate with `order_timestamp`. This is why BRIN indexes can be effective!
