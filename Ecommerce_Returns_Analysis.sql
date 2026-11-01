-- E-Commerce Returns & Fulfilment Analysis | SQL Server
-- Database: EcommerceAnalytics | Source: dbo.cleaned_ecommerce_order_items

USE EcommerceAnalytics;
GO

-- PART A: DATA VALIDATION

-- 1. Check total rows and unique keys
SELECT
    COUNT(*) AS Total_Rows,
    COUNT(DISTINCT order_id) AS Unique_Orders,
    COUNT(DISTINCT customer_id) AS Unique_Customers,
    COUNT(DISTINCT seller_id) AS Unique_Sellers,
    COUNT(*) - COUNT(DISTINCT CONCAT(order_id, '-', order_item_id)) AS Duplicate_Order_Items
FROM dbo.cleaned_ecommerce_order_items;
GO

-- 2. Check item status values (defines cancelled and returned items)
SELECT item_status, COUNT(*) AS Item_Count
FROM dbo.cleaned_ecommerce_order_items
GROUP BY item_status
ORDER BY Item_Count DESC;
GO

-- 3. Check whether item_total includes cancelled and returned items
SELECT
    item_status,
    COUNT(*) AS Item_Count,
    SUM(item_total) AS Sum_Item_Total,
    SUM(CASE WHEN item_total IS NULL OR item_total = 0 THEN 1 ELSE 0 END) AS Zero_Or_Null_Item_Total
FROM dbo.cleaned_ecommerce_order_items
GROUP BY item_status
ORDER BY Item_Count DESC;
GO

-- 4. Check discount scale (percentage points or fraction)
SELECT
    MIN(discount_pct) AS Min_Discount,
    MAX(discount_pct) AS Max_Discount
FROM dbo.cleaned_ecommerce_order_items;
GO

-- 5. Check is_late_delivery against actual_delivery_days > promised_delivery_days
SELECT
    SUM(CASE WHEN actual_delivery_days IS NOT NULL AND promised_delivery_days IS NOT NULL
             THEN 1 ELSE 0 END) AS Comparable_Items,
    SUM(CASE WHEN actual_delivery_days IS NOT NULL AND promised_delivery_days IS NOT NULL
              AND is_late_delivery IN (0, 1)
              AND is_late_delivery <> CASE WHEN actual_delivery_days > promised_delivery_days
                                           THEN 1 ELSE 0 END
             THEN 1 ELSE 0 END) AS Mismatched_Items
FROM dbo.cleaned_ecommerce_order_items;
GO

-- 6. Calculate Data Quality indicators (flag coverage and refund coverage)
SELECT
    CAST(100.0 * SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(10,2)) AS Return_Flag_Known_Pct,
    CAST(100.0 * SUM(CASE WHEN is_late_delivery IN (0, 1) THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(10,2)) AS Late_Delivery_Flag_Known_Pct,
    CAST(100.0 * SUM(CASE WHEN is_returned = 1 AND refund_amount IS NOT NULL THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) AS Refund_Coverage_Pct
FROM dbo.cleaned_ecommerce_order_items;
GO

-- PART B: BUSINESS ANALYSIS

-- 7. Calculate overall KPIs
SELECT
    COUNT(DISTINCT order_id) AS Total_Orders,
    COUNT(DISTINCT customer_id) AS Total_Customers,
    SUM(item_total) AS Total_Sales,
    CAST(SUM(item_total) / NULLIF(COUNT(DISTINCT order_id), 0) AS DECIMAL(18,2)) AS AOV,
    CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) AS Return_Rate_Pct,
    CAST(100.0 * SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN is_late_delivery IN (0, 1) THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) AS Late_Delivery_Rate_Pct,
    SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) AS Returned_Items,
    SUM(refund_amount) AS Total_Refund,
    AVG(CAST(refund_days AS DECIMAL(10,2))) AS Avg_Refund_Days,
    AVG(CAST(promised_delivery_days AS DECIMAL(10,2))) AS Avg_Promised_Days,
    AVG(CAST(actual_delivery_days AS DECIMAL(10,2))) AS Avg_Actual_Days
FROM dbo.cleaned_ecommerce_order_items;
GO

-- 8. Calculate item outcome mix (Delivered, Returned, Cancelled)
SELECT
    item_status,
    COUNT(*) AS Item_Count,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)) AS Share_Pct
FROM dbo.cleaned_ecommerce_order_items
GROUP BY item_status
ORDER BY Item_Count DESC;
GO

-- 9. Compare sales and return rate by category
SELECT
    category,
    SUM(item_total) AS Total_Sales,
    SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END) AS Items_With_Known_Flag,
    CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) AS Return_Rate_Pct,
    CASE WHEN SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END) >= 30
         THEN 'Yes' ELSE 'No' END AS Meets_Min_30
FROM dbo.cleaned_ecommerce_order_items
GROUP BY category
ORDER BY Total_Sales DESC;
GO

-- 10. View top 10 states by sales with their return rate
SELECT TOP 10
    state,
    SUM(item_total) AS Total_Sales,
    COUNT(DISTINCT order_id) AS Orders,
    CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) AS Return_Rate_Pct
FROM dbo.cleaned_ecommerce_order_items
WHERE state IS NOT NULL
GROUP BY state
ORDER BY Total_Sales DESC;
GO

-- 11. Check top return reasons (missing reasons shown as 'Not recorded')
SELECT
    COALESCE(NULLIF(LTRIM(RTRIM(return_reason)), ''), 'Not recorded') AS Return_Reason,
    COUNT(*) AS Returned_Items
FROM dbo.cleaned_ecommerce_order_items
WHERE is_returned = 1
GROUP BY COALESCE(NULLIF(LTRIM(RTRIM(return_reason)), ''), 'Not recorded')
ORDER BY Returned_Items DESC;
GO

-- 12. Compare refunds by refund mode
SELECT
    refund_mode,
    COUNT(*) AS Items,
    SUM(refund_amount) AS Total_Refund,
    AVG(refund_amount) AS Avg_Refund,
    AVG(CAST(refund_days AS DECIMAL(10,2))) AS Avg_Refund_Days
FROM dbo.cleaned_ecommerce_order_items
WHERE refund_amount IS NOT NULL
GROUP BY refund_mode
ORDER BY Total_Refund DESC;
GO

-- 13. Compare late delivery rate and delivery days by courier
SELECT
    courier_partner,
    COUNT(*) AS Items,
    CAST(100.0 * SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN is_late_delivery IN (0, 1) THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) AS Late_Delivery_Rate_Pct,
    AVG(CAST(promised_delivery_days AS DECIMAL(10,2))) AS Avg_Promised_Days,
    AVG(CAST(actual_delivery_days AS DECIMAL(10,2))) AS Avg_Actual_Days
FROM dbo.cleaned_ecommerce_order_items
GROUP BY courier_partner
ORDER BY Late_Delivery_Rate_Pct DESC;
GO

-- 14. Compare late delivery rate by courier and region
SELECT
    courier_partner,
    region,
    SUM(CASE WHEN is_late_delivery IN (0, 1) THEN 1 ELSE 0 END) AS Items_With_Known_Flag,
    CAST(100.0 * SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN is_late_delivery IN (0, 1) THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) AS Late_Delivery_Rate_Pct
FROM dbo.cleaned_ecommerce_order_items
WHERE region IS NOT NULL
GROUP BY courier_partner, region
HAVING SUM(CASE WHEN is_late_delivery IN (0, 1) THEN 1 ELSE 0 END) >= 30
ORDER BY courier_partner, region;
GO

-- 15. Compare return rate for late and on-time deliveries
WITH Delivery AS
(
    SELECT
        is_returned,
        CASE WHEN is_late_delivery = 1 THEN 'Late'
             WHEN is_late_delivery = 0 THEN 'On-time'
             ELSE 'Unknown' END AS Delivery_Outcome
    FROM dbo.cleaned_ecommerce_order_items
)
SELECT
    Delivery_Outcome,
    SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END) AS Items_With_Known_Flag,
    CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) AS Return_Rate_Pct
FROM Delivery
GROUP BY Delivery_Outcome;
GO

-- 16. Count cancelled items, orders with any cancelled item, and fully cancelled orders
WITH OrderCancel AS
(
    SELECT
        order_id,
        COUNT(*) AS Items_In_Order,
        SUM(CASE WHEN item_status = 'Cancelled' THEN 1 ELSE 0 END) AS Cancelled_In_Order
    FROM dbo.cleaned_ecommerce_order_items
    GROUP BY order_id
)
SELECT
    SUM(Cancelled_In_Order) AS Cancelled_Items,
    SUM(CASE WHEN Cancelled_In_Order > 0 THEN 1 ELSE 0 END) AS Orders_With_Any_Cancelled_Item,
    SUM(CASE WHEN Cancelled_In_Order = Items_In_Order THEN 1 ELSE 0 END) AS Fully_Cancelled_Orders
FROM OrderCancel;
GO

-- 17. Count sellers meeting minimum volume and high-risk sellers
-- Rule (provisional): 30+ items, return rate 5+ points above overall, average rating below 3.5
WITH Overall AS
(
    SELECT 100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) /
           NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0) AS Overall_Return_Rate
    FROM dbo.cleaned_ecommerce_order_items
),
SellerStats AS
(
    SELECT
        seller_id,
        COUNT(*) AS Items,
        100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) /
            NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0) AS Return_Rate,
        AVG(CAST(seller_rating AS DECIMAL(10,2))) AS Avg_Rating
    FROM dbo.cleaned_ecommerce_order_items
    GROUP BY seller_id
)
SELECT
    CAST(MAX(o.Overall_Return_Rate) AS DECIMAL(10,2)) AS Overall_Return_Rate_Pct,
    SUM(CASE WHEN s.Items >= 30 THEN 1 ELSE 0 END) AS Sellers_Meeting_Min_Volume,
    SUM(CASE WHEN s.Items >= 30
              AND s.Return_Rate >= o.Overall_Return_Rate + 5
              AND s.Avg_Rating < 3.5 THEN 1 ELSE 0 END) AS High_Risk_Sellers
FROM SellerStats s
CROSS JOIN Overall o;
GO

-- 18. View top 10 high-risk sellers
WITH Overall AS
(
    SELECT 100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) /
           NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0) AS Overall_Return_Rate
    FROM dbo.cleaned_ecommerce_order_items
),
SellerStats AS
(
    SELECT
        seller_id,
        COUNT(*) AS Items,
        100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) /
            NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0) AS Return_Rate,
        AVG(CAST(seller_rating AS DECIMAL(10,2))) AS Avg_Rating,
        SUM(item_total) AS Total_Sales
    FROM dbo.cleaned_ecommerce_order_items
    GROUP BY seller_id
)
SELECT TOP 10
    s.seller_id,
    s.Items,
    CAST(s.Return_Rate AS DECIMAL(10,2)) AS Return_Rate_Pct,
    CAST(s.Avg_Rating AS DECIMAL(10,2)) AS Avg_Seller_Rating,
    s.Total_Sales
FROM SellerStats s
CROSS JOIN Overall o
WHERE s.Items >= 30
  AND s.Return_Rate >= o.Overall_Return_Rate + 5
  AND s.Avg_Rating < 3.5
ORDER BY s.Return_Rate DESC;
GO

-- 19. Compare sales and return rate by discount band
WITH Banded AS
(
    SELECT
        item_total,
        is_returned,
        CASE WHEN discount_pct IS NULL THEN 'Unknown'
             WHEN discount_pct < 10 THEN '1. Below 10%'
             WHEN discount_pct < 20 THEN '2. 10% to below 20%'
             WHEN discount_pct < 30 THEN '3. 20% to below 30%'
             ELSE '4. 30% and above' END AS Discount_Band
    FROM dbo.cleaned_ecommerce_order_items
)
SELECT
    Discount_Band,
    COUNT(*) AS Items,
    SUM(item_total) AS Total_Sales,
    CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) AS Return_Rate_Pct
FROM Banded
GROUP BY Discount_Band
ORDER BY Discount_Band;
GO

-- 20. Compare return rate by payment method and Plus membership
SELECT
    payment_method,
    is_plus_member,
    SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END) AS Items_With_Known_Flag,
    CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) AS Return_Rate_Pct
FROM dbo.cleaned_ecommerce_order_items
GROUP BY payment_method, is_plus_member
HAVING SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END) >= 30
ORDER BY payment_method, is_plus_member;
GO

-- 21. Calculate monthly sales, growth, return rate and late delivery rate
WITH Monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(order_datetime), MONTH(order_datetime), 1) AS Order_Month,
        SUM(item_total) AS Total_Sales,
        CAST(100.0 * SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END) /
            NULLIF(SUM(CASE WHEN is_returned IN (0, 1) THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) AS Return_Rate_Pct,
        CAST(100.0 * SUM(CASE WHEN is_late_delivery = 1 THEN 1 ELSE 0 END) /
            NULLIF(SUM(CASE WHEN is_late_delivery IN (0, 1) THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) AS Late_Delivery_Rate_Pct
    FROM dbo.cleaned_ecommerce_order_items
    WHERE order_datetime IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(order_datetime), MONTH(order_datetime), 1)
)
SELECT
    Order_Month,
    Total_Sales,
    CAST(100.0 * (Total_Sales - LAG(Total_Sales) OVER (ORDER BY Order_Month)) /
        NULLIF(LAG(Total_Sales) OVER (ORDER BY Order_Month), 0) AS DECIMAL(10,2)) AS MoM_Sales_Growth_Pct,
    Return_Rate_Pct,
    Late_Delivery_Rate_Pct
FROM Monthly
ORDER BY Order_Month;
GO

-- 22. Validate that category sales add up to total sales
SELECT
    (SELECT SUM(item_total) FROM dbo.cleaned_ecommerce_order_items) AS Total_Sales,
    SUM(Category_Sales) AS Sales_By_Category
FROM (
    SELECT SUM(item_total) AS Category_Sales
    FROM dbo.cleaned_ecommerce_order_items
    GROUP BY category
) c;
GO