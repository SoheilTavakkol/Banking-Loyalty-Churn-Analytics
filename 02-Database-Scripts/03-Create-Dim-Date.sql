-- ===================================
-- Phase 2: Create Dim_Date
-- Complete Date/Time Dimension with Key and Name columns
-- ===================================

USE BankingDW;
GO

-- Drop table if exists (for development)
IF OBJECT_ID('DW.Dim_Date', 'U') IS NOT NULL
    DROP TABLE DW.Dim_Date;
GO

-- Create Dim_Date
CREATE TABLE DW.Dim_Date
(
    -- Primary Key
    DateKey             INT PRIMARY KEY,           -- Format: YYYYMMDD (e.g., 20250112)
    
    -- Full Date/Time
    FullDateTime        DATETIME NOT NULL,
    Date                DATE NOT NULL,
    
    -- Year Attributes
    Year                INT NOT NULL,
	YearName            VARCHAR(10) NOT NULL,      -- "2025"
        
    -- Quarter Attributes
    Quarter             INT NOT NULL,              -- 1, 2, 3, 4
    QuarterName         VARCHAR(10) NOT NULL,      -- "Q1", "Q2", "Q3", "Q4"
    YearQuarter         VARCHAR(10) NOT NULL,      -- "2025-Q1"
    
    -- Month Attributes
    Month               INT NOT NULL,              -- 1-12
    MonthName           NVARCHAR(20) NOT NULL,     -- "January", "February", ...
    MonthNameShort      NVARCHAR(10) NOT NULL,     -- "Jan", "Feb", ...
    YearMonth           VARCHAR(10) NOT NULL,      -- "2025-01"
    YearMonthName       VARCHAR(20) NOT NULL,      -- "2025 January"
    
    -- Day Attributes
    Day                 INT NOT NULL,              -- 1-31
    DayOfWeek           INT NOT NULL,              -- 1=Monday, 7=Sunday
    DayName             NVARCHAR(20) NOT NULL,     -- "Monday", ...
    DayNameShort        NVARCHAR(10) NOT NULL,     -- "Mon", ...
    DayOfYear           INT NOT NULL,              -- 1-366
    
    -- Week Attributes
    WeekOfYear          INT NOT NULL,              -- 1-53
    WeekOfMonth         INT NOT NULL,              -- 1-5
    
    -- Fiscal Attributes (assuming fiscal year starts in April)
    FiscalYear          INT NOT NULL,
    FiscalQuarter       INT NOT NULL,
    FiscalMonth         INT NOT NULL,
    
    -- Time Attributes
    Time                TIME NOT NULL,
    Hour                INT NOT NULL,              -- 0-23
    HourName            VARCHAR(10) NOT NULL,      -- "00:00", "01:00", ...
    Minute              INT NOT NULL,              -- 0-59
    TimeOfDay           VARCHAR(20) NOT NULL,      -- "Morning", "Afternoon", "Evening", "Night"
    
    -- Classification Flags
    IsWeekend           BIT NOT NULL,
    IsHoliday           BIT NOT NULL DEFAULT 0,
    IsWorkingDay        BIT NOT NULL,              -- NOT (Weekend OR Holiday)
    
    -- Relative Periods (useful for filtering)
    IsToday             BIT NOT NULL DEFAULT 0,
    IsYesterday         BIT NOT NULL DEFAULT 0,
    IsCurrentMonth      BIT NOT NULL DEFAULT 0,
    IsCurrentQuarter    BIT NOT NULL DEFAULT 0,
    IsCurrentYear       BIT NOT NULL DEFAULT 0,
    
    -- Audit
    CreatedDate         DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- Create Indexes for Performance
CREATE NONCLUSTERED INDEX IX_Dim_Date_Date ON DW.Dim_Date(Date);

CREATE NONCLUSTERED INDEX IX_Dim_Date_YearMonth ON DW.Dim_Date(Year, Month);

CREATE NONCLUSTERED INDEX IX_Dim_Date_YearQuarter ON DW.Dim_Date(Year, Quarter);

CREATE NONCLUSTERED INDEX IX_Dim_Date_IsWorkingDay ON DW.Dim_Date(IsWorkingDay) WHERE IsWorkingDay = 1;

CREATE NONCLUSTERED INDEX IX_Dim_Date_FiscalYear ON DW.Dim_Date(FiscalYear, FiscalQuarter);
GO

PRINT 'Dim_Date created successfully with all Key and Name columns!';
GO

-- Display structure
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'DW' 
    AND TABLE_NAME = 'Dim_Date'
ORDER BY ORDINAL_POSITION;
GO