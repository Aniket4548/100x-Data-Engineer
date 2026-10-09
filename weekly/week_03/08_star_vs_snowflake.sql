-- ============================================================================
-- WEEK 3: TOPIC 8 — Star Schema vs Snowflake Schema Deep Dive
-- Description:
-- Side-by-side architectural implementation and benchmark comparing
-- Star Schema (denormalized dimensions) vs Snowflake Schema (normalized dimensions)
-- using your actual product catalog data.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS snowflake;

-- ----------------------------------------------------------------------------
-- 1. BUILD SNOWFLAKE HIERARCHY FOR COMPARISON
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS snowflake.dim_product_snowflaked CASCADE;
DROP TABLE IF EXISTS snowflake.dim_category CASCADE;

CREATE TABLE snowflake.dim_category (
    category_sk SERIAL PRIMARY KEY,
    category_id UUID NOT NULL UNIQUE,
    category_name VARCHAR(100) NOT NULL
);

CREATE TABLE snowflake.dim_product_snowflaked (
    product_sk SERIAL PRIMARY KEY,
    product_id UUID NOT NULL UNIQUE,
    sku VARCHAR(50) NOT NULL,
    product_name VARCHAR(150) NOT NULL,
    brand VARCHAR(100) NOT NULL,
    category_fk INT REFERENCES snowflake.dim_category(category_sk),
    cost_price NUMERIC(10, 2) NOT NULL
);

-- Seed Snowflake Sub-Dimensions from your real catalog tables
INSERT INTO snowflake.dim_category (category_id, category_name)
SELECT category_id, category_name FROM catalog.categories;

INSERT INTO snowflake.dim_product_snowflaked (
    product_id, sku, product_name, brand, category_fk, cost_price
)
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    p.brand,
    c.category_sk,
    p.cost_price
FROM catalog.products p
JOIN snowflake.dim_category c ON p.category_id = c.category_id;

-- ----------------------------------------------------------------------------
-- 2. QUERY COMPARISON
-- Business Question:
-- "Calculate Total Net Sales, Units Sold, and Gross Profit by Category and Brand"
-- ----------------------------------------------------------------------------

-- APPROACH A: Star Schema Query (1 direct join to dwh.dim_product)
EXPLAIN ANALYZE
SELECT 
    p.category_name,
    p.brand,
    COUNT(f.sales_order_line_sk) AS order_lines_count,
    SUM(f.quantity) AS total_units_sold,
    SUM(f.net_sales_amount) AS total_net_revenue,
    SUM(f.gross_margin_amount) AS total_profit,
    ROUND(SUM(f.gross_margin_amount) / NULLIF(SUM(f.net_sales_amount), 0) * 100, 2) AS profit_margin_pct
FROM dwh.fact_sales_order_lines f
JOIN dwh.dim_product p ON f.product_fk = p.product_sk
GROUP BY p.category_name, p.brand
ORDER BY total_net_revenue DESC;

-- APPROACH B: Snowflake Schema Query (Multi-hop joins through sub-tables)
EXPLAIN ANALYZE
SELECT 
    c.category_name,
    ps.brand,
    COUNT(f.sales_order_line_sk) AS order_lines_count,
    SUM(f.quantity) AS total_units_sold,
    SUM(f.net_sales_amount) AS total_net_revenue,
    SUM(f.gross_margin_amount) AS total_profit,
    ROUND(SUM(f.gross_margin_amount) / NULLIF(SUM(f.net_sales_amount), 0) * 100, 2) AS profit_margin_pct
FROM dwh.fact_sales_order_lines f
JOIN snowflake.dim_product_snowflaked ps ON f.product_fk = ps.product_sk
JOIN snowflake.dim_category c ON ps.category_fk = c.category_sk
GROUP BY c.category_name, ps.brand
ORDER BY total_net_revenue DESC;
