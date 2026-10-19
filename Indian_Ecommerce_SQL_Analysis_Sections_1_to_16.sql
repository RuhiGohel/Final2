/*
Indian E-commerce Returns & Fulfilment Intelligence
SQL Server Analysis Script — Sections 1 to 16
Database: EcommerceAnalytics
Table: dbo.cleaned_ecommerce_order_items

How to use:
1. Open this file in SQL Server Management Studio (SSMS).
2. Confirm the database and table names match your setup.
3. Run one section at a time and review the result grid.

Metric notes:
- Each row is treated as an order item.
- item_total is reported as recorded sales, not profit or confirmed net revenue.
- Return and late-delivery rates use only rows where the corresponding flag is 0 or 1.
- discount_pct is assumed to use percentage points (e.g. 20 means 20%).
*/

USE [EcommerceAnalytics];
GO

/* ============================================================
   SECTION 1 — DATABASE & DATA VALIDATION
   ============================================================ */

-- 1.1 Basic row and key counts
SELECT
    COUNT(*) AS Total_Order_Item_Rows,
    COUNT(DISTINCT order_id) AS Total_Orders,
    COUNT(DISTINCT customer_id) AS Total_Customers,
    COUNT(DISTINCT product_id) AS Distinct_Products,
    COUNT(DISTINCT seller_id) AS Distinct_Sellers
FROM dbo.cleaned_ecommerce_order_items;

-- 1.2 Preview the imported data
SELECT TOP (10) *
FROM dbo.cleaned_ecommerce_order_items;

-- 1.3 Check duplicate order-item combinations
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS Duplicate_Count
FROM dbo.cleaned_ecommerce_order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1
ORDER BY Duplicate_Count DESC;


/* ============================================================
   SECTION 2 — OVERALL BUSINESS KPIs
   ============================================================ */

SELECT
    COUNT(DISTINCT order_id) AS Total_Orders,
    COUNT(*) AS Total_Order_Items,
    COUNT(DISTINCT customer_id) AS Total_Customers,
    SUM(quantity) AS Total_Quantity_Sold,
    SUM(item_total) AS Total_Recorded_Sales,
    SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) AS Returned_Items,
    CAST(
        100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0)
        AS DECIMAL(10, 2)
    ) AS Return_Rate_Percent,
    SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END) AS Late_Delivery_Items,
    CAST(
        100.0 * SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_late_delivery IN (0, 1) THEN 1 ELSE 0 END), 0)
        AS DECIMAL(10, 2)
    ) AS Late_Delivery_Rate_Percent,
    SUM(refund_amount) AS Total_Recorded_Refund_Amount
FROM dbo.cleaned_ecommerce_order_items;


/* ============================================================
   SECTION 3 — CATEGORY-WISE SALES ANALYSIS
   ============================================================ */

-- 3.1 Sales, orders, items and quantity by category
SELECT
    category,
    SUM(item_total) AS Total_Recorded_Sales,
    COUNT(DISTINCT order_id) AS Total_Orders,
    COUNT(*) AS Total_Order_Items,
    SUM(quantity) AS Total_Quantity_Sold,
    AVG(selling_price) AS Average_Selling_Price
FROM dbo.cleaned_ecommerce_order_items
GROUP BY category
ORDER BY Total_Recorded_Sales DESC;

-- 3.2 Top 5 categories by recorded sales
SELECT TOP (5)
    category,
    SUM(item_total) AS Total_Recorded_Sales
FROM dbo.cleaned_ecommerce_order_items
GROUP BY category
ORDER BY Total_Recorded_Sales DESC;

-- 3.3 Selling-price range by category
SELECT
    category,
    MIN(selling_price) AS Minimum_Selling_Price,
    AVG(selling_price) AS Average_Selling_Price,
    MAX(selling_price) AS Maximum_Selling_Price
FROM dbo.cleaned_ecommerce_order_items
GROUP BY category
ORDER BY Average_Selling_Price DESC;


/* ============================================================
   SECTION 4 — RETURN RATE BY CATEGORY
   ============================================================ */

SELECT
    category,
    SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) AS Returned_Items,
    SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END) AS Items_With_Known_Return_Flag,
    CAST(
        100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0)
        AS DECIMAL(10, 2)
    ) AS Return_Rate_Percent,
    SUM(CASE WHEN is_returned = 1 THEN item_total ELSE 0 END) AS Recorded_Value_Of_Returned_Items
FROM dbo.cleaned_ecommerce_order_items
GROUP BY category
ORDER BY Return_Rate_Percent DESC;


/* ============================================================
   SECTION 5 — RETURN REASONS ANALYSIS
   ============================================================ */

-- 5.1 Most common return reasons
SELECT
    return_reason,
    COUNT(*) AS Returned_Item_Count
FROM dbo.cleaned_ecommerce_order_items
WHERE is_returned = 1
GROUP BY return_reason
ORDER BY Returned_Item_Count DESC;

-- 5.2 Return reasons by category
SELECT
    category,
    return_reason,
    COUNT(*) AS Returned_Item_Count
FROM dbo.cleaned_ecommerce_order_items
WHERE is_returned = 1
GROUP BY category, return_reason
ORDER BY category, Returned_Item_Count DESC;

-- 5.3 Returned items with missing return reasons
SELECT
    COUNT(*) AS Returned_Items_With_Missing_Reason
FROM dbo.cleaned_ecommerce_order_items
WHERE is_returned = 1
  AND (return_reason IS NULL OR LTRIM(RTRIM(return_reason)) = '');


/* ============================================================
   SECTION 6 — REFUND ANALYSIS
   ============================================================ */

-- 6.1 Overall refund KPIs
SELECT
    COUNT(CASE WHEN refund_amount IS NOT NULL THEN 1 END) AS Items_With_Recorded_Refund,
    SUM(refund_amount) AS Total_Recorded_Refund_Amount,
    AVG(refund_amount) AS Average_Recorded_Refund_Amount,
    AVG(CAST(refund_days AS DECIMAL(10, 2))) AS Average_Refund_Days
FROM dbo.cleaned_ecommerce_order_items;

-- 6.2 Refund amount by refund mode
SELECT
    refund_mode,
    COUNT(*) AS Item_Count,
    SUM(refund_amount) AS Total_Recorded_Refund_Amount,
    AVG(refund_amount) AS Average_Recorded_Refund_Amount
FROM dbo.cleaned_ecommerce_order_items
WHERE refund_amount IS NOT NULL
GROUP BY refund_mode
ORDER BY Total_Recorded_Refund_Amount DESC;

-- 6.3 Refund amount by category
SELECT
    category,
    SUM(refund_amount) AS Total_Recorded_Refund_Amount,
    AVG(refund_amount) AS Average_Recorded_Refund_Amount,
    COUNT(CASE WHEN refund_amount IS NOT NULL THEN 1 END) AS Items_With_Recorded_Refund
FROM dbo.cleaned_ecommerce_order_items
GROUP BY category
ORDER BY Total_Recorded_Refund_Amount DESC;


/* ============================================================
   SECTION 7 — STATE & REGION PERFORMANCE
   ============================================================ */

-- 7.1 State-wise performance
SELECT
    state,
    SUM(item_total) AS Total_Recorded_Sales,
    COUNT(DISTINCT order_id) AS Total_Orders,
    SUM(quantity) AS Total_Quantity_Sold
FROM dbo.cleaned_ecommerce_order_items
WHERE state IS NOT NULL
GROUP BY state
ORDER BY Total_Recorded_Sales DESC;

-- 7.2 Region-wise performance
SELECT
    region,
    SUM(item_total) AS Total_Recorded_Sales,
    COUNT(DISTINCT order_id) AS Total_Orders,
    COUNT(*) AS Total_Order_Items
FROM dbo.cleaned_ecommerce_order_items
WHERE region IS NOT NULL
GROUP BY region
ORDER BY Total_Recorded_Sales DESC;

-- 7.3 State-wise return rate
SELECT
    state,
    SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) AS Returned_Items,
    CAST(
        100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0)
        AS DECIMAL(10, 2)
    ) AS Return_Rate_Percent
FROM dbo.cleaned_ecommerce_order_items
WHERE state IS NOT NULL
GROUP BY state
ORDER BY Return_Rate_Percent DESC;


/* ============================================================
   SECTION 8 — COURIER PERFORMANCE & LATE DELIVERIES
   ============================================================ */

-- 8.1 Late-delivery rate by courier
SELECT
    courier_partner,
    COUNT(*) AS Total_Order_Items,
    SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END) AS Late_Delivery_Items,
    CAST(
        100.0 * SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_late_delivery IN (0, 1) THEN 1 ELSE 0 END), 0)
        AS DECIMAL(10, 2)
    ) AS Late_Delivery_Rate_Percent
FROM dbo.cleaned_ecommerce_order_items
GROUP BY courier_partner
ORDER BY Late_Delivery_Rate_Percent DESC;

-- 8.2 Actual vs promised delivery days by courier
SELECT
    courier_partner,
    AVG(CAST(promised_delivery_days AS DECIMAL(10, 2))) AS Average_Promised_Delivery_Days,
    AVG(CAST(actual_delivery_days AS DECIMAL(10, 2))) AS Average_Actual_Delivery_Days
FROM dbo.cleaned_ecommerce_order_items
GROUP BY courier_partner
ORDER BY Average_Actual_Delivery_Days DESC;

-- 8.3 Delivery-date and delivery-duration availability
SELECT
    COUNT(*) AS Total_Order_Items,
    COUNT(shipped_datetime) AS Items_With_Shipped_Date,
    COUNT(delivered_datetime) AS Items_With_Delivered_Date,
    COUNT(actual_delivery_days) AS Items_With_Actual_Delivery_Days,
    COUNT(promised_delivery_days) AS Items_With_Promised_Delivery_Days
FROM dbo.cleaned_ecommerce_order_items;


/* ============================================================
   SECTION 9 — ORDER STATUS & CANCELLATION ANALYSIS
   ============================================================ */

-- 9.1 Item status distribution
SELECT
    item_status,
    COUNT(*) AS Item_Count
FROM dbo.cleaned_ecommerce_order_items
GROUP BY item_status
ORDER BY Item_Count DESC;

-- 9.2 Order status distribution (rows are order items; orders are distinct)
SELECT
    order_status,
    COUNT(*) AS Order_Item_Rows,
    COUNT(DISTINCT order_id) AS Distinct_Orders
FROM dbo.cleaned_ecommerce_order_items
GROUP BY order_status
ORDER BY Order_Item_Rows DESC;

-- 9.3 Cancellation reasons
SELECT
    cancel_reason,
    COUNT(*) AS Item_Count,
    COUNT(DISTINCT order_id) AS Distinct_Orders
FROM dbo.cleaned_ecommerce_order_items
WHERE cancel_reason IS NOT NULL
  AND LTRIM(RTRIM(cancel_reason)) <> ''
GROUP BY cancel_reason
ORDER BY Item_Count DESC;


/* ============================================================
   SECTION 10 — PAYMENT METHOD ANALYSIS
   ============================================================ */

-- 10.1 Sales and orders by payment method
SELECT
    payment_method,
    SUM(item_total) AS Total_Recorded_Sales,
    COUNT(DISTINCT order_id) AS Total_Orders,
    COUNT(*) AS Total_Order_Items
FROM dbo.cleaned_ecommerce_order_items
GROUP BY payment_method
ORDER BY Total_Recorded_Sales DESC;

-- 10.2 Average recorded order value by payment method
WITH OrderTotals AS (
    SELECT
        order_id,
        payment_method,
        SUM(item_total) AS Order_Total
    FROM dbo.cleaned_ecommerce_order_items
    GROUP BY order_id, payment_method
)
SELECT
    payment_method,
    COUNT(*) AS Total_Orders,
    AVG(Order_Total) AS Average_Recorded_Order_Value
FROM OrderTotals
GROUP BY payment_method
ORDER BY Average_Recorded_Order_Value DESC;


/* ============================================================
   SECTION 11 — SELLER PERFORMANCE ANALYSIS
   ============================================================ */

-- 11.1 Seller sales and order volume
SELECT
    seller_id,
    SUM(item_total) AS Total_Recorded_Sales,
    COUNT(DISTINCT order_id) AS Total_Orders,
    COUNT(*) AS Total_Order_Items,
    AVG(CAST(seller_rating AS DECIMAL(10, 2))) AS Average_Recorded_Seller_Rating
FROM dbo.cleaned_ecommerce_order_items
GROUP BY seller_id
ORDER BY Total_Recorded_Sales DESC;

-- 11.2 Seller return rate
SELECT
    seller_id,
    SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) AS Returned_Items,
    CAST(
        100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0)
        AS DECIMAL(10, 2)
    ) AS Return_Rate_Percent
FROM dbo.cleaned_ecommerce_order_items
GROUP BY seller_id
ORDER BY Return_Rate_Percent DESC;

-- 11.3 Average recorded seller rating
SELECT
    seller_id,
    AVG(CAST(seller_rating AS DECIMAL(10, 2))) AS Average_Recorded_Seller_Rating,
    COUNT(seller_rating) AS Rows_With_Rating
FROM dbo.cleaned_ecommerce_order_items
GROUP BY seller_id
ORDER BY Average_Recorded_Seller_Rating DESC;


/* ============================================================
   SECTION 12 — DISCOUNT ANALYSIS
   Assumption: discount_pct uses percentage points (e.g. 20 = 20%).
   ============================================================ */

-- 12.1 Sales by discount range
SELECT
    CASE
        WHEN discount_pct IS NULL THEN 'Unknown'
        WHEN discount_pct < 10 THEN 'Below 10%'
        WHEN discount_pct < 20 THEN '10% to below 20%'
        WHEN discount_pct < 30 THEN '20% to below 30%'
        ELSE '30% and above'
    END AS Discount_Range,
    COUNT(*) AS Total_Order_Items,
    SUM(item_total) AS Total_Recorded_Sales,
    AVG(CAST(discount_pct AS DECIMAL(10, 2))) AS Average_Discount_Percent
FROM dbo.cleaned_ecommerce_order_items
GROUP BY
    CASE
        WHEN discount_pct IS NULL THEN 'Unknown'
        WHEN discount_pct < 10 THEN 'Below 10%'
        WHEN discount_pct < 20 THEN '10% to below 20%'
        WHEN discount_pct < 30 THEN '20% to below 30%'
        ELSE '30% and above'
    END
ORDER BY Total_Recorded_Sales DESC;

-- 12.2 Average discount by category
SELECT
    category,
    AVG(CAST(discount_pct AS DECIMAL(10, 2))) AS Average_Discount_Percent,
    SUM(item_total) AS Total_Recorded_Sales,
    COUNT(*) AS Total_Order_Items
FROM dbo.cleaned_ecommerce_order_items
GROUP BY category
ORDER BY Average_Discount_Percent DESC;


/* ============================================================
   SECTION 13 — MONTHLY SALES & ORDER TRENDS
   ============================================================ */

-- 13.1 Monthly sales and order counts
SELECT
    DATEFROMPARTS(YEAR(order_datetime), MONTH(order_datetime), 1) AS Order_Month,
    SUM(item_total) AS Total_Recorded_Sales,
    COUNT(DISTINCT order_id) AS Total_Orders,
    COUNT(*) AS Total_Order_Items
FROM dbo.cleaned_ecommerce_order_items
WHERE order_datetime IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(order_datetime), MONTH(order_datetime), 1)
ORDER BY Order_Month;

-- 13.2 Month-on-month recorded sales growth
WITH MonthlySales AS (
    SELECT
        DATEFROMPARTS(YEAR(order_datetime), MONTH(order_datetime), 1) AS Order_Month,
        SUM(item_total) AS Total_Recorded_Sales
    FROM dbo.cleaned_ecommerce_order_items
    WHERE order_datetime IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(order_datetime), MONTH(order_datetime), 1)
), SalesWithPreviousMonth AS (
    SELECT
        Order_Month,
        Total_Recorded_Sales,
        LAG(Total_Recorded_Sales) OVER (ORDER BY Order_Month) AS Previous_Available_Month_Sales
    FROM MonthlySales
)
SELECT
    Order_Month,
    Total_Recorded_Sales,
    Previous_Available_Month_Sales,
    CAST(
        100.0 * (Total_Recorded_Sales - Previous_Available_Month_Sales)
        / NULLIF(Previous_Available_Month_Sales, 0)
        AS DECIMAL(10, 2)
    ) AS Month_On_Month_Sales_Growth_Percent
FROM SalesWithPreviousMonth
ORDER BY Order_Month;


/* ============================================================
   SECTION 14 — MONTHLY RETURN & LATE-DELIVERY TRENDS
   ============================================================ */

SELECT
    DATEFROMPARTS(YEAR(order_datetime), MONTH(order_datetime), 1) AS Order_Month,
    SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) AS Returned_Items,
    CAST(
        100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0)
        AS DECIMAL(10, 2)
    ) AS Return_Rate_Percent,
    SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END) AS Late_Delivery_Items,
    CAST(
        100.0 * SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_late_delivery IN (0, 1) THEN 1 ELSE 0 END), 0)
        AS DECIMAL(10, 2)
    ) AS Late_Delivery_Rate_Percent
FROM dbo.cleaned_ecommerce_order_items
WHERE order_datetime IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(order_datetime), MONTH(order_datetime), 1)
ORDER BY Order_Month;


/* ============================================================
   SECTION 15 — DATA QUALITY CHECKS
   ============================================================ */

-- 15.1 Missing values in important columns
SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS Missing_Order_ID,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS Missing_Customer_ID,
    SUM(CASE WHEN category IS NULL OR LTRIM(RTRIM(category)) = '' THEN 1 ELSE 0 END) AS Missing_Category,
    SUM(CASE WHEN order_datetime IS NULL THEN 1 ELSE 0 END) AS Missing_Order_Datetime,
    SUM(CASE WHEN item_total IS NULL THEN 1 ELSE 0 END) AS Missing_Item_Total,
    SUM(CASE WHEN is_returned IS NULL THEN 1 ELSE 0 END) AS Missing_Return_Flag,
    SUM(CASE WHEN is_late_delivery IS NULL THEN 1 ELSE 0 END) AS Missing_Late_Delivery_Flag
FROM dbo.cleaned_ecommerce_order_items;

-- 15.2 Duplicate order-item combinations
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS Duplicate_Count
FROM dbo.cleaned_ecommerce_order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1
ORDER BY Duplicate_Count DESC;

-- 15.3 Invalid numeric values
SELECT
    SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END) AS Invalid_Quantity_Rows,
    SUM(CASE WHEN mrp < 0 THEN 1 ELSE 0 END) AS Negative_MRP_Rows,
    SUM(CASE WHEN selling_price < 0 THEN 1 ELSE 0 END) AS Negative_Selling_Price_Rows,
    SUM(CASE WHEN item_total < 0 THEN 1 ELSE 0 END) AS Negative_Item_Total_Rows,
    SUM(CASE WHEN discount_pct < 0 OR discount_pct > 100 THEN 1 ELSE 0 END) AS Invalid_Discount_Rows,
    SUM(CASE WHEN refund_amount < 0 THEN 1 ELSE 0 END) AS Negative_Refund_Amount_Rows
FROM dbo.cleaned_ecommerce_order_items;


/* ============================================================
   SECTION 16 — TOP 10 STATES & FINAL BUSINESS KPI SUMMARY
   ============================================================ */

-- 16.1 Top 10 states by recorded sales
SELECT TOP (10)
    state,
    COUNT(DISTINCT order_id) AS Total_Orders,
    SUM(item_total) AS Total_Recorded_Sales,
    SUM(quantity) AS Total_Quantity_Sold
FROM dbo.cleaned_ecommerce_order_items
WHERE state IS NOT NULL
GROUP BY state
ORDER BY Total_Recorded_Sales DESC;

-- 16.2 Final consolidated KPI summary
SELECT
    COUNT(DISTINCT order_id) AS Total_Orders,
    COUNT(*) AS Total_Order_Items,
    COUNT(DISTINCT customer_id) AS Total_Customers,
    SUM(item_total) AS Total_Recorded_Sales,
    SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) AS Returned_Items,
    CAST(
        100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0)
        AS DECIMAL(10, 2)
    ) AS Return_Rate_Percent,
    SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END) AS Late_Delivery_Items,
    CAST(
        100.0 * SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_late_delivery IN (0, 1) THEN 1 ELSE 0 END), 0)
        AS DECIMAL(10, 2)
    ) AS Late_Delivery_Rate_Percent,
    SUM(refund_amount) AS Total_Recorded_Refund_Amount
FROM dbo.cleaned_ecommerce_order_items;

/* END OF SCRIPT */
