-- ===================================
-- Phase 2: Create Fact_CustomerSnapshot
-- Monthly customer-level snapshot fact table
-- ===================================

USE BankingDW;
GO

-- Drop table if exists
IF OBJECT_ID('DW.Fact_CustomerSnapshot', 'U') IS NOT NULL
    DROP TABLE DW.Fact_CustomerSnapshot;
GO

-- Create Fact_CustomerSnapshot
CREATE TABLE DW.Fact_CustomerSnapshot
(
    -- Surrogate Key
    SnapshotKey         BIGINT IDENTITY(1,1) PRIMARY KEY,
    
    -- Foreign Keys to Dimensions
    CustomerKey         INT NOT NULL,                    -- FK to Dim_Customer
    DateKey             INT NOT NULL,                    -- FK to Dim_Date (end of month)
    SegmentKey          INT NULL,                        -- FK to Dim_Segment
    
    -- Transaction Measures (Monthly aggregates)
    TransactionCount    INT NOT NULL DEFAULT 0,          -- Number of transactions in month
    TotalTransactionAmount DECIMAL(18, 2) NOT NULL DEFAULT 0,
    AvgTransactionAmount DECIMAL(18, 2) NULL,            -- Average transaction amount
    MinTransactionAmount DECIMAL(18, 2) NULL,
    MaxTransactionAmount DECIMAL(18, 2) NULL,
    
    -- RF Analysis Measures
    DaysSinceLastTransaction INT NULL,                   -- Recency (days from month end)
    RecencyScore        INT NULL,                        -- Recency score (1-5)
    FrequencyScore      INT NULL,                        -- Frequency score (1-5)
    LoyaltyScore        DECIMAL(5, 2) NULL,              -- Combined RF score
    
    -- Customer Behavior Measures (Synthetic Data)
    SatisfactionScore   DECIMAL(3, 2) NULL,              -- Customer satisfaction (1-5)
    ComplaintFlag       BIT NOT NULL DEFAULT 0,          -- Has complaint in this month
    
    -- Churn & Risk Indicators
    ChurnFlag           BIT NOT NULL DEFAULT 0,          -- Is churned (>90 days inactive)
    AtRiskFlag          BIT NOT NULL DEFAULT 0,          -- At risk of churning
    
    -- Trend Analysis
    TrendCategory       VARCHAR(20) NULL,                -- Growth/Stable/Decline/Churned
    PreviousMonthTransactionCount INT NULL,              -- For calculating growth
    GrowthRate          DECIMAL(5, 2) NULL,              -- % change vs previous month
    
    -- Account Status
    FinalAccountBalance DECIMAL(18, 2) NULL,             -- Balance at end of month
    
    -- Audit
    ETLLoadDate         DATETIME NOT NULL DEFAULT GETDATE(),
    ETLBatchID          INT NULL
);
GO

-- Create Foreign Keys
ALTER TABLE DW.Fact_CustomerSnapshot
    ADD CONSTRAINT FK_Fact_CustomerSnapshot_Customer 
    FOREIGN KEY (CustomerKey) REFERENCES DW.Dim_Customer(CustomerKey);

ALTER TABLE DW.Fact_CustomerSnapshot
    ADD CONSTRAINT FK_Fact_CustomerSnapshot_Date 
    FOREIGN KEY (DateKey) REFERENCES DW.Dim_Date(DateKey);

ALTER TABLE DW.Fact_CustomerSnapshot
    ADD CONSTRAINT FK_Fact_CustomerSnapshot_Segment 
    FOREIGN KEY (SegmentKey) REFERENCES DW.Dim_Segment(SegmentKey);
GO

-- Create Indexes for Performance
CREATE NONCLUSTERED INDEX IX_Fact_CustomerSnapshot_CustomerKey 
    ON DW.Fact_CustomerSnapshot(CustomerKey)
    INCLUDE (DateKey, TransactionCount, LoyaltyScore);

CREATE NONCLUSTERED INDEX IX_Fact_CustomerSnapshot_DateKey 
    ON DW.Fact_CustomerSnapshot(DateKey)
    INCLUDE (CustomerKey, SegmentKey, ChurnFlag);

CREATE NONCLUSTERED INDEX IX_Fact_CustomerSnapshot_Customer_Date 
    ON DW.Fact_CustomerSnapshot(CustomerKey, DateKey)
    INCLUDE (RecencyScore, FrequencyScore, LoyaltyScore);

CREATE NONCLUSTERED INDEX IX_Fact_CustomerSnapshot_SegmentKey 
    ON DW.Fact_CustomerSnapshot(SegmentKey)
    INCLUDE (CustomerKey, DateKey, TransactionCount);

CREATE NONCLUSTERED INDEX IX_Fact_CustomerSnapshot_ChurnFlag 
    ON DW.Fact_CustomerSnapshot(ChurnFlag)
    WHERE ChurnFlag = 1;

CREATE NONCLUSTERED INDEX IX_Fact_CustomerSnapshot_AtRiskFlag 
    ON DW.Fact_CustomerSnapshot(AtRiskFlag)
    WHERE AtRiskFlag = 1;
GO

-- Create Statistics
CREATE STATISTICS STAT_Fact_CustomerSnapshot_Recency 
    ON DW.Fact_CustomerSnapshot(DaysSinceLastTransaction);

CREATE STATISTICS STAT_Fact_CustomerSnapshot_Frequency 
    ON DW.Fact_CustomerSnapshot(TransactionCount);

CREATE STATISTICS STAT_Fact_CustomerSnapshot_Loyalty 
    ON DW.Fact_CustomerSnapshot(LoyaltyScore);

CREATE STATISTICS STAT_Fact_CustomerSnapshot_Satisfaction 
    ON DW.Fact_CustomerSnapshot(SatisfactionScore);
GO

PRINT 'Fact_CustomerSnapshot created successfully!';
GO

-- Display structure
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'DW' 
    AND TABLE_NAME = 'Fact_CustomerSnapshot'
ORDER BY ORDINAL_POSITION;
GO