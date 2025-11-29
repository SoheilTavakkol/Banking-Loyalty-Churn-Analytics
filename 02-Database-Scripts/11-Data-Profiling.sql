USE BankingSource;
GO

PRINT '===================================';
PRINT 'Data Profiling Report';
PRINT '===================================';
PRINT '';

-- Total Rows
PRINT '1. Total Rows:';
SELECT COUNT(*) AS TotalRows FROM dbo.RawTransactions;
PRINT '';

-- Check NULLs
PRINT '2. NULL Values Check:';
SELECT 
    SUM(CASE WHEN TransactionID IS NULL OR TransactionID = 'nan' THEN 1 ELSE 0 END) AS TransactionID_Nulls,
    SUM(CASE WHEN CustomerID IS NULL OR CustomerID = 'nan' THEN 1 ELSE 0 END) AS CustomerID_Nulls,
    SUM(CASE WHEN CustomerDOB IS NULL OR CustomerDOB = 'nan' THEN 1 ELSE 0 END) AS CustomerDOB_Nulls,
    SUM(CASE WHEN CustGender IS NULL OR CustGender = 'nan' THEN 1 ELSE 0 END) AS Gender_Nulls,
    SUM(CASE WHEN CustLocation IS NULL OR CustLocation = 'nan' THEN 1 ELSE 0 END) AS Location_Nulls,
    SUM(CASE WHEN CustAccountBalance IS NULL OR CustAccountBalance = 'nan' THEN 1 ELSE 0 END) AS Balance_Nulls,
    SUM(CASE WHEN TransactionDate IS NULL OR TransactionDate = 'nan' THEN 1 ELSE 0 END) AS Date_Nulls,
    SUM(CASE WHEN TransactionAmount IS NULL OR TransactionAmount = 'nan' THEN 1 ELSE 0 END) AS Amount_Nulls
FROM dbo.RawTransactions;
PRINT '';

-- Sample Data
PRINT '3. Sample Records:';
SELECT TOP 10 * FROM dbo.RawTransactions;
PRINT '';

-- Distinct Customers
PRINT '4. Unique Customers:';
SELECT COUNT(DISTINCT CustomerID) AS UniqueCustomers FROM dbo.RawTransactions;
PRINT '';

-- Date Range
PRINT '5. Transaction Date Range:';
SELECT 
    MIN(TransactionDate) AS MinDate,
    MAX(TransactionDate) AS MaxDate
FROM dbo.RawTransactions;
PRINT '';

PRINT 'Profiling Complete!';
GO