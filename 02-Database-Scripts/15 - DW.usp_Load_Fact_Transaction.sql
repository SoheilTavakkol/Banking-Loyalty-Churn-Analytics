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
        PRINT 'Starting Fact_Transaction load...';

        ALTER INDEX IX_Fact_Transaction_CustomerKey ON DW.Fact_Transaction DISABLE;
        ALTER INDEX IX_Fact_Transaction_DateKey ON DW.Fact_Transaction DISABLE;
        ALTER INDEX IX_Fact_Transaction_Customer_Date ON DW.Fact_Transaction DISABLE;
        ALTER INDEX IX_Fact_Transaction_TransactionID ON DW.Fact_Transaction DISABLE;

        INSERT INTO DW.Fact_Transaction WITH (TABLOCK) (
            CustomerKey, DateKey, LocationKey, TransactionID,
            TransactionAmount, AccountBalance, TransactionCount,
            ETLLoadDate, ETLBatchID
        )
        SELECT
            dc.CustomerKey,
            CAST(CONVERT(VARCHAR(8), TRY_CONVERT(date, s.TransactionDate, 103), 112) AS INT) AS DateKey,
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
            AND TRY_CONVERT(date, s.TransactionDate, 103) BETWEEN dc.StartDate AND ISNULL(dc.EndDate, '9999-12-31')
        INNER JOIN DW.Dim_Date dd
            ON CAST(CONVERT(VARCHAR(8), TRY_CONVERT(date, s.TransactionDate, 103), 112) AS INT) = dd.DateKey
        LEFT JOIN DW.Dim_Location dl
            ON UPPER(REPLACE(LTRIM(RTRIM(s.CustLocation)), ' ', '_')) = dl.LocationCode
        WHERE s.CustomerID IS NOT NULL
          AND s.TransactionDate IS NOT NULL;

        SET @RowsInserted = @@ROWCOUNT;

        PRINT 'Rebuilding Indexes...';

        ALTER INDEX IX_Fact_Transaction_CustomerKey ON DW.Fact_Transaction REBUILD;
        ALTER INDEX IX_Fact_Transaction_DateKey ON DW.Fact_Transaction REBUILD;
        ALTER INDEX IX_Fact_Transaction_Customer_Date ON DW.Fact_Transaction REBUILD;
        ALTER INDEX IX_Fact_Transaction_TransactionID ON DW.Fact_Transaction REBUILD;

        DECLARE @Minutes INT = DATEDIFF(MINUTE, @StartTime, GETDATE());

        PRINT 'SUCCESS: Fact_Transaction load completed';
        PRINT 'Records inserted: ' + CAST(@RowsInserted AS VARCHAR(20));
        PRINT 'Time: ' + CAST(@Minutes AS VARCHAR(20)) + ' minutes';

    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err, 16, 1);
    END CATCH
END;
GO