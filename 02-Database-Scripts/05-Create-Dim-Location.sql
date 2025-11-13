-- ===================================
-- Phase 2: Create Dim_Location
-- Geographic dimension for customer locations
-- ===================================

USE BankingDW;
GO

-- Drop table if exists
IF OBJECT_ID('DW.Dim_Location', 'U') IS NOT NULL
    DROP TABLE DW.Dim_Location;
GO

-- Create Dim_Location
CREATE TABLE DW.Dim_Location
(
    -- Primary Key
    LocationKey         INT IDENTITY(1,1) PRIMARY KEY,
    
    -- Business Key
    LocationCode        VARCHAR(50) NOT NULL UNIQUE,     -- e.g., "MUMBAI", "DELHI"
    
    -- Location Attributes
    LocationName        NVARCHAR(100) NOT NULL,          -- Full location name
    City                NVARCHAR(50) NULL,
    State               NVARCHAR(50) NULL,
    Country             NVARCHAR(50) NOT NULL DEFAULT 'India',
    Region              NVARCHAR(50) NULL,               -- e.g., "West", "North", "South"
    
    -- Geographic Coordinates (optional - for future mapping)
    Latitude            DECIMAL(10, 7) NULL,
    Longitude           DECIMAL(10, 7) NULL,
    
    -- Classification
    LocationType        VARCHAR(20) NULL,                -- e.g., "Urban", "Rural", "Metro"
    
    -- Audit columns
    CreatedDate         DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedDate        DATETIME NULL
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_Dim_Location_LocationCode ON DW.Dim_Location(LocationCode);

CREATE NONCLUSTERED INDEX IX_Dim_Location_City ON DW.Dim_Location(City);

CREATE NONCLUSTERED INDEX IX_Dim_Location_State ON DW.Dim_Location(State);
GO

PRINT 'Dim_Location created successfully!';
GO

-- Display structure
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'DW' 
    AND TABLE_NAME = 'Dim_Location'
ORDER BY ORDINAL_POSITION;
GO