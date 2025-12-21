# Requirements Gathering Document
## Project: Customer Loyalty & Churn Analysis Data Warehouse

---

## 1. Business Context

### 1.1 Project Objective
Design and implement a Data Warehouse for analyzing banking customer behavior with focus on:
- **Customer Loyalty Analysis**: Identification and segmentation of loyal customers
- **Customer Churn Prediction**: Prediction and identification of at-risk customers

### 1.2 Data Sources
- **Primary Dataset**: Bank Transaction Dataset (1M+ records)
  - TransactionID, CustomerID, CustomerDOB, CustGender, CustLocation
  - CustAccountBalance, TransactionDate, TransactionTime, TransactionAmount

- **Synthetic Data** (Engineered based on behavioral patterns):
  - **Satisfaction Score (1-5)**: Calculated based on Frequency and Recency
    - High F + Low R → High Score
    - Low F + High R → Low Score
  - **Complaint Flag (0/1)**: Based on transaction decline patterns
    - If Frequency decreased >30% in last 3 months → Complaint likely
  - **Churn Flag (0/1)**: No activity for more than 90 days
  - **Segment Assignment**: Based on RF Scoring

---

## 2. Business Questions

### 2.1 Descriptive Analysis
1. **What percentage of customers experienced growth/decline/stable/churn in the last 6 months?**
   - Strong Growth: >20% increase in transactions
   - Moderate Growth: 5-20% increase
   - Stable: -5% to +5%
   - Moderate Decline: 5-20% decrease
   - Sharp Decline: >20% decrease
   - Churned: No activity for 90+ days

2. **What percentage of new customers were acquired in the last 6 months?**

3. **What is the distribution of customers based on segmentation?**
   - By RF Segments
   - By Gender
   - By Age Groups
   - By Geographic Location
   - By Account Balance Levels

### 2.2 Diagnostic Analysis
4. **What common patterns exist among churned customers?**
   - Did they have low Satisfaction Scores?
   - Did they have a history of Complaints?
   - Did they show gradual decline in Frequency?
   - Was their Recency increasing?

5. **Which customer segments have the highest churn rates?**
   - Compare Churn Rate across different RF Segments
   - Compare by Demographics
   - Compare by Satisfaction levels

### 2.3 Predictive Analysis
6. **Which current customers are at risk of churning?**
   - Customers with declining Satisfaction Scores
   - Customers with decreasing Frequency
   - Customers with recent Complaints
   - Customers with increasing Recency

7. **What is the probability of new customers becoming loyal?**
   - Based on first 3 months of activity patterns

8. **What is the forecasted Churn Probability for the next 3 months?**
   - Based on current RF Score trends
   - Based on historical patterns

---

## 3. Key Performance Indicators (KPIs)

### 3.1 Customer Activity Metrics

| KPI | Calculation Formula | Description |
|-----|---------------------|-------------|
| **Active Customer Rate** | `(Number of Active Customers / Total Customers) × 100` | Percentage of customers with transactions in last 30/60/90 days |
| **Transaction Frequency** | `Total Transactions / Total Customers / Number of Months` | Average number of transactions per customer per month |
| **Average Transaction Recency** | `AVG(Current Date - Last Transaction Date)` | Average days since last transaction |

### 3.2 Loyalty Metrics

| KPI | Calculation Formula | Description |
|-----|---------------------|-------------|
| **Customer Retention Rate** | `((Customers at End - New Customers) / Customers at Start) × 100` | Customer retention rate in a period |
| **Customer Loyalty Score** | `(Recency Score × 0.3) + (Frequency Score × 0.7)` | Loyalty score based on RF (weights adjustable) |
| **New Customer Conversion Rate** | `(New Customers Became Loyal / Total New Customers) × 100` | Conversion rate of new customers to loyal (after 6 months) |
| **Customer Lifetime (months)** | `Current Date - First Transaction Date` | Customer lifetime in months |

### 3.3 Churn Metrics

| KPI | Calculation Formula | Description |
|-----|---------------------|-------------|
| **Churn Rate** | `(Number of Churned Customers / Total Active Customers at Start) × 100` | Percentage of churned customers in a period |
| **At-Risk Customer Rate** | `(Number of At-Risk Customers / Total Active Customers) × 100` | Percentage of customers with high churn probability |
| **Churn by Segment** | `Churn Rate` grouped by Segment | Churn rate in each segment |
| **Average Days Before Churn** | `AVG(Last Transaction Date - Previous Transaction Date)` for Churned Customers | Average time interval before churn |

### 3.4 Satisfaction Metrics

| KPI | Calculation Formula | Description |
|-----|---------------------|-------------|
| **Average Satisfaction Score** | `AVG(Satisfaction Score)` | Overall average satisfaction (1-5) |
| **Complaint Rate** | `(Customers with Complaints / Total Customers) × 100` | Percentage of customers who complained |
| **Satisfaction Trend** | `(Current Period Avg Score - Previous Period Avg Score) / Previous Period Avg Score × 100` | Percentage change in satisfaction vs. previous period |
| **NPS (Net Promoter Score)** | `% Promoters (Score 4-5) - % Detractors (Score 1-2)` | Customer advocacy index |

---

## 4. User Personas

### 4.1 Bank Manager
**Needs:**
- Executive-level dashboard with overall customer status
- Strategic decision-making based on key KPIs
- Performance comparison between branches/regions

**Common Questions:**
- What percentage of customers are churning?
- Which branches/regions have the most issues?
- What is the overall customer satisfaction trend?

**Dashboard Requirements:**
- KPI Cards (Churn Rate, Active Customers, Avg Satisfaction)
- Trend Charts (monthly/quarterly)
- Geographic Map (Churn by Location)

### 4.2 CRM Team
**Needs:**
- Prioritized list of at-risk customers
- Contact information and interaction history
- Action recommendations

**Common Questions:**
- Which customers should we contact today?
- What message should we send to at-risk customers?
- Which customers are likely to return?

**Dashboard Requirements:**
- Customer List with advanced filters
- Drill-down to individual customer details
- Export to Excel for call lists

### 4.3 Data Analyst
**Needs:**
- Access to granular data
- Drill-down and slice/dice capabilities
- Export to Excel/CSV for deeper analysis
- Ad-hoc query capabilities

**Common Questions:**
- What is the behavioral pattern of customers in group X?
- What is the correlation between Satisfaction and Churn?
- Which factors have the most impact on Churn?

**Dashboard Requirements:**
- Detail Tables with drill-through
- Scatter Plots and Correlation Analysis
- Parameter-based filtering

### 4.4 Marketing Team
**Needs:**
- Customer segmentation for campaign targeting
- Identification of high-value segments
- Campaign effectiveness evaluation

**Common Questions:**
- Which customer segment is suitable for the new campaign?
- What offers should we provide to loyal customers?
- Which age/gender group has the highest growth potential?

**Dashboard Requirements:**
- Segment Analysis Dashboard
- Customer Profiling
- Campaign Performance Tracking (ready for future enhancement)

---

## 5. Initial Dimensional Model

### 5.1 Fact Tables

#### Fact_Transaction (Main Transaction Table)
**Grain**: Each transaction (Transaction-level)

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| TransactionKey | BIGINT (PK) | Surrogate Key |
| CustomerKey | INT (FK) | Link to Dim_Customer |
| DateTimeKey | INT (FK) | Link to Dim_DateTime |
| LocationKey | INT (FK) | Link to Dim_Location |
| TransactionID | VARCHAR(50) | Business Key |
| TransactionAmount | DECIMAL(18,2) | Transaction amount |
| AccountBalance | DECIMAL(18,2) | Account balance after transaction |
| TransactionCount | INT | Always = 1 (for COUNT aggregation) |

**Indexes:**
- Clustered Index on TransactionKey
- Non-Clustered Index on CustomerKey, DateTimeKey

---

#### Fact_CustomerSnapshot (Periodic Customer Status)
**Grain**: Each customer per month (Customer-Month level)

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| SnapshotKey | BIGINT (PK) | Surrogate Key |
| CustomerKey | INT (FK) | Link to Dim_Customer |
| DateKey | INT (FK) | Link to Dim_DateTime (end of month) |
| SegmentKey | INT (FK) | Link to Dim_Segment |
| TransactionCount | INT | Number of transactions in the month |
| TotalTransactionAmount | DECIMAL(18,2) | Total transaction amount |
| AvgTransactionAmount | DECIMAL(18,2) | Average transaction amount |
| DaysSinceLastTransaction | INT | Recency (days since last transaction) |
| RecencyScore | INT | Recency score (1-5) |
| FrequencyScore | INT | Frequency score (1-5) |
| LoyaltyScore | DECIMAL(5,2) | Combined RF loyalty score |
| SatisfactionScore | DECIMAL(3,2) | Satisfaction score (1-5) - Synthetic |
| ComplaintFlag | BIT | Has complaint (0/1) - Synthetic |
| ChurnFlag | BIT | Has churned (0/1) |
| AtRiskFlag | BIT | Is at risk (0/1) |
| TrendCategory | VARCHAR(20) | Strong/Moderate Growth/Stable/Moderate/Sharp Decline/Churned |
| PreviousMonthTransactionCount | INT | Previous month transaction count |
| GrowthRate | DECIMAL(5,2) | Growth rate vs. previous month (%) |

**Indexes:**
- Clustered Index on SnapshotKey
- Non-Clustered Index on CustomerKey, DateKey, SegmentKey

---

### 5.2 Dimension Tables

#### Dim_Customer (SCD Type 2)
**Business Key**: CustomerID

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| CustomerKey | INT (PK) | Surrogate Key |
| CustomerID | VARCHAR(50) | Business Key |
| DateOfBirth | DATE | Date of birth |
| Age | INT | Age (calculated) |
| AgeGroup | VARCHAR(20) | 18-25, 26-35, 36-45, 46-55, 56+ |
| Gender | VARCHAR(10) | Male, Female, Unknown |
| Location | VARCHAR(100) | Geographic location |
| CustomerType | VARCHAR(20) | New, Existing |
| FirstTransactionDate | DATE | Date of first transaction |
| **StartDate** | DATE | Effective start date (SCD Type 2) |
| **EndDate** | DATE | Effective end date (NULL = current) |
| **IsCurrent** | BIT | Is current record (1/0) |

**SCD Type 2 Attributes:**
- Location (if changed, creates new record)
- AgeGroup (if moved to next group)

**Indexes:**
- Clustered Index on CustomerKey
- Non-Clustered Index on CustomerID, IsCurrent

---

#### Dim_DateTime
**Integrated Date and Time**

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| DateTimeKey | INT (PK) | Surrogate Key (Format: YYYYMMDDHH) |
| FullDateTime | DATETIME | Full date and time |
| Date | DATE | Date |
| Year | INT | Year |
| Quarter | INT | Quarter (1-4) |
| Month | INT | Month (1-12) |
| MonthName | VARCHAR(20) | Month name |
| Day | INT | Day of month |
| DayOfWeek | INT | Day of week (1-7) |
| DayName | VARCHAR(20) | Day name |
| IsWeekend | BIT | Is weekend |
| IsHoliday | BIT | Is holiday |
| FiscalYear | INT | Fiscal year |
| FiscalQuarter | INT | Fiscal quarter |
| Time | TIME | Time |
| Hour | INT | Hour (0-23) |
| Minute | INT | Minute (0-59) |
| TimeOfDay | VARCHAR(20) | Morning/Afternoon/Evening/Night |

**Pre-populated**: This table is pre-filled with all dates (e.g., 2015-2030)

---

#### Dim_Location

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| LocationKey | INT (PK) | Surrogate Key |
| Location | VARCHAR(100) | Full location name |
| City | VARCHAR(50) | City |
| State | VARCHAR(50) | State/Province |
| Country | VARCHAR(50) | Country |
| Region | VARCHAR(50) | Geographic region |

---

#### Dim_Segment
**Independent storage of segmentation logic**

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| SegmentKey | INT (PK) | Surrogate Key |
| SegmentCode | VARCHAR(50) | Segment code (e.g., "RF_High") |
| SegmentName | VARCHAR(100) | Segment name (e.g., "Champion") |
| SegmentType | VARCHAR(50) | Segment type (RF, Demographic, Behavioral) |
| Description | VARCHAR(500) | Segmentation logic description (e.g., "R<30, F>10") |
| RecencyMin | INT | Minimum Recency for this segment |
| RecencyMax | INT | Maximum Recency |
| FrequencyMin | INT | Minimum Frequency |
| FrequencyMax | INT | Maximum Frequency |
| IsActive | BIT | Active or deprecated |
| StartDate | DATE | Effective date (SCD Type 2) |
| EndDate | DATE | End date |

**Sample Records:**

| SegmentCode | SegmentName | Description | RecencyMin | RecencyMax | FrequencyMin | FrequencyMax |
|-------------|-------------|-------------|------------|------------|--------------|--------------|
| RF_Champions | Champions | R<30, F>15 | 0 | 30 | 15 | 9999 |
| RF_Loyal | Loyal Customers | R<60, F>8 | 0 | 60 | 8 | 14 |
| RF_AtRisk | At Risk | R>60, F>8 | 60 | 90 | 8 | 9999 |
| RF_Churned | Churned | R>90 | 90 | 9999 | 0 | 9999 |

---

## 6. Technical Requirements

### 6.1 Architecture Stack
- **Source System**: SQL Server Database (OLTP - Simulated)
- **ETL Tool**: SSIS (SQL Server Integration Services)
- **Data Warehouse**: SQL Server (Star Schema)
- **OLAP Model**: SSAS Tabular (In-Memory VertiPaq Engine)
- **Visualization**: Power BI Desktop / SSRS

### 6.2 Environments

| Environment | Purpose | Hardware | Access |
|-------------|---------|----------|--------|
| **Development** | ETL Development, Cube Design | Local Machine / VM | Developer Only |
| **Testing** | UAT, Performance Testing | Separate Server | QA Team + Developer |
| **Production** | End-User Access | Dedicated Server | All Users (Read-Only) |

**Environment Sync:**
- Mirrored schemas across all environments
- Production-like data volume in Testing (via data masking/sampling)

### 6.3 Data Refresh Schedule

| Object | Frequency | Time | Method |
|--------|-----------|------|--------|
| Fact_Transaction | Daily | 2:00 AM | Incremental Load (last 24h) |
| Fact_CustomerSnapshot | Monthly | 1st day 3:00 AM | Full Refresh |
| Dim_Customer | Daily | 1:30 AM | SCD Type 2 Update |
| Dim_Location | On-Demand | Manual | Full Refresh |
| Dim_Segment | As Needed | Manual | Full Refresh |
| Dim_DateTime | One-Time | - | Pre-populated |

### 6.4 ETL Framework
- **Logging**: SSIS Logging to SQL Server Table
- **Error Handling**: Try-Catch in each Data Flow
- **Restart Capability**: Checkpoint for long-running packages
- **Data Quality Checks**: Pre/Post ETL Validation

---

## 7. Data Quality Rules

### 7.1 Source Data Validation

| Field | Rule | Action on Failure |
|-------|------|-------------------|
| CustomerID | NOT NULL | Reject Record |
| TransactionAmount | > 0 AND < 1,000,000 | Flag for Review |
| TransactionDate | Between '2015-01-01' AND Current Date | Reject Record |
| Gender | IN ('M', 'F', NULL) | Convert NULL to 'Unknown' |
| Location | NOT NULL | Convert to 'Unspecified' |
| DateOfBirth | Customer Age between 18-100 | Reject Record |

### 7.2 Business Logic Validation

| KPI/Measure | Rule | Action |
|-------------|------|--------|
| Recency Score | Between 1-5 | Log Warning |
| Frequency Score | Between 1-5 | Log Warning |
| Satisfaction Score | Between 1-5 | Recalculate if out of range |
| Churn Flag | If Recency > 90 then 1, else 0 | Auto-correct |
| Segment Assignment | Must match Dim_Segment rules | Assign to "Unclassified" |

### 7.3 Handling Missing/Invalid Data

**Synthetic Data Generation Logic:**

```
IF Frequency > 10 AND Recency < 30 THEN
    SatisfactionScore = 4 + (RAND() * 1)  -- Between 4-5
ELSE IF Frequency < 3 AND Recency > 60 THEN
    SatisfactionScore = 1 + (RAND() * 1.5)  -- Between 1-2.5
ELSE
    SatisfactionScore = 2.5 + (RAND() * 1.5)  -- Between 2.5-4
END IF

IF (Previous_Frequency - Current_Frequency) / Previous_Frequency > 0.3 THEN
    ComplaintFlag = 1  -- 70% probability of complaint
ELSE
    ComplaintFlag = 0
END IF
```

---

## 8. Success Criteria

### 8.1 Technical Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| ETL Success Rate | > 99% | Daily Execution Logs |
| Data Quality Score | > 98% | Pre/Post ETL Validation |
| Query Response Time | < 5 seconds | 95th Percentile |
| Cube Processing Time | < 30 minutes | Monthly Refresh Log |
| Dashboard Load Time | < 3 seconds | User Experience Testing |

### 8.2 Business Success Metrics

| Metric | Target | Timeline |
|--------|--------|----------|
| Churn Identification Accuracy | > 80% | After 3 months |
| At-Risk Customer Detection | > 75% | Continuous |
| User Adoption Rate | > 70% of target users | After 6 months |
| Report Usage Frequency | Daily access by 50%+ users | After rollout |

### 8.3 User Satisfaction Criteria
- Bank Manager: "I can see the overall status in 5 minutes"
- CRM Team: "I receive my daily call list automatically"
- Data Analyst: "I can ask any question from the data"
- Marketing Team: "I can quickly identify target segments"

---

## 9. Future Enhancements

The current project has a **deliberately limited scope** to ensure feasibility within a reasonable timeframe. The designed architecture easily supports adding the following capabilities:

### 9.1 Campaign Tracking
- **Dim_Campaign**: Store marketing campaign information
- **Fact_CampaignResponse**: Track customer responses to campaigns
- **Impact Analysis**: Campaign impact on Churn and Loyalty

### 9.2 Advanced Analytics
- **Machine Learning Integration**: Use Azure ML or Python for advanced Churn Prediction
- **Predictive Scoring**: Calculate Propensity Score for Cross-sell/Up-sell
- **Anomaly Detection**: Identify unusual transaction behaviors

### 9.3 Real-Time Capabilities
- **Near Real-Time Dashboard**: Faster than daily refresh
- **Alert System**: Automatic alerts for at-risk customers

### 9.4 Additional Data Sources
- **Social Media Sentiment**: Customer sentiment analysis from social media
- **Call Center Data**: Integration of call and support data
- **Product Usage**: Banking product usage data (cards, loans, deposits)

---

## 10. Documentation & Knowledge Transfer

## 10.1 Project Documentation

This document is part of the project documentation suite:

| Document | Status | Description |
|----------|--------|-------------|
| Requirements Document | ✅ Complete | This file - business requirements and KPIs |
| Physical Environment Setup Guide | ✅ Complete | Database creation scripts and setup |
| Data Model Design Document | ✅ Complete | Star schema and ER diagrams |
| Data Dictionary | ✅ Complete | Field specifications and business rules |
| Data Augmentation Guide | ✅ Complete | Python scripts for extending dataset |
| ETL Specification Document | ✅ Complete | SSIS package documentation (40% complete) |
| SSAS Tabular Model Guide | 🔄 In Progress | Cube design and DAX measures |
| Dashboard User Guide | ⏳ Upcoming | Power BI dashboard usage |
| Deployment & Maintenance Guide | ⏳ Upcoming | Production deployment procedures |

## 10.2 Code Repository Structure (GitHub)
```
/Banking-Loyalty-Churn-Analytics
├── /01-Requirements
│   └── Requirements-Document.md                    ✅
├── /02-Database-Scripts
│   ├── 01-1-Create-BankingDW.sql                   ✅
│   ├── 01-2-Create-BankingStaging.sql              ✅
│   ├── 02-Create-Schema.sql                        ✅
│   ├── 03-Create-Dim-Date.sql                      ✅
│   ├── 04-Populate-Dim-Date.sql                    ✅
│   ├── 05-Create-Dim-Location.sql                  ✅
│   ├── 06-Create-Dim-Customer.sql                  ✅
│   ├── 07-Create-Dim-Segment.sql                   ✅
│   ├── 08-Create-Fact-Transaction.sql              ✅
│   ├── 09-Create-Fact-CustomerSnapshot.sql         ✅
│   ├── 10-Create-Source-Database.sql               ✅
│   ├── 11-Data-Profiling.sql                       ✅
│   └── 12-Alter-Dim-Location-DataTypes.sql         ✅
├── /03-Data-Modeling
│   ├── Data-Model-Design.md                        ✅
│   ├── ER-Diagram.md                               ✅
│   └── Data-Dictionary.md                          ✅
├── /04-Python-Scripts
│   ├── import_to_sql.py                            ✅
│   ├── generate_extended_transactions.py           ✅
│   └── requirements.txt                            ✅
├── /05-SSIS-Packages
│   ├── BankingETL/
│   │   ├── Package 1 - Load Staging.dtsx           ✅
│   │   ├── Package 2 - Load Dim_Location.dtsx      ✅
│   │   ├── Package 3 - Load Dim_Customer.dtsx      ✅
│   │   ├── Package 4 - Load Fact_Transaction.dtsx  ✅
│   │   └── Package 5 - CustomerSnapshot.dtsx       ✅
│   └── README.md                                   ✅
├── /06-SSAS-Tabular                                ⏳
├── /07-PowerBI-Dashboards                          ⏳
├── /08-Test-Scripts                                ⏳
└── README.md                                       ✅
```

---

---

**Created:** November 2025  
**Version:** 2.2  
**Status:** In Progress - Phase 6 (SSAS Tabular Model)  
**Author:** Soheil Tavakkol  
**Last Updated:** December 29, 2025

---

## Project Progress

**Completed Phases:**
    ✅ Phase 1: Requirements Gathering
    ✅ Phase 2: Physical Environment Setup
    ✅ Phase 3: Data Modeling
    ✅ Phase 4: Data Augmentation (Python)
    ✅ Phase 5: ETL Development (100% - All 5 packages completed)

**ETL Package Status:**
    ✅ Package 1: Load Staging (155M records, ~30 min)
    ✅ Package 2: Load Dim_Location (9K locations, ~30 sec)
    ✅ Package 3: Load Dim_Customer (884K customers, ~50 sec, SCD Type 2)
    ✅ Package 4: Load Fact_Transaction (154M transactions, ~108 min)
    ✅ Package 5: Load Fact_CustomerSnapshot (15.6M snapshots, ~13 min)

**Next Milestone:** Phase 6 - SSAS Tabular Model Development
