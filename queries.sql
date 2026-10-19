-- 1. Dataset size and date range
SELECT
    COUNT(*) AS "raw_rows",
    MIN("InvoiceDate") AS "earliest_transaction",
    MAX("InvoiceDate") AS "latest_transaction"
FROM "products";

SELECT
    SUM(CASE WHEN "InvoiceNo" IS NULL OR TRIM("voiceNo") = '' THEN 1 ELSE 0 END) AS "missing_invoice",
    SUM(CASE WHEN "StockCode" IS NULL OR TRIM("StockCode") = '' THEN 1 ELSE 0 END) AS "missing_stock_code",
    SUM(CASE WHEN "Description" IS NULL OR TRIM("Description") = '' THEN 1 ELSE 0 END) AS "missing_description",
    SUM(CASE WHEN "Quantity" IS NULL THEN 1 ELSE 0 END) AS "missing_quantity",
    SUM(CASE WHEN "InvoiceDate" IS NULL OR TRIM("InvoiceDate") = '' THEN 1 ELSE 0 END) AS "missing_date",
    SUM(CASE WHEN "UnitPrice" IS NULL THEN 1 ELSE 0 END) AS "missing_unit_price",
    SUM(CASE WHEN "CustomerID" IS NULL OR TRIM("CustomerID") = '' THEN 1 ELSE 0 END) AS "missing_customer",
    SUM(CASE WHEN "Country" IS NULL OR TRIM("Country") = '' THEN 1 ELSE 0 END) AS "missing_country"
FROM "products";

-- 2. Count rows removed by the cleaning rules
SELECT
    (SELECT COUNT(*) FROM "products") AS "raw_rows",
    (SELECT COUNT(*) FROM "cleaned_sales") AS "clean_rows",
    (SELECT COUNT(*) FROM "products") -
    (SELECT COUNT(*) FROM "cleaned_sales") AS "excluded_rows";

-- 3. Overall sales KPIs
SELECT
    ROUND(SUM("line_revenue"), 2) AS "total_revenue",
    COUNT(DISTINCT "voice_no") AS "total_orders",
    COUNT(DISTINCT "customer_id") AS "unique_customers",
    SUM("quantity") AS "units_sold",
    ROUND(SUM("line_revenue") / NULLIF(COUNT(DISTINCT "voice_no"), 0), 2) AS "average_order_value"
FROM "cleaned_sales";

-- 4.Queries

-- i.) Which top 10 products generate highest revenue?
SELECT "stock_code" AS "highest_revenue_products",
       "description",
       SUM("quantity") AS "units_solds",
       ROUND(SUM("line_revenue"),2) AS "revenue"
FROM "cleaned_sales"
GROUP BY "description"
ORDER BY "line_revenue" DESC
LIMIT 10;

-- ii.) Which top 10 countries contribute most revenue?
SELECT "country" AS "highest_revenue_countries",
       COUNT(DISTINCT "voice_no") AS "orders",
       SUM("quantity") AS "units_solds",
       ROUND(SUM("line_revenue"),2) AS "revenue",
       COUNT(DISTINCT "customer_id") AS "customers"
FROM "cleaned_sales"
GROUP BY "country"
ORDER BY "line_revenue" DESC
LIMIT 10;

-- iii.) Which months generate most revenue?
SELECT substr("InvoiceDate", instr("InvoiceDate", '/') + 1,
           instr(substr("InvoiceDate", instr("InvoiceDate", '/') + 1), '/') - 1) AS "month_part",
    substr("InvoiceDate", -4) AS "year_part",
    ROUND(SUM("line_revenue"), 2) AS "revenue",
    COUNT(DISTINCT "voice_no") AS "orders"
FROM "cleaned_sales"
GROUP BY "year_part", "month_part"
ORDER BY CAST("year_part" AS INTEGER), CAST("month_part" AS INTEGER);

-- iv.) Which top 10 CUSTOMERS contribute most revenue?
SELECT "customer_id",
       COUNT("voice_no") AS "Number_of_orders",
       SUM("quantity") AS "units_brought",
       ROUND(SUM("line_revenue"),2) AS "revenue"
FROM "cleaned_sales"
GROUP BY "customer_id"
ORDER BY "revenue" DESC
LIMIT 10;

-- v.) Average revenue by countries?
SELECT "country",
       COUNT(DISTINCT "voice_no") AS "orders",
       SUM("quantity") AS "units_solds",
       ROUND(AVG("line_revenue"),2) AS "revenue",
       COUNT(DISTINCT "customer_id") AS "customers"
FROM "cleaned_sales"
GROUP BY "country"
ORDER BY "line_revenue" DESC;

-- iv.) List Repeat customers: customers with more than one order
WITH "customer_orders" AS (
    SELECT "customer_id", COUNT(DISTINCT "voice_no") AS "order_count"
    FROM "cleaned_sales"
    GROUP BY "customer_id"
)
SELECT
    COUNT(*) AS "customers_with_orders",
    SUM(CASE WHEN "order_count" > 1 THEN 1 ELSE 0 END) AS "repeat_customers",
    ROUND(
      100.0 * SUM(CASE WHEN "order_count" > 1 THEN 1 ELSE 0 END) /
      NULLIF(COUNT(*), 0), 2
    ) AS "repeat_customer_percentage"
FROM "customer_orders";

-- vii. Customers with the longest purchase history (number of distinct orders)
SELECT "customer_id" ,
       COUNT(DISTINCT "voice_no") AS "orders",
       "country",
       SUM("line_revenue") AS "revenue"
FROM "cleaned_sales"
GROUP BY "customer_id"
ORDER BY "orders" DESC
LIMIT 10;

-- viii.) Revenue contribution percentage by country using a window function
WITH "country_revenue" AS(
    SELECT "country", SUM("line_revenue") AS "revenue"
    FROM "cleaned_sales"
    GROUP BY "country"
)
SELECT "country",
       ROUND("revenue",2) AS "revenue",
       ROUND(100*"revenue"/NULLIF(SUM("revenue") OVER(), 0), 2) AS "revenue_share_pct"
FROM "country_revenue"
ORDER BY "revenue" DESC
LIMIT 10;

-- ix.) Product ranking within each country using ROW_NUMBER()
WITH "product_country" AS(
    SELECT "country", "stock_code", "description", SUM("line_revenue") AS "revenue"
    FROM "cleaned_sales"
    GROUP BY "country"
),

"ranked_products" AS(
    SELECT "country", "stock_code", "description", "revenue",
    ROW_NUMBER() OVER(PARTITION BY "country" ORDER BY "revenue" DESC) AS "product_rank"
    FROM "product_country"
)
SELECT  "country", "stock_code", "description", ROUND("revenue", 2) AS "revenue", "product_rank"
FROM "ranked_products"
WHERE "product_rank" <= 3
ORDER BY "country", "product_rank";

-- x.) Cancellation / return indicators in the raw data
-- Cancellation invoices often begin with C. Negative quantities can also be returns.
SELECT
    COUNT(*) AS "raw_rows",
    SUM(CASE WHEN UPPER(TRIM("voiceNo")) LIKE 'C%' THEN 1 ELSE 0 END) AS "cancellation_rows",
    SUM(CASE WHEN "Quantity" < 0 THEN 1 ELSE 0 END) AS "negative_quantity_rows",
    ROUND(SUM(CASE WHEN "Quantity" < 0 THEN "Quantity" * "UnitPrice" ELSE 0 END), 2) AS "negative_line_value"
FROM "products";

-- xi.) Orders with unusually high line totals (top 20 lines)
SELECT * FROM "cleaned_sales"
ORDER BY "line_revenue"
LIMIT 20;


-- xii.) Check for duplicate-looking raw rows
SELECT
    "voiceNo", "StockCode", "Quantity", "InvoiceDate", "UnitPrice", "CustomerID",
    COUNT(*) AS "duplicate_count"
FROM "products"
GROUP BY "voiceNo", "StockCode", "Quantity", "InvoiceDate", "UnitPrice", "CustomerID"
HAVING COUNT(*) > 1
ORDER BY "duplicate_count" DESC
LIMIT 50;

-- xiii.) Customer revenue segments (simple rule-based segmentation)
WITH "customer_revenue" AS (
    SELECT "customer_id", SUM("line_revenue") AS "revenue"
    FROM "cleaned_sales"
    GROUP BY "customer_id"
)
SELECT
    CASE
      WHEN "revenue" >= 10000 THEN 'High value'
      WHEN "revenue" >= 2000 THEN 'Medium value'
      ELSE 'Low value'
    END AS "customer_segment",
    COUNT(*) AS "customers",
    ROUND(SUM("revenue"), 2) AS "segment_revenue"
FROM "customer_revenue"
GROUP BY "customer_segment"
ORDER BY "segment_revenue" DESC;

-- xiv.) One-row KPI summary for a dashboard/report
SELECT ROUND(SUM("line_revenue"), 2) AS "revenue",
    COUNT(DISTINCT "voice_no") AS "orders",
    COUNT(DISTINCT "customer_id") AS "customers",
    SUM("quantity") AS "units_sold",
    ROUND(SUM("line_revenue") / NULLIF(COUNT(DISTINCT "voice_no"), 0), 2) AS "avg_order_value"
FROM "cleaned_sales";
