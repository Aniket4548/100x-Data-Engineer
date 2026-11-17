-- ============================================================================
-- WEEK 4: TOPIC 03 — Single-Column B-Tree Indexes & Scan Mechanics
-- Description:
-- The B-Tree (B+Tree) is the default and most widely used index type in PostgreSQL.
-- It keeps keys in sorted order, providing O(log N) lookup time for equality
-- and range queries.
--
-- Key Concepts Covered:
-- 1. Creating and dropping B-Tree indexes (standard and CONCURRENTLY).
-- 2. Comparing Index Scan vs Bitmap Index Scan vs Sequential Scan.
-- 3. Equality lookups vs Range queries (`BETWEEN`, `<`, `>`).
-- 4. Index-driven sorting: Eliminating expensive `Sort` operations in ORDER BY.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CREATE A TEST BENCHMARK COLUMN: `orders.orders (total_amount)`
-- ----------------------------------------------------------------------------
-- Currently, `orders.orders` has no index on `total_amount`.
-- Let's query orders with a high total amount:

-- Clean up any prior test index if present
DROP INDEX IF EXISTS orders.idx_orders_total_amount;

-- Baseline query without index on total_amount:
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, order_status, total_amount
FROM orders.orders
WHERE total_amount = 4999.00;

-- Result: Seq Scan on orders, reading all ~100+ pages of the table!

-- ----------------------------------------------------------------------------
-- 2. CREATE B-TREE INDEX (STANDARD DDL)
-- ----------------------------------------------------------------------------
-- Standard CREATE INDEX locks the table against writes (INSERT/UPDATE/DELETE).
CREATE INDEX idx_orders_total_amount 
ON orders.orders USING btree (total_amount);

-- Check that the index is registered in PostgreSQL system catalogs:
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE indexname = 'idx_orders_total_amount';

-- ----------------------------------------------------------------------------
-- 3. BENCHMARK WITH SINGLE-COLUMN B-TREE INDEX
-- ----------------------------------------------------------------------------
-- Run the exact same query again:
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, order_status, total_amount
FROM orders.orders
WHERE total_amount = 4999.00;

-- Notice the change:
-- - Plan node: "Index Scan using idx_orders_total_amount on orders"
-- - Buffers: shared hit dropped from table total (~130 pages) down to 2 or 3 pages!
--   (1 or 2 B-tree pages + 1 heap table page).

-- ----------------------------------------------------------------------------
-- 4. UNDERSTANDING BITMAP INDEX SCAN (MULTI-ROW MATCHES)
-- ----------------------------------------------------------------------------
-- When an index query returns dozens or hundreds of rows, PostgreSQL switches
-- from "Index Scan" to "Bitmap Index Scan":
--   Step 1 (Bitmap Index Scan): Scans index leaf pages and builds a bitmap of block numbers.
--   Step 2 (Bitmap Heap Scan): Reads the table blocks sequentially according to the bitmap,
--                             avoiding random I/O thrashing!

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, total_amount
FROM orders.orders
WHERE total_amount BETWEEN 4500.00 AND 5000.00;

-- Notice:
-- - "Bitmap Index Scan on idx_orders_total_amount"
-- - "Bitmap Heap Scan on orders"
-- - The engine sorted physical disk page addresses before visiting the heap!

-- ----------------------------------------------------------------------------
-- 5. ELIMINATING IN-MEMORY SORT OPERATORS WITH B-TREE INDEXES
-- ----------------------------------------------------------------------------
-- B-Trees store data physically in sorted order. If a query requests an ORDER BY
-- matching the index, PostgreSQL does NOT need to run an in-memory Quicksort!

-- A) Without index on order:
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, total_amount
FROM orders.orders
ORDER BY total_amount DESC
LIMIT 10;

-- Notice:
-- Plan node: "Index Scan Backward using idx_orders_total_amount on orders"
-- There is NO `Sort (Sort Method: quicksort)` node in the plan!
-- It streams the first 10 rows directly off the highest leaf node in the B-Tree.

-- ----------------------------------------------------------------------------
-- 6. PRODUCTION BEST PRACTICE: `CREATE INDEX CONCURRENTLY`
-- ----------------------------------------------------------------------------
-- In production OLTP systems, NEVER run plain `CREATE INDEX` on large live tables,
-- because it locks out concurrent INSERTs and UPDATEs.
-- Instead, use `CREATE INDEX CONCURRENTLY`:

-- Syntax example:
-- CREATE INDEX CONCURRENTLY idx_orders_customer_id_safe ON orders.orders (customer_id);
-- Note: CREATE INDEX CONCURRENTLY cannot run inside a multi-statement transaction block
-- (BEGIN ... COMMIT). It must run as a standalone autocommit statement.

-- ----------------------------------------------------------------------------
-- 7. CLEANUP
-- ----------------------------------------------------------------------------
DROP INDEX IF EXISTS orders.idx_orders_total_amount;
