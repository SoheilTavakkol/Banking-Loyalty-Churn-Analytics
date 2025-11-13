-- ===================================
-- Phase 2: Create Fact_Transaction
-- Transaction-level fact table
-- ===================================

USE BankingDW;
GO

-- Drop table if exists
IF OBJECT_ID('DW.Fact_Transaction', 'U') IS NOT NULL
    DROP TABLE DW.Fact_Transaction;
GO

-- Create Fact_Transaction
CREATE TABLE DW.Fact_Transaction
(
    -- Surrogate Key
    TransactionKey      BIGINT IDENTITY(1,1) PRIMARY KEY,
    
    -- Foreign Keys to Dimensions
    CustomerKey         INT NOT NULL,                    -- FK to Dim_Customer
    DateKey             INT NOT NULL,                    -- FK to Dim_Date
    LocationKey         INT NULL,                        -- FK to Dim_Location
    
    -- Degenerate Dimension (Business Key stored in Fact)
    TransactionID       VARCHAR(50) NOT NULL,            -- Original transaction ID
    
    -- Measures (Additive)
    TransactionAmount   DECIMAL(18, 2) NOT NULL,         -- Amount of transaction
    AccountBalance      DECIMAL(18, 2) NOT NULL,         -- Account balance after transaction
    TransactionCount    INT NOT NULL DEFAULT 1,          -- Always 1 (for COUNT aggregation)
    
    -- Audit
    ETLLoadDate         DATETIME NOT NULL DEFAULT GETDATE(),
    ETLBatchID          INT NULL
);
GO

-- Create Foreign Keys
ALTER TABLE DW.Fact_Transaction
    ADD CONSTRAINT FK_Fact_Transaction_Customer 
    FOREIGN KEY (CustomerKey) REFERENCES DW.Dim_Customer(CustomerKey);

ALTER TABLE DW.Fact_Transaction
    ADD CONSTRAINT FK_Fact_Transaction_Date 
    FOREIGN KEY (DateKey) REFERENCES DW.Dim_Date(DateKey);

ALTER TABLE DW.Fact_Transaction
    ADD CONSTRAINT FK_Fact_Transaction_Location 
    FOREIGN KEY (LocationKey) REFERENCES DW.Dim_Location(LocationKey);
GO

-- Create Indexes for Performance
-- Clustered Index already on TransactionKey (PK)

CREATE NONCLUSTERED INDEX IX_Fact_Transaction_CustomerKey 
    ON DW.Fact_Transaction(CustomerKey)
    INCLUDE (DateKey, TransactionAmount);

CREATE NONCLUSTERED INDEX IX_Fact_Transaction_DateKey 
    ON DW.Fact_Transaction(DateKey)
    INCLUDE (CustomerKey, TransactionAmount);

CREATE NONCLUSTERED INDEX IX_Fact_Transaction_Customer_Date 
    ON DW.Fact_Transaction(CustomerKey, DateKey)
    INCLUDE (TransactionAmount, AccountBalance);

CREATE NONCLUSTERED INDEX IX_Fact_Transaction_TransactionID 
    ON DW.Fact_Transaction(TransactionID);
GO

-- Create Statistics (for query optimization)
CREATE STATISTICS STAT_Fact_Transaction_Amount 
    ON DW.Fact_Transaction(TransactionAmount);

CREATE STATISTICS STAT_Fact_Transaction_Balance 
    ON DW.Fact_Transaction(AccountBalance);
GO

PRINT 'Fact_Transaction created successfully!';
GO

-- Display structure
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'DW' 
    AND TABLE_NAME = 'Fact_Transaction'
ORDER BY ORDINAL_POSITION;
GO