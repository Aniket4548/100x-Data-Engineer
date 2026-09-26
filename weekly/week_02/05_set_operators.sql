-- WEEK 2: TOPIC 5 — Set Operators (UNION, UNION ALL, INTERSECT, EXCEPT)

-- Description:
-- Set operators combine rows from multiple queries vertically.
-- This file demonstrates execution rules, performance trade-offs, and how
-- Data Engineers use EXCEPT/UNION ALL for automated dataset reconciliation.

-- ----------------------------------------------------------------------------
-- PROBLEM 1: UNION ALL vs UNION (The Performance Rule)
-- Task: Combine active customer contact records with warehouse contact locations.
-- Rule: Default to UNION ALL to eliminate unnecessary Sort/Hash deduplication overhead.
-- ----------------------------------------------------------------------------

-- UNION ALL: Appends rows without sorting or deduplicating (O(N))
SELECT 'CUSTOMER' AS entity_type, city, country
FROM customer.addresses
WHERE
    is_default = TRUE
UNION ALL
SELECT 'WAREHOUSE' AS entity_type, city, country
FROM logistics.warehouses;

-- ----------------------------------------------------------------------------
-- PROBLEM 2: INTERSECT
-- Task: Find all cities that contain BOTH a warehouse facility AND at least
--       one registered customer address.
-- ----------------------------------------------------------------------------

SELECT city, country
FROM logistics.warehouses
INTERSECT
SELECT city, country
FROM customer.addresses
ORDER BY country, city;

-- ----------------------------------------------------------------------------
-- PROBLEM 3: EXCEPT
-- Task: Identify product SKUs that exist in the catalog as 'active' but have
--       NEVER been ordered in any line item.
-- ----------------------------------------------------------------------------

SELECT product_id
FROM catalog.products
WHERE
    status = 'active'
EXCEPT
SELECT DISTINCT
    product_id
FROM orders.order_items;

-- ----------------------------------------------------------------------------
-- PROBLEM 4: Production Data Reconciliation (Automated Staging vs Prod Diff)
-- Task: After an ELT pipeline syncs a staging table, verify whether the staging
--       and target tables are 100% identical. If not, output exact mismatched rows!
-- ----------------------------------------------------------------------------

CREATE TEMP TABLE stage_customers (
    customer_code VARCHAR(20),
    email VARCHAR(255),
    customer_status VARCHAR(20)
);

INSERT INTO
    stage_customers
VALUES (
        'CUST-001',
        'alice@example.com',
        'active'
    ),
    (
        'CUST-002',
        'bob@example.com',
        'inactive'
    ),
    (
        'CUST-003',
        'charlie@example.com',
        'active'
    );

CREATE TEMP TABLE prod_customers (
    customer_code VARCHAR(20),
    email VARCHAR(255),
    customer_status VARCHAR(20)
);

INSERT INTO
    prod_customers
VALUES (
        'CUST-001',
        'alice@example.com',
        'active'
    ),
    (
        'CUST-002',
        'bob@example.com',
        'active'
    ), -- Discrepancy!
    (
        'CUST-004',
        'david@example.com',
        'active'
    );
-- Missing in stage!

-- Bidirectional Diff Query
(
    SELECT
        'ONLY_IN_STAGING' AS diff_type,
        customer_code,
        email,
        customer_status
    FROM (
            SELECT
                customer_code, email, customer_status
            FROM stage_customers
            EXCEPT
            SELECT
                customer_code, email, customer_status
            FROM prod_customers
        ) s
)
UNION ALL
(
    SELECT
        'ONLY_IN_PROD' AS diff_type,
        customer_code,
        email,
        customer_status
    FROM (
            SELECT
                customer_code, email, customer_status
            FROM prod_customers
            EXCEPT
            SELECT
                customer_code, email, customer_status
            FROM stage_customers
        ) p
);

DROP TABLE stage_customers;

DROP TABLE prod_customers;