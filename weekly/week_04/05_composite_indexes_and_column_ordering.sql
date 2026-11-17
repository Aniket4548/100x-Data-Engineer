-- ============================================================================
-- WEEK 4: TOPIC 05 — Composite Indexes & Column Ordering Rules
-- Description:
-- A composite (multicolumn) index contains two or more columns. The order of
-- columns within the index definition is critical: an incorrectly ordered
-- composite index will be completely ignored by the query planner.
--
-- Key Concepts Covered:
-- 1. The Leftmost-Prefix Principle: Index (A, B, C) can satisfy queries on:
--      - (A)
--      - (A, B)
--      - (A, B, C)
--      ... but CANNOT efficiently satisfy queries on (B) or (C) alone!
-- 2. The Golden Heuristic: "Equality Columns First, Range Columns Second".
-- 3. Composite indexes for sorting (ORDER BY) and mixed sort directions (ASC/DESC).
-- 4. Bitmap Index Scan combining two separate single-column indexes vs. one composite index.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SETUP TEST SCENARIO ON `orders.orders`
-- ----------------------------------------------------------------------------
-- Clean up any existing test composite indexes:
DROP INDEX IF EXISTS orders.idx_test_orders_status_date;
DROP INDEX IF EXISTS orders.idx_test_orders_date_status;

-- ----------------------------------------------------------------------------
-- 2. THE LEFTMOST PREFIX RULE DEMONSTRATION
-- ----------------------------------------------------------------------------
-- Create a composite index with column order: (customer_id, order_status)
CREATE INDEX idx_test_orders_customer_status 
ON orders.orders (customer_id, order_status);

-- Case 1: Query matching the FULL prefix (customer_id AND order_status)
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, order_status, total_amount
FROM orders.orders
WHERE customer_id = '59f3ee9c-59e8-41aa-ae8f-66d07c6e668b' AND order_status = 'delivered';
-- Result: Uses Index Scan directly on idx_test_orders_customer_status!

-- Case 2: Query matching the LEFTMOST column only (customer_id)
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, order_status, total_amount
FROM orders.orders
WHERE customer_id = '59f3ee9c-59e8-41aa-ae8f-66d07c6e668b';
-- Result: Still uses Index Scan! The index can seek directly to customer_id = 150.

-- Case 3: Query filtering ONLY on the SECOND column (order_status)
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, order_status, total_amount
FROM orders.orders
WHERE order_status = 'cancelled';
-- Result: CANNOT seek idx_test_orders_customer_status because customer_id is unknown!
-- Postgres falls back to a different index or a Sequential Scan.

DROP INDEX IF EXISTS orders.idx_test_orders_customer_status;

-- ----------------------------------------------------------------------------
-- 3. EQUALITY BEFORE RANGE: THE GOLDEN DESIGN HEURISTIC
-- ----------------------------------------------------------------------------
-- Consider a common dashboard query:
--   "Find orders where status = 'delivered' and order_timestamp >= '2024-06-01'"
--
-- Notice:
--   - `order_status` is an EQUALITY predicate (`=`)
--   - `order_timestamp` is a RANGE predicate (`>=`)

-- Test Index A: (range_col, equality_col) -> INCORRECT ORDER
CREATE INDEX idx_test_orders_date_status 
ON orders.orders (order_timestamp, order_status);

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_status, order_timestamp, total_amount
FROM orders.orders
WHERE order_status = 'delivered' 
  AND order_timestamp >= '2024-06-01 00:00:00';

-- Test Index B: (equality_col, range_col) -> OPTIMAL ORDER
CREATE INDEX idx_test_orders_status_date 
ON orders.orders (order_status, order_timestamp);

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_status, order_timestamp, total_amount
FROM orders.orders
WHERE order_status = 'delivered' 
  AND order_timestamp >= '2024-06-01 00:00:00';

-- Compare the execution plans:
-- In Index B (status, date):
--   The B-Tree first seeks directly to the sub-tree where `order_status = 'delivered'`,
--   and then immediately scans forward sequentially for `order_timestamp >= '2024-06-01'`.
--   Zero extra index leaf pages are inspected!

DROP INDEX IF EXISTS orders.idx_test_orders_date_status;
DROP INDEX IF EXISTS orders.idx_test_orders_status_date;

-- ----------------------------------------------------------------------------
-- 4. COMPOSITE INDEXES FOR FILTERING + SORTING
-- ----------------------------------------------------------------------------
-- Business query: "Retrieve the 10 most recent orders for a specific customer"
--   WHERE customer_id = ? ORDER BY order_timestamp DESC LIMIT 10

CREATE INDEX idx_orders_cust_date_desc 
ON orders.orders (customer_id, order_timestamp DESC);

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, order_timestamp, total_amount
FROM orders.orders
WHERE customer_id = '59f3ee9c-59e8-41aa-ae8f-66d07c6e668b'
ORDER BY order_timestamp DESC
LIMIT 10;

-- Notice:
-- - Plan node: "Index Scan using idx_orders_cust_date_desc"
-- - Zero Sort node required!
-- - It immediately reads the top 10 rows for this customer directly in pre-sorted order.

DROP INDEX IF EXISTS orders.idx_orders_cust_date_desc;

-- ----------------------------------------------------------------------------
-- 5. BITMAP INDEX SCAN: COMBINING TWO SINGLE-COLUMN INDEXES
-- ----------------------------------------------------------------------------
-- What if you have two separate single-column indexes?
-- PostgreSQL has an engine feature called `BitmapAnd`:
-- It scans both indexes separately, builds two in-memory bitmaps, and intersects them!

-- Let's ensure single indexes exist:
CREATE INDEX IF NOT EXISTS idx_single_cust ON orders.orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_single_status ON orders.orders (order_status);

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders.orders
WHERE customer_id = '59f3ee9c-59e8-41aa-ae8f-66d07c6e668b' AND order_status = 'cancelled';

-- You will often see:
-- -> BitmapAnd
--      -> Bitmap Index Scan on idx_single_cust
--      -> Bitmap Index Scan on idx_single_status
-- -> Bitmap Heap Scan on orders

-- While BitmapAnd works, a single composite index `(customer_id, order_status)`
-- is typically 2x - 5x faster because it requires only 1 B-tree descent!

DROP INDEX IF EXISTS orders.idx_single_cust;
DROP INDEX IF EXISTS orders.idx_single_status;
