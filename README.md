Banking Customer Loyalty & Churn Analytics
End-to-End Business Intelligence Data Warehouse Project

Project Overview
A comprehensive Business Intelligence solution for analyzing banking customer behavior, focusing on loyalty patterns and churn prediction. This project demonstrates the complete lifecycle of a Data Warehouse implementation, from requirements gathering to dashboard delivery.
Business Problem
Banks need to identify at-risk customers before they churn and understand what drives customer loyalty. This DW solution provides actionable insights through RF (Recency-Frequency) analysis, customer segmentation, and predictive analytics.

Technology Stack
ComponentTechnologyDatabaseMicrosoft SQL ServerETLSQL Server Integration Services (SSIS)Data WarehouseSQL Server (Star Schema)OLAPSQL Server Analysis Services (SSAS Tabular)VisualizationPower BI / SSRSVersion ControlGit & GitHub

```
Banking-Loyalty-Churn-Analytics/
├── 01-Requirements/
│   └── Requirements-Document.md          ✅ Phase 1 Complete
├── 02-Database-Scripts/
│   ├── Create-DW-Schema.sql             ⏳ Coming Soon
│   ├── Create-Dimensions.sql
│   └── Create-Facts.sql
├── 03-SSIS-Packages/
│   ├── Load-Dim-Customer.dtsx           ⏳ Coming Soon
│   ├── Load-Dim-DateTime.dtsx
│   ├── Load-Dim-Location.dtsx
│   ├── Load-Dim-Segment.dtsx
│   └── Load-Fact-Transaction.dtsx
├── 04-SSAS-Tabular/
│   └── Banking-Tabular-Model.bim        ⏳ Coming Soon
├── 05-PowerBI-Dashboards/
│   ├── Executive-Dashboard.pbix         ⏳ Coming Soon
│   ├── CRM-Dashboard.pbix
│   └── Analyst-Dashboard.pbix
├── 06-Test-Scripts/
│   └── Data-Quality-Tests.sql           ⏳ Coming Soon
└── README.md
```
Key Features
Data Architecture

Star Schema Design with 2 Fact Tables and 4 Dimension Tables
SCD Type 2 implementation for Customer dimension
1M+ transaction records for realistic scale

Analytics Capabilities

RF Segmentation: Champions, Loyal, At-Risk, Churned customers
Churn Prediction: Identify customers likely to leave
KPI Dashboards: 15+ key metrics for decision-making
Trend Analysis: Growth/decline patterns over time

Technical Highlights

Incremental ETL loads for performance
In-memory OLAP with SSAS Tabular
Synthetic data engineering for missing attributes
Comprehensive data quality framework


Project Phases
Phase 1: Requirements Gathering (Completed)

 Business questions definition
 KPI specifications with formulas
 User persona analysis
 Initial dimensional model design
 Technical requirements documentation

View Requirements Document
Phase 2: Physical Environment Setup (In Progress)

 Development environment configuration
 Testing environment setup
 Production environment planning

Phase 3: Data Modeling (Upcoming)

 Detailed dimensional model
 Star schema implementation
 SCD Type 2 logic design

Phase 4: ETL Development (Upcoming)

 SSIS package development
 Data quality checks
 Incremental load logic

Phase 5: OLAP Cube (Upcoming)

 SSAS Tabular model design
 DAX measures implementation
 Performance optimization

Phase 6: Visualization (Upcoming)

 Power BI dashboard design
 User-specific views
 Report automation

Phase 7: Query Optimization (Upcoming)

 Index optimization
 Query performance tuning
 Cube processing optimization

Phase 8: Deployment (Upcoming)

 User acceptance testing
 Training materials
 Production rollout


Sample Insights
Dashboards and visualizations will be added as the project progresses.
Key Questions Answered:

What percentage of customers churned in the last 6 months?
Which customer segments have the highest loyalty scores?
What are the early warning signs of customer churn?
How do satisfaction scores correlate with transaction frequency?


Learning Objectives
This project demonstrates proficiency in:

-Business requirements analysis
-Dimensional modeling (Star Schema, SCD Type 2)
-ETL design patterns and best practices
-OLAP cube development with SSAS Tabular
-DAX formulas and calculated measures
-Data visualization and storytelling
-End-to-end DW project lifecycle


Data Sources
Primary Dataset: Bank Transaction Data (1M+ records)

Customer demographics
Transaction history
Account balances

Engineered Features (Synthetic Data):

Satisfaction scores based on behavioral patterns
Complaint flags derived from transaction trends
Churn indicators from activity patterns

Note: All data is anonymized and used for educational purposes.

How to Use This Repository
Prerequisites

SQL Server 2019+ (Developer/Enterprise Edition)
SQL Server Data Tools (SSDT) for SSIS
Visual Studio with SSAS extension
Power BI Desktop

Setup Instructions

Clone this repository
Follow the setup guide in Phase 2 (coming soon)
Execute database scripts in order
Deploy SSIS packages
Process SSAS Tabular model
Open Power BI dashboards

Detailed setup instructions will be added after Phase 2 completion.

Contact
Soheil Tavakkol

LinkedIn: www.linkedin.com/in/soheyltavakkol
Email: ss.tvkl@gmail.com


License
This project is for educational and portfolio purposes.

Acknowledgments
This project was developed as part of a comprehensive BI learning path, demonstrating real-world data warehousing practices and Microsoft BI stack expertise.

Last Updated: November 2025
Current Phase: Phase 1 Complete - Requirements Gathering 
