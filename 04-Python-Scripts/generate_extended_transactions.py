"""
Banking Customer Loyalty & Churn Analytics
Smart Data Augmentation Script - Memory Optimized

Purpose: Extend 18-day transaction dataset to 18 months with realistic customer behaviors
Author: Soheil Tavakkol
Date: November 2025
Version: 2.0 - Memory optimized for large datasets
"""

import pyodbc
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta
import random
from tqdm import tqdm
import warnings
import gc

warnings.filterwarnings('ignore')

# ==========================================
# Configuration
# ==========================================

SERVER = 'localhost'
DATABASE = 'BankingSource'
BATCH_SIZE = 10000
CUSTOMER_BATCH_SIZE = 50000  # Process customers in batches

START_DATE = datetime(2015, 1, 1)
END_DATE = datetime(2016, 8, 31)

CUSTOMER_PERSONALITIES = {
    'Champion': 0.20,
    'Loyal': 0.25,
    'AtRisk': 0.20,
    'Churned': 0.20,
    'NewCustomer': 0.15
}

# ==========================================
# Database Connection
# ==========================================

def get_connection():
    """Create SQL Server connection"""
    conn_str = (
        f'DRIVER={{ODBC Driver 17 for SQL Server}};'
        f'SERVER={SERVER};'
        f'DATABASE={DATABASE};'
        f'Trusted_Connection=yes;'
    )
    return pyodbc.connect(conn_str)

# ==========================================
# Data Loading
# ==========================================

def load_original_data():
    """Load original 18-day transactions"""
    print("Loading original data from SQL Server...")
    
    conn = get_connection()
    query = """
    SELECT 
        TransactionID, CustomerID, CustomerDOB, CustGender, CustLocation,
        CustAccountBalance, TransactionDate, TransactionTime, TransactionAmount
    FROM dbo.RawTransactions
    """
    
    df = pd.read_sql(query, conn)
    conn.close()
    
    print("  Converting data types...")
    df['TransactionAmount'] = pd.to_numeric(df['TransactionAmount'], errors='coerce')
    df['CustAccountBalance'] = pd.to_numeric(df['CustAccountBalance'], errors='coerce')
    df['TransactionAmount'].fillna(100.0, inplace=True)
    df['CustAccountBalance'].fillna(10000.0, inplace=True)
    
    print(f"✓ Loaded {len(df):,} transactions for {df['CustomerID'].nunique():,} customers")
    return df

# ==========================================
# Customer Personality Assignment
# ==========================================

def assign_personality():
    """Assign single personality based on distribution"""
    rand = random.random()
    cumsum = np.cumsum(list(CUSTOMER_PERSONALITIES.values()))
    
    if rand < cumsum[0]:
        return 'Champion'
    elif rand < cumsum[1]:
        return 'Loyal'
    elif rand < cumsum[2]:
        return 'AtRisk'
    elif rand < cumsum[3]:
        return 'Churned'
    else:
        return 'NewCustomer'

# ==========================================
# Transaction Generation
# ==========================================

def generate_customer_transactions(customer_id, customer_info, personality):
    """Generate transactions for one customer based on personality"""
    
    transactions = []
    current_date = START_DATE
    
    dob = customer_info['CustomerDOB']
    gender = customer_info['CustGender']
    location = customer_info['CustLocation']
    avg_amount = customer_info['avg_amount']
    current_balance = customer_info['starting_balance']
    
    # Initialize variables
    base_freq = 10
    churn_month = None
    
    if personality == 'Champion':
        base_freq = random.randint(15, 25)
    elif personality == 'Loyal':
        base_freq = random.randint(8, 14)
    elif personality == 'AtRisk':
        base_freq = random.randint(10, 15)
    elif personality == 'Churned':
        base_freq = random.randint(8, 12)
        churn_month = random.randint(6, 12)
    else:  # NewCustomer
        base_freq = random.randint(5, 10)
        start_offset = random.randint(3, 6)
        current_date = END_DATE - relativedelta(months=start_offset)
    
    month_counter = 0
    transaction_counter = 1
    
    while current_date <= END_DATE:
        month_counter += 1
        
        if churn_month and month_counter > churn_month:
            break
        
        if personality == 'AtRisk':
            freq = max(3, int(base_freq * (0.9 ** (month_counter - 1))))
        else:
            freq = max(1, int(base_freq * random.uniform(0.8, 1.2)))
        
        month_end = min(current_date + relativedelta(months=1) - timedelta(days=1), END_DATE)
        
        for _ in range(freq):
            days_in_period = (month_end - current_date).days + 1
            if days_in_period <= 0:
                break
                
            random_day = random.randint(0, days_in_period - 1)
            txn_date = current_date + timedelta(days=random_day)
            
            if txn_date > END_DATE:
                break
            
            amount = round(avg_amount * random.uniform(0.8, 1.2), 2)
            current_balance += amount
            
            txn = {
                'TransactionID': f'T{customer_id[1:]}_{transaction_counter}',
                'CustomerID': customer_id,
                'CustomerDOB': dob,
                'CustGender': gender,
                'CustLocation': location,
                'CustAccountBalance': round(current_balance, 2),
                'TransactionDate': txn_date.strftime('%Y-%m-%d'),
                'TransactionTime': f"{random.randint(0, 23):02d}{random.randint(0, 59):02d}{random.randint(0, 59):02d}",
                'TransactionAmount': amount
            }
            
            transactions.append(txn)
            transaction_counter += 1
        
        current_date += relativedelta(months=1)
    
    return transactions

# ==========================================
# Main Augmentation Process
# ==========================================

def augment_data(df):
    """Main function to augment data - Memory optimized"""
    
    print("\n" + "="*60)
    print("SMART DATA AUGMENTATION (MEMORY OPTIMIZED)")
    print("="*60)
    
    # Prepare customer summary (memory efficient)
    print("\nPreparing customer data...")
    customer_summary = df.groupby('CustomerID').agg({
        'CustomerDOB': 'first',
        'CustGender': 'first',
        'CustLocation': 'first',
        'TransactionAmount': 'mean',
        'CustAccountBalance': 'first'
    }).reset_index()
    
    customer_summary.columns = ['CustomerID', 'CustomerDOB', 'CustGender', 
                                 'CustLocation', 'avg_amount', 'starting_balance']
    
    # Convert to dict for faster access
    customer_dict = customer_summary.set_index('CustomerID').to_dict('index')
    
    # Clear original dataframe from memory
    del df
    gc.collect()
    
    print(f"✓ Prepared {len(customer_dict):,} customers")
    
    # Assign personalities
    print("\nAssigning personalities...")
    personalities = {}
    personality_counts = {p: 0 for p in CUSTOMER_PERSONALITIES.keys()}
    
    for customer_id in tqdm(customer_dict.keys(), desc="Assigning"):
        p = assign_personality()
        personalities[customer_id] = p
        personality_counts[p] += 1
    
    print("\nPersonality Distribution:")
    for p, count in personality_counts.items():
        pct = count / len(customer_dict) * 100
        print(f"  {p:15s}: {count:6,} ({pct:5.1f}%)")
    
    # Truncate table before starting
    print("\nPreparing database...")
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("TRUNCATE TABLE dbo.RawTransactions")
    conn.commit()
    cursor.close()
    conn.close()
    print("✓ Table truncated")
    
    # Process in batches
    customer_ids = list(customer_dict.keys())
    total_customers = len(customer_ids)
    total_transactions = 0
    
    print(f"\nProcessing {total_customers:,} customers in batches of {CUSTOMER_BATCH_SIZE:,}...")
    
    for batch_start in range(0, total_customers, CUSTOMER_BATCH_SIZE):
        batch_end = min(batch_start + CUSTOMER_BATCH_SIZE, total_customers)
        batch_ids = customer_ids[batch_start:batch_end]
        
        print(f"\n  Batch {batch_start//CUSTOMER_BATCH_SIZE + 1}: Customers {batch_start:,} to {batch_end:,}")
        
        batch_transactions = []
        
        for customer_id in tqdm(batch_ids, desc="  Generating"):
            customer_info = customer_dict[customer_id]
            personality = personalities[customer_id]
            
            txns = generate_customer_transactions(customer_id, customer_info, personality)
            batch_transactions.extend(txns)
        
        # Write batch to database
        if batch_transactions:
            batch_df = pd.DataFrame(batch_transactions)
            write_batch_to_database(batch_df)
            total_transactions += len(batch_transactions)
            
            # Clear batch from memory
            del batch_transactions
            del batch_df
            gc.collect()
        
        print(f"  ✓ Batch complete. Total transactions so far: {total_transactions:,}")
    
    print(f"\n✓ All batches complete. Total: {total_transactions:,} transactions")
    return total_transactions

# ==========================================
# Database Writing (Batch)
# ==========================================

def write_batch_to_database(df):
    """Write batch to SQL Server (append mode)"""
    
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        insert_sql = """
        INSERT INTO dbo.RawTransactions 
        (TransactionID, CustomerID, CustomerDOB, CustGender, CustLocation,
         CustAccountBalance, TransactionDate, TransactionTime, TransactionAmount)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        for i in range(0, len(df), BATCH_SIZE):
            batch = df.iloc[i:i+BATCH_SIZE]
            values = [tuple(x) for x in batch.values]
            cursor.executemany(insert_sql, values)
            conn.commit()
        
    except Exception as e:
        print(f"\n  ✗ Error writing batch: {e}")
        conn.rollback()
        raise
    
    finally:
        cursor.close()
        conn.close()

# ==========================================
# Verification
# ==========================================

def verify_output():
    """Verify the augmented data"""
    
    print("\n" + "="*60)
    print("VERIFICATION")
    print("="*60)
    
    conn = get_connection()
    
    query = """
    SELECT 
        MIN(TransactionDate) AS MinDate,
        MAX(TransactionDate) AS MaxDate,
        COUNT(*) AS TotalRecords,
        COUNT(DISTINCT CustomerID) AS UniqueCustomers,
        AVG(CAST(TransactionAmount AS FLOAT)) AS AvgAmount
    FROM dbo.RawTransactions
    """
    
    result = pd.read_sql(query, conn)
    conn.close()
    
    print("\nFinal Statistics:")
    print(f"  Date Range: {result['MinDate'][0]} to {result['MaxDate'][0]}")
    print(f"  Total Transactions: {result['TotalRecords'][0]:,}")
    print(f"  Unique Customers: {result['UniqueCustomers'][0]:,}")
    print(f"  Average Transaction: ${result['AvgAmount'][0]:,.2f}")
    
    min_date = pd.to_datetime(result['MinDate'][0])
    max_date = pd.to_datetime(result['MaxDate'][0])
    months = (max_date.year - min_date.year) * 12 + (max_date.month - min_date.month) + 1
    print(f"  Months Covered: {months}")
    
    print("\n✓ Data augmentation complete!")

# ==========================================
# Main Execution
# ==========================================

if __name__ == "__main__":
    try:
        print("\n" + "="*60)
        print("BANKING DATA AUGMENTATION SCRIPT v2.0")
        print("Memory Optimized Edition")
        print("="*60)
        print(f"Target: Extend 18 days → 18 months")
