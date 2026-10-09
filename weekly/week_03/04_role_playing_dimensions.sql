-- ============================================================================
-- WEEK 3: TOPIC 4 — Role-Playing Dimensions
-- Description:
-- A Role-Playing Dimension occurs when a single physical dimension table
-- (such as dwh.dim_date) is referenced multiple times within the same fact or analysis
-- under different business contexts:
--   - Order Placed Date    (from orders.orders.order_timestamp)
--   - Payment Cleared Date (from orders.payments.payment_timestamp)
--   - Shipment Date        (from logistics.shipments.shipped_at)
--   - Delivery Date        (from logistics.shipments.delivered_at)
--
-- Why Role Views & Aliasing Matter:
-- Instead of maintaining four distinct physical date tables, we create views
-- or aliased joins against the single conformed dwh.dim_date.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS dwh;

-- ----------------------------------------------------------------------------
-- 1. ROLE-PLAYING VIEWS FOR BI CONSUMPTION
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW dwh.dim_order_date AS
SELECT 
    date_key AS order_date_key,
    calendar_date AS order_date,
    year AS order_year,
    quarter_name AS order_quarter,
    month_name AS order_month,
    year_month AS order_year_month,
    is_weekend AS order_is_weekend,
    is_holiday AS order_is_holiday
FROM dwh.dim_date;

CREATE OR REPLACE VIEW dwh.dim_shipment_date AS
SELECT 
    date_key AS shipment_date_key,
    calendar_date AS shipment_date,
    year AS shipment_year,
    quarter_name AS shipment_quarter,
    month_name AS shipment_month,
    year_month AS shipment_year_month,
    is_weekend AS shipment_is_weekend,
    is_holiday AS shipment_is_holiday
FROM dwh.dim_date;

CREATE OR REPLACE VIEW dwh.dim_delivery_date AS
SELECT 
    date_key AS delivery_date_key,
    calendar_date AS delivery_date,
    year AS delivery_year,
    quarter_name AS delivery_quarter,
    month_name AS delivery_month,
    year_month AS delivery_year_month,
    is_weekend AS delivery_is_weekend,
    is_holiday AS delivery_is_holiday
FROM dwh.dim_date;

-- ----------------------------------------------------------------------------
-- 2. PRACTICAL MULTI-ROLE QUERY ON LIVE DATA
-- Task: Measure carrier fulfillment speed (Order to Ship to Delivery) across
--       different months and weekend vs weekday orders.
-- ----------------------------------------------------------------------------

SELECT 
    o.order_number,
    s.carrier,
    -- Role 1: Order Date
    d_order.calendar_date AS order_date,
    d_order.day_name AS order_day,
    d_order.is_weekend AS ordered_on_weekend,
    -- Role 2: Shipped Date
    d_ship.calendar_date AS shipped_date,
    -- Role 3: Delivered Date
    d_deliv.calendar_date AS delivered_date,
    -- Calculated Lags across Roles
    CASE 
        WHEN s.shipped_at IS NOT NULL THEN 
            (d_ship.calendar_date - d_order.calendar_date)
        ELSE NULL 
    END AS days_to_ship,
    CASE 
        WHEN s.delivered_at IS NOT NULL AND s.shipped_at IS NOT NULL THEN 
            (d_deliv.calendar_date - d_ship.calendar_date)
        ELSE NULL 
    END AS days_in_transit,
    CASE 
        WHEN s.delivered_at IS NOT NULL THEN 
            (d_deliv.calendar_date - d_order.calendar_date)
        ELSE NULL 
    END AS total_delivery_lead_days
FROM orders.orders o
JOIN logistics.shipments s ON o.order_id = s.order_id
-- Role Join 1: Order Date
JOIN dwh.dim_date d_order 
    ON TO_CHAR(o.order_timestamp, 'YYYYMMDD')::INT = d_order.date_key
-- Role Join 2: Shipped Date (-1 Fallback if null)
JOIN dwh.dim_date d_ship 
    ON COALESCE(TO_CHAR(s.shipped_at, 'YYYYMMDD')::INT, -1) = d_ship.date_key
-- Role Join 3: Delivered Date (-1 Fallback if null)
JOIN dwh.dim_date d_deliv 
    ON COALESCE(TO_CHAR(s.delivered_at, 'YYYYMMDD')::INT, -1) = d_deliv.date_key
WHERE o.order_status = 'delivered'
ORDER BY total_delivery_lead_days DESC
LIMIT 15;
