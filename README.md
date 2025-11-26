# Banking Customer Loyalty & Churn Analytics

**End-to-End Business Intelligence Data Warehouse Project**

---

## Project Overview

A comprehensive Business Intelligence solution for analyzing banking customer behavior, focusing on loyalty patterns and churn prediction. This project demonstrates the complete lifecycle of a Data Warehouse implementation, from requirements gathering to dashboard delivery.

### Business Problem

Banks need to identify at-risk customers before they churn and understand what drives customer loyalty. This DW solution provides actionable insights through RF (Recency-Frequency) analysis, customer segmentation, and predictive analytics.

---

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Database | Microsoft SQL Server 2019 |
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
│   ├── generate_extended_transactions.py     ✅ Data Augmentation
│   ├── requirements.txt                      ✅ Dependencies
│   └── README.md                             ✅ Documentation
│
├── 05-SSIS-Packages/                         🔄 Phase 5 (In Progress)
│   ├── BankingETL/
│   │   ├── Package 1 - Load Staging.dtsx     ✅ COMPLETED
│   │   ├── Package 2 - Load Dim Location     ⏳ Next
│   │   ├── Package 3 - Load Dim Customer     ⏳ SCD Type 2
│   │   ├── Package 4 - Load Fact Trans       ⏳ Upcoming
│   │   └── Package 5 - CustomerSnapshot      ⏳ Upcoming
│   └── README.md
│
├── 06-SSAS-Tabular/                          ⏳ Phase 6
│   └── Banking-Tabular-Model.bim
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

- **RF Segmentation:** Champions, Loyal, At-Risk, Churned customers
- **Churn Prediction:** Identify customers likely to leave (90+ days inactive)
- **KPI Dashboards:** 15+ key metrics for decision-making
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

**Original Data:** 1,048,567 transaction records (18 days: Aug 13-31, 2016)

**Augmented Data:** 154,777,534 transaction records (20 months: Jan 2015 - Aug 2016)

**Core Attributes:**
- Customer demographics (DOB, Gender, Location)
- Transaction history (Date, Time, Amount)
- Account balances

**Engineered Features (Calculated in ETL):**
- Recency & Frequency scores (1-5 scale)
- Satisfaction scores based on RF patterns
- Complaint flags derived from transaction trends
- Churn indicators from activity patterns (90+ days)
- Customer segmentation (7 segments)

> **Note:** All data is synthetic and anonymized, created for educational purposes.

---

## Data Augmentation Strategy

### Challenge

The original dataset contained only **18 days** of transaction data, insufficient for:
- Churn analysis (requires 90+ days of inactivity)
- RF segmentation (needs multi-month patterns)
- Trend analysis (growth/decline over 6+ months)

### Solution

Implemented a **smart data augmentation pipeline** using Python (v2.0 - Memory Optimized):

**1. Temporal Expansion:**
- Extended 18 days → 20 months (Jan 2015 - Aug 2016)
- Batch processing: 50K customers at a time

**2. Customer Journey Simulation:**
- **Champions (20%):** 15-25 transactions/month, consistent activity
- **Loyal (25%):** 8-14 transactions/month, stable patterns
- **At-Risk (20%):** Declining frequency over time
- **Churned (20%):** Activity stops after 90+ days inactive
- **New Customers (15%):** Only active in last 3-6 months

**3. Realistic Variability:**
- Transaction frequency varies by customer personality
- Account balances evolve realistically
- Temporal patterns show seasonality

### Architecture Decision: Why Python for Augmentation?

**Separation of Concerns:**
- Raw data generation (Python) ≠ Business logic (ETL)
- Business rules stay in ETL for easy modification
- Flexibility: Rules can change without regenerating 154M records

---

## Project Phases

### ✅ Phase 1: Requirements Gathering (Completed)

- Business questions definition
- KPI specifications with formulas (15+ metrics)
- User persona analysis (Bank Manager, CRM Team, Data Analyst, Marketing)
- Initial dimensional model design
- Technical requirements documentation

📄 [View Requirements Document](01-Requirements/Requirements-Document.md)

---

### ✅ Phase 2: Physical Environment Setup (Completed)

**Databases Created:**
- `BankingSource` - OLTP source system
- `BankingDW` - Data Warehouse (Star Schema)

**Dimension Tables (4):**
- `Dim_Date` - Pre-populated (5,844 rows: 2015-2030)
- `Dim_Segment` - Pre-populated (7 RF segments)
- `Dim_Location` - Ready for load
- `Dim_Customer` - SCD Type 2 ready

**Fact Tables (2):**
- `Fact_Transaction` - Transaction-level grain
- `Fact_CustomerSnapshot` - Customer-month grain

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

**Python Script:** `generate_extended_transactions.py` (v2.0 - Memory Optimized)

**Input:**
- 1,048,567 transactions (18 days)
- 884,265 unique customers

**Output:**
- 154,777,534 transactions (20 months)
- Database size: ~17 GB

**Key Achievements:**
- Realistic customer journey simulation
- Temporal patterns with churn decline
- Memory-optimized batch processing

📄 [View Python Scripts](04-Python-Scripts/)

---

### 🔄 Phase 5: ETL Development (In Progress)

#### ✅ Completed: Staging Database & Package 1

**1. Staging Database Architecture**

Created separate `BankingStaging` database (Enterprise best practice):
- `Stg_Customer` (884K records)
- `Stg_Transaction` (154M records)
- `Stg_Location` (9K records)

**2. Package 1 - Load Staging ✅ COMPLETED**

**Data Flows (Parallel Execution):**

| Data Flow | Source | Destination | Records | Runtime |
|-----------|--------|-------------|---------|---------|
| DFT - Load Stg_Customer | RawTransactions | Stg_Customer | 884,265 | ~1m 40s |
| DFT - Load Stg_Transaction | RawTransactions | Stg_Transaction | 154,777,534 | ~28m |
| DFT - Load Stg_Location | RawTransactions | Stg_Location | 9,021 | ~32s |

**Total Load Time:** ~30 minutes for 155+ million records

**Features Implemented:**
- Data cleansing: 'nan' strings → NULL conversion
- Validation flags: Track invalid records
- Performance optimization: Fast Load, Table Lock, Bulk Insert (500K batch)
- Parallel execution: All three flows run simultaneously
- Error handling: Validation flags instead of load failures

**Technical Details:**
- Fast Load with TABLOCK
- Maximum insert commit size: 0 (single transaction)
- Rows per batch: 500,000
- Check constraints disabled during load
- Data type preservation (VARCHAR/NVARCHAR in staging)

#### ⏳ Upcoming Packages

**Package 2: Load Dim_Location**
- Extract distinct locations from staging
- Assign LocationKey (surrogate key)
- ~1 minute runtime

**Package 3: Load Dim_Customer (SCD Type 2)**
- Track historical location changes
- SCD Type 2 logic (IsCurrent, StartDate, EndDate)
- Customer deduplication and versioning

**Package 4: Load Fact_Transaction**
- SCD-aware lookups (match customer version by date)
- Dimension key lookups
- 154M records load

**Package 5: Calculate Fact_CustomerSnapshot**
- Monthly aggregation (Customer-Month grain)
- RF score calculations (1-5 scale)
- Loyalty & Satisfaction scores
- Churn flag (Recency > 90 days)
- Complaint flag (frequency decline > 30%)
- Segment assignment
- Trend analysis

📄 [View SSIS Packages](05-SSIS-Packages/)

---

### ⏳ Phase 6: OLAP Cube (Upcoming)

**Deliverables:**
- SSAS Tabular model with relationships
- 15+ DAX measures for KPIs:
  - Active Customer Rate
  - Churn Rate & Retention Rate
  - Average Loyalty & Satisfaction Scores
  - Complaint Rate
  - NPS (Net Promoter Score)
  - Customer Lifetime Value
  - Segment distribution percentages
- Calculated columns for complex logic
- Row-level security (optional)
- Processing optimization strategies

---

### ⏳ Phase 7: Visualization (Upcoming)

**Four Dashboards Planned:**

**1. Executive Dashboard (Bank Manager)**
- High-level KPIs and trends
- Geographic heat maps
- Executive summary metrics

**2. CRM Dashboard (CRM Team)**
- At-risk customer lists
- Contact prioritization
- Action recommendations

**3. Analyst Dashboard (Data Analyst)**
- Drill-through capabilities
- Correlation analysis
- Deep-dive analytics

**4. Marketing Dashboard (Marketing Team)**
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
- Date Range: Jan 2015 - Aug 2016 (20 months)
- Customers: 884,265 unique
- Locations: 9,021 distinct

**Database Sizes:**
- BankingSource: ~17 GB
- BankingStaging: ~18 GB
- BankingDW: Ready for load

**Performance Metrics:**
- ETL Package 1 Runtime: ~30 minutes
- Throughput: ~5.4 million records/minute
- Parallel execution: 3 simultaneous data flows

---

## Sample Insights

*Dashboards and visualizations will be added as the project progresses.*

### Key Questions Being Answered:

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

**Completed:**
- ✅ Business requirements analysis and KPI definition
- ✅ Dimensional modeling (Star Schema, SCD Type 2 design)
- ✅ Three-layer architecture (Source, Staging, Warehouse)
- ✅ Data quality profiling and cleansing strategies
- ✅ Smart data augmentation for realistic datasets
- ✅ SSIS package development (staging layer)
- ✅ ETL performance optimization (bulk insert, parallel processing)
- ✅ Data validation frameworks

**In Progress:**
- 🔄 SCD Type 2 implementation in ETL
- 🔄 Complex transformation logic (RF calculations)
- 🔄 Fact table loading with dimension lookups

**Upcoming:**
- ⏳ OLAP cube development with SSAS Tabular
- ⏳ DAX formulas and calculated measures
- ⏳ Data visualization and storytelling with Power BI
- ⏳ End-to-end DW project lifecycle management

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
- `01-1-Create-BankingDW.sql` - Data Warehouse
- `01-2-Create-BankingStaging.sql` - Staging Layer
- `10-Create-Source-Database.sql` - Source System
- Other dimension/fact table scripts

**3. Prepare the data**
```bash
cd 04-Python-Scripts
pip install -r requirements.txt
python import_to_sql.py
python generate_extended_transactions.py
```

**4. Run ETL packages**

- Open `05-SSIS-Packages/BankingETL/BankingETL.sln` in Visual Studio
- Configure Connection Managers (BankingSource, BankingStaging, BankingDW)
- Execute Package 1 - Load Staging (~30 min runtime)
- Execute subsequent packages as they become available

**5. Process OLAP cube** *(Coming in Phase 6)*

**6. Open dashboards** *(Coming in Phase 7)*

---

## Project Status

**Current Phase:** Phase 5 - ETL Development (Package 1 Complete)

**Last Updated:** November 2025

**Next Milestone:** Package 2 - Load Dim_Location

**Progress:**
- Requirements: ✅ 100%
- Database Setup: ✅ 100%
- Data Modeling: ✅ 100%
- Data Augmentation: ✅ 100%
- ETL Development: 🔄 20% (1 of 5 packages complete)
- OLAP: ⏳ 0%
- Visualization: ⏳ 0%
- Testing: ⏳ 0%

---

## Key Design Decisions

### 1. Three-Layer Architecture

**Decision:** Separate Source → Staging → Warehouse

**Rationale:**
- Enterprise best practice for isolation
- Easier debugging and error handling
- Clear separation of concerns
- Performance optimization at each layer

### 2. Staging Database (Not Schema)

**Decision:** `BankingStaging` as separate database, not schema in DW

**Rationale:**
- Better security and permission management
- Independent backup/recovery strategies
- Performance isolation
- Enterprise-level architecture patterns

### 3. Data Types in Staging

**Decision:** VARCHAR/NVARCHAR in staging, conversion in later packages

**Rationale:**
- Preserve raw data integrity
- Avoid load failures from type conversion errors
- Validation flags track issues without blocking load
- Business logic remains in transformation layer

### 4. SCD Type 2 for Customer Location

**Decision:** Track historical location changes with versioning

**Rationale:**
- Analyze location-based behavior over time
- Enable accurate historical reporting
- Support "customer moved" analysis

### 5. Synthetic Metrics in ETL (Not Python)

**Decision:** Calculate Satisfaction, Churn, Complaints in Package 5

**Rationale:**
- Separation of data generation vs. business logic
- Business rules can change without regenerating 154M records
- ETL is the proper place for transformation logic
- Auditability and maintainability

### 6. Parallel Execution in Package 1

**Decision:** No precedence constraints between staging loads

**Rationale:**
- Three data flows are independent
- Parallel execution reduces total runtime
- Better resource utilization

### 7. Batch Size Optimization

**Decision:** 500K rows per batch (not default 5K)

**Rationale:**
- Reduces overhead for 154M records
- Fewer commits = faster load
- Balanced against memory constraints

---

## Contact

**Soheil Tavakkol**

Email: ss.tvkl@gmail.com  
LinkedIn: [linkedin.com/in/soheyltavakkol](https://linkedin.com/in/soheyltavakkol)  
GitHub: [github.com/SoheilTavakkol](https://github.com/SoheilTavakkol)

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
