-- =========================================================
-- CUSTOMER
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_addresses_customer
ON customer.addresses(customer_id);

CREATE INDEX IF NOT EXISTS idx_customer_events_customer_time
ON customer.customer_events(customer_id, event_timestamp);

CREATE INDEX IF NOT EXISTS idx_customer_events_type_time
ON customer.customer_events(event_type, event_timestamp);


-- =========================================================
-- CATALOG
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_products_category
ON catalog.products(category_id);

CREATE INDEX IF NOT EXISTS idx_product_prices_product
ON catalog.product_prices(product_id);

CREATE INDEX IF NOT EXISTS idx_product_prices_effective_from
ON catalog.product_prices(effective_from);


-- =========================================================
-- ORDERS
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_orders_customer
ON orders.orders(customer_id);

CREATE INDEX IF NOT EXISTS idx_orders_timestamp
ON orders.orders(order_timestamp);

CREATE INDEX IF NOT EXISTS idx_orders_customer_timestamp
ON orders.orders(customer_id, order_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_orders_status_timestamp
ON orders.orders(order_status, order_timestamp);

CREATE INDEX IF NOT EXISTS idx_order_items_order
ON orders.order_items(order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_product
ON orders.order_items(product_id);

CREATE INDEX IF NOT EXISTS idx_payments_order
ON orders.payments(order_id);

CREATE INDEX IF NOT EXISTS idx_payments_timestamp
ON orders.payments(payment_timestamp);


-- =========================================================
-- LOGISTICS
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_shipments_order
ON logistics.shipments(order_id);

CREATE INDEX IF NOT EXISTS idx_shipments_warehouse
ON logistics.shipments(warehouse_id);

CREATE INDEX IF NOT EXISTS idx_shipments_status
ON logistics.shipments(shipment_status);

CREATE INDEX IF NOT EXISTS idx_delivery_events_shipment_time
ON logistics.delivery_events(shipment_id, event_timestamp);

CREATE INDEX IF NOT EXISTS idx_delivery_events_type_time
ON logistics.delivery_events(event_type, event_timestamp);