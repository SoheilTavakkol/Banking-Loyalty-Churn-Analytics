# Database Scripts

This folder contains all SQL scripts for database setup, schema creation, and ETL stored procedures.

---

## Script Categories

### Phase 2: Physical Environment Setup
Database and schema creation, dimension and fact table definitions.

### Phase 4: Source Database Setup
Operational source database for ETL testing and data profiling.

### Phase 5: ETL Support Scripts
Schema modifications, stored procedures, and staging enhancements.

---

## Execution Order

### 1. Initial Database Setup
```sql
01-1-Create-BankingDW.sql          -- Create BankingDW database
01-2-Create-BankingStaging.sql     -- Create BankingStaging database
02-Create-Schema.sql               -- Create DW and ETL schemas
```

### 2. Dimension Tables
```sql
03-Create-Dim-Date.sql             -- Create Date dimension
04-Populate-Dim-Date.sql           -- Populate Date dimension (2015-2030)

05-Create-Dim-Location.sql         -- Create Location dimension
06-Create-Dim-Customer.sql         -- Create Customer dimension (SCD Type 2)
07-Create-Dim-Segment.sql          -- Create and populate Segment dimension (7 RF segments)
```

### 3. Fact Tables
```sql
08-Create-Fact-Transaction.sql      -- Create Transaction fact table (transaction-level grain)
09-Create-Fact-CustomerSnapshot.sql -- Create CustomerSnapshot fact table (customer-month grain)
```

### 4. Source Database & Data Profiling
```sql
10-Create-Source-Database.sql      -- Create BankingSource database (OLTP simulation)
11-Data-Profiling.sql              -- Perform data profiling on RawTransactions
```

### 5. ETL Support & Enhancements
```sql
12-Alter-Dim-Location-DataTypes.sql      -- Convert VARCHAR to NVARCHAR for Unicode support
14-Add-LocationCode-To-Staging.sql       -- Add LocationCode column for SARGable joins

13-Create-SP-Load-Dim-Customer.sql       -- SP for SCD Type 2
15-Create-SP-Load-Fact-Transaction.sql   -- SP for Fact_Transaction load
16-Create-SP-Package5-Task1.sql          -- Build MonthlyActivity
17-Create-SP-Package5-Task2.sql          -- Build CustomerSpine
18-Create-SP-Package5-Task3.sql          -- Merge & Calculate RF + Business Metrics
19-Create-SP-Package5-Task4.sql          -- Assign Segments
20-Create-SP-Package5-Task5.sql          -- Load Fact_CustomerSnapshot
```

---

## Key Scripts Details

### Dimension Tables

| Script | Object | Rows (Actual) | Type | Notes |
|--------|--------|---------------|------|-------|
| 03–04 | Dim_Date | 5,844 | Pre-populated | 2015–2030, includes fiscal calendar |
| 05 | Dim_Location | 9,354 | Load via Package 2 | Includes location migrations from augmentation |
| 06 | Dim_Customer | 1,169,677 total / 884,225 current | SCD Type 2 | 243,376 customers with location history |
| 07 | Dim_Segment | 7 | Pre-populated | RF-based segments, exhaustive and non-overlapping |

### Fact Tables

| Script | Object | Grain | Load Method | Records (Actual) |
|--------|--------|-------|-------------|------------------|
| 08 | Fact_Transaction | Transaction-level | SP (Package 4) | 147,290,230 |
| 09 | Fact_CustomerSnapshot | Customer-Month | SP (Package 5) | 13,051,115 |

### Stored Procedures

| Script | Procedure | Purpose | Runtime (Actual) | Used By |
|--------|-----------|---------|------------------|---------|
| 13 | usp_Load_Dim_Customer | SCD Type 2 logic | 00:01:55 | Package 3 |
| 15 | usp_Load_Fact_Transaction | Fact load with SCD-aware joins | 00:24:09 | Package 4 |
| 16 | usp_Build_MonthlyActivity | Aggregate transactions to monthly level | 00:01:07 | Package 5 |
| 17 | usp_Build_CustomerSpine | Dense customer-month timeline | 00:01:29 | Package 5 |
| 18 | usp_Merge_CalculateRF | RF metrics + all business metrics | 00:01:23 | Package 5 |
| 19 | usp_Calculate_BusinessMetrics | Assign segment keys | 00:02:02 | Package 5 |
| 20 | usp_Load_FactCustomerSnapshot | Final load into fact table | ~00:04:00 | Package 5 |

**Package 5 total runtime: 00:10:02**

---

## Schema Modifications

### Unicode Support (Script 12)
**Issue:** Dim_Location originally created with VARCHAR
**Fix:** Converted to NVARCHAR for international character support
**Impact:** Required for SSIS Data Flow compatibility

### Performance Optimization (Script 14)
**Issue:** `UPPER(REPLACE(Location, ' ', '_'))` computed inside JOIN is non-SARGable
**Fix:** Pre-compute LocationCode in Staging via `14-Add-LocationCode-To-Staging.sql`
**Impact:** Eliminates function call per row in Package 3 and Package 4 joins

> **Note:** Script 14 must be re-run manually after every execution of Package 1, as Package 1 truncates and reloads `Stg_Customer` without populating `LocationCode`.

---

## Known Issues & Resolutions

### DATEFORMAT Bug (Critical)
**Issue:** SQL Server instance uses `DATEFORMAT=mdy`. Using `TRY_CAST(TransactionDate AS DATE)` silently returns NULL for any day ≥ 13, dropping ~60% of records.
**Fix:** All SPs use `TRY_CONVERT(date, TransactionDate, 103)` (style 103 = dd/mm/yyyy).
**Impact:** Affected original `usp_Load_Fact_Transaction` — corrected in script 15.

### Dim_Segment Gap (Fixed in Script 07)
**Issue:** Original segment ranges did not cover the full Recency × Frequency space, causing FK violations in Package 5.
**Fix:** Ranges redesigned to be exhaustive and non-overlapping. Verified programmatically before deployment.

| Segment | RecencyMin | RecencyMax | FrequencyMin | FrequencyMax |
|---------|-----------|-----------|-------------|-------------|
| Champions | 0 | 59 | 15 | 9999 |
| Loyal Customers | 0 | 59 | 8 | 14 |
| Potential Loyalists | 0 | 59 | 5 | 7 |
| New Customers | 0 | 30 | 0 | 4 |
| At Risk | 60 | 90 | 5 | 9999 |
| Hibernating | 31 | 90 | 0 | 4 |
| Churned | 91 | 9999 | 0 | 9999 |

---

## Post-Execution Verification

```sql
-- Row count check
SELECT 'Dim_Date'                  AS TableName, COUNT(*) AS RowCount FROM DW.Dim_Date
UNION ALL SELECT 'Dim_Segment',                  COUNT(*) FROM DW.Dim_Segment
UNION ALL SELECT 'Dim_Location',                 COUNT(*) FROM DW.Dim_Location
UNION ALL SELECT 'Dim_Customer (Total)',          COUNT(*) FROM DW.Dim_Customer
UNION ALL SELECT 'Dim_Customer (Current)',        COUNT(*) FROM DW.Dim_Customer WHERE IsCurrent = 1
UNION ALL SELECT 'Fact_Transaction',              COUNT(*) FROM DW.Fact_Transaction
UNION ALL SELECT 'Fact_CustomerSnapshot',         COUNT(*) FROM DW.Fact_CustomerSnapshot;

-- Segment distribution
SELECT
    ds.SegmentName,
    COUNT(*) AS CustomerMonths,
    FORMAT(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 'N2') + '%' AS Pct
FROM DW.Fact_CustomerSnapshot fcs
INNER JOIN DW.Dim_Segment ds ON fcs.SegmentKey = ds.SegmentKey
GROUP BY ds.SegmentName
ORDER BY CustomerMonths DESC;

-- Churn & AtRisk in latest month
SELECT
    SUM(CAST(ChurnFlag  AS INT)) AS ChurnedCustomers,
    SUM(CAST(AtRiskFlag AS INT)) AS AtRiskCustomers,
    COUNT(*)                     AS TotalCustomers,
    FORMAT(SUM(CAST(ChurnFlag  AS INT)) * 100.0 / COUNT(*), 'N2') + '%' AS ChurnRate,
    FORMAT(SUM(CAST(AtRiskFlag AS INT)) * 100.0 / COUNT(*), 'N2') + '%' AS AtRiskRate
FROM DW.Fact_CustomerSnapshot
WHERE DateKey = (SELECT MAX(DateKey) FROM DW.Fact_CustomerSnapshot);
```

**Verified Results (Jun 2026):**

| Table | Actual Rows |
|-------|-------------|
| Dim_Date | 5,844 |
| Dim_Segment | 7 |
| Dim_Location | 9,354 |
| Dim_Customer (Total) | 1,169,677 |
| Dim_Customer (Current) | 884,225 |
| Fact_Transaction | 147,290,230 |
| Fact_CustomerSnapshot | 13,051,115 |

| Segment | Customer-Months | % |
|---------|----------------|---|
| Loyal Customers | 3,602,583 | 27.60% |
| Champions | 3,093,899 | 23.71% |
| New Customers | 2,760,614 | 21.15% |
| Potential Loyalists | 1,883,756 | 14.43% |
| Churned | 1,306,637 | 10.01% |
| Hibernating | 403,626 | 3.09% |

---

## Notes

- All dimension tables use surrogate keys (IDENTITY auto-increment)
- SCD Type 2 implemented for Dim_Customer — tracks location changes over time
- Fact tables include `ETLLoadDate` and `ETLBatchID` for audit trail
- Stored procedures include error handling (TRY/CATCH) and dependency guards
- Scripts are idempotent where possible (DROP IF EXISTS)

---

## Related Documentation

- [Data Dictionary](../03-Data-Modeling/Data-Dictionary.md)
- [SSIS Packages](../05-SSIS-Packages/)
- [Python Scripts](../04-Python-Scripts/)
- [Requirements Document](../01-Requirements/)
