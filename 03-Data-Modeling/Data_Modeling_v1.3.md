# Data Model Design Document
## Banking Customer Loyalty & Churn Analysis Data Warehouse

**Version:** 1.3
**Date:** June 2026
**Author:** Soheil Tavakkol

---

## 1. Overview

### 1.1 Purpose
This document provides a comprehensive description of the dimensional data model designed for analyzing banking customer behavior, focusing on loyalty patterns and churn prediction.

### 1.2 Modeling Approach
- **Schema Type:** Star schema with one snowflaked dimension
- **Design Methodology:** Dimensional Modeling (Kimball)
- **SCD Strategy:** Type 2 for Customer Location changes

### 1.3 Implementation Status

✅ Phase 2: Physical schema created
✅ Phase 3: Model design documented
✅ Phase 5: All tables loaded and validated
    - Dimensions: 4 tables (1,184,882 total rows across all dims)
    - Facts: 2 tables (160.3M+ total rows)
    - ETL: 5 SSIS packages completed
✅ Phase 6: SSAS Tabular model deployed (39 DAX measures)
⏳ Phase 7: Power BI Dashboards (next)

### 1.4 Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Star schema with one snowflaked dimension | Simpler queries for most joins; the one snowflake (Customer→Location) avoids duplicating Location attributes across 1.17M customer rows |
| Integrated Date/Time Dimension | Reduces joins, sufficient for project scale |
| SCD Type 2 only for Location | Location is the only attribute that meaningfully changes over time |
| Separate Segment Dimension | Allows flexible segmentation rule changes without ETL modifications |
| Two Fact Tables | Transaction-level for detail, Snapshot for aggregated analysis |
| Fact_Transaction excluded from SSAS | Pre-aggregated in Fact_CustomerSnapshot — keeps the Tabular model lean for reporting workloads |
| KPI thresholds deferred to Power BI | SSAS native KPI status visuals don't render in Power BI; threshold logic is built as DAX measures in the final reporting layer instead |

---

## 2. Schema Architecture

### 2.1 High-Level Structure

```
                    Dim_Date
                    (5,844 rows)
                         |
                         |
    Dim_Customer --------+-------- Fact_Transaction
    (SCD Type 2)         |         (147.3M rows)
         |               |
         | (snowflake)   |
         v               |
    Dim_Location ---------+
    (9,354 rows)         |
                         |
    Dim_Segment ---------+-------- Fact_CustomerSnapshot
    (7 segments)                   (13.05M rows)
```

`Dim_Location` serves two roles: a direct star-join to `Fact_Transaction` (transaction location), and a snowflaked join from `Dim_Customer` (customer's registered location). This is the one place the model departs from a pure star schema.

### 2.2 Why Snowflake Customer→Location Instead of Denormalizing?

A pure star schema would push City/State/Region/Country/LocationType directly into `Dim_Customer`. This was rejected because:
- `Dim_Customer` has 1,169,677 rows (incl. SCD history) vs. `Dim_Location`'s 9,354 — denormalizing would duplicate location attributes ~125× over
- `Dim_Location` is independently useful for `Fact_Transaction` (which has its own, sometimes different, transaction location)
- Location attributes change far less frequently than customer records are created — keeping them separate avoids re-writing location data on every customer SCD version

### 2.3 Schema Benefits

**Query Performance:**
- Most queries are single-level joins (Fact → Dimension); the one snowflake hop (Customer → Location) is a small, indexed lookup table

**Maintainability:**
- Clear business concepts
- Straightforward ETL logic

**Scalability:**
- Easy to add new dimensions
- Segment rules can evolve independently

---

## 3. Dimension Tables

### 3.1 Dim_Date (Pre-populated Reference)

**Purpose:** Time dimension for all date/time-based analysis
**Grain:** One row per day (with integrated time attributes)

| Category | Attributes | Usage |
|----------|-----------|-------|
| **Date Hierarchies** | Year, Quarter, Month, Week, Day | Time-based slicing and grouping |
| **Day Classification** | DayOfWeek, IsWeekend, IsWorkingDay | Behavioral pattern analysis |
| **Fiscal Calendar** | FiscalYear, FiscalQuarter | Business reporting |
| **Relative Flags** | IsToday, IsCurrentMonth, IsCurrentYear | Dynamic filtering |
| **Time** | Hour, Minute, TimeOfDay | Intraday analysis |

**Special Features:**
- Pre-populated: 2015–2030 (5,844 records)
- No ETL required: static reference data
- **Critical for downstream use:** real data only spans 2015-01 to 2016-08 — any measure using `MAX(Dim_Date[Date])` without anchoring to actual fact data will incorrectly resolve to 2030-12-31

**Business Rules:**
- Weekend: Saturday or Sunday
- Working Day: NOT (Weekend OR Holiday)
- TimeOfDay: Morning (6-12), Afternoon (12-18), Evening (18-22), Night (22-6)

---

### 3.2 Dim_Location (Type 1)

**Purpose:** Geographic dimension for location-based analysis
**Grain:** One row per unique location
**SCD Type:** Type 1 (Overwrite)
**Role in schema:** Target of the one snowflake relationship in this model (joined from `Dim_Customer`), in addition to its direct star-join to `Fact_Transaction`

| Attribute | Type | Description |
|-----------|------|--------------|
| LocationKey | INT (PK) | Surrogate key |
| LocationCode | VARCHAR(50) | Business key (normalized location name) |
| LocationName | NVARCHAR(100) | Full location name |
| City | NVARCHAR(50) | Parsed city name |
| State | NVARCHAR(50) | Parsed state/province (99.7% "Unknown" — only 23 cities enriched) |
| Country | NVARCHAR(50) | Country (default: India) |
| Region | NVARCHAR(50) | Geographic region |
| LocationType | VARCHAR(20) | Urban/Rural/Metro classification |

**Derivation Logic:** `LocationCode = UPPER(REPLACE(LocationName, ' ', '_'))`

**Volume:** 9,354 rows — above the original 9,021 due to location migration simulation in the Python augmentation script (243,376 customers changed cities).

---

### 3.3 Dim_Customer (Type 2 - Historical Tracking)

**Purpose:** Customer dimension with historical location tracking
**Grain:** One row per customer per location change (SCD Type 2)

| Attribute | Type | SCD Type | Description |
|-----------|------|----------|--------------|
| CustomerKey | INT (PK) | - | Surrogate key (unique per version) |
| CustomerID | VARCHAR(50) | Fixed | Business key (same across versions) |
| DateOfBirth | DATE | Type 1 | **Nullable** — 697,306 rows are NULL (see Data Quality below) |
| Age | INT | Type 1 | Calculated; NULL when DateOfBirth is NULL |
| AgeGroup | VARCHAR(20) | Type 1 | 18-25, 26-35, 36-45, 46-55, 56+, or "Unknown" |
| Gender | VARCHAR(10) | Type 1 | Male/Female/Unknown |
| **Location** | NVARCHAR(100) | **Type 2** | **Tracked historically** |
| LocationKey | INT (FK) | Type 2 | Snowflake reference to Dim_Location |
| CustomerType | VARCHAR(20) | Type 1 | New/Existing |
| FirstTransactionDate | DATE | Fixed | First transaction ever |
| StartDate / EndDate / IsCurrent | DATE/DATE/BIT | SCD | Standard SCD Type 2 versioning |

**Actual Data (Jun 2026):**

| Metric | Value |
|--------|-------|
| Total rows | 1,169,677 |
| Current versions (IsCurrent=1) | 884,225 |
| Historical versions (IsCurrent=0) | 285,452 |
| Customers with location changes | 243,376 |

#### Data Quality Finding: DateOfBirth

The original load procedure used `TRY_CAST` combined with `ISNULL(..., '1900-01-01')`, which converted unparseable birth dates into a fabricated default instead of NULL — and some Python-generated source rows separately resolved to 1800-01-01. This produced 694,154 customers with implausible ages (126+ years).

**Fix:** `usp_Load_Dim_Customer` rewritten to use `TRY_CONVERT(date, ..., 103)` with explicit year-range validation (1930–2005); anything outside that range, or unparseable, is set to NULL.

**Result:** 472,371 customers with valid DOB, 697,306 with NULL (AgeGroup = "Unknown"). This was a deliberate choice over imputing random plausible birthdates — NULL preserves an honest, auditable data quality signal.

**Why Type 2 for Location?** Location changes can affect customer behavior; enables "did behavior change after relocation?" analysis and location-based cohorting.

---

### 3.4 Dim_Segment (Type 2 - Rule Versioning)

**Purpose:** Customer segmentation rules (RF-based)
**Grain:** One row per segment definition

**Segments (Exhaustive & Non-overlapping):**

| Segment | RecencyMin | RecencyMax | FrequencyMin | FrequencyMax | Color |
|---------|-----------|-----------|-------------|-------------|-------|
| **Champions** | 0 | 59 | 15 | 9999 | #28A745 |
| **Loyal Customers** | 0 | 59 | 8 | 14 | #17A2B8 |
| **Potential Loyalists** | 0 | 59 | 5 | 7 | #6C757D |
| **New Customers** | 0 | 30 | 0 | 4 | #007BFF |
| **At Risk** | 60 | 90 | 5 | 9999 | #FFC107 |
| **Hibernating** | 31 | 90 | 0 | 4 | #FF6B6B |
| **Churned** | 91 | 9999 | 0 | 9999 | #DC3545 |

> **Design Note:** Ranges were redesigned from the original spec to be fully exhaustive and non-overlapping across the entire Recency × Frequency space — verified programmatically before deployment. The original ranges had gaps (e.g. Recency 31–59 with Frequency 0–4 matched no segment) that caused FK violations in Package 5.

**Why Separate Dimension?** Segmentation rules can change over time; central management of business rules; enables "what if" analysis with alternative segmentation strategies.

---

## 4. Fact Tables

### 4.1 Fact_Transaction (Transactional Fact)

**Purpose:** Detailed transaction-level data for deep-dive analysis
**Grain:** One row per transaction

| Measure | Type | Aggregation | Description |
|---------|------|-------------|--------------|
| TransactionAmount | DECIMAL(18,2) | SUM, AVG | Transaction value |
| AccountBalance | DECIMAL(18,2) | AVG | Balance after transaction |
| TransactionCount | INT | SUM | Always 1 (for COUNT) |

**Actual Volume:** 147,290,230 rows | Date Range: 2015-01-01 to 2016-08-31
**Note:** Not imported into the SSAS Tabular model — superseded by the pre-aggregated Fact_CustomerSnapshot for reporting.

---

### 4.2 Fact_CustomerSnapshot (Periodic Snapshot)

**Purpose:** Monthly aggregated customer metrics for trend analysis
**Grain:** One row per customer per month

| Category | Measures | Description |
|----------|----------|--------------|
| **Transaction Aggregates** | TransactionCount, TotalAmount, AvgAmount, Min/Max Amount | Monthly transaction summary |
| **RF Analysis** | DaysSinceLastTransaction, RecencyScore (1-5), FrequencyScore (0-5) | Customer engagement metrics |
| **Loyalty** | LoyaltyScore | Combined RF score: (R × 0.3) + (F × 0.7) |
| **Satisfaction** | SatisfactionScore (1-5) | Synthetic: Based on RF patterns |
| **Behavior Flags** | ComplaintFlag, ChurnFlag, AtRiskFlag | Binary indicators |
| **Trend Analysis** | TrendCategory, GrowthRate, PreviousMonthCount | Period-over-period comparison |
| **Account Status** | FinalAccountBalance | End-of-month balance (carried forward) |

**Note on GrowthRate:** stored pre-scaled as a percentage (25.00 = 25%, not 0.25) — relevant when building DAX measures with Percentage format, which assumes a fraction.

**Actual Volume:** 13,051,115 rows | Coverage: 884K customers × 20 months

**Segment Distribution (Jun 2026):**

| Segment | Customer-Months | % |
|---------|----------------|---|
| Loyal Customers | 3,602,583 | 27.60% |
| Champions | 3,093,899 | 23.71% |
| New Customers | 2,760,614 | 21.15% |
| Potential Loyalists | 1,883,756 | 14.43% |
| Churned | 1,306,637 | 10.01% |
| Hibernating | 403,626 | 3.09% |

---

## 5. Relationships and Cardinality

```
Dim_Date (1) ────────< (Many) Fact_Transaction
Dim_Date (1) ────────< (Many) Fact_CustomerSnapshot

Dim_Customer (1) ────< (Many) Fact_Transaction
Dim_Customer (1) ────< (Many) Fact_CustomerSnapshot

Dim_Location (1) ────< (Many) Fact_Transaction         [star]
Dim_Location (1) ────< (Many) Dim_Customer             [snowflake]

Dim_Segment (1) ─────< (Many) Fact_CustomerSnapshot
```

---

## 6. Data Volumes

| Table | Rows (Actual) | Notes |
|-------|--------------|-------|
| Dim_Date | 5,844 | Static, 2015–2030 |
| Dim_Location | 9,354 | Includes migration-generated locations |
| Dim_Customer | 1,169,677 total / 884,225 current | SCD Type 2 history included |
| Dim_Segment | 7 | Pre-populated |
| Fact_Transaction | 147,290,230 | 20 months, Jan 2015–Aug 2016 |
| Fact_CustomerSnapshot | 13,051,115 | 20 months, customer-month grain |

---

## 7. Index Strategy

### Dimension Indexes

**Dim_Customer:**
- Clustered: CustomerKey (PK)
- Non-Clustered: CustomerID, IsCurrent
- Filtered: (CustomerID, IsCurrent) WHERE IsCurrent=1

**Dim_Date:**
- Clustered: DateKey (PK)
- Non-Clustered: Date, (Year, Month), (Year, Quarter)

**Dim_Segment:**
- Clustered: SegmentKey (PK)
- Non-Clustered: SegmentCode, IsActive

### Fact Indexes

**Fact_Transaction:**
- Clustered: TransactionKey (PK)
- Non-Clustered: CustomerKey, DateKey
- Covering: (CustomerKey, DateKey) INCLUDE (TransactionAmount)

**Fact_CustomerSnapshot:**
- Clustered: SnapshotKey (PK)
- Non-Clustered: CustomerKey, DateKey, SegmentKey
- Filtered: ChurnFlag WHERE ChurnFlag=1
- Filtered: AtRiskFlag WHERE AtRiskFlag=1

---

## 8. Business Rules Summary

**Recency Score (1-5):** ≤30→5, 31-60→4, 61-90→3, 91-180→2, >180→1
**Frequency Score (0-5):** ≥15→5, 10-14→4, 5-9→3, 2-4→2, 1→1, 0→0
**Loyalty Score:** `(RecencyScore × 0.3) + (FrequencyScore × 0.7)`
**ChurnFlag:** 1 if DaysSinceLastTransaction > 90
**AtRiskFlag:** 1 if DaysSinceLastTransaction BETWEEN 60 AND 90

---

## 9. SSAS Tabular Layer (Phase 6 — Complete)

**Model:** BankingLoyaltyChurn, Compatibility Level 1600
**Tables imported:** Dim_Date, Dim_Customer (IsCurrent=1), Dim_Location, Dim_Segment, Fact_CustomerSnapshot
**Excluded:** Fact_Transaction (pre-aggregated, not needed for reporting)

**Calculated columns added:** MonthLabel, MonthSort (Dim_Date); RecencyBucket, LoyaltyBand, GrowthCategory (Fact_CustomerSnapshot)

**39 DAX measures** across 7 Display Folders (Customer Metrics, Churn & Retention, Loyalty & Satisfaction, Transactions, Behavior & Growth, Segments, NPS). All anchor to `[_LastDataDateKey]` rather than `Dim_Date` directly.

**Key debugging lessons (documented for reuse in future models):**
- `DATEADD()` nested inside `CALCULATETABLE()` with a same-table date filter loses traversal context — resolve target date to a scalar first via `CALCULATE(MAX(...))` + `EOMONTH()`
- Percentage-formatted measures over pre-scaled source values (stored as 25.00, not 0.25) need explicit `/100` in the formula
- SSAS service account requires an explicit SQL Server login + `db_datareader` role on the source DW — not granted by default

**KPI threshold/status logic deliberately deferred to Power BI** — SSAS native KPI objects don't carry their status visuals through to Power BI consumption.

---

## 10. Known Issues & Resolutions

| Issue | Impact | Resolution |
|-------|--------|-----------|
| SQL Server DATEFORMAT=mdy | TRY_CAST silently dropped ~60% of records | All SPs use TRY_CONVERT(date, ..., 103) |
| Dim_Customer DOB fallback to 1900/1800 | 694K customers with invalid ages | TRY_CONVERT + year-range validation; NULL preserved over fabrication |
| Dim_Segment ranges had gaps | FK violations in Package 5 | Ranges redesigned to be exhaustive and non-overlapping |
| Package 5 SSIS timeout (300s default) | Load Fact Table task failed | TimeOut set to 0 (unlimited) on all Execute SQL Tasks |
| DAX DATEADD inside CALCULATETABLE | QoQ/YoY measures returned "no current row" errors | Resolve date to scalar first, then filter directly |
| SSAS service account lacked SQL login | Process Full failed with invalid credentials error | Granted db_datareader to NT Service\MSOLAP$SSAS_TABULAR |

---

## 11. Future Enhancements

**Additional Dimensions (Potential):**
- Dim_Campaign: Track marketing campaigns and measure effectiveness
- Dim_Product: Banking products used by customers
- Dim_Channel: Transaction channels (ATM, Online, Branch)

**Advanced Analytics:**
- Churn probability scores via ML integration
- Customer lifetime value predictions
- Next-best-action recommendations

---

**Document Version:** 1.3
**Last Updated:** June 2026
**Status:** ✅ ETL + SSAS Tabular Complete — Proceeding to Phase 7 (Power BI)
