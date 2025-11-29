-- =============================================
-- Script: Alter Dim_Location Data Types
-- Purpose: Change VARCHAR to NVARCHAR for Unicode support
-- Date: November 2025
-- Reason: SSIS loads NVARCHAR data from staging
-- =============================================

USE BankingDW;
GO

PRINT 'Starting Dim_Location data type conversion...';
GO

-- Alter VARCHAR columns to NVARCHAR
ALTER TABLE DW.Dim_Location
ALTER COLUMN LocationCode NVARCHAR(100);

ALTER TABLE DW.Dim_Location
ALTER COLUMN LocationName NVARCHAR(100);

ALTER TABLE DW.Dim_Location
ALTER COLUMN City NVARCHAR(100);

ALTER TABLE DW.Dim_Location
ALTER COLUMN State NVARCHAR(100);

ALTER TABLE DW.Dim_Location
ALTER COLUMN Country NVARCHAR(50);

ALTER TABLE DW.Dim_Location
ALTER COLUMN Region NVARCHAR(50);

ALTER TABLE DW.Dim_Location
ALTER COLUMN LocationType NVARCHAR(50);

PRINT 'Data type conversion completed successfully.';
GO

-- Verification
PRINT 'Verifying column data types...';
GO

SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Dim_Location'
AND TABLE_SCHEMA = 'DW'
ORDER BY ORDINAL_POSITION;
GO

PRINT 'Verification complete.';