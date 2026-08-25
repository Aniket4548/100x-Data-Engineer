-- =========================================================
-- CUSTOMER
-- =========================================================

CREATE TABLE IF NOT EXISTS customer.customers (
    customer_id UUID PRIMARY KEY,
    customer_code VARCHAR(20) NOT NULL UNIQUE,

    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,

    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(30),

    date_of_birth DATE,
    signup_date TIMESTAMPTZ NOT NULL,

    country VARCHAR(100) NOT NULL,

    customer_status VARCHAR(20) NOT NULL
        CHECK (
            customer_status IN (
                'active',
                'inactive',
                'suspended'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);


CREATE TABLE IF NOT EXISTS customer.addresses (
    address_id UUID PRIMARY KEY,

    customer_id UUID NOT NULL,

    address_type VARCHAR(20) NOT NULL
        CHECK (
            address_type IN (
                'home',
                'work',
                'billing',
                'shipping'
            )
        ),

    address_line_1 VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100) NOT NULL,

    is_default BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_address_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer.customers(customer_id)
);


CREATE TABLE IF NOT EXISTS customer.customer_events (
    event_id UUID PRIMARY KEY,

    customer_id UUID NOT NULL,

    event_type VARCHAR(50) NOT NULL,

    event_timestamp TIMESTAMPTZ NOT NULL,

    session_id UUID NOT NULL,

    device_type VARCHAR(30) NOT NULL,

    platform VARCHAR(30) NOT NULL,

    metadata JSONB,

    CONSTRAINT fk_event_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer.customers(customer_id)
);


-- =========================================================
-- CATALOG
-- =========================================================

CREATE TABLE IF NOT EXISTS catalog.categories (
    category_id UUID PRIMARY KEY,

    category_name VARCHAR(100) NOT NULL UNIQUE,

    parent_category_id UUID,

    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_category_parent
        FOREIGN KEY (parent_category_id)
        REFERENCES catalog.categories(category_id)
);


CREATE TABLE IF NOT EXISTS catalog.products (
    product_id UUID PRIMARY KEY,

    sku VARCHAR(50) NOT NULL UNIQUE,

    product_name VARCHAR(255) NOT NULL,

    category_id UUID NOT NULL,

    brand VARCHAR(100) NOT NULL,

    cost_price NUMERIC(12, 2) NOT NULL
        CHECK (cost_price >= 0),

    status VARCHAR(20) NOT NULL
        CHECK (
            status IN (
                'active',
                'inactive',
                'discontinued'
            )
        ),

    launch_date DATE NOT NULL,

    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id)
        REFERENCES catalog.categories(category_id)
);


CREATE TABLE IF NOT EXISTS catalog.product_prices (
    product_price_id UUID PRIMARY KEY,

    product_id UUID NOT NULL,

    price NUMERIC(12, 2) NOT NULL
        CHECK (price >= 0),

    currency CHAR(3) NOT NULL,

    effective_from TIMESTAMPTZ NOT NULL,

    effective_to TIMESTAMPTZ,

    CONSTRAINT fk_price_product
        FOREIGN KEY (product_id)
        REFERENCES catalog.products(product_id),

    CONSTRAINT chk_price_dates
        CHECK (
            effective_to IS NULL
            OR effective_to > effective_from
        )
);


-- =========================================================
-- ORDERS
-- =========================================================

CREATE TABLE IF NOT EXISTS orders.orders (
    order_id UUID PRIMARY KEY,

    order_number VARCHAR(30) NOT NULL UNIQUE,

    customer_id UUID NOT NULL,

    order_timestamp TIMESTAMPTZ NOT NULL,

    order_status VARCHAR(30) NOT NULL
        CHECK (
            order_status IN (
                'pending',
                'confirmed',
                'processing',
                'shipped',
                'delivered',
                'cancelled',
                'refunded'
            )
        ),

    currency CHAR(3) NOT NULL,

    subtotal NUMERIC(14, 2) NOT NULL
        CHECK (subtotal >= 0),

    discount_amount NUMERIC(14, 2) NOT NULL
        CHECK (discount_amount >= 0),

    tax_amount NUMERIC(14, 2) NOT NULL
        CHECK (tax_amount >= 0),

    shipping_amount NUMERIC(14, 2) NOT NULL
        CHECK (shipping_amount >= 0),

    total_amount NUMERIC(14, 2) NOT NULL
        CHECK (total_amount >= 0),

    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer.customers(customer_id)
);


CREATE TABLE IF NOT EXISTS orders.order_items (
    order_item_id UUID PRIMARY KEY,

    order_id UUID NOT NULL,

    product_id UUID NOT NULL,

    quantity INTEGER NOT NULL
        CHECK (quantity > 0),

    unit_price NUMERIC(12, 2) NOT NULL
        CHECK (unit_price >= 0),

    discount_amount NUMERIC(12, 2) NOT NULL
        CHECK (discount_amount >= 0),

    line_total NUMERIC(14, 2) NOT NULL
        CHECK (line_total >= 0),

    CONSTRAINT fk_order_item_order
        FOREIGN KEY (order_id)
        REFERENCES orders.orders(order_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_item_product
        FOREIGN KEY (product_id)
        REFERENCES catalog.products(product_id)
);


CREATE TABLE IF NOT EXISTS orders.payments (
    payment_id UUID PRIMARY KEY,

    order_id UUID NOT NULL,

    payment_reference VARCHAR(50) NOT NULL UNIQUE,

    payment_method VARCHAR(30) NOT NULL
        CHECK (
            payment_method IN (
                'credit_card',
                'debit_card',
                'upi',
                'net_banking',
                'wallet'
            )
        ),

    payment_status VARCHAR(30) NOT NULL
        CHECK (
            payment_status IN (
                'pending',
                'successful',
                'failed',
                'refunded'
            )
        ),

    amount NUMERIC(14, 2) NOT NULL
        CHECK (amount >= 0),

    payment_timestamp TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_payment_order
        FOREIGN KEY (order_id)
        REFERENCES orders.orders(order_id)
);


-- =========================================================
-- LOGISTICS
-- =========================================================

CREATE TABLE IF NOT EXISTS logistics.warehouses (
    warehouse_id UUID PRIMARY KEY,

    warehouse_code VARCHAR(30) NOT NULL UNIQUE,

    warehouse_name VARCHAR(150) NOT NULL,

    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    country VARCHAR(100) NOT NULL,

    capacity INTEGER NOT NULL
        CHECK (capacity > 0),

    created_at TIMESTAMPTZ NOT NULL
);


CREATE TABLE IF NOT EXISTS logistics.shipments (
    shipment_id UUID PRIMARY KEY,

    order_id UUID NOT NULL,

    warehouse_id UUID NOT NULL,

    tracking_number VARCHAR(100) NOT NULL UNIQUE,

    carrier VARCHAR(100) NOT NULL,

    shipment_status VARCHAR(30) NOT NULL
        CHECK (
            shipment_status IN (
                'created',
                'packed',
                'shipped',
                'in_transit',
                'out_for_delivery',
                'delivered',
                'failed'
            )
        ),

    shipped_at TIMESTAMPTZ,

    estimated_delivery_at TIMESTAMPTZ,

    delivered_at TIMESTAMPTZ,

    CONSTRAINT fk_shipment_order
        FOREIGN KEY (order_id)
        REFERENCES orders.orders(order_id),

    CONSTRAINT fk_shipment_warehouse
        FOREIGN KEY (warehouse_id)
        REFERENCES logistics.warehouses(warehouse_id),

    CONSTRAINT chk_delivery_date
        CHECK (
            delivered_at IS NULL
            OR shipped_at IS NULL
            OR delivered_at >= shipped_at
        )
);


CREATE TABLE IF NOT EXISTS logistics.delivery_events (
    delivery_event_id UUID PRIMARY KEY,

    shipment_id UUID NOT NULL,

    event_type VARCHAR(50) NOT NULL,

    event_timestamp TIMESTAMPTZ NOT NULL,

    location VARCHAR(150),

    remarks TEXT,

    CONSTRAINT fk_delivery_event_shipment
        FOREIGN KEY (shipment_id)
        REFERENCES logistics.shipments(shipment_id)
        ON DELETE CASCADE
);