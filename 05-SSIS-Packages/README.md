# SSIS Packages - ETL Pipeline

This folder contains SQL Server Integration Services (SSIS) packages for the Banking Loyalty & Churn Analytics ETL pipeline.

## Project Structure
```
05-SSIS-Packages/
└── BankingETL/
    ├── Package 1 - Load Staging.dtsx
    ├── Package 2 - Load Dim_Location.dtsx
    ├── Package 3 - Load Dim_Customer.dtsx
    ├── Package 4 - Load Fact_Transaction.dtsx
    ├── Package 5 - Calculate CustomerSnapshot.dtsx
    ├── BankingETL.sln
    └── (other SSIS project files)
```

## Package Overview

### Package 1 - Load Staging ✅ COMPLETED

**Purpose:** Extract data from source system (BankingSource) and load into staging tables (BankingStaging) with data cleansing and validation.

**Data Flows:**
- **DFT - Load Stg_Customer:** Extract distinct customers with cleansing and validation flags
  - Records: 884,265 customers
  - Runtime: ~1 minute 40 seconds
  
- **DFT - Load Stg_Transaction:** Extract all transactions with cleansing and validation flags
  - Records: 154,777,534 transactions
  - Runtime: ~28 minutes
  
- **DFT - Load Stg_Location:** Extract distinct locations
  - Records: 9,021 locations
  - Runtime: ~32 seconds

**Total Runtime:** ~30 minutes for 155+ million records

**Key Features:**
- Parallel execution of all three data flows (no dependencies)
- Data cleansing: Convert 'nan' strings to NULL
- Validation flags: Identify invalid records
- Performance optimizations: Fast Load, Table Lock, Bulk Insert (500K batch size)

---
### Package 2 - Load Dim_Location ✅ COMPLETED

**Purpose:** Load distinct locations from staging to Dim_Location with data enrichment using reference table.

**Data Flow:**
```
OLE DB Source (Stg_Location)
    ↓
Lookup - City_Lookup (23 major cities)
    ↓
Derived Column (data enrichment)
    ↓
OLE DB Destination (Dim_Location)
```

**Data Enrichment:**
- **LocationCode:** `UPPER(REPLACE(Location, ' ', '_'))` - Business Key
- **LocationName:** Original location name
- **City:** Location name
- **State:** From City_Lookup if match found, else "Unknown"
- **Region:** From City_Lookup if match found, else "Unknown"
- **Country:** "India" for all records
- **LocationType:** "City" for all records
- **Latitude/Longitude:** NULL (can be enriched later)
- **CreatedDate/ModifiedDate:** GETDATE()

**Reference Table:**
- **ETL.City_Lookup** (in BankingDW): 23 major Indian cities with State and Region mapping
- Created specifically for location enrichment
- Cities include: Mumbai, Delhi, Bangalore, Pune, Chennai, Hyderabad, Kolkata, etc.

**Results:**
- Total locations loaded: 9,021
- Locations with State/Region (matched): 23 (0.3%)
- Locations with State/Region = "Unknown": 8,998 (99.7%)
- Runtime: ~30 seconds

**Key Features:**
- Lookup transformation for data enrichment
- Graceful handling of unmatched locations (mark as "Unknown")
- Demonstrates 80/20 rule: Focus on major cities first
- Unicode support (NVARCHAR) for international characters

**Technical Notes:**
- Dim_Location columns changed from VARCHAR to NVARCHAR for Unicode support
- Script saved: `02-Database-Scripts/12-Alter-Dim-Location-DataTypes.sql`
- Explicit casting used in Derived Column: `(DT_WSTR,length)Expression`
- Lookup configured with "Ignore failure" for unmatched rows

---
### Package 3 - Load Dim_Customer ✅ COMPLETED

Purpose: Load Dim_Customer with SCD Type 2 logic via Stored Procedure

Architecture:
```
Execute SQL Task
  ↓ EXEC DW.usp_Load_Dim_Customer
  ↓
Success
```

**Method:** Hybrid approach (SSIS calls SP)

**Why Stored Procedure?**
- Performance: Set-based operations in SQL Server
- Maintainability: Business logic in database
- Testability: Can test SP independently
- SCD Type 2 complexity: Easier to debug in T-SQL

**Data Flow:**
```
BankingStaging.Stg_Customer (884K records)
  ↓
Stored Procedure: DW.usp_Load_Dim_Customer
  ↓ Step 1: Create #FinalStaging temp table
  ↓   - Join with Dim_Location (via LocationCode)
  ↓   - Calculate Age from DOB
  ↓   - Derive AgeGroup
  ↓   - Handle NULLs (DateOfBirth='1900-01-01', Age=0)
  ↓ Step 2: Expire old records (Location changed)
  ↓ Step 3: Insert new records (new customers + new versions)
  ↓ Step 4: Update Type 1 attributes (Age, AgeGroup, Gender)
  ↓
Dim_Customer (884,265 records)
```

**Runtime:** ~50 seconds for 884K customers

**Key Features:**
- **SCD Type 2 for Location:** Tracks historical location changes
- **Type 1 for Demographics:** Age, AgeGroup, Gender (overwrite)
- **Temp Table with Index:** Clustered index on CustomerID for performance
- **NULL Handling:** Missing DOB → '1900-01-01', Missing Age → 0
- **LocationCode Join:** Pre-computed for SARGable performance

**Results:**
- Total records: 884,265
- Current records: 884,265 (IsCurrent=1)
- Historical records: 0 (first load, no location changes yet)

**Data Quality Observations:**
- 54% customers with missing DOB (source data issue)
- 0.015% customers with missing LocationKey (locations not in Dim_Location)
- 0.1% customers with unknown gender

**Execute SQL Task Settings:**
- Connection: BankingDW
- SQLStatement: `EXEC DW.usp_Load_Dim_Customer;`
- ResultSet: None
- SQLSourceType: Direct input
- TransactionOption: NotSupported (SP manages its own transaction)

**Prerequisites:**
1. LocationCode column added to Stg_Customer (script: `14-Add-LocationCode-To-Staging.sql`)
2. Stored Procedure created (script: `13-Create-SP-Load-Dim-Customer.sql`)
3. Package 1 & 2 completed (Staging and Dim_Location loaded)
   
---
### Connection Managers Required

Before running the packages, ensure these connection managers are configured:

1. **BankingSource** → Source OLTP database
2. **BankingStaging** → Staging database
3. **BankingDW** → Data Warehouse (for future packages)

---
### Package 4 - Load Fact_Transaction ✅ COMPLETED

**Purpose:** Load transaction-level fact table with dimension lookups

**Architecture:**
```
Execute SQL Task
  ↓ EXEC DW.usp_Load_Fact_Transaction
  ↓
Success
```

**Method:** Stored Procedure (Direct INSERT with JOINs)

**Why Stored Procedure?**
- SCD-aware lookup: Match transaction date with customer version
- Set-based operations: Much faster than row-by-row SSIS Lookup
- Complex JOIN logic: BETWEEN clause for SCD Type 2
- Performance: 154M records in ~2 hours

**Data Flow:**
```
BankingStaging.Stg_Transaction (154M records)
  ↓
Stored Procedure: DW.usp_Load_Fact_Transaction
  ↓ Step 1: INSERT with JOINs
  ↓   - SCD-aware CustomerKey lookup:
  ↓     JOIN Dim_Customer WHERE TransactionDate BETWEEN StartDate AND EndDate
  ↓   - DateKey lookup: CAST(CONVERT(VARCHAR(8), Date, 112) AS INT)
  ↓   - LocationKey lookup: via LocationCode
  ↓
Fact_Transaction (154,777,534 records)
```

**Runtime:** 1 hour 48 minutes for 154M transactions

**Key Features:**
- **SCD-aware Lookup:** Matches transaction to correct customer version
- **Direct INSERT:** No temp tables, single statement
- **DateKey Formula:** YYYYMMDD format (e.g., 20150321)
- **NULL Handling:** LocationKey can be NULL (22K records, 0.014%)

**Results:**
- Total records: 154,777,534
- Date range: 2015-01-01 to 2016-08-31 (20 months)
- NULL CustomerKey: 0
- NULL DateKey: 0
- NULL LocationKey: 22,048 (0.014% - acceptable)

**Execute SQL Task Settings:**
- Connection: BankingDW
- SQLStatement: `EXEC DW.usp_Load_Fact_Transaction;`
- ResultSet: None
- SQLSourceType: Direct input
- TransactionOption: NotSupported

**Prerequisites:**
1. Package 3 completed (Dim_Customer with correct StartDate)
2. Stored Procedure created (script: `15-Create-SP-Load-Fact-Transaction.sql`)
3. Dim_Customer StartDate = FirstTransactionDate (not current date!)

**Critical Fix Applied:**
- Initially Dim_Customer had StartDate = 2025-12-03 (current date)
- Transactions are 2015-2016
- Result: 0 matches!
- Fix: Modified Package 3 SP to use FirstTransactionDate as StartDate

---

### Package 5 - Calculate Fact_CustomerSnapshot ✅ COMPLETED

**Purpose:** Monthly customer aggregation with RF analysis and business metrics

**Architecture:** 5-Task Sequential Pipeline (All Execute SQL Tasks)

**Tasks:**
1. **Build Monthly Activity** (~60 sec)
   - Aggregate 154M transactions → 13.7M monthly records
   - SP: `DW.usp_Build_MonthlyActivity`
   
2. **Build Customer Spine** (~90 sec)
   - Create customer-month timeline → 15.6M records
   - SP: `DW.usp_Build_CustomerSpine`
   
3. **Merge & Calculate RF** (~55 sec)
   - Join spine with activity + RF calculations
   - SP: `DW.usp_Merge_CalculateRF`
   
4. **Calculate Business Metrics** (~250 sec)
   - Loyalty, satisfaction, churn, complaints
   - SP: `DW.usp_Calculate_BusinessMetrics`
   
5. **Load Fact Table** (~30 sec)
   - Insert into Fact_CustomerSnapshot
   - SP: `DW.usp_Load_FactCustomerSnapshot`

**Total Runtime:** ~13 minutes

**Results:**
- Records loaded: 15,581,079
- Churn rate: 9.74%
- Loyalty distribution: 75% High/Very High

**Key Features:**
- Global temp tables (`##`) for inter-SP communication
- Parameter passing (`@CutoffDate = '2016-08-31'`)
- Set-based operations for performance
- Segment assignment via Dim_Segment rules

---

## Database Architecture
```
BankingDW (Data Warehouse)
    ├── Dimensions:
    │   ├── Dim_Date (Pre-populated: 5,844 rows) ✅
    │   ├── Dim_Segment (Pre-populated: 7 segments) ✅
    │   ├── Dim_Location (Loaded: 9,021 rows) ✅
    │   └── Dim_Customer (Loaded: 884,265 rows) ✅
    └── Facts:
        ├── Fact_Transaction (Loaded: 154,777,534 rows) ✅
        └── Fact_CustomerSnapshot (Loaded: 15,581,079 rows) ✅
```

---

## How to Run

### Prerequisites
- SQL Server 2019+
- Visual Studio 2019/2022 with SSIS extension
- BankingSource database populated with data
- BankingStaging database created

### Execution Steps

1. Open `BankingETL.sln` in Visual Studio
2. Configure Connection Managers:
   - Right-click each connection → Edit
   - Update server name and credentials
3. Run Package 1:
   - Package 1: Right-click → Execute Package (~30 min)
   - Package 2: Right-click → Execute Package (~30 sec)
4. Monitor progress in Progress tab
5. Verify results with validation queries (see below)

---

## Performance Tuning Applied

**Package 1:**
- **Fast Load Mode:** Bulk insert instead of row-by-row
- **Table Lock:** Exclusive lock during load for speed
- **Maximum Insert Commit Size:** 0 (single transaction)
- **Rows per Batch:** 500,000 (optimized batch size)
- **Check Constraints:** Disabled during load
- **Parallel Execution:** All three data flows run simultaneously

**Package 2:** 
- **Fast Load Mode:** Enabled
- **Table Lock:** Enabled
- **Maximum Insert Commit Size:** 0 (single transaction)
- **Rows per Batch:** 10,000 (smaller dataset)
- **Check Constraints:** Disabled during load
- **Lookup Transformation:** "Ignore failure" for unmatched rows
- **Explicit Unicode casting:** (DT_WSTR,length) in Derived Columns

---

## Validation Queries

**After Package 1:**
```sql
-- Check staging record counts
SELECT COUNT(*) FROM BankingStaging.dbo.Stg_Customer;      -- Expected: 884,265
SELECT COUNT(*) FROM BankingStaging.dbo.Stg_Transaction;   -- Expected: 154,777,534
SELECT COUNT(*) FROM BankingStaging.dbo.Stg_Location;      -- Expected: 9,021

-- Check validation flags
SELECT 
    HasInvalidCustomerID,
    HasInvalidDate,
    HasInvalidAmount,
    COUNT(*) AS RecordCount
FROM BankingStaging.dbo.Stg_Transaction
GROUP BY HasInvalidCustomerID, HasInvalidDate, HasInvalidAmount;
```

**After Package 2:**
```sql
-- Check dimension record count
SELECT COUNT(*) FROM BankingDW.DW.Dim_Location;  -- Expected: 9,021

-- Check State/Region distribution
SELECT 
    State,
    COUNT(*) AS LocationCount
FROM BankingDW.DW.Dim_Location
GROUP BY State
ORDER BY LocationCount DESC;

-- Sample enriched data
SELECT TOP 20 
    LocationKey,
    LocationCode,
    LocationName,
    City,
    State,
    Region,
    Country
FROM BankingDW.DW.Dim_Location
WHERE State != 'Unknown'
ORDER BY State, City;
```
**After Package 3:**
```sql
-- =============================================
-- Package 3 Validation: Dim_Customer
-- =============================================

-- 1. Summary Statistics
SELECT 
    COUNT(*) AS TotalRecords,
    COUNT(DISTINCT CustomerID) AS UniqueCustomers,
    SUM(CASE WHEN IsCurrent = 1 THEN 1 ELSE 0 END) AS CurrentRecords,
    SUM(CASE WHEN IsCurrent = 0 THEN 1 ELSE 0 END) AS HistoricalRecords
FROM BankingDW.DW.Dim_Customer;
-- Expected: 884,265 total, 884,265 unique, 884,265 current, 0 historical (first load)

-- 2. Age Distribution
SELECT 
    AgeGroup, 
    COUNT(*) AS CustomerCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Percentage
FROM BankingDW.DW.Dim_Customer
WHERE IsCurrent = 1
GROUP BY AgeGroup
ORDER BY AgeGroup;

-- 3. Gender Distribution
SELECT 
    Gender, 
    COUNT(*) AS CustomerCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Percentage
FROM BankingDW.DW.Dim_Customer
WHERE IsCurrent = 1
GROUP BY Gender
ORDER BY Gender;

-- 4. Top 10 Locations
SELECT TOP 10
    Location, 
    COUNT(*) AS CustomerCount
FROM BankingDW.DW.Dim_Customer
WHERE IsCurrent = 1
GROUP BY Location
ORDER BY CustomerCount DESC;

-- 5. Data Quality Check
SELECT 
    SUM(CASE WHEN DateOfBirth = '1900-01-01' THEN 1 ELSE 0 END) AS MissingDOB,
    SUM(CASE WHEN Age = 0 THEN 1 ELSE 0 END) AS MissingAge,
    SUM(CASE WHEN Gender = 'Unknown' THEN 1 ELSE 0 END) AS UnknownGender,
    SUM(CASE WHEN LocationKey IS NULL THEN 1 ELSE 0 END) AS MissingLocation,
    SUM(CASE WHEN AgeGroup = 'Unknown' THEN 1 ELSE 0 END) AS UnknownAgeGroup
FROM BankingDW.DW.Dim_Customer
WHERE IsCurrent = 1;

-- 6. Sample Records
SELECT TOP 20
    CustomerKey, CustomerID, DateOfBirth, Age, AgeGroup, 
    Gender, Location, LocationKey, StartDate, EndDate, IsCurrent
FROM BankingDW.DW.Dim_Customer
ORDER BY CustomerKey;

-- 7. SCD Type 2 Check (for future runs)
SELECT 
    CustomerID,
    COUNT(*) AS VersionCount
FROM BankingDW.DW.Dim_Customer
GROUP BY CustomerID
HAVING COUNT(*) > 1
ORDER BY VersionCount DESC;
-- Expected: 0 rows (no location changes yet)
```
### After Package 4:
```sql
-- =============================================
-- Package 4 Validation: Fact_Transaction
-- =============================================

-- 1. Total Records
SELECT COUNT(*) AS TotalTransactions
FROM DW.Fact_Transaction;
-- Expected: ~154,777,534

-- 2. Date Range
SELECT 
    MIN(dd.Date) AS MinDate,
    MAX(dd.Date) AS MaxDate
FROM DW.Fact_Transaction ft
INNER JOIN DW.Dim_Date dd ON ft.DateKey = dd.DateKey;
-- Expected: 2015-01-01 to 2016-08-31

-- 3. NULL Check
SELECT 
    SUM(CASE WHEN CustomerKey IS NULL THEN 1 ELSE 0 END) AS NullCustomerKey,
    SUM(CASE WHEN DateKey IS NULL THEN 1 ELSE 0 END) AS NullDateKey,
    SUM(CASE WHEN LocationKey IS NULL THEN 1 ELSE 0 END) AS NullLocationKey
FROM DW.Fact_Transaction;
-- Expected: 0, 0, ~22K

-- 4. Sample Records
SELECT TOP 20
    ft.TransactionKey,
    ft.CustomerKey,
    ft.DateKey,
    ft.LocationKey,
    ft.TransactionID,
    ft.TransactionAmount,
    ft.AccountBalance,
    dc.CustomerID,
    dd.Date
FROM DW.Fact_Transaction ft
INNER JOIN DW.Dim_Customer dc ON ft.CustomerKey = dc.CustomerKey
INNER JOIN DW.Dim_Date dd ON ft.DateKey = dd.DateKey
ORDER BY ft.TransactionKey;

-- 5. Transaction Volume by Month
SELECT 
    dd.YearMonth,
    COUNT(*) AS TransactionCount,
    SUM(ft.TransactionAmount) AS TotalAmount
FROM DW.Fact_Transaction ft
INNER JOIN DW.Dim_Date dd ON ft.DateKey = dd.DateKey
GROUP BY dd.YearMonth
ORDER BY dd.YearMonth;
```
---
### After Package 5:
```sql
-- =============================================
-- Package 5 Validation: Fact_CustomerSnapshot
-- =============================================

-- Total records
SELECT COUNT(*) FROM DW.Fact_CustomerSnapshot;
-- Expected: 15,581,079

-- Loyalty distribution
SELECT 
    CASE 
        WHEN LoyaltyScore >= 4.5 THEN 'Very High'
        WHEN LoyaltyScore >= 3.5 THEN 'High'
        WHEN LoyaltyScore >= 2.5 THEN 'Medium'
        ELSE 'Low'
    END AS Category,
    COUNT(*) AS Records,
    FORMAT(COUNT(*)*100.0/SUM(COUNT(*)) OVER(), 'N1')+'%' AS Pct
FROM DW.Fact_CustomerSnapshot
GROUP BY CASE 
    WHEN LoyaltyScore >= 4.5 THEN 'Very High'
    WHEN LoyaltyScore >= 3.5 THEN 'High'
    WHEN LoyaltyScore >= 2.5 THEN 'Medium'
    ELSE 'Low' END
ORDER BY Category DESC;

-- Churn analysis
SELECT 
    ChurnFlag,
    COUNT(*) AS Records,
    AVG(LoyaltyScore) AS AvgLoyalty
FROM DW.Fact_CustomerSnapshot
GROUP BY ChurnFlag;
```
---

## Notes

- All staging tables use **VARCHAR/NVARCHAR** to preserve raw data  
- Type conversions and business logic applied in later packages  
- Validation flags allow tracking data quality issues without blocking loads  
- No indexes on staging tables (temporary storage only)  
- Reference tables (like **City_Lookup**) enable realistic data enrichment  
- Unicode support (**NVARCHAR**) throughout dimension tables  
- Explicit casting required in SSIS for VARCHAR to NVARCHAR:  
  `(DT_WSTR,length)`

---

## Troubleshooting
### Common Issues:

### 1.Unicode/Non-Unicode Error
- **Symptom:** Cannot convert between unicode and non-unicode string data types
- **Solution:** Use explicit casting `(DT_WSTR,length)` in Derived Column expressions

### 2-Connection Manager Errors
- **Symptom:** Cannot acquire connection
- **Solution:** Right-click connection → Edit → Test connection → Update server name/credentials

### 3-Memory Issues (Package 1)
- **Symptom:** Out of memory errors
- **Solution:** Reduce Rows per Batch or run data flows sequentially instead of parallel

### 4-Lookup No Match Handling
- **Symptom:** Lookup fails on unmatched rows
- **Solution:** Set "Specify how to handle rows with no matching entries" to "Ignore failure"

---

## Project Repository
Banking-Loyalty-Churn-Analytics
