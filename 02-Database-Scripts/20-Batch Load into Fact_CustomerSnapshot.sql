-- =============================================
-- SP 5: Batch Load into Fact_CustomerSnapshot
-- Purpose: Insert staged data into final fact table
-- Input: ##StagedSnapshot (from Task 4)
-- Output: DW.Fact_CustomerSnapshot loaded
-- Expected Runtime: 15-25 minutes
-- =============================================

USE BankingDW;
GO

DROP PROCEDURE IF EXISTS DW.usp_Load_FactCustomerSnapshot;
GO

CREATE PROCEDURE DW.usp_Load_FactCustomerSnapshot
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @TotalInserted INT = 0;
    
    BEGIN TRY
        PRINT 'Task 5: Loading Fact_CustomerSnapshot...';
        
        -- Verify input
        IF OBJECT_ID('tempdb..##StagedSnapshot') IS NULL
        BEGIN
            RAISERROR('##StagedSnapshot not found. Run Task 4 first.', 16, 1);
            RETURN;
        END
        
        -- Truncate fact table
        TRUNCATE TABLE DW.Fact_CustomerSnapshot;
        PRINT 'Fact table truncated.';
        
        -- Direct insert (no batching - simple and reliable)
        INSERT INTO DW.Fact_CustomerSnapshot (
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
            CustomerKey, MonthEndDateKey, SegmentKey,
            TransactionCount, TotalTransactionAmount, AvgTransactionAmount,
            MinTransactionAmount, MaxTransactionAmount,
            DaysSinceLastTransaction, RecencyScore, FrequencyScore, LoyaltyScore,
            SatisfactionScore, ComplaintFlag,
            ChurnFlag, AtRiskFlag, TrendCategory,
            PreviousMonthTransactionCount, GrowthRate, ISNULL(FinalAccountBalance, 0),
            GETDATE(), 1
        FROM ##StagedSnapshot;
        
        SET @TotalInserted = @@ROWCOUNT;
        
        -- Cleanup
        DROP TABLE ##MonthlyActivity;
        DROP TABLE ##CustomerMonthSpine;
        DROP TABLE ##StagedSnapshot;
        
        DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, GETDATE());
        
        PRINT '';
        PRINT '===== LOAD COMPLETED =====';
        PRINT 'Total records: ' + FORMAT(@TotalInserted, 'N0');
        PRINT 'Duration: ' + CAST(@Duration AS VARCHAR(10)) + ' seconds';
        
        -- Distribution check
        SELECT 
            RecencyScore,
            COUNT(*) AS Records,
            FORMAT(COUNT(*) * 100.0 / @TotalInserted, 'N2') + '%' AS Percentage
        FROM DW.Fact_CustomerSnapshot
        GROUP BY RecencyScore
        ORDER BY RecencyScore DESC;
        
        SELECT @TotalInserted AS RowCount;
        
    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR in Task 5: ' + @Err;
        RAISERROR(@Err, 16, 1);
    END CATCH
END;
GO