-- =============================================
-- Script: Add LocationCode column to Stg_Customer
-- Purpose: Performance optimization for Dim_Customer load
-- Date: December 2025
-- Reason: Pre-compute LocationCode for SARGable joins
-- =============================================

USE BankingStaging;
GO

-- Add LocationCode column if not exists
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'Stg_Customer' 
      AND COLUMN_NAME = 'LocationCode'
)
BEGIN
    ALTER TABLE dbo.Stg_Customer 
    ADD LocationCode NVARCHAR(100);
    
    PRINT 'Column LocationCode added to Stg_Customer';
END
ELSE
BEGIN
    PRINT 'Column LocationCode already exists';
END
GO

-- Populate LocationCode for existing records
UPDATE dbo.Stg_Customer
SET LocationCode = UPPER(REPLACE(TRIM(Location), ' ', '_'))
WHERE Location IS NOT NULL AND Location != 'nan';
GO

PRINT 'LocationCode populated successfully';
GO

-- Verify
SELECT TOP 10 
    Location, 
    LocationCode 
FROM dbo.Stg_Customer;
GO