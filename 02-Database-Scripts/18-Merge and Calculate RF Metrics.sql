-- =============================================
-- SP 3: Merge and Calculate RF Metrics
-- Purpose: Join spine with activity, calculate Recency/Frequency
-- Input: ##CustomerMonthSpine, ##MonthlyActivity
-- Output: Global temp table ##StagedSnapshot
-- Expected Runtime: 10-15 minutes
-- =============================================

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
        PRINT 'Task 3: Merging and calculating RF metrics...';
        
        -- Verify inputs
        IF OBJECT_ID('tempdb..##CustomerMonthSpine') IS NULL
        BEGIN
            RAISERROR('##CustomerMonthSpine not found. Run Task 2 first.', 16, 1);
            RETURN;
        END
        
        IF OBJECT_ID('tempdb..##MonthlyActivity') IS NULL
        BEGIN
            RAISERROR('##MonthlyActivity not found. Run Task 1 first.', 16, 1);
            RETURN;
        END
        
        -- Drop if exists
        IF OBJECT_ID('tempdb..##StagedSnapshot') IS NOT NULL 
            DROP TABLE ##StagedSnapshot;
        
        -- Merge and calculate in one step
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
                act.MonthEndBalance
            FROM ##CustomerMonthSpine spine
            LEFT JOIN ##MonthlyActivity act 
                ON spine.CustomerKey = act.CustomerKey 
                AND spine.MonthEndDate = act.MonthEndDate
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
                -- Carry forward last transaction date
                MAX(md.LastTxDateInMonth) OVER (
                    PARTITION BY md.CustomerKey 
                    ORDER BY md.MonthEndDate
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ) AS RunningLastTxDate,
                -- Carry forward balance
                COALESCE(
                    md.MonthEndBalance,
                    MAX(md.MonthEndBalance) OVER (
                        PARTITION BY md.CustomerKey 
                        ORDER BY md.MonthEndDate
                        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                    )
                ) AS FinalAccountBalance
            FROM MergedData md
        )
        SELECT 
            wrm.CustomerKey,
            wrm.MonthEndDate,
            wrm.MonthEndDateKey,
            wrm.TransactionCount,
            wrm.TotalTransactionAmount,
            wrm.AvgTransactionAmount,
            wrm.MinTransactionAmount,
            wrm.MaxTransactionAmount,
            wrm.FinalAccountBalance,
            -- Calculate Recency
            DATEDIFF(DAY, wrm.RunningLastTxDate, wrm.MonthEndDate) AS DaysSinceLastTransaction,
            -- RecencyScore (1-5)
            CASE 
                WHEN DATEDIFF(DAY, wrm.RunningLastTxDate, wrm.MonthEndDate) <= 30 THEN 5
                WHEN DATEDIFF(DAY, wrm.RunningLastTxDate, wrm.MonthEndDate) <= 60 THEN 4
                WHEN DATEDIFF(DAY, wrm.RunningLastTxDate, wrm.MonthEndDate) <= 90 THEN 3
                WHEN DATEDIFF(DAY, wrm.RunningLastTxDate, wrm.MonthEndDate) <= 180 THEN 2
                ELSE 1
            END AS RecencyScore,
            -- FrequencyScore (0-5)
            CASE 
                WHEN wrm.TransactionCount >= 15 THEN 5
                WHEN wrm.TransactionCount >= 10 THEN 4
                WHEN wrm.TransactionCount >= 5 THEN 3
                WHEN wrm.TransactionCount >= 2 THEN 2
                WHEN wrm.TransactionCount >= 1 THEN 1
                ELSE 0
            END AS FrequencyScore,
            -- Placeholder columns for Task 4
            CAST(NULL AS DECIMAL(5,2)) AS LoyaltyScore,
            CAST(NULL AS BIT) AS ChurnFlag,
            CAST(NULL AS BIT) AS AtRiskFlag,
            CAST(NULL AS INT) AS PreviousMonthTransactionCount,
            CAST(NULL AS DECIMAL(5,2)) AS GrowthRate,
            CAST(NULL AS DECIMAL(3,2)) AS SatisfactionScore,
            CAST(NULL AS BIT) AS ComplaintFlag,
            CAST(NULL AS VARCHAR(20)) AS TrendCategory,
            CAST(NULL AS INT) AS SegmentKey
        INTO ##StagedSnapshot
        FROM WithRunningMetrics wrm;
        
        SET @RowCount = @@ROWCOUNT;
        
        -- Create index for Task 4
        CREATE CLUSTERED INDEX IX_Staged 
            ON ##StagedSnapshot(CustomerKey, MonthEndDate);
        
        DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, GETDATE());
        
        PRINT 'Task 3 Complete: ' + FORMAT(@RowCount, 'N0') + ' records staged';
        PRINT 'Duration: ' + CAST(@Duration AS VARCHAR(10)) + ' seconds';
        
        SELECT @RowCount AS [RowCount];
        
    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR in Task 3: ' + @Err;
        RAISERROR(@Err, 16, 1);
    END CATCH
END;
GO