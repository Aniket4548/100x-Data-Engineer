-- ============================================================================
-- 100x DATA ENGINEER: WEEK 5 — CHAPTER 6
-- File: 06_cardinality_estimation_and_statistics.sql
-- Topic: Cardinality Estimation, pg_stats & Extended Statistics
-- ============================================================================
-- Description:
-- Cardinality Estimation is the brain of the Cost-Based Optimizer.
-- If the planner estimates that a scan will return 5 rows, it chooses an Index
-- Scan and a Nested Loop. If it knows the scan will return 50,000 rows, it chooses
-- a Sequential Scan and a Hash Join.
--
-- A misestimate of 10x at the table scan layer can compound into a 1,000x disaster
-- at the top of the join tree.
--
-- Key Concepts Covered:
-- 1. Inspecting `pg_stats`: `null_frac`, `n_distinct`, MCV lists, and Histograms.
-- 2. Selectivity calculation mechanics for equality and range queries.
-- 3. The Cardinality Misestimate Snowball: Why underestimating causes bad join choices.
-- 4. The Independence Assumption failure on correlated columns.
-- 5. Fixing estimation errors with Extended Statistics (`CREATE STATISTICS`).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. INSPECTING POSTGRESQL'S COLUMN STATISTICS CATALOG
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS stats_demo CASCADE;

CREATE TABLE stats_demo (
    car_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    make VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    body_style VARCHAR(30) NOT NULL,
    model_year INT NOT NULL,
    odometer_miles INT NOT NULL
);

-- Insert 100,000 synthetic vehicles with strong real-world column correlations:
-- - If make = 'Porsche', model is always '911' or 'Cayenne'
-- - If make = 'Audi', model is always 'A4' or 'Q7'
INSERT INTO stats_demo (make, model, body_style, model_year, odometer_miles)
SELECT 
    CASE (i % 5)
        WHEN 0 THEN 'Porsche'
        WHEN 1 THEN 'Audi'
        WHEN 2 THEN 'BMW'
        WHEN 3 THEN 'Toyota'
        ELSE 'Honda'
    END AS make,
    CASE (i % 5)
        WHEN 0 THEN CASE WHEN (i % 2) = 0 THEN '911' ELSE 'Cayenne' END
        WHEN 1 THEN CASE WHEN (i % 2) = 0 THEN 'A4' ELSE 'Q7' END
        WHEN 2 THEN CASE WHEN (i % 2) = 0 THEN 'M3' ELSE 'X5' END
        WHEN 3 THEN CASE WHEN (i % 2) = 0 THEN 'Camry' ELSE 'RAV4' END
        ELSE CASE WHEN (i % 2) = 0 THEN 'Civic' ELSE 'CR-V' END
    END AS model,
    CASE (i % 3) WHEN 0 THEN 'Sedan' WHEN 1 THEN 'SUV' ELSE 'Coupe' END,
    2015 + (i % 10),
    (i % 150000)
FROM generate_series(1, 100000) AS i;

VACUUM ANALYZE stats_demo;

-- Inspect pg_stats for `make` and `model`:
SELECT 
    schemaname, 
    tablename, 
    attname AS column_name, 
    null_frac, 
    n_distinct, 
    most_common_vals, 
    most_common_freqs, 
    correlation
FROM pg_stats
WHERE tablename = 'stats_demo' 
  AND attname IN ('make', 'model', 'model_year');

-- ----------------------------------------------------------------------------
-- 2. THE INDEPENDENCE ASSUMPTION FAILURE DEMONSTRATION
-- ----------------------------------------------------------------------------
-- When querying: `WHERE make = 'Porsche' AND model = '911'`
-- Real world: 10,000 rows match (10% of table).
--
-- How PostgreSQL calculates it WITHOUT extended stats:
--   P(make = 'Porsche') = 0.20 (20%)
--   P(model = '911') = 0.10 (10%)
--   Assumed Joint Probability = 0.20 * 0.10 = 0.02 (2% = 2,000 rows)
-- The planner expects 2,000 rows, but actual is 10,000 rows (a 5x error)!

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM stats_demo
WHERE make = 'Porsche' AND model = '911';

-- Notice:
-- rows=2000 (estimated) vs actual rows=10000 (500% misestimate!)

-- ----------------------------------------------------------------------------
-- 3. SOLVING MISCARDINALITY WITH EXTENDED MULTIVARIATE STATISTICS
-- ----------------------------------------------------------------------------
-- Create Extended Statistics object:
CREATE STATISTICS stats_car_make_model (dependencies, ndistinct, mcv) 
ON make, model FROM stats_demo;

-- Re-run ANALYZE to compute multi-column statistics:
ANALYZE stats_demo;

-- Verify the extended statistics catalog:
SELECT 
    stxname, 
    stxkeys, 
    stxkind 
FROM pg_statistic_ext
WHERE stxname = 'stats_car_make_model';

-- Re-run the exact same query:
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM stats_demo
WHERE make = 'Porsche' AND model = '911';

-- TELEMETRY COMPARISON:
-- Before Extended Stats: Estimated Rows = 2,000 | Actual Rows = 10,000 (500% error)
-- After Extended Stats:  Estimated Rows = 10,000 | Actual Rows = 10,000 (0% error — EXACT!)

-- Clean up:
DROP TABLE IF EXISTS stats_demo CASCADE;

