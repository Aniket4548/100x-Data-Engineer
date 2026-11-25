-- ============================================================================
-- 100x DATA ENGINEER: WEEK 5 — CHAPTER 3
-- File: 03_physical_scan_operators.sql
-- Topic: Physical Scan Operators: Seq Scan, Index Scan, Bitmap Scan, Index-Only Scan
-- ============================================================================
-- Description:
-- The foundation of every query execution plan is the Scan Node. This script
-- explores the four physical scan methods used by PostgreSQL to read tuples:
--
--   1. Sequential Scan (Seq Scan & Parallel Seq Scan)
--   2. Index Scan (B-Tree lookup + CTID heap fetch)
--   3. Bitmap Index Scan + Bitmap Heap Scan (Two-stage batched physical page reads)
--   4. Index-Only Scan (Heap bypass via Visibility Map)
--
-- Key Demonstrations:
-- - Why the planner switches between scan methods based on selectivity.
-- - How Bitmap Scans convert random I/O into clustered/sequential physical I/O.
-- - Combining multiple independent indexes via BitmapAnd and BitmapOr.
-- - Forcing planner flags to observe the Random I/O Cliff when forcing index scans
--   on low-selectivity queries.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SETUP EXPERIMENTAL TESTBENCH
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS scan_benchmark CASCADE;

CREATE TABLE scan_benchmark (
    record_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id      INT NOT NULL,
    category_code  VARCHAR(10) NOT NULL,
    metric_value   NUMERIC(10,2) NOT NULL,
    event_status   VARCHAR(20) NOT NULL,
    payload        TEXT NOT NULL,
    created_at     TIMESTAMP NOT NULL
);

-- Insert 200,000 synthetic rows with deliberate cardinality profiles:
-- - tenant_id: 1 to 2,000 (high selectivity: ~0.05% of rows per tenant)
-- - category_code: 10 distinct values (moderate selectivity: ~10% of rows)
-- - event_status: 3 distinct values (low selectivity: ~33% of rows)
INSERT INTO scan_benchmark (tenant_id, category_code, metric_value, event_status, payload, created_at)
SELECT 
    (i % 2000) + 1,
    'CAT_' || LPAD((i % 10)::TEXT, 2, '0'),
    ROUND((random() * 5000)::numeric, 2),
    CASE (i % 3)
        WHEN 0 THEN 'PENDING'
        WHEN 1 THEN 'PROCESSED'
        ELSE 'ARCHIVED'
    END,
    REPEAT('payload_data_block_', 3),
    NOW() - ((i % 1000) || ' hours')::INTERVAL
FROM generate_series(1, 200000) AS i;

-- Create dedicated indexes:
CREATE INDEX idx_scan_tenant ON scan_benchmark (tenant_id);
CREATE INDEX idx_scan_category ON scan_benchmark (category_code);
CREATE INDEX idx_scan_status ON scan_benchmark (event_status);
CREATE INDEX idx_scan_covering ON scan_benchmark (tenant_id) INCLUDE (metric_value, event_status);

VACUUM ANALYZE scan_benchmark;

-- ----------------------------------------------------------------------------
-- 2. OPERATOR 1: SEQUENTIAL SCAN (LOW SELECTIVITY / BULK ACCESS)
-- ----------------------------------------------------------------------------
-- Scenario: Querying with a low-selectivity filter (~33% of table = ~66,000 rows).
-- PostgreSQL knows that reading 1/3 of the table via random index lookups
-- would thrash the disk cache. It chooses a Sequential Scan instead:

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), AVG(metric_value)
FROM scan_benchmark
WHERE event_status = 'PROCESSED';

-- Observations:
-- 1. Sequential scan reads all heap pages sequentially using large kernel readaheads.
-- 2. On large tables, PostgreSQL automatically spawns a `Parallel Seq Scan` with workers.

-- ----------------------------------------------------------------------------
-- 3. OPERATOR 2: INDEX SCAN (HIGH SELECTIVITY LOOKUP)
-- ----------------------------------------------------------------------------
-- Scenario: Querying for a single tenant (0.05% of rows = ~100 rows out of 200,000).
-- An Index Scan traverses the B-Tree root -> internal -> leaf, retrieves matching
-- `ctid` pointers, and fetches each row directly from the heap.

EXPLAIN (ANALYZE, BUFFERS)
SELECT record_id, category_code, payload
FROM scan_benchmark
WHERE tenant_id = 42;

-- Telemetry Highlights:
-- - Plan Node: `Index Scan using idx_scan_tenant on scan_benchmark`
-- - Very low buffer count (~3-5 pages hit).
-- - Execution time < 0.15 ms.

-- ----------------------------------------------------------------------------
-- 4. OPERATOR 3: BITMAP INDEX SCAN + BITMAP HEAP SCAN
-- ----------------------------------------------------------------------------
-- Scenario: Querying medium selectivity (~10% = 20,000 rows).
-- An Index Scan would make 20,000 random disk jumps (visiting the same page multiple times).
-- A Seq Scan would read 100% of the pages.
--
-- Solution: The Bitmap Scan!
-- Stage 1: `Bitmap Index Scan` scans the index and constructs an in-memory bit array:
--          Bit 1 = page/tuple contains a match; Bit 0 = no match.
-- Stage 2: `Bitmap Heap Scan` reads heap pages in strict ASCENDING PHYSICAL BLOCK ORDER.
--          Each page is fetched at most ONCE, turning random I/O into sequential I/O!

EXPLAIN (ANALYZE, BUFFERS)
SELECT record_id, metric_value, payload
FROM scan_benchmark
WHERE category_code = 'CAT_03';

-- ----------------------------------------------------------------------------
-- 5. COMBINING MULTIPLE INDEXES VIA BITMAPAND & BITMAPOR
-- ----------------------------------------------------------------------------
-- A major superpower of Bitmap Scans: PostgreSQL can combine separate indexes
-- on different columns without needing a composite index!

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM scan_benchmark
WHERE tenant_id = 150 OR category_code = 'CAT_08';

-- Review the plan:
-- -> Bitmap Heap Scan on scan_benchmark
--    -> BitmapOr
--       -> Bitmap Index Scan on idx_scan_tenant
--       -> Bitmap Index Scan on idx_scan_category

-- ----------------------------------------------------------------------------
-- 6. OPERATOR 4: INDEX-ONLY SCAN (HEAP BYPASS)
-- ----------------------------------------------------------------------------
-- When all columns in the `SELECT`, `WHERE`, and `ORDER BY` clauses are present
-- in the index, AND the heap page is marked all-visible in the Visibility Map (`VM`),
-- the engine never touches the table heap at all!

EXPLAIN (ANALYZE, BUFFERS)
SELECT tenant_id, metric_value, event_status
FROM scan_benchmark
WHERE tenant_id = 88;

-- Telemetry Highlights:
-- - Plan Node: `Index Only Scan using idx_scan_covering on scan_benchmark`
-- - `Heap Fetches: 0` (True zero-heap access!).

-- ----------------------------------------------------------------------------
-- 7. THE SELECTIVITY CROSSOVER EXPERIMENT: FORCING THE PLANNER
-- ----------------------------------------------------------------------------
-- What happens if we force an Index Scan on a 33% selectivity query?
-- Let's disable Seq Scan and Bitmap Scan to observe the disastrous cost penalty:

SET enable_seqscan = off;
SET enable_bitmapscan = off;

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), AVG(metric_value)
FROM scan_benchmark
WHERE event_status = 'PROCESSED';

-- Compare execution time:
-- Index Scan forced: ~45 - 80 ms (randomly jumping across 2,000+ heap blocks)
-- Default Seq Scan:  ~12 - 18 ms (streaming read of heap blocks)
--
-- This proves why the planner's refusal to use an index is often the CORRECT decision!

RESET enable_seqscan;
RESET enable_bitmapscan;

-- Clean up:
DROP TABLE IF EXISTS scan_benchmark CASCADE;

