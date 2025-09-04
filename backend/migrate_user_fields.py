"""
Migration script to add email, first_name, last_name, position, and department fields to existing User table
"""

import sqlite3
import os
from passlib.context import CryptContext

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def migrate_user_table():
    """Add new columns to existing users table and update existing users"""
    db_path = "./bidashboard.db"
    
    if not os.path.exists(db_path):
        print("📋 No existing database found. New database will be created with updated schema.")
        return
    
    print("🔄 Starting user table migration...")
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check if new columns already exist
        cursor.execute("PRAGMA table_info(users)")
        columns = [column[1] for column in cursor.fetchall()]
        
        new_columns_needed = []
        if 'email' not in columns:
            new_columns_needed.append('email')
        if 'first_name' not in columns:
            new_columns_needed.append('first_name')
        if 'last_name' not in columns:
            new_columns_needed.append('last_name')
        if 'position' not in columns:
            new_columns_needed.append('position')
        if 'department' not in columns:
            new_columns_needed.append('department')
        
        if not new_columns_needed:
            print("✅ User table already has all required columns.")
            return
        
        print(f"📝 Adding columns: {', '.join(new_columns_needed)}")
        
        # Add new columns
        if 'email' in new_columns_needed:
            cursor.execute("ALTER TABLE users ADD COLUMN email VARCHAR(255)")
        if 'first_name' in new_columns_needed:
            cursor.execute("ALTER TABLE users ADD COLUMN first_name VARCHAR(100)")
        if 'last_name' in new_columns_needed:
            cursor.execute("ALTER TABLE users ADD COLUMN last_name VARCHAR(100)")
        if 'position' in new_columns_needed:
            cursor.execute("ALTER TABLE users ADD COLUMN position VARCHAR(150)")
        if 'department' in new_columns_needed:
            cursor.execute("ALTER TABLE users ADD COLUMN department VARCHAR(100)")
        
        # Update existing users with default values
        cursor.execute("SELECT id, username FROM users")
        existing_users = cursor.fetchall()
        
        for user_id, username in existing_users:
            if username == "mario.gonzalez":
                cursor.execute("""
                    UPDATE users SET 
                        email = ?, 
                        first_name = ?, 
                        last_name = ?, 
                        position = ?, 
                        department = ?
                    WHERE id = ?
                """, (
                    "mario.gonzalez@forzatrans.com",
                    "Mario",
                    "Gonzalez", 
                    "BI Manager",
                    "Business Intelligence",
                    user_id
                ))
            elif username == "testuser":
                cursor.execute("""
                    UPDATE users SET 
                        email = ?, 
                        first_name = ?, 
                        last_name = ?, 
                        position = ?, 
                        department = ?
                    WHERE id = ?
                """, (
                    "test.user@forzatrans.com",
                    "Test",
                    "User",
                    "Data Analyst", 
                    "Business Intelligence",
                    user_id
                ))
            else:
                # Generic default for other users
                cursor.execute("""
                    UPDATE users SET 
                        email = ?, 
                        first_name = ?, 
                        last_name = ?, 
                        position = ?, 
                        department = ?
                    WHERE id = ?
                """, (
                    f"{username}@forzatrans.com",
                    username.split('.')[0].title() if '.' in username else username.title(),
                    username.split('.')[1].title() if '.' in username else "User",
                    "Employee",
                    "General",
                    user_id
                ))
        
        conn.commit()
        print("✅ Migration completed successfully!")
        print(f"📊 Updated {len(existing_users)} existing users")
        
        # Show updated users
        cursor.execute("SELECT username, email, first_name, last_name, position, department FROM users")
        updated_users = cursor.fetchall()
        
        print("\n👥 Updated users:")
        for user in updated_users:
            username, email, first_name, last_name, position, department = user
            print(f"   • {first_name} {last_name} ({username})")
            print(f"     📧 {email}")
            print(f"     💼 {position} - {department}")
            print()
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    print("🚀 User Table Migration Script")
    print("=" * 40)
    migrate_user_table()
    print("🎉 Migration process completed!")