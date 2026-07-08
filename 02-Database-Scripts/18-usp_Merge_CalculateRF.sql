USE BankingDW;
GO

DROP PROCEDURE IF EXISTS DW.usp_Merge_CalculateRF;
GO

CREATE PROCEDURE DW.usp_Merge_CalculateRF
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RowCount INT;

    BEGIN TRY
        IF OBJECT_ID('tempdb..##CustomerMonthSpine') IS NULL
            RAISERROR('##CustomerMonthSpine not found. Run SP2 first.', 16, 1);
        IF OBJECT_ID('tempdb..##MonthlyActivity') IS NULL
            RAISERROR('##MonthlyActivity not found. Run SP1 first.', 16, 1);

        IF OBJECT_ID('tempdb..##StagedSnapshot') IS NOT NULL
            DROP TABLE ##StagedSnapshot;

        ;WITH MergedData AS (
            SELECT
                spine.CustomerKey,
                spine.MonthEndDate,
                spine.MonthEndDateKey,
                ISNULL(act.TransactionCount, 0) AS TransactionCount,
                ISNULL(act.TotalTransactionAmount, 0) AS TotalTransactionAmount,
                ISNULL(act.AvgTransactionAmount, 0) AS AvgTransactionAmount,
                ISNULL(act.MinTransactionAmount, 0) AS MinTransactionAmount,
                ISNULL(act.MaxTransactionAmount, 0) AS MaxTransactionAmount,
                act.LastTxDateInMonth,
                act.MonthEndBalance,
                ISNULL(prevAct.TransactionCount, 0) AS PreviousMonthTransactionCount,
                CASE WHEN prevAct.CustomerKey IS NULL THEN 1 ELSE 0 END AS IsFirstMonth
            FROM ##CustomerMonthSpine spine
            LEFT JOIN ##MonthlyActivity act
                ON spine.CustomerKey  = act.CustomerKey
               AND spine.MonthEndDate = act.MonthEndDate
            LEFT JOIN ##MonthlyActivity prevAct
                ON spine.CustomerKey = prevAct.CustomerKey
               AND prevAct.MonthEndDate = EOMONTH(DATEADD(MONTH, -1, spine.MonthEndDate))
        ),
        WithRunningMetrics AS (
            SELECT
                md.CustomerKey,
                md.MonthEndDate,
                md.MonthEndDateKey,
                md.TransactionCount,
                md.TotalTransactionAmount,
                md.AvgTransactionAmount,
                md.MinTransactionAmount,
                md.MaxTransactionAmount,
                md.PreviousMonthTransactionCount,
                md.IsFirstMonth,
                MAX(md.LastTxDateInMonth) OVER (
                    PARTITION BY md.CustomerKey
                    ORDER BY md.MonthEndDate
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ) AS RunningLastTxDate,
                COALESCE(
                    md.MonthEndBalance,
                    MAX(md.MonthEndBalance) OVER (
                        PARTITION BY md.CustomerKey
                        ORDER BY md.MonthEndDate
                        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                    )
                ) AS FinalAccountBalance
            FROM MergedData md
        ),
        ComputedMetrics AS (
            SELECT
                wrm.*,
                DATEDIFF(DAY, wrm.RunningLastTxDate, wrm.MonthEndDate) AS DaysSinceLastTransaction,
                CASE
                    WHEN DATEDIFF(DAY, wrm.RunningLastTxDate, wrm.MonthEndDate) <= 30  THEN 5
                    WHEN DATEDIFF(DAY, wrm.RunningLastTxDate, wrm.MonthEndDate) <= 60  THEN 4
                    WHEN DATEDIFF(DAY, wrm.RunningLastTxDate, wrm.MonthEndDate) <= 90  THEN 3
                    WHEN DATEDIFF(DAY, wrm.RunningLastTxDate, wrm.MonthEndDate) <= 180 THEN 2
                    ELSE 1
                END AS RecencyScore,
                CASE
                    WHEN wrm.TransactionCount >= 15 THEN 5
                    WHEN wrm.TransactionCount >= 10 THEN 4
                    WHEN wrm.TransactionCount >= 5  THEN 3
                    WHEN wrm.TransactionCount >= 2  THEN 2
                    WHEN wrm.TransactionCount >= 1  THEN 1
                    ELSE 0
                END AS FrequencyScore
            FROM WithRunningMetrics wrm
        )
        SELECT
            cm.CustomerKey,
            cm.MonthEndDate,
            cm.MonthEndDateKey,
            cm.TransactionCount,
            cm.TotalTransactionAmount,
            cm.AvgTransactionAmount,
            cm.MinTransactionAmount,
            cm.MaxTransactionAmount,
            cm.FinalAccountBalance,
            cm.DaysSinceLastTransaction,
            cm.RecencyScore,
            cm.FrequencyScore,
            CAST((cm.RecencyScore * 0.3) + (cm.FrequencyScore * 0.7) AS DECIMAL(5,2)) AS LoyaltyScore,
            CASE WHEN cm.DaysSinceLastTransaction > 90  THEN 1 ELSE 0 END AS ChurnFlag,
            CASE WHEN cm.DaysSinceLastTransaction BETWEEN 60 AND 90 THEN 1 ELSE 0 END AS AtRiskFlag,
            cm.PreviousMonthTransactionCount,
            cm.IsFirstMonth,
            CASE
                WHEN cm.PreviousMonthTransactionCount = 0 THEN NULL
                ELSE CASE
                    WHEN ((cm.TransactionCount - cm.PreviousMonthTransactionCount) * 100.0 / cm.PreviousMonthTransactionCount) >  999.99 THEN CAST( 999.99 AS DECIMAL(5,2))
                    WHEN ((cm.TransactionCount - cm.PreviousMonthTransactionCount) * 100.0 / cm.PreviousMonthTransactionCount) < -99.99  THEN CAST(-99.99  AS DECIMAL(5,2))
                    ELSE CAST(ROUND((cm.TransactionCount - cm.PreviousMonthTransactionCount) * 100.0 / cm.PreviousMonthTransactionCount, 2) AS DECIMAL(5,2))
                END
            END AS GrowthRate,
            CASE
                WHEN cm.RecencyScore >= 4 AND cm.FrequencyScore >= 4 THEN CAST(4.0 + (ABS(CHECKSUM(NEWID())) % 101) / 100.0 AS DECIMAL(3,2))
                WHEN cm.RecencyScore <= 2 AND cm.FrequencyScore <= 2 THEN CAST(1.0 + (ABS(CHECKSUM(NEWID())) % 151) / 100.0 AS DECIMAL(3,2))
                ELSE CAST(2.5 + (ABS(CHECKSUM(NEWID())) % 151) / 100.0 AS DECIMAL(3,2))
            END AS SatisfactionScore,
            CAST(CASE
                WHEN cm.PreviousMonthTransactionCount > 0
                     AND ((cm.TransactionCount - cm.PreviousMonthTransactionCount) * 100.0 / cm.PreviousMonthTransactionCount) < -30
                     AND (ABS(CHECKSUM(NEWID())) % 100) < 70 THEN 1
                ELSE 0
            END AS BIT) AS ComplaintFlag,
            CASE
                WHEN cm.DaysSinceLastTransaction > 90 THEN 'Churned'
                WHEN cm.PreviousMonthTransactionCount = 0 THEN 'New'
                WHEN ((cm.TransactionCount - cm.PreviousMonthTransactionCount) * 100.0 / cm.PreviousMonthTransactionCount) > 20  THEN 'Strong Growth'
                WHEN ((cm.TransactionCount - cm.PreviousMonthTransactionCount) * 100.0 / cm.PreviousMonthTransactionCount) > 5   THEN 'Moderate Growth'
                WHEN ABS((cm.TransactionCount - cm.PreviousMonthTransactionCount) * 100.0 / cm.PreviousMonthTransactionCount) <= 5 THEN 'Stable'
                WHEN ((cm.TransactionCount - cm.PreviousMonthTransactionCount) * 100.0 / cm.PreviousMonthTransactionCount) >= -20 THEN 'Moderate Decline'
                ELSE 'Sharp Decline'
            END AS TrendCategory,
            CAST(NULL AS INT) AS SegmentKey
        INTO ##StagedSnapshot
        FROM ComputedMetrics cm;

        SET @RowCount = @@ROWCOUNT;

        CREATE CLUSTERED INDEX IX_Staged
            ON ##StagedSnapshot(CustomerKey, MonthEndDate);

        PRINT 'SP3 Complete: ' + FORMAT(@RowCount, 'N0') + ' records staged | '
              + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR) + 's';

        SELECT @RowCount AS [RowCount];

    END TRY
    BEGIN CATCH
        DECLARE @Err3 NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err3, 16, 1);
    END CATCH
END;
GO