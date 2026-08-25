CREATE OR REPLACE VIEW orders.v_customer_order_summary AS
SELECT
    o.customer_id,
    COUNT(*) AS total_orders,
    SUM(o.total_amount) AS total_revenue,
    AVG(o.total_amount) AS average_order_value,
    MIN(o.order_timestamp) AS first_order_at,
    MAX(o.order_timestamp) AS latest_order_at
FROM orders.orders o
GROUP BY o.customer_id;


CREATE OR REPLACE VIEW orders.v_product_sales AS
SELECT
    oi.product_id,
    p.product_name,
    p.category_id,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.line_total) AS revenue
FROM orders.order_items oi
JOIN catalog.products p
    ON oi.product_id = p.product_id
GROUP BY
    oi.product_id,
    p.product_name,
    p.category_id;


CREATE OR REPLACE VIEW orders.v_daily_revenue AS
SELECT
    DATE(order_timestamp) AS order_date,
    COUNT(*) AS total_orders,
    SUM(total_amount) AS revenue
FROM orders.orders
WHERE order_status NOT IN (
    'cancelled',
    'refunded'
)
GROUP BY DATE(order_timestamp);

CREATE OR REPLACE VIEW customer.v_customer_activity AS
SELECT
    customer_id,
    DATE(event_timestamp) AS activity_date,
    COUNT(*) AS event_count,
    COUNT(DISTINCT event_type) AS event_types
FROM customer.customer_events
GROUP BY
    customer_id,
    DATE(event_timestamp);


