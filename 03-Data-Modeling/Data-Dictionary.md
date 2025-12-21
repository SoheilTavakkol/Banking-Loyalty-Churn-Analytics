# Data Dictionary
## Banking Customer Loyalty & Churn Analysis Data Warehouse

**Version:** 1.0  
**Last Updated:** November 2025

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
3. [Standard Columns](#standard-columns)
4. [Code Values](#code-values)

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

| Column Name | Data Type | Nullable | Default | Description | Sample Values |
|-------------|-----------|----------|---------|-------------|---------------|
| **DateKey** | INT | No | - | Primary key (YYYYMMDD format) | 20160208, 20230715 |
| FullDateTime | DATETIME | No | - | Complete date and time | 2016-02-08 14:32:07 |
| Date | DATE | No | - | Date portion only | 2016-02-08 |
| Year | INT | No | - | Year (4-digit) | 2016, 2023 |
| YearName | VARCHAR(10) | No | - | Year as string | "2016", "2023" |
| Quarter | INT | No | - | Quarter of year (1-4) | 1, 2, 3, 4 |
| QuarterName | VARCHAR(10) | No | - | Quarter with prefix | "Q1", "Q2", "Q3", "Q4" |
| YearQuarter | VARCHAR(10) | No | - | Year and quarter combined | "2016-Q1", "2023-Q3" |
| Month | INT | No | - | Month number (1-12) | 1, 2, ..., 12 |
| MonthName | NVARCHAR(20) | No | - | Full month name | "January", "February" |
| MonthNameShort | NVARCHAR(10) | No | - | Abbreviated month | "Jan", "Feb" |
| YearMonth | VARCHAR(10) | No | - | Year and month (YYYY-MM) | "2016-02", "2023-07" |
| YearMonthName | VARCHAR(20) | No | - | Year and month name | "2016 February" |
| Day | INT | No | - | Day of month (1-31) | 1, 15, 28 |
| DayOfWeek | INT | No | - | Day of week (1=Monday, 7=Sunday) | 1, 2, ..., 7 |
| DayName | NVARCHAR(20) | No | - | Full day name | "Monday", "Tuesday" |
| DayNameShort | NVARCHAR(10) | No | - | Abbreviated day | "Mon", "Tue" |
| DayOfYear | INT | No | - | Day number in year (1-366) | 1, 100, 365 |
| WeekOfYear | INT | No | - | Week number in year (1-53) | 1, 26, 52 |
| WeekOfMonth | INT | No | - | Week number in month (1-5) | 1, 2, 3, 4, 5 |
| FiscalYear | INT | No | - | Fiscal year (starts April) | 2016, 2023 |
| FiscalQuarter | INT | No | - | Fiscal quarter (1-4) | 1, 2, 3, 4 |
| FiscalMonth | INT | No | - | Fiscal month (1-12) | 1, 6, 12 |
| Time | TIME | No | - | Time portion | 14:32:07, 00:00:00 |
| Hour | INT | No | - | Hour of day (0-23) | 0, 14, 23 |
| HourName | VARCHAR(10) | No | - | Hour with format (HH:00) | "00:00", "14:00" |
| Minute | INT | No | - | Minute (0-59) | 0, 32, 59 |
| TimeOfDay | VARCHAR(20) | No | - | Period of day | "Morning", "Afternoon", "Evening", "Night" |
| IsWeekend | BIT | No | 0 | Is Saturday or Sunday | 0, 1 |
| IsHoliday | BIT | No | 0 | Is public holiday (future use) | 0, 1 |
| IsWorkingDay | BIT | No | - | Not weekend and not holiday | 0, 1 |
| IsToday | BIT | No | 0 | Is current date | 0, 1 |
| IsYesterday | BIT | No | 0 | Is yesterday | 0, 1 |
| IsCurrentMonth | BIT | No | 0 | Is current month | 0, 1 |
| IsCurrentQuarter | BIT | No | 0 | Is current quarter | 0, 1 |
| IsCurrentYear | BIT | No | 0 | Is current year | 0, 1 |
| CreatedDate | DATETIME | No | GETDATE() | Record creation timestamp | 2025-11-13 09:00:00 |

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
**Purpose:** Customer demographic and profile information  
**Type:** Slowly Changing Dimension (Type 2 for Location)  
**Rows:** 884,265 (loaded via Package 3)  
**Grain:** One row per customer per location change  
**SCD Type:** Type 2 (Location), Type 1 (Age, Gender)
**Status:** ✅ Loaded - No location changes yet (all IsCurrent=1)

#### Columns

| Column Name | Data Type | Nullable | Default | Description | Sample Values | SCD Type |
|-------------|-----------|----------|---------|-------------|---------------|----------|
| **CustomerKey** | INT | No | Identity | Primary key (surrogate) | 1, 2, 1000000 | - |
| CustomerID | VARCHAR(50) | No | - | Business key (stable across versions) | "C5841053", "C2142763" | Fixed |
| DateOfBirth | DATE | No | - | Customer's birth date | 1994-10-01, 1957-04-04 | Type 1 |
| Age | INT | No | - | Current age (calculated) | 29, 66 | Type 1 |
| AgeGroup | VARCHAR(20) | No | - | Age range category | "18-25", "26-35", "56+" | Type 1 |
| Gender | VARCHAR(10) | No | - | Customer gender | "Male", "Female", "Unknown" | Type 1 |
| **Location** | NVARCHAR(100) | No | - | **Customer location (SCD Type 2)** | "MUMBAI", "DELHI" | **Type 2** |
| LocationKey | INT | Yes | NULL | Foreign key to Dim_Location | 1, 25, 100 | Type 2 |
| CustomerType | VARCHAR(20) | No | - | New or existing customer | "New", "Existing" | Type 1 |
| FirstTransactionDate | DATE | Yes | NULL | Date of very first transaction | 2016-01-05, 2016-08-12 | Fixed |
| **StartDate** | DATE | No | - | **SCD: Version effective start date** | 2020-01-01, 2023-07-15 | SCD |
| **EndDate** | DATE | Yes | NULL | **SCD: Version effective end date (NULL=current)** | 2023-07-14, NULL | SCD |
| **IsCurrent** | BIT | No | 1 | **SCD: Is this the current version?** | 0, 1 | SCD |
| CreatedDate | DATETIME | No | GETDATE() | Record creation timestamp | 2025-11-13 10:00:00 | Audit |
| ModifiedDate | DATETIME | Yes | NULL | Record last modified timestamp | NULL, 2023-07-15 10:30:00 | Audit |

#### Business Rules
- **AgeGroup Calculation:**
  - 18-25: Age between 18 and 25
  - 26-35: Age between 26 and 35
  - 36-45: Age between 36 and 45
  - 46-55: Age between 46 and 55
  - 56+: Age 56 or above

- **SCD Type 2 Logic:**
  - When Location changes, create new row with:
    - New CustomerKey (surrogate)
    - Same CustomerID (business key)
    - New Location value
    - StartDate = change date
    - EndDate = NULL
    - IsCurrent = 1
  - Update old row:
    - EndDate = change date - 1
    - IsCurrent = 0

- **CustomerType:**
  - New: FirstTransactionDate within 90 days
  - Existing: FirstTransactionDate > 90 days ago

#### Indexes
- Clustered: CustomerKey (PK)
- Non-Clustered: CustomerID, (CustomerID, IsCurrent) WHERE IsCurrent=1
- Non-Clustered: AgeGroup, Gender

---

### Dim_Location

**Schema:** DW  
**Purpose:** Geographic location reference  
**Type:** Standard dimension  
**Rows:** 9,021 (loaded)  
**Grain:** One row per unique location  
**SCD Type:** Type 1 (Overwrite)  
**Status:** ✅ Loaded via Package 2

#### Columns

| Column Name | Data Type | Nullable | Default | Description | Sample Values |
|-------------|-----------|----------|---------|-------------|---------------|
| **LocationKey** | INT | No | Identity | Primary key (surrogate) | 1, 2, 9021 |
| LocationCode | NVARCHAR(100) | No | - | Normalized location code (unique, BK) | "MUMBAI", "NAVI_MUMBAI" |
| LocationName | NVARCHAR(100) | No | - | Full location name | "MUMBAI", "NAVI MUMBAI" |
| City | NVARCHAR(100) | Yes | NULL | City name (same as LocationName) | "MUMBAI", "DELHI" |
| State | NVARCHAR(100) | Yes | NULL | State/province name | "Maharashtra", "Delhi", "Unknown" |
| Country | NVARCHAR(50) | No | 'India' | Country name | "India" |
| Region | NVARCHAR(50) | Yes | NULL | Geographic region | "West", "North", "South", "Unknown" |
| Latitude | DECIMAL(10,7) | Yes | NULL | Geographic latitude (future use) | NULL |
| Longitude | DECIMAL(10,7) | Yes | NULL | Geographic longitude (future use) | NULL |
| LocationType | NVARCHAR(50) | Yes | NULL | Classification | "City" |
| CreatedDate | DATETIME | No | GETDATE() | Record creation timestamp | 2025-11-29 10:00:00 |
| ModifiedDate | DATETIME | Yes | NULL | Record last modified timestamp | NULL |

#### Data Enrichment Strategy

**Reference Table:** ETL.City_Lookup (23 major Indian cities)

**Enrichment Results:**
- **9,021 total locations** loaded
- **23 locations (0.3%)** enriched with State/Region from City_Lookup
- **8,998 locations (99.7%)** marked as State="Unknown", Region="Unknown"

**Major Cities Enriched:**
- Mumbai, Delhi, Bangalore, Pune, Chennai, Hyderabad, Kolkata
- Ahmedabad, Jaipur, Lucknow, Kanpur, Nagpur, Indore, Thane
- Bhopal, Visakhapatnam, Patna, Vadodara, Ghaziabad, Faridabad
- Rajamandry, Mohali

**Business Logic:**
- LocationCode: `UPPER(REPLACE(LocationName, ' ', '_'))`
- State/Region: Lookup from ETL.City_Lookup, else "Unknown"
- Country: "India" for all records
- LocationType: "City" for all records
- Latitude/Longitude: NULL (can be enriched in future phases)

#### Business Rules
- **LocationCode:** Business Key - `UPPER(REPLACE(LocationName, ' ', '_'))`
- **Country:** Defaults to "India" (expandable for international)
- **State/Region "Unknown":** Indicates location not in reference table (can be enriched later)
- **80/20 Rule Applied:** Focus on major cities first, mark rest for future enrichment

#### Indexes
- Clustered: LocationKey (PK)
- Non-Clustered: LocationCode (Unique)
- Non-Clustered: State, Region

#### Load History
- **Package 2:** Initial load of 9,021 locations (Nov 2025)
- **Runtime:** ~30 seconds
- **Source:** BankingStaging.dbo.Stg_Location

---

**ETL Notes:**
- Loaded via Package 2 - Load Dim_Location
- Unicode support (NVARCHAR) throughout
- Lookup transformation with "Ignore failure" for unmatched locations
- Explicit casting in SSIS: `(DT_WSTR,length)Expression`
---

### Dim_Segment

**Schema:** DW  
**Purpose:** Customer segmentation rules (RF-based)  
**Type:** Configuration dimension  
**Rows:** 7 (pre-defined RF segments)  
**Grain:** One row per segment definition  
**SCD Type:** Type 2 (for rule changes)

#### Columns

| Column Name | Data Type | Nullable | Default | Description | Sample Values |
|-------------|-----------|----------|---------|-------------|---------------|
| **SegmentKey** | INT | No | Identity | Primary key (surrogate) | 1, 2, 7 |
| SegmentCode | VARCHAR(50) | No | - | Segment identifier code | "RF_Champions", "RF_Churned" |
| SegmentName | NVARCHAR(100) | No | - | Display name | "Champions", "At Risk" |
| SegmentType | VARCHAR(50) | No | - | Type of segmentation | "RF", "Demographic", "Behavioral" |
| Description | NVARCHAR(500) | Yes | NULL | Segmentation logic description | "High frequency, low recency" |
| RecencyMin | INT | Yes | NULL | Minimum recency (days) | 0, 60, 90 |
| RecencyMax | INT | Yes | NULL | Maximum recency (days) | 30, 90, 9999 |
| FrequencyMin | INT | Yes | NULL | Minimum frequency (transactions) | 0, 5, 15 |
| FrequencyMax | INT | Yes | NULL | Maximum frequency (transactions) | 7, 15, 9999 |
| DisplayOrder | INT | No | 999 | UI sort order | 1, 2, 6 |
| Color | VARCHAR(20) | Yes | NULL | Hex color for visualization | "#28A745", "#DC3545" |
| IsActive | BIT | No | 1 | Is segment active? | 0, 1 |
| StartDate | DATE | No | CURRENT_DATE | Rule effective date | 2025-01-01 |
| EndDate | DATE | Yes | NULL | Rule expiration date (NULL=active) | NULL, 2025-12-31 |
| CreatedDate | DATETIME | No | GETDATE() | Record creation timestamp | 2025-11-13 12:00:00 |
| ModifiedDate | DATETIME | Yes | NULL | Record last modified timestamp | NULL |

#### Pre-defined Segments

| SegmentKey | SegmentCode | SegmentName | RecencyMin | RecencyMax | FrequencyMin | FrequencyMax | DisplayOrder |
|------------|-------------|-------------|------------|------------|--------------|--------------|--------------|
| 1 | RF_Champions | Champions | 0 | 30 | 15 | 9999 | 1 |
| 2 | RF_Loyal | Loyal Customers | 0 | 60 | 8 | 14 | 2 |
| 3 | RF_Potential | Potential Loyalists | 0 | 45 | 5 | 7 | 3 |
| 4 | RF_AtRisk | At Risk | 60 | 90 | 5 | 15 | 4 |
| 5 | RF_Hibernating | Hibernating | 60 | 90 | 0 | 4 | 5 |
| 6 | RF_Churned | Churned | 90 | 9999 | 0 | 9999 | 6 |
| 7 | RF_New | New Customers | 0 | 30 | 0 | 9999 | 7 |

#### Business Rules
- **Segment Assignment:** Customer matches if Recency and Frequency fall within Min/Max ranges
- **Priority:** If multiple segments match, use lowest DisplayOrder
- **IsActive:** Only active segments (IsActive=1) are used for assignment

#### Indexes
- Clustered: SegmentKey (PK)
- Non-Clustered: SegmentCode, SegmentType, IsActive WHERE IsActive=1

---

## Fact Tables

### Fact_Transaction

**Schema:** DW  
**Purpose:** Transaction-level detail for granular analysis  
**Type:** Transaction fact table  
**Rows:** 154,777,534 (loaded via Package 4)  
**Grain:** One row per transaction  
**Load Frequency:** Daily (incremental)
**Date Range:** 2015-01-01 to 2016-08-31 (20 months)
**Status:** ✅ Loaded

#### Columns

| Column Name | Data Type | Nullable | Default | Description | Sample Values | Measure Type |
|-------------|-----------|----------|---------|-------------|---------------|--------------|
| **TransactionKey** | BIGINT | No | Identity | Primary key (surrogate) | 1, 1000000 | - |
| CustomerKey | INT | No | - | Foreign key to Dim_Customer (SCD aware) | 1, 50000 | Dimension |
| DateKey | INT | No | - | Foreign key to Dim_Date | 20160208, 20230715 | Dimension |
| LocationKey | INT | Yes | NULL | Foreign key to Dim_Location | 1, 100 | Dimension |
| TransactionID | VARCHAR(50) | No | - | Business key (degenerate dimension) | "T1", "T1000000" | Degenerate |
| TransactionAmount | DECIMAL(18,2) | No | - | Transaction amount in currency | 25.00, 27999.00 | Additive |
| AccountBalance | DECIMAL(18,2) | No | - | Account balance after transaction | 17819.05, 2270.69 | Semi-Additive |
| TransactionCount | INT | No | 1 | Always 1 (for COUNT aggregation) | 1 | Additive |
| ETLLoadDate | DATETIME | No | GETDATE() | ETL load timestamp | 2025-11-13 14:00:00 | Audit |
| ETLBatchID | INT | Yes | NULL | ETL batch identifier | 100, 250 | Audit |

#### Measure Descriptions
- **TransactionAmount:** Fully additive across all dimensions
- **AccountBalance:** Semi-additive (meaningful as AVG, not SUM)
- **TransactionCount:** Always 1, used for COUNT() aggregation

#### Business Rules
- **CustomerKey Lookup (SCD Type 2):**
  ```sql
  SELECT CustomerKey
  FROM Dim_Customer
  WHERE CustomerID = ?
    AND TransactionDate BETWEEN StartDate AND ISNULL(EndDate, '9999-12-31')
  ```
- **Negative Amounts:** Not allowed (validation in ETL)
- **Zero Amounts:** Allowed (e.g., balance inquiry transactions)

#### Indexes
- Clustered: TransactionKey (PK)
- Non-Clustered: CustomerKey, DateKey
- Covering: (CustomerKey, DateKey) INCLUDE (TransactionAmount, AccountBalance)
- Non-Clustered: TransactionID (for degenerate dimension lookups)

---

### Fact_CustomerSnapshot

**Schema:** DW  
**Purpose:** Monthly aggregated customer metrics for trend analysis  
**Type:** Periodic snapshot fact table  
**Rows:** 15,581,079 (loaded via Package 5)  
**Grain:** One row per customer per month  
**Load Frequency:** Monthly (full refresh for completed months)
**Coverage:** 884K customers × ~18 months average
**Date Range:** 2015-01-31 to 2016-08-31
**Status:** ✅ Loaded

#### Columns

| Column Name | Data Type | Nullable | Default | Description | Sample Values | Measure Type |
|-------------|-----------|----------|---------|-------------|---------------|--------------|
| **SnapshotKey** | BIGINT | No | Identity | Primary key (surrogate) | 1, 100000 | - |
| CustomerKey | INT | No | - | FK to Dim_Customer (current version) | 1, 50000 | Dimension |
| DateKey | INT | No | - | FK to Dim_Date (last day of month) | 20160229, 20230831 | Dimension |
| SegmentKey | INT | Yes | NULL | FK to Dim_Segment | 1, 4, 6 | Dimension |
| TransactionCount | INT | No | 0 | Number of transactions in month | 0, 5, 20 | Additive |
| TotalTransactionAmount | DECIMAL(18,2) | No | 0 | Sum of transaction amounts | 0.00, 5000.00 | Additive |
| AvgTransactionAmount | DECIMAL(18,2) | Yes | NULL | Average transaction amount | NULL, 250.00 | Non-Additive |
| MinTransactionAmount | DECIMAL(18,2) | Yes | NULL | Minimum transaction amount | NULL, 10.00 | Non-Additive |
| MaxTransactionAmount | DECIMAL(18,2) | Yes | NULL | Maximum transaction amount | NULL, 2000.00 | Non-Additive |
| DaysSinceLastTransaction | INT | Yes | NULL | Recency: days from last txn to month-end | 5, 45, 120 | Non-Additive |
| RecencyScore | INT | Yes | NULL | Recency score (1-5) | 1, 3, 5 | Non-Additive |
| FrequencyScore | INT | Yes | NULL | Frequency score (1-5) | 1, 3, 5 | Non-Additive |
| LoyaltyScore | DECIMAL(5,2) | Yes | NULL | Combined RF score: (R×0.3)+(F×0.7) | 1.00, 3.50, 5.00 | Non-Additive |
| SatisfactionScore | DECIMAL(3,2) | Yes | NULL | Satisfaction (1-5) - Synthetic | 1.50, 3.75, 5.00 | Non-Additive |
| ComplaintFlag | BIT | No | 0 | Has complaint in month - Synthetic | 0, 1 | Additive |
| ChurnFlag | BIT | No | 0 | Is churned (R>90 days) | 0, 1 | Additive |
| AtRiskFlag | BIT | No | 0 | At risk (60<R≤90 days) | 0, 1 | Additive |
| TrendCategory | VARCHAR(20) | Yes | NULL | Growth trend classification | "Strong Growth", "Churned" | Categorical |
| PreviousMonthTransactionCount | INT | Yes | NULL | Transaction count in prior month | NULL, 5, 8 | Non-Additive |
| GrowthRate | DECIMAL(5,2) | Yes | NULL | % change vs previous month | -30.00, 0.00, 25.00 | Non-Additive |
| FinalAccountBalance | DECIMAL(18,2) | Yes | NULL | Account balance at month-end | 5000.00, 15000.00 | Semi-Additive |
| ETLLoadDate | DATETIME | No | GETDATE() | ETL load timestamp | 2025-11-13 15:00:00 | Audit |
| ETLBatchID | INT | Yes | NULL | ETL batch identifier | 100, 250 | Audit |

#### Calculated Measures

**Recency Score:**
```
Days Since Last Transaction → Score
≤ 30                       → 5
31-60                      → 4
61-90                      → 3
91-180                     → 2
> 180                      → 1
```

**Frequency Score:**
```
Transaction Count → Score
≥ 15             → 5
10-14            → 4
5-9              → 3
2-4              → 2
0-1              → 1
```

**Loyalty Score:**
```
LoyaltyScore = (RecencyScore × 0.3) + (FrequencyScore × 0.7)
```

**Satisfaction Score (Synthetic):**
```
IF FrequencyScore > 3 AND RecencyScore > 3:
    Random(4.0, 5.0)
ELSE IF FrequencyScore < 2 AND RecencyScore < 2:
    Random(1.0, 2.5)
ELSE:
    Random(2.5, 4.0)
```

**Complaint Flag (Synthetic):**
```
IF GrowthRate < -30%:
    Random(0, 1) with 70% probability of 1
ELSE:
    0
```

**Trend Category:**
```
GrowthRate > 20%:  "Strong Growth"
5% < GrowthRate ≤ 20%: "Moderate Growth"
-5% ≤ GrowthRate ≤ 5%: "Stable"
-20% ≤ GrowthRate < -5%: "Moderate Decline"
GrowthRate < -20%: "Sharp Decline"
ChurnFlag = 1: "Churned"
```

#### Business Rules
- **Snapshot Date:** Always last day of month
- **Customer Version:** Links to current (IsCurrent=1) customer record
- **Segment Assignment:** Based on Recency and Frequency matching Dim_Segment rules
- **Growth Calculation:** Requires previous month data (NULL for first month)

#### Indexes
- Clustered: SnapshotKey (PK)
- Non-Clustered: CustomerKey, DateKey, SegmentKey
- Covering: (CustomerKey, DateKey) INCLUDE (LoyaltyScore, ChurnFlag)
- Filtered: ChurnFlag WHERE ChurnFlag=1
- Filtered: AtRiskFlag WHERE AtRiskFlag=1

---

## Standard Columns

All tables include these audit columns:

| Column | Type | Description |
|--------|------|-------------|
| CreatedDate | DATETIME | Record creation timestamp (DEFAULT GETDATE()) |
| ModifiedDate | DATETIME | Record last modification timestamp (NULL if never modified) |
| ETLLoadDate | DATETIME | ETL process execution timestamp (for fact tables) |
| ETLBatchID | INT | ETL batch identifier (for fact tables, optional) |

---

## Code Values

### Gender
- `M` or `Male`: Male
- `F` or `Female`: Female
- `Unknown`: Not specified or data quality issue

### CustomerType
- `New`: FirstTransactionDate within 90 days
- `Existing`: FirstTransactionDate more than 90 days ago

### TimeOfDay
- `Morning`: 06:00 - 11:59
- `Afternoon`: 12:00 - 17:59
- `Evening`: 18:00 - 21:59
- `Night`: 22:00 - 05:59

### TrendCategory
- `Strong Growth`: GrowthRate > 20%
- `Moderate Growth`: 5% < GrowthRate ≤ 20%
- `Stable`: -5% ≤ GrowthRate ≤ 5%
- `Moderate Decline`: -20% ≤ GrowthRate < -5%
- `Sharp Decline`: GrowthRate < -20%
- `Churned`: ChurnFlag = 1

### LocationType
- `Urban`: City location
- `Rural`: Village/countryside location
- `Metro`: Metropolitan area

### SegmentType
- `RF`: Recency-Frequency based segmentation
- `Demographic`: Age, gender, location based
- `Behavioral`: Transaction pattern based

---

## Data Lineage

### Source → Staging → Dimension/Fact

```
CSV File (bank_transactions.xlsx)
    ↓
BankingSource.dbo.RawTransactions
    ↓
BankingStaging.dbo.Stg_Customer
BankingStaging.dbo.Stg_Transaction
BankingStaging.dbo.Stg_Location
    ↓
BankingDW.DW.Dim_Customer (SCD Type 2)
BankingDW.DW.Dim_Location
BankingDW.DW.Fact_Transaction
    ↓
BankingDW.DW.Fact_CustomerSnapshot (aggregation)
```

---

**Document Version:** 1.1  
- Last Updated: December 2025
- Status: ✅ Complete - All data loaded and validated
- ETL Status:
    ✅ Package 1: Staging loaded (155M records)
    ✅ Package 2: Dim_Location loaded (9,021 locations)
    ✅ Package 3: Dim_Customer loaded (884K customers)
    ✅ Package 4: Fact_Transaction loaded (154M transactions)
    ✅ Package 5: Fact_CustomerSnapshot loaded (15.6M snapshots)

- Review Frequency: Quarterly or after schema/ETL changes
- Next Review: Before Phase 7 (Power BI Dashboards)

