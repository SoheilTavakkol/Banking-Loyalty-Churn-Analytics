-- ===================================
-- Phase 2: Create Schema
-- Organize DW objects in separate schema
-- ===================================

USE BankingDW;
GO

-- Create DW Schema for all DW objects
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'DW')
	BEGIN
		EXEC('CREATE SCHEMA DW');
		PRINT 'Schema DW created successfully!';
	END
ELSE
	BEGIN
		PRINT 'Schema DW already exists.';
	END
GO

-- Create ETL Schema for staging and ETL processes
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'ETL')
	BEGIN
		EXEC('CREATE SCHEMA ETL');
		PRINT 'Schema ETL created successfully!';
	END
ELSE
	BEGIN
		PRINT 'Schema ETL already exists.';
	END
GO

PRINT 'All schemas created successfully!';
GO