# Python Scripts

## Overview
This folder contains Python scripts for data preparation and augmentation.

## Scripts

### 1. `import_to_sql.py`
Initial data import script that loads the original CSV file (18 days of transactions) into SQL Server.

**Status:** ✅ Completed

---

### 2. `generate_extended_transactions.py`
**Smart Data Augmentation Script**

Extends the limited 18-day transaction dataset to a comprehensive 18-month period (Jan 2015 - Aug 2016) with realistic customer behavioral patterns.

#### What it does:
- Reads original 18-day transactions from `BankingSource.dbo.RawTransactions`
- Creates diverse customer journeys based on 5 personality types:
  - **Champions (20%):** 15-25 transactions/month, consistent activity
  - **Loyal (25%):** 8-14 transactions/month, stable patterns
  - **At-Risk (20%):** Start strong (10-15), decline to 3-5 over time
  - **Churned (20%):** Active for 6-12 months, then stop (90+ days inactive)
  - **New Customers (15%):** Only appear in last 3-6 months
- Generates realistic transaction amounts with ±20% variation
- Updates account balances organically
- Maintains all original customer attributes (DOB, Gender, Location)
- Outputs ~5-8M transactions spanning 18 months

#### Key Features:
- **Temporal Intelligence:** Transactions distributed realistically across months
- **Behavioral Realism:** Each customer follows a consistent journey
- **Data Integrity:** All relationships and constraints preserved
- **Performance:** Uses batch inserts (10,000 records at a time)
- **Progress Tracking:** Real-time progress bar with ETA

#### Technical Details:
- **Input:** `BankingSource.dbo.RawTransactions` (1M records, 18 days)
- **Output:** Same table (5-8M records, 18 months)
- **Processing Time:** ~10-15 minutes for 884K customers
- **Memory Usage:** Processes in batches to handle large datasets

#### Important Notes:
-  This script **truncates** `RawTransactions` before generating new data
-  Backup your original data if needed before running
-  Can be re-run to regenerate with different patterns
-  Business logic (Satisfaction, Churn flags) calculated later in ETL

---

## Dependencies

Install required packages:
```bash
pip install -r requirements.txt
```

**Required Packages:**
- `pyodbc`: SQL Server connectivity
- `pandas`: Data manipulation
- `numpy`: Numerical operations
- `python-dateutil`: Date calculations
- `tqdm`: Progress bars

---

## Execution Order

1. **Initial Import** (one-time):
```bash
   python import_to_sql.py
```

2. **Data Augmentation** (run when ready for ETL):
```bash
   python generate_extended_transactions.py
```

3. **Proceed to ETL** (SSIS packages in `/05-SSIS-Packages/`)

---

## Configuration

Both scripts use these SQL Server connection settings:
- **Server:** `localhost` (or your server name)
- **Database:** `BankingSource`
- **Authentication:** Windows Authentication (Trusted_Connection)

To modify connection settings, edit the `get_connection()` function in each script.

---

## Troubleshooting

**Issue:** `pyodbc.Error: ('01000', "[01000] [Microsoft]...")`
- **Solution:** Ignore this warning, it's informational only

**Issue:** `Memory Error`
- **Solution:** Script uses batch processing, but if needed reduce `BATCH_SIZE` in the script

**Issue:** `Connection timeout`
- **Solution:** Increase timeout in connection string: `timeout=60`

**Issue:** Script runs slowly
- **Solution:** Normal for large datasets. Progress bar shows ETA.

---

## Output Verification

After running `generate_extended_transactions.py`, verify the output:
```sql
USE BankingSource;
GO

-- Check date range
SELECT 
    MIN(TransactionDate) AS MinDate,
    MAX(TransactionDate) AS MaxDate,
    COUNT(*) AS TotalRecords,
    COUNT(DISTINCT CustomerID) AS UniqueCustomers
FROM dbo.RawTransactions;

-- Expected output:
-- MinDate: 2015-01-01 (or close)
-- MaxDate: 2016-08-31
-- TotalRecords: 5-8 million
-- UniqueCustomers: 884,265
```

---

## Architecture Note

**Why Python for augmentation instead of ETL?**

This design follows data warehousing best practices:
- ✅ **Separation of Concerns:** Data generation (Python) vs. business logic (ETL)
- ✅ **Auditability:** Clear distinction between raw data and calculated metrics
- ✅ **Flexibility:** Business rules (Satisfaction, Churn) remain in ETL for easy modification
- ✅ **Testability:** Can regenerate source data without affecting ETL logic

**What happens in ETL?**
- Satisfaction Score calculation (based on RF analysis)
- Churn Flag determination (90+ days inactive)
- Complaint Flag derivation (declining transaction patterns)
- Customer segmentation assignment

---

## Version History

- **v1.0** (Nov 2025): Initial implementation with smart customer journey simulation
