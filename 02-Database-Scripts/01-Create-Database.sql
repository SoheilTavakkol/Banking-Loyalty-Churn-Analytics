-- ===================================
-- Phase 2: Physical Environment Setup
-- Create Main Database
-- ===================================

USE master;
GO

-- Check if database exists, drop if needed
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'BankingDW')
	BEGIN
		ALTER DATABASE BankingDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
		DROP DATABASE BankingDW;
	END
GO

-- Create Data Warehouse Database
CREATE DATABASE BankingDW
	ON PRIMARY
	(
		NAME = N'BankingDW_Data',
		FILENAME = N'L:\SQLData\Banking_DW\BankingDW_Data.mdf',
		SIZE = 500MB,
		FILEGROWTH = 100MB
	)
	LOG ON
	(
		NAME = N'BankingDW_Log',
		FILENAME = N'L:\SQLData\Banking_DW\BankingDW_Log.ldf',
		SIZE = 100MB,
		FILEGROWTH = 50MB
	);
	GO

	USE BankingDW;
	GO

PRINT 'Database BankingDW created successfully!';
GO