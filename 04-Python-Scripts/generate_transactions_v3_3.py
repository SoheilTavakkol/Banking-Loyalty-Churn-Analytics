
"""
Banking Data Augmentation  v3.3  –  DW-Aligned Edition
=======================================================
Changes from v3.2:
  1. Markov transitions removed       (Segment recalculated in DW from real RF data)
  2. Zero-transaction months enabled  (critical for Churn / AtRisk KPIs)
  3. Real dormancy periods            (2-6 month blackout windows for 12% of customers)
  4. Campaign-based acquisition       (NewCustomer starts at Mar-15, Aug-15, or Jan-16)
  5. Higher monthly volatility        (uniform 0.50-1.60 instead of 0.80-1.20)
  6. Shock events restricted          (only financial transaction types, not Fee/Refund/Interest)
  7. Location migration preserved     (supports SCD Type 2 in Dim_Customer)
  8. Churn month range tightened      (8-15 months, was 6-18)
"""

import gc
import random
import warnings
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
from dateutil.relativedelta import relativedelta
from tqdm import tqdm

warnings.filterwarnings("ignore")


# =============================================================================
# 1. CONFIGURATION
# =============================================================================

DATA_SOURCE  = "csv"
CSV_PATH     = "bank_transactions.csv"

SQL_SERVER   = "localhost"
SQL_DATABASE = "BankingSource"
SQL_TABLE    = "RawTransactions"

AUG_START = datetime(2015, 1, 1)
AUG_END   = datetime(2016, 8, 31)

WRITE_BATCH_SIZE    = 10_000
CUSTOMER_BATCH_SIZE = 50_000

PERSONALITY_DIST: Dict[str, float] = {
    "Champion":    0.20,
    "Loyal":       0.25,
    "AtRisk":      0.20,
    "Churned":     0.20,
    "NewCustomer": 0.15,
}

# Shock events: probability and multiplier range
SHOCK_PROB             = 0.02
SHOCK_MULTIPLIER_RANGE = (10, 50)

# Shock applies only to high-value financial types
# Fee / Refund / Interest are excluded (small, predictable amounts)
SHOCK_ELIGIBLE_TYPES = {
    "POSPurchase",
    "ATMWithdrawal",
    "TransferOut",
    "TransferIn",
    "CashDeposit",
}

# Location migration probability per month
LOCATION_CHANGE_PROB = 0.02

# Campaign months: NewCustomer cohorts acquired in waves
CAMPAIGN_MONTHS: List[datetime] = [
    datetime(2015, 3, 1),
    datetime(2015, 8, 1),
    datetime(2016, 1, 1),
]

# Dormancy: 12% of customers go silent for 2-6 months at a random point
DORMANCY_PROB          = 0.12
DORMANCY_LENGTH_RANGE  = (2, 6)   # months of silence
DORMANCY_START_RANGE   = (4, 14)  # dormancy can begin in month 4-14

# Zero-transaction month probability by personality
# These zero-frequency months drive DaysSinceLastTransaction, ChurnFlag, AtRiskFlag
ZERO_MONTH_PROB: Dict[str, float] = {
    "Champion":    0.03,   # rare skip — Champions rarely go quiet
    "Loyal":       0.05,   # occasional missed month
    "AtRisk":      0.25,   # frequent gaps — drives AtRiskFlag in DW
    "Churned":     0.60,   # mostly inactive before hard stop — drives ChurnFlag
    "NewCustomer": 0.08,   # still establishing rhythm
}


# =============================================================================
# 2. TEMPORAL MODELS
# =============================================================================

SEASONAL_AMOUNT_MULT: Dict[int, float] = {
    1:  0.92, 2:  0.85, 3:  1.18, 4:  1.00,
    5:  1.02, 6:  0.95, 7:  0.93, 8:  1.05,
    9:  1.08, 10: 1.22, 11: 1.18, 12: 1.10,
}

SEASONAL_FREQ_MULT: Dict[int, float] = {
    1:  0.90, 2:  0.85, 3:  1.10, 4:  1.00,
    5:  1.02, 6:  0.95, 7:  0.93, 8:  1.05,
    9:  1.08, 10: 1.20, 11: 1.15, 12: 1.08,
}

WEEKDAY_MULT: Dict[int, float] = {
    0: 1.05, 1: 1.00, 2: 1.00, 3: 1.02,
    4: 1.12, 5: 0.95, 6: 0.82,
}

_RAW_HOUR = np.array([
    0.005, 0.003, 0.002, 0.002, 0.003, 0.008,
    0.015, 0.025, 0.045, 0.065, 0.075, 0.085,
    0.082, 0.080, 0.082, 0.090, 0.092, 0.100,
    0.085, 0.065, 0.055, 0.035, 0.020, 0.010,
])
HOUR_WEIGHTS = _RAW_HOUR / _RAW_HOUR.sum()

_RAW_SAL_HOUR = np.array([
    0.05, 0.12, 0.18, 0.28, 0.25, 0.12,
    0.00, 0.00, 0.00, 0.00, 0.00, 0.00,
    0.00, 0.00, 0.00, 0.00, 0.00, 0.00,
    0.00, 0.00, 0.00, 0.00, 0.00, 0.00,
])
SALARY_HOUR_WEIGHTS = _RAW_SAL_HOUR / _RAW_SAL_HOUR.sum()


# =============================================================================
# 3. TRANSACTION TYPE MODEL
# =============================================================================

TXN_TYPES: Dict[str, Tuple[str, Tuple[float, float]]] = {
    "SalaryCredit":  ("IN",  (18.0, 35.0)),
    "CashDeposit":   ("IN",  (2.0,  8.0)),
    "TransferIn":    ("IN",  (1.5,  5.0)),
    "Refund":        ("IN",  (0.2,  0.8)),
    "Interest":      ("IN",  (0.01, 0.04)),
    "POSPurchase":   ("OUT", (0.3,  1.5)),
    "ATMWithdrawal": ("OUT", (0.5,  2.0)),
    "BillPayment":   ("OUT", (0.5,  1.5)),
    "TransferOut":   ("OUT", (0.8,  3.0)),
    "EMI":           ("OUT", (1.5,  4.0)),
    "Fee":           ("OUT", (0.01, 0.10)),
}

_TXN_KEYS            = list(TXN_TYPES.keys())
_TXN_KEYS_NO_SALARY  = _TXN_KEYS[1:]

assert _TXN_KEYS[0] == "SalaryCredit"

_RAW_SEG_W: Dict[str, np.ndarray] = {
    "Champion":    np.array([0.04, 0.02, 0.05, 0.03, 0.01, 0.38, 0.12, 0.14, 0.10, 0.09, 0.02]),
    "Loyal":       np.array([0.05, 0.03, 0.04, 0.03, 0.01, 0.35, 0.14, 0.16, 0.08, 0.09, 0.02]),
    "AtRisk":      np.array([0.03, 0.04, 0.03, 0.02, 0.01, 0.28, 0.25, 0.15, 0.12, 0.05, 0.02]),
    "Churned":     np.array([0.02, 0.03, 0.02, 0.01, 0.01, 0.22, 0.35, 0.12, 0.15, 0.05, 0.02]),
    "NewCustomer": np.array([0.05, 0.08, 0.10, 0.04, 0.01, 0.32, 0.12, 0.12, 0.06, 0.08, 0.02]),
}

SEG_W_NO_SAL: Dict[str, np.ndarray] = {
    k: v[1:] / v[1:].sum() for k, v in _RAW_SEG_W.items()
}

ATM_DENOMINATIONS = [500, 1_000, 2_000, 5_000]


# =============================================================================
# 4. PERSONALITY CONFIGURATION
# =============================================================================

@dataclass
class PersonalityConfig:
    freq_min:          int
    freq_max:          int
    amount_trend_rate: float
    amount_trend_cap:  float
    amount_sigma:      float
    churn_month_range: Optional[Tuple[int, int]] = None


PERSONALITY_CONFIGS: Dict[str, PersonalityConfig] = {
    "Champion":    PersonalityConfig(15, 25, 1.015, 1.45, 0.35),
    "Loyal":       PersonalityConfig( 8, 14, 1.005, 1.18, 0.30),
    "AtRisk":      PersonalityConfig( 8, 15, 0.960, 0.40, 0.45),
    "Churned":     PersonalityConfig( 5, 12, 0.920, 0.15, 0.50, churn_month_range=(8, 15)),
    "NewCustomer": PersonalityConfig( 3,  8, 1.008, 1.20, 0.38),
}


# =============================================================================
# 5. AMOUNT MODEL  (shock restricted to SHOCK_ELIGIBLE_TYPES)
# =============================================================================

class AmountModel:
    MIN_AMOUNT = 1.0

    def __init__(self, avg_amount: float, cfg: PersonalityConfig):
        self.avg     = max(avg_amount, 10.0)
        self.cfg     = cfg
        self._log_mu = np.log(self.avg) - (cfg.amount_sigma ** 2) / 2.0

    def sample(self, txn_type: str, month_index: int, cal_month: int) -> float:
        if txn_type == "ATMWithdrawal":
            amount = float(random.choice(ATM_DENOMINATIONS))

        elif txn_type == "Fee":
            amount = round(random.uniform(5, 350), 2)

        else:
            base     = np.random.lognormal(self._log_mu, self.cfg.amount_sigma)
            trend    = max(0.05, min(self.cfg.amount_trend_rate ** month_index,
                                     self.cfg.amount_trend_cap))
            seasonal = SEASONAL_AMOUNT_MULT[cal_month]
            _, (lo, hi) = TXN_TYPES[txn_type]
            amount   = base * trend * seasonal * random.uniform(lo, hi)

        # Shock: 2% chance, only for high-value transaction types
        if txn_type in SHOCK_ELIGIBLE_TYPES and random.random() < SHOCK_PROB:
            lo_s, hi_s = SHOCK_MULTIPLIER_RANGE
            amount    *= random.uniform(lo_s, hi_s)

        return max(self.MIN_AMOUNT, round(amount, 2))


# =============================================================================
# 6. BALANCE TRACKER
# =============================================================================

class BalanceTracker:
    RBI_MIN = 100.0

    def __init__(self, starting_balance: float):
        self.balance = max(float(starting_balance), self.RBI_MIN)

    def apply(self, txn_type: str, amount: float) -> float:
        direction, _ = TXN_TYPES[txn_type]
        if direction == "IN":
            self.balance += amount
        else:
            self.balance = max(self.RBI_MIN, self.balance - amount)
        return round(self.balance, 2)


# =============================================================================
# 7. HELPERS
# =============================================================================

_P_KEYS  = list(PERSONALITY_DIST.keys())
_P_PROBS = list(PERSONALITY_DIST.values())


def assign_personality() -> str:
    return str(np.random.choice(_P_KEYS, p=_P_PROBS))


def make_txn_time(txn_type: str) -> int:
    weights = SALARY_HOUR_WEIGHTS if txn_type == "SalaryCredit" else HOUR_WEIGHTS
    h = int(np.random.choice(np.arange(24), p=weights))
    m = random.randint(0, 59)
    s = random.randint(0, 59)
    return h * 10_000 + m * 100 + s


def make_txn_date(day: datetime) -> str:
    return f"{day.day}/{day.month}/{day.year}"


# =============================================================================
# 8. TRANSACTION GENERATOR  (per-customer)
# =============================================================================

def generate_customer_transactions(
    customer_id:   str,
    profile:       dict,
    personality:   str,
    all_locations: List[str],
) -> List[dict]:

    cfg          = PERSONALITY_CONFIGS[personality]
    amount_model = AmountModel(profile["avg_amount"], cfg)
    balance      = BalanceTracker(profile["starting_balance"])

    dob         = profile["dob"]
    gender      = profile["gender"]
    current_loc = profile["location"]

    # ── Activity window ──────────────────────────────────────────────────────
    start_date  = AUG_START
    churn_month: Optional[int] = None
    salary_day  = random.choice([1, 5, 25, 28])

    if personality == "Churned":
        lo, hi      = cfg.churn_month_range      # type: ignore[misc]
        churn_month = random.randint(lo, hi)

    elif personality == "NewCustomer":
        # Campaign-based cohort acquisition: customers arrive in waves
        start_date = random.choice(CAMPAIGN_MONTHS)
        start_date = max(AUG_START, start_date)

    # ── Dormancy window (12% of all customers, any personality) ──────────────
    dormant_until: Optional[Tuple[int, int]] = None
    if random.random() < DORMANCY_PROB:
        d_len   = random.randint(*DORMANCY_LENGTH_RANGE)
        d_start = random.randint(*DORMANCY_START_RANGE)
        dormant_until = (d_start, d_start + d_len)

    base_freq   = random.randint(cfg.freq_min, cfg.freq_max)
    transactions: List[dict] = []
    txn_counter = 1
    current_date = start_date
    month_index  = 0

    while current_date <= AUG_END:
        month_index += 1
        cal_month    = current_date.month

        # ── Hard stop: churned customers go permanently silent ────────────────
        if churn_month and month_index > churn_month:
            break

        # ── Dormancy: customer is silent during blackout window ───────────────
        if dormant_until:
            d_start, d_end = dormant_until
            if d_start <= month_index <= d_end:
                current_date += relativedelta(months=1)
                continue  # no transactions this month — DaysSinceLastTransaction grows

        # ── Salary credit ─────────────────────────────────────────────────────
        salary_prob = {
            "Champion":    0.97,
            "Loyal":       0.95,
            "NewCustomer": 0.80,
            "AtRisk":      max(0.15, 0.85 - 0.04 * month_index),
            "Churned":     max(0.05, 0.70 - 0.08 * month_index),
        }[personality]

        if random.random() < salary_prob:
            s_day  = min(salary_day, 28)
            s_date = (current_date.replace(day=s_day) + timedelta(days=random.randint(-1, 2)))
            s_date = min(max(s_date, current_date), AUG_END)

            amount   = amount_model.sample("SalaryCredit", month_index - 1, cal_month)
            bal_snap = balance.apply("SalaryCredit", amount)

            transactions.append({
                "TransactionID":           f"T{customer_id[1:]}_{txn_counter}",
                "CustomerID":              customer_id,
                "CustomerDOB":             dob,
                "CustGender":              gender,
                "CustLocation":            current_loc,
                "CustAccountBalance":      bal_snap,
                "TransactionDate":         make_txn_date(s_date),
                "TransactionTime":         make_txn_time("SalaryCredit"),
                "TransactionAmount": amount,
            })
            txn_counter += 1

        # ── Spending frequency ────────────────────────────────────────────────
        if personality == "AtRisk":
            # Frequency declines progressively
            freq_trend = max(0.25, 0.91 ** (month_index - 1))

        elif personality == "Churned":
            # Frequency accelerates downward in the last 5 months before churn_month
            months_until_churn = max(1, (churn_month or 99) - month_index)
            if months_until_churn <= 5:
                freq_trend = max(0.05, 0.82 ** (5 - months_until_churn))
            else:
                freq_trend = 1.0

        else:
            freq_trend = 1.0

        # Higher volatility (0.50-1.60) creates meaningful MoM GrowthRate variance
        freq = max(0, int(
            base_freq
            * freq_trend
            * SEASONAL_FREQ_MULT[cal_month]
            * random.uniform(0.50, 1.60)
        ))

        # Personality-specific zero-month probability
        # This drives DaysSinceLastTransaction > 60/90 → AtRisk / Churn flags in DW
        if random.random() < ZERO_MONTH_PROB[personality]:
            freq = 0

        # ── Location migration ────────────────────────────────────────────────
        if len(all_locations) > 1 and random.random() < LOCATION_CHANGE_PROB:
            candidates  = [l for l in all_locations if l != current_loc]
            current_loc = random.choice(candidates)

        # ── Spending transactions ─────────────────────────────────────────────
        month_end  = min(current_date + relativedelta(months=1) - timedelta(days=1), AUG_END)
        days_span  = (month_end - current_date).days + 1

        for _ in range(freq):
            txn_date = current_date + timedelta(days=random.randint(0, days_span - 1))
            if txn_date > AUG_END:
                continue
            if random.random() > min(1.0, WEEKDAY_MULT[txn_date.weekday()]):
                continue

            txn_type = str(np.random.choice(
                _TXN_KEYS_NO_SALARY,
                p=SEG_W_NO_SAL[personality],
            ))

            amount   = amount_model.sample(txn_type, month_index - 1, cal_month)
            bal_snap = balance.apply(txn_type, amount)

            transactions.append({
                "TransactionID":           f"T{customer_id[1:]}_{txn_counter}",
                "CustomerID":              customer_id,
                "CustomerDOB":             dob,
                "CustGender":              gender,
                "CustLocation":            current_loc,
                "CustAccountBalance":      bal_snap,
                "TransactionDate":         make_txn_date(txn_date),
                "TransactionTime":         make_txn_time(txn_type),
                "TransactionAmount": amount,
            })
            txn_counter += 1

        current_date += relativedelta(months=1)

    return transactions


# =============================================================================
# 9. DATA LOADING & PROFILING
# =============================================================================

def get_sql_connection():
    import pyodbc
    return pyodbc.connect(
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_SERVER};DATABASE={SQL_DATABASE};Trusted_Connection=yes;"
    )


def load_source_data() -> pd.DataFrame:
    if DATA_SOURCE == "csv":
        print(f"  Source: CSV  →  {CSV_PATH}")
        df = pd.read_csv(CSV_PATH)
    else:
        print(f"  Source: SQL  →  {SQL_SERVER}.{SQL_DATABASE}.{SQL_TABLE}")
        conn = get_sql_connection()
        df   = pd.read_sql(f"SELECT * FROM dbo.{SQL_TABLE}", conn)
        conn.close()

    df.columns = [c.strip() for c in df.columns]
    df["TransactionAmount"] = (
        pd.to_numeric(df["TransactionAmount"], errors="coerce").fillna(500.0)
    )
    df["CustAccountBalance"] = (
        pd.to_numeric(df["CustAccountBalance"], errors="coerce").fillna(10_000.0)
    )
    print(f"  ✓ {len(df):,} rows  |  {df['CustomerID'].nunique():,} customers")
    return df


def build_customer_profiles(
    df: pd.DataFrame,
) -> Tuple[Dict[str, dict], List[str]]:

    def _log_mean(x: pd.Series) -> float:
        pos = x[x > 0]
        return float(np.exp(np.log(pos).mean())) if len(pos) > 0 else 500.0

    agg = (
        df.groupby("CustomerID")
        .agg(
            avg_amount       = ("TransactionAmount", _log_mean),
            starting_balance = ("CustAccountBalance",      "first"),
            gender           = ("CustGender",              "first"),
            location         = ("CustLocation",            "first"),
            dob              = ("CustomerDOB",              "first"),
        )
        .reset_index()
    )
    cap = agg["avg_amount"].quantile(0.99)
    agg["avg_amount"] = agg["avg_amount"].clip(upper=cap)

    profiles      = agg.set_index("CustomerID").to_dict("index")
    all_locations = sorted(df["CustLocation"].dropna().unique().tolist())

    return profiles, all_locations


# =============================================================================
# 10. SQL WRITER
# =============================================================================

_OUTPUT_COLS = [
    "TransactionID", "CustomerID", "CustomerDOB", "CustGender", "CustLocation",
    "CustAccountBalance", "TransactionDate", "TransactionTime", "TransactionAmount",
]

_INSERT_SQL = f"""
    INSERT INTO dbo.{SQL_TABLE}
    (TransactionID, CustomerID, CustomerDOB, CustGender, CustLocation,
     CustAccountBalance, TransactionDate, TransactionTime, [TransactionAmount])
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
"""


def write_batch_to_sql(df: pd.DataFrame) -> None:
    conn   = get_sql_connection()
    cursor = conn.cursor()
    try:
        rows = df[_OUTPUT_COLS].values.tolist()
        for i in range(0, len(rows), WRITE_BATCH_SIZE):
            cursor.executemany(_INSERT_SQL, rows[i : i + WRITE_BATCH_SIZE])
            conn.commit()
    except Exception as exc:
        conn.rollback()
        raise exc
    finally:
        cursor.close()
        conn.close()


# =============================================================================
# 11. AUGMENTATION ORCHESTRATOR
# =============================================================================

def run_augmentation(
    profiles:      Dict[str, dict],
    all_locations: List[str],
) -> int:

    print("\n" + "=" * 68)
    print("  AUGMENTATION  v3.3  –  DW-Aligned Edition")
    print("=" * 68)
    print(f"  Window    : {AUG_START.date()}  →  {AUG_END.date()}")
    print(f"  Customers : {len(profiles):,}")
    print(f"  Locations : {len(all_locations):,} unique")
    print(f"  Campaigns : {[d.strftime('%b-%Y') for d in CAMPAIGN_MONTHS]}")

    print("\n[1/4]  Assigning personalities …")
    personalities: Dict[str, str] = {}
    counts = {p: 0 for p in PERSONALITY_DIST}
    for cid in tqdm(profiles, desc="  Assign", ncols=72):
        p                  = assign_personality()
        personalities[cid] = p
        counts[p]         += 1

    print("\n  Distribution:")
    for p, n in counts.items():
        bar = "█" * int(n / len(profiles) * 36)
        print(f"    {p:15s}  {n:7,}  ({n/len(profiles)*100:4.1f}%)  {bar}")

    print("\n[2/4]  Truncating SQL table …")
    conn   = get_sql_connection()
    cursor = conn.cursor()
    cursor.execute(f"TRUNCATE TABLE dbo.{SQL_TABLE}")
    conn.commit()
    cursor.close()
    conn.close()
    print("  ✓ Done")

    all_ids    = list(profiles.keys())
    n_batches  = -(-len(all_ids) // CUSTOMER_BATCH_SIZE)
    total_txns = 0

    print(f"\n[3/4]  Generating  (batch = {CUSTOMER_BATCH_SIZE:,} customers) …")
    for b_idx, start in enumerate(range(0, len(all_ids), CUSTOMER_BATCH_SIZE)):
        batch_ids  = all_ids[start : start + CUSTOMER_BATCH_SIZE]
        batch_rows: List[dict] = []

        print(f"\n  Batch {b_idx+1}/{n_batches}  –  customers {start:,}–{start+len(batch_ids):,}")
        for cid in tqdm(batch_ids, desc="  Generate", leave=False, ncols=72):
            batch_rows.extend(
                generate_customer_transactions(
                    cid, profiles[cid], personalities[cid], all_locations
                )
            )

        if batch_rows:
            df_b = pd.DataFrame(batch_rows)
            write_batch_to_sql(df_b)
            total_txns += len(batch_rows)
            del df_b, batch_rows
            gc.collect()

        print(f"  ✓ Running total: {total_txns:,}")

    return total_txns


# =============================================================================
# 12. VERIFICATION
# =============================================================================

def verify_output() -> None:
    print("\n[4/4]  Verifying output …")
    conn  = get_sql_connection()
    stats = pd.read_sql(f"""
        SELECT
            MIN(TransactionDate)                            AS MinDate,
            MAX(TransactionDate)                            AS MaxDate,
            COUNT(*)                                        AS TotalRows,
            COUNT(DISTINCT CustomerID)                      AS UniqueCustomers,
            COUNT(DISTINCT CustLocation)                    AS UniqueLocations,
            AVG(CAST([TransactionAmount] AS FLOAT))   AS AvgAmount,
            MAX(CAST([TransactionAmount] AS FLOAT))   AS MaxAmount,
            AVG(CAST(CustAccountBalance        AS FLOAT))   AS AvgBalance,
            MIN(CAST(CustAccountBalance        AS FLOAT))   AS MinBalance
        FROM dbo.{SQL_TABLE}
    """, conn)
    conn.close()

    r = stats.iloc[0]
    print(f"\n  Date range        : {r.MinDate}  →  {r.MaxDate}")
    print(f"  Total rows        : {r.TotalRows:,.0f}")
    print(f"  Unique customers  : {r.UniqueCustomers:,.0f}")
    print(f"  Unique locations  : {r.UniqueLocations:,.0f}")
    print(f"  Avg amount   (₹)  : {r.AvgAmount:>14,.2f}")
    print(f"  Max amount   (₹)  : {r.MaxAmount:>14,.2f}  ← shock events visible")
    print(f"  Avg balance  (₹)  : {r.AvgBalance:>14,.2f}")
    print(f"  Min balance  (₹)  : {r.MinBalance:>14,.2f}")
    print("\n  ✓ Ready for SSIS Package 1 → Load Staging")


# =============================================================================
# 13. ENTRY POINT
# =============================================================================

if __name__ == "__main__":
    print("\n" + "=" * 68)
    print("  BANKING DATA AUGMENTATION  v3.3")
    print("  DW-Aligned Edition  –  Indian Banking Context")
    print("=" * 68)
    print(f"  Target : {SQL_SERVER}.{SQL_DATABASE}.{SQL_TABLE}")
    print(f"  Period : {AUG_START.date()}  →  {AUG_END.date()}")

    try:
        print("\n[Loading seed data]")
        df_seed              = load_source_data()
        profiles, all_locs   = build_customer_profiles(df_seed)
        del df_seed
        gc.collect()

        total = run_augmentation(profiles, all_locs)
        verify_output()

        print("\n" + "=" * 68)
        print(f"  SUCCESS  –  {total:,} transactions generated")
        print("  Next: SSIS  →  Package 1 – Load Staging")
        print("=" * 68 + "\n")

    except Exception as exc:
        import traceback
        print(f"\n  FAILED: {exc}")
        traceback.print_exc()
ENDOFSCRIPT
