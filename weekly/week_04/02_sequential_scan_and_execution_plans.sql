-- ============================================================================
-- WEEK 4: TOPIC 02 — Sequential Scan & Execution Plan Cost Model
-- Description:
-- A Sequential Scan (Full Table Scan) is the baseline against which every
-- index must compete. In many scenarios (e.g. bulk reads, low selectivity),
-- a sequential scan is actually FASTER than an index scan.
--
-- Key Concepts Covered:
-- 1. Anatomy of `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)`.
-- 2. PostgreSQL cost formula arithmetic:
--      cost = (pages * seq_page_cost) + (rows * cpu_tuple_cost) + (rows * cpu_operator_cost)
-- 3. Reading Shared Buffers: hit vs read vs dirtied.
-- 4. The "enable_seqscan" planner flag — testing optimizer tradeoffs.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. BASELINE TABLE STATISTICS & PLANNER COST PARAMETERS
-- ----------------------------------------------------------------------------
-- Check the baseline variables that define the optimizer cost calculations:
SELECT 
    name, 
    setting, 
    unit, 
    short_desc 
FROM pg_settings 
WHERE name IN (
    'seq_page_cost', 
    'random_page_cost', 
    'cpu_tuple_cost', 
    'cpu_index_tuple_cost', 
    'cpu_operator_cost'
);

-- Let's inspect the page and tuple count for `orders.order_items`:
SELECT 
    relname, 
    relpages, 
    reltuples 
FROM pg_class 
WHERE relname = 'order_items' 
  AND relnamespace = 'orders'::regnamespace;

-- ----------------------------------------------------------------------------
-- 2. SEQUENTIAL SCAN WITHOUT FILTERS (FULL TABLE READ)
-- ----------------------------------------------------------------------------
-- When reading all rows, PostgreSQL performs a pure Sequential Scan.
-- Notice the estimated cost:
--   Formula: (relpages * 1.0) + (reltuples * 0.01)

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    line_total
FROM orders.order_items;

-- Interpret the output:
-- - "Seq Scan on orders.order_items"
-- - "cost=0.00..XXX.XX":
--     0.00 = Startup cost (time to return the first row)
--     XXX.XX = Total cost (time to return all rows)
-- - "Buffers: shared hit=XXX": Pages read directly from memory (shared_buffers).

-- ----------------------------------------------------------------------------
-- 3. SEQUENTIAL SCAN WITH FILTER CONDITION
-- ----------------------------------------------------------------------------
-- Filter: Scanning rows and discarding those that do not match the predicate.

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders.orders
WHERE total_amount > 5000;

-- Notice:
-- - "Rows Removed by Filter: NNNN"
-- - The engine had to physically read EVERY single page in the table,
--   evaluate `total_amount > 5000` for every tuple, and discard non-matches.

-- ----------------------------------------------------------------------------
-- 4. FORCING VS. DISABLING SEQUENTIAL SCANS
-- ----------------------------------------------------------------------------
-- By default, PostgreSQL chooses the cheapest plan according to its cost model.
-- You can tell the planner to avoid sequential scans by setting `enable_seqscan = off`.
-- NOTE: In production, NEVER leave enable_seqscan = off permanently! It is a diagnostic tool.

-- Baseline with seq scan enabled:
SET enable_seqscan = on;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, total_amount, order_status
FROM orders.orders
WHERE order_status = 'delivered';

-- Now artificially discourage sequential scan:
SET enable_seqscan = off;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, total_amount, order_status
FROM orders.orders
WHERE order_status = 'delivered';

-- Notice:
-- If an index on `order_status` exists, Postgres will switch to it, but the total
-- cost might actually be HIGHER than the seq scan!
-- Why? Because reading ~70% of rows via index causes massive RANDOM I/O page jumps.

-- Reset setting back to default:
RESET enable_seqscan;

-- ----------------------------------------------------------------------------
-- 5. MEASURING I/O TIMING (DISK VS BUFFER CACHE)
-- ----------------------------------------------------------------------------
-- If track_io_timing is enabled, EXPLAIN ANALYZE will show exact disk read times:

SET track_io_timing = on;

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(line_total)
FROM orders.order_items
WHERE quantity >= 5;

RESET track_io_timing;
