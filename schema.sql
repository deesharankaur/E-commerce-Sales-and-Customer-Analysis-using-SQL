--  Table structured to fit Kaggle CSV import
CREATE TABLE IF NOT EXISTS "products" (
    "voiceNo" TEXT PRIMARY KEY,
    "StockCode" TEXT NOT NULL,
    "Description" TEXT,
    "Quantity" INTEGER,
    "InvoiceDate" TEXT,
    "UnitPrice" REAL,
    "CustomerID" INTEGER,
    "Country" TEXT
);

--Creating View for cleaned data
-- removing cancelled invoices(starting with C), missing identifiers,
-- blank descriptions, and non-positive quantities/prices.
DROP VIEW IF EXISTS "cleaned_sales";

CREATE VIEW "cleaned_sales" AS
SELECT trim("voiceNo") AS "voice_no",
       trim("StockCode") AS "stock_code",
       trim("Description") AS "description",
       CAST("Quantity" AS INTEGER) AS "quantity",
       trim("InvoiceDate") AS "invoice_date",
       CAST("UnitPrice" AS REAL) AS "unit_price",
       TRIM("CustomerID") AS "customer_id",
       TRIM("Country") AS "country",
       CAST("Quantity" AS INTEGER) * CAST("UnitPrice" AS REAL) AS line_revenue

FROM "products"
WHERE
 "voiceNo" IS NOT NULL
  AND TRIM("voiceNo") <> ''
  AND UPPER(TRIM("voiceNo")) NOT LIKE 'C%'
  AND "StockCode" IS NOT NULL
  AND TRIM("StockCode") <> ''
  AND "Description" IS NOT NULL
  AND TRIM("Description") <> ''
  AND "Quantity" IS NOT NULL
  AND CAST("Quantity" AS INTEGER) > 0
  AND "UnitPrice" IS NOT NULL
  AND CAST("UnitPrice" AS REAL) > 0
  AND "CustomerID" IS NOT NULL
  AND TRIM("CustomerID") <> ''
  AND "Country" IS NOT NULL
  AND TRIM("Country") <> '';

-- indexes for faster raw-table checks and queries.
CREATE INDEX IF NOT EXISTS "idx_raw_voice" ON "products"("voiceNo");
CREATE INDEX IF NOT EXISTS "idx_raw_customer" ON "products"("CustomerID");
CREATE INDEX IF NOT EXISTS "idx_raw_date" ON "products"("InvoiceDate");
CREATE INDEX IF NOT EXISTS "idx_raw_stock" ON "products"("StockCode");
