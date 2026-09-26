-- WEEK 2: TOPIC 10 — Slowly Changing Dimensions (SCD Types 0 to 3)

-- Description:
-- In Data Warehousing and Dimensional Modeling (Ralph Kimball methodology),
-- dimensions change slowly over time. How your warehouse captures these changes
-- dictates historical accuracy, query complexity, and storage overhead.
--
-- This file implements production SQL patterns for:
--   • SCD Type 0: Retain Original (Fixed / Immutable)
--   • SCD Type 1: Overwrite (Current State Only, No History)
--   • SCD Type 2: Add New Row (Full Historical Versioning with Validity Windows)
--   • SCD Type 3: Add New Attribute (Limited History: Previous & Current)

-- 1. SCD TYPE 0: RETAIN ORIGINAL (IMMUTABLE / FIXED)

-- Concept:
-- The dimension attribute is never updated once written. Any subsequent changes
-- arriving from source systems are ignored.
--
-- Real-World Use Cases:
--   • Original account registration date
--   • Customer date of birth
--   • Initial acquisition campaign / referral code
-- ----------------------------------------------------------------------------

CREATE TEMP TABLE dim_customer_scd0 (
    customer_id UUID PRIMARY KEY,
    customer_code VARCHAR(20) NOT NULL UNIQUE,
    date_of_birth DATE NOT NULL,
    acquisition_channel VARCHAR(50) NOT NULL,
    first_signup_timestamp TIMESTAMPTZ NOT NULL
);

-- Seed initial record
INSERT INTO
    dim_customer_scd0
VALUES (
        'a0000000-0000-0000-0000-000000000001',
        'CUST-001',
        '1995-06-15',
        'organic_search',
        '2026-01-01 10:00:00+00'
    );

-- SCD Type 0 Ingestion Pattern: DO NOTHING on conflict
-- Source tries to change acquisition_channel or date_of_birth -> Rejected/Ignored!
INSERT INTO
    dim_customer_scd0 (
        customer_id,
        customer_code,
        date_of_birth,
        acquisition_channel,
        first_signup_timestamp
    )
VALUES (
        'a0000000-0000-0000-0000-000000000001',
        'CUST-001',
        '1995-06-15',
        'paid_ads',
        '2026-01-01 10:00:00+00'
    )
ON CONFLICT (customer_id) DO NOTHING;

-- Verification: acquisition_channel remains 'organic_search'
SELECT * FROM dim_customer_scd0;

-- 2. SCD TYPE 1: OVERWRITE (CURRENT STATE ONLY)

-- Concept:
-- Overwrites the existing record with the new incoming value. No history is
-- maintained. Past facts joined to this dimension will reflect the NEW state.
--
-- Real-World Use Cases:
--   • Correcting data entry typos (name, phone number)
--   • Current customer email address or phone number
--   • Product list prices where historical prices are tracked in a separate price log
--
-- Trade-offs:
--   ✅ Simple schema and trivial queries
--   ❌ Completely destroys historical context (cannot answer: "What was customer's phone when order #100 was placed?")
-- ----------------------------------------------------------------------------

CREATE TEMP TABLE dim_customer_scd1 (
    customer_id UUID PRIMARY KEY,
    customer_code VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(30),
    updated_at TIMESTAMPTZ NOT NULL
);

-- Seed initial record
INSERT INTO
    dim_customer_scd1
VALUES (
        'a0000000-0000-0000-0000-000000000001',
        'CUST-001',
        'Alice',
        'Smith',
        'alice@oldmail.com',
        '+1-555-0100',
        '2026-01-01 10:00:00+00'
    );

-- SCD Type 1 Ingestion Pattern: Atomic Upsert Overwrite
INSERT INTO
    dim_customer_scd1 (
        customer_id,
        customer_code,
        first_name,
        last_name,
        email,
        phone,
        updated_at
    )
VALUES (
        'a0000000-0000-0000-0000-000000000001',
        'CUST-001',
        'Alice',
        'Smith-Johnson',
        'alice@newmail.com',
        '+1-555-0999',
        NOW()
    )
ON CONFLICT (customer_id) DO
UPDATE
SET
    last_name = EXCLUDED.last_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    updated_at = EXCLUDED.updated_at;

-- Verification: Prior email and phone are completely overwritten
SELECT * FROM dim_customer_scd1;

-- 3. SCD TYPE 2: ADD NEW ROW (FULL HISTORICAL VERSIONING)

-- Concept:
-- The industry standard for auditability and true point-in-time analytical accuracy.
-- When a tracked attribute changes:
--   1. The existing active row is closed (valid_to is set, is_current set to FALSE).
--   2. A new row is inserted with a new Surrogate Key, valid_from = current time,
--      valid_to = 'infinity' / '9999-12-31', and is_current = TRUE.
--
-- Real-World Use Cases:
--   • Customer address changes (state/country tax compliance & regional sales attribution)
--   • Customer subscription tier (Free -> Pro -> Enterprise)
--   • Product department / category reclassification
--   • Employee department or job title changes
-- ----------------------------------------------------------------------------

CREATE TEMP TABLE dim_customer_scd2 (
    customer_sk BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Surrogate Key
    customer_id UUID NOT NULL, -- Natural / Business Key
    customer_code VARCHAR(20) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    membership_tier VARCHAR(20) NOT NULL, -- Tracked attribute!
    country VARCHAR(100) NOT NULL, -- Tracked attribute!
    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00',
    is_current BOOLEAN NOT NULL DEFAULT TRUE
);

-- Natural key + valid_from uniqueness guarantee
CREATE UNIQUE INDEX uq_dim_customer_scd2 ON dim_customer_scd2 (customer_id, valid_from);

-- Seed initial version (V1: Bronze tier, registered in UK)
INSERT INTO
    dim_customer_scd2 (
        customer_id,
        customer_code,
        first_name,
        last_name,
        membership_tier,
        country,
        valid_from
    )
VALUES (
        'a0000000-0000-0000-0000-000000000001',
        'CUST-001',
        'Alice',
        'Smith',
        'Bronze',
        'UK',
        '2026-01-01 00:00:00+00'
    );

-- Incoming CDC update at 2026-06-01: Alice upgraded to 'Gold' and moved to 'USA'
CREATE TEMP TABLE stg_incoming_customer_update (
    customer_id UUID,
    customer_code VARCHAR(20),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    membership_tier VARCHAR(20),
    country VARCHAR(100),
    change_timestamp TIMESTAMPTZ
);

INSERT INTO
    stg_incoming_customer_update
VALUES (
        'a0000000-0000-0000-0000-000000000001',
        'CUST-001',
        'Alice',
        'Smith',
        'Gold',
        'USA',
        '2026-06-01 12:00:00+00'
    );

-- Production Atomic SCD Type 2 Pipeline Step (Using CTEs)
WITH
    incoming_diff AS (
        -- Find rows where tracked attributes actually changed
        SELECT src.customer_id, src.customer_code, src.first_name, src.last_name, src.membership_tier, src.country, src.change_timestamp
        FROM
            stg_incoming_customer_update src
            JOIN dim_customer_scd2 tgt ON src.customer_id = tgt.customer_id
            AND tgt.is_current = TRUE
        WHERE
            tgt.membership_tier != src.membership_tier
            OR tgt.country != src.country
    ),
    expire_old_records AS (
        -- Step 1: Expire the current record
        UPDATE dim_customer_scd2 tgt
        SET
            valid_to = diff.change_timestamp,
            is_current = FALSE
        FROM incoming_diff diff
        WHERE
            tgt.customer_id = diff.customer_id
            AND tgt.is_current = TRUE
        RETURNING
            tgt.customer_id
    )
    -- Step 2: Insert new version (V2)
INSERT INTO
    dim_customer_scd2 (
        customer_id,
        customer_code,
        first_name,
        last_name,
        membership_tier,
        country,
        valid_from,
        valid_to,
        is_current
    )
SELECT
    diff.customer_id,
    diff.customer_code,
    diff.first_name,
    diff.last_name,
    diff.membership_tier,
    diff.country,
    diff.change_timestamp AS valid_from,
    '9999-12-31 23:59:59+00'::TIMESTAMPTZ AS valid_to,
    TRUE AS is_current
FROM
    incoming_diff diff
    JOIN expire_old_records e ON diff.customer_id = e.customer_id;

-- ----------------------------------------------------------------------------
-- HOW TO QUERY SCD TYPE 2 IN PRODUCTION
-- ----------------------------------------------------------------------------

-- Query A: Get Current State (Fast lookups for real-time dashboards)
SELECT
    customer_code,
    membership_tier,
    country
FROM dim_customer_scd2
WHERE
    is_current = TRUE;

-- Query B: Point-In-Time Historical Reconstruction (As-of query)
-- "What was Alice's tier and country when she made a purchase on 2026-03-15?"
SELECT
    customer_code,
    membership_tier,
    country,
    valid_from,
    valid_to
FROM dim_customer_scd2
WHERE
    customer_id = 'a0000000-0000-0000-0000-000000000001'
    AND '2026-03-15 15:00:00+00' >= valid_from
    AND '2026-03-15 15:00:00+00' < valid_to;
-- Result: 'Bronze' and 'UK' (Historical accuracy is perfectly preserved!)

-- 4. SCD TYPE 3: ADD NEW ATTRIBUTE (PREVIOUS & CURRENT VALUE)

-- Concept:
-- Preserves a limited snapshot of history by adding dedicated columns for
-- previous values directly within the SAME row.
--
-- Real-World Use Cases:
--   • Territory realignment (current_sales_rep vs previous_sales_rep)
--   • Customer tier migration (current_tier vs previous_tier)
--   • Tax jurisdiction change
--
-- Trade-offs:
--   ✅ No row multiplication (1 customer = 1 row)
--   ❌ Can only remember 1 previous change; historical depth beyond that is lost.
-- ----------------------------------------------------------------------------

CREATE TEMP TABLE dim_customer_scd3 (
    customer_id UUID PRIMARY KEY,
    customer_code VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    current_tier VARCHAR(20) NOT NULL,
    previous_tier VARCHAR(20),
    tier_effective_date TIMESTAMPTZ NOT NULL
);

-- Seed initial record
INSERT INTO
    dim_customer_scd3
VALUES (
        'a0000000-0000-0000-0000-000000000001',
        'CUST-001',
        'Alice',
        'Bronze',
        NULL,
        '2026-01-01 00:00:00+00'
    );

-- SCD Type 3 Ingestion Pattern: Shift current into previous on update
CREATE TEMP TABLE stg_tier_change (
    customer_id UUID,
    new_tier VARCHAR(20),
    effective_time TIMESTAMPTZ
);

INSERT INTO
    stg_tier_change
VALUES (
        'a0000000-0000-0000-0000-000000000001',
        'Gold',
        '2026-06-01 00:00:00+00'
    );

UPDATE dim_customer_scd3 tgt
SET
    previous_tier = tgt.current_tier, -- Shift current into previous!
    current_tier = src.new_tier, -- Set new current tier
    tier_effective_date = src.effective_time
FROM stg_tier_change src
WHERE
    tgt.customer_id = src.customer_id
    AND tgt.current_tier != src.new_tier;

-- Verification: Shows both Current ('Gold') and Previous ('Bronze')
SELECT * FROM dim_customer_scd3;

-- 5. MASTER COMPARISON MATRIX: SCD 0, 1, 2, 3

/*
┌───────┬──────────────────────────┬──────────────────────┬──────────────────────┬────────────────────────────────┐
│ Type  │ Strategy                 │ Rows per Entity      │ History Preserved    │ Typical Use Case               │
├───────┼──────────────────────────┼──────────────────────┼──────────────────────┼────────────────────────────────┤
│ SCD 0 │ Retain Original          │ Exactly 1            │ None (Frozen initial)│ Date of birth, signup date     │
│ SCD 1 │ Overwrite In-Place       │ Exactly 1            │ None (Latest only)   │ Typo corrections, current phone│
│ SCD 2 │ Add New Row with Dates   │ N rows (1 per change)│ Complete history     │ Subscriptions, tax addresses   │
│ SCD 3 │ Previous & Current Col   │ Exactly 1            │ 1 previous snapshot  │ Sales territories, tier shifts │
└───────┴──────────────────────────┴──────────────────────┴──────────────────────┴────────────────────────────────┘
*/

-- Clean up
DROP TABLE dim_customer_scd0;

DROP TABLE dim_customer_scd1;

DROP TABLE dim_customer_scd2;

DROP TABLE stg_incoming_customer_update;

DROP TABLE dim_customer_scd3;

DROP TABLE stg_tier_change;
