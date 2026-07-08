# Data Modeling Documentation

This folder contains comprehensive documentation of the dimensional data model design for the Banking Customer Loyalty & Churn Analysis Data Warehouse.

## Contents

### [Data Model Design](Data_Modeling_v1.3.md)
Complete dimensional model documentation including:
- Star schema architecture (with one snowflaked dimension)
- Dimension and fact table specifications
- SCD Type 2 implementation details
- Business rules and calculations
- Design justifications
- SSAS Tabular layer summary and known DAX pitfalls
- Known issues & resolutions log

### [ER Diagram](ER-Diagram_v2.md)
Visual representations of the data model including:
- Entity relationship diagrams (Mermaid)
- Star schema visualization, with the Customer→Location snowflake branch called out explicitly
- SCD Type 2 flow diagrams
- Data flow diagram (source CSV → Python augmentation → staging → DW → SSAS Tabular → Power BI)
- Cardinality summary and fact table grain comparison

### [Data Dictionary](Data-Dictionary_v1.3.md)
Detailed reference guide for all tables and columns:
- Complete field specifications
- Data types and constraints
- Business rules and validations
- Code value definitions
- Calculated measure formulas
- Data quality findings (e.g. DateOfBirth fallback bug) and applied fixes
- SSAS Tabular layer: column renaming, calculated columns, DAX measure inventory

---

## Model Summary

**Schema Type:** Star Schema with one snowflaked dimension (Kimball Methodology)

The model is a star schema everywhere except one branch: `Dim_Customer → Dim_Location` is a dimension-to-dimension relationship, kept separate because `Dim_Location` is shared context for both `Fact_Transaction` and `Dim_Customer`, and denormalizing it would duplicate location attributes across 1.17M customer rows instead of 9,354 location rows.

**Dimensions:** 4 tables
- Dim_Date — 5,844 rows, pre-populated (2015–2030)
- Dim_Customer — SCD Type 2 (Location); 1,169,677 total rows / 884,225 current
- Dim_Location — 9,354 rows; snowflake target of Dim_Customer, star-joined to Fact_Transaction
- Dim_Segment — 7 RF-based segments, exhaustive and non-overlapping ranges

**Facts:** 2 tables
- Fact_Transaction — transaction-level grain, 147,290,230 rows
- Fact_CustomerSnapshot — customer-month grain, 13,051,115 rows

**Key Features:**
- SCD Type 2 for customer location tracking (243,376 customers changed location)
- RF-based customer segmentation, redesigned to eliminate gaps/overlaps
- Synthetic data for satisfaction scores and complaint flags
- Monthly snapshot fact table for trend analysis
- Anchoring convention (`[_LastDataDateKey]`) to avoid the Dim_Date 2030 trap in downstream DAX
- Model consumed live by three Power BI dashboards (Executive, Marketing, CRM & Retention) via SSAS Tabular Live Connection

---

## Implementation Status

| Phase | Description | Status |
|---|---|---|
| Phase 2 | Physical schema created | ✅ Complete |
| Phase 3 | Data model design documented (this folder) | ✅ Complete |
| Phase 5 | ETL: 5 SSIS packages, all tables loaded & validated | ✅ Complete |
| Phase 6 | SSAS Tabular model deployed (39 DAX measures) | ✅ Complete |
| Phase 7 | Power BI Dashboards (Executive, Marketing, CRM & Retention) | ✅ Complete |
| Phase 8 | Testing & Deployment | ⏸️ Not Planned |

> The model documented in this folder is the **final, as-built schema** — it did not change between Phase 3 and project completion. The one planned addition that was ultimately not pursued was a fourth "Analyst" Power BI dashboard; no schema, SSAS, or DAX changes would have been required to support it, since all necessary measures and dimensions already exist (see the main [project README](../README.md) for details).

---

## Actual Data Volumes (Final)

| Table | Rows |
|---|---|
| Dim_Date | 5,844 |
| Dim_Location | 9,354 |
| Dim_Customer (total / current) | 1,169,677 / 884,225 |
| Dim_Segment | 7 |
| Fact_Transaction | 147,290,230 |
| Fact_CustomerSnapshot | 13,051,115 |

**Latest-month snapshot (Aug 2016), as surfaced on the dashboards:**

| Metric | Value |
|---|---|
| Total Customers | 831,639 |
| Churn Rate | 15.76% |
| Avg Loyalty Score | 3.2 |
| NPS Score | 29.31 |

---

## Related Documentation

- [Database Scripts](../02-Database-Scripts/) — physical implementation of this model
- [Python Scripts](../04-Python-Scripts/) — source data augmentation
- [SSIS Packages](../05-SSIS-Packages/) — ETL that populates this model
- [SSAS Tabular Model](../06-SSAS-Tabular/) — semantic layer built on top of this model
- [Power BI Dashboards](../07-PowerBI-Dashboards/) — final consumption layer
- [Project README](../README.md)

---

**Version:** 1.3 (Final)
**Status:** ✅ Complete — model unchanged since Phase 3, validated end-to-end through Phase 7
**Last Updated:** July 2026
