-- =============================================
-- SP 2: Build Customer-Month Spine
-- Purpose: Create dense timeline for active customers
-- Input: ##MonthlyActivity (from Task 1)
-- Output: Global temp table ##CustomerMonthSpine
-- Expected Runtime: 3-5 minutes
-- =============================================

USE BankingDW;
GO

DROP PROCEDURE IF EXISTS DW.usp_Build_CustomerSpine;
GO

CREATE PROCEDURE DW.usp_Build_CustomerSpine
    @CutoffDate DATE = '2016-08-31'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RowCount INT;
    
    BEGIN TRY
        PRINT 'Task 2: Building Customer-Month Spine...';
        
        -- Check input
        IF OBJECT_ID('tempdb..##MonthlyActivity') IS NULL
        BEGIN
            RAISERROR('##MonthlyActivity not found. Run Task 1 first.', 16, 1);
            RETURN;
        END
        
        -- Drop if exists
        IF OBJECT_ID('tempdb..##CustomerMonthSpine') IS NOT NULL 
            DROP TABLE ##CustomerMonthSpine;
        
        -- Build all-months reference
        IF OBJECT_ID('tempdb..#AllMonths') IS NOT NULL DROP TABLE #AllMonths;
        
        SELECT DISTINCT
            EOMONTH(d.Date) AS MonthEndDate,
            MAX(d.DateKey) AS MonthEndDateKey
        INTO #AllMonths
        FROM DW.Dim_Date d
        WHERE d.Date BETWEEN '2015-01-01' AND @CutoffDate
        GROUP BY EOMONTH(d.Date);
        
        CREATE CLUSTERED INDEX IX_Months ON #AllMonths(MonthEndDate);
        
        -- Get customer profiles
        IF OBJECT_ID('tempdb..#CustomerProfile') IS NOT NULL DROP TABLE #CustomerProfile;
        
        SELECT 
            c.CustomerKey,
            c.FirstTransactionDate,
            MAX(ma.LastTxDateInMonth) AS LastEverTxDate,
            DATEDIFF(DAY, MAX(ma.LastTxDateInMonth), @CutoffDate) AS DaysSinceLastTx
        INTO #CustomerProfile
        FROM DW.Dim_Customer c WITH (NOLOCK)
        INNER JOIN ##MonthlyActivity ma ON c.CustomerKey = ma.CustomerKey
        WHERE c.IsCurrent = 1
        GROUP BY c.CustomerKey, c.FirstTransactionDate;
        
        CREATE CLUSTERED INDEX IX_Profile ON #CustomerProfile(CustomerKey);
        
        -- Build smart spine: Dense for active, Sparse for churned
        SELECT 
            cp.CustomerKey,
            m.MonthEndDate,
            m.MonthEndDateKey
        INTO ##CustomerMonthSpine
        FROM #CustomerProfile cp
        CROSS JOIN #AllMonths m
        WHERE m.MonthEndDate >= cp.FirstTransactionDate
          AND m.MonthEndDate <= @CutoffDate
          AND (
              -- Dense: Last 12 months for all customers
              DATEDIFF(MONTH, cp.LastEverTxDate, m.MonthEndDate) BETWEEN 0 AND 12
              OR
              -- Sparse: Only months with transactions if older
              EXISTS (
                  SELECT 1 FROM ##MonthlyActivity ma
                  WHERE ma.CustomerKey = cp.CustomerKey
                    AND ma.MonthEndDate = m.MonthEndDate
              )
          );
        
        SET @RowCount = @@ROWCOUNT;
        
        -- Create index
        CREATE CLUSTERED INDEX IX_Spine 
            ON ##CustomerMonthSpine(CustomerKey, MonthEndDate);
        
        DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, GETDATE());
        
        PRINT 'Task 2 Complete: ' + FORMAT(@RowCount, 'N0') + ' customer-months';
        PRINT 'Duration: ' + CAST(@Duration AS VARCHAR(10)) + ' seconds';
        
        SELECT @RowCount AS [RowCount];
        
    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR in Task 2: ' + @Err;
        RAISERROR(@Err, 16, 1);
    END CATCH
END;
GO