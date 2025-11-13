-- ===================================
-- Phase 2: Populate Dim_Date
-- Generate date records from 2015 to 2030
-- ===================================

USE BankingDW;
GO

PRINT 'Starting Dim_Date population...';
GO

-- Variables for date range
DECLARE @StartDate DATE = '2015-01-01';
DECLARE @EndDate DATE = '2030-12-31';

-- Temporary table for generating dates
DECLARE @DateTable TABLE (FullDateTime DATETIME);

-- Generate all dates in range
WITH DateRange AS (
    SELECT @StartDate AS DateValue
    UNION ALL
    SELECT DATEADD(DAY, 1, DateValue)
    FROM DateRange
    WHERE DATEADD(DAY, 1, DateValue) <= @EndDate
)
INSERT INTO @DateTable (FullDateTime)
SELECT DateValue
FROM DateRange
OPTION (MAXRECURSION 0);

-- Insert into Dim_Date
INSERT INTO DW.Dim_Date
(
    DateKey,
    FullDateTime,
    Date,
    Year,
    YearName,
    Quarter,
    QuarterName,
    YearQuarter,
    Month,
    MonthName,
    MonthNameShort,
    YearMonth,
    YearMonthName,
    Day,
    DayOfWeek,
    DayName,
    DayNameShort,
    DayOfYear,
    WeekOfYear,
    WeekOfMonth,
    FiscalYear,
    FiscalQuarter,
    FiscalMonth,
    Time,
    Hour,
    HourName,
    Minute,
    TimeOfDay,
    IsWeekend,
    IsHoliday,
    IsWorkingDay,
    IsToday,
    IsYesterday,
    IsCurrentMonth,
    IsCurrentQuarter,
    IsCurrentYear
)
SELECT
    -- Primary Key: YYYYMMDD
    CAST(FORMAT(FullDateTime, 'yyyyMMdd') AS INT) AS DateKey,
    
    -- Full Date/Time
    FullDateTime,
    CAST(FullDateTime AS DATE) AS Date,
    
    -- Year
    YEAR(FullDateTime) AS Year,
    CAST(YEAR(FullDateTime) AS VARCHAR(10)) AS YearName,
    
    -- Quarter
    DATEPART(QUARTER, FullDateTime) AS Quarter,
    'Q' + CAST(DATEPART(QUARTER, FullDateTime) AS VARCHAR(1)) AS QuarterName,
    CAST(YEAR(FullDateTime) AS VARCHAR(4)) + '-Q' + CAST(DATEPART(QUARTER, FullDateTime) AS VARCHAR(1)) AS YearQuarter,
    
    -- Month
    MONTH(FullDateTime) AS Month,
    DATENAME(MONTH, FullDateTime) AS MonthName,
    LEFT(DATENAME(MONTH, FullDateTime), 3) AS MonthNameShort,
    FORMAT(FullDateTime, 'yyyy-MM') AS YearMonth,
    FORMAT(FullDateTime, 'yyyy') + ' ' + DATENAME(MONTH, FullDateTime) AS YearMonthName,
    
    -- Day
    DAY(FullDateTime) AS Day,
    
    -- Day of Week (1=Monday, 7=Sunday)
    CASE DATEPART(WEEKDAY, FullDateTime)
        WHEN 1 THEN 7  -- Sunday
        WHEN 2 THEN 1  -- Monday
        WHEN 3 THEN 2  -- Tuesday
        WHEN 4 THEN 3  -- Wednesday
        WHEN 5 THEN 4  -- Thursday
        WHEN 6 THEN 5  -- Friday
        WHEN 7 THEN 6  -- Saturday
    END AS DayOfWeek,
    
    DATENAME(WEEKDAY, FullDateTime) AS DayName,
    LEFT(DATENAME(WEEKDAY, FullDateTime), 3) AS DayNameShort,
    DATEPART(DAYOFYEAR, FullDateTime) AS DayOfYear,
    
    -- Week
    DATEPART(WEEK, FullDateTime) AS WeekOfYear,
    DATEDIFF(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, FullDateTime), 0), FullDateTime) + 1 AS WeekOfMonth,
    
    -- Fiscal Year (assuming fiscal year starts in April)
    CASE 
        WHEN MONTH(FullDateTime) >= 4 THEN YEAR(FullDateTime)
        ELSE YEAR(FullDateTime) - 1
    END AS FiscalYear,
    
    CASE 
        WHEN MONTH(FullDateTime) IN (4, 5, 6) THEN 1
        WHEN MONTH(FullDateTime) IN (7, 8, 9) THEN 2
        WHEN MONTH(FullDateTime) IN (10, 11, 12) THEN 3
        ELSE 4
    END AS FiscalQuarter,
    
    CASE 
        WHEN MONTH(FullDateTime) >= 4 THEN MONTH(FullDateTime) - 3
        ELSE MONTH(FullDateTime) + 9
    END AS FiscalMonth,
    
    -- Time (default to midnight for date-only records)
    CAST('00:00:00' AS TIME) AS Time,
    0 AS Hour,
    '00:00' AS HourName,
    0 AS Minute,
    'Night' AS TimeOfDay,
    
    -- Flags
    CASE 
        WHEN DATEPART(WEEKDAY, FullDateTime) IN (1, 7) THEN 1  -- Sunday or Saturday
        ELSE 0
    END AS IsWeekend,
    
    0 AS IsHoliday,  -- Can be updated later with actual holidays
    
    CASE 
        WHEN DATEPART(WEEKDAY, FullDateTime) NOT IN (1, 7) THEN 1
        ELSE 0
    END AS IsWorkingDay,
    
    -- Relative periods
    CASE WHEN CAST(FullDateTime AS DATE) = CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END AS IsToday,
    CASE WHEN CAST(FullDateTime AS DATE) = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE) THEN 1 ELSE 0 END AS IsYesterday,
    CASE WHEN YEAR(FullDateTime) = YEAR(GETDATE()) AND MONTH(FullDateTime) = MONTH(GETDATE()) THEN 1 ELSE 0 END AS IsCurrentMonth,
    CASE WHEN YEAR(FullDateTime) = YEAR(GETDATE()) AND DATEPART(QUARTER, FullDateTime) = DATEPART(QUARTER, GETDATE()) THEN 1 ELSE 0 END AS IsCurrentQuarter,
    CASE WHEN YEAR(FullDateTime) = YEAR(GETDATE()) THEN 1 ELSE 0 END AS IsCurrentYear

FROM @DateTable;

PRINT 'Dim_Date populated successfully!';
PRINT 'Total records: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- Verification queries
PRINT '';
PRINT 'Sample records:';
SELECT TOP 10 
    DateKey, 
    Date, 
    YearName,
    QuarterName,
    MonthName, 
    DayName,
    DayOfWeek,
    IsWeekend,
    IsWorkingDay
FROM DW.Dim_Date
ORDER BY DateKey;
GO

PRINT '';
PRINT 'Statistics:';
SELECT 
    MIN(Date) AS MinDate,
    MAX(Date) AS MaxDate,
    COUNT(*) AS TotalDays,
    SUM(CAST(IsWeekend AS INT)) AS TotalWeekends,
    SUM(CAST(IsWorkingDay AS INT)) AS TotalWorkingDays
FROM DW.Dim_Date;
GO