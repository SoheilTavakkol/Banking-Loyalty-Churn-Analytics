# Phase 6: SSAS Tabular Model — v3.0

## Status
✅ **COMPLETED** — Deployed and verified

---

## Critical Data Context

| Property | Value |
|----------|-------|
| First month with data | 2015-01 |
| Last month with data | **2016-08-31** |
| Months with data | 20 |
| Dim_Date range | 2015-01-01 to **2030-12-31** |
| **Risk** | Any measure using `MAX(Dim_Date[Date])` without filtering to actual data returns 2030-12-31 — **wrong** |
| **Fix** | All measures anchor to `[_LastDataDateKey]`, derived from `MAX(Fact_CustomerSnapshot[DateKey])` — never from `Dim_Date` alone |

---

## Project Information

- **Model Name:** BankingLoyaltyChurn
- **Compatibility Level:** 1600 (SQL Server 2022)
- **Target Database:** BankingTabularModel
- **Data Source:** BankingDW (SQL/.;BankingDW)
- **Deployment Server:** localhost\SSAS_Tabular
- **Data Source Credentials:** Windows (`NT Service\MSOLAP$SSAS_TABULAR`) — granted `db_datareader` on BankingDW

---

## Tables Imported & Deployed (5)

| Table | Filter | Rows Transferred (verified) |
|-------|--------|------------------------------|
| Dim_Date | All rows | 5,844 |
| Dim_Customer | `WHERE IsCurrent = 1` | 1,169,677* |
| Dim_Location | All rows | 9,354 |
| Dim_Segment | `WHERE IsActive = 1` | 7 |
| Fact_CustomerSnapshot | All rows | 13,051,115 |

*\*Deploy log shows 1,169,677 — this is the full Dim_Customer row count. If the `IsCurrent = 1` filter is intended (884,225 expected), verify the Power Query filter step is still applied; otherwise historical SCD rows are being imported alongside current ones.*

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

## Date Table Configuration

`Dim_Date` marked as Date Table (`Mark as Date Table`) using `Dim_Date[Date]` — done immediately after table import, before any measure development.

### Calendar Hierarchy

```
📅 Calendar
  └── Year
      └── Quarter Name
          └── Month Name (sorted by MonthSort)
              └── Date
```

---

## Column Naming

All columns renamed with spaces (e.g. `CustomerKey` → `Customer Key`, `ChurnFlag` → `Churn Flag`) across all 5 tables, consistent with the naming convention used throughout the measures below.

---

## Calculated Columns

### Dim_Date

```dax
MonthLabel := FORMAT(Dim_Date[Date], "MMM-YY")
MonthSort  := Dim_Date[Year] * 100 + Dim_Date[Month Number]
```

### Fact_CustomerSnapshot

```dax
RecencyBucket :=
SWITCH(
    TRUE(),
    Fact_CustomerSnapshot[Days Since Last Transaction] <= 30,  "0-30 days",
    Fact_CustomerSnapshot[Days Since Last Transaction] <= 60,  "31-60 days",
    Fact_CustomerSnapshot[Days Since Last Transaction] <= 90,  "61-90 days",
    Fact_CustomerSnapshot[Days Since Last Transaction] <= 180, "91-180 days",
    "180+ days"
)

LoyaltyBand :=
SWITCH(
    TRUE(),
    Fact_CustomerSnapshot[Loyalty Score] >= 4.0, "High (4-5)",
    Fact_CustomerSnapshot[Loyalty Score] >= 2.5, "Medium (2.5-4)",
    "Low (<2.5)"
)

GrowthCategory :=
SWITCH(
    TRUE(),
    Fact_CustomerSnapshot[Churn Flag] = 1,   "Churned",
    Fact_CustomerSnapshot[Growth Rate] > 20, "Growing",
    Fact_CustomerSnapshot[Growth Rate] < -20,"Declining",
    "Stable"
)
```

Calculated columns were built **before** measures, so all measures referencing `GrowthCategory` (Growing/Declining Customers) had a valid column to filter on from the start.

---

## Hidden Columns

Applied across all tables — technical/audit/FK columns are hidden from report view:

**Dim_Customer:** Customer Key, LocationKey, StartDate, EndDate, Is Current, CreatedDate, ModifiedDate
**Dim_Date:** DateKey, IsCurrentMonth, IsCurrentYear, CreatedDate
**Dim_Location:** LocationKey, CreatedDate, ModifiedDate, Latitude, Longitude
**Dim_Segment:** SegmentKey, Recency Min, Recency Max, Frequency Min, Frequency Max, StartDate, EndDate, CreatedDate, ModifiedDate
**Fact_CustomerSnapshot:** Customer Key, DateKey, SegmentKey, ETLLoadDate, ETLBatchID, Recency Score, Frequency Score

---

## DAX Measures (39 total)

All measures live in a dedicated `_Measures` table. All measures use `:=` syntax (SSAS Tabular requirement, different from Power BI's `=`).

### Foundation (hidden)

```dax
_LastDataDateKey:= MAXX(ALL(Fact_CustomerSnapshot), Fact_CustomerSnapshot[DateKey])

_LastDataMonth:= 
VAR MaxKey = [_LastDataDateKey]
RETURN CALCULATE(MAX(Dim_Date[Year Month]), Dim_Date[DateKey] = MaxKey)

_PrevDataDateKey:= 
VAR MaxKey = [_LastDataDateKey] 
RETURN MAXX(FILTER(ALL(Fact_CustomerSnapshot), Fact_CustomerSnapshot[DateKey] < MaxKey), Fact_CustomerSnapshot[DateKey])
```

### Customer Metrics (7)
Total Customers, Active Customers, Active Customer Rate, New Customers This Month, Customer Growth MoM, Customer Growth QoQ, Customer Growth YoY

### Churn & Retention (7)
Churned Customers, Churn Rate, Retention Rate, At-Risk Customers, At-Risk Rate, Churn Rate MoM Change, Churn Rate Trend, Churn Rate QoQ Change, Churn Rate YoY Change

### Loyalty & Satisfaction (6)
Avg Loyalty Score, Avg Satisfaction Score, Avg Recency Days, Loyalty Score Trend, Loyalty MoM Change, Loyalty QoQ Change, Loyalty YoY Change

### Transactions (6)
Total Transaction Amount, Total Transaction Amount (Latest Month), Avg Transaction Amount, Total Transactions, Avg Transactions Per Customer, Transaction Volume Trend

### Behavior & Growth (5)
Customers with Complaints, Complaint Rate, Avg Growth Rate, Growing Customers, Declining Customers

### Segments (7)
Customer Count by Segment, Segment Share, Champions Count, Churned Segment Count, Segment Migration (Month), Segment Migration (Quarter), Segment Migration (Year)

### NPS (4)
Promoters, Detractors, NPS Score, NPS Trend

Full formula listing maintained in `Measures.txt` (project repo).

---

## Debugging Notes — Time Intelligence Pattern

Several QoQ/YoY measures (`Churn Rate QoQ/YoY Change`, `Loyalty QoQ/YoY Change`, `Segment Migration Quarter/Year`) initially failed with:
```
The value for '<measure>' cannot be determined. Either the column doesn't exist, or there is no current row for this column.
```

**Root cause:** `DATEADD()` was nested inside `CALCULATETABLE()` alongside a `DateKey =` filter on the same table:
```dax
-- BROKEN PATTERN
CALCULATETABLE(
    DATEADD(Dim_Date[Date], -3, MONTH),
    Dim_Date[DateKey] = MaxDateKey
)
```
`DATEADD` requires the full, unfiltered date timeline to walk backward through. Pre-filtering `Dim_Date` to a single row before calling `DATEADD` leaves it with nothing to traverse.

**Fix pattern** — resolve the target date as a scalar first, then filter directly:
```dax
VAR MaxDateValue   = CALCULATE(MAX(Dim_Date[Date]), Dim_Date[DateKey] = MaxDateKey)
VAR PrevQuarterDate = EOMONTH(MaxDateValue, -3)
VAR PrevQuarterChurn =
    CALCULATE(
        [Churn Rate Trend],
        REMOVEFILTERS(Dim_Date),
        Dim_Date[Date] = PrevQuarterDate
    )
```

**Note:** `Customer Growth QoQ/YoY` used a simpler, single-layer `CALCULATE(..., DATEADD(...))` pattern (no nested `CALCULATETABLE`) and worked correctly from the start — confirming the issue was specifically the nested nesting pattern, not `DATEADD` itself.

All affected measures were corrected and re-verified via direct DAX query in SSMS (Analysis Services connection) before deployment.

---

## Debugging Notes — Avg Growth Rate Percentage Scaling

`Avg Growth Rate` initially displayed as `4302.22%` instead of `43.02%`.

**Root cause:** `Fact_CustomerSnapshot[Growth Rate]` is stored in the DW as an already-scaled percentage (e.g. `25.00` = 25%), not as a fraction (`0.25`). DAX's `Percentage` format multiplies the underlying value by 100 for display, assuming a fraction. Without dividing by 100 in the measure, the double-scaling produced a 100x inflated result.

**Fix:**
```dax
Avg Growth Rate:= 
VAR MaxDate = [_LastDataDateKey]
RETURN
CALCULATE(
    AVERAGE(Fact_CustomerSnapshot[Growth Rate]),
    Dim_Date[DateKey] = MaxDate
) / 100
```

---

## Debugging Notes — Data Source Authentication

Process Database (Process Full) initially failed:
```
OLE DB or ODBC error: The credentials provided for the SQL source are invalid. (Source at .;BankingDW.)
```

**Root cause:** Data source credentials were set to `AuthenticationKind: ServiceAccount`, but the SSAS service account (`NT Service\MSOLAP$SSAS_TABULAR`) had no SQL Server login / database user on `BankingDW`.

**Fix (SQL Server, run as admin):**
```sql
USE master;
CREATE LOGIN [NT Service\MSOLAP$SSAS_TABULAR] FROM WINDOWS;

USE BankingDW;
CREATE USER [NT Service\MSOLAP$SSAS_TABULAR] FOR LOGIN [NT Service\MSOLAP$SSAS_TABULAR];
ALTER ROLE db_datareader ADD MEMBER [NT Service\MSOLAP$SSAS_TABULAR];
```

After granting `db_datareader`, Process Full succeeded.

---

## KPIs — Deferred to Power BI

SSAS Tabular native KPI objects (Base Measure + Target + Status thresholds) were **not** built in this model. Reason: Power BI does not render SSAS KPI status indicators (traffic-light visuals) — it only reads the Base Measure and Target value, discarding the threshold/status logic. Since Power BI is the final reporting layer (Phase 7), KPI threshold logic will be implemented there instead, either as status-returning DAX measures (e.g. `Churn Rate Status` returning "Good"/"Warning"/"Critical") or directly in Power BI's conditional formatting.

---

## Dashboard Mapping (for Phase 7 — Power BI)

### Dashboard 1 — Executive Overview (C-Level)
**Audience:** CEO, CFO, Board
Total Customers · Churn Rate · Retention Rate · Avg Loyalty Score · NPS Score · Churn Rate Trend (line) · Loyalty Score Trend (line) · Customer Count by Segment (donut) · Transaction Volume Trend (bar)
**Filter:** None (always latest month + full trend lines)

### Dashboard 2 — CRM & Retention (Middle Management)
**Audience:** Head of Retail Banking, CRM Manager
At-Risk Customers · At-Risk Rate · Churned Customers · Churn Rate MoM/QoQ/YoY Change · Customer Count by Segment (bar) · Segment Share · Segment Migration (Month/Quarter/Year) · Avg Recency Days · Complaint Rate
**Filter:** Month slicer, Segment slicer

### Dashboard 3 — Analyst / Operational Detail
**Audience:** Data Analyst, Branch Manager
Churn Rate Trend by segment · Loyalty Score Trend · NPS Trend · Avg Growth Rate by segment · Growing vs Declining Customers · Transaction Volume Trend · Avg Transactions Per Customer by segment
**Filter:** Month range slicer, Segment slicer, Location/Region slicer

### Dashboard 4 — Geographic / Marketing
**Audience:** Marketing, Regional Managers
Total Customers by Location · Churn Rate by Location · Avg Loyalty Score by Location · NPS Score by Location · Active Customer Rate by Location
**Filter:** Month slicer, Segment slicer, Region slicer

> Most locations have State/Region = "Unknown" — use top-N LocationName directly, or filter to enriched regions only.

---

## Measure Format Strings

| Measure type | Format |
|---|---|
| Counts (Total Customers, Churned Customers, etc.) | `#,##0` |
| Rates (Churn Rate, Retention Rate, At-Risk Rate, etc.) | `0.00%` |
| Avg Loyalty/Satisfaction Score | `0.00` |
| Total Transaction Amount | `#,##0` (INR, no symbol) |
| Avg Transaction Amount | `#,##0.00` |
| NPS Score, NPS Trend | `0.0%` |
| MoM/QoQ/YoY Change measures | `+0.00%;-0.00%;0.00%` |
| Avg Recency Days | `#,##0.0` |
| Avg Growth Rate | `0.0%` (value pre-divided by 100 in formula) |

---

## Verified Deployment (Jun 2026)

| Object | Rows Transferred |
|---|---|
| Dim_Date | 5,844 |
| Dim_Location | 9,354 |
| Dim_Segment | 7 |
| Dim_Customer | 1,169,677 |
| Fact_CustomerSnapshot | 13,051,115 |
| _Measures | 1 (sample row) |

**Deploy result:** 7 Total, 7 Success, 0 Error.

### Baseline KPI values (Aug 2016 — latest month)

| Measure | Value |
|---|---|
| Total Customers | 831,639 |
| Churned Customers | 131,041 |
| Churn Rate | 15.76% |
| At-Risk Customers | 8,275 |
| At-Risk Rate | 1.00% |
| Avg Loyalty Score | 3.21 |

---

**Document Version:** 3.0
**Last Updated:** June 2026
**Status:** ✅ COMPLETED — Deployed and verified
**Author:** Soheil Tavakkol
