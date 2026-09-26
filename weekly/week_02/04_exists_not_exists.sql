-- WEEK 2: TOPIC 4 — EXISTS and NOT EXISTS (Semi-Joins & Anti-Joins)

-- Description:
-- EXISTS and NOT EXISTS are short-circuiting set-membership operators.
-- They prevent duplicate row generation compared to standard joins and avoid
-- the catastrophic three-valued logic NULL trap of NOT IN.

-- ----------------------------------------------------------------------------
-- PROBLEM 1: Semi-Join with EXISTS
-- Task: Find all active customers who have experienced at least one failed payment.
-- Note: An INNER JOIN with payments would return duplicate customer rows if
--       they had multiple failed payments, requiring an expensive DISTINCT.
-- ----------------------------------------------------------------------------

SELECT c.customer_id, c.customer_code, c.first_name, c.last_name, c.email
FROM customer.customers c
WHERE
    c.customer_status = 'active'
    AND EXISTS (
        SELECT 1
        FROM orders.orders o
            JOIN orders.payments p ON o.order_id = p.order_id
        WHERE
            o.customer_id = c.customer_id
            AND p.payment_status = 'failed'
    );

-- ----------------------------------------------------------------------------
-- PROBLEM 2: Anti-Join with NOT EXISTS
-- Task: Identify "Dormant Leads": customers who registered more than 30 days ago
--       but have NEVER placed any orders in the system.
-- ----------------------------------------------------------------------------

SELECT c.customer_id, c.first_name, c.last_name, c.email, c.signup_date
FROM customer.customers c
WHERE
    c.signup_date < NOW() - INTERVAL '30 days'
    AND NOT EXISTS (
        SELECT 1
        FROM orders.orders o
        WHERE
            o.customer_id = c.customer_id
    );

-- ----------------------------------------------------------------------------
-- PROBLEM 3: The Fatal NOT IN with NULLs Trap (Three-Valued Logic)
-- Task: Observe why NOT IN silently breaks production pipelines when NULLs exist.
-- ----------------------------------------------------------------------------

-- Setup temporary scratch table with a NULL
CREATE TEMP TABLE test_active_promos (promo_code VARCHAR(20));

INSERT INTO
    test_active_promos
VALUES ('SAVE10'),
    ('SUMMER20'),
    (NULL);

CREATE TEMP TABLE test_applied_promos (code VARCHAR(20));

INSERT INTO test_applied_promos VALUES ('SAVE10'), ('FALL50');

-- ⚠️ DANGER: Returns 0 ROWS because of (code != NULL) resolving to UNKNOWN!
SELECT *
FROM test_applied_promos
WHERE
    code NOT IN (
        SELECT promo_code
        FROM test_active_promos
    );

-- ✅ BULLETPROOF: NOT EXISTS evaluates row existence, returning 'FALL50' as expected!
SELECT *
FROM test_applied_promos tap
WHERE
    NOT EXISTS (
        SELECT 1
        FROM test_active_promos promo
        WHERE
            promo.promo_code = tap.code
    );

DROP TABLE test_active_promos;

DROP TABLE test_applied_promos;

-- ----------------------------------------------------------------------------
-- PROBLEM 4: NOT EXISTS vs LEFT JOIN ... WHERE IS NULL
-- Task: Compare query plans and syntax for anti-joins.
-- ----------------------------------------------------------------------------

-- Pattern A: NOT EXISTS (Cleaner intent, easier for query planner to optimize)
EXPLAIN
ANALYZE
SELECT p.product_id, p.product_name
FROM catalog.products p
WHERE
    NOT EXISTS (
        SELECT 1
        FROM orders.order_items oi
        WHERE
            oi.product_id = p.product_id
    );

-- Pattern B: LEFT JOIN ... WHERE IS NULL (Traditional equivalent)
EXPLAIN
ANALYZE
SELECT p.product_id, p.product_name
FROM catalog.products p
    LEFT JOIN orders.order_items oi ON p.product_id = oi.product_id
WHERE
    oi.order_item_id IS NULL;