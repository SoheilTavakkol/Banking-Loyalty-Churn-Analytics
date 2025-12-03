# SSIS Packages - ETL Pipeline

This folder contains SQL Server Integration Services (SSIS) packages for the Banking Loyalty & Churn Analytics ETL pipeline.

## Project Structure
```
05-SSIS-Packages/
└── BankingETL/
    ├── Package 1 - Load Staging.dtsx
    ├── Package 2 - Load Dim_Location.dtsx
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


## Database Architecture
```
BankingSource (OLTP)
    └── RawTransactions (154M records)
              ↓
BankingStaging (Staging Layer)
    ├── Stg_Customer (884K records)
    ├── Stg_Transaction (154M records)
    └── Stg_Location (9K records)
              ↓
BankingDW (Data Warehouse)
    ├── Dimensions:
    │   ├── Dim_Date (Pre-populated: 5,844 rows)
    │   ├── Dim_Segment (Pre-populated: 7 segments)
    │   ├── Dim_Location (Loaded: 9,021 rows) 
    │   └── Dim_Customer (SCD Type 2) ⏳ Next
    └── Facts:
        ├── Fact_Transaction (transaction-level grain)
        └── Fact_CustomerSnapshot (customer-month grain)
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

---

## Upcoming Packages

### **Package 4:** Load Fact_Transaction ⏳ NEXT

Purpose: Load transaction-level fact table

Source: Stg_Transaction (154M records)
Destination: Fact_Transaction
Complexity:
- SCD-aware CustomerKey lookup (match transaction date with customer version)
- DateKey lookup from Dim_Date
- LocationKey lookup from Dim_Location
Estimated Runtime: 2-3 hours for 154M records
---

### **Package 5:** Calculate Fact_CustomerSnapshot
- Monthly aggregation (**Customer–Month** grain)  
- **RF score** calculations (Recency: 1–5, Frequency: 1–5)  
- Loyalty & Satisfaction scores  
- Churn flag (**Recency > 90 days**)  
- Complaint flag (**frequency decline > 30%**)  
- Segment assignment from **Dim_Segment**  
- Trend analysis (growth rate)  
- Expected records: **~15–20M** (884K customers × 20 months)  
- Estimated runtime: **~2–3 hours**

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
