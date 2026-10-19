/*
Indian E-commerce Returns & Fulfilment Analysis | SQL Server
Import cleaned_ecommerce_order_items.csv as dbo.EcommerceOrderItems.
Grain: one row per order item. Use item_total for item sales and DISTINCT order_id for orders.
*/

-- 1. Overall business KPIs
SELECT COUNT_BIG(*) AS order_item_rows,
       COUNT(DISTINCT order_id) AS unique_orders,
       COUNT(DISTINCT customer_id) AS unique_customers,
       SUM(quantity) AS units_sold,
       SUM(item_total) AS item_level_sales,
       SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) AS returned_items,
       CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT_BIG(*), 0) AS decimal(8,2)) AS returned_item_rate_pct,
       SUM(refund_amount) AS recorded_refund_amount
FROM dbo.EcommerceOrderItems;

-- 2. Data quality checks
SELECT SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS missing_order_id,
       SUM(CASE WHEN order_item_id IS NULL THEN 1 ELSE 0 END) AS missing_order_item_id,
       SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END) AS nonpositive_quantity,
       SUM(CASE WHEN discount_pct < 0 OR discount_pct > 100 THEN 1 ELSE 0 END) AS invalid_discount,
       SUM(CASE WHEN order_datetime IS NULL THEN 1 ELSE 0 END) AS missing_order_datetime
FROM dbo.EcommerceOrderItems;

-- 3. Sales by category
SELECT category, COUNT_BIG(*) AS item_rows,
       COUNT(DISTINCT order_id) AS unique_orders, SUM(quantity) AS units_sold,
       SUM(item_total) AS item_level_sales
FROM dbo.EcommerceOrderItems
GROUP BY category ORDER BY item_level_sales DESC;

-- 4. Return rate and recorded refunds by category
SELECT category, COUNT_BIG(*) AS item_rows,
       SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) AS returned_items,
       CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT_BIG(*), 0) AS decimal(8,2)) AS return_rate_pct,
       SUM(refund_amount) AS recorded_refund_amount
FROM dbo.EcommerceOrderItems
GROUP BY category ORDER BY return_rate_pct DESC;

-- 5. Common return reasons
SELECT return_reason, COUNT_BIG(*) AS returned_items
FROM dbo.EcommerceOrderItems
WHERE is_returned = 1 AND return_reason IS NOT NULL
GROUP BY return_reason ORDER BY returned_items DESC;

-- 6. Top products by item-level sales
SELECT TOP (20) product_id, category, sub_category, brand,
       SUM(item_total) AS item_level_sales,
       SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) AS returned_items,
       CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT_BIG(*), 0) AS decimal(8,2)) AS return_rate_pct
FROM dbo.EcommerceOrderItems
GROUP BY product_id, category, sub_category, brand
ORDER BY item_level_sales DESC;

-- 7. Courier delivery performance; NULL delivery flags are excluded from the rate
SELECT courier_partner, COUNT_BIG(*) AS item_rows,
       SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END) AS late_items,
       CAST(100.0 * SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END) /
            NULLIF(SUM(CASE WHEN is_late_delivery IS NOT NULL THEN 1 ELSE 0 END), 0) AS decimal(8,2)) AS late_rate_pct,
       AVG(CAST(actual_delivery_days AS decimal(10,2))) AS avg_delivery_days
FROM dbo.EcommerceOrderItems
GROUP BY courier_partner ORDER BY late_rate_pct DESC;

-- 8. Order status and cancellation reasons
SELECT order_status, COUNT(DISTINCT order_id) AS unique_orders, COUNT_BIG(*) AS item_rows
FROM dbo.EcommerceOrderItems
GROUP BY order_status ORDER BY unique_orders DESC;

SELECT cancel_reason, COUNT(DISTINCT order_id) AS unique_orders
FROM dbo.EcommerceOrderItems
WHERE cancel_reason IS NOT NULL
GROUP BY cancel_reason ORDER BY unique_orders DESC;

-- 9. Monthly sales, orders, and returns
SELECT DATEFROMPARTS(YEAR(order_datetime), MONTH(order_datetime), 1) AS order_month,
       COUNT(DISTINCT order_id) AS unique_orders, SUM(quantity) AS units_sold,
       SUM(item_total) AS item_level_sales,
       SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) AS returned_items
FROM dbo.EcommerceOrderItems
WHERE order_datetime IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(order_datetime), MONTH(order_datetime), 1)
ORDER BY order_month;

-- 10. Payment method comparison
SELECT payment_method, COUNT(DISTINCT order_id) AS unique_orders,
       SUM(item_total) AS item_level_sales,
       CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT_BIG(*), 0) AS decimal(8,2)) AS return_rate_pct
FROM dbo.EcommerceOrderItems
GROUP BY payment_method ORDER BY item_level_sales DESC;

-- 11. Regional performance
SELECT region, state, COUNT(DISTINCT order_id) AS unique_orders,
       SUM(item_total) AS item_level_sales,
       CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT_BIG(*), 0) AS decimal(8,2)) AS return_rate_pct
FROM dbo.EcommerceOrderItems
GROUP BY region, state ORDER BY item_level_sales DESC;

-- 12. Plus-member comparison
SELECT is_plus_member, COUNT(DISTINCT order_id) AS unique_orders,
       SUM(item_total) AS item_level_sales,
       CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT_BIG(*), 0) AS decimal(8,2)) AS return_rate_pct
FROM dbo.EcommerceOrderItems
GROUP BY is_plus_member ORDER BY is_plus_member;

-- 13. Seller performance
SELECT seller_id, COUNT_BIG(*) AS item_rows, SUM(item_total) AS item_level_sales,
       AVG(CAST(seller_rating AS decimal(5,2))) AS avg_seller_rating,
       CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT_BIG(*), 0) AS decimal(8,2)) AS return_rate_pct
FROM dbo.EcommerceOrderItems
GROUP BY seller_id ORDER BY item_level_sales DESC;

-- 14. Recorded refunds by refund mode (not proof of settlement)
SELECT refund_mode, COUNT_BIG(*) AS refund_records,
       SUM(refund_amount) AS recorded_refund_amount,
       AVG(CAST(refund_amount AS decimal(12,2))) AS average_recorded_refund
FROM dbo.EcommerceOrderItems
WHERE is_returned = 1 AND refund_amount IS NOT NULL
GROUP BY refund_mode ORDER BY recorded_refund_amount DESC;
