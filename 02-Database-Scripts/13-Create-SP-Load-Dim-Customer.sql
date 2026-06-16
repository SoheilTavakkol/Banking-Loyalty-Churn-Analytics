USE BankingDW;
GO

DROP PROCEDURE IF EXISTS DW.usp_Load_Dim_Customer;
GO

CREATE PROCEDURE DW.usp_Load_Dim_Customer
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RowsInserted INT = 0;
    DECLARE @RowsSkippedNoTxn INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ================================================================
        -- Step 1: Per (CustomerID, Location) activity window from
        -- Stg_Transaction. TRY_CONVERT style 103 = dd/mm/yyyy, independent
        -- of server DATEFORMAT/locale settings.
        -- ================================================================
        DROP TABLE IF EXISTS #LocationHistory;

        SELECT
            CustomerID,
            ISNULL(NULLIF(LTRIM(RTRIM(CustLocation)), 'nan'), 'Unspecified') AS Location,
            MIN(TRY_CONVERT(date, TransactionDate, 103)) AS LocStartDate,
            MAX(TRY_CONVERT(date, TransactionDate, 103)) AS LocEndDate
        INTO #LocationHistory
        FROM BankingStaging.dbo.Stg_Transaction
        WHERE CustomerID IS NOT NULL
        GROUP BY CustomerID, ISNULL(NULLIF(LTRIM(RTRIM(CustLocation)), 'nan'), 'Unspecified');

        CREATE CLUSTERED INDEX IX_LH ON #LocationHistory(CustomerID, Location);

        -- ================================================================
        -- Step 2: Customer-level demographics (DOB / Gender are constant
        -- across all location-versions, so MAX() just picks the value)
        -- ================================================================
        DROP TABLE IF EXISTS #CustomerDemo;

        SELECT
            CustomerID,
            MAX(ISNULL(TRY_CAST(NULLIF(DOB, 'nan') AS DATE), '1900-01-01')) AS DateOfBirth,
            MAX(CASE
                    WHEN UPPER(LTRIM(RTRIM(NULLIF(Gender, 'nan')))) IN ('M', 'MALE')   THEN 'Male'
                    WHEN UPPER(LTRIM(RTRIM(NULLIF(Gender, 'nan')))) IN ('F', 'FEMALE') THEN 'Female'
                    ELSE 'Unknown'
                END) AS Gender
        INTO #CustomerDemo
        FROM BankingStaging.dbo.Stg_Customer
        WHERE CustomerID IS NOT NULL
        GROUP BY CustomerID;

        CREATE CLUSTERED INDEX IX_CD ON #CustomerDemo(CustomerID);

        -- ================================================================
        -- Step 3: Combine, compute Age/AgeGroup/LocationKey, and flag
        -- exactly one "current" row per customer (latest LocEndDate;
        -- Location used as deterministic tie-breaker).
        -- ================================================================
        DROP TABLE IF EXISTS #FinalStaging;

        SELECT
            lh.CustomerID,
            cd.DateOfBirth,
            DATEDIFF(YEAR, cd.DateOfBirth, GETDATE())
                - CASE WHEN MONTH(cd.DateOfBirth) > MONTH(GETDATE())
                         OR (MONTH(cd.DateOfBirth) = MONTH(GETDATE())
                             AND DAY(cd.DateOfBirth) > DAY(GETDATE()))
                       THEN 1 ELSE 0 END AS Age,
            cd.Gender,
            lh.Location,
            dl.LocationKey,
            lh.LocStartDate AS StartDate,
            ROW_NUMBER() OVER (
                PARTITION BY lh.CustomerID
                ORDER BY lh.LocEndDate DESC, lh.Location ASC
            ) AS rn,
            lh.LocEndDate
        INTO #Combined
        FROM #LocationHistory lh
        INNER JOIN #CustomerDemo cd ON cd.CustomerID = lh.CustomerID
        LEFT JOIN DW.Dim_Location dl
            ON dl.LocationCode = UPPER(REPLACE(lh.Location, ' ', '_'))
        WHERE lh.LocStartDate IS NOT NULL;   -- excludes rows where every date failed to parse

        SET @RowsSkippedNoTxn = (
            SELECT COUNT(*) FROM #LocationHistory WHERE LocStartDate IS NULL
        );

        SELECT
            CustomerID,
            DateOfBirth,
            Age,
            CASE
                WHEN Age BETWEEN 18 AND 25 THEN '18-25'
                WHEN Age BETWEEN 26 AND 35 THEN '26-35'
                WHEN Age BETWEEN 36 AND 45 THEN '36-45'
                WHEN Age BETWEEN 46 AND 55 THEN '46-55'
                WHEN Age > 56              THEN '56+'
                ELSE 'Unknown'
            END AS AgeGroup,
            Gender,
            Location,
            LocationKey,
            StartDate,
            CASE WHEN rn = 1 THEN NULL ELSE LocEndDate END AS EndDate,
            CASE WHEN rn = 1 THEN 1    ELSE 0           END AS IsCurrent
        INTO #FinalStaging
        FROM #Combined;

        -- ================================================================
        -- Step 4: Full reload insert (Dim_Customer is truncated/empty
        -- before this SP runs, so no UPDATE/expire step is needed)
        -- ================================================================
        INSERT INTO DW.Dim_Customer (
            CustomerID, DateOfBirth, Age, AgeGroup, Gender, Location, LocationKey,
            CustomerType, FirstTransactionDate, StartDate, EndDate, IsCurrent, CreatedDate
        )
        SELECT
            CustomerID, DateOfBirth, Age, AgeGroup, Gender, Location, LocationKey,
            'Existing',
            StartDate,   -- FirstTransactionDate for this location-version
            StartDate,
            EndDate,
            IsCurrent,
            GETDATE()
        FROM #FinalStaging;

        SET @RowsInserted = @@ROWCOUNT;

        DROP TABLE #FinalStaging;
        DROP TABLE #Combined;
        DROP TABLE #CustomerDemo;
        DROP TABLE #LocationHistory;

        COMMIT TRANSACTION;

        PRINT 'SUCCESS: Dim_Customer load completed';
        PRINT 'Inserted          : ' + CAST(@RowsInserted AS VARCHAR(20));
        PRINT 'Skipped (no valid date) : ' + CAST(@RowsSkippedNoTxn AS VARCHAR(20));

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DROP TABLE IF EXISTS #FinalStaging;
        DROP TABLE IF EXISTS #Combined;
        DROP TABLE IF EXISTS #CustomerDemo;
        DROP TABLE IF EXISTS #LocationHistory;
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err, 16, 1);
    END CATCH
END;
GO

PRINT 'Stored Procedure rewritten: DW.usp_Load_Dim_Customer (full-reload design)';
GO