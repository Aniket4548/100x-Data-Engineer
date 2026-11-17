-- ============================================================================
-- WEEK 4: TOPIC 07 — Hash Indexes: Internals & Benchmarks
-- Description:
-- While B-Trees store sorted data for equality and range lookups, Hash indexes
-- compute a 32-bit hash value and map it directly into physical bucket pages.
-- They provide O(1) expected time complexity for equality searches (`=`),
-- but CANNOT support range queries, sorting, or prefix matching.
--
-- Key Concepts Covered:
-- 1. Creating Hash indexes: `CREATE INDEX ... USING hash (column)`.
-- 2. The Equality-Only restriction: Showing range/prefix queries fail to use the index.
-- 3. Side-by-side comparison: Hash Index vs. B-Tree Index on physical size and speed.
-- 4. WAL logging and crash-safety context (PostgreSQL 10+).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SETUP ON HIGH-CARDINALITY STRING COLUMN: `logistics.shipments (tracking_number)`
-- ----------------------------------------------------------------------------
-- Clean up prior test indexes:
DROP INDEX IF EXISTS logistics.idx_shipments_tracking_hash;
DROP INDEX IF EXISTS logistics.idx_shipments_tracking_btree;

-- ----------------------------------------------------------------------------
-- 2. CREATE HASH INDEX VS B-TREE INDEX
-- ----------------------------------------------------------------------------
-- Create Hash Index:
CREATE INDEX idx_shipments_tracking_hash 
ON logistics.shipments USING hash (tracking_number);

-- Create B-Tree Index for direct comparison:
CREATE INDEX idx_shipments_tracking_btree 
ON logistics.shipments USING btree (tracking_number);

-- ----------------------------------------------------------------------------
-- 3. COMPARE DISK STORAGE SIZES
-- ----------------------------------------------------------------------------
-- Hash indexes organize data into buckets and overflow pages.
-- Let's compare their physical footprint on disk:

SELECT 
    indexname,
    indexdef,
    pg_size_pretty(pg_relation_size(quote_ident(schemaname) || '.' || quote_ident(indexname))) AS index_size_bytes
FROM pg_indexes
WHERE indexname IN ('idx_shipments_tracking_hash', 'idx_shipments_tracking_btree');

-- ----------------------------------------------------------------------------
-- 4. EQUALITY LOOKUP BENCHMARK (`=`)
-- ----------------------------------------------------------------------------
-- Grab an existing tracking number:
SELECT tracking_number FROM logistics.shipments LIMIT 1;

-- Test Equality Lookup:
EXPLAIN (ANALYZE, BUFFERS)
SELECT shipment_id, order_id, shipment_status, tracking_number
FROM logistics.shipments
WHERE tracking_number = (SELECT tracking_number FROM logistics.shipments LIMIT 1);

-- Force Postgres to evaluate the Hash index specifically if needed:
SET enable_indexscan = on;
SET enable_seqscan = off;

EXPLAIN (ANALYZE, BUFFERS)
SELECT shipment_id, order_id, shipment_status, tracking_number
FROM logistics.shipments
WHERE tracking_number = 'TRK-2024-00001';

RESET enable_seqscan;

-- ----------------------------------------------------------------------------
-- 5. THE LIMITATION: RANGE & PREFIX QUERIES FAIL ON HASH INDEXES
-- ----------------------------------------------------------------------------
-- Hash indexes do NOT preserve sorting. The hash function scatters values.
-- Therefore, operators like `<`, `>`, `BETWEEN`, `ORDER BY`, or `LIKE`
-- CANNOT use a Hash index!

-- Drop the B-Tree index to see Hash index behavior in isolation:
DROP INDEX IF EXISTS logistics.idx_shipments_tracking_btree;

-- Case A: Range Query
EXPLAIN (ANALYZE, BUFFERS)
SELECT shipment_id, tracking_number
FROM logistics.shipments
WHERE tracking_number >= 'TRK-2024-00001';

-- Notice:
-- Plan node: "Seq Scan on shipments"
-- The Hash index is completely unusable for range predicates!

-- Case B: Ordering Query
EXPLAIN (ANALYZE, BUFFERS)
SELECT shipment_id, tracking_number
FROM logistics.shipments
ORDER BY tracking_number ASC
LIMIT 10;

-- Notice:
-- Plan node: "Seq Scan on shipments" followed by "Sort"
-- The Hash index cannot assist with sorting!

-- ----------------------------------------------------------------------------
-- 6. ARCHITECTURAL DECISION MATRIX: WHEN TO USE HASH INDEXES
-- ----------------------------------------------------------------------------
-- Use Hash Index WHEN:
--   1. The column contains long strings (e.g. SHA-256 tokens, UUIDs, external tracking IDs).
--   2. You ONLY ever query `WHERE col = constant`.
--   3. You never need range scans (`>`, `<`), range pagination, or `ORDER BY`.
--
-- Use B-Tree Index WHEN:
--   - You need `<`, `>`, `BETWEEN`, `ORDER BY`, or covering index (`INCLUDE`).
--   (B-Trees are the safe default in 95%+ of production scenarios).

-- ----------------------------------------------------------------------------
-- 7. CLEANUP
-- ----------------------------------------------------------------------------
DROP INDEX IF EXISTS logistics.idx_shipments_tracking_hash;
