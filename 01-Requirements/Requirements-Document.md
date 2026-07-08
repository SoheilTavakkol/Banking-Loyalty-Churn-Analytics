# Requirements Gathering Document
## Project: Customer Loyalty & Churn Analysis Data Warehouse

**Note on this revision:** This document was originally written at the start of the project (November 2025) as a forward-looking requirements specification. It has since been rewritten, now that the project is complete, to reflect what was actually built: the final schema, the final KPI set (as implemented in the 39 SSAS DAX measures), the three dashboards that were actually delivered, and the scope items that were deliberately descoped along the way. It remains Phase 1 in spirit — the business case, questions, and personas that motivated the project — but the technical specifications below now match the delivered system rather than the original plan.

---

## 1. Business Context

### 1.1 Project Objective
Design and implement a Data Warehouse for analyzing banking customer behavior with focus on:
- **Customer Loyalty Analysis**: Identification and segmentation of loyal customers
- **Customer Churn Prediction**: Identification of at-risk and churned customers based on activity patterns

### 1.2 Data Sources

- **Primary Dataset (seed)**: Bank Transaction Dataset — 1,048,567 records, ~55 days of activity
  - `TransactionID`, `CustomerID`, `CustomerDOB`, `CustGender`, `CustLocation`
  - `CustAccountBalance`, `TransactionDate`, `TransactionTime`, `TransactionAmount`

- **Augmented Dataset**: The 55-day seed was extended to 147,290,230 transaction records spanning 20 months (Jan 2015 – Aug 2016) via a custom Python generator (`generate_transactions_v3_3.py`) — see `04-Python-Scripts/` for the full simulation logic (customer personality archetypes, seasonal patterns, dormancy, shock events, location migration).

- **Synthetic Data** (engineered in ETL, not in Python — see Key Design Decision #6 in the main README):
  - **Satisfaction Score (1.0–5.0)**: Randomized within bands conditioned on Recency/Frequency Score:
    - RecencyScore ≥ 4 AND FrequencyScore ≥ 4 → Random(4.0, 5.0)
    - RecencyScore ≤ 2 AND FrequencyScore ≤ 2 → Random(1.0, 2.5)
    - Otherwise → Random(2.5, 4.0)
  - **Complaint Flag (0/1)**: If GrowthRate < -30% vs. previous month, 70% probability of flag = 1
  - **Churn Flag (0/1)**: `DaysSinceLastTransaction > 90`
  - **At-Risk Flag (0/1)**: `DaysSinceLastTransaction BETWEEN 60 AND 90`
  - **Segment Assignment**: Based on RF (Recency-Frequency) scoring against `Dim_Segment` ranges — see section 5.2

> **Scope note:** The original plan for "Monetary" as a third RFM dimension was dropped early — transaction amounts in the augmented dataset don't reliably differentiate customer value the way Recency and Frequency do, so segmentation was implemented as **RF**, not RFM, throughout the warehouse and semantic layer.

---

## 2. Business Questions

### 2.1 Descriptive Analysis
1. **What percentage of customers experienced growth/decline/stable/churn in the last month?**
   - Strong Growth: >20% increase in transactions vs. previous month
   - Moderate Growth: 5–20% increase
   - Stable: within ±5%
   - Moderate Decline: -20% to -5%
   - Sharp Decline: <-20%
   - Churned: No activity for 90+ days

2. **What percentage of new customers were acquired, and how many convert to loyal segments?**

3. **What is the distribution of customers based on segmentation?**
   - By RF Segments (7 segments)
   - By Gender
   - By Age Groups
   - By Geographic Location (State)
   - By Account Balance / Transaction Amount Levels

### 2.2 Diagnostic Analysis
4. **What common patterns exist among churned and hibernating customers?**
   - Do they have low Satisfaction Scores?
   - Do they have a history of Complaints?
   - Did they show gradual decline in Frequency before going silent?
   - Is churn/hibernation concentrated in specific states, or spread uniformly?

5. **Which customer segments have the highest churn and complaint rates?**
   - Compare Churn Rate and Complaint Rate across the 7 RF Segments
   - Compare by Geographic Location

### 2.3 Retention & Funnel Analysis
6. **Which current customers are at risk of churning?**
   - Customers with `AtRiskFlag = 1` (60–90 days inactive)
   - Customers with declining `GrowthRate` over consecutive months

7. **How effectively do new customers progress through the loyalty funnel?**
   - New → Potential Loyalist → Loyal conversion rate
   - Hibernating → reactivation ("win-back") rate

> **Descoped from original scope:** Formal predictive churn-probability forecasting (next-3-months probability modeling) was part of the original ambition for this document but was not implemented — it would require a dedicated ML layer (see Future Enhancements). The delivered project answers questions 1–7 above descriptively and diagnostically through the Power BI dashboards, not predictively.

---

## 3. Key Performance Indicators (KPIs)

The KPIs below are the ones actually implemented as DAX measures in the SSAS Tabular model (39 measures across 7 Display Folders) and surfaced across the three delivered dashboards (Executive, Marketing, CRM & Retention).

### 3.1 Customer Metrics

| KPI | Calculation Formula | Dashboard(s) |
|-----|---------------------|--------------|
| **Total Customers** | `COUNT(Dim_Customer[CustomerKey])`, latest month | Executive, CRM |
| **Active Customers** | Customers with `TransactionCount > 0` in latest month | Executive |
| **Active Rate** | `(Active Customers / Total Customers) × 100` | Executive |
| **New Customers** | Count where `IsFirstMonth = 1` | Marketing |
| **Customer Growth MoM / QoQ / YoY** | `(Current Period − Prior Period) / Prior Period × 100` | Executive |

### 3.2 Loyalty Metrics

| KPI | Calculation Formula | Dashboard(s) |
|-----|---------------------|--------------|
| **Avg Loyalty Score** | `AVG((RecencyScore × 0.3) + (FrequencyScore × 0.7))` | Executive |
| **Avg Recency Days** | `AVG(DaysSinceLastTransaction)` | — (SSAS layer) |
| **New Customer Retention Rate** | `(New Customers still active next month / New Customers) × 100` | Marketing |
| **Loyal Conversion Rate** | `(Potential Loyalists converted to Loyal / Potential Loyalists) × 100` | Marketing |

### 3.3 Churn & Retention Metrics

| KPI | Calculation Formula | Dashboard(s) |
|-----|---------------------|--------------|
| **Churn Rate** | `(Churned Customers / Total Customers) × 100` | Executive, CRM |
| **At-Risk Rate** | `(At-Risk Customers / Total Customers) × 100` | — (SSAS layer) |
| **Hibernating Customers** | Count of customers in the Hibernating segment | Marketing, CRM |
| **Hibernating Rate** | `(Hibernating Customers / Total Customers) × 100` | Marketing |
| **Churn Trend / MoM / QoQ / YoY Change** | Period-over-period change in Churn Rate | Executive, CRM |

### 3.4 Transaction Metrics

| KPI | Calculation Formula | Dashboard(s) |
|-----|---------------------|--------------|
| **Avg Transaction Amount** | `AVG(TotalTransactionAmount / TransactionCount)` | Executive |
| **Total Transactions** | `SUM(TransactionCount)` | Executive |
| **Transaction Volume Trend** | Monthly trend of Total Transactions | Executive |

### 3.5 Behavior & Complaint Metrics

| KPI | Calculation Formula | Dashboard(s) |
|-----|---------------------|--------------|
| **Total Complaints** | `SUM(ComplaintFlag)` | CRM |
| **Complaint Rate** | `(Complaints / Total Customers) × 100` | CRM |
| **Complaints per 1K Customers** | `(Complaints / Total Customers) × 1000` | CRM |
| **Avg Growth Rate** | `AVG(GrowthRate)` (stored pre-scaled; ÷100 for Percentage format) | Executive |
| **Growing / Declining Customers** | Count by `TrendCategory` | Executive |

### 3.6 Segment Metrics

| KPI | Calculation Formula | Dashboard(s) |
|-----|---------------------|--------------|
| **Customer Count by Segment** | `COUNT(...)` grouped by `SegmentKey` | Executive, Marketing, CRM |
| **Segment Share %** | `(Segment Count / Total Customers) × 100` | Executive |
| **Potential Loyalists** | Count in `RF_Potential` segment | Marketing |
| **Segment Migration (MoM/QoQ/YoY)** | Customers moving between segments period over period | — (SSAS layer) |

### 3.7 NPS (Net Promoter Score)

| KPI | Calculation Formula | Dashboard(s) |
|-----|---------------------|--------------|
| **Promoters / Detractors** | Customers with `SatisfactionScore ≥ 4` / `≤ 2` | — (SSAS layer) |
| **NPS Score** | `DIVIDE([Promoters] − [Detractors], [Total Customers]) × 100` | Executive, CRM |
| **NPS Trend** | Monthly trend of NPS Score | Executive |

> **Confirmed value:** NPS Score ≈ 29.3 in the latest month (Aug 2016), driven by the Satisfaction Score distribution generated in `usp_Merge_CalculateRF`.

---

## 4. User Personas

### 4.1 Bank Manager (CEO/CFO) → **Executive Dashboard** ✅ Delivered
**Needs:**
- Executive-level dashboard with overall customer status, always showing the latest month
- Strategic KPIs comprehensible within seconds
- Segment- and trend-level context without needing to filter

**Common Questions:**
- What percentage of customers are churning?
- Is the customer base growing or shrinking?
- What is the overall loyalty/satisfaction trend?

**Delivered Dashboard:** 6 KPI cards (Total Customers, Active Customers, Avg Loyalty Score, Churn Rate, Avg Transaction Amount, NPS Score) + trend charts (Total vs. Active Customers, Churn vs. Loyalty, Transaction Volume vs. NPS) + segment breakdowns (Growing/Declining by segment, Complaints Distribution, Segment summary table).

### 4.2 CRM Team (CRM Manager, Head of Retail) → **CRM & Retention Dashboard** ✅ Delivered
**Needs:**
- Visibility into at-risk and churned customer volumes
- Complaint pattern analysis
- Geographic concentration of churn/complaints

**Common Questions:**
- How many customers are at risk right now, and is that number growing?
- Which segments generate the most complaints?
- Which states have the highest churn concentration?

**Delivered Dashboard:** 6 KPI cards (Total Customers, Churn Rate, Avg NPS, Hibernating Customers, Total Complaints, Complaints per 1K Customers) + trend charts (Satisfaction vs. Churn, Complaints Volume Trend, Complaints by Segment) + breakdowns (At-Risk vs. Lost Customers trend, Churned Customers by State, Active Segments Volume Trend).

### 4.3 Marketing Team → **Marketing Dashboard** ✅ Delivered
**Needs:**
- Customer segmentation for campaign targeting, organized by lifecycle stage
- Visibility into funnel conversion (new → loyal) and win-back opportunity (hibernating)
- Geographic breakdowns for regional campaign planning

**Common Questions:**
- How many new customers are we acquiring, and are they sticking around?
- What is our Potential Loyalist → Loyal conversion rate?
- Where should we focus win-back campaigns?

**Delivered Dashboard:** 6 KPI cards organized by lifecycle stage (Acquisition: New Customers, Retention Rate; Nurture: Potential Loyalists, Conversion Rate; Win-Back: Hibernating Customers, Hibernating Rate) + trend charts (New Customers by State, Potential Volume & Conversion Rate, Hibernating Rate Trend) + breakdowns (Loyal Conversions by State, Potential→Loyal Funnel, Hibernating Customers by State).

### 4.4 Data Analyst → **Analyst Dashboard** ⏸️ Descoped
**Needs (as originally captured):**
- Access to granular, segment-level data with drill-through
- Ad-hoc slice/dice capability across all dimensions
- Growth rate breakdowns by segment

**Status:** These requirements were captured during Phase 1 but the dedicated Analyst Dashboard was **not built**. The three delivered dashboards (Executive, Marketing, CRM) were judged sufficient to demonstrate the intended range of dashboard design patterns for this portfolio project, and a fourth, largely overlapping dashboard was not pursued. The underlying semantic model (39 DAX measures, all dimension tables) fully supports building this dashboard later if needed — see Future Enhancements.

---

## 5. Dimensional Model (As Built)

### 5.1 Fact Tables

#### Fact_Transaction (Main Transaction Table)
**Grain**: One row per transaction
**Actual volume**: 147,290,230 rows | Jan 2015 – Aug 2016

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| TransactionKey | BIGINT (PK) | Surrogate key |
| CustomerKey | INT (FK) | Link to Dim_Customer (SCD-aware) |
| DateKey | INT (FK) | Link to Dim_Date |
| LocationKey | INT (FK) | Link to Dim_Location |
| TransactionID | VARCHAR(50) | Business key (degenerate dimension) |
| TransactionAmount | DECIMAL(18,2) | Transaction amount |
| AccountBalance | DECIMAL(18,2) | Account balance after transaction |
| TransactionCount | INT | Always = 1 (for COUNT aggregation) |

**Not imported into SSAS** — pre-aggregated into Fact_CustomerSnapshot for reporting.

---

#### Fact_CustomerSnapshot (Periodic Customer Status)
**Grain**: One row per customer per month
**Actual volume**: 13,051,115 rows | Jan 2015 – Aug 2016

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| SnapshotKey | BIGINT (PK) | Surrogate key |
| CustomerKey | INT (FK) | Link to Dim_Customer |
| DateKey | INT (FK) | Link to Dim_Date (end of month) |
| SegmentKey | INT (FK) | Link to Dim_Segment |
| TransactionCount | INT | Number of transactions in the month |
| TotalTransactionAmount | DECIMAL(18,2) | Total transaction amount |
| AvgTransactionAmount | DECIMAL(18,2) | Average transaction amount |
| MinTransactionAmount / MaxTransactionAmount | DECIMAL(18,2) | Min/Max transaction amount |
| DaysSinceLastTransaction | INT | Recency (days since last transaction) |
| RecencyScore | INT | Recency score (1–5) |
| FrequencyScore | INT | Frequency score (0–5) |
| LoyaltyScore | DECIMAL(5,2) | Combined RF loyalty score |
| SatisfactionScore | DECIMAL(3,2) | Satisfaction score (1–5) — Synthetic |
| ComplaintFlag | BIT | Has complaint (0/1) — Synthetic |
| ChurnFlag | BIT | Has churned (0/1) |
| AtRiskFlag | BIT | Is at risk (0/1) |
| TrendCategory | VARCHAR(20) | Strong/Moderate Growth, Stable, Moderate/Sharp Decline, Churned, New |
| PreviousMonthTransactionCount | INT | Previous month transaction count |
| GrowthRate | DECIMAL(5,2) | Growth rate vs. previous month (%, pre-scaled) |
| FinalAccountBalance | DECIMAL(18,2) | End-of-month balance (carried forward) |

---

### 5.2 Dimension Tables

#### Dim_Customer (SCD Type 2)
**Business Key**: CustomerID
**Actual volume**: 1,169,677 total rows / 884,225 current (`IsCurrent = 1`)

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| CustomerKey | INT (PK) | Surrogate key |
| CustomerID | VARCHAR(50) | Business key |
| DateOfBirth | DATE, nullable | Date of birth — NULL if unparseable/out of range |
| Age | INT, nullable | Calculated; NULL if DateOfBirth is NULL |
| AgeGroup | VARCHAR(20) | 18-25, 26-35, 36-45, 46-55, 56+, or "Unknown" |
| Gender | VARCHAR(10) | Male, Female, Unknown |
| Location | NVARCHAR(100) | Geographic location — **SCD Type 2 attribute** |
| LocationKey | INT (FK), nullable | Snowflake link to Dim_Location |
| CustomerType | VARCHAR(20) | New, Existing |
| FirstTransactionDate | DATE | Date of first transaction |
| StartDate / EndDate / IsCurrent | DATE / DATE / BIT | SCD Type 2 versioning |

**SCD Type 2 attribute:** Location only (Age/AgeGroup are Type 1 — overwritten, not versioned, since re-deriving age from a fixed DOB every load makes Type-2 tracking of AgeGroup redundant).

---

#### Dim_Date
**Integrated Date and Time attributes** (superseded the originally planned `Dim_DateTime`, since the transaction dataset only carries date + time-of-day, not true sub-day timestamps requiring their own key granularity)

**Actual volume**: 5,844 rows (2015–2030, pre-populated)

Key columns: `DateKey` (PK, YYYYMMDD), `Date`, `Year`, `Quarter`, `Month`, `MonthName`, `Day`, `DayOfWeek`, `DayName`, `IsWeekend`, `IsWorkingDay`, `FiscalYear`, `FiscalQuarter`, `Hour`, `TimeOfDay`, plus relative-period flags (`IsCurrentMonth`, etc.). Full column list in `Data-Dictionary.md`.

> **Critical usage note carried through the whole project:** real transaction data only spans 2015-01 to 2016-08; every downstream DAX measure anchors to `[_LastDataDateKey]` = `MAX(Fact_CustomerSnapshot[DateKey])`, never to `MAX(Dim_Date[Date])` directly, since the latter resolves to 2030-12-31.

---

#### Dim_Location
**Actual volume**: 9,354 rows

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| LocationKey | INT (PK) | Surrogate key |
| LocationCode | NVARCHAR(100) | Business key: `UPPER(REPLACE(LocationName, ' ', '_'))` |
| LocationName | NVARCHAR(100) | Full location name |
| City | NVARCHAR(100) | City |
| State | NVARCHAR(100) | State/province (99.7% "Unknown" — only 23 cities enriched) |
| Country | NVARCHAR(50) | Country (default "India") |
| Region | NVARCHAR(50) | Geographic region |
| LocationType | NVARCHAR(50) | Classification |

**Role in schema:** Star-joined directly to `Fact_Transaction`, and snowflake-joined from `Dim_Customer` (the model's one deliberate snowflake branch).

---

#### Dim_Segment
**Actual volume**: 7 rows, exhaustive & non-overlapping RF ranges

| SegmentCode | SegmentName | RecencyMin | RecencyMax | FrequencyMin | FrequencyMax |
|-------------|-------------|-----------|-----------|-------------|-------------|
| RF_Champions | Champions | 0 | 59 | 15 | 9999 |
| RF_Loyal | Loyal Customers | 0 | 59 | 8 | 14 |
| RF_Potential | Potential Loyalists | 0 | 59 | 5 | 7 |
| RF_New | New Customers | 0 | 30 | 0 | 4 |
| RF_AtRisk | At Risk | 60 | 90 | 5 | 9999 |
| RF_Hibernating | Hibernating | 31 | 90 | 0 | 4 |
| RF_Churned | Churned | 91 | 9999 | 0 | 9999 |

> **Revision note:** The original draft ranges (see git history) left gaps in the Recency × Frequency space (e.g., Recency 31–59 with Frequency 0–4 matched no segment), which caused foreign-key violations during the Fact_CustomerSnapshot load. Ranges were redesigned and verified programmatically to be exhaustive and non-overlapping before the final load.

---

## 6. Technical Requirements (As Built)

### 6.1 Architecture Stack
- **Source System**: SQL Server database (`BankingSource`) — simulated OLTP, populated by the Python augmentation script
- **Staging**: SQL Server database (`BankingStaging`) — separate database, not schema, for isolation
- **ETL Tool**: SSIS (SQL Server Integration Services), 5 packages + a 5-stage stored-procedure pipeline for the snapshot fact
- **Data Warehouse**: SQL Server (`BankingDW`) — star schema with one snowflaked dimension
- **OLAP Model**: SSAS Tabular (Compatibility Level 1600, VertiPaq in-memory engine)
- **Visualization**: Power BI Desktop, Live Connection to SSAS Tabular

### 6.2 Environment

This is a single-developer portfolio project, built and run entirely in one local development environment (SQL Server Developer Edition + Visual Studio + Power BI Desktop). The original plan's separate Development / Testing / Production environments, environment-sync procedures, and role-based access tiers were **not implemented** — they describe an enterprise deployment pattern that is out of scope for a portfolio project and is captured instead under Future Enhancements / Phase 8.

### 6.3 Data Load Pattern

All fact and dimension tables are loaded via a **one-time, full historical batch load** covering Jan 2015 – Aug 2016 — there is no live source system, so there is no incremental/daily refresh schedule in production use. The ETL packages are fully capable of incremental patterns (see `usp_Load_Fact_Transaction` and the 5-SP snapshot pipeline), but this was exercised only as a full reload during development, not scheduled.

**Actual load runtimes (single full run):**

| Package | Rows | Runtime |
|---|---|---|
| Package 1 — Load Staging | ~157.7M (3 tables) | Parallel |
| Package 2 — Load Dim_Location | 9,354 | ~30 sec |
| Package 3 — Load Dim_Customer | 1,169,677 | 00:01:55 |
| Package 4 — Load Fact_Transaction | 147,290,230 | 00:24:09 |
| Package 5 — Load Fact_CustomerSnapshot | 13,051,115 | 00:10:02 |

### 6.4 ETL Framework
- **Error Handling**: `TRY...CATCH` in every stored procedure, with transaction rollback on failure
- **Data Quality Checks**: Validation flags (`HasInvalidCustomerID`, `HasInvalidDate`, etc.) carried from staging through to load
- **Logging**: `PRINT` statements with row counts and runtimes at each SP boundary (sufficient for a single-developer project; no centralized SSIS logging table was implemented)
- **Restart Capability**: Each SP in the 5-stage snapshot pipeline can be re-run independently against its global temp table inputs, provided upstream steps have completed

---

## 7. Data Quality Rules (As Implemented)

### 7.1 Source Data Validation

| Field | Rule | Actual Handling |
|-------|------|-------------------|
| CustomerID | NOT NULL | Rows with NULL CustomerID excluded from dimension/fact loads |
| TransactionAmount | Numeric | `TRY_CAST(... AS DECIMAL(18,2))`; failures default to 0 |
| TransactionDate | Parseable as dd/mm/yyyy | `TRY_CONVERT(date, ..., 103)` — **not** `TRY_CAST`, which silently dropped ~60% of rows under the server's `DATEFORMAT=mdy` setting |
| Gender | M/F/nan/other | Normalized to 'Male' / 'Female' / 'Unknown' |
| Location | NULL/'nan' | Converted to 'Unspecified' |
| DateOfBirth | Parseable, year 1930–2005 | Outside this range or unparseable → **NULL**, `AgeGroup = "Unknown"` (697,306 rows) — deliberately not imputed with a fabricated default (see Key Design Decision #8 in the main README) |

### 7.2 Business Logic Validation (As Implemented)

| KPI/Measure | Rule | Actual Handling |
|-------------|------|--------|
| RecencyScore | 1–5 | Enforced by `CASE` logic in `usp_Merge_CalculateRF` |
| FrequencyScore | 0–5 | Enforced by `CASE` logic in `usp_Merge_CalculateRF` |
| SatisfactionScore | 1.0–5.0 | Enforced by randomized-band generation logic (see section 1.2) |
| ChurnFlag | `DaysSinceLastTransaction > 90` | Computed directly, no post-hoc correction needed |
| Segment Assignment | Must match a `Dim_Segment` range | Any customer-month that failed to match originally (due to the range-gap bug) caused an FK violation, not a silent "Unclassified" fallback — this forced the range redesign in section 5.2 rather than masking the issue |

### 7.3 Synthetic Data Generation Logic (Final, as implemented in `usp_Merge_CalculateRF`)

```sql
-- Satisfaction Score
CASE
    WHEN RecencyScore >= 4 AND FrequencyScore >= 4
        THEN 4.0 + (ABS(CHECKSUM(NEWID())) % 101) / 100.0   -- 4.0–5.0
    WHEN RecencyScore <= 2 AND FrequencyScore <= 2
        THEN 1.0 + (ABS(CHECKSUM(NEWID())) % 151) / 100.0   -- 1.0–2.5
    ELSE 2.5 + (ABS(CHECKSUM(NEWID())) % 151) / 100.0        -- 2.5–4.0
END AS SatisfactionScore

-- Complaint Flag
CASE
    WHEN GrowthRate < -30 AND (ABS(CHECKSUM(NEWID())) % 100) < 70
        THEN 1
    ELSE 0
END AS ComplaintFlag
```

---

## 8. Success Criteria

### 8.1 Technical Success — Actual Results

| Metric | Original Target | Actual Result |
|--------|--------|-------------|
| ETL completion (full historical load) | > 99% success | 100% — all 5 packages completed without data loss after bug fixes |
| Fact_Transaction load throughput | Not originally specified | 147.3M rows in 24m 9s |
| Fact_CustomerSnapshot load throughput | Not originally specified | 13.05M rows in 10m 2s |
| SSAS model deployment | Successful deployment | 7/7 objects deployed, 13,051,115 rows processed |
| Dashboard load time / query response | < 3–5 seconds | Not formally benchmarked (single-user local Power BI Desktop; informal experience was well within this range) |

> **Scope note:** Formal, ongoing production metrics (daily ETL success rate, cube processing SLA, 95th-percentile query response) don't apply to a project with no scheduled production runs — see section 6.3. The table above reports what was actually measured during the one-time build.

### 8.2 Business Success — Actual Outcome

The original targets in this section (churn identification accuracy > 80%, user adoption rate, daily report usage) assumed a live production rollout to real bank staff, which was never the goal of this portfolio project. The realized business value instead is:

- A working, end-to-end demonstration that the RF-segmentation and churn-flagging logic produces a coherent, internally consistent customer base (e.g., NPS ≈ 29.3, Churn Rate ≈ 15.76%, segment shares summing correctly across 831,639 latest-month customers)
- Three fully functional, audience-appropriate dashboards that a hiring manager or reviewer can open and understand within seconds
- A documented, reproducible pipeline (scripts + SPs + model + measures) that could be pointed at a real OLTP source with minimal rework

### 8.3 User Satisfaction Criteria (Design Intent, Retained from Original)
- Bank Manager: "I can see the overall status in 5 minutes" → addressed by the Executive Dashboard's single-screen KPI + trend layout
- CRM Team: "I can identify where churn/complaints are concentrated" → addressed by the CRM & Retention Dashboard's geographic and segment breakdowns
- Marketing Team: "I can quickly identify target segments and funnel health" → addressed by the Marketing Dashboard's Acquisition/Nurture/Win-Back layout
- Data Analyst: "I can ask any question from the data" → **not addressed by a dedicated dashboard** (see section 4.4); the semantic model itself supports this via Power BI's own ad-hoc exploration against the Live Connection

---

## 9. Future Enhancements

The delivered project has a **deliberately limited scope**. The architecture supports adding the following, none of which were pursued:

### 9.1 Analyst Dashboard
- Segment-level drill-through, growth rate by segment, transaction volume patterns
- All required measures already exist in the SSAS model (39 measures across 7 folders) — this would be a pure Power BI visualization exercise, no further ETL/modeling work needed

### 9.2 Campaign Tracking
- `Dim_Campaign`: Store marketing campaign information
- `Fact_CampaignResponse`: Track customer responses to campaigns
- Impact analysis: campaign impact on Churn and Loyalty

### 9.3 Advanced Analytics
- Machine learning integration (Azure ML or Python) for genuine predictive Churn Probability, rather than the current rule-based `ChurnFlag`/`AtRiskFlag`
- Propensity scoring for cross-sell/up-sell
- Anomaly detection on unusual transaction behaviors (beyond the synthetic "shock events" already in the augmented data)

### 9.4 Real-Time & Production Capabilities (Phase 8 scope, not pursued)
- Incremental/CDC-based load patterns instead of full historical batch load
- Scheduled refresh and near-real-time dashboards
- Formal Dev/Test/Prod environment separation and UAT
- Automated data-quality test suite (`08-Test-Scripts/`)

### 9.5 Additional Data Sources
- Social media sentiment analysis
- Call center / support interaction data
- Banking product usage data (cards, loans, deposits)

---

## 10. Documentation & Knowledge Transfer

### 10.1 Project Documentation

| Document | Status | Description |
|----------|--------|-------------|
| Requirements Document | ✅ Complete (this file, rewritten post-completion) | Business requirements, KPIs, and as-built specifications |
| Database Scripts | ✅ Complete | Database/schema/table creation scripts |
| Data Model Design Document | ✅ Complete | Star schema (with one snowflaked dimension) and ER diagrams |
| Data Dictionary | ✅ Complete | Field specifications, business rules, code values |
| Data Augmentation Guide | ✅ Complete | `generate_transactions_v3_3.py` — Python scripts for extending the dataset |
| ETL / SSIS Documentation | ✅ Complete | All 5 packages + 5-stage SP pipeline documented |
| SSAS Tabular Model Guide | ✅ Complete | Model structure, relationships, 39 DAX measures |
| Power BI Dashboard Documentation | ✅ Complete | Executive, Marketing, CRM & Retention dashboards |
| Deployment & Maintenance Guide | ⏸️ Not Planned | Out of scope — see section 9.4 |

### 10.2 Code Repository Structure (GitHub)

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
│   ├── 12-Alter-Dim-Location-DataTypes.sql         ✅
│   ├── 13-Create-SP-Load-Dim-Customer.sql          ✅
│   ├── 14-Add-LocationCode-To-Staging.sql          ✅
│   ├── 15-Create-SP-Load-Fact-Transaction.sql      ✅
│   └── 16-20-Create-SP-Package5-Tasks.sql          ✅
├── /03-Data-Modeling
│   ├── Data-Model-Design.md                        ✅
│   ├── ER-Diagram.md                               ✅
│   └── Data-Dictionary.md                          ✅
├── /04-Python-Scripts
│   ├── import_to_sql.py                            ✅
│   ├── generate_transactions_v3_3.py               ✅
│   └── requirements.txt                            ✅
├── /05-SSIS-Packages
│   ├── BankingETL/
│   │   ├── Package 1 - Load Staging.dtsx           ✅
│   │   ├── Package 2 - Load Dim_Location.dtsx      ✅
│   │   ├── Package 3 - Load Dim_Customer.dtsx      ✅
│   │   ├── Package 4 - Load Fact_Transaction.dtsx  ✅
│   │   └── Package 5 - CustomerSnapshot.dtsx       ✅
│   └── README.md                                   ✅
├── /06-SSAS-Tabular                                ✅
├── /07-PowerBI-Dashboards                          ✅
└── README.md                                       ✅
```

> `/08-Test-Scripts` was removed from the final repository structure — Phase 8 was not pursued (see section 9.4).

---

**Created:** November 2025
**Version:** 3.0 (Final — rewritten to reflect completed project)
**Status:** Project Complete — Phases 1 through 7
**Author:** Soheil Tavakkol
**Last Updated:** July 2026

---

## Project Progress

**Completed Phases:**
- ✅ Phase 1: Requirements Gathering
- ✅ Phase 2: Physical Environment Setup
- ✅ Phase 3: Data Modeling
- ✅ Phase 4: Data Augmentation (Python)
- ✅ Phase 5: ETL Development (5 packages)
- ✅ Phase 6: SSAS Tabular Model (39 DAX measures)
- ✅ Phase 7: Power BI Dashboards (Executive, Marketing, CRM & Retention)

**Descoped / Not Planned:**
- ⏸️ Analyst Dashboard (originally part of Phase 7 scope — see section 4.4 and 9.1)
- ⏸️ Phase 8: Testing & Deployment (see section 9.4)

**Final ETL Volumes:**
- Package 1: Load Staging (~157.7M records combined)
- Package 2: Load Dim_Location (9,354 locations, ~30 sec)
- Package 3: Load Dim_Customer (1,169,677 rows / 884,225 current, 00:01:55, SCD Type 2)
- Package 4: Load Fact_Transaction (147,290,230 transactions, 00:24:09)
- Package 5: Load Fact_CustomerSnapshot (13,051,115 snapshots, 00:10:02)

**Project Status:** Complete.
