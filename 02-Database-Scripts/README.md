# Database Scripts

This folder contains all SQL scripts for database setup, schema creation, and ETL stored procedures for the **Banking Customer Loyalty & Churn Analytics** project.

**Status:** ✅ Complete — all scripts below were executed and verified against the final 147.3M-transaction / 884K-customer dataset.

---

## Script Categories

### Phase 2: Physical Environment Setup
Database and schema creation, dimension and fact table definitions (`BankingDW`).

### Phase 4: Source Database Setup
Simulated OLTP source database (`BankingSource`) for the augmented dataset, plus data profiling.

### Phase 5: ETL Support Scripts
Schema modifications and the stored-procedure layer that backs SSIS Packages 3, 4, and 5.

---

## Execution Order

### 1. Initial Database Setup
```sql
01-1-Create-BankingDW.sql          -- Create BankingDW database
01-2-Create-BankingStaging.sql     -- Create BankingStaging database (separate DB, not schema)
02-Create-Schema.sql               -- Create DW and ETL schemas inside BankingDW
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
11-Data-Profiling.sql              -- Data profiling on RawTransactions (NULL checks, ranges, samples)
```

### 5. Schema Modifications (run once, before first ETL execution)
```sql
12-Alter-Dim-Location-DataTypes.sql      -- Convert VARCHAR to NVARCHAR for Unicode support
14-Add-LocationCode-To-Staging.sql       -- Add LocationCode column to Stg_Customer for SARGable joins
```

### 6. Stored Procedures (back SSIS Packages 3–5)
```sql
13-Create-SP-Load-Dim-Customer.sql       -- usp_Load_Dim_Customer      — Package 3, SCD Type 2
15-Create-SP-Load-Fact-Transaction.sql   -- usp_Load_Fact_Transaction  — Package 4

16-Create-SP-Package5-Task1.sql          -- usp_Build_MonthlyActivity    — Package 5, Stage 1
17-Create-SP-Package5-Task2.sql          -- usp_Build_CustomerSpine      — Package 5, Stage 2
18-Create-SP-Package5-Task3.sql          -- usp_Merge_CalculateRF        — Package 5, Stage 3
19-Create-SP-Package5-Task4.sql          -- usp_Calculate_BusinessMetrics — Package 5, Stage 4
20-Create-SP-Package5-Task5.sql          -- usp_Load_FactCustomerSnapshot — Package 5, Stage 5
```

> **Execution note:** Scripts 01–11 are run once, in order, to stand up the empty schema. Scripts 12–20 create stored procedures and one schema fix; they don't move data themselves — data only moves when the corresponding SSIS package (or, for Package 5, the 5-stage SP chain) is executed. See `05-SSIS-Packages/README.md` for the package-level run sequence, including the mandatory manual re-run of script 14 after every Package 1 execution (see Known Issues below).

---

## Key Scripts Details

### Dimension Tables

| Script | Object | Rows (Actual) | Type | Notes |
|--------|--------|---------------|------|-------|
| 03–04 | Dim_Date | 5,844 | Pre-populated | 2015–2030, includes fiscal calendar |
| 05 | Dim_Location | 9,354 | Loaded via Package 2 | Includes location migrations from augmentation (above the original 9,021) |
| 06 | Dim_Customer | 1,169,677 total / 884,225 current | SCD Type 2 (Location only) | 243,376 customers with location history |
| 07 | Dim_Segment | 7 | Pre-populated | RF-based segments, exhaustive and non-overlapping (see Known Issues) |

### Fact Tables

| Script | Object | Grain | Load Method | Records (Actual) |
|--------|--------|-------|-------------|------------------|
| 08 | Fact_Transaction | Transaction-level | SP `usp_Load_Fact_Transaction` (Package 4) | 147,290,230 |
| 09 | Fact_CustomerSnapshot | Customer-Month | 5-stage SP pipeline (Package 5) | 13,051,115 |

> Fact_Transaction is **not** imported into the SSAS Tabular model — it is pre-aggregated into Fact_CustomerSnapshot, which is what the semantic layer and all three Power BI dashboards consume.

### Stored Procedures

| Script | Procedure | Purpose | Runtime (Actual) | Used By |
|--------|-----------|---------|------------------|---------|
| 13 | `usp_Load_Dim_Customer` | SCD Type 2 logic (location history) | 00:01:55 | Package 3 |
| 15 | `usp_Load_Fact_Transaction` | Fact load with SCD-aware customer joins | 00:24:09 | Package 4 |
| 16 | `usp_Build_MonthlyActivity` | Aggregate transactions to monthly level | 00:01:07 | Package 5, Stage 1 |
| 17 | `usp_Build_CustomerSpine` | Build dense customer-month timeline | 00:01:29 | Package 5, Stage 2 |
| 18 | `usp_Merge_CalculateRF` | Merge spine + activity; compute RF scores, Loyalty/Satisfaction Score, Churn/AtRisk flags, Growth Rate, Trend Category | 00:01:23 | Package 5, Stage 3 |
| 19 | `usp_Calculate_BusinessMetrics` | Assign `SegmentKey` (despite the procedure name, this stage does segment assignment, not general business-metric calculation — those were already computed in script 18) | 00:02:02 | Package 5, Stage 4 |
| 20 | `usp_Load_FactCustomerSnapshot` | Truncate & load into `DW.Fact_CustomerSnapshot`; drop global temp tables | ~00:04:00 | Package 5, Stage 5 |

**Package 5 total runtime: 00:10:02**

---

## Schema Modifications

### Unicode Support (Script 12)
**Issue:** `Dim_Location` was originally created with `VARCHAR` columns.
**Fix:** Converted to `NVARCHAR` for international character support.
**Impact:** Required for SSIS Data Flow compatibility with NVARCHAR-typed staging data.

### Performance Optimization (Script 14)
**Issue:** `UPPER(REPLACE(Location, ' ', '_'))` computed inline inside a `JOIN` predicate is non-SARGable — it forces a row-by-row function evaluation instead of an index seek.
**Fix:** Pre-compute `LocationCode` in `Stg_Customer` via `14-Add-LocationCode-To-Staging.sql`.
**Impact:** Eliminates the function call per row in the Package 3 and Package 4 joins.

> **Recurring known issue:** Script 14 must be re-run manually after every execution of Package 1, because Package 1 truncates and reloads `Stg_Customer` from scratch and does not know about the `LocationCode` column (it was added post-hoc, outside the package's original data-flow metadata).

---

## Known Issues & Resolutions

### 1. DATEFORMAT Bug (Critical — affects Scripts 13, 15, and the Package 5 pipeline)
**Issue:** The SQL Server instance uses `DATEFORMAT=mdy`. Using `TRY_CAST(TransactionDate AS DATE)` on `dd/mm/yyyy`-formatted strings silently returns `NULL` for any day ≥ 13, dropping roughly 60% of rows.
**Fix:** Every date parse in every script uses `TRY_CONVERT(date, TransactionDate, 103)` (style 103 = `dd/mm/yyyy`) instead of `TRY_CAST`.
**Impact:** First caught in `usp_Load_Fact_Transaction` (script 15) during Package 4 testing; the fix was then applied consistently across scripts 13, 15, 18, and the source data-profiling logic.

### 2. Dim_Customer DateOfBirth Fallback (Script 13)
**Issue:** An earlier version of `usp_Load_Dim_Customer` used `TRY_CAST` combined with `ISNULL(..., '1900-01-01')`, silently converting unparseable birth dates into a fabricated `1900-01-01` (or `1800-01-01` for some Python-generated source rows) instead of `NULL`. This produced 694,154 customers with implausible ages (126+ years).
**Fix:** Rewritten to use `TRY_CONVERT(date, ..., 103)` with explicit year-range validation (1930–2005); anything outside that range, or unparseable, is set to `NULL` instead of a fabricated default.
**Result:** 472,371 customers with valid `DateOfBirth`, 697,306 with `NULL` / `AgeGroup = "Unknown"` — a deliberate choice to preserve an honest, auditable data-quality signal rather than fabricate demographic data.

### 3. Duplicate Fact_Transaction Rows from SCD Overlap (Script 15)
**Issue:** The initial join from `Stg_Transaction` to `Dim_Customer` used `TransactionDate BETWEEN StartDate AND EndDate`. Customers with an A → B → A location history (moved away and later moved back) matched **multiple** SCD versions for transactions that fell in the overlapping date range, producing duplicate fact rows.
**Fix:** Changed the join to a direct `(CustomerID, Location)` string match against `Dim_Customer`, which is guaranteed 1:1 per customer given how the location-history staging table (`#LocationHistory` in script 13) is built.

### 4. Fact_Transaction Load — Transaction Log Overflow (Script 15)
**Issue:** Wrapping the full 147M-row insert in an explicit transaction exhausted the transaction log.
**Fix:** Removed the explicit transaction wrapper, added `WITH (TABLOCK)` to the insert, and disabled/rebuilt the four non-clustered indexes around the load instead of maintaining them row-by-row.

### 5. Dim_Segment Range Gaps (Fixed in Script 07)
**Issue:** The original segment ranges did not cover the full Recency × Frequency space (e.g., Recency 31–59 with Frequency 0–4 matched no segment), causing foreign-key violations on `SegmentKey` during the Package 5 load (script 19/20).
**Fix:** Ranges redesigned to be exhaustive and non-overlapping, and verified programmatically before deployment.

| Segment | RecencyMin | RecencyMax | FrequencyMin | FrequencyMax |
|---------|-----------|-----------|-------------|-------------|
| Champions | 0 | 59 | 15 | 9999 |
| Loyal Customers | 0 | 59 | 8 | 14 |
| Potential Loyalists | 0 | 59 | 5 | 7 |
| New Customers | 0 | 30 | 0 | 4 |
| At Risk | 60 | 90 | 5 | 9999 |
| Hibernating | 31 | 90 | 0 | 4 |
| Churned | 91 | 9999 | 0 | 9999 |

### 6. SSIS Execute SQL Task Timeout (Script 20 / Package 5)
**Issue:** The default SSIS Execute SQL Task timeout (300 seconds) was too short for the final `usp_Load_FactCustomerSnapshot` call against 13M+ rows, causing the task to fail mid-load.
**Fix:** `TimeOut` property set to `0` (unlimited) on the Execute SQL Task calling script 20, and on the other four Package 5 stage tasks as a precaution.

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

**Verified Results (final):**

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

**Latest month (Aug 2016) Churn / At-Risk:**

| Metric | Value |
|---|---|
| Total Customers | 831,639 |
| Churn Rate | 15.76% |
| At-Risk Rate | 1.00% |

---

## Notes

- All dimension tables use surrogate keys (`IDENTITY` auto-increment).
- SCD Type 2 is implemented for `Dim_Customer` — tracks location changes over time only (Age/Gender are Type 1, overwritten on each load).
- Fact tables include `ETLLoadDate` and `ETLBatchID` for audit trail.
- Stored procedures include error handling (`TRY`/`CATCH`) and dependency guards (e.g., scripts 17–20 check that the prior stage's global temp table exists before running).
- Scripts are idempotent where possible (`DROP ... IF EXISTS` before `CREATE`).
- Staging data types are kept as `VARCHAR`/`NVARCHAR` throughout (see `01-2-Create-BankingStaging.sql`), with all type conversion and validation happening in the stored-procedure layer — this preserves raw data integrity and keeps business logic out of the load-into-staging step.

---

## Related Documentation

- [Data Dictionary](../03-Data-Modeling/Data-Dictionary.md)
- [Data Model Design](../03-Data-Modeling/Data-Model-Design.md)
- [SSIS Packages](../05-SSIS-Packages/)
- [Python Scripts](../04-Python-Scripts/)
- [Requirements Document](../01-Requirements/)
- [Project README](../README.md)
