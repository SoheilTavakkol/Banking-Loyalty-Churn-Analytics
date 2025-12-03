# Database Scripts

This folder contains all SQL scripts for Phase 2: Physical Environment Setup

## Execution Order

Run scripts in the following order:

01. `01-Create-Database.sql` - Create BankingDW database
02. `02-Create-Schema.sql` - Create DW and ETL schemas
03. `03-Create-Dim-Date.sql` - Create Date dimension
04. `04-Populate-Dim-Date.sql` - Populate Date dimension (2015-2030)
05. `05-Create-Dim-Location.sql` - Create Location dimension
06. `06-Create-Dim-Customer.sql` - Create Customer dimension (SCD Type 2)
07. `07-Create-Dim-Segment.sql` - Create and populate Segment dimension
08. `08-Create-Fact-Transaction.sql` - Create Transaction fact table
09. `09-Create-Fact-CustomerSnapshot.sql` - Create CustomerSnapshot fact table
10. `10-Create-Source-Database.sql` - Create operational source database for ETL testing  
11. `11-Data-Profiling.sql` - Perform data profiling on source data  
12. `12-Alter-Dim-Location-DataTypes.sql` - Apply datatype corrections to Dim_Location  
13. `13-Create-SP-Load-Dim-Customer.sql` - Create stored procedure for SCD Type 2 Customer loading  
14. `14-Add-LocationCode-To-Staging.sql` - Add LocationCode to Staging.Customer for ETL mapping  










