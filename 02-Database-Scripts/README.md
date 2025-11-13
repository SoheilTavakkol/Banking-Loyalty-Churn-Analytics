# Database Scripts

This folder contains all SQL scripts for Phase 2: Physical Environment Setup

## Execution Order

Run scripts in the following order:

1. `01-Create-Database.sql` - Create BankingDW database
2. `02-Create-Schema.sql` - Create DW and ETL schemas
3. `03-Create-Dim-Date.sql` - Create Date dimension
4. `04-Populate-Dim-Date.sql` - Populate Date dimension (2015-2030)
5. `05-Create-Dim-Location.sql` - Create Location dimension
6. `06-Create-Dim-Customer.sql` - Create Customer dimension (SCD Type 2)
7. `07-Create-Dim-Segment.sql` - Create and populate Segment dimension
8. `08-Create-Fact-Transaction.sql` - Create Transaction fact table
9. `09-Create-Fact-CustomerSnapshot.sql` - Create CustomerSnapshot fact table
