-- =============================================
-- Stored Procedure: usp_Load_Fact_Transaction
-- Purpose: Load Fact_Transaction with dimension lookups
-- Author: Banking DW Team
-- Date: December 2025
-- Performance: ~108 minutes for 154M records
-- =============================================

USE BankingDW;
GO

DROP PROCEDURE IF EXISTS DW.usp_Load_Fact_Transaction;
GO

CREATE PROCEDURE DW.usp_Load_Fact_Transaction
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @RowsInserted INT = 0;
    DECLARE @StartTime DATETIME = GETDATE();
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        PRINT 'Starting Fact_Transaction load...';
        
        -- Direct insert with all lookups
        INSERT INTO DW.Fact_Transaction (
            CustomerKey, DateKey, LocationKey, TransactionID,
            TransactionAmount, AccountBalance, TransactionCount,
            ETLLoadDate, ETLBatchID
        )
        SELECT 
            dc.CustomerKey,
            CAST(CONVERT(VARCHAR(8), TRY_CAST(s.TransactionDate AS DATE), 112) AS INT) AS DateKey,
            dl.LocationKey,
            s.TransactionID,
            ISNULL(TRY_CAST(s.TransactionAmount AS DECIMAL(18,2)), 0) AS TransactionAmount,
            ISNULL(TRY_CAST(s.AccountBalance AS DECIMAL(18,2)), 0) AS AccountBalance,
            1 AS TransactionCount,
            GETDATE() AS ETLLoadDate,
            NULL AS ETLBatchID
        FROM BankingStaging.dbo.Stg_Transaction s
        INNER JOIN DW.Dim_Customer dc 
            ON s.CustomerID = dc.CustomerID
            AND TRY_CAST(s.TransactionDate AS DATE) BETWEEN dc.StartDate AND ISNULL(dc.EndDate, '9999-12-31')
        INNER JOIN DW.Dim_Date dd
            ON CAST(CONVERT(VARCHAR(8), TRY_CAST(s.TransactionDate AS DATE), 112) AS INT) = dd.DateKey
        LEFT JOIN DW.Dim_Location dl
            ON UPPER(REPLACE(LTRIM(RTRIM(s.CustLocation)), ' ', '_')) = dl.LocationCode
        WHERE s.CustomerID IS NOT NULL
          AND s.TransactionDate IS NOT NULL;
        
        SET @RowsInserted = @@ROWCOUNT;
        
        COMMIT TRANSACTION;
        
        DECLARE @Minutes INT = DATEDIFF(MINUTE, @StartTime, GETDATE());
        
        PRINT 'SUCCESS: Fact_Transaction load completed';
        PRINT 'Records inserted: ' + CAST(@RowsInserted AS VARCHAR(20));
        PRINT 'Time: ' + CAST(@Minutes AS VARCHAR(20)) + ' minutes';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err, 16, 1);
    END CATCH
END;
GO

PRINT 'Stored Procedure created: DW.usp_Load_Fact_Transaction';
GO