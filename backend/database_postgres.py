"""
BIDashboard PostgreSQL Database Configuration
Author: Database Architect
Date: 2025-09-03
Description: PostgreSQL database connection and models for FastAPI
"""

import os
from sqlalchemy import create_engine, Column, Integer, String, Boolean, DateTime, Text, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.sql import func
from typing import Generator
from dotenv import load_dotenv
import logging

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database URL
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://mario_gonzalez:Mario2024!@localhost:5432/bidashboard")

# Create SQLAlchemy engine
engine = create_engine(
    DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,
    echo=False
)

# Create SessionLocal class
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create Base class
Base = declarative_base()

# Database Models
class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
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
    created_by = Column(Integer, nullable=True)  # FK to users
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
    salary = Column(Integer, nullable=False)  # Store as cents to avoid float issues
    hire_date = Column(DateTime(timezone=True), nullable=False)
    status = Column(String(20), default='active', index=True)  # active, inactive
    created_by = Column(Integer, nullable=True)  # FK to users
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

# Database connection management
def get_db() -> Generator[Session, None, None]:
    """
    Dependency that creates a database session and closes it when done.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def init_database():
    """
    Create database tables and initialize with sample data.
    """
    try:
        # Create all tables
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables created successfully")
        
        # Check if we need to initialize data
        db = SessionLocal()
        try:
            # Check if admin user exists
            admin_user = db.query(User).filter(User.username == "mario_gonzalez").first()
            if not admin_user:
                logger.info("Initializing database with default data")
                # This will be handled by the migration script
                pass
        finally:
            db.close()
            
    except Exception as e:
        logger.error(f"Error initializing database: {e}")
        raise

def test_connection():
    """
    Test database connection.
    """
    try:
        db = SessionLocal()
        try:
            # Test query
            result = db.execute(text("SELECT 1")).scalar()
            logger.info(f"Database connection successful: {result}")
            return True
        finally:
            db.close()
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        return False

if __name__ == "__main__":
    # Test connection and initialize database
    if test_connection():
        init_database()
        print("✅ Database setup completed successfully!")
        print(f"📊 Database URL: {DATABASE_URL}")
        print("🔐 Mario Gonzalez credentials:")
        print("   Username: mario_gonzalez")
        print("   Password: Mario2024!")
    else:
        print("❌ Database connection failed!")