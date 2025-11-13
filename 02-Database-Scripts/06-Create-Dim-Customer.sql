-- ===================================
-- Phase 2: Create Dim_Customer (SCD Type 2)
-- Customer dimension with historical tracking for Location changes
-- ===================================

USE BankingDW;
GO

-- Drop table if exists
IF OBJECT_ID('DW.Dim_Customer', 'U') IS NOT NULL
    DROP TABLE DW.Dim_Customer;
GO

-- Create Dim_Customer
CREATE TABLE DW.Dim_Customer
(
    -- Surrogate Key (auto-increment for each version)
    CustomerKey         INT IDENTITY(1,1) PRIMARY KEY,
    
    -- Business Key (same for all versions of a customer)
    CustomerID          VARCHAR(50) NOT NULL,
    
    -- Demographic Attributes (Type 1 - Overwrite)
    DateOfBirth         DATE NOT NULL,
    Age                 INT NOT NULL,                    -- Calculated from DOB
    AgeGroup            VARCHAR(20) NOT NULL,            -- e.g., "18-25", "26-35", etc.
    Gender              VARCHAR(10) NOT NULL,            -- Male, Female, Unknown
    
    -- Location Attributes (Type 2 - Track History)
    Location            NVARCHAR(100) NOT NULL,          -- This is the SCD Type 2 attribute
    LocationKey         INT NULL,                        -- FK to Dim_Location (optional)
    
    -- Customer Classification
    CustomerType        VARCHAR(20) NOT NULL,            -- New, Existing
    FirstTransactionDate DATE NULL,                      -- Date of first transaction ever
    
    -- SCD Type 2 Metadata
    StartDate           DATE NOT NULL,                   -- Effective start date
    EndDate             DATE NULL,                       -- Effective end date (NULL = current)
    IsCurrent           BIT NOT NULL DEFAULT 1,          -- 1 = current record, 0 = historical
    
    -- Audit columns
    CreatedDate         DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedDate        DATETIME NULL
);
GO

-- Create indexes for performance
CREATE NONCLUSTERED INDEX IX_Dim_Customer_CustomerID ON DW.Dim_Customer(CustomerID);

CREATE NONCLUSTERED INDEX IX_Dim_Customer_CustomerID_IsCurrent ON DW.Dim_Customer(CustomerID, IsCurrent)
    WHERE IsCurrent = 1;  -- Filtered index for current records only

CREATE NONCLUSTERED INDEX IX_Dim_Customer_IsCurrent ON DW.Dim_Customer(IsCurrent) WHERE IsCurrent = 1;

CREATE NONCLUSTERED INDEX IX_Dim_Customer_AgeGroup ON DW.Dim_Customer(AgeGroup);

CREATE NONCLUSTERED INDEX IX_Dim_Customer_Gender ON DW.Dim_Customer(Gender);

CREATE NONCLUSTERED INDEX IX_Dim_Customer_StartDate_EndDate ON DW.Dim_Customer(StartDate, EndDate);
GO

-- Add foreign key to Dim_Location (optional)
ALTER TABLE DW.Dim_Customer
    ADD CONSTRAINT FK_Dim_Customer_Location 
    FOREIGN KEY (LocationKey) REFERENCES DW.Dim_Location(LocationKey);
GO

PRINT 'Dim_Customer created successfully with SCD Type 2 support!';
GO

-- Display structure
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'DW' 
    AND TABLE_NAME = 'Dim_Customer'
ORDER BY ORDINAL_POSITION;
GO