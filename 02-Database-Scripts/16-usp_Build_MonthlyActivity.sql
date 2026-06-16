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
        IF OBJECT_ID('tempdb..##MonthlyActivity') IS NOT NULL
            DROP TABLE ##MonthlyActivity;

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

        CREATE CLUSTERED INDEX IX_MonthlyActivity
            ON ##MonthlyActivity(CustomerKey, MonthEndDate);

        PRINT 'SP1 Complete: ' + FORMAT(@RowCount, 'N0') + ' records | '
              + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR) + 's';

        SELECT @RowCount AS [RowCount];

    END TRY
    BEGIN CATCH
        DECLARE @Err1 NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err1, 16, 1);
    END CATCH
END;
GO