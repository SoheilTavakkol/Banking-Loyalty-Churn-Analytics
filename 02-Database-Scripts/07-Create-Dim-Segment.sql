USE BankingDW;
GO

IF OBJECT_ID('DW.Dim_Segment', 'U') IS NOT NULL
    DROP TABLE DW.Dim_Segment;
GO

CREATE TABLE DW.Dim_Segment
(
    SegmentKey      INT IDENTITY(1,1) PRIMARY KEY,
    SegmentCode     VARCHAR(50)    NOT NULL UNIQUE,
    SegmentName     NVARCHAR(100)  NOT NULL,
    SegmentType     VARCHAR(50)    NOT NULL,
    Description     NVARCHAR(500)  NULL,
    RecencyMin      INT            NULL,
    RecencyMax      INT            NULL,
    FrequencyMin    INT            NULL,
    FrequencyMax    INT            NULL,
    DisplayOrder    INT            NOT NULL DEFAULT 999,
    Color           VARCHAR(20)    NULL,
    IsActive        BIT            NOT NULL DEFAULT 1,
    StartDate       DATE           NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    EndDate         DATE           NULL,
    CreatedDate     DATETIME       NOT NULL DEFAULT GETDATE(),
    ModifiedDate    DATETIME       NULL
);
GO

CREATE NONCLUSTERED INDEX IX_Dim_Segment_SegmentCode ON DW.Dim_Segment(SegmentCode);
CREATE NONCLUSTERED INDEX IX_Dim_Segment_SegmentType ON DW.Dim_Segment(SegmentType);
CREATE NONCLUSTERED INDEX IX_Dim_Segment_IsActive    ON DW.Dim_Segment(IsActive) WHERE IsActive = 1;
GO

INSERT INTO DW.Dim_Segment
    (SegmentCode, SegmentName, SegmentType, Description, RecencyMin, RecencyMax, FrequencyMin, FrequencyMax, DisplayOrder, Color)
VALUES
    ('RF_Champions',   'Champions',          'RF', 'High frequency (15+), active within 60 days',          0,   59,  15, 9999, 1, '#28A745'),
    ('RF_Loyal',       'Loyal Customers',    'RF', 'Good frequency (8-14), active within 60 days',         0,   59,   8,   14, 2, '#17A2B8'),
    ('RF_Potential',   'Potential Loyalists','RF', 'Moderate frequency (5-7), active within 60 days',      0,   59,   5,    7, 3, '#6C757D'),
    ('RF_New',         'New Customers',      'RF', 'Low frequency (0-4), active within 30 days',           0,   30,   0,    4, 4, '#007BFF'),
    ('RF_AtRisk',      'At Risk',            'RF', 'Any frequency (5+), inactive 60-90 days',             60,   90,   5, 9999, 5, '#FFC107'),
    ('RF_Hibernating', 'Hibernating',        'RF', 'Low frequency (0-4), inactive 31-90 days',            31,   90,   0,    4, 6, '#FF6B6B'),
    ('RF_Churned',     'Churned',            'RF', 'Any frequency, inactive 91+ days',                    91, 9999,   0, 9999, 7, '#DC3545');
GO

SELECT
    SegmentKey, SegmentCode, SegmentName,
    RecencyMin, RecencyMax, FrequencyMin, FrequencyMax,
    DisplayOrder, Color, IsActive
FROM DW.Dim_Segment
ORDER BY DisplayOrder;
GO