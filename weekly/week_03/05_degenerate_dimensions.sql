-- ============================================================================
-- WEEK 3: TOPIC 5 — Degenerate Dimensions (DD)
-- Description:
-- A Degenerate Dimension is a dimensional attribute (identifier, code, or status)
-- stored directly in the fact table without a separate dimension table.
--
-- Real Examples From Your Database:
--   - orders.orders.order_number (e.g. ORD-...)
--   - logistics.shipments.tracking_number
--   - orders.payments.payment_reference
--   - orders.orders.order_status
--   - orders.orders.currency
--
-- The Anti-Pattern:
-- Creating a `dim_order_number` table for 10,000 orders creates a useless 1-column
-- table that increases join costs and uses memory with zero descriptive gain.
--
-- Why Kimball Keeps Degenerate Dimensions in Facts:
-- 1. Line Item Grouping: Groups multiple items belonging to the same order.
-- 2. Auditability: Tracing a line-item back to the source operational invoice.
-- 3. Partitioning / Clustering in analytical query engines.
-- ============================================================================

-- Querying operational order lines showing degenerate dimensions alongside dimensional context:
SELECT 
    -- Degenerate Dimensions (Stored directly on the fact line)
    o.order_number,
    oi.order_item_id,
    o.order_status,
    o.currency,
    pay.payment_method,
    -- Contextual Dimensions (From dimensional tables)
    c.full_name AS customer_name,
    c.country AS customer_country,
    p.product_name,
    p.brand,
    p.category_name,
    -- Additive Fact Measures
    oi.quantity,
    oi.unit_price,
    oi.discount_amount,
    oi.line_total
FROM orders.orders o
JOIN orders.order_items oi ON o.order_id = oi.order_id
LEFT JOIN orders.payments pay ON o.order_id = pay.order_id
JOIN dwh.dim_customer c ON o.customer_id = c.customer_id
JOIN dwh.dim_product p ON oi.product_id = p.product_id
LIMIT 20;
