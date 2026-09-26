-- WEEK 2: TOPIC 8 — Production Upsert Patterns & Idempotency

-- Description:
-- High-throughput ELT pipelines rely on INSERT ... ON CONFLICT (UPSERT)
-- because it prevents concurrency deadlocks, eliminates race conditions, and
-- provides complete pipeline idempotency.

-- ----------------------------------------------------------------------------
-- SETUP: Create Target Inventory Table
-- ----------------------------------------------------------------------------

CREATE TEMP TABLE warehouse_inventory (
    warehouse_id UUID,
    sku VARCHAR(50),
    stock_quantity INTEGER NOT NULL,
    reserved_quantity INTEGER NOT NULL DEFAULT 0,
    last_updated_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (warehouse_id, sku)
);

-- Seed initial stock
INSERT INTO
    warehouse_inventory
VALUES (
        '11111111-1111-1111-1111-111111111111',
        'SKU-001',
        100,
        10,
        NOW() - INTERVAL '2 hours'
    ),
    (
        '11111111-1111-1111-1111-111111111111',
        'SKU-002',
        50,
        5,
        NOW() - INTERVAL '2 hours'
    );

-- ----------------------------------------------------------------------------
-- PATTERN 1: Idempotent Deduplication with DO NOTHING
-- Use Case: Ingesting events or log records where duplicates must simply be ignored.
-- ----------------------------------------------------------------------------

INSERT INTO
    warehouse_inventory (
        warehouse_id,
        sku,
        stock_quantity,
        reserved_quantity,
        last_updated_at
    )
VALUES (
        '11111111-1111-1111-1111-111111111111',
        'SKU-001',
        100,
        10,
        NOW()
    ), -- Duplicate, will be skipped
    (
        '11111111-1111-1111-1111-111111111111',
        'SKU-003',
        200,
        0,
        NOW()
    ) -- New record, will be inserted
ON CONFLICT (warehouse_id, sku) DO NOTHING;

-- ----------------------------------------------------------------------------
-- PATTERN 2: Atomic Upsert with EXCLUDED & No-Op Suppression
-- Use Case: Syncing latest stock levels from inventory scanners.
-- Note: The WHERE clause prevents creating dead tuple row versions if quantities haven't changed!
-- ----------------------------------------------------------------------------

INSERT INTO
    warehouse_inventory (
        warehouse_id,
        sku,
        stock_quantity,
        reserved_quantity,
        last_updated_at
    )
VALUES (
        '11111111-1111-1111-1111-111111111111',
        'SKU-001',
        85,
        15,
        NOW()
    ), -- Stock changed!
    (
        '11111111-1111-1111-1111-111111111111',
        'SKU-002',
        50,
        5,
        NOW()
    ) -- Identical, no-op write suppressed!
ON CONFLICT (warehouse_id, sku) DO
UPDATE
SET
    stock_quantity = EXCLUDED.stock_quantity,
    reserved_quantity = EXCLUDED.reserved_quantity,
    last_updated_at = EXCLUDED.last_updated_at
WHERE
    warehouse_inventory.stock_quantity != EXCLUDED.stock_quantity
    OR warehouse_inventory.reserved_quantity != EXCLUDED.reserved_quantity;

-- ----------------------------------------------------------------------------
-- PATTERN 3: Bulk Batch Ingestion from Staging
-- Use Case: Loading 100,000+ staged records into target production table in one SQL statement.
-- ----------------------------------------------------------------------------

CREATE TEMP TABLE stg_inventory_batch (
    warehouse_id UUID,
    sku VARCHAR(50),
    new_quantity INTEGER,
    batch_timestamp TIMESTAMPTZ
);

INSERT INTO
    stg_inventory_batch
VALUES (
        '11111111-1111-1111-1111-111111111111',
        'SKU-001',
        120,
        NOW()
    ),
    (
        '11111111-1111-1111-1111-111111111111',
        'SKU-004',
        300,
        NOW()
    );

INSERT INTO
    warehouse_inventory (
        warehouse_id,
        sku,
        stock_quantity,
        reserved_quantity,
        last_updated_at
    )
SELECT
    warehouse_id,
    sku,
    new_quantity,
    0 AS reserved_quantity,
    batch_timestamp
FROM stg_inventory_batch
ON CONFLICT (warehouse_id, sku) DO
UPDATE
SET
    stock_quantity = EXCLUDED.stock_quantity,
    last_updated_at = EXCLUDED.last_updated_at;

-- Final Verification
SELECT * FROM warehouse_inventory ORDER BY sku;

DROP TABLE warehouse_inventory;

DROP TABLE stg_inventory_batch;