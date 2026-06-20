# Banking Customer Loyalty & Churn Analytics

**End-to-End Business Intelligence Data Warehouse Project**

---

## Project Overview

A comprehensive Business Intelligence solution for analyzing banking customer behavior, focusing on loyalty patterns and churn prediction. This project demonstrates the complete lifecycle of a Data Warehouse implementation, from requirements gathering to dashboard delivery.

## Business Problem

Banks need to identify at-risk customers before they churn and understand what drives customer loyalty. This DW solution provides actionable insights through RF (Recency-Frequency) analysis, customer segmentation, and predictive analytics.

---

## Technology Stack

| Component | Technology |
|---|---|
| Database | Microsoft SQL Server 2019+ |
| ETL | SQL Server Integration Services (SSIS) |
| Staging Layer | SQL Server (BankingStaging) |
| Data Warehouse | SQL Server (Star schema with one snowflaked dimension - BankingDW) |
| OLAP | SQL Server Analysis Services (SSAS Tabular) |
| Visualization | Power BI Desktop |
| Scripting | Python 3.13 |
| Version Control | Git & GitHub |

---

## Repository Structure

```
Banking-Loyalty-Churn-Analytics/
│
├── 01-Requirements/
│   └── Requirements-Document.md              ✅ Phase 1
│
├── 02-Database-Scripts/
│   ├── 01-1-Create-BankingDW.sql             ✅ Phase 2
│   ├── 01-2-Create-BankingStaging.sql        ✅ Phase 5
│   ├── 02-Create-Schema.sql                  ✅ Phase 2
│   ├── 03-Create-Dim-Date.sql                ✅ Phase 2
│   ├── 04-Populate-Dim-Date.sql              ✅ Phase 2
│   ├── 05-Create-Dim-Location.sql            ✅ Phase 2
│   ├── 06-Create-Dim-Customer.sql            ✅ Phase 2
│   ├── 07-Create-Dim-Segment.sql             ✅ Phase 2 (ranges corrected)
│   ├── 08-Create-Fact-Transaction.sql        ✅ Phase 2
│   ├── 09-Create-Fact-CustomerSnapshot.sql   ✅ Phase 2
│   ├── 10-Create-Source-Database.sql         ✅ Phase 4
│   ├── 11-Data-Profiling.sql                 ✅ Phase 4
│   ├── 12-Alter-Dim-Location-DataTypes.sql   ✅ Phase 5
│   ├── 13-Create-SP-Load-Dim-Customer.sql    ✅ Phase 5 (DOB fix)
│   ├── 14-Add-LocationCode-To-Staging.sql    ✅ Phase 5
│   ├── 15-Create-SP-Load-Fact-Transaction.sql✅ Phase 5 (date parsing fix)
│   ├── 16-20-Create-SP-Package5-Tasks.sql    ✅ Phase 5 (5-SP pipeline)
│   └── README.md
│
├── 03-Data-Modeling/
│   ├── Data-Model-Design.md                  ✅ Phase 3
│   ├── ER-Diagram.md                         ✅ Phase 3
│   ├── Data-Dictionary.md                    ✅ Phase 3
│   └── README.md
│
├── 04-Python-Scripts/
│   ├── import_to_sql.py                      ✅ Initial Data Import
│   ├── generate_transactions_v3_3.py         ✅ Data Augmentation
│   ├── requirements.txt                      ✅ Dependencies
│   └── README.md                             ✅ Documentation
│
├── 05-SSIS-Packages/
│   ├── BankingETL/
│   │   ├── Package 1 - Load Staging.dtsx     ✅ COMPLETED
│   │   ├── Package 2 - Load Dim Location     ✅ COMPLETED
│   │   ├── Package 3 - Load Dim Customer     ✅ COMPLETED
│   │   ├── Package 4 - Load Fact Trans       ✅ COMPLETED
│   │   └── Package 5 - CustomerSnapshot      ✅ COMPLETED
│   └── README.md
│
├── 06-SSAS-Tabular/                          ✅ Phase 6 - COMPLETED
│   ├── BankingLoyaltyChurn/
│   │   ├── Model.bim
│   │   ├── BankingLoyaltyChurn.sln
│   │   └── Measures.txt
│   └── README.md
│
├── 07-PowerBI-Dashboards/                    ⏳ Phase 7
│   ├── Executive-Dashboard.pbix
│   ├── CRM-Dashboard.pbix
│   ├── Analyst-Dashboard.pbix
│   └── Marketing-Dashboard.pbix
│
├── 08-Test-Scripts/                          ⏳ Phase 8
│   └── Data-Quality-Tests.sql
│
└── README.md
```

---

## Key Features

### Data Architecture

**Three-Layer Architecture:**
- Source Layer (BankingSource - OLTP)
- Staging Layer (BankingStaging - ETL workspace)
- Data Warehouse (BankingDW - Star schema with one snowflaked dimension)

**Dimensional Design:**
- 4 Dimension Tables (Date, Customer, Location, Segment)
- 2 Fact Tables (Transaction, CustomerSnapshot)
- SCD Type 2 implementation for Customer dimension
- **One snowflaked branch:** `Dim_Customer → Dim_Location` (Location is shared by both fact tables and the Customer dimension, so it is kept as an independent dimension rather than denormalized into Customer — avoids duplicating City/State/Region across 1.17M customer rows)

**Scale:**
- 147.3M transaction records
- 884K current unique customers (1.17M total rows including SCD history)
- 9,354 distinct locations
- 13.05M customer-month snapshot records
- 20-month temporal coverage (Jan 2015 - Aug 2016)

### Analytics Capabilities

- **RF Segmentation:** Champions, Loyal Customers, Potential Loyalists, New Customers, At Risk, Hibernating, Churned — ranges redesigned to be exhaustive and non-overlapping across the full Recency × Frequency space
- **Churn Prediction:** Identify customers likely to leave (90+ days inactive)
- **KPI Layer:** 39 DAX measures across 7 categories (Customer Metrics, Churn & Retention, Loyalty & Satisfaction, Transactions, Behavior & Growth, Segments, NPS)
- **Trend Analysis:** MoM, QoQ, and YoY growth/decline patterns
- **Customer Journey:** Track behavior and location changes with SCD Type 2

### Technical Highlights

- **Performance ETL:** 147M+ transaction records loaded in ~24 minutes
- **Parallel Processing:** Independent data flows run simultaneously
- **Data Quality Framework:** Validation flags, NULL-safe parsing, and date-format-safe casting throughout
- **Scalable Design:** TABLOCK + minimal-logging inserts for large fact loads
- **Best Practices:** Separation of staging, transformation, and warehouse layers

---

## Data Sources

### Dataset: Synthetic Banking Transactions

**Original Data:** 1,048,567 transaction records (~55 days)

**Augmented Data:** 147,290,230 transaction records (20 months: Jan 2015 – Aug 2016)

**Core Attributes:**
- Customer demographics (DOB, Gender, Location)
- Transaction history (Date, Time, Amount)
- Account balances

**Engineered Features (Calculated in ETL):**
- Recency & Frequency scores (1–5 scale)
- Satisfaction scores based on RF patterns
- Complaint flags derived from transaction trends
- Churn/At-Risk indicators from activity patterns (60/90+ day thresholds)
- Customer segmentation (7 segments)

> **Note:** All data is synthetic and anonymized, created for educational purposes.

---

## Data Augmentation Strategy

### Challenge

The original dataset contained only ~55 days of transaction data, insufficient for:
- Churn analysis (requires 90+ days of inactivity)
- RF segmentation (needs multi-month patterns)
- Trend analysis (growth/decline over 6+ months)

### Solution

Implemented a BI-aligned data augmentation pipeline using **Python (v3.3 - DW-Aligned Edition)** that produces realistic time-series data calibrated to the KPIs computed in `Fact_CustomerSnapshot`.

**1. Temporal Expansion:**
- Extended ~55 days → 20 months (Jan 2015 – Aug 2016)
- Batch processing: 50K customers at a time

**2. Customer Journey Simulation:**

| Segment | Share | Monthly Frequency | Behaviour |
|---|---|---|---|
| Champions | 20% | 15–25 transactions | Consistent activity, +1.5% amount growth/month |
| Loyal | 25% | 8–14 transactions | Stable patterns, rare zero-months (5%) |
| At-Risk | 20% | Declining (−9%/month) | 25% chance of zero-transaction month → drives `AtRiskFlag` |
| Churned | 20% | Stops at month 8–15 | 60% chance of zero-month before hard stop → drives `ChurnFlag` |
| New Customers | 15% | 3–8 transactions | Campaign-based acquisition waves (Mar-15, Aug-15, Jan-16) |

**3. Realistic Variability:**
- **Bidirectional balance:** Salary credits (IN) + spending withdrawals (OUT) via 11 transaction types
- **Indian seasonal patterns:** Diwali peak in Oct (+22%), FY-end surge in Mar (+18%), Feb trough (−15%)
- **Dormancy periods:** 12% of customers go completely silent for 2–6 months — critical for `AtRiskFlag` and `ChurnFlag`
- **Shock events:** 2% of high-value transactions are 10–50× normal amount — prevents artificially clean dashboards
- **Location migration:** 2% monthly probability of city change — feeds SCD Type 2 in `Dim_Customer`
- **Monthly volatility:** Frequency noise of ±50–160% — enables meaningful `GrowthRate` in `Fact_CustomerSnapshot`

### Architecture Decision: Why Python for Augmentation?

**Separation of Concerns:**
- Raw data generation (Python) ≠ Business logic (ETL)
- Business rules stay in ETL for easy modification
- Segment labels are recalculated by the DW from real RF metrics — not inherited from Python

---

## Project Phases

### ✅ Phase 1: Requirements Gathering (Completed)

- Business questions definition
- KPI specifications with formulas
- User persona analysis (Bank Manager, CRM Team, Data Analyst, Marketing)
- Initial dimensional model design
- Technical requirements documentation

📄 [View Requirements Document](01-Requirements/Requirements-Document.md)

---

### ✅ Phase 2: Physical Environment Setup (Completed)

**Databases Created:**
- `BankingSource` — OLTP source system
- `BankingStaging` — ETL workspace
- `BankingDW` — Data Warehouse

**Dimension Tables (4):**
- `Dim_Date` — Pre-populated (5,844 rows: 2015–2030)
- `Dim_Segment` — Pre-populated (7 RF segments, exhaustive/non-overlapping ranges)
- `Dim_Location` — Loaded via Package 2
- `Dim_Customer` — SCD Type 2

**Fact Tables (2):**
- `Fact_Transaction` — Transaction-level grain
- `Fact_CustomerSnapshot` — Customer-month grain

📄 [View Database Scripts](02-Database-Scripts/)

---

### ✅ Phase 3: Data Modeling (Completed)

- Detailed dimensional model documentation
- Star schema (with one snowflaked dimension) design and ER diagrams
- SCD Type 2 logic specification
- Complete data dictionary
- Business rules documentation

📄 [View Data Modeling Documentation](03-Data-Modeling/)

---

### ✅ Phase 4: Data Augmentation (Completed)

**Python Script:** `generate_transactions_v3_3.py` (v3.3 - DW-Aligned Edition)

**Input:** 1,048,567 transactions, ~55 days
**Output:** 147,290,230 transactions, 20 months, 884,225 unique customers, 9,354 locations

**Key Achievements:**
- Realistic customer journey simulation aligned to DW KPI thresholds
- Dormancy periods and zero-transaction months for natural Churn/AtRisk signals
- Campaign-based customer acquisition for realistic cohort analysis
- Indian seasonal patterns (Diwali, Holi, FY-end) for meaningful trend dashboards
- Shock events for realistic outlier distribution
- Memory-optimized batch processing (50K customers per cycle)

📄 [View Python Scripts](04-Python-Scripts/)

---

### ✅ Phase 5: ETL Development (Completed)

**1. Staging Database Architecture**

Separate `BankingStaging` database (enterprise best practice):
- `Stg_Customer` (1,169,677 rows — includes one row per customer-location combination)
- `Stg_Transaction` (147,290,230 rows)
- `Stg_Location` (9,354 rows)

**2. Package 1 — Load Staging ✅**
Parallel data flows, `'nan'` string cleansing, validation flags, TABLOCK + fast load.
**Known issue:** `Stg_Customer.LocationCode` requires manual re-run of `14-Add-LocationCode-To-Staging.sql` after every Package 1 execution (column was added post-hoc, outside the package's data flow knowledge).

**3. Package 2 — Load Dim_Location ✅**
Extract distinct locations, LocationCode = `UPPER(REPLACE(Location, ' ', '_'))`. 9,354 rows (above original 9,021 due to migration-generated locations).

**4. Package 3 — Load Dim_Customer ✅**
SCD Type 2 via fully-rewritten stored procedure. `ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY LocEndDate DESC)` assigns exactly one current version per customer.
**Bug fixed:** DOB parsing originally used `TRY_CAST` with `ISNULL(..., '1900-01-01')` fallback, producing invalid birth years (1900, 1800) for ~693K rows. Corrected to `TRY_CONVERT(date, ..., 103)` with 1930–2005 range validation; invalid DOBs now NULL with AgeGroup = "Unknown" (697,306 rows) rather than fabricated.
Runtime: 00:01:55 for 1,169,677 rows.

**5. Package 4 — Load Fact_Transaction ✅**
**Three bugs fixed:**
- Transaction log overflow → removed explicit transaction wrapper, added `TABLOCK`, disabled/rebuilt indexes
- `TRY_CAST` silently dropping ~60% of rows under server `DATEFORMAT=mdy` → replaced with `TRY_CONVERT(date, ..., 103)` everywhere
- Duplicate rows from SCD date-range overlap (customers with A→B→A location history) → join changed from `BETWEEN StartDate AND EndDate` to direct `(CustomerID, Location)` key match

Runtime: 00:24:09 for 147,290,230 rows.

**6. Package 5 — Load Fact_CustomerSnapshot ✅**
5-stage SP pipeline: `usp_Build_MonthlyActivity` → `usp_Build_CustomerSpine` → `usp_Merge_CalculateRF` → `usp_Calculate_BusinessMetrics` → `usp_Load_FactCustomerSnapshot`.
**Issues resolved:** SSIS Execute SQL Task default timeout (300s) too short for final load — set to unlimited; `Dim_Segment` range gaps caused FK violations on `SegmentKey` — ranges redesigned to be exhaustive/non-overlapping.

Runtime: 00:10:02 for 13,051,115 rows.

📄 [View SSIS Packages](05-SSIS-Packages/)

---

### ✅ Phase 6: SSAS Tabular Model (Completed)

**Completed:**
- ✅ Project setup (Compatibility Level: 1600 — SQL Server 2022), model name `BankingLoyaltyChurn`
- ✅ Data source connection (`.;BankingDW`), authenticated via SSAS service account granted `db_datareader`
- ✅ 5 tables imported: Dim_Date, Dim_Customer, Dim_Location, Dim_Segment, Fact_CustomerSnapshot (Fact_Transaction intentionally excluded — pre-aggregated)
- ✅ 4 relationships (all Many-to-One, Single direction) — including the one snowflaked link (Dim_Customer → Dim_Location)
- ✅ Dim_Date marked as Date Table; Calendar hierarchy (Year → Quarter → Month → Date)
- ✅ All columns renamed with spaces for report-friendly display
- ✅ 3 calculated columns (RecencyBucket, LoyaltyBand, GrowthCategory) + 2 on Dim_Date (MonthLabel, MonthSort)
- ✅ Technical/audit/FK columns hidden across all 5 tables
- ✅ 39 DAX measures across 7 Display Folders, all anchored to `_LastDataDateKey` (never to raw `Dim_Date` max, which extends to 2030)
- ✅ Model deployed and verified — 7/7 objects succeeded, 13,051,115 fact rows transferred
- ✅ KPI threshold/status logic deliberately deferred to Power BI (SSAS native KPI objects don't render their status visuals in Power BI — only Base Measure and Target are read)

**DAX Measure Categories (39 total):**
- Customer Metrics (7): Total/Active/New Customers, Active Rate, Growth MoM/QoQ/YoY
- Churn & Retention (9): Churned/At-Risk Customers, Churn/Retention/At-Risk Rate, Churn Trend, MoM/QoQ/YoY Change
- Loyalty & Satisfaction (7): Avg Loyalty/Satisfaction Score, Avg Recency Days, Loyalty Trend, MoM/QoQ/YoY Change
- Transactions (6): Total/Avg Transaction Amount, Total Transactions, Avg Per Customer, Volume Trend
- Behavior & Growth (5): Complaints, Complaint Rate, Avg Growth Rate, Growing/Declining Customers
- Segments (7): Count by Segment, Share, Champions/Churned Count, Migration (Month/Quarter/Year)
- NPS (4): Promoters, Detractors, NPS Score, NPS Trend

**Key debugging fixes during this phase:**
- `DATEADD()` nested inside `CALCULATETABLE()` with a same-table date filter caused "no current row" errors on QoQ/YoY measures — fixed by resolving the target date to a scalar first (`CALCULATE(MAX(...))` + `EOMONTH`), then filtering directly
- `Avg Growth Rate` initially showed `4302%` instead of `43%` — `GrowthRate` is stored pre-scaled as a percentage in the DW, requiring `/100` before applying Percentage format
- SSAS service account lacked SQL login on `BankingDW`, causing Process Full to fail — resolved via `CREATE USER ... ALTER ROLE db_datareader`

📄 [View SSAS Tabular Model](06-SSAS-Tabular/)

---

### ⏳ Phase 7: Visualization (Upcoming)

**Four Dashboards Planned (mapped to specific measures in `06-SSAS-Tabular/README.md`):**

**1. Executive Dashboard** (C-Level: CEO, CFO)
High-level KPIs, churn/loyalty trend lines, segment distribution — no date filter, always latest month + full 20-month trend.

**2. CRM & Retention Dashboard** (Head of Retail, CRM Manager)
At-risk customer counts, churn MoM/QoQ/YoY changes, segment migration tracking, complaint rate.

**3. Analyst Dashboard** (Data Analyst, Branch Manager)
Segment-level trend breakdowns, growth rate by segment, transaction volume patterns, drill-through detail.

**4. Marketing / Geographic Dashboard** (Marketing, Regional Managers)
Location-based churn and loyalty distribution, NPS by region.

KPI threshold logic (Good/Warning/Critical) will be implemented in Power BI as status-returning measures, since this layer was deliberately left out of SSAS.

---

### ⏳ Phase 8: Testing & Deployment (Upcoming)

- Data quality validation
- Performance tuning and optimization
- User Acceptance Testing (UAT)
- Comprehensive documentation
- Training materials
- Production rollout
- Monitoring and maintenance procedures

---

## Current Project Statistics

**Data Volume:**
- Source: 147,290,230 transactions
- Staging: ~157.7M records (3 tables combined)
- Date Range: Jan 2015 – Aug 2016 (20 months)
- Customers: 884,225 current (1,169,677 total incl. SCD history)
- Locations: 9,354 distinct

**Performance Metrics:**
- Package 4 (Fact_Transaction) Runtime: 00:24:09 for 147.3M rows
- Package 5 (Fact_CustomerSnapshot) Runtime: 00:10:02 for 13.05M rows
- Parallel execution: 3 simultaneous staging data flows in Package 1

**Data Loaded (Verified Jun 2026):**

| Table | Rows | Status |
|---|---|---|
| Dim_Date | 5,844 | ✅ |
| Dim_Segment | 7 | ✅ |
| Dim_Location | 9,354 | ✅ |
| Dim_Customer (current) | 884,225 | ✅ |
| Dim_Customer (total, incl. SCD history) | 1,169,677 | ✅ |
| Fact_Transaction | 147,290,230 | ✅ |
| Fact_CustomerSnapshot | 13,051,115 | ✅ |

**SSAS Baseline KPIs (Aug 2016 — latest month):**

| Metric | Value |
|---|---|
| Total Customers | 831,639 |
| Churn Rate | 15.76% |
| At-Risk Rate | 1.00% |
| Avg Loyalty Score | 3.21 |

---

## Key Questions Being Answered

- What percentage of customers churned in the last 6 months?
- Which customer segments have the highest loyalty scores?
- What are the early warning signs of customer churn?
- How do satisfaction scores correlate with transaction frequency?
- Which demographics show the strongest retention rates?
- What transaction patterns indicate at-risk customers?
- How effective are retention strategies by segment?

---

## Learning Objectives

This project demonstrates proficiency in:

**✅ Completed:**
- Business requirements analysis and KPI definition
- Dimensional modeling (star schema with deliberate snowflaking, SCD Type 2 design)
- Three-layer architecture (Source, Staging, Warehouse)
- Data quality profiling, cleansing, and NULL-safe handling strategies
- Smart data augmentation for realistic BI-ready datasets
- SSIS package development (staging, dimension, and fact layers)
- ETL performance optimization (TABLOCK, minimal logging, parallel processing)
- Data validation frameworks
- SCD Type 2 implementation in ETL (Hybrid approach: SSIS + Stored Procedures)
- Locale-safe date parsing (`TRY_CONVERT` with explicit style codes vs. `TRY_CAST`)
- Performance tuning (temp tables, indexing, set-based operations)
- Stored Procedure development for complex transformations
- Complex transformation logic (RF score calculations, exhaustive segment range design)
- Fact table loading with SCD-aware dimension lookups
- Monthly aggregation fact tables
- Multi-stage ETL pipelines with Stored Procedures
- Global temp table management in SQL Server
- SSAS Tabular model development (structure, relationships, hierarchies)
- Display Folders and column organization
- Marking Date tables for Time Intelligence
- DAX time-intelligence debugging (DATEADD context-loss patterns, percentage scaling)
- Data source authentication troubleshooting (Windows service account permissions)
- Model deployment and verification

**⏳ Upcoming:**
- Data visualization and storytelling with Power BI
- KPI threshold/status visual design
- End-to-end DW project lifecycle management

---

## How to Use This Repository

### Prerequisites

- SQL Server 2019+ (Developer/Enterprise Edition)
- Python 3.8+ with required packages
- Visual Studio 2019/2022 with SSIS extension
- Visual Studio with SSAS extension (for Phase 6)
- Power BI Desktop (for Phase 7)

### Setup Instructions

**1. Clone the repository**
```bash
git clone https://github.com/SoheilTavakkol/Banking-Loyalty-Churn-Analytics.git
cd Banking-Loyalty-Churn-Analytics
```

**2. Set up databases**

Execute scripts in `02-Database-Scripts/` in numeric order (01 through 20).

**3. Prepare the data**
```bash
cd 04-Python-Scripts
pip install -r requirements.txt
python import_to_sql.py
python generate_transactions_v3_3.py
```

**4. Run ETL packages**
1. Open `05-SSIS-Packages/BankingETL/BankingETL.sln` in Visual Studio
2. Configure Connection Managers (BankingSource, BankingStaging, BankingDW)
3. Execute Package 1 — Load Staging
4. Manually run `14-Add-LocationCode-To-Staging.sql`
5. Execute Packages 2 through 5 in order (set Execute SQL Task TimeOut = 0 on Package 5)

**5. Deploy SSAS Tabular Model**
1. Open `06-SSAS-Tabular/BankingLoyaltyChurn/BankingLoyaltyChurn.sln` in Visual Studio
2. Ensure the SSAS service account has `db_datareader` on `BankingDW`
3. Deploy to Analysis Services, then Process Full

**6. Open dashboards** *(Coming in Phase 7)*

---

## Project Status

**Current Phase:** Phase 6 — SSAS Tabular Model (COMPLETED) | Phase 7 — Power BI (Next)

**Last Updated:** June 2026

**Progress:**

| Phase | Status | Completion |
|---|---|---|
| Requirements | ✅ Complete | 100% |
| Database Setup | ✅ Complete | 100% |
| Data Modeling | ✅ Complete | 100% |
| Data Augmentation | ✅ Complete | 100% |
| ETL Development | ✅ Complete | 100% |
| SSAS Tabular Model | ✅ Complete | 100% |
| Power BI Dashboards | ⏳ Upcoming | 0% |
| Testing & Deployment | ⏳ Upcoming | 0% |

---

## Key Design Decisions

**1. Three-Layer Architecture**
Separate Source → Staging → Warehouse for isolation, easier debugging, clear separation of concerns, and performance optimization at each layer.

**2. Staging Database (Not Schema)**
`BankingStaging` as a separate database for better security, independent backup/recovery, performance isolation, and enterprise-level architecture patterns.

**3. Data Types in Staging**
VARCHAR/NVARCHAR in staging, with type conversion in later packages. Preserves raw data integrity, avoids load failures, and keeps business logic in the transformation layer.

**4. One Deliberate Snowflake: Dim_Customer → Dim_Location**
Location is shared context for both fact tables and the Customer dimension. Rather than denormalizing City/State/Region/LocationType into every one of 1.17M customer rows, Location stays an independent dimension (9,354 rows) joined once from Customer. This is the one place the model departs from a pure star schema, and it's intentional.

**5. SCD Type 2 for Customer Location**
Track historical location changes with versioning to analyze location-based behavior over time. The augmentation script simulates city migrations (2% monthly probability) so SCD Type 2 is exercised with realistic data throughout the 20-month window.

**6. Synthetic Metrics in ETL (Not Python)**
Satisfaction scores, Churn flags, and Complaints are calculated in Package 5 — not in the Python augmentation script. Business rules can change without regenerating 147M records, and ETL remains the authoritative place for transformation logic.

**7. Segment Assignment in DW (Not Python)**
Customer segments (Champions, Loyal, At-Risk, etc.) are assigned by `Fact_CustomerSnapshot` based on actual RF metrics computed from transaction history. The Python script controls behavioral patterns only; the DW determines segment labels from real data.

**8. NULL Over Imputation for Data Quality Issues**
~697K customers have unparseable/missing DOB in the source data. Rather than imputing random plausible birthdates, these are left NULL with `AgeGroup = "Unknown"` — preserving an honest, auditable data quality signal rather than fabricating demographic data.

**9. KPI Logic in Power BI, Not SSAS**
SSAS Tabular KPI objects (Base Measure + Target + Status) aren't rendered with their status visuals when consumed from Power BI — only the Base Measure and Target values come through. Threshold/status logic is implemented as regular DAX measures, built in Power BI directly.

**10. Parallel Execution in Package 1**
No precedence constraints between the three staging data flows — they run simultaneously for better resource utilization and reduced total runtime.

---

## Contact

**Soheil Tavakkol**

- Email: ss.tvkl@gmail.com
- LinkedIn: [linkedin.com/in/soheyltavakkol](https://linkedin.com/in/soheyltavakkol)
- GitHub: [github.com/SoheilTavakkol](https://github.com/SoheilTavakkol)

---

## License

This project is for educational and portfolio purposes.

---

## Acknowledgments

This project was developed as part of a comprehensive BI learning path, demonstrating real-world data warehousing practices and Microsoft BI stack expertise.

**Key Techniques Demonstrated:**
- Handling data limitations through smart augmentation
- Dimensional modeling best practices (Kimball methodology, including deliberate snowflaking where justified)
- SCD Type 2 implementation patterns
- Three-layer ETL architecture
- Performance optimization for large-scale data (147M+ records)
- Locale-aware date handling in SQL Server
- DAX time-intelligence debugging
- Separation of concerns in data architecture
- End-to-end BI solution design
- Enterprise-level database organization

---

## Future Enhancements

- Incremental load patterns (CDC implementation)
- Real-time dashboard refresh
- Machine learning integration for churn prediction
- Advanced analytics (cohort analysis, customer segmentation clustering)
- Mobile dashboard versions
- Automated testing framework
- CI/CD pipeline for deployments
