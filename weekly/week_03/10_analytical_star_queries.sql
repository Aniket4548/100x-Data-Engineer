-- ============================================================================
-- WEEK 3: TOPIC 10 — Star Schema Analytics & Business Intelligence Queries
-- Description:
-- Testing our completed Star Schema with high-value analytical queries on 30,000
-- actual order lines:
--   1. Temporal Slice & Dice: Monthly sales and profit trends.
--   2. Fiscal Calendar Rollups: Automated quarterly rollups without CASE logic.
--   3. Geographic & Product Cohort Profitability: Country vs Category margins.
--   4. Query Performance Comparison: 3 Star Joins vs 8 Relational 3NF Joins.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- QUERY 1: Slicing by Time and Geography (Revenue & Margin by Month & Country)
-- ----------------------------------------------------------------------------
SELECT 
    d.year_month,
    c.country,
    COUNT(DISTINCT f.order_number) AS total_orders,
    SUM(f.quantity) AS units_sold,
    SUM(f.net_sales_amount) AS net_revenue,
    SUM(f.gross_margin_amount) AS gross_profit,
    ROUND(SUM(f.gross_margin_amount) / NULLIF(SUM(f.net_sales_amount), 0) * 100, 2) AS profit_margin_pct
FROM dwh.fact_sales_order_lines f
JOIN dwh.dim_date d ON f.order_date_fk = d.date_key
JOIN dwh.dim_customer c ON f.customer_fk = c.customer_sk
GROUP BY d.year_month, c.country
ORDER BY d.year_month, net_revenue DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- QUERY 2: Fiscal Calendar Roll-Up (Enterprise Financial Reporting)
-- ----------------------------------------------------------------------------
SELECT 
    d.fiscal_year,
    d.fiscal_quarter,
    p.category_name,
    SUM(f.quantity) AS total_units_sold,
    SUM(f.net_sales_amount) AS total_sales,
    SUM(f.gross_margin_amount) AS total_margin,
    ROUND(AVG(f.net_sales_amount), 2) AS avg_line_value
FROM dwh.fact_sales_order_lines f
JOIN dwh.dim_date d ON f.order_date_fk = d.date_key
JOIN dwh.dim_product p ON f.product_fk = p.product_sk
GROUP BY d.fiscal_year, d.fiscal_quarter, p.category_name
ORDER BY d.fiscal_year, d.fiscal_quarter, total_sales DESC;

-- ----------------------------------------------------------------------------
-- QUERY 3: Customer Value & Cross-Selling (Pareto Margin Contribution)
-- ----------------------------------------------------------------------------
SELECT 
    c.customer_code,
    c.full_name,
    c.city,
    c.country,
    COUNT(DISTINCT f.order_number) AS orders_placed,
    SUM(f.quantity) AS total_items_bought,
    SUM(f.net_sales_amount) AS total_spend,
    SUM(f.gross_margin_amount) AS total_customer_profit,
    ROUND(SUM(f.gross_margin_amount) / NULLIF(SUM(f.net_sales_amount), 0) * 100, 1) AS margin_contribution_pct
FROM dwh.fact_sales_order_lines f
JOIN dwh.dim_customer c ON f.customer_fk = c.customer_sk
WHERE c.customer_sk <> -1
GROUP BY c.customer_sk, c.customer_code, c.full_name, c.city, c.country
ORDER BY total_spend DESC
LIMIT 15;

-- ----------------------------------------------------------------------------
-- QUERY 4: 3-JOIN STAR QUERY VS 7-JOIN 3NF QUERY BENCHMARK
-- ----------------------------------------------------------------------------

-- A) ON THE STAR SCHEMA (Clean 3 joins directly to the fact table)
EXPLAIN ANALYZE
SELECT 
    p.category_name,
    c.country,
    SUM(f.net_sales_amount) AS net_revenue,
    SUM(f.gross_margin_amount) AS gross_profit
FROM dwh.fact_sales_order_lines f
JOIN dwh.dim_date d ON f.order_date_fk = d.date_key
JOIN dwh.dim_product p ON f.product_fk = p.product_sk
JOIN dwh.dim_customer c ON f.customer_fk = c.customer_sk
WHERE d.quarter_name = 'Q1' AND d.year = 2026
GROUP BY p.category_name, c.country;

-- B) ON RAW 3NF TABLES (Requires joining across 7 operational tables)
EXPLAIN ANALYZE
SELECT 
    cat.category_name,
    addr.country,
    SUM(oi.line_total) AS net_revenue,
    SUM(oi.line_total - (oi.quantity * p.cost_price)) AS gross_profit
FROM orders.orders o
JOIN orders.order_items oi ON o.order_id = oi.order_id
JOIN customer.customers cust ON o.customer_id = cust.customer_id
LEFT JOIN customer.addresses addr ON cust.customer_id = addr.customer_id AND addr.is_default = TRUE
JOIN catalog.products p ON oi.product_id = p.product_id
JOIN catalog.categories cat ON p.category_id = cat.category_id
WHERE EXTRACT(QUARTER FROM o.order_timestamp) = 1 
  AND EXTRACT(YEAR FROM o.order_timestamp) = 2026
GROUP BY cat.category_name, addr.country;
