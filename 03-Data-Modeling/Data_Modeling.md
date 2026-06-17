# Data Model Design Document
## Banking Customer Loyalty & Churn Analysis Data Warehouse

**Version:** 1.2
**Date:** June 2026
**Author:** Soheil Tavakkol

---

## 1. Overview

### 1.1 Purpose
This document provides a comprehensive description of the dimensional data model designed for analyzing banking customer behavior, focusing on loyalty patterns and churn prediction.

### 1.2 Modeling Approach
- **Schema Type:** Star Schema
- **Design Methodology:** Dimensional Modeling (Kimball)
- **SCD Strategy:** Type 2 for Customer Location changes

### 1.3 Implementation Status

✅ Phase 2: Physical schema created
✅ Phase 3: Model design documented
✅ Phase 5: All tables loaded and validated
    - Dimensions: 4 tables (1,063,510 total rows)
    - Facts: 2 tables (160M+ total rows)
    - ETL: 5 SSIS packages completed
✅ Phase 6: SSAS Tabular model
⏳ Phase 7: Power BI Dashboards (next)

### 1.4 Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Star Schema over Snowflake | Simpler queries, better performance for BI tools |
| Integrated Date/Time Dimension | Reduces joins, sufficient for project scale |
| SCD Type 2 only for Location | Location is the only attribute that meaningfully changes |
| Separate Segment Dimension | Allows flexible segmentation rule changes without ETL modifications |
| Two Fact Tables | Transaction-level for detail, Snapshot for aggregated analysis |

---

## 2. Star Schema Architecture

### 2.1 High-Level Structure

```
                    Dim_Date
                    (5,844 rows)
                         |
                         |
    Dim_Customer --------+-------- Fact_Transaction
    (SCD Type 2)         |         (147M rows)
                         |
    Dim_Location --------+
                         |
                         |
    Dim_Segment ---------+-------- Fact_CustomerSnapshot
    (7 segments)                   (13M rows)
```

### 2.2 Schema Benefits

**Query Performance:**
- Single-level joins (Fact → Dimension)
- No navigation through normalized hierarchies
- Optimal for aggregate queries

**Maintainability:**
- Clear business concepts
- Easy to understand by non-technical users
- Straightforward ETL logic

**Scalability:**
- Easy to add new dimensions
- Can extend facts with new measures
- Segment rules can evolve independently

---

## 3. Dimension Tables

### 3.1 Dim_Date (Pre-populated Reference)

**Purpose:** Time dimension for all date/time-based analysis

**Grain:** One row per day (with integrated time attributes)

**Key Attributes:**

| Category | Attributes | Usage |
|----------|-----------|-------|
| **Date Hierarchies** | Year, Quarter, Month, Week, Day | Time-based slicing and grouping |
| **Day Classification** | DayOfWeek, IsWeekend, IsWorkingDay | Behavioral pattern analysis |
| **Fiscal Calendar** | FiscalYear, FiscalQuarter | Business reporting |
| **Relative Flags** | IsToday, IsCurrentMonth, IsCurrentYear | Dynamic filtering |
| **Time** | Hour, Minute, TimeOfDay | Intraday analysis |

**Special Features:**
- **DayOfWeek:** 1=Monday, 7=Sunday (ISO 8601 standard)
- **Pre-populated:** 2015-2030 (5,844 records)
- **No ETL required:** Static reference data

**Business Rules:**
- Weekend: Saturday or Sunday
- Working Day: NOT (Weekend OR Holiday)
- TimeOfDay: Morning (6-12), Afternoon (12-18), Evening (18-22), Night (22-6)

---

### 3.2 Dim_Location (Type 1)

**Purpose:** Geographic dimension for location-based analysis

**Grain:** One row per unique location

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| LocationKey | INT (PK) | Surrogate key |
| LocationCode | VARCHAR(50) | Business key (normalized location name) |
| LocationName | NVARCHAR(100) | Full location name |
| City | NVARCHAR(50) | Parsed city name |
| State | NVARCHAR(50) | Parsed state/province |
| Country | NVARCHAR(50) | Country (default: India) |
| Region | NVARCHAR(50) | Geographic region (West/North/South/East) |
| LocationType | VARCHAR(20) | Urban/Rural/Metro classification |

**SCD Type:** Type 1 (Overwrite)
- Location attributes don't have historical significance as a dimension
- Historical location tracking is done via Dim_Customer (Type 2)

**Derivation Logic:**
```
LocationCode = UPPER(REPLACE(LocationName, ' ', '_'))
Example: "NAVI MUMBAI" → "NAVI_MUMBAI"
```

---

### 3.3 Dim_Customer (Type 2 - Historical Tracking)

**Purpose:** Customer dimension with historical location tracking

**Grain:** One row per customer per location change (SCD Type 2)

**Key Attributes:**

| Attribute | Type | SCD Type | Description |
|-----------|------|----------|-------------|
| CustomerKey | INT (PK) | - | Surrogate key (unique per version) |
| CustomerID | VARCHAR(50) | Fixed | Business key (same across versions) |
| DateOfBirth | DATE | Type 1 | Never changes |
| Age | INT | Type 1 | Calculated, updated |
| AgeGroup | VARCHAR(20) | Type 1 | 18-25, 26-35, 36-45, 46-55, 56+ |
| Gender | VARCHAR(10) | Type 1 | Male/Female/Unknown |
| **Location** | NVARCHAR(100) | **Type 2** | **Tracked historically** |
| LocationKey | INT (FK) | Type 2 | Reference to Dim_Location |
| CustomerType | VARCHAR(20) | Type 1 | New/Existing |
| FirstTransactionDate | DATE | Fixed | First transaction ever |
| **StartDate** | DATE | **SCD** | **Effective start date** |
| **EndDate** | DATE | **SCD** | **Effective end date (NULL=current)** |
| **IsCurrent** | BIT | **SCD** | **1=current, 0=historical** |

**Actual Data (Jun 2026):**

| Metric | Value |
|--------|-------|
| Total rows | 1,169,677 |
| Current versions (IsCurrent=1) | 884,225 |
| Historical versions (IsCurrent=0) | 285,452 |
| Customers with location changes | 243,376 |

**Why Type 2 for Location?**
- Location changes can affect customer behavior
- Need to analyze: "Did behavior change after relocation?"
- Enables location-based cohort analysis

---

### 3.4 Dim_Segment (Type 2 - Rule Versioning)

**Purpose:** Customer segmentation rules (RF-based)

**Grain:** One row per segment definition

**Pre-defined Segments (Exhaustive & Non-overlapping):**

| Segment | RecencyMin | RecencyMax | FrequencyMin | FrequencyMax | Color |
|---------|-----------|-----------|-------------|-------------|-------|
| **Champions** | 0 | 59 | 15 | 9999 | #28A745 |
| **Loyal Customers** | 0 | 59 | 8 | 14 | #17A2B8 |
| **Potential Loyalists** | 0 | 59 | 5 | 7 | #6C757D |
| **New Customers** | 0 | 30 | 0 | 4 | #007BFF |
| **At Risk** | 60 | 90 | 5 | 9999 | #FFC107 |
| **Hibernating** | 31 | 90 | 0 | 4 | #FF6B6B |
| **Churned** | 91 | 9999 | 0 | 9999 | #DC3545 |

> **Design Note:** Ranges were redesigned from original spec to be fully exhaustive and non-overlapping across the entire Recency × Frequency space. Verified programmatically before deployment. Original ranges had gaps that caused FK violations in Package 5.

**Why Separate Dimension?**
- Segmentation rules can change over time
- Central management of business rules
- Enables "What if" analysis with different segmentation strategies

---

## 4. Fact Tables

### 4.1 Fact_Transaction (Transactional Fact)

**Purpose:** Detailed transaction-level data for deep-dive analysis

**Grain:** One row per transaction

**Measures:**

| Measure | Type | Aggregation | Description |
|---------|------|-------------|-------------|
| TransactionAmount | DECIMAL(18,2) | SUM, AVG | Transaction value |
| AccountBalance | DECIMAL(18,2) | AVG | Balance after transaction |
| TransactionCount | INT | SUM | Always 1 (for COUNT) |

**Actual Volume:** 147,290,230 rows | Date Range: 2015-01-01 to 2016-08-31

---

### 4.2 Fact_CustomerSnapshot (Periodic Snapshot)

**Purpose:** Monthly aggregated customer metrics for trend analysis

**Grain:** One row per customer per month

**Measures:**

| Category | Measures | Description |
|----------|----------|-------------|
| **Transaction Aggregates** | TransactionCount, TotalAmount, AvgAmount, Min/Max Amount | Monthly transaction summary |
| **RF Analysis** | DaysSinceLastTransaction, RecencyScore (1-5), FrequencyScore (0-5) | Customer engagement metrics |
| **Loyalty** | LoyaltyScore | Combined RF score: (R × 0.3) + (F × 0.7) |
| **Satisfaction** | SatisfactionScore (1-5) | Synthetic: Based on RF patterns |
| **Behavior Flags** | ComplaintFlag, ChurnFlag, AtRiskFlag | Binary indicators |
| **Trend Analysis** | TrendCategory, GrowthRate, PreviousMonthCount | Period-over-period comparison |
| **Account Status** | FinalAccountBalance | End-of-month balance (carried forward) |

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

Dim_Location (1) ────< (Many) Fact_Transaction
Dim_Location (1) ────< (Many) Dim_Customer

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

### Scoring Logic

**Recency Score (1-5):**
```
≤ 30 days  → 5
31-60      → 4
61-90      → 3
91-180     → 2
> 180      → 1
```

**Frequency Score (0-5):**
```
≥ 15 txns  → 5
10-14      → 4
5-9        → 3
2-4        → 2
1          → 1
0          → 0
```

**Loyalty Score:**
```
LoyaltyScore = (RecencyScore × 0.3) + (FrequencyScore × 0.7)
```

**Flags:**
- ChurnFlag = 1 if DaysSinceLastTransaction > 90
- AtRiskFlag = 1 if DaysSinceLastTransaction BETWEEN 60 AND 90

---

## 9. Known Issues & Resolutions

| Issue | Impact | Resolution |
|-------|--------|-----------|
| SQL Server DATEFORMAT=mdy | TRY_CAST dropped ~60% of records silently | All SPs use TRY_CONVERT(date, ..., 103) |
| Dim_Segment ranges had gaps | FK violations in Package 5 | Ranges redesigned to be exhaustive and non-overlapping |
| Package 5 SSIS timeout (300s default) | Load Fact Table task failed | TimeOut set to 0 (unlimited) on all Execute SQL Tasks |

---

## 10. Future Enhancements

**Additional Dimensions (Potential):**
- Dim_Campaign: Track marketing campaigns and measure effectiveness
- Dim_Product: Banking products used by customers
- Dim_Channel: Transaction channels (ATM, Online, Branch)

**Advanced Analytics:**
- Churn probability scores via ML integration
- Customer lifetime value predictions
- Next-best-action recommendations

---

**Document Version:** 1.2
**Last Updated:** June 2026
**Status:** ✅ ETL Complete — Proceeding to Phase 7 (Power BI)
