-- ============================================================================
-- WEEK 4: TOPIC 08 — Specialized Indexes: Partial, Expression & BRIN
-- Description:
-- Real-world data engineering requires knowing when standard B-Trees are wasteful.
-- PostgreSQL provides advanced specialized indexing features:
--   1. Partial Indexes: Index only a subset of rows meeting a WHERE clause.
--   2. Expression Indexes: Index computed results of functions (e.g. LOWER(col)).
--   3. BRIN (Block Range Indexes): Tiny footprint indexes for physically ordered big data.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. PARTIAL INDEXES: INDEXING ONLY THE ACTIVE SUBSET
-- ----------------------------------------------------------------------------
-- Scenario:
-- An e-commerce fulfillment team only cares about unfulfilled orders
-- (`order_status IN ('pending', 'processing')`).
-- 95% of orders in the table are already 'delivered' or 'cancelled'.
-- Indexing the entire 100,000 rows wastes memory and slows down writes!

DROP INDEX IF EXISTS orders.idx_orders_full_status;
DROP INDEX IF EXISTS orders.idx_orders_partial_unfulfilled;

-- Full index on all rows:
CREATE INDEX idx_orders_full_status 
ON orders.orders (order_id, order_status);

-- Partial index on ONLY unfulfilled orders:
CREATE INDEX idx_orders_partial_unfulfilled 
ON orders.orders (order_id, order_timestamp)
WHERE order_status IN ('pending', 'processing');

-- Compare physical sizes:
SELECT 
    indexname,
    pg_size_pretty(pg_relation_size(quote_ident(schemaname) || '.' || quote_ident(indexname))) AS index_size
FROM pg_indexes
WHERE indexname IN ('idx_orders_full_status', 'idx_orders_partial_unfulfilled');

-- Notice:
-- The partial index is a fraction of the size!
-- Furthermore, INSERTs or UPDATEs on 'delivered' orders do NOT write to the partial index at all!

-- Benchmark the query using the partial predicate:
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_timestamp
FROM orders.orders
WHERE order_status IN ('pending', 'processing')
ORDER BY order_timestamp ASC;

DROP INDEX IF EXISTS orders.idx_orders_full_status;
DROP INDEX IF EXISTS orders.idx_orders_partial_unfulfilled;

-- ----------------------------------------------------------------------------
-- 2. EXPRESSION (FUNCTIONAL) INDEXES
-- ----------------------------------------------------------------------------
-- Problem: Applying a function on an indexed column prevents standard B-Tree index usage!

DROP INDEX IF EXISTS customer.idx_customers_email_lower;

-- Query doing case-insensitive email lookup:
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, first_name, last_name, email
FROM customer.customers
WHERE LOWER(email) = 'user@example.com';

-- Even if `email` has an index, `LOWER(email)` forces a SEQUENTIAL SCAN
-- because the index stores original case values, not lowercase hashes!

-- Solution: Create an Expression Index
CREATE INDEX idx_customers_email_lower 
ON customer.customers (LOWER(email));

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, first_name, last_name, email
FROM customer.customers
WHERE LOWER(email) = 'user@example.com';

-- Notice:
-- Plan node: "Bitmap Index Scan on idx_customers_email_lower" or "Index Scan"!
-- The expression is pre-computed and stored directly in the index!

DROP INDEX IF EXISTS customer.idx_customers_email_lower;

-- ----------------------------------------------------------------------------
-- 3. BRIN (BLOCK RANGE INDEXES) FOR APPEND-ONLY BIG DATA
-- ----------------------------------------------------------------------------
-- BRIN indexes do NOT store individual tuple pointers.
-- Instead, BRIN stores the minimum and maximum values for a range of blocks
-- (default: 128 physical 8KB pages = 1 MB of table data).
-- Perfect for append-only time series and event logs!

DROP INDEX IF EXISTS customer.idx_cust_events_time_btree;
DROP INDEX IF EXISTS customer.idx_cust_events_time_brin;

-- Create standard B-Tree on 20,000 events:
CREATE INDEX idx_cust_events_time_btree 
ON customer.customer_events USING btree (event_timestamp);

-- Create BRIN index on the same column:
CREATE INDEX idx_cust_events_time_brin 
ON customer.customer_events USING brin (event_timestamp) 
WITH (pages_per_range = 32);

-- Compare physical disk footprint:
SELECT 
    indexname,
    pg_size_pretty(pg_relation_size(quote_ident(schemaname) || '.' || quote_ident(indexname))) AS index_size
FROM pg_indexes
WHERE indexname IN ('idx_cust_events_time_btree', 'idx_cust_events_time_brin');

-- BRIN index is typically 10x to 100x SMALLER than B-Tree!
-- In a multi-terabyte warehouse, BRIN allows indexing billions of rows with just megabytes of RAM.

-- Query using BRIN index:
SET enable_seqscan = off;

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM customer.customer_events
WHERE event_timestamp >= '2024-06-01 00:00:00';

RESET enable_seqscan;

DROP INDEX IF EXISTS customer.idx_cust_events_time_btree;
DROP INDEX IF EXISTS customer.idx_cust_events_time_brin;
