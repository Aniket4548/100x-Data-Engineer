-- ============================================================================
-- WEEK 3: TOPIC 2 — Enterprise Date Dimension Generator (dim_date)
-- Description:
-- In analytical data warehouses, you NEVER perform date calculations on the fly
-- using DATE_TRUNC, EXTRACT, or string formatting across millions of fact rows.
-- Instead, every warehouse pre-generates a static `dim_date` covering 10–50 years.
--
-- Key Dimensional Principles Illustrated:
-- 1. Integer Surrogate Key formatted as YYYYMMDD (e.g. 20260115) for fast partitioning/joins.
-- 2. Pre-computed calendar and fiscal attributes (Quarter, Fiscal Year, Month Name).
-- 3. Boolean flags (is_weekend, is_holiday) for clean slicing without CASE statements in BI.
-- 4. The -1 Unknown Date Record Pattern for late-arriving or missing timestamps.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS dwh;

DROP TABLE IF EXISTS dwh.dim_date CASCADE;

CREATE TABLE dwh.dim_date (
    date_key INT PRIMARY KEY,                       -- Format: YYYYMMDD (e.g., 20260115) or -1 for Unknown
    calendar_date DATE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    quarter_name VARCHAR(10) NOT NULL,             -- 'Q1', 'Q2', etc.
    month INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,               -- 'January', 'February', etc.
    month_short VARCHAR(3) NOT NULL,               -- 'Jan', 'Feb', etc.
    year_month VARCHAR(7) NOT NULL,                -- '2026-01'
    day_of_month INT NOT NULL,
    day_of_week INT NOT NULL,                      -- 1 (Sunday) to 7 (Saturday) or ISO 1-7
    day_name VARCHAR(15) NOT NULL,                 -- 'Monday', 'Tuesday', etc.
    is_weekend BOOLEAN NOT NULL,
    iso_week INT NOT NULL,
    fiscal_year INT NOT NULL,                      -- Assuming Fiscal Year starts July 1st
    fiscal_quarter VARCHAR(10) NOT NULL,           -- 'FY26-Q3'
    is_holiday BOOLEAN DEFAULT FALSE,
    holiday_name VARCHAR(50)
);

-- ----------------------------------------------------------------------------
-- 1. Insert the Mandatory -1 "UNKNOWN" Date Record
-- ----------------------------------------------------------------------------
INSERT INTO dwh.dim_date (
    date_key, calendar_date, year, quarter, quarter_name,
    month, month_name, month_short, year_month, day_of_month,
    day_of_week, day_name, is_weekend, iso_week,
    fiscal_year, fiscal_quarter, is_holiday, holiday_name
) VALUES (
    -1, '1900-01-01', 1900, 0, 'Unknown',
    0, 'Unknown', 'Unk', '1900-00', 0,
    0, 'Unknown', FALSE, 0,
    1900, 'Unknown', FALSE, 'Not Applicable'
);

-- ----------------------------------------------------------------------------
-- 2. Populate 2024 to 2030 Using PostgreSQL generate_series
-- ----------------------------------------------------------------------------
INSERT INTO dwh.dim_date (
    date_key, calendar_date, year, quarter, quarter_name,
    month, month_name, month_short, year_month, day_of_month,
    day_of_week, day_name, is_weekend, iso_week,
    fiscal_year, fiscal_quarter, is_holiday, holiday_name
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT AS date_key,
    d::DATE AS calendar_date,
    EXTRACT(YEAR FROM d)::INT AS year,
    EXTRACT(QUARTER FROM d)::INT AS quarter,
    'Q' || EXTRACT(QUARTER FROM d)::TEXT AS quarter_name,
    EXTRACT(MONTH FROM d)::INT AS month,
    TRIM(TO_CHAR(d, 'Month')) AS month_name,
    TO_CHAR(d, 'Mon') AS month_short,
    TO_CHAR(d, 'YYYY-MM') AS year_month,
    EXTRACT(DAY FROM d)::INT AS day_of_month,
    EXTRACT(ISODOW FROM d)::INT AS day_of_week,
    TRIM(TO_CHAR(d, 'Day')) AS day_name,
    CASE WHEN EXTRACT(ISODOW FROM d) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend,
    EXTRACT(WEEK FROM d)::INT AS iso_week,
    CASE 
        WHEN EXTRACT(MONTH FROM d) >= 7 THEN EXTRACT(YEAR FROM d)::INT + 1
        ELSE EXTRACT(YEAR FROM d)::INT 
    END AS fiscal_year,
    CASE
        WHEN EXTRACT(MONTH FROM d) IN (7, 8, 9) THEN 'FY' || RIGHT(EXTRACT(YEAR FROM d)::TEXT, 2) || '-Q1'
        WHEN EXTRACT(MONTH FROM d) IN (10, 11, 12) THEN 'FY' || RIGHT(EXTRACT(YEAR FROM d)::TEXT, 2) || '-Q2'
        WHEN EXTRACT(MONTH FROM d) IN (1, 2, 3) THEN 'FY' || RIGHT((EXTRACT(YEAR FROM d) - 1)::TEXT, 2) || '-Q3'
        ELSE 'FY' || RIGHT((EXTRACT(YEAR FROM d) - 1)::TEXT, 2) || '-Q4'
    END AS fiscal_quarter,
    CASE 
        WHEN EXTRACT(MONTH FROM d) = 1 AND EXTRACT(DAY FROM d) = 1 THEN TRUE
        WHEN EXTRACT(MONTH FROM d) = 7 AND EXTRACT(DAY FROM d) = 4 THEN TRUE
        WHEN EXTRACT(MONTH FROM d) = 12 AND EXTRACT(DAY FROM d) = 25 THEN TRUE
        ELSE FALSE
    END AS is_holiday,
    CASE 
        WHEN EXTRACT(MONTH FROM d) = 1 AND EXTRACT(DAY FROM d) = 1 THEN 'New Year''s Day'
        WHEN EXTRACT(MONTH FROM d) = 7 AND EXTRACT(DAY FROM d) = 4 THEN 'Independence Day'
        WHEN EXTRACT(MONTH FROM d) = 12 AND EXTRACT(DAY FROM d) = 25 THEN 'Christmas Day'
        ELSE NULL
    END AS holiday_name
FROM GENERATE_SERIES('2024-01-01'::DATE, '2030-12-31'::DATE, '1 day'::INTERVAL) AS s(d);

-- Verification
SELECT 
    date_key, 
    calendar_date, 
    quarter_name, 
    fiscal_quarter, 
    is_weekend, 
    is_holiday,
    holiday_name
FROM dwh.dim_date
WHERE date_key IN (20250101, 20260115, 20260704, 20261225, -1)
ORDER BY date_key;
