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
-- Step 1: Create main databases
01-1-Create-BankingDW.sql          -- Create BankingDW database
01-2-Create-BankingStaging.sql     -- Create BankingStaging database
02-Create-Schema.sql               -- Create DW and ETL schemas
```

### 2. Dimension Tables
```sql
-- Step 2: Date dimension (pre-populated)
03-Create-Dim-Date.sql             -- Create Date dimension
04-Populate-Dim-Date.sql           -- Populate Date dimension (2015-2030)

-- Step 3: Other dimensions
05-Create-Dim-Location.sql         -- Create Location dimension
06-Create-Dim-Customer.sql         -- Create Customer dimension (SCD Type 2)
07-Create-Dim-Segment.sql          -- Create and populate Segment dimension (7 RF segments)
```

### 3. Fact Tables
```sql
-- Step 4: Fact tables
08-Create-Fact-Transaction.sql     -- Create Transaction fact table (transaction-level grain)
09-Create-Fact-CustomerSnapshot.sql -- Create CustomerSnapshot fact table (customer-month grain)
```

### 4. Source Database & Data Profiling
```sql
-- Step 5: Source system
10-Create-Source-Database.sql      -- Create BankingSource database (OLTP simulation)
11-Data-Profiling.sql              -- Perform data profiling on RawTransactions
```

### 5. ETL Support & Enhancements
```sql
-- Step 6: Schema corrections
12-Alter-Dim-Location-DataTypes.sql -- Convert VARCHAR to NVARCHAR for Unicode support

-- Step 7: Staging enhancements
14-Add-LocationCode-To-Staging.sql  -- Add LocationCode column for SARGable joins

-- Step 8: Stored Procedures
13-Create-SP-Load-Dim-Customer.sql  -- SP for SCD Type 2 Customer loading (~50 sec for 884K)
15-Create-SP-Load-Fact-Transaction.sql -- SP for Fact_Transaction loading (~108 min for 154M)
```


---

## Key Scripts Details

### **Dimension Tables**

| Script | Object | Rows | Type | Notes |
|--------|--------|------|------|-------|
| 03-04 | Dim_Date | 5,844 | Pre-populated | 2015-2030, includes fiscal calendar |
| 05 | Dim_Location | Ready | Load via Package 2 | 9K locations expected |
| 06 | Dim_Customer | Ready | SCD Type 2 | Tracks location changes |
| 07 | Dim_Segment | 7 | Pre-populated | RF-based segments |

### **Fact Tables**

| Script | Object | Grain | Load Method | Records Expected |
|--------|--------|-------|-------------|------------------|
| 08 | Fact_Transaction | Transaction-level | SP (Package 4) | ~154M |
| 09 | Fact_CustomerSnapshot | Customer-Month | SP (Package 5) | ~15-20M |

### **Stored Procedures**

| Script | Procedure | Purpose | Runtime | Used By |
|--------|-----------|---------|---------|---------|
| 13 | usp_Load_Dim_Customer | SCD Type 2 logic | ~50 sec | Package 3 |
| 15 | usp_Load_Fact_Transaction | Fact load with SCD-aware joins | ~108 min | Package 4 |

---

## Schema Modifications

### Unicode Support (Script 12)
**Issue:** Dim_Location originally created with VARCHAR  
**Fix:** Converted to NVARCHAR for international character support  
**Impact:** Required for SSIS Data Flow compatibility

### Performance Optimization (Script 14)
**Issue:** `UPPER(REPLACE(Location, ' ', '_'))` in JOIN is non-SARGable  
**Fix:** Pre-compute LocationCode in Staging  
**Impact:** ~3.5x faster joins in dimension lookups

---

## Post-Execution Verification

After running all scripts, verify with:
```sql
-- Check all objects created
SELECT 
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS ObjectName,
    type_desc AS ObjectType
FROM sys.objects
WHERE schema_id IN (SCHEMA_ID('DW'), SCHEMA_ID('ETL'))
ORDER BY SchemaName, type_desc, name;

-- Check row counts
SELECT 'Dim_Date' AS TableName, COUNT(*) AS RowCount FROM DW.Dim_Date
UNION ALL
SELECT 'Dim_Segment', COUNT(*) FROM DW.Dim_Segment
UNION ALL
SELECT 'Dim_Location', COUNT(*) FROM DW.Dim_Location
UNION ALL
SELECT 'Dim_Customer', COUNT(*) FROM DW.Dim_Customer
UNION ALL
SELECT 'Fact_Transaction', COUNT(*) FROM DW.Fact_Transaction
UNION ALL
SELECT 'Fact_CustomerSnapshot', COUNT(*) FROM DW.Fact_CustomerSnapshot;
```

**Expected Results:**
- Dim_Date: 5,844
- Dim_Segment: 7
- Dim_Location: 9,021 (after Package 2)
- Dim_Customer: 884,265 (after Package 3)
- Fact_Transaction: 154,777,534 (after Package 4)
- Fact_CustomerSnapshot: 0 (until Package 5)

---

## Notes

- All dimension tables use surrogate keys (auto-increment)
- SCD Type 2 implemented for Dim_Customer (Location tracking)
- Fact tables include ETLLoadDate and ETLBatchID for audit
- Stored procedures include error handling and transaction management
- Scripts are idempotent where possible (DROP IF EXISTS)

---

## Related Documentation

- [Data Dictionary](../03-Data-Modeling/Data-Dictionary.md)
- [SSIS Packages](../05-SSIS-Packages/)
- [Requirements Document](../01-Requirements/)
