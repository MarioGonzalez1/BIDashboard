#!/usr/bin/env python3
"""
Script to create Mario Gonzalez user in the BIDashboard database
"""

import pyodbc
import os
import sys
from pathlib import Path

# Add the backend directory to the Python path
backend_dir = Path(__file__).parent
sys.path.insert(0, str(backend_dir))

def create_user():
    """Create Mario Gonzalez user in the database"""
    
    # Database connection string (adjust as needed)
    connection_string = (
        "DRIVER={ODBC Driver 17 for SQL Server};"
        "SERVER=localhost;"  # Change if your SQL Server is on a different host
        "DATABASE=BIDashboard;"
        "Trusted_Connection=yes;"  # Use Windows Authentication
    )
    
    # Alternative connection string if you use SQL Server authentication
    # connection_string = (
    #     "DRIVER={ODBC Driver 17 for SQL Server};"
    #     "SERVER=localhost;"
    #     "DATABASE=BIDashboard;"
    #     "UID=your_username;"
    #     "PWD=your_password;"
    # )
    
    try:
        print("🔗 Connecting to SQL Server...")
        
        # Connect to database
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()
        
        print("✅ Connected successfully!")
        print("📝 Reading SQL script...")
        
        # Read the SQL script
        sql_file_path = backend_dir / "database" / "create_user_mario.sql"
        
        if not sql_file_path.exists():
            raise FileNotFoundError(f"SQL script not found at: {sql_file_path}")
        
        with open(sql_file_path, 'r', encoding='utf-8') as file:
            sql_content = file.read()
        
        print("🚀 Executing user creation script...")
        
        # Split the SQL content by GO statements and execute each batch
        sql_batches = [batch.strip() for batch in sql_content.split('GO') if batch.strip()]
        
        for i, batch in enumerate(sql_batches, 1):
            if batch and not batch.startswith('--'):
                try:
                    cursor.execute(batch)
                    print(f"✅ Executed batch {i}/{len(sql_batches)}")
                except pyodbc.Error as e:
                    print(f"⚠️  Warning in batch {i}: {e}")
                    # Continue with other batches
        
        # Commit the transaction
        conn.commit()
        
        print("\n🎉 User creation completed!")
        print("\n📋 User Details:")
        print("   👤 Username: mario.gonzalez")
        print("   📧 Email: mario.gonzalez@forzatrans.com")
        print("   🔐 Temporary Password: ChangeMe2024!")
        print("   👑 Role: Administrator")
        print("\n⚠️  IMPORTANT: Please change your password after first login!")
        
        # Verify user was created
        print("\n🔍 Verifying user creation...")
        cursor.execute("""
            SELECT 
                u.UserID,
                u.Username,
                u.Email,
                u.FirstName + ' ' + u.LastName AS FullName,
                r.RoleName,
                u.CreatedDate,
                u.IsActive
            FROM [Security].[Users] u
            LEFT JOIN [Security].[UserRoles] ur ON u.UserID = ur.UserID
            LEFT JOIN [Security].[Roles] r ON ur.RoleID = r.RoleID
            WHERE u.Email = 'mario.gonzalez@forzatrans.com'
        """)
        
        results = cursor.fetchall()
        if results:
            print("✅ User verification successful:")
            for row in results:
                print(f"   ID: {row[0]}, Username: {row[1]}, Email: {row[2]}")
                print(f"   Name: {row[3]}, Role: {row[4] or 'No role assigned'}")
                print(f"   Created: {row[5]}, Active: {row[6]}")
        else:
            print("❌ User not found - creation may have failed")
        
    except pyodbc.Error as e:
        print(f"❌ Database error: {e}")
        return False
    except FileNotFoundError as e:
        print(f"❌ File error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False
    finally:
        if 'conn' in locals():
            conn.close()
            print("🔒 Database connection closed")
    
    return True

if __name__ == "__main__":
    print("🚀 Starting user creation process...")
    print("="*50)
    
    success = create_user()
    
    print("="*50)
    if success:
        print("✅ Process completed successfully!")
    else:
        print("❌ Process failed - check error messages above")
        sys.exit(1)