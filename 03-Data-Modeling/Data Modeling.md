# Data Model Design Document
## Banking Customer Loyalty & Churn Analysis Data Warehouse

**Version:** 1.0  
**Date:** November 2025  
**Author:** Soheil Tavakkol

---

## 1. Overview

### 1.1 Purpose
This document provides a comprehensive description of the dimensional data model designed for analyzing banking customer behavior, focusing on loyalty patterns and churn prediction.

### 1.2 Modeling Approach
- **Schema Type:** Star Schema
- **Design Methodology:** Dimensional Modeling (Kimball)
- **SCD Strategy:** Type 2 for Customer Location changes

### 1.3 Key Design Decisions

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
    (SCD Type 2)         |         (1M+ rows)
                         |
    Dim_Location --------+
                         |
                         |
    Dim_Segment ---------+-------- Fact_CustomerSnapshot
    (7 segments)                   (Monthly aggregates)
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

**SCD Type 2 Logic:**

**Scenario:** Customer moves from Mumbai to Delhi

```
Before Move:
CustomerKey | CustomerID | Location | StartDate  | EndDate | IsCurrent
1           | C001       | Mumbai   | 2020-01-01 | NULL    | 1

After Move (Transaction dated 2023-07-15):
CustomerKey | CustomerID | Location | StartDate  | EndDate    | IsCurrent
1           | C001       | Mumbai   | 2020-01-01 | 2023-07-14 | 0  ← Updated
2           | C001       | Delhi    | 2023-07-15 | NULL       | 1  ← New record
```

**Why Type 2 for Location?**
- Location changes can affect customer behavior
- Need to analyze: "Did behavior change after relocation?"
- Enables location-based cohort analysis

**Type 1 Attributes:**
- Age/AgeGroup: Overwrite (calculated from DOB)
- Gender: Overwrite (extremely rare changes, not historically significant)

---

### 3.4 Dim_Segment (Type 2 - Rule Versioning)

**Purpose:** Customer segmentation rules (RF-based)

**Grain:** One row per segment definition

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| SegmentKey | INT (PK) | Surrogate key |
| SegmentCode | VARCHAR(50) | Business key (e.g., "RF_Champions") |
| SegmentName | NVARCHAR(100) | Display name (e.g., "Champions") |
| SegmentType | VARCHAR(50) | RF, Demographic, Behavioral |
| Description | NVARCHAR(500) | Segmentation logic description |
| RecencyMin/Max | INT | Days range for Recency |
| FrequencyMin/Max | INT | Transaction count range |
| DisplayOrder | INT | UI sorting order |
| Color | VARCHAR(20) | Hex color for visualization |
| IsActive | BIT | Active or deprecated |
| StartDate | DATE | Rule effective date |
| EndDate | DATE | Rule expiration (NULL=active) |

**Pre-defined Segments:**

| Segment | Recency | Frequency | Description |
|---------|---------|-----------|-------------|
| **Champions** | 0-30 | >15 | Most valuable: High frequency, low recency |
| **Loyal Customers** | 0-60 | 8-14 | Regular customers with consistent activity |
| **Potential Loyalists** | 0-45 | 5-7 | Growing customers showing promise |
| **At Risk** | 60-90 | 5-15 | Previously active, declining engagement |
| **Hibernating** | 60-90 | 0-4 | Low frequency, becoming inactive |
| **Churned** | >90 | Any | Lost customers, no activity 90+ days |
| **New Customers** | 0-30 | Any | Recently acquired (first 90 days) |

**Why Separate Dimension?**
- Segmentation rules can change over time
- Can track historical segment assignments
- Enables "What if" analysis with different segmentation strategies
- Central management of business rules

---

## 4. Fact Tables

### 4.1 Fact_Transaction (Transactional Fact)

**Purpose:** Detailed transaction-level data for deep-dive analysis

**Grain:** One row per transaction

**Fact Type:** Transaction (most granular)

**Dimensions:**
- CustomerKey → Dim_Customer (SCD Type 2 aware)
- DateKey → Dim_Date
- LocationKey → Dim_Location

**Measures:**

| Measure | Type | Aggregation | Description |
|---------|------|-------------|-------------|
| TransactionAmount | DECIMAL(18,2) | SUM, AVG | Transaction value |
| AccountBalance | DECIMAL(18,2) | AVG | Balance after transaction |
| TransactionCount | INT | SUM | Always 1 (for COUNT) |

**Degenerate Dimension:**
- TransactionID (stored in fact, no separate dimension)

**SCD Type 2 Consideration:**

When loading transactions, the ETL must:
1. Look up CustomerKey WHERE:
   - CustomerID = ?
   - AND TransactionDate BETWEEN StartDate AND ISNULL(EndDate, '9999-12-31')

This ensures each transaction links to the correct customer version (location) at that point in time.

**Example:**
```
Transaction on 2023-01-15: Links to CustomerKey=1 (Mumbai)
Transaction on 2023-08-20: Links to CustomerKey=2 (Delhi)
```

**Query Pattern:**
```sql
-- Transactions by customer location over time
SELECT 
    C.Location,
    YEAR(D.Date) AS Year,
    SUM(F.TransactionAmount) AS TotalAmount
FROM Fact_Transaction F
JOIN Dim_Customer C ON F.CustomerKey = C.CustomerKey
JOIN Dim_Date D ON F.DateKey = D.DateKey
GROUP BY C.Location, YEAR(D.Date);
```

---

### 4.2 Fact_CustomerSnapshot (Periodic Snapshot)

**Purpose:** Monthly aggregated customer metrics for trend analysis

**Grain:** One row per customer per month

**Fact Type:** Periodic Snapshot (monthly)

**Dimensions:**
- CustomerKey → Dim_Customer (IsCurrent=1)
- DateKey → Dim_Date (last day of month)
- SegmentKey → Dim_Segment

**Measures:**

| Category | Measures | Description |
|----------|----------|-------------|
| **Transaction Aggregates** | TransactionCount, TotalAmount, AvgAmount, Min/Max Amount | Monthly transaction summary |
| **RF Analysis** | DaysSinceLastTransaction, RecencyScore (1-5), FrequencyScore (1-5) | Customer engagement metrics |
| **Loyalty** | LoyaltyScore | Combined RF score: (R × 0.3) + (F × 0.7) |
| **Satisfaction** | SatisfactionScore (1-5) | Synthetic: Based on RF patterns |
| **Behavior Flags** | ComplaintFlag, ChurnFlag, AtRiskFlag | Binary indicators |
| **Trend Analysis** | TrendCategory, GrowthRate, PreviousMonthCount | Period-over-period comparison |
| **Account Status** | FinalAccountBalance | End-of-month balance |

**Calculated Measures:**

**Recency Score (1-5):**
```
Recency (days) → Score
≤ 30           → 5
31-60          → 4
61-90          → 3
91-180         → 2
> 180          → 1
```

**Frequency Score (1-5):**
```
Transaction Count → Score
≥ 15              → 5
10-14             → 4
5-9               → 3
2-4               → 2
0-1               → 1
```

**Loyalty Score:**
```
LoyaltyScore = (RecencyScore × 0.3) + (FrequencyScore × 0.7)

Example:
R=5, F=4 → (5×0.3) + (4×0.7) = 1.5 + 2.8 = 4.3
```

**Satisfaction Score (Synthetic):**
```
IF FrequencyScore > 3 AND RecencyScore > 3:
    → 4.0 to 5.0 (satisfied customers)
ELSE IF FrequencyScore < 2 AND RecencyScore < 2:
    → 1.0 to 2.5 (dissatisfied)
ELSE:
    → 2.5 to 4.0 (neutral)
```

**Complaint Flag (Synthetic):**
```
IF (Previous Month Transactions - Current Month Transactions) / Previous > 0.3:
    → 70% probability of complaint (decline > 30%)
ELSE:
    → No complaint
```

**Flags:**
- ChurnFlag: 1 if Recency > 90 days
- AtRiskFlag: 1 if Recency between 60-90 days
- TrendCategory: Strong Growth / Moderate Growth / Stable / Moderate Decline / Sharp Decline / Churned

**Query Pattern:**
```sql
-- Customer segment distribution over time
SELECT 
    D.YearMonth,
    S.SegmentName,
    COUNT(DISTINCT F.CustomerKey) AS CustomerCount,
    AVG(F.LoyaltyScore) AS AvgLoyalty
FROM Fact_CustomerSnapshot F
JOIN Dim_Date D ON F.DateKey = D.DateKey
JOIN Dim_Segment S ON F.SegmentKey = S.SegmentKey
GROUP BY D.YearMonth, S.SegmentName
ORDER BY D.YearMonth, S.DisplayOrder;
```

---

## 5. Relationships and Cardinality

### 5.1 Dimension to Fact Relationships

```
Dim_Date (1) ────────< (Many) Fact_Transaction
Dim_Date (1) ────────< (Many) Fact_CustomerSnapshot

Dim_Customer (1) ────< (Many) Fact_Transaction
Dim_Customer (1) ────< (Many) Fact_CustomerSnapshot

Dim_Location (1) ────< (Many) Fact_Transaction
Dim_Location (1) ────< (Many) Dim_Customer

Dim_Segment (1) ─────< (Many) Fact_CustomerSnapshot
```

### 5.2 Referential Integrity

**Enforced via Foreign Keys:**
- All FK constraints are defined at database level
- Ensures no orphan records in fact tables
- ETL must handle lookup failures gracefully

**Lookup Strategy:**
- Dimension loads must complete before fact loads
- Use MERGE or INSERT/UPDATE for dimensions
- Fact loads perform lookups to get surrogate keys

---

## 6. Data Volumes and Growth

### 6.1 Current Volumes

| Table | Rows | Growth Rate |
|-------|------|-------------|
| Dim_Date | 5,844 | Static (pre-populated) |
| Dim_Location | ~500 | Slow (new locations rare) |
| Dim_Customer | ~900K | Medium (new customers + SCD versions) |
| Dim_Segment | 7 | Very slow (rule changes rare) |
| Fact_Transaction | 1M+ | High (daily transactions) |
| Fact_CustomerSnapshot | ~27K/month | Medium (monthly snapshots) |

### 6.2 Storage Estimates

**Fact_Transaction:**
- Row size: ~50 bytes
- 1M rows: ~50 MB
- Annual growth: ~18M rows → ~900 MB/year

**Fact_CustomerSnapshot:**
- Row size: ~120 bytes
- 900K customers × 12 months: ~10.8M rows → ~1.3 GB/year

**Total DW size (3 years):** ~5-6 GB (excluding indexes)

---

## 7. Index Strategy

### 7.1 Dimension Indexes

**Dim_Customer:**
- Clustered: CustomerKey (PK)
- Non-Clustered: CustomerID, IsCurrent (for lookups)
- Non-Clustered: (CustomerID, IsCurrent) WHERE IsCurrent=1 (filtered)

**Dim_Date:**
- Clustered: DateKey (PK)
- Non-Clustered: Date, (Year, Month), (Year, Quarter)

**Dim_Segment:**
- Clustered: SegmentKey (PK)
- Non-Clustered: SegmentCode, IsActive

### 7.2 Fact Indexes

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

### 8.1 Customer Classification

**New Customer:** FirstTransactionDate within last 90 days

**Active Customer:** Transaction within last 30 days

**At Risk:** 60-90 days since last transaction

**Churned:** 90+ days since last transaction

### 8.2 Segmentation Rules

Segments are assigned based on:
1. Recency score (1-5)
2. Frequency score (1-5)
3. Matching against Dim_Segment ranges

**Assignment Logic:**
```
FOR each customer in month:
    Calculate RecencyScore
    Calculate FrequencyScore
    
    MATCH against Dim_Segment WHERE:
        Recency BETWEEN RecencyMin AND RecencyMax
        AND Frequency BETWEEN FrequencyMin AND FrequencyMax
        AND IsActive = 1
    
    Assign SegmentKey
```

### 8.3 Data Quality Rules

**Mandatory Fields:**
- CustomerID, TransactionID, TransactionDate

**Validation Rules:**
- Age: 18-100 years
- TransactionAmount: 0 < Amount < 1,000,000
- Dates: Between 2015-01-01 and Current Date

**NaN/NULL Handling:**
- CustomerDOB = NaN → Reject record (0.32% of data)
- Gender = NaN → Convert to 'Unknown'
- Location = NaN → Convert to 'Unspecified'
- Balance = NaN → Convert to 0

---

## 9. Query Patterns

### 9.1 Common Analytical Queries

**Churn Analysis:**
```sql
SELECT 
    S.SegmentName,
    SUM(CASE WHEN ChurnFlag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS ChurnRate
FROM Fact_CustomerSnapshot F
JOIN Dim_Segment S ON F.SegmentKey = S.SegmentKey
JOIN Dim_Date D ON F.DateKey = D.DateKey
WHERE D.YearMonth = '2016-08'
GROUP BY S.SegmentName;
```

**Loyalty Trends:**
```sql
SELECT 
    D.YearMonth,
    AVG(F.LoyaltyScore) AS AvgLoyalty,
    AVG(F.SatisfactionScore) AS AvgSatisfaction
FROM Fact_CustomerSnapshot F
JOIN Dim_Date D ON F.DateKey = D.DateKey
GROUP BY D.YearMonth
ORDER BY D.YearMonth;
```

**Location-based Transaction Analysis:**
```sql
SELECT 
    C.Location,
    COUNT(F.TransactionKey) AS TxnCount,
    SUM(F.TransactionAmount) AS TotalAmount
FROM Fact_Transaction F
JOIN Dim_Customer C ON F.CustomerKey = C.CustomerKey
JOIN Dim_Date D ON F.DateKey = D.DateKey
WHERE D.Year = 2016
GROUP BY C.Location
ORDER BY TotalAmount DESC;
```

---

## 10. Design Justifications

### 10.1 Why Star Schema?

**Advantages for this project:**
- Simple to understand for business users
- Optimal for BI tool queries (Power BI, Tableau)
- Fast aggregate queries (single-level joins)
- Easy to add new dimensions or measures

**When Snowflake would be better:**
- Multiple levels of hierarchies (we don't have complex hierarchies)
- Dimension size concerns (our dimensions are small)
- Need for shared subdimensions (not applicable here)

### 10.2 Why Two Fact Tables?

**Fact_Transaction:**
- For detailed, transaction-level analysis
- "What were the transactions on 2016-08-15?"
- High granularity, fast inserts

**Fact_CustomerSnapshot:**
- For aggregated, customer-level trends
- "How did customer loyalty change over time?"
- Pre-aggregated, optimized for time-series queries

**Alternative (Rejected):**
Single fact table with both grains → Would require complex queries and poor performance

### 10.3 Why SCD Type 2 Only for Location?

**Location:** Type 2
- Business value: Location changes can indicate life events
- Analysis value: Compare behavior before/after relocation
- Frequency: Customers do relocate occasionally

**Gender:** Type 1
- Business value: Changes extremely rare, not analytically significant
- Complexity: Not worth the overhead

**Age:** Type 1 (Calculated)
- Always derivable from DateOfBirth
- No need for history (current age is always calculable)

---

## 11. Future Enhancements

### 11.1 Additional Dimensions (Potential)

**Dim_Campaign:**
- Track marketing campaigns
- Measure campaign effectiveness on churn/loyalty

**Dim_Product:**
- Banking products used by customers
- Cross-sell/up-sell analysis

**Dim_Channel:**
- Transaction channels (ATM, Online, Branch)
- Channel preference analysis

### 11.2 Additional Facts (Potential)

**Fact_CampaignResponse:**
- Customer responses to campaigns
- A/B testing analysis

**Fact_DailyBalance:**
- Daily account balances
- Cash flow analysis

### 11.3 Advanced Analytics

**Machine Learning Integration:**
- Churn probability scores
- Next-best-action recommendations
- Customer lifetime value predictions

---

## 12. Conclusion

This dimensional model provides a robust foundation for banking customer analytics:

✅ **Comprehensive:** Covers loyalty, churn, and behavioral analysis  
✅ **Performant:** Star schema optimized for BI queries  
✅ **Flexible:** Separate segment dimension enables rule evolution  
✅ **Historical:** SCD Type 2 tracks meaningful changes  
✅ **Scalable:** Can accommodate millions of transactions  
✅ **Maintainable:** Clear structure, well-documented  

The design balances analytical depth with implementation simplicity, making it suitable for both educational purposes and production deployment.

---

**Document Version:** 1.0  
**Last Updated:** November 2025  
**Next Review:** Before Phase 4 (ETL Development)