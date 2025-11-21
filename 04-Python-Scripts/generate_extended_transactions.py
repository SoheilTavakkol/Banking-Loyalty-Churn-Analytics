"""
Banking Customer Loyalty & Churn Analytics
Smart Data Augmentation Script

Purpose: Extend 18-day transaction dataset to 18 months with realistic customer behaviors
Author: Soheil Tavakkol
Date: November 2025
Version: 1.1 - Fixed numeric conversion issues
"""

import pyodbc
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta
import random
from tqdm import tqdm
import warnings

# Suppress pandas warnings
warnings.filterwarnings('ignore')

# ==========================================
# Configuration
# ==========================================

SERVER = 'localhost'  # Change if needed
DATABASE = 'BankingSource'
BATCH_SIZE = 10000  # Insert records in batches

# Date range for augmentation
START_DATE = datetime(2015, 1, 1)
END_DATE = datetime(2016, 8, 31)

# Customer personality distribution
CUSTOMER_PERSONALITIES = {
    'Champion': 0.20,      # 20% - High frequency, consistent
    'Loyal': 0.25,         # 25% - Medium frequency, stable
    'AtRisk': 0.20,        # 20% - Declining over time
    'Churned': 0.20,       # 20% - Stop after some months
    'NewCustomer': 0.15    # 15% - Recent joiners only
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
        TransactionID,
        CustomerID,
        CustomerDOB,
        CustGender,
        CustLocation,
        CustAccountBalance,
        TransactionDate,
        TransactionTime,
        TransactionAmount
    FROM dbo.RawTransactions
    """
    
    df = pd.read_sql(query, conn)
    conn.close()
    
    # Convert numeric columns properly
    print("  Converting data types...")
    df['TransactionAmount'] = pd.to_numeric(df['TransactionAmount'], errors='coerce')
    df['CustAccountBalance'] = pd.to_numeric(df['CustAccountBalance'], errors='coerce')
    
    # Fill NaN values with defaults
    df['TransactionAmount'].fillna(100.0, inplace=True)
    df['CustAccountBalance'].fillna(10000.0, inplace=True)
    
    print(f"✓ Loaded {len(df):,} transactions for {df['CustomerID'].nunique():,} customers")
    return df

# ==========================================
# Customer Personality Assignment
# ==========================================

def assign_customer_personalities(customers):
    """Assign personality type to each customer"""
    print("\nAssigning customer personalities...")
    
    personalities = []
    cumsum = np.cumsum(list(CUSTOMER_PERSONALITIES.values()))
    
    for _ in tqdm(range(len(customers)), desc="Assigning personalities"):
        rand = random.random()
        if rand < cumsum[0]:
            personalities.append('Champion')
        elif rand < cumsum[1]:
            personalities.append('Loyal')
        elif rand < cumsum[2]:
            personalities.append('AtRisk')
        elif rand < cumsum[3]:
            personalities.append('Churned')
        else:
            personalities.append('NewCustomer')
    
    return personalities

# ==========================================
# Transaction Generation
# ==========================================

def generate_customer_transactions(customer_data, personality, original_txns):
    """Generate transactions for one customer based on personality"""
    
    transactions = []
    current_date = START_DATE
    
    # Customer info (same for all transactions)
    customer_id = customer_data['CustomerID']
    dob = customer_data['CustomerDOB']
    gender = customer_data['CustGender']
    location = customer_data['CustLocation']
    
    # Get average transaction amount (now safely numeric)
    avg_amount = original_txns['TransactionAmount'].mean()
    if pd.isna(avg_amount) or avg_amount == 0:
        avg_amount = 500.0  # Default amount
    
    # Get starting balance (now safely numeric)
    current_balance = original_txns['CustAccountBalance'].iloc[0]
    if pd.isna(current_balance) or current_balance == 0:
        current_balance = 10000.0  # Default starting balance
    
    # Determine transaction frequency based on personality
    if personality == 'Champion':
        base_freq = random.randint(15, 25)  # 15-25 txns/month
        churn_month = None  # Never churns
        
    elif personality == 'Loyal':
        base_freq = random.randint(8, 14)   # 8-14 txns/month
        churn_month = None  # Never churns
        
    elif personality == 'AtRisk':
        base_freq = random.randint(10, 15)  # Starts 10-15
        churn_month = None  # Declines but doesn't fully churn
        
    elif personality == 'Churned':
        base_freq = random.randint(8, 12)   # 8-12 initially
        churn_month = random.randint(6, 12)  # Churns after 6-12 months
        
    else:  # NewCustomer
        base_freq = random.randint(5, 10)   # 5-10 txns/month
        # Only appears in last 3-6 months
        start_offset = random.randint(3, 6)
        current_date = END_DATE - relativedelta(months=start_offset)
    
    # Generate transactions month by month
    month_counter = 0
    transaction_counter = 1
    
    while current_date <= END_DATE:
        month_counter += 1
        
        # Check if customer has churned
        if churn_month and month_counter > churn_month:
            break
        
        # Calculate frequency for this month
        if personality == 'AtRisk':
            # Gradual decline: reduce by 10% each month
            freq = max(3, int(base_freq * (0.9 ** (month_counter - 1))))
        else:
            # Add some randomness (±20%)
            freq = max(1, int(base_freq * random.uniform(0.8, 1.2)))
        
        # Generate transactions for this month
        month_end = min(current_date + relativedelta(months=1) - timedelta(days=1), END_DATE)
        
        for _ in range(freq):
            # Random date within the month
            days_in_period = (month_end - current_date).days + 1
            if days_in_period <= 0:
                break
            random_day = random.randint(0, days_in_period - 1)
            txn_date = current_date + timedelta(days=random_day)
            
            if txn_date > END_DATE:
                break
            
            # Generate transaction amount (±20% variation)
            amount = round(float(avg_amount) * random.uniform(0.8, 1.2), 2)
            
            # Update balance
            current_balance = float(current_balance) + amount
            
            # Generate transaction
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
        
        # Move to next month
        current_date += relativedelta(months=1)
    
    return transactions

# ==========================================
# Main Augmentation Process
# ==========================================

def augment_data(df):
    """Main function to augment data"""
    
    print("\n" + "="*60)
    print("SMART DATA AUGMENTATION")
    print("="*60)
    
    # Get unique customers
    customers = df.groupby('CustomerID').first().reset_index()
    print(f"\nProcessing {len(customers):,} unique customers")
    
    # Assign personalities
    customers['Personality'] = assign_customer_personalities(customers)
    
    # Show personality distribution
    print("\nPersonality Distribution:")
    for p, count in customers['Personality'].value_counts().items():
        pct = count / len(customers) * 100
        print(f"  {p:15s}: {count:6,} ({pct:5.1f}%)")
    
    # Generate new transactions
    print("\nGenerating transactions...")
    all_transactions = []
    
    for idx, row in tqdm(customers.iterrows(), total=len(customers), desc="Processing customers"):
        # Get original transactions for this customer
        original_txns = df[df['CustomerID'] == row['CustomerID']]
        
        # Generate new transactions
        new_txns = generate_customer_transactions(row, row['Personality'], original_txns)
        all_transactions.extend(new_txns)
    
    # Convert to DataFrame
    result_df = pd.DataFrame(all_transactions)
    
    print(f"\n✓ Generated {len(result_df):,} transactions")
    print(f"  Date range: {result_df['TransactionDate'].min()} to {result_df['TransactionDate'].max()}")
    
    return result_df

# ==========================================
# Database Writing
# ==========================================

def write_to_database(df):
    """Write augmented data to SQL Server"""
    
    print("\nWriting to SQL Server...")
    print("⚠️  This will TRUNCATE RawTransactions and insert new data")
    
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        # Truncate existing data
        print("  Truncating table...")
        cursor.execute("TRUNCATE TABLE dbo.RawTransactions")
        conn.commit()
        
        # Prepare insert statement
        insert_sql = """
        INSERT INTO dbo.RawTransactions 
        (TransactionID, CustomerID, CustomerDOB, CustGender, CustLocation,
         CustAccountBalance, TransactionDate, TransactionTime, TransactionAmount)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        # Insert in batches
        total_batches = (len(df) + BATCH_SIZE - 1) // BATCH_SIZE
        
        for i in tqdm(range(0, len(df), BATCH_SIZE), total=total_batches, desc="Inserting batches"):
            batch = df.iloc[i:i+BATCH_SIZE]
            
            # Convert DataFrame rows to tuples
            values = [tuple(x) for x in batch.values]
            
            # Execute batch insert
            cursor.executemany(insert_sql, values)
            conn.commit()
        
        print(f"\n✓ Successfully inserted {len(df):,} records")
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
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
    
    # Calculate months covered
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
        print("BANKING DATA AUGMENTATION SCRIPT")
        print("="*60)
        print(f"Target: Extend 18 days → 18 months")
        print(f"Period: {START_DATE.strftime('%Y-%m-%d')} to {END_DATE.strftime('%Y-%m-%d')}")
        print("="*60)
        
        # Step 1: Load original data
        original_df = load_original_data()
        
        # Step 2: Augment data
        augmented_df = augment_data(original_df)
        
        # Step 3: Write to database
        write_to_database(augmented_df)
        
        # Step 4: Verify
        verify_output()
        
        print("\n" + "="*60)
        print("SUCCESS! Ready for ETL processing.")
        print("="*60 + "\n")
        
    except Exception as e:
        print(f"\n✗ Error occurred: {e}")
        import traceback
        traceback.print_exc()
