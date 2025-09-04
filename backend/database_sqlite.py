"""
BIDashboard SQLite Database Configuration
Simple SQLite database for development and quick setup
"""

import os
from sqlalchemy import create_engine, Column, Integer, String, Boolean, DateTime, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.sql import func
from passlib.context import CryptContext

# Database URL
DATABASE_URL = "sqlite:///./bidashboard.db"

# Create SQLAlchemy engine
engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}  # Only needed for SQLite
)

# Create SessionLocal class
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create Base class
Base = declarative_base()

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Database Models
class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    position = Column(String(150), nullable=True)  # Job title/position
    department = Column(String(100), nullable=True)  # Department/Division
    hashed_password = Column(String(255), nullable=False)
    is_admin = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

class Dashboard(Base):
    __tablename__ = "dashboards"
    
    id = Column(Integer, primary_key=True, index=True)
    titulo = Column(String(200), nullable=False, index=True)
    url_acceso = Column(Text, nullable=False)
    categoria = Column(String(100), nullable=False, index=True)
    subcategoria = Column(String(100), nullable=True)
    descripcion = Column(Text, nullable=True)
    url_imagen_preview = Column(Text, nullable=True)
    created_by = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

class Employee(Base):
    __tablename__ = "employees"
    
    id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    phone = Column(String(20), nullable=True)
    department = Column(String(100), nullable=False, index=True)
    position = Column(String(100), nullable=False)
    salary = Column(Integer, nullable=False)
    hire_date = Column(DateTime(timezone=True), nullable=False)
    status = Column(String(20), default='active', index=True)
    created_by = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

def init_database():
    """Create database tables and add default users"""
    # Create all tables
    Base.metadata.create_all(bind=engine)
    
    # Add default users
    db = SessionLocal()
    try:
        # Check if users exist
        if not db.query(User).first():
            # Create admin user
            admin_password = pwd_context.hash("ChangeMe2024!")
            admin_user = User(
                username="mario.gonzalez",
                email="mario.gonzalez@forzatrans.com",
                first_name="Mario",
                last_name="Gonzalez",
                position="BI Manager",
                department="Business Intelligence",
                hashed_password=admin_password,
                is_admin=True
            )
            db.add(admin_user)
            
            # Create test user
            test_password = pwd_context.hash("test123")
            test_user = User(
                username="testuser",
                email="test.user@forzatrans.com",
                first_name="Test",
                last_name="User",
                position="Data Analyst",
                department="Business Intelligence",
                hashed_password=test_password,
                is_admin=False
            )
            db.add(test_user)
            
            db.commit()
            print("✅ Default users created")
        else:
            print("✅ Database already initialized")
            
    except Exception as e:
        print(f"❌ Error initializing database: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    print("🔧 Initializing SQLite database...")
    init_database()
    print("🎉 SQLite database ready!")
    print("\n📋 Available credentials:")
    print("   👤 Username: mario.gonzalez")
    print("   🔐 Password: ChangeMe2024!")
    print("\n   👤 Username: testuser") 
    print("   🔐 Password: test123")