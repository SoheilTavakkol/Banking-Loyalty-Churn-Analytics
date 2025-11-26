# SSIS Packages - ETL Pipeline

This folder contains SQL Server Integration Services (SSIS) packages for the Banking Loyalty & Churn Analytics ETL pipeline.

## Project Structure
```
05-SSIS-Packages/
└── BankingETL/
    ├── Package 1 - Load Staging.dtsx
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
    ├── Dimensions (Dim_Customer, Dim_Location, Dim_Date, Dim_Segment)
    └── Facts (Fact_Transaction, Fact_CustomerSnapshot)
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
   - Right-click on package → Execute Package
   - Monitor progress in Progress tab

---

## Performance Tuning Applied

- **Fast Load Mode:** Bulk insert instead of row-by-row
- **Table Lock:** Exclusive lock during load for speed
- **Maximum Insert Commit Size:** 0 (single transaction)
- **Rows per Batch:** 500,000 (optimized batch size)
- **Check Constraints:** Disabled during load
- **Parallel Execution:** All three data flows run simultaneously

---

## Upcoming Packages

- **Package 2:** Load Dim_Location
- **Package 3:** Load Dim_Customer (SCD Type 2)
- **Package 4:** Load Fact_Transaction
- **Package 5:** Calculate Fact_CustomerSnapshot (RF scores, segmentation)

---

## Notes

- All staging tables use VARCHAR/NVARCHAR to preserve raw data
- Type conversions and business logic applied in later packages
- Validation flags allow tracking data quality issues
- No indexes on staging tables (temporary storage only)
