# Banking Customer Loyalty & Churn Analytics 

## End-to-End Business Intelligence Data Warehouse Project 

## Project Overview 
A comprehensive Business Intelligence solution for analyzing banking customer behavior, focusing on loyalty patterns and churn prediction. This project demonstrates the complete lifecycle of a Data Warehouse implementation, from requirements gathering to dashboard delivery.

## Business Problem
Banks need to identify at-risk customers before they churn and understand what drives customer loyalty. This DW solution provides actionable insights through RF (Recency-Frequency) analysis, customer segmentation, and predictive analytics.

## Technology Stack

| Component | Technology |
|---------------------------|---------------------------|
| **Database**              | Microsoft SQL Server |
| **ETL**                   | SQL Server Integration Services (SSIS) |
| **Data Warehouse**        | SQL Server (Star Schema) |
| **OLAP**                  | SQL Server Analysis Services (SSAS Tabular) |
| **Visualization**         | Power BI / SSRS |
| **Version Control**       | Git & GitHub |


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
│   ├── 10-Create-Source-Database.sql         ✅ Phase 4 (partial)
│   ├── 11-Data-Profiling.sql                 ✅ Phase 4 (partial)
│   └── README.md
│
├── 03-Data-Modeling/
│   ├── Data-Model-Design.md                  ✅ Phase 3
│   ├── ER-Diagram.md                         ✅ Phase 3
│   ├── Data-Dictionary.md                    ✅ Phase 3
│   └── README.md
│
├── 04-Python-Scripts/
│   ├── import_to_sql.py                      ✅ Data Import
│   └── README.md                             ⏳ Coming Soon
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

## Key Features
### Data Architecture
- Star Schema Design with 2 Fact Tables and 4 Dimension Tables
- SCD Type 2 implementation for Customer dimension
- 1M+ transaction records for realistic scale

### Analytics Capabilities
- RF Segmentation: Champions, Loyal, At-Risk, Churned customers
- Churn Prediction: Identify customers likely to leave
- KPI Dashboards: 15+ key metrics for decision-making
- Trend Analysis: Growth/decline patterns over time

### Technical Highlights
- Incremental ETL loads for performance
- In-memory OLAP with SSAS Tabular
- Synthetic data engineering for missing attributes
- Comprehensive data quality framework


## Project Phases
### Phase 1: Requirements Gathering (Completed)
 - Business questions definition
 - KPI specifications with formulas
 - User persona analysis
 - Initial dimensional model design
 - Technical requirements documentation
View Requirements Document

### Phase 2: Physical Environment Setup (Completed)
- Development environment configuration
- Database and schema creation
- Dimension tables (4 tables with SCD Type 2)
- Fact tables (2 tables - Transaction & Snapshot)
- Indexes, constraints, and relationships
- Pre-populated reference data

** [View Database Scripts](02-Database-Scripts/)**

*Note: Testing and Production environments will be set up during Phase 8 (Deployment)*

### Phase 3: Data Modeling (Completed)
- Detailed dimensional model documentation
- Star schema design and ER diagrams
- SCD Type 2 logic implementation
- Complete data dictionary

** [View Data Modeling Documentation](03-Data-Modeling/)**

*Comprehensive dimensional model with Mermaid diagrams, business rules, and field specifications*

### Phase 4: ETL Development (In Progress)
- [x] Source database setup
- [x] CSV data import (1M+ records)  
- [x] Data profiling and quality analysis
- [ ] Staging layer design
- [ ] SSIS package development
- [ ] Data quality validation
- [ ] SCD Type 2 implementation
- [ ] Incremental load logic

**Current Focus:** Staging layer and ETL pipeline design

### Phase 5: OLAP Cube (Upcoming)
 - SSAS Tabular model design
 - DAX measures implementation
 - Performance optimization

### Phase 6: Visualization (Upcoming)
 - Power BI dashboard design
 - User-specific views
 - Report automation

### Phase 7: Query Optimization (Upcoming)
 - Index optimization
 - Query performance tuning
 - Cube processing optimization

### Phase 8: Deployment (Upcoming)
 - User acceptance testing
 - Training materials
 - Production rollout


## Sample Insights
Dashboards and visualizations will be added as the project progresses.

## Key Questions Answered:
- What percentage of customers churned in the last 6 months?
- Which customer segments have the highest loyalty scores?
- What are the early warning signs of customer churn?
- How do satisfaction scores correlate with transaction frequency?


## Learning Objectives
This project demonstrates proficiency in:
- Business requirements analysis
- Dimensional modeling (Star Schema, SCD Type 2)
- ETL design patterns and best practices
- OLAP cube development with SSAS Tabular
- DAX formulas and calculated measures
- Data visualization and storytelling
- End-to-end DW project lifecycle


## Data Sources
### Primary Dataset: Bank Transaction Data (1M+ records)
- Customer demographics
- Transaction history
- Account balances

### Engineered Features (Synthetic Data):
- Satisfaction scores based on behavioral patterns
- Complaint flags derived from transaction trends
- Churn indicators from activity patterns

_Note: All data is anonymized and used for educational purposes._

## How to Use This Repository
### Prerequisites
- SQL Server 2019+ (Developer/Enterprise Edition)
- Visual Studio with SSIS extension
- Visual Studio with SSAS extension
- Power BI Desktop

## Setup Instructions
- Clone this repository
- Follow the setup guide in Phase 2 (coming soon)
- Execute database scripts in order
- Deploy SSIS packages
- Process SSAS Tabular model
- Open Power BI dashboards

_Detailed setup instructions will be added after Phase 2 completion._

### Contact
Soheil Tavakkol

LinkedIn: www.linkedin.com/in/soheyltavakkol

Email: ss.tvkl@gmail.com


### License
This project is for educational and portfolio purposes.

### Acknowledgments
This project was developed as part of a comprehensive BI learning path, demonstrating real-world data warehousing practices and Microsoft BI stack expertise.

### Last Updated: 
November 2025
### Current Phase: 
Update README: Phase 2 as complete 
