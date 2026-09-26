-- WEEK 2: TOPIC 7 — The SQL Standard MERGE Statement

-- Description:
-- MERGE (introduced in PostgreSQL 15 and standard in Snowflake/BigQuery/Oracle)
-- synchronizes a target table with a source dataset in a single atomic command.

-- ----------------------------------------------------------------------------
-- SETUP: Create Staging and Target Tables for Demonstration
-- ----------------------------------------------------------------------------

CREATE TEMP TABLE dim_product_target (
    sku VARCHAR(50) PRIMARY KEY,
    product_name VARCHAR(255),
    cost_price NUMERIC(10, 2),
    status VARCHAR(20),
    is_deleted BOOLEAN DEFAULT FALSE,
    last_synced_at TIMESTAMPTZ
);

CREATE TEMP TABLE stg_product_source (
    sku VARCHAR(50),
    product_name VARCHAR(255),
    cost_price NUMERIC(10, 2),
    status VARCHAR(20),
    action VARCHAR(20) -- 'UPSERT', 'DELETE'
);

-- Seed baseline data
INSERT INTO
    dim_product_target (
        sku,
        product_name,
        cost_price,
        status,
        last_synced_at
    )
VALUES (
        'SKU-101',
        'Wireless Mouse',
        25.00,
        'active',
        NOW() - INTERVAL '1 day'
    ),
    (
        'SKU-102',
        'Mechanical Keyboard',
        80.00,
        'active',
        NOW() - INTERVAL '1 day'
    ),
    (
        'SKU-103',
        'HDMI Cable 2m',
        10.00,
        'active',
        NOW() - INTERVAL '1 day'
    );

-- Incoming CDC batch
INSERT INTO
    stg_product_source (
        sku,
        product_name,
        cost_price,
        status,
        action
    )
VALUES (
        'SKU-101',
        'Wireless Mouse V2',
        28.50,
        'active',
        'UPSERT'
    ), -- Price change & rename
    (
        'SKU-103',
        'HDMI Cable 2m',
        10.00,
        'discontinued',
        'DELETE'
    ), -- Request to remove
    (
        'SKU-104',
        'USB-C Hub Multiport',
        45.00,
        'active',
        'UPSERT'
    );
-- Brand new item

-- ----------------------------------------------------------------------------
-- PROBLEM 1: Comprehensive Multi-Action MERGE
-- Task: In a single atomic statement:
--       - DELETE rows marked for deletion
--       - UPDATE existing products with new prices/names
--       - INSERT newly discovered products
-- ----------------------------------------------------------------------------

MERGE INTO dim_product_target AS target USING stg_product_source AS source ON target.sku = source.sku

-- Branch 1: Matched and source requests deletion
WHEN MATCHED AND source.action = 'DELETE' THEN DELETE

-- Branch 2: Matched and updated data arrived
WHEN MATCHED
AND (
    target.cost_price != source.cost_price
    OR target.product_name != source.product_name
) THEN
UPDATE
SET
    product_name = source.product_name,
    cost_price = source.cost_price,
    status = source.status,
    last_synced_at = NOW()

-- Branch 3: Not matched -> Insert brand new record
WHEN NOT MATCHED THEN INSERT (
    sku,
    product_name,
    cost_price,
    status,
    is_deleted,
    last_synced_at
)
VALUES (
        source.sku,
        source.product_name,
        source.cost_price,
        source.status,
        FALSE,
        NOW()
    );

-- Verification
SELECT * FROM dim_product_target ORDER BY sku;

DROP TABLE dim_product_target;

DROP TABLE stg_product_source;