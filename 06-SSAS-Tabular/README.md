# Phase 6: SSAS Tabular Model — v3.1 (Final)

## Status
✅ **COMPLETED** — Deployed and verified. This revision corrects two open items from v3.0 (see Revision Notes) and replaces the Phase-6-era dashboard plan with the dashboards actually delivered in Phase 7.

## Revision Notes (v3.0 → v3.1)

1. **Dim_Customer import row count resolved.** v3.0 flagged an open question: the deploy log showed 1,169,677 rows (the full table) and asked whether the `IsCurrent = 1` Power Query filter was actually applied, since 884,225 was expected. **Confirmed:** the filter was applied correctly — the model imports only current-version customers. The 1,169,677 figure in the old table was a copy-paste of `Dim_Customer`'s total row count from the source database, not the actual Tabular import count. Corrected below.
2. **Measure count corrected from 39 to 45.** Counting the measures actually listed by category in v3.0 gives 45, not 39 (two of the seven category headers undercounted their own listed items). This document now states the true count and flags that the "39 measures" figure quoted in the main project README and Data Dictionary predates this final build and should be updated to 45 in those files.
3. **Dashboard Mapping section replaced.** v3.0's section described a *planned* 4-dashboard layout for Phase 7 (Executive, CRM & Retention, Analyst, Geographic/Marketing). Phase 7 is now complete and only **3** dashboards were actually built (Executive, Marketing, CRM & Retention); the Analyst and standalone Geographic dashboards were descoped. The section below now documents what was actually delivered.

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
| Dim_Customer | `WHERE IsCurrent = 1` | **884,225** |
| Dim_Location | All rows | 9,354 |
| Dim_Segment | `WHERE IsActive = 1` | 7 |
| Fact_CustomerSnapshot | All rows | 13,051,115 |

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

## DAX Measures (45 total)

All measures live in a dedicated `_Measures` table. All measures use `:=` syntax (SSAS Tabular requirement, different from Power BI's `=`). Three additional hidden foundation measures (below) support the 45 report-facing measures but aren't counted in that total.

> **Correction from v3.0:** the earlier document header stated "39 total" while its own category breakdown (once counted item-by-item) sums to 45. The main project README and Data Dictionary still cite 39 and should be corrected to match this document, which is the authoritative source for the SSAS layer.

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

### Churn & Retention (9)
Churned Customers, Churn Rate, Retention Rate, At-Risk Customers, At-Risk Rate, Churn Rate MoM Change, Churn Rate Trend, Churn Rate QoQ Change, Churn Rate YoY Change

### Loyalty & Satisfaction (7)
Avg Loyalty Score, Avg Satisfaction Score, Avg Recency Days, Loyalty Score Trend, Loyalty MoM Change, Loyalty QoQ Change, Loyalty YoY Change

### Transactions (6)
Total Transaction Amount, Total Transaction Amount (Latest Month), Avg Transaction Amount, Total Transactions, Avg Transactions Per Customer, Transaction Volume Trend

### Behavior & Growth (5)
Customers with Complaints, Complaint Rate, Avg Growth Rate, Growing Customers, Declining Customers

### Segments (7)
Customer Count by Segment, Segment Share, Champions Count, Churned Segment Count, Segment Migration (Month), Segment Migration (Quarter), Segment Migration (Year)

### NPS (4)
Promoters, Detractors, NPS Score, NPS Trend

**Category total check:** 7 + 9 + 7 + 6 + 5 + 7 + 4 = **45**

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

**Note:** `Customer Growth QoQ/YoY` used a simpler, single-layer `CALCULATE(..., DATEADD(...))` pattern (no nested `CALCULATETABLE`) and worked correctly from the start — confirming the issue was specifically the nested pattern, not `DATEADD` itself.

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

SSAS Tabular native KPI objects (Base Measure + Target + Status thresholds) were **not** built in this model. Reason: Power BI does not render SSAS KPI status indicators (traffic-light visuals) — it only reads the Base Measure and Target value, discarding the threshold/status logic. Since Power BI is the final reporting layer, KPI threshold logic was implemented there instead, as status-returning DAX measures and Canvas KPI Card business targets — see the dashboards below.

---

## Dashboard Mapping — As Actually Delivered (Phase 7)

The plan drafted during Phase 6 called for four dashboards (Executive, CRM & Retention, Analyst, Geographic/Marketing). **Three were built; the Analyst dashboard was descoped, and the Geographic dashboard's location-based breakdowns were folded into the Marketing dashboard instead of standing alone.** All three dashboards connect via SSAS Tabular Live Connection and follow the same three-level layout: KPI Cards → Trend/Distribution → Deeper Breakdowns.

### 1. Executive Dashboard (CEO, CFO)
- **Level 1 (KPI cards):** Total Customers, Active Customers, Avg Loyalty Score, Churn Rate, Avg Transaction Amount, NPS Score
- **Level 2 (trend):** Total vs. Active Customers trend, Churn Rate vs. Loyalty Score Trend (combo), Transaction Volume vs. NPS Trend
- **Level 3 (breakdown):** Growing vs. Declining Customers by segment, Complaints Distribution (treemap), segment summary table (Customer Count, Total Transaction Amount, Trend)
- **Filter:** Year/Month slicers; KPI cards always resolve to the latest available month via `[_LastDataDateKey]`

### 2. Marketing Dashboard (Marketing, Regional Managers)
- **Level 1 (KPI cards, by lifecycle stage):** Acquisition (New Customers, New Customer Retention Rate) · Nurture (Potential Loyalists, Loyal Conversion Rate) · Win-Back (Hibernating Customers, Hibernating Rate)
- **Level 2 (trend):** New Customers by State (donut), Potential Volume & Conversion Rate (combo), Hibernating Rate Trend (area)
- **Level 3 (breakdown):** Loyal Conversions by State (donut), Potential → Loyal Funnel, Hibernating Customers by State (bar)
- **Note:** This is where the originally-planned standalone "Geographic Dashboard" ended up — location breakdowns (`Dim_Location[State]`) are used throughout this dashboard's Level 2/3 visuals rather than in a separate dashboard, since the marketing use case was the only one that consistently needed a State-level cut.

### 3. CRM & Retention Dashboard (Head of Retail, CRM Manager)
- **Level 1 (KPI cards):** Total Customers, Churn Rate %, Avg NPS, Hibernating Customers, Total Complaints, Complaints per 1K Customers
- **Level 2 (trend):** Satisfaction vs. Churn (combo), Complaints Volume Trend (area), Complaints by Segment (donut)
- **Level 3 (breakdown):** At-Risk vs. Lost (Churned) Customers trend, Churned Customers by State (bar), Active Segments Volume Trend (stacked area)

### Descoped: Analyst / Operational Detail Dashboard
Originally planned to cover Churn Rate Trend by segment, Loyalty Score Trend, NPS Trend, Avg Growth Rate by segment, and drill-through detail for Data Analysts / Branch Managers. **Not built.** All of the underlying measures required already exist in the 45-measure model above — building this dashboard later would be a pure Power BI exercise with no further SSAS or DAX work needed.

> Most locations have State/Region = "Unknown" (~99.7%) — the delivered Marketing and CRM dashboards' State-level visuals work with this reality by showing the top populated states plus an "Other" bucket, rather than filtering "Unknown" out.

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

> **Known custom-visual quirk (see Power BI documentation):** the Canvas KPI Card visual used on all three dashboards does not respect the `FormatString` metadata inherited from these live-connected SSAS measures. Rate-type KPI cards use dedicated `_disp` measures (×100, with an explicit `0.00"%"` format string applied in Power BI) as a workaround — this lives in the Power BI layer, not here, but is noted for anyone extending this model.

---

## Verified Deployment (Final)

| Object | Rows Transferred |
|---|---|
| Dim_Date | 5,844 |
| Dim_Location | 9,354 |
| Dim_Segment | 7 |
| Dim_Customer | 884,225 |
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
| NPS Score | 29.31 |

---

## Related Documentation

- [Data Dictionary](../03-Data-Modeling/Data-Dictionary_v1.3.md) — needs its "39 measures" reference updated to 45 (see Revision Notes)
- [Database Scripts](../02-Database-Scripts/) — source tables feeding this model
- [Power BI Dashboards](../07-PowerBI-Dashboards/) — consumption layer described in Dashboard Mapping above
- [Project README](../README.md) — also needs its "39 DAX measures" reference updated to 45

---

**Document Version:** 3.1 (Final)
**Last Updated:** July 2026
**Status:** ✅ COMPLETED — Deployed and verified
**Author:** Soheil Tavakkol
