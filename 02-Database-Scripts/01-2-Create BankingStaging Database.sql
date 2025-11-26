-- ========================================
-- 1. Create BankingStaging Database
-- ========================================
USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'BankingStaging')
BEGIN
    CREATE DATABASE BankingStaging;
    PRINT 'Database BankingStaging created successfully.';
END
ELSE
BEGIN
    PRINT 'Database BankingStaging already exists.';
END
GO

USE BankingStaging;
GO

-- ========================================
-- 2. Create Staging Tables
-- ========================================

-- Stg_Customer
IF OBJECT_ID('dbo.Stg_Customer', 'U') IS NOT NULL
    DROP TABLE dbo.Stg_Customer;

CREATE TABLE dbo.Stg_Customer (
    CustomerID NVARCHAR(50) NOT NULL,
    Location NVARCHAR(100),
    DOB NVARCHAR(50),
    Gender NVARCHAR(10),
    HasInvalidCustomerID BIT DEFAULT 0,
    HasInvalidLocation BIT DEFAULT 0,
    HasInvalidDOB BIT DEFAULT 0,
    LoadDate DATETIME DEFAULT GETDATE()
);

PRINT 'Table Stg_Customer created successfully.';
GO

-- Stg_Transaction
IF OBJECT_ID('dbo.Stg_Transaction', 'U') IS NOT NULL
    DROP TABLE dbo.Stg_Transaction;

CREATE TABLE dbo.Stg_Transaction (
    TransactionID NVARCHAR(50) NOT NULL,
    CustomerID NVARCHAR(50),
    TransactionDate NVARCHAR(50),
    TransactionAmount NVARCHAR(50),
    AccountBalance NVARCHAR(50),
    CustLocation NVARCHAR(100),
    HasInvalidCustomerID BIT DEFAULT 0,
    HasInvalidDate BIT DEFAULT 0,
    HasInvalidAmount BIT DEFAULT 0,
    LoadDate DATETIME DEFAULT GETDATE()
);

PRINT 'Table Stg_Transaction created successfully.';
GO

-- Stg_Location
IF OBJECT_ID('dbo.Stg_Location', 'U') IS NOT NULL
    DROP TABLE dbo.Stg_Location;

CREATE TABLE dbo.Stg_Location (
    Location NVARCHAR(100) NOT NULL,
    LoadDate DATETIME DEFAULT GETDATE()
);

PRINT 'Table Stg_Location created successfully.';
GO

-- ========================================
-- 3. Verify Tables Created
-- ========================================
SELECT 
    TABLE_NAME,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = t.TABLE_NAME) AS ColumnCount
FROM INFORMATION_SCHEMA.TABLES t
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;