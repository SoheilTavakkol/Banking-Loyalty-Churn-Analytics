# Phase 6: SSAS Tabular Model

## Status
✅ **COMPLETED** - Model deployed and tested in SSMS

---

## Project Information

- **Model Name:** BankingTabularModel
- **Compatibility Level:** 1600 (SQL Server 2022)
- **Workspace:** Integrated Workspace
- **Target Database:** BankingTabularModel
- **Data Source:** SOHEILT;BankingDW
- **Deployment Server:** localhost\SSAS_Tabular

---

## Data Model Structure

### Tables Imported (5)

- ✅ **DW.Dim_Date** - 5,844 rows (Calendar dimension 2015-2030)
- ✅ **DW.Dim_Customer** - 884,265 rows (Current customers, IsCurrent=1)
- ✅ **DW.Dim_Location** - 9,021 rows (Geographic dimension)
- ✅ **DW.Dim_Segment** - 7 rows (RF segmentation rules)
- ✅ **DW.Fact_CustomerSnapshot** - 15,581,079 rows (Monthly customer metrics)

### Relationships (4)

**All relationships:** Many-to-One, Single direction, Active

- ✅ Fact_CustomerSnapshot → Dim_Customer (CustomerKey)
- ✅ Fact_CustomerSnapshot → Dim_Date (DateKey)
- ✅ Fact_CustomerSnapshot → Dim_Segment (SegmentKey)
- ✅ Dim_Customer → Dim_Location (LocationKey)

---

## Model Organization

### Calendar Hierarchy

**Dim_Date** marked as Date Table with hierarchy:
```
📅 Calendar
  ├── Year
  ├── Quarter
  ├── Month
  └── Date
```

### Display Folders (7 Categories)

Measures organized for better user experience:

1. **Customer Metrics** (4 measures)
2. **Churn & Retention** (4 measures)
3. **Loyalty & Satisfaction** (3 measures)
4. **Transactions** (4 measures)
5. **Behavior** (3 measures)
6. **Segments** (2 measures)
7. **NPS** (3 measures)

### Column Visibility

**Hidden columns:**
- Surrogate keys (CustomerKey, LocationKey, SegmentKey, DateKey)
- SCD metadata (StartDate, EndDate, IsCurrent)
- ETL audit columns (ETLLoadDate, ETLBatchID, CreatedDate, ModifiedDate)

**Visible columns:**
- Business attributes only (CustomerID, Location, SegmentName, Date, etc.)

---

## DAX Measures (21 KPIs)

### Customer Activity Metrics (4)

- **Total Customers** - `#,##0` - Total unique customers
- **Active Customers** - `#,##0` - Customers active in last 30 days
- **Active Customer Rate** - `0.00%` - Active / Total
- **Avg Transaction Frequency** - `#,##0.00` - Average monthly transactions

### Churn & Retention Metrics (4)

- **Churned Customers** - `#,##0` - Customers inactive >90 days
- **Churn Rate** - `0.00%` - Churned / Total
- **Retention Rate** - `0.00%` - 1 - Churn Rate
- **At-Risk Customers** - `#,##0` - Customers with 60-90 days inactivity

### Loyalty & Satisfaction Metrics (3)

- **Avg Loyalty Score** - `0.00` - Combined RF score (1-5)
- **Avg Satisfaction Score** - `0.00` - Synthetic satisfaction (1-5)
- **Avg Recency Days** - `#,##0.0` - Average days since last transaction

### Transaction Metrics (4)

- **Total Transaction Amount** - `$#,##0` - Sum of all transactions
- **Total Transactions** - `#,##0` - Total transaction count
- **Avg Transaction Amount** - `$#,##0.00` - Average per transaction
- **Total Balance** - `$#,##0` - Sum of account balances

### Behavioral Metrics (3)

- **Customers with Complaints** - `#,##0` - Customers with complaint flag
- **Complaint Rate** - `0.00%` - Complaints / Total
- **Avg Growth Rate** - `0.0%` - Average month-over-month growth

### Segment Distribution (2)

- **Customer Count by Segment** - `#,##0` - Customers per segment
- **Segment %** - `0.0%` - Segment percentage of total

### Advanced KPIs - NPS (3)

- **Promoters** - `#,##0` - Customers with satisfaction ≥4
- **Detractors** - `#,##0` - Customers with satisfaction ≤2
- **NPS Score** - `0.0%` - (Promoters - Detractors) / Total

---

## Key Results (August 2016)

- **Total Customers:** 884,265
- **Active Customers:** 707,073 (80%)
- **Churned Customers:** 126,451 (14.3%)
- **At-Risk Customers:** 0 (no customers in 60-90 day window)
- **Avg Loyalty Score:** 3.50
- **Avg Satisfaction Score:** 3.66
- **NPS Score:** 38.7%

---

## Development Summary

### Completed Steps

- [x] **Step 1:** Project setup and configuration
- [x] **Step 2:** Data source connection (BankingDW)
- [x] **Step 3:** Import tables (5 tables)
- [x] **Step 4:** Create relationships (4 relationships)
- [x] **Step 5:** Build Calendar hierarchy
- [x] **Step 6:** Create 21 DAX measures
- [x] **Step 7:** Format measures (currency, percentage)
- [x] **Step 8:** Organize Display Folders
- [x] **Step 9:** Hide technical columns
- [x] **Step 10:** Deploy to SSAS server
- [x] **Step 11:** Test and validate in SSMS

### Technical Notes

- All measures use `REMOVEFILTERS()` for context independence
- Customer-based measures filter to latest month (DateKey)
- Transaction measures aggregate across all periods
- `VAR MaxDateInData` pattern used consistently
- Handle blank values with `+0` or `IF(ISBLANK())`

---

## Next Steps

**Phase 7: Power BI Dashboards**
- Connect Power BI to SSAS Tabular model
- Create 4 dashboards (Executive, CRM, Analyst, Marketing)
- Implement interactive filters and drill-through
- Add visual storytelling elements

---

**Last Updated:** December 2025  
**Status:** ✅ COMPLETED  
**Author:** Soheil Tavakkol
