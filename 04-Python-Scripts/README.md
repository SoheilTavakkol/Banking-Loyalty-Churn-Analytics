# Python Scripts

## Overview

This folder contains Python scripts for data preparation and augmentation.

---

## Scripts

### 1. `import_to_sql.py`

Initial data import script that loads the original CSV file (18 days of transactions) into SQL Server.

**Status:** ✅ Completed

---

### 2. `generate_transactions_v3_3.py`

**BI-Aligned Data Augmentation Script (v3.3 – DW-Aligned Edition)**

Extends the limited ~55-day transaction dataset (`bank_transactions.csv`) to a full 20-month period (Jan 2015 – Aug 2016), producing realistic time-series data calibrated to the KPIs computed in `Fact_CustomerSnapshot` (Recency, Frequency, Churn, AtRisk, GrowthRate, Loyalty).

#### What it does:

* Reads the original transactions from `bank_transactions.csv`
* Builds one behavioral profile per customer (avg amount, starting balance, DOB, gender, location)
* Assigns each customer one of 5 personality types and simulates 20 months of activity
* Generates 11 distinct transaction types (Salary, POS, ATM, EMI, Transfers, Bills, Fees, Deposits, Refunds, Interest) with realistic IN/OUT direction
* Maintains a running account balance that grows or shrinks based on income vs. spending
* Writes the full augmented dataset to `BankingSource.dbo.RawTransactions`

**Customer personality types:**

| Segment | Share | Monthly Frequency | Behaviour |
|---|---|---|---|
| Champions | 20% | 15–25 transactions | Consistent activity, +1.5% amount growth/month |
| Loyal | 25% | 8–14 transactions | Stable patterns, rare zero-months (5%) |
| At-Risk | 20% | Declining (−9%/month) | 25% chance of zero-transaction month |
| Churned | 20% | Stops permanently in month 8–15 | 60% chance of zero-month before hard stop |
| New Customers | 15% | 3–8 transactions | Campaign-based acquisition (Mar-15, Aug-15, Jan-16) |

#### Key Features:

* **Bidirectional Balance:** Salary credits (IN) and spending withdrawals (OUT) move the balance realistically in both directions — no monotonic growth
* **Indian Seasonal Patterns:** Diwali peak in October (+22%), Holi/FY-end surge in March (+18%), trough in February (−15%)
* **Dormancy Periods:** 12% of customers go completely silent for 2–6 months at a random point — drives `AtRiskFlag` and `ChurnFlag` in the DW
* **Zero-Transaction Months:** Personality-specific probability (3% Champions → 60% Churned) so `DaysSinceLastTransaction` grows naturally
* **Campaign-Based Acquisition:** New customers arrive in three waves (Mar-2015, Aug-2015, Jan-2016) for realistic cohort analysis
* **Shock Events:** 2% of high-value transaction types (POS, ATM, Transfers, Cash Deposit) are 10–50× the normal amount — prevents artificially clean charts
* **Location Migration:** 2% monthly probability of city change per customer — feeds SCD Type 2 in `Dim_Customer`
* **Monthly Volatility:** Frequency noise of ±50–160% — produces meaningful `GrowthRate` month-over-month
* **Progress Tracking:** Real-time progress bars per customer batch (50,000 customers per cycle)

#### Technical Details:

* **Input:** `bank_transactions.csv` (~1.05M records, ~55 days)
* **Output:** `BankingSource.dbo.RawTransactions` (~147M records, 20 months)
* **Customers:** 884,265 unique
* **Locations:** ~9,300 distinct (after migration)
* **Batch Size:** 50,000 customers per generation cycle, 10,000 rows per SQL write
* **Memory:** Memory-optimized — each batch is flushed and garbage-collected before the next begins

#### Important Notes:

* This script **truncates** `RawTransactions` before generating new data
* Set `DATA_SOURCE = "csv"` and `CSV_PATH` to point at your source file before running
* Output column is `TransactionAmount` (matches `BankingSource.dbo.RawTransactions` schema — `VARCHAR`, INR values, no currency suffix)
* Customer **segment labels are NOT written** — the script only controls *behavioral patterns* (frequency, amounts, dormancy). Actual RF segments (Champions, Loyal, At-Risk, Churned, etc.) are computed later by `Fact_CustomerSnapshot` from real transaction history
* Can be re-run to regenerate with different random patterns (re-truncates the table each time)

---

## Dependencies

Install required packages:

```
pip install -r requirements.txt
```

**Required Packages:**

* `pyodbc` — SQL Server connectivity
* `pandas` — Data manipulation
* `numpy` — Numerical operations and sampling
* `python-dateutil` — Date calculations
* `tqdm` — Progress bars

---

## Execution Order

1. **Initial Import** (one-time):
   ```
   python import_to_sql.py
   ```

2. **Data Augmentation** (run when ready for ETL):
   ```
   python generate_transactions_v3_3.py
   ```

3. **Proceed to ETL** (SSIS packages in `/05-SSIS-Packages/`)

---

## Configuration

`generate_transactions_v3_3.py` uses these settings (top of file):

| Setting | Default | Description |
|---|---|---|
| `DATA_SOURCE` | `"csv"` | `"csv"` reads from `CSV_PATH`, `"sql"` reads from `RawTransactions` |
| `CSV_PATH` | `"bank_transactions.csv"` | Path to the seed dataset |
| `SQL_SERVER` | `"localhost"` | SQL Server instance |
| `SQL_DATABASE` | `"BankingSource"` | Target database |
| `SQL_TABLE` | `"RawTransactions"` | Target table |
| `AUG_START` / `AUG_END` | `2015-01-01` / `2016-08-31` | Augmentation window (20 months) |

**Authentication:** Windows Authentication (`Trusted_Connection`)

To modify connection settings, edit the `get_sql_connection()` function in the script.

---

## Troubleshooting

**Issue:** `pyodbc.Error: ('01000', "[01000] [Microsoft]...")`
* **Solution:** Ignore this warning, it's informational only

**Issue:** `ModuleNotFoundError: No module named 'tqdm'` (or `dateutil`)
* **Solution:** `pip install tqdm python-dateutil --break-system-packages` (or use a virtual environment)

**Issue:** `Memory Error`
* **Solution:** The script already batches by 50,000 customers — reduce `CUSTOMER_BATCH_SIZE` further if needed

**Issue:** `Connection timeout`
* **Solution:** Increase timeout in the connection string inside `get_sql_connection()`

**Issue:** Script runs slowly
* **Solution:** Expected for ~147M output rows. Each batch prints progress and a running total

---

## Output Verification

After running `generate_transactions_v3_3.py`, verify the output in SSMS:

```sql
USE BankingSource;
GO

-- 1. Overall volume & date range
SELECT
    COUNT(*)                                     AS TotalRows,
    COUNT(DISTINCT CustomerID)                   AS UniqueCustomers,
    COUNT(DISTINCT CustLocation)                 AS UniqueLocations,
    MIN(TRY_CONVERT(date, TransactionDate, 103)) AS MinDate,
    MAX(TRY_CONVERT(date, TransactionDate, 103)) AS MaxDate
FROM dbo.RawTransactions;

-- Expected:
--   TotalRows         ~ 147,000,000
--   UniqueCustomers   = 884,265
--   UniqueLocations   ~ 9,300 (slightly above original 9,021 due to migration)
--   MinDate           = 2015-01-01
--   MaxDate           = 2016-08-31


-- 2. Recency distribution (Churn / AtRisk signal check)
WITH CustomerLastTxn AS (
    SELECT CustomerID, MAX(TRY_CONVERT(date, TransactionDate, 103)) AS LastTxnDate
    FROM dbo.RawTransactions
    GROUP BY CustomerID
)
SELECT
    CASE
        WHEN DATEDIFF(DAY, LastTxnDate, '2016-08-31') <= 30 THEN '0-30 days (Active)'
        WHEN DATEDIFF(DAY, LastTxnDate, '2016-08-31') <= 60 THEN '31-60 days (Watch)'
        WHEN DATEDIFF(DAY, LastTxnDate, '2016-08-31') <= 90 THEN '61-90 days (AtRisk)'
        ELSE '90+ days (Churned)'
    END AS RecencyBucket,
    COUNT(*) AS CustomerCount
FROM CustomerLastTxn
GROUP BY
    CASE
        WHEN DATEDIFF(DAY, LastTxnDate, '2016-08-31') <= 30 THEN '0-30 days (Active)'
        WHEN DATEDIFF(DAY, LastTxnDate, '2016-08-31') <= 60 THEN '31-60 days (Watch)'
        WHEN DATEDIFF(DAY, LastTxnDate, '2016-08-31') <= 90 THEN '61-90 days (AtRisk)'
        ELSE '90+ days (Churned)'
    END;

-- Expected: ~20% of customers fall into "90+ days (Churned)"
```

---

## Architecture Note

**Why Python for augmentation instead of ETL?**

This design follows data warehousing best practices:

* ✅ **Separation of Concerns:** Data generation (Python) vs. business logic (ETL)
* ✅ **Auditability:** Clear distinction between raw data and calculated metrics
* ✅ **Flexibility:** Business rules (Satisfaction, Churn, Segment) remain in ETL for easy modification
* ✅ **Testability:** Can regenerate source data without affecting ETL logic

**What happens in ETL (not in Python)?**

* Satisfaction Score calculation (based on RF analysis)
* Churn Flag / At-Risk Flag determination (90+ / 60–90 days inactive)
* Complaint Flag derivation (declining transaction patterns)
* **Customer segment assignment** (Champions, Loyal, At-Risk, Churned, etc.) — computed from real `DaysSinceLastTransaction` and `TransactionCount` in `Fact_CustomerSnapshot`, not inherited from the Python "personality" labels

> The Python "personality" assigned to a customer (Champion, Loyal, AtRisk, Churned, NewCustomer) shapes their *behavior* over time — it is an input to the simulation, not the output segment shown in dashboards.

---

## Version History

* **v1.0** (Nov 2025): Initial implementation with smart customer journey simulation. Output: 5–8M transactions over 18 months. Balance was monotonically increasing; amounts had low variance; no seasonality, dormancy, or shock events.
* **v3.3** (Jun 2026) — *DW-Aligned Edition*: Complete rewrite calibrated to `Fact_CustomerSnapshot` KPIs.
  - Bidirectional balance via 11 transaction types (Salary, POS, ATM, EMI, Transfers, Bills, Fees, Deposits, Refunds, Interest)
  - Indian seasonal model (Diwali, Holi, FY-end, monsoon)
  - Dormancy periods (12% of customers, 2–6 month blackouts)
  - Zero-transaction months (personality-specific probability)
  - Campaign-based new customer acquisition (3 waves)
  - Shock events (2% of high-value transactions, 10–50×)
  - Location migration (2%/month, feeds SCD Type 2)
  - Increased monthly volatility (±50–160%) for meaningful GrowthRate
  - Output: ~147M transactions over 20 months
