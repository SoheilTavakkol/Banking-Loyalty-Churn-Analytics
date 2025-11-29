-- ===================================
-- Phase 3: Create Source Database
-- OLTP Staging for CSV Import
-- ===================================

USE master;
GO

-- Drop if exists
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'BankingSource')
BEGIN
    ALTER DATABASE BankingSource SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BankingSource;
END
GO

-- Create Source Database
CREATE DATABASE BankingSource
ON PRIMARY
(
    NAME = N'BankingSource_Data',
    FILENAME = N'L:\SQLData\Banking_DW\BankingSource_Data.mdf',
    SIZE = 500MB,
    FILEGROWTH = 100MB
)
LOG ON
(
    NAME = N'BankingSource_Log',
    FILENAME = N'L:\SQLData\Banking_DW\BankingSource_Log.ldf',
    SIZE = 100MB,
    FILEGROWTH = 50MB
);
GO

USE BankingSource;
GO

-- Create Raw Transactions Table (exact match to CSV)
CREATE TABLE dbo.RawTransactions
(
    TransactionID       VARCHAR(50) NULL,
    CustomerID          VARCHAR(50) NULL,
    CustomerDOB         VARCHAR(50) NULL,        -- Keep as VARCHAR for mixed formats
    CustGender          VARCHAR(10) NULL,
    CustLocation        NVARCHAR(200) NULL,
    CustAccountBalance  VARCHAR(50) NULL,        -- Keep as VARCHAR (has NULLs)
    TransactionDate     VARCHAR(50) NULL,        -- Keep as VARCHAR initially
    TransactionTime     VARCHAR(50) NULL,
    TransactionAmount   VARCHAR(50) NULL
);
GO

PRINT 'BankingSource database and RawTransactions table created successfully!';
GO