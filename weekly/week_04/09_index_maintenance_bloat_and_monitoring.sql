-- ============================================================================
-- WEEK 4: TOPIC 09 — Index Maintenance, Bloat & Operational Monitoring
-- Description:
-- Indexes are not free. Every index created imposes a write penalty on INSERT,
-- UPDATE, and DELETE operations (Write Amplification). Over time, repeated
-- updates cause B-Tree page splits and index bloat.
--
-- Key Concepts Covered:
-- 1. Detecting unused indexes using `pg_stat_user_indexes`.
-- 2. Detecting redundant / duplicate indexes.
-- 3. Write Amplification benchmark: Measuring INSERT speed with 0 vs 5 indexes.
-- 4. Index bloat remediation: REINDEX and REINDEX CONCURRENTLY.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. IDENTIFYING UNUSED INDEXES (CANDIDATES FOR REMOVAL)
-- ----------------------------------------------------------------------------
-- In production, unused indexes waste RAM, disk space, and slow down writes.
-- Query `pg_stat_user_indexes` where `idx_scan = 0`:

SELECT 
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS number_of_scans,
    idx_tup_read AS tuples_read_from_index,
    idx_tup_fetch AS tuples_fetched_from_heap,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname IN ('orders', 'customer', 'catalog', 'logistics', 'dwh')
ORDER BY idx_scan ASC, pg_relation_size(indexrelid) DESC;

-- Rule of Thumb:
-- If `idx_scan = 0` on a table with millions of transactions over 30 days,
-- and it is NOT a primary key / unique constraint, DROP IT!

-- ----------------------------------------------------------------------------
-- 2. DETECTING DUPLICATE & REDUNDANT INDEXES
-- ----------------------------------------------------------------------------
-- If you have an index on `(customer_id, order_timestamp)`, an index on
-- `(customer_id)` ALONE is usually redundant because the composite index's
-- leftmost prefix satisfies queries on `customer_id`.

SELECT 
    t.relname AS table_name,
    i1.relname AS index_1,
    i2.relname AS index_2,
    pg_get_indexdef(i1.oid) AS def_1,
    pg_get_indexdef(i2.oid) AS def_2
FROM pg_index x1
JOIN pg_index x2 ON x1.indrelid = x2.indrelid AND x1.indexrelid <> x2.indexrelid
JOIN pg_class i1 ON i1.oid = x1.indexrelid
JOIN pg_class i2 ON i2.oid = x2.indexrelid
JOIN pg_class t ON t.oid = x1.indrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE n.nspname IN ('orders', 'customer', 'catalog', 'dwh')
  -- Condition where index 1 leading column matches index 2 leading column
  AND x1.indkey[0] = x2.indkey[0]
  AND x1.indexrelid < x2.indexrelid;

-- ----------------------------------------------------------------------------
-- 3. WRITE AMPLIFICATION BENCHMARK: 0 INDEXES VS. 5 INDEXES
-- ----------------------------------------------------------------------------
-- Let's empirically test the write penalty imposed by indexes.

-- Setup clean test tables in public schema:
DROP TABLE IF EXISTS public.bench_no_indexes;
DROP TABLE IF EXISTS public.bench_with_indexes;

CREATE TABLE public.bench_no_indexes (
    id INT,
    val_a INT,
    val_b VARCHAR(50),
    val_c TIMESTAMP,
    val_d NUMERIC(10,2)
);

CREATE TABLE public.bench_with_indexes (
    id INT,
    val_a INT,
    val_b VARCHAR(50),
    val_c TIMESTAMP,
    val_d NUMERIC(10,2)
);

-- Add 5 indexes to the second table:
CREATE INDEX idx_bwi_id ON public.bench_with_indexes (id);
CREATE INDEX idx_bwi_a ON public.bench_with_indexes (val_a);
CREATE INDEX idx_bwi_b ON public.bench_with_indexes (val_b);
CREATE INDEX idx_bwi_c ON public.bench_with_indexes (val_c);
CREATE INDEX idx_bwi_d ON public.bench_with_indexes (val_d);

-- Benchmark INSERT of 20,000 rows into table WITHOUT indexes:
DO $$
DECLARE
    t_start TIMESTAMP;
    t_end TIMESTAMP;
BEGIN
    t_start := clock_timestamp();
    
    INSERT INTO public.bench_no_indexes
    SELECT 
        g,
        (g % 500),
        'Product ' || g,
        NOW() - (g || ' minutes')::interval,
        (g * 1.5)::numeric(10,2)
    FROM generate_series(1, 20000) g;
    
    t_end := clock_timestamp();
    RAISE NOTICE 'Insert without indexes duration: %', (t_end - t_start);
END $$;

-- Benchmark INSERT of identical 20,000 rows into table WITH 5 indexes:
DO $$
DECLARE
    t_start TIMESTAMP;
    t_end TIMESTAMP;
BEGIN
    t_start := clock_timestamp();
    
    INSERT INTO public.bench_with_indexes
    SELECT 
        g,
        (g % 500),
        'Product ' || g,
        NOW() - (g || ' minutes')::interval,
        (g * 1.5)::numeric(10,2)
    FROM generate_series(1, 20000) g;
    
    t_end := clock_timestamp();
    RAISE NOTICE 'Insert WITH 5 indexes duration: %', (t_end - t_start);
END $$;

-- Compare the durations in the Messages/Output tab:
-- The table with 5 indexes will typically take 3x to 5x LONGER to insert!

-- Cleanup benchmark tables:
DROP TABLE IF EXISTS public.bench_no_indexes;
DROP TABLE IF EXISTS public.bench_with_indexes;

-- ----------------------------------------------------------------------------
-- 4. REBUILDING BLOATED INDEXES: REINDEX
-- ----------------------------------------------------------------------------
-- Over time, heavy updates and page splits cause B-Trees to fragment and bloat.
-- REINDEX rebuilds the B-Tree from scratch, compacting pages to the default fillfactor (90%).

-- Standard REINDEX (Locks table writes):
-- REINDEX TABLE orders.orders;

-- Production Non-Blocking REINDEX (PostgreSQL 12+):
-- REINDEX TABLE CONCURRENTLY orders.orders;
