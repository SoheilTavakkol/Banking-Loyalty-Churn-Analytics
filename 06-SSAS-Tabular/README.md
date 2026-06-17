# Phase 6: SSAS Tabular Model — v2.0

## Status
✅ **COMPLETED** — Redesigned for multi-level dashboard support

---

## Critical Data Context

| Property | Value |
|----------|-------|
| First month with data | 2015-01 |
| Last month with data | **2016-08-31** |
| Months with data | 20 |
| Dim_Date range | 2015-01-01 to **2030-12-31** |
| **Risk** | Any measure using `MAX(Dim_Date[Date])` returns 2030-12-31 — **wrong** |
| **Fix** | Always anchor to `MAX(Fact_CustomerSnapshot[DateKey])` |

All DAX measures in this model use `[_LastDataMonth]` as the anchor — never Dim_Date max.

---

## Project Information

- **Model Name:** BankingTabularModel
- **Compatibility Level:** 1600 (SQL Server 2022)
- **Target Database:** BankingTabularModel
- **Data Source:** BankingDW
- **Deployment Server:** localhost\SSAS_Tabular

---

## Tables Imported (5)

| Table | Filter | Rows |
|-------|--------|------|
| DW.Dim_Date | All rows | 5,844 |
| DW.Dim_Customer | `WHERE IsCurrent = 1` | 884,225 |
| DW.Dim_Location | All rows | 9,354 |
| DW.Dim_Segment | `WHERE IsActive = 1` | 7 |
| DW.Fact_CustomerSnapshot | All rows | 13,051,115 |

> Fact_Transaction is **not imported** into the Tabular model — all transaction-level metrics are pre-aggregated in Fact_CustomerSnapshot.

---

## Relationships (4)

All relationships: Many-to-One, Single direction, Active

| From | To | Column |
|------|----|--------|
| Fact_CustomerSnapshot | Dim_Customer | CustomerKey |
| Fact_CustomerSnapshot | Dim_Date | DateKey |
| Fact_CustomerSnapshot | Dim_Segment | SegmentKey |
| Dim_Customer | Dim_Location | LocationKey |

---

## Calculated Columns

Add these columns directly in the Tabular model — they do not exist in the DW.

### In Dim_Date

```dax
-- MonthLabel: for axis labels in charts
MonthLabel = FORMAT(Dim_Date[Date], "MMM-YY")

-- MonthSort: numeric sort for MonthLabel
MonthSort = Dim_Date[Year] * 100 + Dim_Date[Month]
```

### In Fact_CustomerSnapshot

```dax
-- RecencyBucket: human-readable recency band
RecencyBucket =
SWITCH(
    TRUE(),
    Fact_CustomerSnapshot[DaysSinceLastTransaction] <= 30,  "0-30 days",
    Fact_CustomerSnapshot[DaysSinceLastTransaction] <= 60,  "31-60 days",
    Fact_CustomerSnapshot[DaysSinceLastTransaction] <= 90,  "61-90 days",
    Fact_CustomerSnapshot[DaysSinceLastTransaction] <= 180, "91-180 days",
    "180+ days"
)

-- LoyaltyBand: for segmenting loyalty score
LoyaltyBand =
SWITCH(
    TRUE(),
    Fact_CustomerSnapshot[LoyaltyScore] >= 4.0, "High (4-5)",
    Fact_CustomerSnapshot[LoyaltyScore] >= 2.5, "Medium (2.5-4)",
    "Low (<2.5)"
)

-- GrowthCategory: simplified trend
GrowthCategory =
SWITCH(
    TRUE(),
    Fact_CustomerSnapshot[ChurnFlag] = 1,   "Churned",
    Fact_CustomerSnapshot[GrowthRate] > 20,  "Growing",
    Fact_CustomerSnapshot[GrowthRate] < -20, "Declining",
    "Stable"
)
```

---

## DAX Measures

### Foundation (hidden — used internally)

```dax
_LastDataDateKey =
MAXX(ALL(Fact_CustomerSnapshot), Fact_CustomerSnapshot[DateKey])

_LastDataMonth =
CALCULATE(
    MAX(Dim_Date[YearMonth]),
    Dim_Date[DateKey] = [_LastDataDateKey]
)

_PrevDataDateKey =
VAR AllKeys = VALUES(Fact_CustomerSnapshot[DateKey])
VAR MaxKey   = [_LastDataDateKey]
RETURN MAXX(FILTER(ALL(Fact_CustomerSnapshot), Fact_CustomerSnapshot[DateKey] < MaxKey), Fact_CustomerSnapshot[DateKey])
```

---

### Display Folder 1 — Customer Metrics

```dax
Total Customers =
CALCULATE(
    DISTINCTCOUNT(Fact_CustomerSnapshot[CustomerKey]),
    Dim_Date[DateKey] = [_LastDataDateKey]
)

Active Customers =
CALCULATE(
    DISTINCTCOUNT(Fact_CustomerSnapshot[CustomerKey]),
    Dim_Date[DateKey] = [_LastDataDateKey],
    Fact_CustomerSnapshot[ChurnFlag] = 0,
    Fact_CustomerSnapshot[AtRiskFlag] = 0
)

Active Customer Rate =
DIVIDE([Active Customers], [Total Customers])

New Customers This Month =
CALCULATE(
    DISTINCTCOUNT(Fact_CustomerSnapshot[CustomerKey]),
    Dim_Date[DateKey] = [_LastDataDateKey],
    Fact_CustomerSnapshot[TrendCategory] = "New"
)

Customer Growth MoM =
VAR ThisMonth =
    CALCULATE(
        DISTINCTCOUNT(Fact_CustomerSnapshot[CustomerKey]),
        Dim_Date[DateKey] = [_LastDataDateKey]
    )
VAR PrevMonth =
    CALCULATE(
        DISTINCTCOUNT(Fact_CustomerSnapshot[CustomerKey]),
        Dim_Date[DateKey] = [_PrevDataDateKey]
    )
RETURN DIVIDE(ThisMonth - PrevMonth, PrevMonth)
```

---

### Display Folder 2 — Churn & Retention

```dax
Churned Customers =
CALCULATE(
    DISTINCTCOUNT(Fact_CustomerSnapshot[CustomerKey]),
    Dim_Date[DateKey] = [_LastDataDateKey],
    Fact_CustomerSnapshot[ChurnFlag] = 1
)

Churn Rate =
DIVIDE([Churned Customers], [Total Customers])

Retention Rate =
1 - [Churn Rate]

At-Risk Customers =
CALCULATE(
    DISTINCTCOUNT(Fact_CustomerSnapshot[CustomerKey]),
    Dim_Date[DateKey] = [_LastDataDateKey],
    Fact_CustomerSnapshot[AtRiskFlag] = 1
)

At-Risk Rate =
DIVIDE([At-Risk Customers], [Total Customers])

Churn Rate MoM Change =
VAR ThisChurn =
    CALCULATE(
        DIVIDE(
            CALCULATE(COUNTROWS(Fact_CustomerSnapshot), Fact_CustomerSnapshot[ChurnFlag] = 1),
            COUNTROWS(Fact_CustomerSnapshot)
        ),
        Dim_Date[DateKey] = [_LastDataDateKey]
    )
VAR PrevChurn =
    CALCULATE(
        DIVIDE(
            CALCULATE(COUNTROWS(Fact_CustomerSnapshot), Fact_CustomerSnapshot[ChurnFlag] = 1),
            COUNTROWS(Fact_CustomerSnapshot)
        ),
        Dim_Date[DateKey] = [_PrevDataDateKey]
    )
RETURN ThisChurn - PrevChurn

Churn Rate Trend =
CALCULATE(
    DIVIDE(
        CALCULATE(COUNTROWS(Fact_CustomerSnapshot), Fact_CustomerSnapshot[ChurnFlag] = 1),
        COUNTROWS(Fact_CustomerSnapshot)
    )
)
-- Use this measure in a line chart with Dim_Date[MonthLabel] on axis
-- It respects filter context → shows monthly trend automatically
```

---

### Display Folder 3 — Loyalty & Satisfaction

```dax
Avg Loyalty Score =
CALCULATE(
    AVERAGE(Fact_CustomerSnapshot[LoyaltyScore]),
    Dim_Date[DateKey] = [_LastDataDateKey]
)

Avg Satisfaction Score =
CALCULATE(
    AVERAGE(Fact_CustomerSnapshot[SatisfactionScore]),
    Dim_Date[DateKey] = [_LastDataDateKey]
)

Avg Recency Days =
CALCULATE(
    AVERAGE(Fact_CustomerSnapshot[DaysSinceLastTransaction]),
    Dim_Date[DateKey] = [_LastDataDateKey]
)

Loyalty Score Trend =
AVERAGE(Fact_CustomerSnapshot[LoyaltyScore])
-- Use in line chart with MonthLabel on axis

Loyalty MoM Change =
VAR This = CALCULATE(AVERAGE(Fact_CustomerSnapshot[LoyaltyScore]), Dim_Date[DateKey] = [_LastDataDateKey])
VAR Prev = CALCULATE(AVERAGE(Fact_CustomerSnapshot[LoyaltyScore]), Dim_Date[DateKey] = [_PrevDataDateKey])
RETURN This - Prev
```

---

### Display Folder 4 — Transactions

```dax
Total Transaction Amount =
SUM(Fact_CustomerSnapshot[TotalTransactionAmount])

Total Transaction Amount (Latest Month) =
CALCULATE(
    SUM(Fact_CustomerSnapshot[TotalTransactionAmount]),
    Dim_Date[DateKey] = [_LastDataDateKey]
)

Avg Transaction Amount =
CALCULATE(
    AVERAGE(Fact_CustomerSnapshot[AvgTransactionAmount]),
    Dim_Date[DateKey] = [_LastDataDateKey]
)

Total Transactions =
CALCULATE(
    SUM(Fact_CustomerSnapshot[TransactionCount]),
    Dim_Date[DateKey] = [_LastDataDateKey]
)

Avg Transactions Per Customer =
DIVIDE([Total Transactions], [Total Customers])

Transaction Volume Trend =
SUM(Fact_CustomerSnapshot[TransactionCount])
-- Use in line chart with MonthLabel on axis
```

---

### Display Folder 5 — Behavior & Growth

```dax
Customers with Complaints =
CALCULATE(
    COUNTROWS(Fact_CustomerSnapshot),
    Dim_Date[DateKey] = [_LastDataDateKey],
    Fact_CustomerSnapshot[ComplaintFlag] = 1
)

Complaint Rate =
DIVIDE([Customers with Complaints], [Total Customers])

Avg Growth Rate =
CALCULATE(
    AVERAGEX(
        FILTER(Fact_CustomerSnapshot, NOT ISBLANK(Fact_CustomerSnapshot[GrowthRate])),
        Fact_CustomerSnapshot[GrowthRate]
    ),
    Dim_Date[DateKey] = [_LastDataDateKey]
)

Growing Customers =
CALCULATE(
    COUNTROWS(Fact_CustomerSnapshot),
    Dim_Date[DateKey] = [_LastDataDateKey],
    Fact_CustomerSnapshot[GrowthCategory] = "Growing"
)

Declining Customers =
CALCULATE(
    COUNTROWS(Fact_CustomerSnapshot),
    Dim_Date[DateKey] = [_LastDataDateKey],
    Fact_CustomerSnapshot[GrowthCategory] = "Declining"
)
```

---

### Display Folder 6 — Segments

```dax
Customer Count by Segment =
CALCULATE(
    DISTINCTCOUNT(Fact_CustomerSnapshot[CustomerKey]),
    Dim_Date[DateKey] = [_LastDataDateKey]
)
-- Use with Dim_Segment[SegmentName] on rows/axis

Segment Share =
DIVIDE(
    [Customer Count by Segment],
    CALCULATE([Customer Count by Segment], REMOVEFILTERS(Dim_Segment))
)

Champions Count =
CALCULATE(
    [Customer Count by Segment],
    Dim_Segment[SegmentCode] = "RF_Champions"
)

Churned Segment Count =
CALCULATE(
    [Customer Count by Segment],
    Dim_Segment[SegmentCode] = "RF_Churned"
)

Segment Migration (Month) =
-- Customers who were in a different segment last month vs this month
-- Use this in the Analyst dashboard for segment movement analysis
VAR ThisMonth =
    CALCULATETABLE(
        SELECTCOLUMNS(Fact_CustomerSnapshot, "CK", Fact_CustomerSnapshot[CustomerKey], "Seg", Fact_CustomerSnapshot[SegmentKey]),
        Dim_Date[DateKey] = [_LastDataDateKey]
    )
VAR PrevMonth =
    CALCULATETABLE(
        SELECTCOLUMNS(Fact_CustomerSnapshot, "CK", Fact_CustomerSnapshot[CustomerKey], "Seg", Fact_CustomerSnapshot[SegmentKey]),
        Dim_Date[DateKey] = [_PrevDataDateKey]
    )
RETURN
    COUNTROWS(
        FILTER(
            NATURALINNERJOIN(ThisMonth, SELECTCOLUMNS(PrevMonth, "CK", [CK], "PrevSeg", [Seg])),
            [Seg] <> [PrevSeg]
        )
    )
```

---

### Display Folder 7 — NPS

```dax
Promoters =
CALCULATE(
    COUNTROWS(Fact_CustomerSnapshot),
    Dim_Date[DateKey] = [_LastDataDateKey],
    Fact_CustomerSnapshot[SatisfactionScore] >= 4
)

Detractors =
CALCULATE(
    COUNTROWS(Fact_CustomerSnapshot),
    Dim_Date[DateKey] = [_LastDataDateKey],
    Fact_CustomerSnapshot[SatisfactionScore] <= 2
)

NPS Score =
DIVIDE([Promoters] - [Detractors], [Total Customers])

NPS Trend =
DIVIDE(
    CALCULATE(COUNTROWS(FILTER(Fact_CustomerSnapshot, Fact_CustomerSnapshot[SatisfactionScore] >= 4))) -
    CALCULATE(COUNTROWS(FILTER(Fact_CustomerSnapshot, Fact_CustomerSnapshot[SatisfactionScore] <= 2))),
    COUNTROWS(Fact_CustomerSnapshot)
)
-- Use in line chart with MonthLabel on axis
```

---

## Dashboard Mapping

### Dashboard 1 — Executive Overview (C-Level)
**Audience:** CEO, CFO, Board
**Question answered:** "Is the bank growing or losing customers? What's the churn risk?"

| Measure | Visual |
|---------|--------|
| Total Customers | KPI card |
| Churn Rate | KPI card + MoM change indicator |
| Retention Rate | KPI card |
| Avg Loyalty Score | KPI card + MoM change |
| NPS Score | KPI card |
| Churn Rate Trend | Line chart (20 months) |
| Loyalty Score Trend | Line chart (20 months) |
| Customer Count by Segment | Donut chart |
| Transaction Volume Trend | Bar chart (20 months) |

**Filter:** No date slicer (always shows latest month + trend lines across all months)

---

### Dashboard 2 — CRM & Retention (Middle Management)
**Audience:** Head of Retail Banking, CRM Manager
**Question answered:** "Which customers are at risk? Where should we focus retention effort?"

| Measure | Visual |
|---------|--------|
| At-Risk Customers | KPI card |
| At-Risk Rate | KPI card |
| Churned Customers | KPI card |
| Churn Rate MoM Change | KPI card with arrow indicator |
| Customer Count by Segment | Bar chart (all 7 segments) |
| Segment Share | % bar |
| Segment Migration (Month) | Single number card |
| Avg Recency Days by Segment | Bar chart |
| Complaint Rate | KPI card |

**Filter:** Month slicer (Dim_Date[YearMonth]), Segment slicer

---

### Dashboard 3 — Analyst / Operational Detail
**Audience:** Data Analyst, Branch Manager
**Question answered:** "How is each segment performing month over month? Where are growth/decline patterns?"

| Measure | Visual |
|---------|--------|
| Churn Rate Trend | Line chart by segment (small multiples) |
| Loyalty Score Trend | Line chart — all months |
| NPS Trend | Line chart — all months |
| Avg Growth Rate by Segment | Bar chart |
| Growing vs Declining Customers | Stacked bar |
| Transaction Volume Trend | Line chart |
| Avg Transactions Per Customer by Segment | Bar chart |
| Customers with Complaints by Segment | Bar chart |

**Filter:** Month range slicer, Segment slicer, Location slicer (via Dim_Location[Region])

---

### Dashboard 4 — Geographic / Marketing
**Audience:** Marketing, Regional Managers
**Question answered:** "Which locations have the highest churn? Where are loyal customers concentrated?"

| Measure | Visual |
|---------|--------|
| Total Customers by Location | Map or bar chart |
| Churn Rate by Location | Bar chart (top 20) |
| Avg Loyalty Score by Location | Heatmap / bar |
| NPS Score by Location | Bar chart |
| Active Customer Rate by Location | Bar chart |

**Filter:** Month slicer, Segment slicer, Region slicer (Dim_Location[Region])

> **Note:** Most locations have State/Region = "Unknown" — filter to known regions or use LocationName directly for the top-N locations with data.

---

## Hidden Columns (Technical)

Hide all of the following from report view:

**Dim_Customer:** CustomerKey, LocationKey, StartDate, EndDate, IsCurrent, CreatedDate, ModifiedDate
**Dim_Date:** DateKey, all IsXxx flags except IsWeekend, CreatedDate
**Dim_Location:** LocationKey, CreatedDate, ModifiedDate, Latitude, Longitude
**Dim_Segment:** SegmentKey, RecencyMin, RecencyMax, FrequencyMin, FrequencyMax, StartDate, EndDate, CreatedDate, ModifiedDate
**Fact_CustomerSnapshot:** All FK columns (CustomerKey, DateKey, SegmentKey), ETLLoadDate, ETLBatchID, RecencyScore, FrequencyScore (use LoyaltyScore instead)

---

## Calendar Hierarchy

Mark `Dim_Date` as Date Table using `Dim_Date[Date]`.

```
📅 Calendar
  └── Year (Dim_Date[Year])
      └── Quarter (Dim_Date[QuarterName])
          └── Month (Dim_Date[MonthLabel])   ← sort by MonthSort
              └── Date (Dim_Date[Date])
```

---

## Measure Format Strings

| Measure | Format |
|---------|--------|
| Total Customers, Active Customers, etc. | `#,##0` |
| Churn Rate, Retention Rate, Active Customer Rate, etc. | `0.00%` |
| Avg Loyalty Score, Avg Satisfaction Score | `0.00` |
| Total Transaction Amount | `#,##0` (INR, no $ symbol) |
| Avg Transaction Amount | `#,##0.00` |
| NPS Score | `0.0%` |
| MoM Change measures | `+0.00%;-0.00%;0.00%` |
| Avg Recency Days | `#,##0.0` |

---

## Verified Baseline (Aug 2016 — Last Month)

| Measure | Value |
|---------|-------|
| Total Customers | 831,639 |
| Churned Customers | 131,041 |
| Churn Rate | 15.76% |
| At-Risk Customers | 8,275 |
| At-Risk Rate | 1.00% |
| Avg Loyalty Score | 3.21 |

---

**Document Version:** 2.0
**Last Updated:** June 2026
**Status:** ✅ COMPLETED
**Author:** Soheil Tavakkol
