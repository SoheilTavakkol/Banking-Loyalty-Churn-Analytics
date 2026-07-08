# Python Scripts

## Overview

This folder contains the Python scripts used for data preparation and augmentation — the step that turns a ~55-day transaction seed file into a realistic 20-month dataset for the Data Warehouse.

**Status:** ✅ Complete — output verified against the final 147,290,230-row / 884,225-customer dataset loaded into `BankingSource`.

---

## Scripts

### 1. `import_to_sql.py`

Initial data import script that loads the original CSV file (~55 days of transactions) into SQL Server (`BankingSource.dbo.RawTransactions`).

**Status:** ✅ Completed

---

### 2. `generate_transactions_v3_3.py`

**BI-Aligned Data Augmentation Script (v3.3 – DW-Aligned Edition)**

Extends the limited ~55-day transaction dataset (`bank_transactions.csv`) to a full 20-month period (Jan 2015 – Aug 2016), producing realistic time-series data calibrated to the KPIs computed in `Fact_CustomerSnapshot` (Recency, Frequency, Churn, AtRisk, GrowthRate, Loyalty). This is the script that produced the final dataset used throughout the rest of the project.

#### What it does:

* Reads the original transactions from `bank_transactions.csv`
* Builds one behavioral profile per customer (avg amount, starting balance, DOB, gender, location)
* Assigns each customer one of 5 personality types and simulates up to 20 months of activity
* Generates 11 distinct transaction types (Salary, POS, ATM, EMI, Transfers, Bills, Fees, Deposits, Refunds, Interest) with realistic IN/OUT direction
* Maintains a running account balance that grows or shrinks based on income vs. spending
* Writes the full augmented dataset to `BankingSource.dbo.RawTransactions`

**Customer personality types:**

| Segment | Share | Monthly Frequency | Behaviour |
|---|---|---|---|
| Champions | 20% | 15–25 transactions | Consistent activity, +1.5% amount growth/month |
| Loyal | 25% | 8–14 transactions | Stable patterns, rare zero-months (3–5%) |
| At-Risk | 20% | Declining (frequency trend ~0.91^month) | 25% chance of zero-transaction month |
| Churned | 20% | Stops permanently in month 8–15 | 60% chance of zero-month before hard stop |
| New Customers | 15% | 3–8 transactions | Campaign-based acquisition (Mar-15, Aug-15, Jan-16) |

> **Note:** "Personality" here is a Python-side simulation label used only to shape behavior — it is intentionally distinct from the final RF-based **Segment** (Champions, Loyal, Potential Loyalists, New, At Risk, Hibernating, Churned) that the data warehouse computes independently from real transaction history. The two use overlapping names by design (to keep the simulation intuitive) but are not the same thing — see "Architecture Note" below.

#### Key Features:

* **Bidirectional Balance:** Salary credits (IN) and spending withdrawals (OUT) move the balance realistically in both directions — no monotonic growth (a deliberate fix vs. the original v1.0 prototype, see Version History)
* **Indian Seasonal Patterns:** Diwali peak in October (+22%), FY-end surge in March (+18%), trough in February (−15%), with separate seasonal multipliers for amount and frequency
* **Dormancy Periods:** 12% of customers go completely silent for 2–6 months at a random point (starting between month 4–14) — drives `AtRiskFlag` and `ChurnFlag` in the DW
* **Zero-Transaction Months:** Personality-specific probability (3% Champions, 5% Loyal, 25% At-Risk, 60% Churned, 8% New) so `DaysSinceLastTransaction` grows naturally even for "active" personalities
* **Campaign-Based Acquisition:** New customers arrive in three waves (Mar-2015, Aug-2015, Jan-2016) for realistic cohort analysis
* **Shock Events:** 2% probability on high-value transaction types only (POS Purchase, ATM Withdrawal, Transfer In/Out, Cash Deposit) at 10–50× the normal amount — Fee/Refund/Interest are excluded since they're small, predictable amounts. Prevents artificially clean charts
* **Location Migration:** 2% monthly probability of city change per customer — feeds SCD Type 2 in `Dim_Customer`
* **Monthly Volatility:** Frequency noise sampled uniformly between 0.50× and 1.60× — produces meaningful `GrowthRate` month-over-month
* **Weekday & Hour-of-Day Modeling:** Transaction timing weighted by day-of-week (Friday busiest, Sunday quietest) and hour-of-day (salary credits cluster in the morning; general spending peaks midday–evening)
* **Progress Tracking:** Real-time progress bars per customer batch (50,000 customers per cycle)

#### Technical Details:

* **Input:** `bank_transactions.csv` (1,048,567 records, ~55 days)
* **Output:** `BankingSource.dbo.RawTransactions` — **147,290,230 records**, 20 months (verified final count)
* **Customers:** **884,225** unique (matches `Dim_Customer` current-version count downstream)
* **Locations:** **9,354** distinct (after migration — above the original 9,021 due to the 2%/month location-change simulation)
* **Batch Size:** 50,000 customers per generation cycle, 10,000 rows per SQL write
* **Memory:** Memory-optimized — each batch is flushed and garbage-collected before the next begins

#### Important Notes:

* This script **truncates** `RawTransactions` before generating new data
* Set `DATA_SOURCE = "csv"` and `CSV_PATH` to point at your source file before running
* Output column is `TransactionAmount` (matches `BankingSource.dbo.RawTransactions` schema — `VARCHAR`, INR values, no currency suffix)
* Customer **segment labels are NOT written** — the script only controls *behavioral patterns* (frequency, amounts, dormancy). Actual RF segments (Champions, Loyal, At-Risk, Churned, etc.) are computed later by `Fact_CustomerSnapshot` from real transaction history
* Can be re-run to regenerate with different random patterns (re-truncates the table each time) — note that re-running will produce a *different* random dataset each time (no fixed seed), so exact row/customer counts may drift slightly from the verified figures above on a fresh run

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
| `WRITE_BATCH_SIZE` | `10,000` | Rows per SQL `executemany` write |
| `CUSTOMER_BATCH_SIZE` | `50,000` | Customers processed per generation cycle |

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
* **Solution:** Expected for ~147M output rows. Each batch prints progress and a running total; a full run takes several hours depending on hardware

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

-- Expected (final verified run):
--   TotalRows         = 147,290,230
--   UniqueCustomers    = 884,225
--   UniqueLocations   = 9,354 (above original 9,021 due to migration)
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

-- Expected: roughly 20% of customers fall into "90+ days (Churned)",
-- consistent with the Churned personality's 20% population share
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

* Satisfaction Score calculation (randomized bands conditioned on Recency/Frequency Score)
* Churn Flag / At-Risk Flag determination (90+ / 60–90 days inactive)
* Complaint Flag derivation (declining transaction patterns, GrowthRate < -30%)
* **Customer segment assignment** (Champions, Loyal, Potential Loyalists, New, At Risk, Hibernating, Churned) — computed from real `DaysSinceLastTransaction` and `TransactionCount` in `Fact_CustomerSnapshot`, not inherited from the Python "personality" labels

> The Python "personality" assigned to a customer (Champion, Loyal, AtRisk, Churned, NewCustomer) shapes their *behavior* over time — it is an input to the simulation, not the output segment shown in the dashboards. The two happen to correlate strongly (by design, since the simulation was calibrated to produce realistic RF patterns), but a customer's final dashboard segment is always derived from their actual simulated transactions, never copied from their Python personality label.

---

## Version History

* **v1.0** (Nov 2025): Initial prototype (`generate_extended_transactions.py`) — smart customer journey simulation with 5 personality types over a 20-month window. Balance was monotonically increasing (every transaction added to it — no OUT direction); transaction amounts had low variance; no seasonality, dormancy, or shock events. Superseded and not part of the final repository.
* **v2.x – v3.2** (intermediate, Dec 2025 – May 2026): Iterative refinements (not individually preserved in the repo) — added Markov-chain segment transitions, introduced initial seasonal multipliers, and began separating spending transaction types. The Markov-based segment transitions were later removed entirely once it was decided that segments should be recalculated from real RF data in the DW rather than carried forward from Python.
* **v3.3** (Jun 2026) — *DW-Aligned Edition* (current, `generate_transactions_v3_3.py`): Complete rewrite calibrated to `Fact_CustomerSnapshot` KPIs.
  - Removed Markov-based segment transitions (segments now purely a DW/ETL concern)
  - Bidirectional balance via 11 transaction types (Salary, POS, ATM, EMI, Transfers, Bills, Fees, Deposits, Refunds, Interest)
  - Indian seasonal model (Diwali, FY-end, February trough)
  - Dormancy periods (12% of customers, 2–6 month blackouts)
  - Zero-transaction months (personality-specific probability, enables realistic Churn/AtRisk signal)
  - Campaign-based new customer acquisition (3 waves)
  - Shock events restricted to financial transaction types only (10–50× multiplier)
  - Location migration (2%/month, feeds SCD Type 2)
  - Increased monthly volatility (0.50×–1.60×) for meaningful GrowthRate
  - Churn month range tightened to 8–15 months (from an earlier 6–18 month range)
  - **Final output:** 147,290,230 transactions, 884,225 unique customers, 9,354 locations, over 20 months — this is the dataset that flows through the entire rest of the project

---

## Related Documentation

- [Requirements Document](../01-Requirements/) — business context for the KPIs this data is calibrated to
- [Database Scripts](../02-Database-Scripts/) — target schema (`BankingSource.dbo.RawTransactions`)
- [Data Dictionary](../03-Data-Modeling/Data-Dictionary_v1.3.md) — downstream field definitions
- [SSIS Packages](../05-SSIS-Packages/) — next step in the pipeline
- [Project README](../README.md)
