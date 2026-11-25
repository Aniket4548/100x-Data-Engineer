-- ============================================================================
-- 100x DATA ENGINEER: WEEK 5 — CHAPTER 1
-- File: 01_query_planner_architecture.sql
-- Topic: The PostgreSQL Query Processing Pipeline & Planner Architecture
-- ============================================================================
-- Description:
-- In PostgreSQL, executing a SQL query is not an atomic step. The engine compiles
-- declarative SQL into an imperative physical plan tree through five distinct stages:
--
--   1. Parser: Tokenizes SQL and constructs the Parse Tree (grammatical validation).
--   2. Semantic Analyzer: Validates catalog objects (tables, columns, types, operators).
--   3. Rewriter: Expands Views and evaluates PostgreSQL Rules / RLS policies.
--   4. Cost-Based Planner: Generates candidate Paths, estimates mathematical costs,
--      searches join trees via Dynamic Programming (or GEQO), and creates the Plan tree.
--   5. Volcano Executor: Executes the Plan tree via a demand-driven iterator model
--      (ExecInitNode -> ExecProcNode -> ExecEndNode).
--
-- This script provides hands-on demonstrations of each pipeline stage.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. INSPECT PLANNER PIPELINE & SEARCH CONTROLS
-- ----------------------------------------------------------------------------
-- PostgreSQL provides GUC parameters that dictate how the optimizer searches
-- for optimal execution paths and when it falls back to genetic algorithms.

SELECT 
    name, 
    setting, 
    unit, 
    short_desc 
FROM pg_settings 
WHERE name IN (
    'geqo',                  -- Genetic Query Optimizer toggle (on/off)
    'geqo_threshold',        -- Number of tables in FROM clause to trigger GEQO (default: 12)
    'join_collapse_limit',   -- Max explicit joins to plan with dynamic programming (default: 8)
    'from_collapse_limit',   -- Max subqueries to flatten into parent query (default: 8)
    'default_statistics_target' -- Sample size target for ANALYZE (default: 100)
)
ORDER BY name;

-- ----------------------------------------------------------------------------
-- 2. REWRITER IN ACTION: VIEW EXPANSION & SUBQUERY FLATTENING
-- ----------------------------------------------------------------------------
-- Let's observe how the Query Rewriter transforms a relational View into its
-- underlying base table query tree before the optimizer ever costs it.

DROP VIEW IF EXISTS active_customer_summary CASCADE;
DROP TABLE IF EXISTS pipeline_demo_orders CASCADE;
DROP TABLE IF EXISTS pipeline_demo_customers CASCADE;

CREATE TABLE pipeline_demo_customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE pipeline_demo_orders (
    order_id INT PRIMARY KEY,
    customer_id INT REFERENCES pipeline_demo_customers(customer_id),
    order_amount NUMERIC(10,2) NOT NULL,
    order_date DATE NOT NULL
);

INSERT INTO pipeline_demo_customers (customer_id, customer_name, is_active)
SELECT i, 'Customer_' || i, (i % 5 != 0)
FROM generate_series(1, 1000) AS i;

INSERT INTO pipeline_demo_orders (order_id, customer_id, order_amount, order_date)
SELECT i, (i % 1000) + 1, ROUND((random() * 500 + 10)::numeric, 2), CURRENT_DATE - (i % 30)
FROM generate_series(1, 5000) AS i;

VACUUM ANALYZE pipeline_demo_customers;
VACUUM ANALYZE pipeline_demo_orders;

-- Create an operational view:
CREATE VIEW active_customer_summary AS
SELECT 
    c.customer_id,
    c.customer_name,
    COUNT(o.order_id) AS total_orders,
    SUM(o.order_amount) AS total_spent
FROM pipeline_demo_customers c
JOIN pipeline_demo_orders o ON c.customer_id = o.customer_id
WHERE c.is_active = TRUE
GROUP BY c.customer_id, c.customer_name;

-- Now query the view:
-- Observe how the EXPLAIN output shows NO reference to the view name itself!
-- The rewriter expanded the view definition directly into the base table plan tree:
EXPLAIN (VERBOSE, COSTS)
SELECT * 
FROM active_customer_summary 
WHERE total_spent > 1000;

-- ----------------------------------------------------------------------------
-- 3. THE VOLCANO ITERATOR MODEL: PIPELINED DEMAND VS BLOCKING NODES
-- ----------------------------------------------------------------------------
-- The Volcano model pulls tuples on demand via `ExecProcNode()`.
--
-- Demonstration A: Streaming / Pipelined Execution with LIMIT
-- The `Limit` node terminates execution as soon as 5 rows are emitted.
-- Notice the actual time: it stops immediately without reading the remaining rows!

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, customer_name
FROM pipeline_demo_customers
LIMIT 5;

-- Demonstration B: Blocking (Stop-and-Wait) Node with SORT
-- When an `ORDER BY` is introduced on an unindexed column, the `Sort` node
-- MUST consume ALL input rows before emitting the first row!
-- Observe that the startup time jumps from 0.01 ms to several milliseconds:

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, customer_name
FROM pipeline_demo_customers
ORDER BY customer_name DESC
LIMIT 5;

-- ----------------------------------------------------------------------------
-- 4. CLEANUP
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS active_customer_summary CASCADE;
DROP TABLE IF EXISTS pipeline_demo_orders CASCADE;
DROP TABLE IF EXISTS pipeline_demo_customers CASCADE;

