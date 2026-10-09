-- ============================================================================
-- WEEK 3: TOPIC 7 — The Fact ELT Pipeline (Source to Star Schema)
-- Description:
-- Transforming ~30,000 operational records from orders.order_items and orders.orders
-- into the dwh.fact_sales_order_lines Star Schema.
--
-- Engineering Mechanics:
-- 1. Surrogate Key Replacement: Mapping customer_id & product_id UUIDs to BIGINT SKs.
-- 2. Date Surrogate Key: Mapping timestamps to YYYYMMDD integer keys in dim_date.
-- 3. Header-to-Line Allocation: Prorating order tax and shipping amounts proportionally.
-- 4. Idempotent Upsert: Using ON CONFLICT (order_item_id) for safe re-runs.
-- ============================================================================

WITH raw_lines AS (
    SELECT 
        o.order_id,
        o.order_number,
        o.order_timestamp,
        o.order_status,
        o.currency,
        o.customer_id,
        o.tax_amount AS order_tax,
        o.shipping_amount AS order_shipping,
        oi.order_item_id,
        oi.product_id,
        oi.quantity,
        oi.unit_price,
        (oi.quantity * oi.unit_price) AS line_gross,
        oi.discount_amount,
        oi.line_total AS line_net,
        SUM(oi.line_total) OVER (PARTITION BY o.order_id) AS order_subtotal
    FROM orders.orders o
    JOIN orders.order_items oi ON o.order_id = oi.order_id
),
allocated_lines AS (
    SELECT 
        rl.*,
        CASE 
            WHEN rl.order_subtotal > 0 THEN 
                ROUND((rl.line_net / rl.order_subtotal) * rl.order_tax, 2)
            ELSE 0.00 
        END AS line_tax_allocated,
        CASE 
            WHEN rl.order_subtotal > 0 THEN 
                ROUND((rl.line_net / rl.order_subtotal) * rl.order_shipping, 2)
            ELSE 0.00 
        END AS line_shipping_allocated
    FROM raw_lines rl
),
transformed_fact AS (
    SELECT 
        -- Surrogate Key Lookups (Decoupling from source UUIDs)
        COALESCE(d.date_key, -1) AS order_date_fk,
        COALESCE(c.customer_sk, -1) AS customer_fk,
        COALESCE(p.product_sk, -1) AS product_fk,
        -- Degenerate Dimensions
        al.order_number,
        al.order_item_id,
        al.order_status,
        al.currency,
        -- Additive Fact Metrics
        al.quantity,
        al.unit_price,
        al.line_gross AS line_gross_amount,
        al.discount_amount AS line_discount_amount,
        al.line_net AS net_sales_amount,
        ROUND(al.quantity * COALESCE(p.cost_price, 0.00), 2) AS cost_amount,
        ROUND(al.line_net - (al.quantity * COALESCE(p.cost_price, 0.00)), 2) AS gross_margin_amount,
        -- Allocated Measures
        al.line_tax_allocated AS allocated_tax_amount,
        al.line_shipping_allocated AS allocated_shipping_amount
    FROM allocated_lines al
    LEFT JOIN dwh.dim_date d 
        ON TO_CHAR(al.order_timestamp, 'YYYYMMDD')::INT = d.date_key
    LEFT JOIN dwh.dim_customer c 
        ON al.customer_id = c.customer_id
    LEFT JOIN dwh.dim_product p 
        ON al.product_id = p.product_id
)
INSERT INTO dwh.fact_sales_order_lines (
    order_date_fk,
    customer_fk,
    product_fk,
    order_number,
    order_item_id,
    order_status,
    currency,
    quantity,
    unit_price,
    line_gross_amount,
    line_discount_amount,
    net_sales_amount,
    cost_amount,
    gross_margin_amount,
    allocated_tax_amount,
    allocated_shipping_amount
)
SELECT 
    order_date_fk,
    customer_fk,
    product_fk,
    order_number,
    order_item_id,
    order_status,
    currency,
    quantity,
    unit_price,
    line_gross_amount,
    line_discount_amount,
    net_sales_amount,
    cost_amount,
    gross_margin_amount,
    allocated_tax_amount,
    allocated_shipping_amount
FROM transformed_fact
ON CONFLICT (order_item_id)
DO UPDATE SET
    order_status = EXCLUDED.order_status,
    net_sales_amount = EXCLUDED.net_sales_amount,
    gross_margin_amount = EXCLUDED.gross_margin_amount,
    allocated_tax_amount = EXCLUDED.allocated_tax_amount,
    allocated_shipping_amount = EXCLUDED.allocated_shipping_amount;

-- ----------------------------------------------------------------------------
-- VERIFICATION
-- ----------------------------------------------------------------------------
SELECT 
    count(*) AS total_fact_rows,
    SUM(quantity) AS total_units_sold,
    SUM(net_sales_amount) AS total_net_revenue,
    SUM(gross_margin_amount) AS total_gross_margin
FROM dwh.fact_sales_order_lines;
