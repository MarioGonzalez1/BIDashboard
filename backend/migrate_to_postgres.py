"""
Migration script from JSON to PostgreSQL for BIDashboard
Author: Database Architect
Date: 2025-09-03
"""

import json
import os
from datetime import datetime
from passlib.context import CryptContext
from database_postgres import SessionLocal, User, Dashboard, Employee, init_database, test_connection

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)

def hash_password(password: str) -> str:
    """Hash a password"""
    return pwd_context.hash(password)

def migrate_data():
    """
    Migrate data from JSON file to PostgreSQL database
    """
    print("🚀 Starting migration from JSON to PostgreSQL...")
    
    # Initialize database
    if not test_connection():
        print("❌ Database connection failed!")
        return False
    
    init_database()
    
    # Load JSON data
    json_file = "db.json"
    if not os.path.exists(json_file):
        print(f"❌ JSON file {json_file} not found!")
        return False
    
    with open(json_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    db = SessionLocal()
    try:
        # Migrate Users
        print("👥 Migrating users...")
        for user_data in data.get("users", []):
            existing_user = db.query(User).filter(User.username == user_data["username"]).first()
            if not existing_user:
                user = User(
                    username=user_data["username"],
                    hashed_password=user_data["hashed_password"],
                    is_admin=user_data.get("is_admin", False),
                    is_active=True
                )
                db.add(user)
                print(f"   ✅ Added user: {user_data['username']}")
            else:
                print(f"   ⚠️  User already exists: {user_data['username']}")
        
        db.commit()
        
        # Migrate Dashboards/Tableros  
        print("📊 Migrating dashboards...")
        for dashboard_data in data.get("tableros", []):
            existing_dashboard = db.query(Dashboard).filter(Dashboard.id == dashboard_data["id"]).first()
            if not existing_dashboard:
                dashboard = Dashboard(
                    id=dashboard_data["id"],
                    titulo=dashboard_data["titulo"],
                    url_acceso=dashboard_data["url_acceso"],
                    categoria=dashboard_data["categoria"],
                    subcategoria=dashboard_data.get("subcategoria", ""),
                    descripcion=dashboard_data.get("descripcion", ""),
                    url_imagen_preview=dashboard_data.get("url_imagen_preview", ""),
                    created_by=1  # Assuming first user (admin)
                )
                db.add(dashboard)
                print(f"   ✅ Added dashboard: {dashboard_data['titulo']}")
            else:
                print(f"   ⚠️  Dashboard already exists: {dashboard_data['titulo']}")
        
        db.commit()
        
        # Add sample employees if none exist
        print("👨‍💼 Adding sample employees...")
        existing_employees = db.query(Employee).count()
        if existing_employees == 0:
            sample_employees = [
                {
                    "first_name": "Mario",
                    "last_name": "Gonzalez",
                    "email": "mario.gonzalez@bidashboard.com",
                    "phone": "+1-555-0101",
                    "department": "IT",
                    "position": "System Administrator",
                    "salary": 75000,
                    "hire_date": datetime(2024, 1, 15),
                    "status": "active"
                },
                {
                    "first_name": "Ana",
                    "last_name": "Rodriguez",
                    "email": "ana.rodriguez@bidashboard.com", 
                    "phone": "+1-555-0102",
                    "department": "Operations",
                    "position": "Operations Manager",
                    "salary": 80000,
                    "hire_date": datetime(2023, 6, 1),
                    "status": "active"
                },
                {
                    "first_name": "Carlos",
                    "last_name": "Martinez",
                    "email": "carlos.martinez@bidashboard.com",
                    "phone": "+1-555-0103", 
                    "department": "Finance",
                    "position": "Financial Analyst",
                    "salary": 65000,
                    "hire_date": datetime(2024, 3, 10),
                    "status": "active"
                }
            ]
            
            for emp_data in sample_employees:
                employee = Employee(**emp_data, created_by=1)
                db.add(employee)
                print(f"   ✅ Added employee: {emp_data['first_name']} {emp_data['last_name']}")
            
            db.commit()
        else:
            print(f"   ⚠️  {existing_employees} employees already exist")
        
        print("✅ Migration completed successfully!")
        
        # Print summary
        user_count = db.query(User).count()
        dashboard_count = db.query(Dashboard).count()
        employee_count = db.query(Employee).count()
        
        print(f"""
📊 Migration Summary:
   👥 Users: {user_count}
   📊 Dashboards: {dashboard_count}
   👨‍💼 Employees: {employee_count}

🔐 Database Credentials:
   Host: localhost
   Port: 5432
   Database: bidashboard
   Username: mario_gonzalez
   Password: Mario2024!

🌐 Application URLs:
   Frontend: http://localhost:4201
   Backend: http://localhost:8000
   API Docs: http://localhost:8000/docs
        """)
        
        return True
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        db.rollback()
        return False
    finally:
        db.close()

if __name__ == "__main__":
    success = migrate_data()
    if success:
        print("🎉 Database migration completed successfully!")
        print("   You can now update your FastAPI application to use PostgreSQL")
    else:
        print("💥 Migration failed. Please check the errors above.")