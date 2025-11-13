-- ===================================
-- Phase 2: Create Dim_Segment
-- Segmentation rules dimension for customer classification
-- ===================================

USE BankingDW;
GO

-- Drop table if exists
IF OBJECT_ID('DW.Dim_Segment', 'U') IS NOT NULL
    DROP TABLE DW.Dim_Segment;
GO

-- Create Dim_Segment
CREATE TABLE DW.Dim_Segment
(
    -- Primary Key
    SegmentKey          INT IDENTITY(1,1) PRIMARY KEY,
    
    -- Business Key
    SegmentCode         VARCHAR(50) NOT NULL UNIQUE,     -- e.g., "RF_Champions", "RF_AtRisk"
    
    -- Segment Attributes
    SegmentName         NVARCHAR(100) NOT NULL,          -- e.g., "Champions", "At Risk Customers"
    SegmentType         VARCHAR(50) NOT NULL,            -- e.g., "RF", "Demographic", "Behavioral"
    Description         NVARCHAR(500) NULL,              -- Description of segmentation logic
    
    -- RF Segmentation Rules (for RF type segments)
    RecencyMin          INT NULL,                        -- Minimum Recency (days)
    RecencyMax          INT NULL,                        -- Maximum Recency (days)
    FrequencyMin        INT NULL,                        -- Minimum Frequency (transaction count)
    FrequencyMax        INT NULL,                        -- Maximum Frequency (transaction count)
    
    -- Priority & Display
    DisplayOrder        INT NOT NULL DEFAULT 999,        -- Order for UI display
    Color               VARCHAR(20) NULL,                -- Hex color code for visualization (e.g., "#28A745")
    
    -- Status
    IsActive            BIT NOT NULL DEFAULT 1,          -- Active or deprecated segment
    
    -- SCD Type 2 Metadata (optional - if segmentation rules change)
    StartDate           DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    EndDate             DATE NULL,
    
    -- Audit columns
    CreatedDate         DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedDate        DATETIME NULL
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_Dim_Segment_SegmentCode 
    ON DW.Dim_Segment(SegmentCode);

CREATE NONCLUSTERED INDEX IX_Dim_Segment_SegmentType 
    ON DW.Dim_Segment(SegmentType);

CREATE NONCLUSTERED INDEX IX_Dim_Segment_IsActive 
    ON DW.Dim_Segment(IsActive)
    WHERE IsActive = 1;
GO

PRINT 'Dim_Segment created successfully!';
GO

-- Insert default RF segments
INSERT INTO DW.Dim_Segment 
(SegmentCode, SegmentName, SegmentType, Description, RecencyMin, RecencyMax, FrequencyMin, FrequencyMax, DisplayOrder, Color)
VALUES
-- Champions: High frequency, low recency
('RF_Champions', 'Champions', 'RF', 'Most valuable customers: High frequency (>15), Low recency (<30 days)', 0, 30, 15, 9999, 1, '#28A745'),

-- Loyal Customers: Good frequency, reasonable recency
('RF_Loyal', 'Loyal Customers', 'RF', 'Regular customers: Medium-high frequency (8-14), Low-medium recency (<60 days)', 0, 60, 8, 14, 2, '#17A2B8'),

-- Potential Loyalists: Recent customers with moderate frequency
('RF_Potential', 'Potential Loyalists', 'RF', 'Growing customers: Low-medium frequency (5-7), Low recency (<45 days)', 0, 45, 5, 7, 3, '#6C757D'),

-- At Risk: Previously active but declining
('RF_AtRisk', 'At Risk', 'RF', 'Declining customers: Medium frequency (5-15), Medium-high recency (60-90 days)', 60, 90, 5, 15, 4, '#FFC107'),

-- Hibernating: Low frequency, high recency
('RF_Hibernating', 'Hibernating', 'RF', 'Inactive customers: Low frequency (<5), High recency (60-90 days)', 60, 90, 0, 4, 5, '#FF6B6B'),

-- Churned: No activity for 90+ days
('RF_Churned', 'Churned', 'RF', 'Lost customers: Any frequency, Very high recency (>90 days)', 90, 9999, 0, 9999, 6, '#DC3545'),

-- New Customers: Recently joined (first 90 days)
('RF_New', 'New Customers', 'RF', 'Recently acquired customers: Any frequency, Very low recency (<30 days) with recent first transaction', 0, 30, 0, 9999, 7, '#007BFF');

PRINT CAST(@@ROWCOUNT AS VARCHAR(10)) + ' default segments inserted.';
GO

-- Verification query
SELECT 
    SegmentKey,
    SegmentCode,
    SegmentName,
    SegmentType,
    RecencyMin,
    RecencyMax,
    FrequencyMin,
    FrequencyMax,
    DisplayOrder,
    IsActive
FROM DW.Dim_Segment
ORDER BY DisplayOrder;
GO