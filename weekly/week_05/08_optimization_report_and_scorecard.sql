-- ============================================================================
-- 100x DATA ENGINEER: WEEK 5 — CHAPTER 8
-- File: 08_optimization_report_and_scorecard.sql
-- Topic: Build: Before/After Optimization Report & Benchmark Scorecard
-- ============================================================================
-- Description:
-- The final capstone deliverable of Week 5: A comprehensive, data-driven
-- optimization report evaluating the 10 Deliberately Bad Queries benchmarked in
-- Chapter 7 (`07_ten_bad_queries_and_optimizations.sql`).
--
-- This script:
--   1. Computes macro-level performance metrics (latency reduction, buffer reduction).
--   2. Renders the Executive Optimization Scorecard.
--   3. Generates a SQL-driven ASCII visual latency comparison chart.
--   4. Provides an automated Query Triage & Remediation Matrix for production.
-- ============================================================================

SET search_path TO tuning_bench, public;

-- ----------------------------------------------------------------------------
-- 1. EXECUTIVE MACRO-LEVEL PERFORMANCE METRICS
-- ----------------------------------------------------------------------------
SELECT 
    COUNT(*) AS total_queries_optimized,
    ROUND(SUM(baseline_latency_ms), 2) AS total_baseline_latency_ms,
    ROUND(SUM(optimized_latency_ms), 2) AS total_optimized_latency_ms,
    ROUND(
        ((SUM(baseline_latency_ms) - SUM(optimized_latency_ms)) / SUM(baseline_latency_ms)) * 100, 
        2
    ) AS total_latency_reduction_pct,
    ROUND(SUM(baseline_latency_ms) / NULLIF(SUM(optimized_latency_ms), 0), 2) AS aggregate_workload_speedup,
    SUM(baseline_buffers) AS total_baseline_buffers,
    SUM(optimized_buffers) AS total_optimized_buffers,
    ROUND(
        ((SUM(baseline_buffers) - SUM(optimized_buffers))::numeric / SUM(baseline_buffers)) * 100, 
        2
    ) AS total_buffer_io_reduction_pct,
    COUNT(*) FILTER (WHERE disk_spill_eliminated = TRUE) AS disk_spills_eliminated
FROM optimization_scorecard;

-- ----------------------------------------------------------------------------
-- 2. DETAILED QUERY-BY-QUERY SCORECARD
-- ----------------------------------------------------------------------------
SELECT 
    query_id,
    query_name,
    anti_pattern_category,
    baseline_latency_ms,
    optimized_latency_ms,
    speedup_factor || 'x' AS speedup,
    baseline_buffers,
    optimized_buffers,
    buffer_reduction_pct || '%' AS io_reduction,
    optimization_strategy
FROM optimization_scorecard
ORDER BY query_id ASC;

-- ----------------------------------------------------------------------------
-- 3. SQL-RENDERED VISUAL ASCII LATENCY COMPARISON CHART
-- ----------------------------------------------------------------------------
-- Visual representation of the dramatic latency collapse across all 10 queries:
SELECT 
    LPAD(query_id::text, 2, '0') || '. ' || RPAD(query_name, 30, ' ') AS query_label,
    RPAD(REPEAT('█', LEAST(50, GREATEST(1, (baseline_latency_ms / 3)::int))), 50, ' ') || 
    ' [' || LPAD(baseline_latency_ms::text, 6, ' ') || ' ms]' AS baseline_chart,
    RPAD(REPEAT('▓', LEAST(50, GREATEST(1, (optimized_latency_ms / 3)::int))), 50, ' ') || 
    ' [' || LPAD(optimized_latency_ms::text, 6, ' ') || ' ms]' AS optimized_chart,
    LPAD(speedup_factor::text, 7, ' ') || 'x' AS speedup
FROM optimization_scorecard
ORDER BY query_id ASC;

-- ----------------------------------------------------------------------------
-- 4. PRODUCTION QUERY EXECUTION TRIAGE MATRIX (DECISION GUIDE)
-- ----------------------------------------------------------------------------
-- Use this diagnostic reference when debugging slow queries in production:
SELECT 
    symptom AS "EXPLAIN Plan Symptom",
    root_cause AS "Underlying Engine Root Cause",
    remediation AS "Recommended Remediation Strategy"
FROM (
    VALUES 
    (
        'Seq Scan on large table with Filter: (func(col) = ...)',
        'Non-sargable expression prevents B-Tree index lookup',
        'Rewrite predicate to bare column half-open range [start, end) or create functional expression index.'
    ),
    (
        'Filter: (col)::numeric = ... (explicit or implicit cast)',
        'Data type mismatch between literal/parameter and column type',
        'Ensure application binds exact data type matching the schema definition.'
    ),
    (
        'Nested Loop with inner node loops=10,000+ and high execution time',
        'Missing foreign key index or severe outer cardinality misestimation',
        'Add index on inner join column, or run ANALYZE / CREATE STATISTICS to correct cardinality.'
    ),
    (
        'Sort Method: external merge Disk: X kB',
        'Sort dataset exceeded work_mem budget, spilling to disk temp files',
        'Elevate SET LOCAL work_mem for the query, or create a B-Tree index matching ORDER BY to eliminate sort node.'
    ),
    (
        'SubPlan 1 (returns type record) executing per outer row',
        'Correlated scalar subquery in SELECT projection (N+1 query)',
        'Refactor to LEFT JOIN with GROUP BY or pre-aggregate in an isolated CTE.'
    ),
    (
        'SubPlan on NOT IN (SELECT ...)',
        'Three-valued SQL NULL logic prevents Hash Anti-Join optimization',
        'Rewrite query to use NOT EXISTS with a correlated inner predicate.'
    ),
    (
        'Hash ... Batches: 16 (originally 1) Memory Usage: X kB',
        'Hash table exceeded work_mem during build phase, spilling to disk',
        'Increase work_mem for the session/transaction to enable single-pass in-memory Hash Join (Batches: 1).'
    ),
    (
        'High execution time on OFFSET N LIMIT K (large N)',
        'Offset pagination scans and discards N tuples before returning K tuples',
        'Implement Keyset (Seek) Pagination using composite index (WHERE (sort_col, id) > (...)).'
    ),
    (
        'Estimated rows = 5, Actual rows = 50,000 (Multi-column filter)',
        'Independence assumption failure on correlated columns',
        'Create Extended Statistics (CREATE STATISTICS ... (dependencies, mcv)) and re-run ANALYZE.'
    )
) AS triage(symptom, root_cause, remediation);

