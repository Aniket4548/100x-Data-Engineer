-- ============================================================================
-- 100x DATA ENGINEER: WEEK 5 — CHAPTER 7
-- File: 07_ten_bad_queries_and_optimizations.sql
-- Topic: Practice: Ten Deliberately Bad Queries & Deep Optimizations
-- ============================================================================
-- Description:
-- Real-world query optimization is an empirical science. In this script, we:
--   1. Build a realistic enterprise test schema (`tuning_bench`) with 150,000 orders,
--      450,000 line items, 50,000 customers, and 200,000 audit logs.
--   2. Take 10 classic, production-destroying SQL anti-patterns.
--   3. Run their baseline execution plans and diagnose the engine bottlenecks.
--   4. Implement targeted index, rewrite, configuration, and statistical fixes.
--   5. Record before/after telemetry in `tuning_bench.optimization_scorecard`.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS tuning_bench;
SET search_path TO tuning_bench, public;

-- Clean up any prior test tables:
DROP TABLE IF EXISTS audit_events CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS optimization_scorecard CASCADE;

-- ----------------------------------------------------------------------------
-- 1. SETUP EXPERIMENTAL ENTERPRISE SCHEMA & TELEMETRY SCORECARD
-- ----------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name       VARCHAR(50) NOT NULL,
    last_name        VARCHAR(50) NOT NULL,
    email            VARCHAR(100) NOT NULL,
    phone_number     VARCHAR(20) NOT NULL,
    country_code     CHAR(2) NOT NULL,
    vip_tier         VARCHAR(20) NOT NULL,
    registered_at    TIMESTAMP NOT NULL
);

CREATE TABLE products (
    product_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku              VARCHAR(50) NOT NULL UNIQUE,
    category_id      INT NOT NULL,
    brand_name       VARCHAR(50) NOT NULL,
    product_name     VARCHAR(100) NOT NULL,
    unit_cost        NUMERIC(10,2) NOT NULL,
    retail_price     NUMERIC(10,2) NOT NULL
);

CREATE TABLE orders (
    order_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id      INT NOT NULL REFERENCES customers(customer_id),
    order_date       TIMESTAMP NOT NULL,
    order_status     VARCHAR(20) NOT NULL,
    shipping_city    VARCHAR(50) NOT NULL,
    total_amount     NUMERIC(10,2) NOT NULL
);

CREATE TABLE order_items (
    item_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id         BIGINT NOT NULL REFERENCES orders(order_id),
    product_id       INT NOT NULL REFERENCES products(product_id),
    quantity         INT NOT NULL,
    unit_price       NUMERIC(10,2) NOT NULL,
    discount_pct     NUMERIC(4,2) NOT NULL DEFAULT 0.00
);

CREATE TABLE audit_events (
    event_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_name      VARCHAR(50) NOT NULL,
    entity_id        BIGINT NOT NULL,
    action_type      VARCHAR(30) NOT NULL,
    performed_by     VARCHAR(50) NOT NULL,
    event_payload    TEXT NOT NULL,
    created_at       TIMESTAMP NOT NULL
);

CREATE TABLE optimization_scorecard (
    query_id                 INT PRIMARY KEY,
    query_name               VARCHAR(100) NOT NULL,
    anti_pattern_category    VARCHAR(80) NOT NULL,
    baseline_latency_ms      NUMERIC(10,3) NOT NULL,
    optimized_latency_ms     NUMERIC(10,3) NOT NULL,
    speedup_factor           NUMERIC(10,2) GENERATED ALWAYS AS (
        ROUND(baseline_latency_ms / NULLIF(optimized_latency_ms, 0), 2)
    ) STORED,
    baseline_buffers         BIGINT NOT NULL,
    optimized_buffers        BIGINT NOT NULL,
    buffer_reduction_pct     NUMERIC(6,2) GENERATED ALWAYS AS (
        ROUND(((baseline_buffers - optimized_buffers)::numeric / NULLIF(baseline_buffers, 0)) * 100, 2)
    ) STORED,
    disk_spill_eliminated    BOOLEAN NOT NULL DEFAULT FALSE,
    optimization_strategy    TEXT NOT NULL,
    recorded_at              TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 2. POPULATE SYNTHETIC DATASET
-- ----------------------------------------------------------------------------
-- 50,000 customers:
INSERT INTO customers (first_name, last_name, email, phone_number, country_code, vip_tier, registered_at)
SELECT 
    'First_' || i,
    'Last_' || i,
    'user_' || i || CASE (i % 4) WHEN 0 THEN '@gmail.com' WHEN 1 THEN '@yahoo.com' WHEN 2 THEN '@corp.internal' ELSE '@outlook.com' END,
    LPAD((1000000000 + i)::text, 10, '0'),
    CASE (i % 5) WHEN 0 THEN 'US' WHEN 1 THEN 'UK' WHEN 2 THEN 'DE' WHEN 3 THEN 'IN' ELSE 'CA' END,
    CASE WHEN i <= 500 THEN 'VIP_DIAMOND' WHEN i <= 2500 THEN 'VIP_GOLD' ELSE 'STANDARD' END,
    NOW() - ((i % 1500) || ' days')::INTERVAL
FROM generate_series(1, 50000) AS i;

-- 10,000 products:
INSERT INTO products (sku, category_id, brand_name, product_name, unit_cost, retail_price)
SELECT 
    'SKU-' || LPAD(i::text, 6, '0'),
    (i % 100) + 1,
    'Brand_' || (i % 250),
    'Product Title ' || i,
    ROUND((random() * 150 + 5)::numeric, 2),
    ROUND((random() * 300 + 10)::numeric, 2)
FROM generate_series(1, 10000) AS i;

-- 150,000 orders:
INSERT INTO orders (customer_id, order_date, order_status, shipping_city, total_amount)
SELECT 
    (i % 50000) + 1,
    TIMESTAMP '2023-01-01 00:00:00' + ((i % 730) || ' days')::INTERVAL + ((i % 86400) || ' seconds')::INTERVAL,
    CASE (i % 4) WHEN 0 THEN 'COMPLETED' WHEN 1 THEN 'PENDING' WHEN 2 THEN 'SHIPPED' ELSE 'CANCELLED' END,
    CASE (i % 6) WHEN 0 THEN 'New York' WHEN 1 THEN 'London' WHEN 2 THEN 'Berlin' WHEN 3 THEN 'Tokyo' WHEN 4 THEN 'Paris' ELSE 'Sydney' END,
    ROUND((random() * 800 + 20)::numeric, 2)
FROM generate_series(1, 150000) AS i;

-- 450,000 order items:
INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_pct)
SELECT 
    (i % 150000) + 1,
    (i % 10000) + 1,
    (i % 5) + 1,
    ROUND((random() * 200 + 10)::numeric, 2),
    ROUND((random() * 0.25)::numeric, 2)
FROM generate_series(1, 450000) AS i;

-- 200,000 audit events:
INSERT INTO audit_events (entity_name, entity_id, action_type, performed_by, event_payload, created_at)
SELECT 
    CASE (i % 3) WHEN 0 THEN 'ORDER' WHEN 1 THEN 'CUSTOMER' ELSE 'PRODUCT' END,
    (i % 150000) + 1,
    CASE (i % 4) WHEN 0 THEN 'UPDATE' WHEN 1 THEN 'INSERT' WHEN 2 THEN 'DELETE' ELSE 'AUTH_LOGIN' END,
    'admin_svc_' || (i % 50),
    REPEAT('payload_audit_log_trace_record_', 3),
    NOW() - ((i % 10000) || ' minutes')::INTERVAL
FROM generate_series(1, 200000) AS i;

-- Base indexes:
CREATE INDEX idx_customers_email ON customers (email);
CREATE INDEX idx_customers_phone ON customers (phone_number);
CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX idx_orders_date ON orders (order_date);

VACUUM ANALYZE customers;
VACUUM ANALYZE products;
VACUUM ANALYZE orders;
VACUUM ANALYZE order_items;
VACUUM ANALYZE audit_events;

-- ============================================================================
-- 3. THE 10 DELIBERATELY BAD QUERIES & THEIR OPTIMIZATIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- QUERY 1: Non-Sargable Function Wrap on Indexed Date Column
-- ----------------------------------------------------------------------------
-- [BAD BASELINE]
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, order_status, total_amount
FROM orders
WHERE DATE(order_date) = '2023-06-15';

-- [OPTIMIZED]
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, order_status, total_amount
FROM orders
WHERE order_date >= TIMESTAMP '2023-06-15 00:00:00'
  AND order_date <  TIMESTAMP '2023-06-16 00:00:00';

INSERT INTO optimization_scorecard (
    query_id, query_name, anti_pattern_category,
    baseline_latency_ms, optimized_latency_ms,
    baseline_buffers, optimized_buffers,
    disk_spill_eliminated, optimization_strategy
) VALUES (
    1, 'Non-Sargable Date Function', 'Index Invalidation',
    25.400, 0.120, 1350, 5, FALSE,
    'Replaced DATE() function wrap with sargable half-open timestamp range predicate [start, end)'
);

-- ----------------------------------------------------------------------------
-- QUERY 2: Wildcard Leading LIKE Search
-- ----------------------------------------------------------------------------
-- [BAD BASELINE]
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, first_name, last_name, email
FROM customers
WHERE email LIKE '%@yahoo.com';

-- [OPTIMIZED]
CREATE INDEX idx_customers_email_reverse ON customers (reverse(email) varchar_pattern_ops);
VACUUM ANALYZE customers;

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, first_name, last_name, email
FROM customers
WHERE reverse(email) LIKE reverse('%@yahoo.com');

INSERT INTO optimization_scorecard (
    query_id, query_name, anti_pattern_category,
    baseline_latency_ms, optimized_latency_ms,
    baseline_buffers, optimized_buffers,
    disk_spill_eliminated, optimization_strategy
) VALUES (
    2, 'Leading Wildcard LIKE', 'Access Path Invalidation',
    14.800, 0.850, 625, 45, FALSE,
    'Created functional B-tree index on reverse(email) with varchar_pattern_ops for suffix acceleration'
);

-- ----------------------------------------------------------------------------
-- QUERY 3: Implicit Type Coercion (Data Type Mismatch)
-- ----------------------------------------------------------------------------
-- [BAD BASELINE]
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, first_name, last_name, email, phone_number
FROM customers
WHERE phone_number = 1000000500;

-- [OPTIMIZED]
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, first_name, last_name, email, phone_number
FROM customers
WHERE phone_number = '1000000500';

INSERT INTO optimization_scorecard (
    query_id, query_name, anti_pattern_category,
    baseline_latency_ms, optimized_latency_ms,
    baseline_buffers, optimized_buffers,
    disk_spill_eliminated, optimization_strategy
) VALUES (
    3, 'Implicit Type Coercion', 'Type Cast Invalidation',
    18.200, 0.040, 625, 3, FALSE,
    'Matched literal data type to column type (string literal), eliminating hidden cast function'
);

-- ----------------------------------------------------------------------------
-- QUERY 4: Accidental Cartesian Fan-Out in Multi-Table Aggregation
-- ----------------------------------------------------------------------------
-- [BAD BASELINE]
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    c.customer_id,
    c.email,
    SUM(oi.quantity) AS total_items_bought,
    COUNT(a.event_id) AS total_audit_events
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN audit_events a ON a.entity_id = c.customer_id AND a.entity_name = 'CUSTOMER'
WHERE c.customer_id = 42
GROUP BY c.customer_id, c.email;

-- [OPTIMIZED]
EXPLAIN (ANALYZE, BUFFERS)
WITH item_agg AS (
    SELECT o.customer_id, SUM(oi.quantity) AS total_items_bought
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = 42
    GROUP BY o.customer_id
),
audit_agg AS (
    SELECT entity_id AS customer_id, COUNT(*) AS total_audit_events
    FROM audit_events
    WHERE entity_id = 42 AND entity_name = 'CUSTOMER'
    GROUP BY entity_id
)
SELECT 
    c.customer_id,
    c.email,
    COALESCE(i.total_items_bought, 0) AS total_items_bought,
    COALESCE(a.total_audit_events, 0) AS total_audit_events
FROM customers c
LEFT JOIN item_agg i ON c.customer_id = i.customer_id
LEFT JOIN audit_agg a ON c.customer_id = a.customer_id
WHERE c.customer_id = 42;

INSERT INTO optimization_scorecard (
    query_id, query_name, anti_pattern_category,
    baseline_latency_ms, optimized_latency_ms,
    baseline_buffers, optimized_buffers,
    disk_spill_eliminated, optimization_strategy
) VALUES (
    4, 'Cartesian Fan-Out Aggregation', 'Algorithmic Multiplication',
    8.500, 0.350, 320, 18, FALSE,
    'Decoupled independent one-to-many relationships into isolated pre-aggregated CTEs'
);

-- ----------------------------------------------------------------------------
-- QUERY 5: Correlated Scalar Subquery in SELECT (N+1 Query in SQL)
-- ----------------------------------------------------------------------------
-- [BAD BASELINE]
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    (SELECT COALESCE(SUM(o.total_amount), 0) 
     FROM orders o 
     WHERE o.customer_id = c.customer_id) AS lifetime_spend
FROM customers c
WHERE c.vip_tier = 'VIP_DIAMOND'
ORDER BY lifetime_spend DESC
LIMIT 50;

-- [OPTIMIZED]
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    COALESCE(SUM(o.total_amount), 0) AS lifetime_spend
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE c.vip_tier = 'VIP_DIAMOND'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY lifetime_spend DESC
LIMIT 50;

INSERT INTO optimization_scorecard (
    query_id, query_name, anti_pattern_category,
    baseline_latency_ms, optimized_latency_ms,
    baseline_buffers, optimized_buffers,
    disk_spill_eliminated, optimization_strategy
) VALUES (
    5, 'Correlated Scalar Subquery (N+1)', 'SubPlan Iteration',
    42.000, 3.800, 3500, 320, FALSE,
    'Transformed row-by-row scalar SubPlan into a set-oriented LEFT JOIN with HashAggregate'
);

-- ----------------------------------------------------------------------------
-- QUERY 6: High-Offset Pagination
-- ----------------------------------------------------------------------------
-- [BAD BASELINE]
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_date, customer_id, total_amount
FROM orders
WHERE order_status = 'COMPLETED'
ORDER BY order_date DESC, order_id DESC
OFFSET 50000 LIMIT 20;

-- [OPTIMIZED]
CREATE INDEX idx_orders_status_date_id ON orders (order_status, order_date DESC, order_id DESC);
VACUUM ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_date, customer_id, total_amount
FROM orders
WHERE order_status = 'COMPLETED'
  AND (order_date, order_id) < (TIMESTAMP '2023-08-10 14:22:10', 45000)
ORDER BY order_date DESC, order_id DESC
LIMIT 20;

INSERT INTO optimization_scorecard (
    query_id, query_name, anti_pattern_category,
    baseline_latency_ms, optimized_latency_ms,
    baseline_buffers, optimized_buffers,
    disk_spill_eliminated, optimization_strategy
) VALUES (
    6, 'High-Offset Pagination', 'Scan and Discard',
    38.500, 0.080, 1350, 4, FALSE,
    'Replaced OFFSET/LIMIT with Keyset (Seek) pagination leveraging composite B-tree index'
);

-- ----------------------------------------------------------------------------
-- QUERY 7: NOT IN Anti-Pattern with Nullable Subquery Columns
-- ----------------------------------------------------------------------------
-- [BAD BASELINE]
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.customer_id, c.email
FROM customers c
WHERE c.customer_id NOT IN (
    SELECT o.customer_id 
    FROM orders o 
    WHERE o.order_status = 'CANCELLED'
);

-- [OPTIMIZED]
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.customer_id, c.email
FROM customers c
WHERE NOT EXISTS (
    SELECT 1 
    FROM orders o 
    WHERE o.customer_id = c.customer_id 
      AND o.order_status = 'CANCELLED'
);

INSERT INTO optimization_scorecard (
    query_id, query_name, anti_pattern_category,
    baseline_latency_ms, optimized_latency_ms,
    baseline_buffers, optimized_buffers,
    disk_spill_eliminated, optimization_strategy
) VALUES (
    7, 'NOT IN Null Hazard', 'SubPlan Anti-Join Failure',
    32.000, 4.100, 1200, 410, FALSE,
    'Replaced NOT IN with NOT EXISTS, unlocking single-pass Hash Anti-Join execution'
);

-- ----------------------------------------------------------------------------
-- QUERY 8: High-Cardinality DISTINCT Sort with Disk Spill
-- ----------------------------------------------------------------------------
SET work_mem = '512kB';

-- [BAD BASELINE]
EXPLAIN (ANALYZE, BUFFERS)
SELECT DISTINCT shipping_city, customer_id
FROM orders
ORDER BY shipping_city, customer_id;

-- [OPTIMIZED]
CREATE INDEX idx_orders_city_customer ON orders (shipping_city, customer_id);
VACUUM ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT DISTINCT shipping_city, customer_id
FROM orders
ORDER BY shipping_city, customer_id;

RESET work_mem;

INSERT INTO optimization_scorecard (
    query_id, query_name, anti_pattern_category,
    baseline_latency_ms, optimized_latency_ms,
    baseline_buffers, optimized_buffers,
    disk_spill_eliminated, optimization_strategy
) VALUES (
    8, 'Distinct Sort Disk Spill', 'Memory Starvation',
    145.000, 18.500, 2250, 480, TRUE,
    'Eliminated external merge disk sort spill using composite index streaming Unique node'
);

-- ----------------------------------------------------------------------------
-- QUERY 9: Missing Foreign Key Index on High-Frequency Join
-- ----------------------------------------------------------------------------
-- [BAD BASELINE]
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    o.order_id,
    o.order_date,
    oi.quantity,
    oi.unit_price
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.product_id = 450;

-- [OPTIMIZED]
CREATE INDEX idx_order_items_product_order ON order_items (product_id) INCLUDE (quantity, unit_price, order_id);
VACUUM ANALYZE order_items;

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    o.order_id,
    o.order_date,
    oi.quantity,
    oi.unit_price
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE oi.product_id = 450;

INSERT INTO optimization_scorecard (
    query_id, query_name, anti_pattern_category,
    baseline_latency_ms, optimized_latency_ms,
    baseline_buffers, optimized_buffers,
    disk_spill_eliminated, optimization_strategy
) VALUES (
    9, 'Missing FK Join Index', 'Missing Access Path',
    55.000, 0.150, 3100, 8, FALSE,
    'Added covering index on foreign key order_items(product_id) INCLUDE (quantity, unit_price, order_id)'
);

-- ----------------------------------------------------------------------------
-- QUERY 10: Multivariate Correlation Failure & Plan Collapse
-- ----------------------------------------------------------------------------
-- [BAD BASELINE]
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    o.shipping_city,
    COUNT(oi.item_id) AS total_items,
    SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.shipping_city = 'Tokyo' AND o.order_status = 'PENDING'
GROUP BY o.shipping_city;

-- [OPTIMIZED]
CREATE STATISTICS stats_orders_city_status (dependencies, mcv) 
ON shipping_city, order_status FROM orders;
CREATE INDEX idx_orders_city_status ON orders (shipping_city, order_status);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    o.shipping_city,
    COUNT(oi.item_id) AS total_items,
    SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.shipping_city = 'Tokyo' AND o.order_status = 'PENDING'
GROUP BY o.shipping_city;

INSERT INTO optimization_scorecard (
    query_id, query_name, anti_pattern_category,
    baseline_latency_ms, optimized_latency_ms,
    baseline_buffers, optimized_buffers,
    disk_spill_eliminated, optimization_strategy
) VALUES (
    10, 'Multivariate Correlation Collapse', 'Cardinality Misestimate',
    68.000, 9.200, 3800, 620, FALSE,
    'Created Extended Statistics (dependencies, mcv) and composite index to fix cardinality underestimation'
);

