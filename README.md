# Banking Customer Loyalty & Churn Analytics
**End-to-End Business Intelligence Data Warehouse Project**

## Project Overview

A comprehensive Business Intelligence solution for analyzing banking customer behavior, focusing on loyalty patterns and churn prediction. This project demonstrates the complete lifecycle of a Data Warehouse implementation, from requirements gathering to dashboard delivery.

## Business Problem

Banks need to identify at-risk customers before they churn and understand what drives customer loyalty. This DW solution provides actionable insights through RF (Recency-Frequency) analysis, customer segmentation, and predictive analytics.

---

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Database | Microsoft SQL Server |
| ETL | SQL Server Integration Services (SSIS) |
| Data Warehouse | SQL Server (Star Schema) |
| OLAP | SQL Server Analysis Services (SSAS Tabular) |
| Visualization | Power BI / SSRS |
| Scripting | Python 3.x |
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
│   ├── 01-Create-Database.sql                ✅ Phase 2
│   ├── 02-Create-Schema.sql                  ✅ Phase 2
│   ├── 03-Create-Dim-Date.sql                ✅ Phase 2
│   ├── 04-Populate-Dim-Date.sql              ✅ Phase 2
│   ├── 05-Create-Dim-Location.sql            ✅ Phase 2
│   ├── 06-Create-Dim-Customer.sql            ✅ Phase 2
│   ├── 07-Create-Dim-Segment.sql             ✅ Phase 2
│   ├── 08-Create-Fact-Transaction.sql        ✅ Phase 2
│   ├── 09-Create-Fact-CustomerSnapshot.sql   ✅ Phase 2
│   ├── 10-Create-Source-Database.sql         ✅ Phase 4
│   ├── 11-Data-Profiling.sql                 ✅ Phase 4
│   ├── 12-Create-Staging-Tables.sql          ✅ Phase 4
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
├── 05-SSIS-Packages/                         ⏳ Phase 5 (upcoming)
│   ├── 00-Master-Package.dtsx
│   ├── 01-Load-Staging.dtsx
│   ├── 02-Load-Dim-Location.dtsx
│   ├── 03-Load-Dim-Customer.dtsx
│   ├── 04-Load-Fact-Transaction.dtsx
│   ├── 05-Calculate-CustomerSnapshot.dtsx
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
- **Star Schema Design** with 2 Fact Tables and 4 Dimension Tables
- **SCD Type 2** implementation for Customer dimension
- **1M+ transaction records** for realistic scale
- **18-month temporal coverage** (Jan 2015 - Aug 2016)

### Analytics Capabilities
- **RF Segmentation:** Champions, Loyal, At-Risk, Churned customers
- **Churn Prediction:** Identify customers likely to leave
- **KPI Dashboards:** 15+ key metrics for decision-making
- **Trend Analysis:** Growth/decline patterns over time

### Technical Highlights
- Incremental ETL loads for performance
- In-memory OLAP with SSAS Tabular
- Smart data augmentation for comprehensive analysis
- Comprehensive data quality framework
- SCD Type 2 for historical tracking

---

## Data Sources

### Dataset: Synthetic Banking Transactions
**1M+ transaction records** spanning 18 months (Jan 2015 - Aug 2016), generated using smart data augmentation to simulate realistic customer behavioral patterns.

**Core Attributes:**
- Customer demographics (DOB, Gender, Location)
- Transaction history (Date, Time, Amount)
- Account balances

**Engineered Features (Calculated in ETL):**
- Satisfaction scores based on RF patterns
- Complaint flags derived from transaction trends
- Churn indicators from activity patterns
- Customer segmentation (Champions, Loyal, At-Risk, Churned)

> **Note:** All data is synthetic and anonymized, created for educational and portfolio purposes.

---

## Data Augmentation Strategy

### Challenge
The original dataset contained only 18 days of transaction data (Aug 13-31, 2016), which was insufficient for:
- Churn analysis (requires 90+ days of inactivity)
- RF segmentation (needs multi-month patterns)
- Trend analysis (growth/decline over 6+ months)

### Solution
Implemented a **smart data augmentation pipeline** using Python to:

1. **Temporal Expansion:** Extended 18 days → 18 months (Jan 2015 - Aug 2016)
2. **Customer Journey Simulation:** Created diverse behavioral patterns:
   - **Champions (20%):** High frequency, consistent activity
   - **Loyal (25%):** Moderate frequency, stable patterns
   - **At-Risk (20%):** Declining activity over time
   - **Churned (20%):** Activity cessation after 90+ days
   - **New Customers (15%):** Recent acquisition patterns

3. **Realistic Variability:**
   - Transaction frequency varies by customer segment
   - Account balances evolve based on transaction patterns
   - Seasonal and monthly variations
   - Organic customer lifecycle progression

### Architecture Decision
**Why Python for augmentation, not ETL?**
- **Separation of Concerns:** Raw data generation vs. business logic
- **Auditability:** Clear distinction between source data and calculated metrics
- **Flexibility:** Business rules (Satisfaction, Churn) remain in ETL layer for easy modification
- **Best Practice:** Keep ETL focused on transformation, not generation

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
- Development environment configuration
- Database and schema creation (BankingDW, BankingSource)
- **Dimension tables** (4 tables):
  - `Dim_Date` (pre-populated 2015-2030)
  - `Dim_Customer` (SCD Type 2 for location tracking)
  - `Dim_Location` (geographic hierarchy)
  - `Dim_Segment` (RF segmentation rules)
- **Fact tables** (2 tables):
  - `Fact_Transaction` (transaction-level grain)
  - `Fact_CustomerSnapshot` (customer-month grain)
- Indexes, constraints, and relationships
- Pre-populated reference data

📄 [View Database Scripts](02-Database-Scripts/)

> **Note:** Testing and Production environments will be set up during Phase 8 (Deployment)

---

### ✅ Phase 3: Data Modeling (Completed)
- Detailed dimensional model documentation
- Star schema design and ER diagrams (Mermaid)
- SCD Type 2 logic implementation
- Complete data dictionary with business rules

📄 [View Data Modeling Documentation](03-Data-Modeling/)

**Highlights:**
- Comprehensive field specifications
- Business rule documentation
- Query pattern examples
- SCD Type 2 flow diagrams

---

### 🔄 Phase 4: ETL Development (Data Preparation Complete)

**Completed:**
- ✅ Source database setup (BankingSource)
- ✅ CSV data import (1M+ records)
- ✅ Data profiling and quality analysis
- ✅ Smart data augmentation (18 days → 18 months)
- ✅ Staging layer design (3 staging tables)

**In Progress:**
- ⏳ SSIS package development
- ⏳ Data cleansing and transformation logic
- ⏳ SCD Type 2 implementation
- ⏳ Synthetic field calculation (Satisfaction, Churn, Complaints)
- ⏳ Incremental load logic

📄 [View Python Scripts](04-Python-Scripts/) | [View Staging Scripts](02-Database-Scripts/)

**Current Focus:** ETL pipeline design and SSIS package development

---

### ⏳ Phase 5: OLAP Cube (Upcoming)
- SSAS Tabular model design
- DAX measures implementation (15+ KPIs)
- Performance optimization
- Row-level security (if needed)

---

### ⏳ Phase 6: Visualization (Upcoming)
- Power BI dashboard design
- User-specific views (Executive, CRM, Analyst, Marketing)
- Report automation
- Interactive drill-through capabilities

---

### ⏳ Phase 7: Query Optimization (Upcoming)
- Index optimization
- Query performance tuning
- Cube processing optimization
- Partitioning strategy

---

### ⏳ Phase 8: Deployment (Upcoming)
- User acceptance testing (UAT)
- Training materials
- Production rollout
- Monitoring and maintenance procedures

---

## Sample Insights

Dashboards and visualizations will be added as the project progresses.

### Key Questions Answered:
- What percentage of customers churned in the last 6 months?
- Which customer segments have the highest loyalty scores?
- What are the early warning signs of customer churn?
- How do satisfaction scores correlate with transaction frequency?
- Which demographics show the strongest retention rates?
- What transaction patterns indicate at-risk customers?

---

## Learning Objectives

This project demonstrates proficiency in:

- ✅ Business requirements analysis and KPI definition
- ✅ Dimensional modeling (Star Schema, SCD Type 2)
- ✅ Data quality profiling and cleansing strategies
- ✅ Smart data augmentation for realistic datasets
- ⏳ ETL design patterns and best practices
- ⏳ SSIS package development
- ⏳ OLAP cube development with SSAS Tabular
- ⏳ DAX formulas and calculated measures
- ⏳ Data visualization and storytelling
- ⏳ End-to-end DW project lifecycle

---

## How to Use This Repository

### Prerequisites
- SQL Server 2019+ (Developer/Enterprise Edition)
- Python 3.8+ with required packages
- Visual Studio with SSIS extension
- Visual Studio with SSAS extension
- Power BI Desktop

### Setup Instructions

1. **Clone the repository**
```bash
   git clone https://github.com/SoheilTavakkol/Banking-Loyalty-Churn-Analytics.git
   cd Banking-Loyalty-Churn-Analytics
```

2. **Set up the database environment**
   - Execute scripts in `02-Database-Scripts/` in numerical order
   - This creates BankingDW and BankingSource databases

3. **Prepare the data**
```bash
   cd 04-Python-Scripts
   pip install -r requirements.txt
   python import_to_sql.py          # Import original CSV
   python generate_extended_transactions.py  # Augment data
```

4. **Run ETL packages** (Coming in Phase 5)
   - Deploy SSIS packages from `05-SSIS-Packages/`
   - Execute Master Package for full load

5. **Process OLAP cube** (Coming in Phase 6)
   - Deploy SSAS Tabular model
   - Process cube

6. **Open dashboards** (Coming in Phase 7)
   - Open Power BI files in `07-PowerBI-Dashboards/`

> Detailed setup instructions will be added as each phase is completed.

---

## Project Status

**Current Phase:** Phase 4 - ETL Development (Data Preparation Complete)

**Last Updated:** November 2025

**Next Milestone:** SSIS Package Development for staging and dimension loading

---

## Contact

**Soheil Tavakkol**

 Email: ss.tvkl@gmail.com  
 LinkedIn: [linkedin.com/in/soheyltavakkol](https://www.linkedin.com/in/soheyltavakkol)

---

## License

This project is for educational and portfolio purposes.

---

## Acknowledgments

This project was developed as part of a comprehensive BI learning path, demonstrating real-world data warehousing practices and Microsoft BI stack expertise.

**Key Techniques Demonstrated:**
- Handling data limitations through smart augmentation
- Dimensional modeling best practices
- SCD Type 2 implementation
- Separation of concerns in data architecture
- End-to-end BI solution design
