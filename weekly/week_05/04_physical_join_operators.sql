-- ============================================================================
-- 100x DATA ENGINEER: WEEK 5 — CHAPTER 4
-- File: 04_physical_join_operators.sql
-- Topic: Physical Join Operators: Nested-Loop, Hash Join & Merge Join
-- ============================================================================
-- Description:
-- Relational algebra defines logical joins. PostgreSQL must execute them using
-- one of three physical join algorithms:
--
--   1. Nested-Loop Join : Outer driving loop iterating over inner relation.
--   2. Hash Join        : In-memory hash table on inner table; stream/probe outer.
--   3. Merge Join       : Dual cursor lockstep progression along sorted streams.
--
-- This script benchmarks and contrasts all three join algorithms on identical data.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SETUP EXPERIMENTAL TESTBENCH
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS join_demo_orders CASCADE;
DROP TABLE IF EXISTS join_demo_customers CASCADE;

CREATE TABLE join_demo_customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    vip_tier VARCHAR(20) NOT NULL,
    country_code CHAR(2) NOT NULL
);

CREATE TABLE join_demo_orders (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_amount NUMERIC(10,2) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL
);

-- Populate 2,000 customers:
INSERT INTO join_demo_customers (customer_id, customer_name, vip_tier, country_code)
SELECT 
    i,
    'Customer_' || i,
    CASE WHEN i <= 50 THEN 'PLATINUM' WHEN i <= 250 THEN 'GOLD' ELSE 'STANDARD' END,
    CASE (i % 4) WHEN 0 THEN 'US' WHEN 1 THEN 'UK' WHEN 2 THEN 'DE' ELSE 'IN' END
FROM generate_series(1, 2000) AS i;

-- Populate 100,000 orders:
INSERT INTO join_demo_orders (order_id, customer_id, order_amount, order_status, created_at)
SELECT 
    i,
    (i % 2000) + 1,
    ROUND((random() * 500 + 10)::numeric, 2),
    CASE (i % 3) WHEN 0 THEN 'DELIVERED' WHEN 1 THEN 'SHIPPED' ELSE 'PROCESSING' END,
    NOW() - ((i % 500) || ' days')::INTERVAL
FROM generate_series(1, 100000) AS i;

-- Add index on foreign key customer_id:
CREATE INDEX idx_join_orders_cust ON join_demo_orders (customer_id);

VACUUM ANALYZE join_demo_customers;
VACUUM ANALYZE join_demo_orders;

-- ----------------------------------------------------------------------------
-- 2. OPERATOR 1: PARAMETERIZED INDEX NESTED LOOP (THE OLTP KING)
-- ----------------------------------------------------------------------------
-- Scenario: Selective outer filter (only 50 PLATINUM customers out of 2,000).
-- Outer Table: `join_demo_customers` (filtered to 50 rows).
-- Inner Table: `join_demo_orders` (B-Tree index lookup per outer customer).

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    c.customer_id,
    c.customer_name,
    c.vip_tier,
    o.order_id,
    o.order_amount
FROM join_demo_customers c
JOIN join_demo_orders o ON c.customer_id = o.customer_id
WHERE c.vip_tier = 'PLATINUM';

-- Telemetry Highlights:
-- -> Nested Loop
--    -> Seq Scan on join_demo_customers c (Filter: vip_tier = 'PLATINUM', rows=50)
--    -> Index Scan using idx_join_orders_cust on join_demo_orders o
--         Index Cond: (customer_id = c.customer_id)
--         (actual time=0.008..0.032 rows=50 loops=50)
-- Total execution time is < 2 ms! Notice loops=50 on the inner scan.

-- ----------------------------------------------------------------------------
-- 3. OPERATOR 2: HASH JOIN (THE OLAP WORKHORSE)
-- ----------------------------------------------------------------------------
-- Scenario: Non-selective bulk join (all 2,000 customers joined to 100,000 orders).
-- Outer Table: `join_demo_orders` (100,000 rows streamed during probe phase).
-- Inner Table: `join_demo_customers` (2,000 rows hashed into memory during build phase).

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    c.country_code,
    COUNT(o.order_id) AS total_orders,
    SUM(o.order_amount) AS total_revenue
FROM join_demo_customers c
JOIN join_demo_orders o ON c.customer_id = o.customer_id
GROUP BY c.country_code;

-- Telemetry Highlights:
-- -> Hash Join
--    Hash Cond: (o.customer_id = c.customer_id)
--    -> Seq Scan on join_demo_orders o
--    -> Hash
--         Buckets: 2048  Batches: 1  Memory Usage: 115kB
--         -> Seq Scan on join_demo_customers c
--
-- Notice:
-- 1. Single batch in memory (`Batches: 1`).
-- 2. Completes across 100,000 rows in ~25 ms!

-- ----------------------------------------------------------------------------
-- 4. HASH JOIN DISK SPILL WHEN `work_mem` IS CHOKED
-- ----------------------------------------------------------------------------
-- Choke work_mem to force multi-batch disk partitioning:
SET work_mem = '64kB';

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    c.country_code,
    COUNT(o.order_id) AS total_orders,
    SUM(o.order_amount) AS total_revenue
FROM join_demo_customers c
JOIN join_demo_orders o ON c.customer_id = o.customer_id
GROUP BY c.country_code;

-- Look for: `Batches: 4 (originally 1)` and `temp read / written` in buffers!
RESET work_mem;

-- ----------------------------------------------------------------------------
-- 5. OPERATOR 3: MERGE JOIN (PRE-SORTED B-TREE STREAMING)
-- ----------------------------------------------------------------------------
-- Scenario: Both relations pre-sorted on join key via primary and foreign key indexes.
-- PostgreSQL walks both streams in lockstep without building a hash table or sorting!

SET enable_hashjoin = off;
SET enable_nestloop = off;

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    c.customer_id,
    c.customer_name,
    o.order_id,
    o.order_amount
FROM join_demo_customers c
JOIN join_demo_orders o ON c.customer_id = o.customer_id;

-- Telemetry Highlights:
-- -> Merge Join
--    Merge Cond: (c.customer_id = o.customer_id)
--    -> Index Scan using join_demo_customers_pkey on join_demo_customers c
--    -> Index Scan using idx_join_orders_cust on join_demo_orders o
--
-- Notice:
-- 1. No Sort nodes!
-- 2. Zero startup latency!

RESET enable_hashjoin;
RESET enable_nestloop;

-- Clean up:
DROP TABLE IF EXISTS join_demo_orders CASCADE;
DROP TABLE IF EXISTS join_demo_customers CASCADE;

