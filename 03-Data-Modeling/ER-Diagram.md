# Entity Relationship Diagram
## Banking Customer Loyalty & Churn Analysis Data Warehouse

---

## Star Schema Overview

```mermaid
erDiagram
    Dim_Date ||--o{ Fact_Transaction : "DateKey"
    Dim_Date ||--o{ Fact_CustomerSnapshot : "DateKey"
    
    Dim_Customer ||--o{ Fact_Transaction : "CustomerKey"
    Dim_Customer ||--o{ Fact_CustomerSnapshot : "CustomerKey"
    
    Dim_Location ||--o{ Fact_Transaction : "LocationKey"
    Dim_Location ||--o{ Dim_Customer : "LocationKey"
    
    Dim_Segment ||--o{ Fact_CustomerSnapshot : "SegmentKey"

    Dim_Date {
        int DateKey PK
        datetime FullDateTime
        date Date
        int Year
        int Quarter
        int Month
        nvarchar MonthName
        int Day
        int DayOfWeek
        nvarchar DayName
        bit IsWeekend
        bit IsWorkingDay
        int Hour
        varchar TimeOfDay
    }

    Dim_Customer {
        int CustomerKey PK
        varchar CustomerID
        date DateOfBirth
        int Age
        varchar AgeGroup
        varchar Gender
        nvarchar Location "SCD Type 2"
        int LocationKey FK
        varchar CustomerType
        date FirstTransactionDate
        date StartDate "SCD"
        date EndDate "SCD"
        bit IsCurrent "SCD"
    }

    Dim_Location {
        int LocationKey PK
        varchar LocationCode
        nvarchar LocationName
        nvarchar City
        nvarchar State
        nvarchar Country
        nvarchar Region
        varchar LocationType
    }

    Dim_Segment {
        int SegmentKey PK
        varchar SegmentCode
        nvarchar SegmentName
        varchar SegmentType
        nvarchar Description
        int RecencyMin
        int RecencyMax
        int FrequencyMin
        int FrequencyMax
        int DisplayOrder
        bit IsActive
    }

    Fact_Transaction {
        bigint TransactionKey PK
        int CustomerKey FK
        int DateKey FK
        int LocationKey FK
        varchar TransactionID
        decimal TransactionAmount
        decimal AccountBalance
        int TransactionCount
    }

    Fact_CustomerSnapshot {
        bigint SnapshotKey PK
        int CustomerKey FK
        int DateKey FK
        int SegmentKey FK
        int TransactionCount
        decimal TotalTransactionAmount
        decimal AvgTransactionAmount
        int DaysSinceLastTransaction
        int RecencyScore
        int FrequencyScore
        decimal LoyaltyScore
        decimal SatisfactionScore
        bit ComplaintFlag
        bit ChurnFlag
        bit AtRiskFlag
        varchar TrendCategory
        decimal GrowthRate
    }
```

---

## Detailed Relationship Descriptions

### 1. Dim_Date Relationships

**To Fact_Transaction:**
- **Cardinality:** 1:Many
- **Description:** One date can have many transactions
- **Join:** `Fact_Transaction.DateKey = Dim_Date.DateKey`

**To Fact_CustomerSnapshot:**
- **Cardinality:** 1:Many
- **Description:** One date (end of month) can have many customer snapshots
- **Join:** `Fact_CustomerSnapshot.DateKey = Dim_Date.DateKey`

---

### 2. Dim_Customer Relationships

**To Fact_Transaction:**
- **Cardinality:** 1:Many (with SCD Type 2 consideration)
- **Description:** One customer version can have many transactions
- **Join:** `Fact_Transaction.CustomerKey = Dim_Customer.CustomerKey`
- **Special Note:** Must join based on transaction date falling within StartDate and EndDate

**To Fact_CustomerSnapshot:**
- **Cardinality:** 1:Many
- **Description:** One customer (current version) can have many monthly snapshots
- **Join:** `Fact_CustomerSnapshot.CustomerKey = Dim_Customer.CustomerKey WHERE IsCurrent = 1`

---

### 3. Dim_Location Relationships

**To Dim_Customer:**
- **Cardinality:** 1:Many
- **Description:** One location can have many customers (or customer versions)
- **Join:** `Dim_Customer.LocationKey = Dim_Location.LocationKey`

**To Fact_Transaction:**
- **Cardinality:** 1:Many
- **Description:** One location can have many transactions
- **Join:** `Fact_Transaction.LocationKey = Dim_Location.LocationKey`

---

### 4. Dim_Segment Relationships

**To Fact_CustomerSnapshot:**
- **Cardinality:** 1:Many
- **Description:** One segment can classify many customer snapshots
- **Join:** `Fact_CustomerSnapshot.SegmentKey = Dim_Segment.SegmentKey`

---

## SCD Type 2 Relationship (Dim_Customer)

### Visual Representation

```mermaid
graph TB
    subgraph "Dim_Customer - SCD Type 2"
        C1["CustomerKey: 1<br/>CustomerID: C001<br/>Location: Mumbai<br/>StartDate: 2020-01-01<br/>EndDate: 2023-07-14<br/>IsCurrent: 0"]
        C2["CustomerKey: 2<br/>CustomerID: C001<br/>Location: Delhi<br/>StartDate: 2023-07-15<br/>EndDate: NULL<br/>IsCurrent: 1"]
    end
    
    subgraph "Fact_Transaction"
        T1["Transaction<br/>Date: 2023-01-15<br/>CustomerKey: 1"]
        T2["Transaction<br/>Date: 2023-08-20<br/>CustomerKey: 2"]
    end
    
    T1 -->|Links to Mumbai version| C1
    T2 -->|Links to Delhi version| C2
    
    style C1 fill:#ffcccc
    style C2 fill:#ccffcc
```

### How SCD Type 2 Works

**Scenario:** Customer C001 moves from Mumbai to Delhi on 2023-07-15

**Before Move:**
```
CustomerKey | CustomerID | Location | StartDate  | EndDate | IsCurrent
1           | C001       | Mumbai   | 2020-01-01 | NULL    | 1
```

**After Move:**
```
CustomerKey | CustomerID | Location | StartDate  | EndDate    | IsCurrent
1           | C001       | Mumbai   | 2020-01-01 | 2023-07-14 | 0  ← Historical
2           | C001       | Delhi    | 2023-07-15 | NULL       | 1  ← Current
```

**Transaction Linking:**
- Transactions before 2023-07-15 → Link to CustomerKey=1 (Mumbai)
- Transactions after 2023-07-15 → Link to CustomerKey=2 (Delhi)

**SQL Join Pattern:**
```sql
SELECT *
FROM Fact_Transaction F
JOIN Dim_Customer C ON F.CustomerKey = C.CustomerKey
WHERE C.CustomerID = 'C001'
  AND F.TransactionDate BETWEEN C.StartDate AND ISNULL(C.EndDate, '9999-12-31')
```

---

## Data Flow Diagram

```mermaid
graph LR
    subgraph "Source"
        S1[CSV File<br/>1M+ Records]
    end
    
    subgraph "Staging"
        ST1[BankingSource DB<br/>RawTransactions]
    end
    
    subgraph "Data Warehouse - Dimensions"
        D1[Dim_Date<br/>Pre-populated]
        D2[Dim_Location<br/>Distinct Locations]
        D3[Dim_Customer<br/>SCD Type 2]
        D4[Dim_Segment<br/>RF Rules]
    end
    
    subgraph "Data Warehouse - Facts"
        F1[Fact_Transaction<br/>Transaction-level]
        F2[Fact_CustomerSnapshot<br/>Monthly Aggregates]
    end
    
    S1 -->|Python Import| ST1
    ST1 -->|ETL Extract| D2
    ST1 -->|ETL Extract| D3
    ST1 -->|ETL Load| F1
    F1 -->|Aggregation| F2
    
    D1 -.->|Lookup| F1
    D2 -.->|Lookup| F1
    D3 -.->|Lookup| F1
    
    D1 -.->|Lookup| F2
    D3 -.->|Lookup| F2
    D4 -.->|Lookup| F2
    
    style S1 fill:#e1f5ff
    style ST1 fill:#fff4e1
    style D1 fill:#e8f5e9
    style D2 fill:#e8f5e9
    style D3 fill:#e8f5e9
    style D4 fill:#e8f5e9
    style F1 fill:#fff9c4
    style F2 fill:#fff9c4
```

---

## Fact Table Grain Comparison

```mermaid
graph TD
    subgraph "Fact_Transaction Grain"
        FT1[One row per transaction]
        FT2[High volume: 154M+ rows]
        FT3[Detailed analysis]
        FT4[Example: 5 transactions = 5 rows]
    end
    
    subgraph "Fact_CustomerSnapshot Grain"
        FS1[One row per customer per month]
        FS2[Medium volume: ~780K rows/month average]
        FS3[Trend analysis]
        FS4[Example: 5 customers, 1 month = 5 rows]
    end
    
    style FT1 fill:#ffebee
    style FS1 fill:#e3f2fd
```

---

## Index Strategy Visualization

```mermaid
graph TB
    subgraph "Dim_Customer Indexes"
        IDX1["Clustered Index:<br/>CustomerKey PK"]
        IDX2["Non-Clustered:<br/>CustomerID, IsCurrent"]
        IDX3["Filtered Index:<br/>CustomerID, IsCurrent<br/>WHERE IsCurrent=1"]
    end
    
    subgraph "Fact_Transaction Indexes"
        IDX4["Clustered Index:<br/>TransactionKey PK"]
        IDX5["Non-Clustered:<br/>CustomerKey"]
        IDX6["Non-Clustered:<br/>DateKey"]
        IDX7["Covering Index:<br/>CustomerKey, DateKey<br/>INCLUDE TransactionAmount"]
    end
    
    subgraph "Fact_CustomerSnapshot Indexes"
        IDX8["Clustered Index:<br/>SnapshotKey PK"]
        IDX9["Non-Clustered:<br/>CustomerKey, DateKey"]
        IDX10["Filtered Index:<br/>ChurnFlag WHERE ChurnFlag=1"]
        IDX11["Filtered Index:<br/>AtRiskFlag WHERE AtRiskFlag=1"]
    end
    
    style IDX1 fill:#c8e6c9
    style IDX4 fill:#fff9c4
    style IDX8 fill:#fff9c4
```

---

## Query Pattern Examples

### Pattern 1: Simple Dimension Lookup

```mermaid
graph LR
    Q1[Query] --> F1[Fact_Transaction]
    F1 --> D1[Dim_Date]
    F1 --> D2[Dim_Customer]
    
    style Q1 fill:#e1f5ff
    style F1 fill:#fff9c4
    style D1 fill:#e8f5e9
    style D2 fill:#e8f5e9
```

**SQL:**
```sql
SELECT 
    D.MonthName,
    C.AgeGroup,
    SUM(F.TransactionAmount) AS Total
FROM Fact_Transaction F
JOIN Dim_Date D ON F.DateKey = D.DateKey
JOIN Dim_Customer C ON F.CustomerKey = C.CustomerKey
WHERE D.Year = 2016
GROUP BY D.MonthName, C.AgeGroup;
```

---

### Pattern 2: Snapshot Trend Analysis

```mermaid
graph LR
    Q2[Query] --> F2[Fact_CustomerSnapshot]
    F2 --> D1[Dim_Date]
    F2 --> D3[Dim_Segment]
    
    style Q2 fill:#e1f5ff
    style F2 fill:#fff9c4
    style D1 fill:#e8f5e9
    style D3 fill:#e8f5e9
```

**SQL:**
```sql
SELECT 
    D.YearMonth,
    S.SegmentName,
    AVG(F.LoyaltyScore) AS AvgLoyalty,
    COUNT(DISTINCT F.CustomerKey) AS CustomerCount
FROM Fact_CustomerSnapshot F
JOIN Dim_Date D ON F.DateKey = D.DateKey
JOIN Dim_Segment S ON F.SegmentKey = S.SegmentKey
GROUP BY D.YearMonth, S.SegmentName
ORDER BY D.YearMonth;
```

---

## Cardinality Summary

| Relationship | Cardinality | Description |
|--------------|-------------|-------------|
| Dim_Date → Fact_Transaction | 1:Many | One date, many transactions |
| Dim_Date → Fact_CustomerSnapshot | 1:Many | One month-end date, many snapshots |
| Dim_Customer → Fact_Transaction | 1:Many | One customer version, many transactions |
| Dim_Customer → Fact_CustomerSnapshot | 1:Many | One customer, many monthly snapshots |
| Dim_Location → Fact_Transaction | 1:Many | One location, many transactions |
| Dim_Location → Dim_Customer | 1:Many | One location, many customers |
| Dim_Segment → Fact_CustomerSnapshot | 1:Many | One segment, many customer-months |

---
## Actual Data Volumes (As of December 2025)

| Table | Rows Loaded | Date Range | Source |
|-------|-------------|------------|--------|
| Dim_Date | 5,844 | 2015-2030 | Pre-populated |
| Dim_Location | 9,021 | - | Package 2 |
| Dim_Customer | 884,265 | - | Package 3 |
| Dim_Segment | 7 | - | Pre-populated |
| Fact_Transaction | 154,777,534 | 2015-01 to 2016-08 | Package 4 |
| Fact_CustomerSnapshot | 15,581,079 | 2015-01 to 2016-08 | Package 5 |

**Total DW Size:** ~17 GB (including indexes)

---

## Referential Integrity

All relationships are enforced through:
- ✅ Foreign Key Constraints (at database level)
- ✅ ETL Lookup Transformations (in SSIS)
- ✅ NULL handling for optional relationships

**Cascading Rules:**
- No CASCADE DELETE (data warehouse principle: never delete facts)
- No CASCADE UPDATE on surrogate keys
- Orphan prevention through ETL validation

---

## Legend

```mermaid
graph LR
    PK["Primary Key PK"]
    FK["Foreign Key FK"]
    SCD["SCD Type 2 Attribute"]
    
    style PK fill:#ffcccc
    style FK fill:#ccccff
    style SCD fill:#ffffcc
```

---

**Document Version:** 1.1  
**Last Updated:** December 2025  
**Tool:** Mermaid.js  

**Implementation Status:**
- ✅ Physical Schema: Created (Phase 2)
- ✅ Data Loaded: All tables populated (Phase 5)
  - Dim_Date: 5,844 rows
  - Dim_Location: 9,021 rows
  - Dim_Customer: 884,265 rows (SCD Type 2 ready)
  - Dim_Segment: 7 segments
  - Fact_Transaction: 154,777,534 rows
  - Fact_CustomerSnapshot: 15,581,079 rows

**GitHub Rendering:** Automatic via Mermaid.js
