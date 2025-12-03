-- =============================================
-- Stored Procedure: usp_Load_Dim_Customer
-- Purpose: Load Dim_Customer with SCD Type 2 logic
-- Author: Banking DW Team
-- Date: December 2025
-- Performance: ~50 seconds for 884K customers
-- =============================================

USE BankingDW;
GO

DROP PROCEDURE IF EXISTS DW.usp_Load_Dim_Customer;
GO

CREATE PROCEDURE DW.usp_Load_Dim_Customer
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @RowsExpired INT = 0;
    DECLARE @RowsInserted INT = 0;
    DECLARE @RowsUpdated INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        DROP TABLE IF EXISTS #FinalStaging;

        SELECT
            s.CustomerID,
            ISNULL(TRY_CAST(NULLIF(s.DOB, 'nan') AS DATE), '1900-01-01') AS DateOfBirth,
            ISNULL(
                CASE 
                    WHEN TRY_CAST(NULLIF(s.DOB, 'nan') AS DATE) IS NULL THEN NULL
                    ELSE DATEDIFF(YEAR, TRY_CAST(NULLIF(s.DOB, 'nan') AS DATE), @CurrentDate) -
                         CASE WHEN MONTH(TRY_CAST(NULLIF(s.DOB, 'nan') AS DATE)) > MONTH(@CurrentDate) OR 
                                  (MONTH(TRY_CAST(NULLIF(s.DOB, 'nan') AS DATE)) = MONTH(@CurrentDate) AND 
                                   DAY(TRY_CAST(NULLIF(s.DOB, 'nan') AS DATE)) > DAY(@CurrentDate))
                              THEN 1 ELSE 0 END
                END
            , 0) AS Age,
            CASE 
                WHEN UPPER(LTRIM(RTRIM(NULLIF(s.Gender, 'nan')))) IN ('M', 'MALE') THEN 'Male'
                WHEN UPPER(LTRIM(RTRIM(NULLIF(s.Gender, 'nan')))) IN ('F', 'FEMALE') THEN 'Female'
                ELSE 'Unknown'
            END AS Gender,
            LTRIM(RTRIM(ISNULL(NULLIF(s.Location, 'nan'), 'Unspecified'))) AS Location,
            l.LocationKey
        INTO #FinalStaging
        FROM BankingStaging.dbo.Stg_Customer s
        LEFT JOIN DW.Dim_Location l ON s.LocationCode = l.LocationCode
        WHERE s.CustomerID IS NOT NULL;

        CREATE CLUSTERED INDEX IX_Cust ON #FinalStaging(CustomerID);

        ALTER TABLE #FinalStaging ADD AgeGroup VARCHAR(20) NOT NULL DEFAULT 'Unknown';

        UPDATE #FinalStaging
        SET AgeGroup = CASE 
                          WHEN Age BETWEEN 18 AND 25 THEN '18-25'
                          WHEN Age BETWEEN 26 AND 35 THEN '26-35'
                          WHEN Age BETWEEN 36 AND 45 THEN '36-45'
                          WHEN Age BETWEEN 46 AND 55 THEN '46-55'
                          WHEN Age > 56 THEN '56+'
                          ELSE 'Unknown'
                      END;

        UPDATE dc SET 
            EndDate = @CurrentDate, 
            IsCurrent = 0, 
            ModifiedDate = GETDATE()
        FROM DW.Dim_Customer dc
        INNER JOIN #FinalStaging s ON dc.CustomerID = s.CustomerID
        WHERE dc.IsCurrent = 1 AND dc.Location <> s.Location;

        SET @RowsExpired = @@ROWCOUNT;

        INSERT INTO DW.Dim_Customer (
            CustomerID, DateOfBirth, Age, AgeGroup, Gender, Location, LocationKey,
            CustomerType, FirstTransactionDate, StartDate, EndDate, IsCurrent, CreatedDate
        )
        SELECT 
            s.CustomerID, s.DateOfBirth, s.Age, s.AgeGroup, s.Gender, s.Location, s.LocationKey,
            'Existing', NULL, @CurrentDate, NULL, 1, GETDATE()
        FROM #FinalStaging s
        WHERE NOT EXISTS (
            SELECT 1 FROM DW.Dim_Customer dc 
            WHERE dc.CustomerID = s.CustomerID AND dc.IsCurrent = 1 AND dc.Location = s.Location
        );

        SET @RowsInserted = @@ROWCOUNT;

        UPDATE dc SET 
            Age = s.Age, 
            AgeGroup = s.AgeGroup, 
            Gender = s.Gender, 
            ModifiedDate = GETDATE()
        FROM DW.Dim_Customer dc
        INNER JOIN #FinalStaging s ON dc.CustomerID = s.CustomerID
        WHERE dc.IsCurrent = 1 AND dc.Location = s.Location;

        SET @RowsUpdated = @@ROWCOUNT;

        DROP TABLE #FinalStaging;

        COMMIT TRANSACTION;

        PRINT 'SUCCESS: Dim_Customer load completed';
        PRINT 'Expired : ' + CAST(@RowsExpired AS VARCHAR(20));
        PRINT 'Inserted: ' + CAST(@RowsInserted AS VARCHAR(20));
        PRINT 'Updated : ' + CAST(@RowsUpdated AS VARCHAR(20));

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DROP TABLE IF EXISTS #FinalStaging;
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err, 16, 1);
    END CATCH
END;
GO