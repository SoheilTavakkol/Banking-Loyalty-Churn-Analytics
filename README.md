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
| Data Warehouse | SQL Server (Star Schema - BankingDW) |
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
│   ├── 07-Create-Dim-Segment.sql             ✅ Phase 2
│   ├── 08-Create-Fact-Transaction.sql        ✅ Phase 2
│   ├── 09-Create-Fact-CustomerSnapshot.sql   ✅ Phase 2
│   ├── 10-Create-Source-Database.sql         ✅ Phase 4
│   └── 11-Data-Profiling.sql                 ✅ Phase 4
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
│   ├── BankingTabularModel/
│   │   ├── Model.bim
│   │   ├── BankingTabularModel.sln
│   │   └── BankingTabularModel.smproj
│   └── README.md
│
├── 07-PowerBI-Dashboards/                    ⏳ Phase 7
│   ├── Executive-Dashboard.pbix
│   ├── CRM-Dashboard.pbix
│   └── Analyst-Dashboard.pbix
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
- Data Warehouse (BankingDW - Star Schema)

**Star Schema Design:**
- 4 Dimension Tables (Date, Customer, Location, Segment)
- 2 Fact Tables (Transaction, CustomerSnapshot)
- SCD Type 2 implementation for Customer dimension

**Scale:**
- 154.7M transaction records
- 884K unique customers
- 9K distinct locations
- 20-month temporal coverage (Jan 2015 - Aug 2016)

### Analytics Capabilities

- **RF Segmentation:** Champions, Loyal, At-Risk, Hibernating, Churned, Potential Loyalists, New Customers
- **Churn Prediction:** Identify customers likely to leave (90+ days inactive)
- **KPI Dashboards:** 21 key metrics for decision-making
- **Trend Analysis:** Growth/decline patterns over time
- **Customer Journey:** Track behavior changes with SCD Type 2

### Technical Highlights

- **Performance ETL:** 155M+ records loaded in ~30 minutes
- **Parallel Processing:** Independent data flows run simultaneously
- **Data Quality Framework:** Validation flags and cleansing rules
- **Scalable Design:** Bulk insert with optimized batch sizes (500K rows)
- **Best Practices:** Separation of staging, transformation, and warehouse layers

---

## Data Sources

### Dataset: Synthetic Banking Transactions

**Original Data:** 1,048,567 transaction records (18 days: Aug 13–31, 2016)

**Augmented Data:** ~154M transaction records (20 months: Jan 2015 – Aug 2016)

**Core Attributes:**
- Customer demographics (DOB, Gender, Location)
- Transaction history (Date, Time, Amount)
- Account balances

**Engineered Features (Calculated in ETL):**
- Recency & Frequency scores (1–5 scale)
- Satisfaction scores based on RF patterns
- Complaint flags derived from transaction trends
- Churn indicators from activity patterns (90+ days)
- Customer segmentation (7 segments)

> **Note:** All data is synthetic and anonymized, created for educational purposes.

---

## Data Augmentation Strategy

### Challenge

The original dataset contained only 18 days of transaction data, insufficient for:
- Churn analysis (requires 90+ days of inactivity)
- RF segmentation (needs multi-month patterns)
- Trend analysis (growth/decline over 6+ months)

### Solution

Implemented a BI-aligned data augmentation pipeline using **Python (v3.3 - DW-Aligned Edition)** that produces realistic time-series data calibrated to the KPIs computed in `Fact_CustomerSnapshot`.

**1. Temporal Expansion:**
- Extended 18 days → 20 months (Jan 2015 – Aug 2016)
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
- KPI specifications with formulas (21 metrics)
- User persona analysis (Bank Manager, CRM Team, Data Analyst, Marketing)
- Initial dimensional model design
- Technical requirements documentation

📄 [View Requirements Document](01-Requirements/Requirements-Document.md)

---

### ✅ Phase 2: Physical Environment Setup (Completed)

**Databases Created:**
- `BankingSource` — OLTP source system
- `BankingDW` — Data Warehouse (Star Schema)

**Dimension Tables (4):**
- `Dim_Date` — Pre-populated (5,844 rows: 2015–2030)
- `Dim_Segment` — Pre-populated (7 RF segments)
- `Dim_Location` — Ready for load
- `Dim_Customer` — SCD Type 2 ready

**Fact Tables (2):**
- `Fact_Transaction` — Transaction-level grain
- `Fact_CustomerSnapshot` — Customer-month grain

📄 [View Database Scripts](02-Database-Scripts/)

---

### ✅ Phase 3: Data Modeling (Completed)

- Detailed dimensional model documentation
- Star schema design and ER diagrams
- SCD Type 2 logic specification
- Complete data dictionary
- Business rules documentation

📄 [View Data Modeling Documentation](03-Data-Modeling/)

---

### ✅ Phase 4: Data Augmentation (Completed)

**Python Script:** `generate_transactions_v3_3.py` (v3.3 - DW-Aligned Edition)

**Input:**
- 1,048,567 transactions (18 days)
- 884,265 unique customers

**Output:**
- ~154M transactions (20 months)
- Database size: ~17 GB

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

Created separate `BankingStaging` database (enterprise best practice):
- `Stg_Customer` (884K records)
- `Stg_Transaction` (154M records)
- `Stg_Location` (9K records)

**2. Package 1 — Load Staging ✅ COMPLETED**

| Data Flow | Source | Destination | Records | Runtime |
|---|---|---|---|---|
| DFT - Load Stg_Customer | RawTransactions | Stg_Customer | 884,265 | ~1m 40s |
| DFT - Load Stg_Transaction | RawTransactions | Stg_Transaction | 154,777,534 | ~28m |
| DFT - Load Stg_Location | RawTransactions | Stg_Location | 9,021 | ~32s |

Total Load Time: ~30 minutes for 155+ million records

Features implemented:
- Data cleansing: `'nan'` strings → NULL conversion
- Validation flags: Track invalid records
- Performance optimization: Fast Load, Table Lock, Bulk Insert (500K batch)
- Parallel execution: All three flows run simultaneously
- Error handling: Validation flags instead of load failures

**3. Package 2 — Load Dim_Location ✅ COMPLETED**
- Extract distinct locations from staging
- Data enrichment with City_Lookup reference table
- LocationKey assignment (surrogate key)
- Runtime: ~30 seconds for 9K locations

**4. Package 3 — Load Dim_Customer ✅ COMPLETED**
- SCD Type 2 implementation via Stored Procedure
- Track historical location changes (IsCurrent, StartDate, EndDate)
- Customer deduplication and versioning
- Calculate Age and AgeGroup
- Runtime: ~50 seconds for 884K customers
- Method: Hybrid approach (SSIS + SP)

**5. Package 4 — Load Fact_Transaction ✅ COMPLETED**
- SCD-aware CustomerKey lookup (match transaction date with customer version)
- Dimension key lookups (Customer, Date, Location)
- Direct INSERT with JOINs via Stored Procedure
- Runtime: 1 hour 48 minutes for 154M transactions
- Method: Stored Procedure (set-based operations)

**6. Package 5 — Load Fact_CustomerSnapshot ✅ COMPLETED**
- Monthly aggregation with 5-task architecture
- RF score calculations via Stored Procedures
- Loyalty & Satisfaction scores
- Churn/AtRisk flags
- Segment assignment
- Runtime: ~13 minutes for 15.6M records
- Method: 5 Sequential Stored Procedures

📄 [View SSIS Packages](05-SSIS-Packages/)

---

### ✅ Phase 6: SSAS Tabular Model (Completed)

**Completed:**
- ✅ Project setup (Compatibility Level: 1600 — SQL Server 2022)
- ✅ Data source connection (`SOHEILT;BankingDW`)
- ✅ Tables imported (5 tables: Dim_Date, Dim_Customer, Dim_Location, Dim_Segment, Fact_CustomerSnapshot)
- ✅ Relationships created (4 relationships — all Many-to-One, Single direction)
- ✅ Calendar hierarchy (Year → Quarter → Month → Date)
- ✅ Display Folders configured (Customer Metrics, Churn & Retention, Loyalty & Satisfaction, Transactions, Behavior, Segments, NPS)
- ✅ Technical columns hidden (keys, SCD metadata, audit fields)
- ✅ 21 DAX measures created and formatted
- ✅ Model deployed and tested in SSMS

**DAX Measures Created (21 KPIs):**
- **Customer Activity:** Total Customers, Active Customers, Active Customer Rate, Avg Transaction Frequency
- **Churn & Retention:** Churned Customers, Churn Rate, Retention Rate, At-Risk Customers
- **Loyalty & Satisfaction:** Avg Loyalty Score, Avg Satisfaction Score, Avg Recency Days
- **Transactions:** Total Transaction Amount, Total Transactions, Avg Transaction Amount, Total Balance
- **Behavior:** Customers with Complaints, Complaint Rate, Avg Growth Rate
- **Segments:** Customer Count by Segment, Segment %
- **NPS:** Promoters, Detractors, NPS Score

📄 [View SSAS Tabular Model](06-SSAS-Tabular/)

---

### ⏳ Phase 7: Visualization (Upcoming)

**Four Dashboards Planned:**

**1. Executive Dashboard** (Bank Manager)
- High-level KPIs and trends
- Geographic heat maps
- Executive summary metrics

**2. CRM Dashboard** (CRM Team)
- At-risk customer lists
- Contact prioritization
- Action recommendations

**3. Analyst Dashboard** (Data Analyst)
- Drill-through capabilities
- Correlation analysis
- Deep-dive analytics

**4. Marketing Dashboard** (Marketing Team)
- Segment profiling
- Campaign target identification
- ROI tracking

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
- Source: 154,777,534 transactions
- Staging: 155,660,820 records (3 tables)
- Date Range: Jan 2015 – Aug 2016 (20 months)
- Customers: 884,265 unique
- Locations: 9,021 distinct

**Database Sizes:**
- BankingSource: ~17 GB
- BankingStaging: ~18 GB
- BankingDW: Fully loaded

**Performance Metrics:**
- ETL Package 1 Runtime: ~30 minutes
- Throughput: ~5.4 million records/minute
- Parallel execution: 3 simultaneous data flows

**Data Loaded:**

| Table | Rows | Status |
|---|---|---|
| Dim_Date | 5,844 | ✅ |
| Dim_Segment | 7 | ✅ |
| Dim_Location | 9,021 | ✅ |
| Dim_Customer | 884,265 | ✅ |
| Fact_Transaction | 154,777,534 | ✅ |
| Fact_CustomerSnapshot | 15,581,079 | ✅ |

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
- Dimensional modeling (Star Schema, SCD Type 2 design)
- Three-layer architecture (Source, Staging, Warehouse)
- Data quality profiling and cleansing strategies
- Smart data augmentation for realistic BI-ready datasets
- SSIS package development (staging, dimension, and fact layers)
- ETL performance optimization (bulk insert, parallel processing)
- Data validation frameworks
- SCD Type 2 implementation in ETL (Hybrid approach: SSIS + Stored Procedures)
- NULL handling strategies (default values, data quality flagging)
- Performance tuning (temp tables, indexing, set-based operations)
- Stored Procedure development for complex transformations
- Complex transformation logic (RF score calculations)
- Fact table loading with dimension lookups
- Monthly aggregation fact tables
- Multi-stage ETL pipelines with Stored Procedures
- Global temp table management in SQL Server
- SSAS Tabular model development (structure, relationships, hierarchies)
- Display Folders and column organization
- Marking Date tables for Time Intelligence
- DAX formulas and calculated measures (21 KPIs)
- Model deployment and testing

**⏳ Upcoming:**
- Data visualization and storytelling with Power BI
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

Execute scripts in `02-Database-Scripts/` in this order:
1. `01-1-Create-BankingDW.sql` — Data Warehouse
2. `01-2-Create-BankingStaging.sql` — Staging Layer
3. `10-Create-Source-Database.sql` — Source System
4. Remaining dimension and fact table scripts

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
3. Execute Package 1 — Load Staging (~30 min runtime)
4. Execute subsequent packages in order

**5. Deploy SSAS Tabular Model**
1. Open `06-SSAS-Tabular/BankingTabularModel/BankingTabularModel.sln` in Visual Studio
2. Deploy to Analysis Services
3. Process the model

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

**4. SCD Type 2 for Customer Location**
Track historical location changes with versioning to analyze location-based behavior over time. The augmentation script simulates city migrations (2% monthly probability) so SCD Type 2 is exercised with realistic data throughout the 20-month window.

**5. Synthetic Metrics in ETL (Not Python)**
Satisfaction scores, Churn flags, and Complaints are calculated in Package 5 — not in the Python augmentation script. Business rules can change without regenerating 154M records, and ETL remains the authoritative place for transformation logic.

**6. Segment Assignment in DW (Not Python)**
Customer segments (Champions, Loyal, At-Risk, etc.) are assigned by `Fact_CustomerSnapshot` based on actual RF metrics computed from transaction history. The Python script controls behavioral patterns only; the DW determines segment labels from real data.

**7. Parallel Execution in Package 1**
No precedence constraints between the three staging data flows — they run simultaneously for better resource utilization and reduced total runtime.

**8. Batch Size Optimization**
500K rows per batch (vs. the default 5K) reduces commit overhead for 154M records while staying within memory constraints.

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
- Dimensional modeling best practices (Kimball methodology)
- SCD Type 2 implementation patterns
- Three-layer ETL architecture
- Performance optimization for large-scale data (155M+ records)
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
