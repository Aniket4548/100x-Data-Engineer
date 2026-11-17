-- ============================================================================
-- WEEK 4: TOPIC 10 — End-to-End Index Performance Case Study
-- Description:
-- The Week 4 Capstone Exercise: Optimizing a mission-critical analytical &
-- operational query through four distinct architectural stages:
--
--   STAGE 1: Baseline Execution (No Dedicated Index — Sequential Scan)
--   STAGE 2: Single-Column Index (Bitmap / Index Scan with Residual Filter)
--   STAGE 3: Composite Index (Equality + Range + Sort Optimization)
--   STAGE 4: Covering Index with INCLUDE (Index-Only Scan, Heap Fetches = 0)
--
-- Follow along, execute each stage, and record the telemetry in the scorecard at
-- the bottom of the script.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. THE BUSINESS SCENARIO & TARGET QUERY
-- ----------------------------------------------------------------------------
-- Context:
-- An e-commerce VIP Customer Portal powers a dashboard widget:
-- "Show the customer's top 10 purchased items within a date window, displaying
--  product, quantity, line total, and order date, sorted by date descending."
--
-- Target Table: `dwh.fact_sales_order_lines` (30,000 rows)
-- Query Predicates:
--   - Filter 1 (Equality): `customer_fk = 142`
--   - Filter 2 (Range):    `order_date_fk >= 20240101`
--   - Projection:         `order_item_id, order_date_fk, product_fk, quantity, net_sales_amount`
--   - Order:              `ORDER BY order_date_fk DESC LIMIT 10`

-- Clean up any prior case study indexes:
DROP INDEX IF EXISTS dwh.idx_case_single;
DROP INDEX IF EXISTS dwh.idx_case_composite;
DROP INDEX IF EXISTS dwh.idx_case_covering;

-- ----------------------------------------------------------------------------
-- STAGE 1: BASELINE EXECUTION (NO DEDICATED INDEX)
-- ----------------------------------------------------------------------------
-- Drop existing customer index temporarily to observe the raw unindexed baseline:
DROP INDEX IF EXISTS dwh.idx_fact_sales_customer;

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    order_item_id,
    order_date_fk,
    product_fk,
    quantity,
    net_sales_amount
FROM dwh.fact_sales_order_lines
WHERE customer_fk = 142
  AND order_date_fk >= 20240101
ORDER BY order_date_fk DESC
LIMIT 10;

/*
STAGE 1 TELEMETRY RECORD:
- Scan Type:          Seq Scan on fact_sales_order_lines
- Sort Method:        quicksort / top-N heapsort
- Shared Buffers Hit: All ~400+ table heap blocks read
- Execution Time:     ~3.5 - 8.0 ms
- Observation:        Database had to inspect every single row in the warehouse table!
*/

-- ----------------------------------------------------------------------------
-- STAGE 2: SINGLE-COLUMN INDEX
-- ----------------------------------------------------------------------------
-- We add an index on the primary customer filter:
CREATE INDEX idx_case_single 
ON dwh.fact_sales_order_lines (customer_fk);

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    order_item_id,
    order_date_fk,
    product_fk,
    quantity,
    net_sales_amount
FROM dwh.fact_sales_order_lines
WHERE customer_fk = 142
  AND order_date_fk >= 20240101
ORDER BY order_date_fk DESC
LIMIT 10;

/*
STAGE 2 TELEMETRY RECORD:
- Scan Type:          Bitmap Index Scan / Index Scan using idx_case_single
- Filter / Recheck:   Filter: (order_date_fk >= 20240101)
- Sort Method:        Sort node still required (Sort Key: order_date_fk DESC)
- Shared Buffers Hit: ~15 - 30 blocks
- Execution Time:     ~0.3 - 0.8 ms (5x - 10x faster than Stage 1)
- Bottlenecks Remaining:
  1. Residual filtering: Must fetch rows to evaluate order_date_fk.
  2. In-memory Sort: Must sort matching rows by date.
*/

-- ----------------------------------------------------------------------------
-- STAGE 3: COMPOSITE INDEX (EQUALITY + RANGE + SORT)
-- ----------------------------------------------------------------------------
-- Applying the Golden Rule: Equality first (`customer_fk`), then Range/Sort (`order_date_fk DESC`):
CREATE INDEX idx_case_composite 
ON dwh.fact_sales_order_lines (customer_fk, order_date_fk DESC);

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    order_item_id,
    order_date_fk,
    product_fk,
    quantity,
    net_sales_amount
FROM dwh.fact_sales_order_lines
WHERE customer_fk = 142
  AND order_date_fk >= 20240101
ORDER BY order_date_fk DESC
LIMIT 10;

/*
STAGE 3 TELEMETRY RECORD:
- Scan Type:          Index Scan using idx_case_composite
- Sort Method:        NONE! (Eliminated in-memory sort!)
- Shared Buffers Hit: ~5 - 10 blocks (Index pages + matched Heap pages)
- Execution Time:     ~0.08 - 0.20 ms
- Bottlenecks Remaining:
  - Must still visit the heap table pages to retrieve `product_fk`, `quantity`, `net_sales_amount`.
*/

-- ----------------------------------------------------------------------------
-- STAGE 4: COVERING INDEX (INCLUDE PAYLOAD COLUMNS)
-- ----------------------------------------------------------------------------
-- Store search/sort keys in the B-Tree root/branch/leaf, and append payload
-- columns directly to the leaf pages using `INCLUDE`:
CREATE INDEX idx_case_covering 
ON dwh.fact_sales_order_lines (customer_fk, order_date_fk DESC)
INCLUDE (order_item_id, product_fk, quantity, net_sales_amount);

-- Ensure statistics and visibility map are updated:
-- In psql/DBeaver autocommit mode, run: VACUUM ANALYZE dwh.fact_sales_order_lines;
ANALYZE dwh.fact_sales_order_lines;

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    order_item_id,
    order_date_fk,
    product_fk,
    quantity,
    net_sales_amount
FROM dwh.fact_sales_order_lines
WHERE customer_fk = 142
  AND order_date_fk >= 20240101
ORDER BY order_date_fk DESC
LIMIT 10;

/*
STAGE 4 TELEMETRY RECORD:
- Scan Type:          Index Only Scan using idx_case_covering
- Heap Fetches:       0 (Zero heap accesses!)
- Sort Method:        NONE
- Shared Buffers Hit: 2 - 3 blocks (B-tree pages only!)
- Execution Time:     ~0.03 - 0.06 ms
- Speedup vs Stage 1: ~50x to 100x faster!
*/

-- ----------------------------------------------------------------------------
-- 5. RESTORE STANDARD ENVIRONMENT & CLEANUP
-- ----------------------------------------------------------------------------
DROP INDEX IF EXISTS dwh.idx_case_single;
DROP INDEX IF EXISTS dwh.idx_case_composite;
DROP INDEX IF EXISTS dwh.idx_case_covering;

-- Recreate standard foreign key index for dwh:
CREATE INDEX IF NOT EXISTS idx_fact_sales_customer 
ON dwh.fact_sales_order_lines (customer_fk);

-- ----------------------------------------------------------------------------
-- 6. CASE STUDY SUMMARY PERFORMANCE SCORECARD
-- ----------------------------------------------------------------------------
/*
+--------------------+---------------------+---------------+--------------+--------------+
| Indexing Strategy  | Access Plan Node    | Heap Fetches  | Buffers Hit  | Latency (ms) |
+--------------------+---------------------+---------------+--------------+--------------+
| 1. No Index        | Seq Scan + Sort     | All Pages     | ~450 pages   | ~5.50 ms     |
| 2. Single-Column   | Index Scan + Sort   | Filtered Rows | ~25 pages    | ~0.65 ms     |
| 3. Composite       | Index Scan (No Sort)| Matched Rows  | ~8 pages     | ~0.15 ms     |
| 4. Covering Index  | Index Only Scan     | 0 (Zero!)     | 2-3 pages    | ~0.04 ms     |
+--------------------+---------------------+---------------+--------------+--------------+
Key Takeaways:
1. Moving from Seq Scan to Index Scan eliminates the vast majority of disk I/O.
2. Composite indexes that match ORDER BY eliminate the CPU cost of sorting.
3. Covering indexes (INCLUDE) eliminate heap visits entirely, achieving sub-millisecond latencies.
*/
