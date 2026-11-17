-- ============================================================================
-- WEEK 4: TOPIC 04 — Cardinality, Selectivity & PostgreSQL Catalog Statistics
-- Description:
-- An index is only useful if the query predicate is SELECTIVE. The PostgreSQL query
-- planner does not guess — it relies on statistics stored in `pg_stats` to compute
-- whether an index scan will be cheaper than a sequential scan.
--
-- Key Concepts Covered:
-- 1. Cardinality (Total rows vs. Distinct values: n_distinct).
-- 2. Selectivity mathematics: Selectivity = (Matching Rows) / (Total Rows).
-- 3. Querying `pg_stats`: Most Common Values (MCV), frequencies, and histograms.
-- 4. The "Tipping Point": Why the planner abandons an index for non-selective queries.
-- 5. Physical correlation (`correlation`): Clustered vs unclustered heap ordering.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. REFRESH CATALOG STATISTICS VIA ANALYZE
-- ----------------------------------------------------------------------------
ANALYZE orders.orders;
ANALYZE orders.order_items;

-- ----------------------------------------------------------------------------
-- 2. INSPECTING `pg_stats` FOR TABLE COLUMNS
-- ----------------------------------------------------------------------------
-- `pg_stats` provides insight into what the planner knows about each column:
--   - `null_frac`: Percentage of null values.
--   - `n_distinct`: If positive, estimated distinct count. If negative, fraction of table.
--   - `most_common_vals`: Array of top frequent values.
--   - `most_common_freqs`: Frequencies of those top values.
--   - `correlation`: Correlation between physical row order and logical value order (-1 to +1).

SELECT 
    schemaname,
    tablename,
    attname AS column_name,
    null_frac,
    avg_width,
    n_distinct,
    correlation,
    most_common_vals::text AS top_values,
    most_common_freqs::text AS top_frequencies
FROM pg_stats
WHERE schemaname = 'orders' 
  AND tablename = 'orders'
  AND attname IN ('order_status', 'customer_id', 'total_amount', 'order_timestamp');

-- ----------------------------------------------------------------------------
-- 3. HIGH SELECTIVITY VS. LOW SELECTIVITY (THE TIPPING POINT)
-- ----------------------------------------------------------------------------
-- In `orders.orders`, let's see the distribution of `order_status`:
SELECT 
    order_status,
    COUNT(*) AS row_count,
    ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER () * 100, 2) AS pct_of_table
FROM orders.orders
GROUP BY order_status
ORDER BY row_count DESC;

-- Ensure an index exists on `order_status`:
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders.orders (order_status);

-- Case A: LOW SELECTIVITY (e.g. 'delivered' represents ~60-70% of rows)
-- Selectivity is low (matches a huge percentage of rows).
-- Visiting 60% of rows via index would cause thousands of random page fetches!
-- PostgreSQL chooses a SEQUENTIAL SCAN instead:

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, total_amount
FROM orders.orders
WHERE order_status = 'delivered';

-- Look at the plan: Notice "Seq Scan on orders" even though the index exists!

-- Case B: HIGH SELECTIVITY (e.g. 'cancelled' or rare status representing < 5% of rows)
-- Selectivity is high (matches very few rows).
-- Visiting < 5% of rows via index is significantly cheaper than scanning the entire table:

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, total_amount
FROM orders.orders
WHERE order_status = 'cancelled';

-- Look at the plan: Notice "Bitmap Index Scan on idx_orders_status" or "Index Scan"!
-- The exact same index was ignored for 'delivered' but chosen for 'cancelled'!

-- ----------------------------------------------------------------------------
-- 4. UNDERSTANDING PHYSICAL CORRELATION (CORRELATION COLUMN)
-- ----------------------------------------------------------------------------
-- Correlation measures whether values are ordered monotonically on disk pages:
--   1.0  = Rows are stored in exact sorted order on disk.
--   0.0  = Rows are completely randomly scattered across disk blocks.
--  -1.0  = Rows are stored in exact reverse order on disk.

SELECT 
    attname AS column_name,
    correlation
FROM pg_stats
WHERE schemaname = 'orders' 
  AND tablename = 'orders'
ORDER BY ABS(correlation) DESC;

-- Why correlation matters:
-- If correlation is close to 1.0 (e.g. `order_id` or `order_timestamp`), an index scan
-- reads heap pages sequentially.
-- If correlation is near 0.0 (e.g. `customer_id` or UUID), an index scan jumps back
-- and forth randomly across disk pages, causing high I/O latency!

-- ----------------------------------------------------------------------------
-- 5. TUNING STATISTICAL ACCURACY: DEFAULT_STATISTICS_TARGET
-- ----------------------------------------------------------------------------
-- If the planner frequently misestimates row counts for skewed columns,
-- you can raise the sample size for that specific column:

ALTER TABLE orders.orders ALTER COLUMN order_status SET STATISTICS 500;
ANALYZE orders.orders;

-- Verify histogram or MCV sample expansion:
SELECT attname, array_length(most_common_vals::text::text[], 1) AS mcv_count
FROM pg_stats
WHERE schemaname = 'orders' AND tablename = 'orders' AND attname = 'order_status';

-- Reset statistics target back to default (100):
ALTER TABLE orders.orders ALTER COLUMN order_status SET STATISTICS DEFAULT;
ANALYZE orders.orders;
