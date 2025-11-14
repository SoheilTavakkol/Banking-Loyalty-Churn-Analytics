# Data Modeling Documentation

This folder contains comprehensive documentation of the dimensional data model design.

## Contents

###  [Data Model Design](Data-Model-Design.md)
Complete dimensional model documentation including:
- Star schema architecture
- Dimension and fact table specifications
- SCD Type 2 implementation details
- Business rules and calculations
- Design justifications

###  [ER Diagram](ER-Diagram.md)
Visual representations of the data model including:
- Entity relationship diagrams (Mermaid)
- Star schema visualization
- SCD Type 2 flow diagrams
- Data flow diagrams
- Query pattern examples

###  [Data Dictionary](Data-Dictionary.md)
Detailed reference guide for all tables and columns:
- Complete field specifications
- Data types and constraints
- Business rules and validations
- Code value definitions
- Calculated measure formulas

---

## Model Summary

**Schema Type:** Star Schema (Kimball Methodology)

**Dimensions:** 4 tables
- Dim_Date (5,844 rows - pre-populated)
- Dim_Customer (SCD Type 2)
- Dim_Location  
- Dim_Segment (7 RF segments)

**Facts:** 2 tables
- Fact_Transaction (Transaction-level grain)
- Fact_CustomerSnapshot (Customer-month grain)

**Key Features:**
-  SCD Type 2 for customer location tracking
-  RF-based customer segmentation
-  Synthetic data for satisfaction and complaints
-  Monthly snapshot for trend analysis


**Version:** 1.0  
**Status:** Complete  
**Next Phase:** ETL Development
