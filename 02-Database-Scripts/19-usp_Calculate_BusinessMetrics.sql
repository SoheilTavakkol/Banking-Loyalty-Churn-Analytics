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
        IF OBJECT_ID('tempdb..##StagedSnapshot') IS NULL
            RAISERROR('##StagedSnapshot not found. Run SP3 first.', 16, 1);

        UPDATE ss
        SET ss.SegmentKey = ds.SegmentKey
        FROM ##StagedSnapshot ss
        INNER JOIN DW.Dim_Segment ds
            ON ds.IsActive = 1
           AND ss.DaysSinceLastTransaction BETWEEN ds.RecencyMin   AND ds.RecencyMax
           AND ss.TransactionCount         BETWEEN ds.FrequencyMin AND ds.FrequencyMax
        WHERE ss.SegmentKey IS NULL;

        SET @RowCount = @@ROWCOUNT;

        PRINT 'SP4 Complete: ' + FORMAT(@RowCount, 'N0') + ' segments assigned | '
              + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR) + 's';

        SELECT @RowCount AS [RowCount];

    END TRY
    BEGIN CATCH
        DECLARE @Err4 NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err4, 16, 1);
    END CATCH
END;
GO