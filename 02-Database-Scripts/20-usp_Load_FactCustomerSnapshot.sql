USE BankingDW;
GO

DROP PROCEDURE IF EXISTS DW.usp_Load_FactCustomerSnapshot;
GO

CREATE PROCEDURE DW.usp_Load_FactCustomerSnapshot
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartTime    DATETIME = GETDATE();
    DECLARE @TotalInserted INT     = 0;

    BEGIN TRY
        IF OBJECT_ID('tempdb..##StagedSnapshot') IS NULL
            RAISERROR('##StagedSnapshot not found. Run SP4 first.', 16, 1);

        TRUNCATE TABLE DW.Fact_CustomerSnapshot;

        INSERT INTO DW.Fact_CustomerSnapshot WITH (TABLOCK) (
            CustomerKey, DateKey, SegmentKey,
            TransactionCount, TotalTransactionAmount, AvgTransactionAmount,
            MinTransactionAmount, MaxTransactionAmount,
            DaysSinceLastTransaction, RecencyScore, FrequencyScore, LoyaltyScore,
            SatisfactionScore, ComplaintFlag,
            ChurnFlag, AtRiskFlag, TrendCategory,
            PreviousMonthTransactionCount, GrowthRate, FinalAccountBalance,
            ETLLoadDate, ETLBatchID
        )
        SELECT
            CustomerKey, MonthEndDateKey, ISNULL(SegmentKey, -1),
            TransactionCount, TotalTransactionAmount, AvgTransactionAmount,
            MinTransactionAmount, MaxTransactionAmount,
            DaysSinceLastTransaction, RecencyScore, FrequencyScore, LoyaltyScore,
            SatisfactionScore, ComplaintFlag,
            ChurnFlag, AtRiskFlag, TrendCategory,
            PreviousMonthTransactionCount, GrowthRate, ISNULL(FinalAccountBalance, 0),
            GETDATE(), 1
        FROM ##StagedSnapshot;

        SET @TotalInserted = @@ROWCOUNT;

        PRINT 'SP5 Complete: ' + FORMAT(@TotalInserted, 'N0') + ' records | '
              + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR) + 's';

        SELECT
            RecencyScore,
            COUNT(*) AS Records,
            FORMAT(COUNT(*) * 100.0 / @TotalInserted, 'N2') + '%' AS Pct
        FROM ##StagedSnapshot
        GROUP BY RecencyScore
        ORDER BY RecencyScore DESC;

        IF OBJECT_ID('tempdb..##MonthlyActivity')    IS NOT NULL DROP TABLE ##MonthlyActivity;
        IF OBJECT_ID('tempdb..##CustomerMonthSpine') IS NOT NULL DROP TABLE ##CustomerMonthSpine;
        IF OBJECT_ID('tempdb..##StagedSnapshot')     IS NOT NULL DROP TABLE ##StagedSnapshot;

        SELECT @TotalInserted AS [RowCount];

    END TRY
    BEGIN CATCH
        DECLARE @Err5 NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err5, 16, 1);
    END CATCH
END;
GO