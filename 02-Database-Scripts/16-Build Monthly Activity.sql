-- =============================================
-- SP 1: Build Monthly Activity
-- Purpose: Aggregate all transactions to monthly level
-- Output: Global temp table ##MonthlyActivity
-- Expected Runtime: 8-12 minutes for 154M records
-- =============================================

USE BankingDW;
GO

DROP PROCEDURE IF EXISTS DW.usp_Build_MonthlyActivity;
GO

CREATE PROCEDURE DW.usp_Build_MonthlyActivity
    @CutoffDate DATE = '2016-08-31'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RowCount INT;
    
    BEGIN TRY
        PRINT 'Task 1: Building Monthly Activity...';
        PRINT 'Cutoff Date: ' + CAST(@CutoffDate AS VARCHAR(10));
        
        -- Drop if exists
        IF OBJECT_ID('tempdb..##MonthlyActivity') IS NOT NULL 
            DROP TABLE ##MonthlyActivity;
        
        -- Build sparse monthly aggregates
        SELECT
            ft.CustomerKey,
            EOMONTH(dd.Date) AS MonthEndDate,
            YEAR(dd.Date) AS TxYear,
            MONTH(dd.Date) AS TxMonth,
            COUNT(*) AS TransactionCount,
            CAST(SUM(ft.TransactionAmount) AS DECIMAL(18,2)) AS TotalTransactionAmount,
            CAST(AVG(ft.TransactionAmount) AS DECIMAL(18,2)) AS AvgTransactionAmount,
            CAST(MIN(ft.TransactionAmount) AS DECIMAL(18,2)) AS MinTransactionAmount,
            CAST(MAX(ft.TransactionAmount) AS DECIMAL(18,2)) AS MaxTransactionAmount,
            MAX(dd.Date) AS LastTxDateInMonth,
            MAX(ft.AccountBalance) AS MonthEndBalance
        INTO ##MonthlyActivity
        FROM DW.Fact_Transaction ft WITH (NOLOCK)
        INNER JOIN DW.Dim_Date dd WITH (NOLOCK) ON ft.DateKey = dd.DateKey
        WHERE dd.Date <= @CutoffDate
        GROUP BY ft.CustomerKey, EOMONTH(dd.Date), YEAR(dd.Date), MONTH(dd.Date);
        
        SET @RowCount = @@ROWCOUNT;
        
        -- Create index for next tasks
        CREATE CLUSTERED INDEX IX_MonthlyActivity 
            ON ##MonthlyActivity(CustomerKey, MonthEndDate);
        
        DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, GETDATE());
        
        PRINT 'Task 1 Complete: ' + FORMAT(@RowCount, 'N0') + ' records';
        PRINT 'Duration: ' + CAST(@Duration AS VARCHAR(10)) + ' seconds';
        
        -- Return row count for SSIS logging
        SELECT @RowCount AS [RowCount];
        
    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR in Task 1: ' + @Err;
        RAISERROR(@Err, 16, 1);
    END CATCH
END;
GO