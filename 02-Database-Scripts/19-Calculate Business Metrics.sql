-- =============================================
-- SP 4: Calculate Business Metrics
-- Purpose: Add derived columns (Loyalty, Growth, Satisfaction, etc.)
-- Input: ##StagedSnapshot (from Task 3)
-- Output: Updates ##StagedSnapshot in place
-- Expected Runtime: 8-12 minutes
-- =============================================

USE BankingDW;
GO

DROP PROCEDURE IF EXISTS DW.usp_Calculate_BusinessMetrics;
GO

CREATE PROCEDURE DW.usp_Calculate_BusinessMetrics
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RowCount INT;
    
    BEGIN TRY
        PRINT 'Task 4: Calculating business metrics...';
        
        -- Verify input
        IF OBJECT_ID('tempdb..##StagedSnapshot') IS NULL
        BEGIN
            RAISERROR('##StagedSnapshot not found. Run Task 3 first.', 16, 1);
            RETURN;
        END
        
        -- Step 1: Calculate previous month count for growth
        UPDATE ss
        SET ss.PreviousMonthTransactionCount = prev.TransactionCount
        FROM ##StagedSnapshot ss
        LEFT JOIN ##StagedSnapshot prev
            ON ss.CustomerKey = prev.CustomerKey
            AND prev.MonthEndDate = DATEADD(MONTH, -1, ss.MonthEndDate);
        
        -- Step 2: Calculate all derived metrics
        UPDATE ##StagedSnapshot
        SET 
            -- Loyalty Score
            LoyaltyScore = CAST((RecencyScore * 0.3) + (FrequencyScore * 0.7) AS DECIMAL(5,2)),
            
            -- Flags
            ChurnFlag = CASE WHEN DaysSinceLastTransaction > 90 THEN 1 ELSE 0 END,
            AtRiskFlag = CASE WHEN DaysSinceLastTransaction BETWEEN 60 AND 90 THEN 1 ELSE 0 END,
            
            -- Growth Rate (with overflow protection)
            GrowthRate = CASE 
                WHEN PreviousMonthTransactionCount IS NULL OR PreviousMonthTransactionCount = 0 THEN NULL
                ELSE 
                    CASE 
                        WHEN ((TransactionCount - PreviousMonthTransactionCount) * 100.0 / PreviousMonthTransactionCount) > 999.99 
                            THEN CAST(999.99 AS DECIMAL(5,2))
                        WHEN ((TransactionCount - PreviousMonthTransactionCount) * 100.0 / PreviousMonthTransactionCount) < -99.99 
                            THEN CAST(-99.99 AS DECIMAL(5,2))
                        ELSE CAST(ROUND(((TransactionCount - PreviousMonthTransactionCount) * 100.0 / PreviousMonthTransactionCount), 2) AS DECIMAL(5,2))
                    END
            END,
            
            -- Satisfaction Score (synthetic)
            SatisfactionScore = CASE 
                WHEN RecencyScore >= 4 AND FrequencyScore >= 4 THEN 
                    CAST(4.0 + (ABS(CHECKSUM(NEWID())) % 101) / 100.0 AS DECIMAL(3,2))
                WHEN RecencyScore <= 2 AND FrequencyScore <= 2 THEN 
                    CAST(1.0 + (ABS(CHECKSUM(NEWID())) % 151) / 100.0 AS DECIMAL(3,2))
                ELSE 
                    CAST(2.5 + (ABS(CHECKSUM(NEWID())) % 151) / 100.0 AS DECIMAL(3,2))
            END,
            
            -- Complaint Flag
            ComplaintFlag = CAST(CASE 
                WHEN PreviousMonthTransactionCount > 0 
                     AND ((TransactionCount - PreviousMonthTransactionCount) * 100.0 / PreviousMonthTransactionCount) < -30
                     AND (ABS(CHECKSUM(NEWID())) % 100) < 70
                THEN 1
                ELSE 0
            END AS BIT),
            
            -- Trend Category
            TrendCategory = CASE 
                WHEN DaysSinceLastTransaction > 90 THEN 'Churned'
                WHEN PreviousMonthTransactionCount IS NULL THEN 'New'
                WHEN PreviousMonthTransactionCount > 0 AND ((TransactionCount - PreviousMonthTransactionCount) * 100.0 / PreviousMonthTransactionCount) > 20 THEN 'Strong Growth'
                WHEN PreviousMonthTransactionCount > 0 AND ((TransactionCount - PreviousMonthTransactionCount) * 100.0 / PreviousMonthTransactionCount) > 5 THEN 'Moderate Growth'
                WHEN PreviousMonthTransactionCount > 0 AND ABS((TransactionCount - PreviousMonthTransactionCount) * 100.0 / PreviousMonthTransactionCount) <= 5 THEN 'Stable'
                WHEN PreviousMonthTransactionCount > 0 AND ((TransactionCount - PreviousMonthTransactionCount) * 100.0 / PreviousMonthTransactionCount) >= -20 THEN 'Moderate Decline'
                ELSE 'Sharp Decline'
            END;
        
        SET @RowCount = @@ROWCOUNT;
        
        -- Step 3: Assign segments
        UPDATE ss
        SET ss.SegmentKey = (
            SELECT TOP 1 ds.SegmentKey 
            FROM DW.Dim_Segment ds 
            WHERE ds.IsActive = 1
              AND ss.DaysSinceLastTransaction BETWEEN ds.RecencyMin AND ds.RecencyMax
              AND ss.TransactionCount BETWEEN ds.FrequencyMin AND ds.FrequencyMax
            ORDER BY ds.DisplayOrder
        )
        FROM ##StagedSnapshot ss;
        
        DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, GETDATE());
        
        PRINT 'Task 4 Complete: ' + FORMAT(@RowCount, 'N0') + ' records updated';
        PRINT 'Duration: ' + CAST(@Duration AS VARCHAR(10)) + ' seconds';
        
        SELECT @RowCount AS [RowCount];
        
    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR in Task 4: ' + @Err;
        RAISERROR(@Err, 16, 1);
    END CATCH
END;
GO