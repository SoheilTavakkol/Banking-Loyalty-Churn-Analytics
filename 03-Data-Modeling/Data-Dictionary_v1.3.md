# Data Dictionary
## Banking Customer Loyalty & Churn Analysis Data Warehouse

**Version:** 1.3
**Last Updated:** June 2026

---

## Table of Contents
1. [Dimension Tables](#dimension-tables)
   - [Dim_Date](#dim_date)
   - [Dim_Customer](#dim_customer)
   - [Dim_Location](#dim_location)
   - [Dim_Segment](#dim_segment)
2. [Fact Tables](#fact-tables)
   - [Fact_Transaction](#fact_transaction)
   - [Fact_CustomerSnapshot](#fact_customersnapshot)
3. [SSAS Tabular Layer](#ssas-tabular-layer)
4. [Standard Columns](#standard-columns)
5. [Code Values](#code-values)

---

## Dimension Tables

### Dim_Date

**Schema:** DW
**Purpose:** Calendar and time dimension for temporal analysis
**Type:** Reference dimension (pre-populated)
**Rows:** 5,844 (2015-2030)
**Grain:** One row per day
**SCD Type:** Static (no changes)

#### Columns

| Column Name | Data Type | Nullable | Description | Sample Values |
|-------------|-----------|----------|-------------|---------------|
| **DateKey** | INT | No | Primary key (YYYYMMDD format) | 20160208, 20230715 |
| FullDateTime | DATETIME | No | Complete date and time | 2016-02-08 14:32:07 |
| Date | DATE | No | Date portion only | 2016-02-08 |
| Year | INT | No | Year (4-digit) | 2016, 2023 |
| YearName | VARCHAR(10) | No | Year as string | "2016", "2023" |
| Quarter | INT | No | Quarter of year (1-4) | 1, 2, 3, 4 |
| QuarterName | VARCHAR(10) | No | Quarter with prefix | "Q1", "Q2" |
| YearQuarter | VARCHAR(10) | No | Year and quarter combined | "2016-Q1" |
| Month | INT | No | Month number (1-12) | 1, 2, ..., 12 |
| MonthName | NVARCHAR(20) | No | Full month name | "January", "February" |
| MonthNameShort | NVARCHAR(10) | No | Abbreviated month | "Jan", "Feb" |
| YearMonth | VARCHAR(10) | No | Year and month (YYYY-MM) | "2016-02" |
| YearMonthName | VARCHAR(20) | No | Year and month name | "2016 February" |
| Day | INT | No | Day of month (1-31) | 1, 15, 28 |
| DayOfWeek | INT | No | Day of week (1=Monday, 7=Sunday) | 1, 2, ..., 7 |
| DayName | NVARCHAR(20) | No | Full day name | "Monday", "Tuesday" |
| DayNameShort | NVARCHAR(10) | No | Abbreviated day | "Mon", "Tue" |
| DayOfYear | INT | No | Day number in year (1-366) | 1, 100, 365 |
| WeekOfYear | INT | No | Week number in year (1-53) | 1, 26, 52 |
| WeekOfMonth | INT | No | Week number in month (1-5) | 1, 2, 3 |
| FiscalYear | INT | No | Fiscal year (starts April) | 2016, 2023 |
| FiscalQuarter | INT | No | Fiscal quarter (1-4) | 1, 2, 3, 4 |
| FiscalMonth | INT | No | Fiscal month (1-12) | 1, 6, 12 |
| Hour | INT | No | Hour of day (0-23) | 0, 14, 23 |
| TimeOfDay | VARCHAR(20) | No | Period of day | "Morning", "Afternoon", "Evening", "Night" |
| IsWeekend | BIT | No | Is Saturday or Sunday | 0, 1 |
| IsWorkingDay | BIT | No | Not weekend and not holiday | 0, 1 |
| IsCurrentMonth | BIT | No | Is current month | 0, 1 |
| IsCurrentYear | BIT | No | Is current year | 0, 1 |
| CreatedDate | DATETIME | No | Record creation timestamp | 2025-11-13 09:00:00 |

#### Business Rules
- **DayOfWeek:** 1 = Monday, 7 = Sunday (ISO 8601)
- **TimeOfDay:** Morning (6-12), Afternoon (12-18), Evening (18-22), Night (22-6)
- **FiscalYear:** Starts April 1st
- **IsWorkingDay:** TRUE if NOT (IsWeekend OR IsHoliday)

#### Indexes
- Clustered: DateKey (PK)
- Non-Clustered: Date, (Year, Month), (Year, Quarter)

---

### Dim_Customer

**Schema:** DW
**Purpose:** Customer demographic and profile information with location history
**Type:** Slowly Changing Dimension (Type 2 for Location)
**Rows:** 1,169,677 total | 884,225 current (IsCurrent=1)
**Grain:** One row per customer per location change
**SCD Type:** Type 2 (Location), Type 1 (Age, Gender)
**Snowflake note:** This dimension joins to `Dim_Location` via `LocationKey` — the one dimension-to-dimension link in this model (see ER-Diagram.md for rationale)

#### Columns

| Column Name | Data Type | Nullable | Description | Sample Values | SCD Type |
|-------------|-----------|----------|-------------|---------------|----------|
| **CustomerKey** | INT | No | Primary key (surrogate) | 1, 2, 1000000 | - |
| CustomerID | VARCHAR(50) | No | Business key (stable across versions) | "C5841053" | Fixed |
| DateOfBirth | DATE | **Yes** | Customer's birth date — NULL if unparseable/out of range | 1994-10-01, NULL | Type 1 |
| Age | INT | **Yes** | Current age (calculated) — NULL if DateOfBirth is NULL | 29, 66, NULL | Type 1 |
| AgeGroup | VARCHAR(20) | No | Age range category | "18-25", "26-35", "56+", "Unknown" | Type 1 |
| Gender | VARCHAR(10) | No | Customer gender | "Male", "Female", "Unknown" | Type 1 |
| **Location** | NVARCHAR(100) | No | **Customer location (SCD Type 2)** | "MUMBAI", "DELHI" | **Type 2** |
| LocationKey | INT | Yes | Foreign key to Dim_Location (snowflake link) | 1, 25, 100 | Type 2 |
| CustomerType | VARCHAR(20) | No | New or existing customer | "New", "Existing" | Type 1 |
| FirstTransactionDate | DATE | Yes | Date of very first transaction | 2015-01-05 | Fixed |
| **StartDate** | DATE | No | **SCD: Version effective start date** | 2015-01-01 | SCD |
| **EndDate** | DATE | Yes | **SCD: Version effective end date (NULL=current)** | 2016-03-14, NULL | SCD |
| **IsCurrent** | BIT | No | **SCD: Is this the current version?** | 0, 1 | SCD |
| CreatedDate | DATETIME | No | Record creation timestamp | 2025-11-13 10:00:00 | Audit |
| ModifiedDate | DATETIME | Yes | Record last modified timestamp | NULL | Audit |

#### Data Quality: DateOfBirth

A bug in the original `usp_Load_Dim_Customer` used `TRY_CAST` with an `ISNULL(..., '1900-01-01')` fallback, which silently converted unparseable dates into a fabricated 1900-01-01 (or, for some Python-generated source values, 1800-01-01) instead of NULL. This produced 629,803 + 64,351 = 694,154 customers with invalid 126+ year ages.

**Fix applied** in `13-Create-SP-Load-Dim-Customer.sql`:
```sql
CASE
    WHEN TRY_CONVERT(date, NULLIF(DOB, 'nan'), 103) IS NULL          THEN NULL
    WHEN YEAR(TRY_CONVERT(date, NULLIF(DOB, 'nan'), 103)) < 1930     THEN NULL
    WHEN YEAR(TRY_CONVERT(date, NULLIF(DOB, 'nan'), 103)) > 2005     THEN NULL
    ELSE TRY_CONVERT(date, NULLIF(DOB, 'nan'), 103)
END
```

**Result after fix:**

| DOB Category | Row Count |
|---|---|
| Valid (1930–2005) | 472,371 |
| NULL (Unknown) | 697,306 |

**Design decision:** Invalid DOBs are kept as NULL (AgeGroup = "Unknown") rather than imputed with random plausible values — preserves an honest, auditable data quality signal for the portfolio rather than fabricating demographic data.

#### SCD Type 2 Volume (Actual)

| Versions per Customer | Customer Count |
|-----------------------|---------------|
| 1 (never moved) | 640,829 |
| 2 | 205,593 |
| 3 | 33,879 |
| 4 | 3,609 |
| 5 | 301 |
| 6 | 14 |

#### Business Rules
- **AgeGroup:** 18-25 / 26-35 / 36-45 / 46-55 / 56+ / Unknown (if Age is NULL)
- **CustomerType:** New if FirstTransactionDate within 90 days, else Existing
- **SCD Join Pattern:** `CustomerID = ? AND TransactionDate BETWEEN StartDate AND ISNULL(EndDate, '9999-12-31')` — superseded in ETL by direct `(CustomerID, Location)` key match (see Fact_Transaction notes)

---

### Dim_Location

**Schema:** DW
**Purpose:** Geographic location reference
**Type:** Standard dimension (Type 1)
**Rows:** 9,354 (loaded via Package 2)
**Grain:** One row per unique location
**SCD Type:** Type 1 (Overwrite)

#### Columns

| Column Name | Data Type | Nullable | Description | Sample Values |
|-------------|-----------|----------|-------------|---------------|
| **LocationKey** | INT | No | Primary key (surrogate) | 1, 2, 9354 |
| LocationCode | NVARCHAR(100) | No | Normalized location code (BK) | "MUMBAI", "NAVI_MUMBAI" |
| LocationName | NVARCHAR(100) | No | Full location name | "MUMBAI", "NAVI MUMBAI" |
| City | NVARCHAR(100) | Yes | City name | "MUMBAI", "DELHI" |
| State | NVARCHAR(100) | Yes | State/province name | "Maharashtra", "Unknown" |
| Country | NVARCHAR(50) | No | Country name | "India" |
| Region | NVARCHAR(50) | Yes | Geographic region | "West", "North", "Unknown" |
| Latitude | DECIMAL(10,7) | Yes | Geographic latitude (future use) | NULL |
| Longitude | DECIMAL(10,7) | Yes | Geographic longitude (future use) | NULL |
| LocationType | NVARCHAR(50) | Yes | Classification | "City" |
| CreatedDate | DATETIME | No | Record creation timestamp | 2025-11-29 10:00:00 |
| ModifiedDate | DATETIME | Yes | Record last modified timestamp | NULL |

#### Notes
- Row count is 9,354 (higher than original 9,021) due to location migration simulation in Python augmentation — 243,376 customers changed cities, generating new location records
- 99.7% of locations have State/Region = "Unknown" — only 23 major cities were enriched via lookup
- LocationCode formula: `UPPER(REPLACE(LocationName, ' ', '_'))`
- This is the target of the model's one snowflake relationship (`Dim_Customer.LocationKey → Dim_Location.LocationKey`)

---

### Dim_Segment

**Schema:** DW
**Purpose:** Customer segmentation rules (RF-based)
**Type:** Configuration dimension
**Rows:** 7 (pre-defined RF segments)
**Grain:** One row per segment definition
**SCD Type:** Type 2 (for rule changes)

#### Columns

| Column Name | Data Type | Nullable | Description | Sample Values |
|-------------|-----------|----------|-------------|---------------|
| **SegmentKey** | INT | No | Primary key (surrogate) | 1, 2, 7 |
| SegmentCode | VARCHAR(50) | No | Segment identifier code | "RF_Champions", "RF_Churned" |
| SegmentName | NVARCHAR(100) | No | Display name | "Champions", "At Risk" |
| SegmentType | VARCHAR(50) | No | Type of segmentation | "RF" |
| Description | NVARCHAR(500) | Yes | Segmentation logic description | "High frequency, low recency" |
| RecencyMin | INT | Yes | Minimum recency (days) | 0, 60, 91 |
| RecencyMax | INT | Yes | Maximum recency (days) | 59, 90, 9999 |
| FrequencyMin | INT | Yes | Minimum frequency (transactions) | 0, 5, 15 |
| FrequencyMax | INT | Yes | Maximum frequency (transactions) | 4, 14, 9999 |
| DisplayOrder | INT | No | UI sort order | 1, 2, 7 |
| Color | VARCHAR(20) | Yes | Hex color for visualization | "#28A745", "#DC3545" |
| IsActive | BIT | No | Is segment active? | 0, 1 |
| StartDate | DATE | No | Rule effective date | 2026-06-01 |
| EndDate | DATE | Yes | Rule expiration date (NULL=active) | NULL |
| CreatedDate | DATETIME | No | Record creation timestamp | 2026-06-01 |
| ModifiedDate | DATETIME | Yes | Record last modified timestamp | NULL |

#### Segment Definitions (Exhaustive & Non-overlapping)

| SegmentKey | SegmentCode | SegmentName | RecencyMin | RecencyMax | FrequencyMin | FrequencyMax |
|------------|-------------|-------------|-----------|-----------|-------------|-------------|
| 1 | RF_Champions | Champions | 0 | 59 | 15 | 9999 |
| 2 | RF_Loyal | Loyal Customers | 0 | 59 | 8 | 14 |
| 3 | RF_Potential | Potential Loyalists | 0 | 59 | 5 | 7 |
| 4 | RF_New | New Customers | 0 | 30 | 0 | 4 |
| 5 | RF_AtRisk | At Risk | 60 | 90 | 5 | 9999 |
| 6 | RF_Hibernating | Hibernating | 31 | 90 | 0 | 4 |
| 7 | RF_Churned | Churned | 91 | 9999 | 0 | 9999 |

> **Design note:** Ranges were redesigned from the original spec to eliminate gaps and overlaps across the full Recency × Frequency space, verified programmatically before deployment. The original design had uncovered zones (e.g. Recency 31–59 with Frequency 0–4) which caused FK violations during Package 5 load — every customer-month combination must map to exactly one segment.

---

## Fact Tables

### Fact_Transaction

**Schema:** DW
**Purpose:** Transaction-level detail for granular analysis
**Type:** Transaction fact table
**Rows:** 147,290,230 (loaded via Package 4 — 00:24:09)
**Grain:** One row per transaction
**Date Range:** 2015-01-01 to 2016-08-31

#### Columns

| Column Name | Data Type | Nullable | Description | Sample Values | Measure Type |
|-------------|-----------|----------|-------------|---------------|--------------|
| **TransactionKey** | BIGINT | No | Primary key (surrogate) | 1, 1000000 | - |
| CustomerKey | INT | No | FK to Dim_Customer (SCD-aware) | 1, 50000 | Dimension |
| DateKey | INT | No | FK to Dim_Date | 20160208 | Dimension |
| LocationKey | INT | Yes | FK to Dim_Location | 1, 100 | Dimension |
| TransactionID | VARCHAR(50) | No | Business key (degenerate dimension) | "T1", "T1000000" | Degenerate |
| TransactionAmount | DECIMAL(18,2) | No | Transaction amount (INR) | 25.00, 27999.00 | Additive |
| AccountBalance | DECIMAL(18,2) | No | Account balance after transaction | 17819.05, 2270.69 | Semi-Additive |
| TransactionCount | INT | No | Always 1 (for COUNT aggregation) | 1 | Additive |
| ETLLoadDate | DATETIME | No | ETL load timestamp | 2026-06-01 14:00:00 | Audit |
| ETLBatchID | INT | Yes | ETL batch identifier | 1 | Audit |

#### ETL Notes
- **Critical:** Date parsing uses `TRY_CONVERT(date, TransactionDate, 103)` — style 103 required because server DATEFORMAT=mdy. Using `TRY_CAST` silently dropped ~60% of records (days ≥ 13 parsed as NULL) in early runs.
- **SCD Join:** CustomerKey resolved by matching `(CustomerID, CustLocation)` to `Dim_Customer` — avoids duplicate rows for customers with A→B→A location history that a date-range BETWEEN join produced.
- **Not imported into SSAS Tabular** — pre-aggregated into Fact_CustomerSnapshot instead.

---

### Fact_CustomerSnapshot

**Schema:** DW
**Purpose:** Monthly aggregated customer metrics for trend analysis
**Type:** Periodic snapshot fact table
**Rows:** 13,051,115 (loaded via Package 5 — 00:10:02)
**Grain:** One row per customer per month
**Date Range:** 2015-01-31 to 2016-08-31

#### Columns

| Column Name | Data Type | Nullable | Description | Sample Values | Measure Type |
|-------------|-----------|----------|-------------|---------------|--------------|
| **SnapshotKey** | BIGINT | No | Primary key (surrogate) | 1, 100000 | - |
| CustomerKey | INT | No | FK to Dim_Customer (current version) | 1, 50000 | Dimension |
| DateKey | INT | No | FK to Dim_Date (last day of month) | 20160831 | Dimension |
| SegmentKey | INT | Yes | FK to Dim_Segment | 1, 4, 7 | Dimension |
| TransactionCount | INT | No | Number of transactions in month | 0, 5, 20 | Additive |
| TotalTransactionAmount | DECIMAL(18,2) | No | Sum of transaction amounts | 0.00, 5000.00 | Additive |
| AvgTransactionAmount | DECIMAL(18,2) | Yes | Average transaction amount | NULL, 250.00 | Non-Additive |
| MinTransactionAmount | DECIMAL(18,2) | Yes | Minimum transaction amount | NULL, 10.00 | Non-Additive |
| MaxTransactionAmount | DECIMAL(18,2) | Yes | Maximum transaction amount | NULL, 2000.00 | Non-Additive |
| DaysSinceLastTransaction | INT | Yes | Recency: days from last txn to month-end | 5, 45, 120 | Non-Additive |
| RecencyScore | INT | Yes | Recency score (1-5) | 1, 3, 5 | Non-Additive |
| FrequencyScore | INT | Yes | Frequency score (0-5) | 0, 3, 5 | Non-Additive |
| LoyaltyScore | DECIMAL(5,2) | Yes | Combined RF score: (R×0.3)+(F×0.7) | 1.00, 3.50, 5.00 | Non-Additive |
| SatisfactionScore | DECIMAL(3,2) | Yes | Satisfaction (1-5) — Synthetic | 1.50, 3.75, 5.00 | Non-Additive |
| ComplaintFlag | BIT | No | Has complaint in month — Synthetic | 0, 1 | Additive |
| ChurnFlag | BIT | No | Is churned (DaysSince > 90) | 0, 1 | Additive |
| AtRiskFlag | BIT | No | At risk (60 < DaysSince ≤ 90) | 0, 1 | Additive |
| TrendCategory | VARCHAR(20) | Yes | Growth trend classification | "Strong Growth", "Churned" | Categorical |
| PreviousMonthTransactionCount | INT | Yes | Transaction count in prior month | NULL, 5, 8 | Non-Additive |
| GrowthRate | DECIMAL(5,2) | Yes | % change vs previous month — stored pre-scaled (25.00 = 25%, not 0.25) | -30.00, 0.00, 25.00 | Non-Additive |
| FinalAccountBalance | DECIMAL(18,2) | Yes | Account balance at month-end (carried forward) | 5000.00, 15000.00 | Semi-Additive |
| ETLLoadDate | DATETIME | No | ETL load timestamp | 2026-06-01 15:00:00 | Audit |
| ETLBatchID | INT | Yes | ETL batch identifier | 1 | Audit |

#### Calculated Measures (computed in `usp_Merge_CalculateRF` / `usp_Calculate_BusinessMetrics`)

**Recency Score:** ≤30→5, 31-60→4, 61-90→3, 91-180→2, >180→1
**Frequency Score:** ≥15→5, 10-14→4, 5-9→3, 2-4→2, 1→1, 0→0
**Loyalty Score:** `(RecencyScore × 0.3) + (FrequencyScore × 0.7)`
**Satisfaction Score (Synthetic):** R≥4 & F≥4 → Random(4.0,5.0); R≤2 & F≤2 → Random(1.0,2.5); else Random(2.5,4.0)
**Complaint Flag (Synthetic):** GrowthRate < -30% → 70% probability of 1
**Trend Category:** Churned / New / Strong Growth (>20%) / Moderate Growth (>5%) / Stable (±5%) / Moderate Decline (≥-20%) / Sharp Decline (<-20%)

#### Verified Results (Jun 2026)

| Metric | Value |
|--------|-------|
| Total rows | 13,051,115 |
| Latest month (Aug 2016) ChurnRate | 15.76% |
| Latest month AtRiskRate | 1.00% |
| Customers in latest month | 831,639 |

---

## SSAS Tabular Layer

**Model:** BankingLoyaltyChurn (Compatibility Level 1600)
**Tables imported:** Dim_Date, Dim_Customer (filtered IsCurrent=1 at source), Dim_Location, Dim_Segment, Fact_CustomerSnapshot
**Fact_Transaction is not imported** — all reporting metrics are pre-aggregated in Fact_CustomerSnapshot.

### Column Renaming
All columns renamed with spaces for report-friendly display (e.g. `CustomerKey` → `Customer Key`, `ChurnFlag` → `Churn Flag`, `GrowthRate` → `Growth Rate`). DAX formulas in `Measures.txt` reference these spaced names.

### Calculated Columns Added in SSAS

| Table | Column | Logic |
|---|---|---|
| Dim_Date | MonthLabel | `FORMAT(Date, "MMM-YY")` |
| Dim_Date | MonthSort | `Year * 100 + Month Number` |
| Fact_CustomerSnapshot | RecencyBucket | Bands: 0-30 / 31-60 / 61-90 / 91-180 / 180+ days |
| Fact_CustomerSnapshot | LoyaltyBand | High (≥4.0) / Medium (≥2.5) / Low (<2.5) |
| Fact_CustomerSnapshot | GrowthCategory | Churned / Growing (>20%) / Declining (<-20%) / Stable |

### DAX Measures: 39 total across 7 Display Folders
Full formula listing in `06-SSAS-Tabular/Measures.txt`. Key pattern used throughout: every measure anchors to `[_LastDataDateKey]` (= `MAX(Fact_CustomerSnapshot[DateKey])`), never to `Dim_Date` directly, since `Dim_Date` extends to 2030 while real data ends 2016-08-31.

### Known DAX Pitfalls (documented for reuse)
1. `DATEADD()` nested inside `CALCULATETABLE()` with a same-table date filter loses its traversal context → "no current row" errors. Fix: resolve the target date to a scalar via `CALCULATE(MAX(...))` + `EOMONTH()` first, then filter directly.
2. `GrowthRate` is stored pre-scaled as a percentage (25.00 = 25%) — measures using `Percentage` format must divide by 100 in the formula, or the value displays 100× too large.

---

## Standard Columns

| Column | Type | Tables | Description |
|--------|------|--------|-------------|
| CreatedDate | DATETIME | All | Record creation timestamp (DEFAULT GETDATE()) |
| ModifiedDate | DATETIME | Dims | Last modification timestamp (NULL if never modified) |
| ETLLoadDate | DATETIME | Facts | ETL process execution timestamp |
| ETLBatchID | INT | Facts | ETL batch identifier |

---

## Code Values

### Gender
- `Male` / `Female`: Standard values
- `Unknown`: Not specified or data quality issue

### CustomerType
- `New`: FirstTransactionDate within 90 days
- `Existing`: FirstTransactionDate more than 90 days ago

### AgeGroup
- `18-25` / `26-35` / `36-45` / `46-55` / `56+`: Standard bands
- `Unknown`: DateOfBirth is NULL (unparseable or out-of-range source value)

### TimeOfDay
- `Morning`: 06:00–11:59
- `Afternoon`: 12:00–17:59
- `Evening`: 18:00–21:59
- `Night`: 22:00–05:59

### TrendCategory
- `Strong Growth`: GrowthRate > 20%
- `Moderate Growth`: 5% < GrowthRate ≤ 20%
- `Stable`: |GrowthRate| ≤ 5%
- `Moderate Decline`: -20% ≤ GrowthRate < -5%
- `Sharp Decline`: GrowthRate < -20%
- `Churned`: ChurnFlag = 1
- `New`: No previous month data

### SegmentType
- `RF`: Recency-Frequency based segmentation

---

## Data Lineage

```
bank_transactions.csv (original seed — 1.05M records, ~55 days)
    ↓ Python generate_transactions_v3_3.py
BankingSource.dbo.RawTransactions (147,290,230 records, 20 months)
    ↓ Package 1 (SSIS)
BankingStaging.dbo.Stg_Customer / Stg_Transaction / Stg_Location
    ↓ Package 2       ↓ Package 3        ↓ Package 4
DW.Dim_Location   DW.Dim_Customer    DW.Fact_Transaction
                                           ↓ Package 5 (5-SP pipeline)
                                   DW.Fact_CustomerSnapshot
                                           ↓ Import
                                   SSAS Tabular (BankingLoyaltyChurn)
                                           ↓ Phase 7
                                   Power BI Dashboards
```

---

**Document Version:** 1.3
**Last Updated:** June 2026
**Status:** ✅ ETL + SSAS Tabular Complete — Proceeding to Phase 7 (Power BI)
