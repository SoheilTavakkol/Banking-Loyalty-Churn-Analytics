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
        IF OBJECT_ID('tempdb..##MonthlyActivity') IS NULL
            RAISERROR('##MonthlyActivity not found. Run SP1 first.', 16, 1);

        IF OBJECT_ID('tempdb..##CustomerMonthSpine') IS NOT NULL
            DROP TABLE ##CustomerMonthSpine;

        IF OBJECT_ID('tempdb..#AllMonths') IS NOT NULL DROP TABLE #AllMonths;

        SELECT DISTINCT
            EOMONTH(d.Date) AS MonthEndDate,
            MAX(d.DateKey) AS MonthEndDateKey
        INTO #AllMonths
        FROM DW.Dim_Date d
        WHERE d.Date BETWEEN '2015-01-01' AND @CutoffDate
        GROUP BY EOMONTH(d.Date);

        CREATE CLUSTERED INDEX IX_Months ON #AllMonths(MonthEndDate);

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
              (m.MonthEndDate >= cp.LastEverTxDate AND m.MonthEndDate <= DATEADD(MONTH, 12, cp.LastEverTxDate))
              OR EXISTS (
                  SELECT 1 FROM ##MonthlyActivity ma
                  WHERE ma.CustomerKey = cp.CustomerKey
                    AND ma.MonthEndDate = m.MonthEndDate
              )
          );

        SET @RowCount = @@ROWCOUNT;

        CREATE CLUSTERED INDEX IX_Spine
            ON ##CustomerMonthSpine(CustomerKey, MonthEndDate);

        PRINT 'SP2 Complete: ' + FORMAT(@RowCount, 'N0') + ' customer-months | '
              + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR) + 's';

        SELECT @RowCount AS [RowCount];

    END TRY
    BEGIN CATCH
        DECLARE @Err2 NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err2, 16, 1);
    END CATCH
END;
GO