-- ============================================================================
-- 100x DATA ENGINEER: WEEK 5 — CHAPTER 5
-- File: 05_sort_operations_and_work_mem.sql
-- Topic: Sort Operations, Memory Management & work_mem Tuning
-- ============================================================================
-- Description:
-- Sorting is one of the most CPU- and memory-intensive operations in database
-- engineering. Unoptimized sorts that spill from RAM to disk can degrade query
-- latency by 10x to 100x.
--
-- Sort Methods in PostgreSQL:
--   1. top-N heapsort: Used when `ORDER BY ... LIMIT N` is present. Maintains a
--      bounded priority queue (heap) of size N in memory. Extremely fast ($O(K \log N)$).
--   2. quicksort: In-memory sorting used when all tuples fit within `work_mem`.
--   3. external merge Disk: External sort used when tuples exceed `work_mem`.
--      Spills sorted runs to temporary disk files and merges them in multi-pass I/O.
--   4. Incremental Sort (PG 13+): Capitalizes on partially presorted data streams.
--
-- Key Concepts Covered:
-- 1. Identifying the three sort methods in `EXPLAIN (ANALYZE, BUFFERS)`.
-- 2. Monitoring disk temporary files (`temp read`, `temp written`, `Disk: X kB`).
-- 3. The `work_mem` allocation formula and why high global `work_mem` causes OOM.
-- 4. Safe session-level and transaction-level `work_mem` optimization.
-- 5. Eliminating sort nodes entirely using B-Tree index ordering.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SETUP EXPERIMENTAL TESTBENCH
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS sort_benchmark CASCADE;

CREATE TABLE sort_benchmark (
    log_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    server_id INT NOT NULL,
    service_name VARCHAR(50) NOT NULL,
    response_time_ms NUMERIC(8,2) NOT NULL,
    payload_dump TEXT NOT NULL,
    logged_at TIMESTAMP NOT NULL
);

-- Insert 100,000 logs with wide payloads (~150 bytes per row):
INSERT INTO sort_benchmark (server_id, service_name, response_time_ms, payload_dump, logged_at)
SELECT 
    (i % 50) + 1,
    'service_' || (i % 10),
    ROUND((random() * 2500)::numeric, 2),
    REPEAT('metric_log_trace_data_chunk_', 3),
    NOW() - ((i % 10000) || ' minutes')::INTERVAL
FROM generate_series(1, 100000) AS i;

VACUUM ANALYZE sort_benchmark;

-- ----------------------------------------------------------------------------
-- 2. SORT METHOD 1: TOP-N HEAPSORT (BOUNDED LIMIT)
-- ----------------------------------------------------------------------------
-- When ordering by a column but requesting only the top N rows (e.g. `LIMIT 10`),
-- PostgreSQL does NOT sort all 100,000 rows. It maintains a bounded heap of size 10 in RAM.

EXPLAIN (ANALYZE, BUFFERS)
SELECT log_id, response_time_ms, service_name
FROM sort_benchmark
ORDER BY response_time_ms DESC
LIMIT 10;

-- Telemetry Highlights:
-- -> Limit
--    -> Sort (cost=... rows=100000 width=...)
--         Sort Key: response_time_ms DESC
--         Sort Method: top-N heapsort  Memory: 26kB
--
-- Notice:
-- Even though 100,000 rows were scanned, memory consumption was only 26 kB!

-- ----------------------------------------------------------------------------
-- 3. SORT METHOD 2: IN-MEMORY QUICKSORT
-- ----------------------------------------------------------------------------
-- When sorting the entire dataset, and `work_mem` is large enough to hold all
-- rows, PostgreSQL uses an in-memory Quicksort.

SET work_mem = '64MB';

EXPLAIN (ANALYZE, BUFFERS)
SELECT log_id, server_id, response_time_ms, logged_at
FROM sort_benchmark
ORDER BY response_time_ms DESC;

-- Telemetry Highlights:
-- -> Sort
--      Sort Key: response_time_ms DESC
--      Sort Method: quicksort  Memory: 7850kB
-- All 7.85 MB of sorted tuples fit in RAM with zero disk spills.

-- ----------------------------------------------------------------------------
-- 4. SORT METHOD 3: EXTERNAL MERGE DISK (THE PERFORMANCE KILLER)
-- ----------------------------------------------------------------------------
-- When `work_mem` is constrained (default is often 4MB), sorting large or wide
-- datasets spills to disk.

SET work_mem = '512kB';

EXPLAIN (ANALYZE, BUFFERS)
SELECT log_id, server_id, response_time_ms, payload_dump
FROM sort_benchmark
ORDER BY response_time_ms DESC;

-- Telemetry Breakdown of Disk Spill:
-- -> Sort
--      Sort Key: response_time_ms DESC
--      Sort Method: external merge  Disk: 9480kB
--      Buffers: shared hit=1250, temp read=1185 written=1190
--
-- Consequences:
-- 1. `Disk: 9480kB`: 9.5 MB written to disk temp files and read back.
-- 2. `temp read=1185 written=1190`: 2,375 temporary disk buffer page operations.
-- 3. High latency penalty due to disk I/O.

-- ----------------------------------------------------------------------------
-- 5. SAFELY TUNING `work_mem` IN PRODUCTION
-- ----------------------------------------------------------------------------
-- CAUTION: `work_mem` is allocated per sort/hash operation, PER query, PER connection!
-- Setting `work_mem` globally too high will cause Linux Out-Of-Memory (OOM) Killer panic.
--
-- BEST PRACTICE: Elevate `work_mem` dynamically at the TRANSACTION level:

BEGIN;
  -- Elevate work_mem ONLY for this heavy reporting transaction:
  SET LOCAL work_mem = '128MB';

  -- Run the heavy query in RAM:
  SELECT service_name, AVG(response_time_ms), COUNT(*)
  FROM sort_benchmark
  GROUP BY service_name
  ORDER BY AVG(response_time_ms) DESC;
COMMIT;
-- Automatically reverts back to default upon COMMIT!

-- ----------------------------------------------------------------------------
-- 6. ELIMINATING THE SORT ENTIRELY VIA B-TREE INDEX
-- ----------------------------------------------------------------------------
-- The best sort is the sort you NEVER perform.
-- A B-Tree index stores keys in pre-sorted order. An Index Scan can read them
-- in exact order with ZERO sorting overhead!

CREATE INDEX idx_sort_response_time ON sort_benchmark (response_time_ms DESC);
VACUUM ANALYZE sort_benchmark;

EXPLAIN (ANALYZE, BUFFERS)
SELECT log_id, server_id, response_time_ms
FROM sort_benchmark
ORDER BY response_time_ms DESC
LIMIT 50;

-- Notice:
-- The `Sort` node is 100% GONE! Execution time is < 0.08 ms!

RESET work_mem;
DROP TABLE IF EXISTS sort_benchmark CASCADE;

