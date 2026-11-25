-- ============================================================================
-- 100x DATA ENGINEER: WEEK 5 — CHAPTER 2
-- File: 02_explain_and_cost_model.sql
-- Topic: Reading and Deconstructing Execution Plans & Cost Model Arithmetic
-- ============================================================================
-- Description:
-- Mastering `EXPLAIN (ANALYZE, BUFFERS)` is the central technical skill of query
-- optimization. This script covers:
--
--   1. Full syntax of `EXPLAIN` with modern PostgreSQL options.
--   2. Decoding cost units: Startup cost, Total cost, Rows, and Width.
--   3. Actual execution metrics: Actual time, actual rows, and the `loops` multiplier.
--   4. Shared Buffers telemetry: hit, read, dirtied, written, and temp files.
--   5. Verifying the Cost Model arithmetic mathematically down to the decimal point.
--   6. Planning time vs Execution time and Prepared Statements.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. INSPECT POSTGRESQL'S CORE COST PARAMETERS
-- ----------------------------------------------------------------------------
-- Costs are measured in arbitrary units, anchored to `seq_page_cost = 1.0`
-- (the estimated cost of reading one 8 KB disk page sequentially).

SELECT 
    name, 
    setting, 
    unit, 
    short_desc 
FROM pg_settings 
WHERE name IN (
    'seq_page_cost',        -- Sequential disk page fetch (baseline: 1.0)
    'random_page_cost',     -- Random disk page fetch (default: 4.0; SSD: 1.1)
    'cpu_tuple_cost',       -- CPU cost to process one tuple header (default: 0.01)
    'cpu_index_tuple_cost', -- CPU cost to process one index entry (default: 0.005)
    'cpu_operator_cost',    -- CPU cost to evaluate an operator/qual (default: 0.0025)
    'parallel_tuple_cost',  -- CPU cost to transfer a tuple between workers (0.1)
    'parallel_setup_cost'   -- Startup cost to launch worker processes (1000.0)
)
ORDER BY name;

-- ----------------------------------------------------------------------------
-- 2. SETUP CONTROLLED TEST TABLE FOR MATHEMATICAL VERIFICATION
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS cost_verification_table CASCADE;

CREATE TABLE cost_verification_table AS
SELECT 
    i AS id,
    'user_' || (i % 1000) AS username,
    (i % 50) AS status_code,
    ROUND((random() * 1000)::numeric, 2) AS score,
    clock_timestamp() - (i || ' minutes')::interval AS created_at
FROM generate_series(1, 100000) AS i;

-- Vacuum and analyze to compute exact catalog pages and tuple counts:
VACUUM ANALYZE cost_verification_table;

-- Inspect physical table size in pages and rows:
SELECT 
    relname, 
    relpages, 
    reltuples 
FROM pg_class 
WHERE relname = 'cost_verification_table';

-- ----------------------------------------------------------------------------
-- 3. VERIFYING THE PLANNER'S COST FORMULA WITH REAL ARITHMETIC
-- ----------------------------------------------------------------------------
-- Let's trace how PostgreSQL calculates the cost of:
--   SELECT * FROM cost_verification_table WHERE status_code = 10;
--
-- Suppose relpages = 736 and reltuples = 100,000:
--   1. Page I/O Cost:
--      736 pages * seq_page_cost (1.0) = 736.00
--   2. Tuple CPU Cost:
--      100,000 tuples * cpu_tuple_cost (0.01) = 1000.00
--   3. Filter Operator CPU Cost:
--      100,000 evaluations * cpu_operator_cost (0.0025) = 250.00
--   Total Estimated Cost:
--      736.00 + 1000.00 + 250.00 = 1986.00

EXPLAIN (COSTS, BUFFERS)
SELECT * 
FROM cost_verification_table 
WHERE status_code = 10;

-- Notice how the estimated cost in the output matches the exact theoretical calculation!

-- ----------------------------------------------------------------------------
-- 4. THE LOOPS MULTIPLIER RULE IN EXPLAIN ANALYZE
-- ----------------------------------------------------------------------------
-- When an execution node has `loops=N`, the values for `rows` and `actual time`
-- are AVERAGES per single loop iteration!
--
-- Create an index to observe an Index Scan executed in a loop:
CREATE INDEX idx_cost_status ON cost_verification_table (status_code);
VACUUM ANALYZE cost_verification_table;

EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id, c.score
FROM generate_series(1, 10) AS s(status_target)
JOIN cost_verification_table c ON c.status_code = s.status_target;

-- INTERPRETATION OF THE OUTPUT:
-- If the inner Index Scan reports:
--   (actual time=0.015..0.045 rows=2000 loops=10)
--
--   1. Total rows emitted by inner scan = 2000 * 10 = 20,000 rows!
--   2. Total time spent in inner scan = 0.045 ms * 10 = 0.45 ms!
-- Always multiply by `loops` when calculating total resource consumption.

-- ----------------------------------------------------------------------------
-- 5. BUFFER CACHE TELEMETRY: HIT VS READ VS TEMPORARY FILES
-- ----------------------------------------------------------------------------
-- The `BUFFERS` option reveals where pages were fetched:
--   - shared hit: Found in PostgreSQL RAM (shared_buffers)
--   - shared read: Read from Operating System cache or physical NVMe/SSD disk
--   - shared dirtied: Modified in memory by this query
--   - temp read / written: Written to temporary disk files (work_mem exceeded!)

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT status_code, COUNT(*), AVG(score)
FROM cost_verification_table
GROUP BY status_code;

-- ----------------------------------------------------------------------------
-- 6. PLANNING TIME VS EXECUTION TIME & PREPARED STATEMENTS
-- ----------------------------------------------------------------------------
-- Analytical queries with 10+ joins can suffer from query planning latency.
-- In high-throughput OLTP, if Planning Time > Execution Time, use PREPARED STATEMENTS
-- to parse and plan the query once, then execute repeatedly with zero planning overhead:

PREPARE fetch_user_score(int) AS
SELECT id, username, score
FROM cost_verification_table
WHERE id = $1;

-- Execute the cached plan:
EXECUTE fetch_user_score(42);
EXECUTE fetch_user_score(105);

DEALLOCATE fetch_user_score;

-- Clean up:
DROP TABLE IF EXISTS cost_verification_table CASCADE;

