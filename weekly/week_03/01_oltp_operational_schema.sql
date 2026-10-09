-- ============================================================================
-- WEEK 3: TOPIC 1 — Operational (3NF) Database Audit & Dimensional Mapping
-- Description:
-- Your PostgreSQL database already has a live, rich 3NF operational warehouse:
--   - catalog  (categories, products, product_prices)
--   - customer (customers, addresses, customer_events)
--   - orders   (orders, order_items, payments)
--   - logistics (warehouses, shipments, delivery_events)
--
-- This script:
-- 1. Audits the existing 3NF operational tables and active row counts.
-- 2. Highlights the normalization structure (why it's 3NF and why OLAP needs Star Schema).
-- 3. Prepares the target analytical schema: `dwh`.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. AUDIT EXISTING 3NF OPERATIONAL SCHEMAS & ROW COUNTS
-- ----------------------------------------------------------------------------


ANALYZE;


SELECT 
    schemaname AS schema_name,
    relname AS table_name,
    n_live_tup AS estimated_row_count
FROM pg_stat_user_tables
WHERE schemaname IN ('catalog', 'customer', 'logistics', 'orders')
ORDER BY schemaname, relname;


-- ----------------------------------------------------------------------------
-- 2. THE 3NF COMPLEXITY PROBLEM: A DEMONSTRATION
-- Business Question:
-- "Find the gross revenue, discounts, units sold, and profit margin by Category,
--  Customer Country, and Warehouse for delivered orders."
--
-- Notice how in your existing 3NF schema, this requires a 7-to-8 table join:
-- orders ──► order_items ──► products ──► categories
--    │
--    ├──► customers ──► addresses
--    │
--    └──► shipments ──► warehouses
-- ----------------------------------------------------------------------------

EXPLAIN ANALYZE
SELECT 
    cat.category_name,
    addr.country AS customer_country,
    wh.warehouse_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.line_total) AS total_gross_revenue,
    SUM(oi.discount_amount) AS total_discounts,
    SUM(oi.line_total - (oi.quantity * p.cost_price)) AS total_profit
FROM orders.orders o
JOIN orders.order_items oi ON o.order_id = oi.order_id
JOIN catalog.products p ON oi.product_id = p.product_id
JOIN catalog.categories cat ON p.category_id = cat.category_id
JOIN customer.customers c ON o.customer_id = c.customer_id
LEFT JOIN customer.addresses addr ON c.customer_id = addr.customer_id AND addr.is_default = TRUE
LEFT JOIN logistics.shipments s ON o.order_id = s.order_id
LEFT JOIN logistics.warehouses wh ON s.warehouse_id = wh.warehouse_id
WHERE o.order_status = 'delivered'
GROUP BY cat.category_name, addr.country, wh.warehouse_name
ORDER BY total_gross_revenue DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- 3. INITIALIZE THE DATA WAREHOUSE TARGET SCHEMA
-- ----------------------------------------------------------------------------
-- All dimensional models will be built inside the `dwh` schema, leaving your
-- operational tables (catalog, customer, orders, logistics) completely intact.

CREATE SCHEMA IF NOT EXISTS dwh;

COMMENT ON SCHEMA dwh IS 'Analytical Data Warehouse built on Kimball Dimensional Modeling principles.';
