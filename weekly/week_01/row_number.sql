--Write a PostgreSQL query to retrieve the most recent order for every customer WITHOUT using any window functions (OVER, ROW_NUMBER, etc.).

--Required Output Columns:

--customer_id
--order_id
--order_timestamp
--total_amount
--order_status

-- solution 1: using distinct_on

select distinct on (o.customer_id) o.customer_id, o.order_id, o.order_timestamp, o.total_amount, o.order_status from orders.orders o
order by o.customer_id, o.order_timestamp desc

-- solution 2: without using distinct_on

WITH latest_timestamps AS (
    SELECT customer_id, MAX(order_timestamp) AS max_time
    FROM orders.orders
    GROUP BY customer_id
)
SELECT 
    o.customer_id, 
    o.order_id, 
    o.order_timestamp, 
    o.total_amount, 
    o.order_status
FROM orders.orders o
JOIN latest_timestamps lt 
    ON o.customer_id = lt.customer_id 
   AND o.order_timestamp = lt.max_time;


--Using window functions
WITH ranked_orders AS (
    SELECT 
        o.customer_id, 
        o.order_id, 
        o.order_timestamp, 
        o.total_amount, 
        o.order_status,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id 
            ORDER BY o.order_timestamp DESC
        ) AS rn
    FROM orders.orders o
)
SELECT 
    customer_id, 
    order_id, 
    order_timestamp, 
    total_amount, 
    order_status
FROM ranked_orders
WHERE rn = 1;

--Explaniation
-- This query uses CTE and Row_number function to get the most recent order for each customer.
-- The ROW_NUMBER() function is used to assign a unique rank to each order within each customer partition.
-- The PARTITION BY clause is used to partition the data by customer_id.
-- The ORDER BY clause is used to order the data by order_timestamp in descending order.
