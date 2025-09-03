"""
SQL Server Database Models and Connection for BIDashboard
Matches the schema created in the SQL Server deployment scripts
"""

import os
from sqlalchemy import create_engine, Column, Integer, String, DateTime, Text, Boolean, Numeric, ForeignKey, Index, text
from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship
from sqlalchemy.sql import func
from datetime import datetime
from typing import Generator

# Database Configuration
DB_SERVER = os.getenv("DB_SERVER", "localhost")
DB_NAME = os.getenv("DB_NAME", "BIDashboard") 
DB_USERNAME = os.getenv("DB_USERNAME", "mario_gonzalez")
DB_PASSWORD = os.getenv("DB_PASSWORD", "Mario2024!BIDashboard@MSSQL")
DB_PORT = os.getenv("DB_PORT", "1433")

# Connection string for SQL Server
DATABASE_URL = f"mssql+pymssql://{DB_USERNAME}:{DB_PASSWORD}@{DB_SERVER}:{DB_PORT}/{DB_NAME}"

# Create engine with connection pooling
engine = create_engine(
    DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    pool_timeout=30,
    pool_recycle=1800,  # 30 minutes
    echo=False  # Set to True for SQL debugging
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# =================================================================
# SECURITY SCHEMA MODELS
# =================================================================

class User(Base):
    __tablename__ = "Users"
    __table_args__ = {'schema': 'Security'}
    
    UserID = Column(Integer, primary_key=True, autoincrement=True)
    Username = Column(String(100), unique=True, nullable=False)
    EmailAddress = Column(String(255), unique=True, nullable=False)
    FirstName = Column(String(100), nullable=False)
    LastName = Column(String(100), nullable=False)
    PasswordHash = Column(String(255), nullable=False)
    IsAdmin = Column(Boolean, default=False)
    IsActive = Column(Boolean, default=True)
    CreatedDate = Column(DateTime, default=func.getutcdate())
    LastLoginDate = Column(DateTime)
    FailedLoginAttempts = Column(Integer, default=0)
    CreatedBy = Column(Integer)
    ModifiedBy = Column(Integer)
    ModifiedDate = Column(DateTime)
    
    # Relationships
    created_dashboards = relationship("Dashboard", foreign_keys="Dashboard.CreatedBy", back_populates="creator")
    created_employees = relationship("Employee", foreign_keys="Employee.CreatedBy", back_populates="creator")

class UserSession(Base):
    __tablename__ = "UserSessions"
    __table_args__ = {'schema': 'Security'}
    
    SessionID = Column(Integer, primary_key=True, autoincrement=True)
    UserID = Column(Integer, ForeignKey('Security.Users.UserID'), nullable=False)
    TokenHash = Column(String(255), nullable=False)
    ExpiryDate = Column(DateTime, nullable=False)
    IsActive = Column(Boolean, default=True)
    CreatedDate = Column(DateTime, default=func.getutcdate())
    IPAddress = Column(String(45))
    UserAgent = Column(String(500))

# =================================================================
# DASHBOARD SCHEMA MODELS
# =================================================================

class Category(Base):
    __tablename__ = "Categories"
    __table_args__ = {'schema': 'Dashboard'}
    
    CategoryID = Column(Integer, primary_key=True, autoincrement=True)
    CategoryName = Column(String(100), nullable=False)
    Description = Column(Text)
    IsActive = Column(Boolean, default=True)
    CreatedDate = Column(DateTime, default=func.getutcdate())
    CreatedBy = Column(Integer)
    ModifiedBy = Column(Integer)
    ModifiedDate = Column(DateTime)
    
    # Relationships
    dashboards = relationship("Dashboard", back_populates="category")
    subcategories = relationship("Subcategory", back_populates="category")

class Subcategory(Base):
    __tablename__ = "Subcategories"
    __table_args__ = {'schema': 'Dashboard'}
    
    SubcategoryID = Column(Integer, primary_key=True, autoincrement=True)
    CategoryID = Column(Integer, ForeignKey('Dashboard.Categories.CategoryID'), nullable=False)
    SubcategoryName = Column(String(100), nullable=False)
    Description = Column(Text)
    IsActive = Column(Boolean, default=True)
    CreatedDate = Column(DateTime, default=func.getutcdate())
    CreatedBy = Column(Integer)
    ModifiedBy = Column(Integer)
    ModifiedDate = Column(DateTime)
    
    # Relationships
    category = relationship("Category", back_populates="subcategories")
    dashboards = relationship("Dashboard", back_populates="subcategory")

class Dashboard(Base):
    __tablename__ = "Dashboards"
    __table_args__ = {'schema': 'Dashboard'}
    
    DashboardID = Column(Integer, primary_key=True, autoincrement=True)
    Title = Column(String(200), nullable=False)
    Description = Column(Text)
    AccessURL = Column(String(500), nullable=False)
    PreviewImagePath = Column(String(500))
    CategoryID = Column(Integer, ForeignKey('Dashboard.Categories.CategoryID'))
    SubcategoryID = Column(Integer, ForeignKey('Dashboard.Subcategories.SubcategoryID'))
    IsPublic = Column(Boolean, default=True)
    IsActive = Column(Boolean, default=True)
    CreatedBy = Column(Integer, ForeignKey('Security.Users.UserID'), nullable=False)
    CreatedDate = Column(DateTime, default=func.getutcdate())
    ModifiedBy = Column(Integer)
    ModifiedDate = Column(DateTime)
    ViewCount = Column(Integer, default=0)
    LastAccessedDate = Column(DateTime)
    
    # Relationships
    creator = relationship("User", foreign_keys=[CreatedBy], back_populates="created_dashboards")
    category = relationship("Category", back_populates="dashboards")
    subcategory = relationship("Subcategory", back_populates="dashboards")
    analytics = relationship("DashboardAnalytic", back_populates="dashboard")

class DashboardAnalytic(Base):
    __tablename__ = "DashboardAnalytics"
    __table_args__ = {'schema': 'Dashboard'}
    
    AnalyticsID = Column(Integer, primary_key=True, autoincrement=True)
    DashboardID = Column(Integer, ForeignKey('Dashboard.Dashboards.DashboardID'), nullable=False)
    UserID = Column(Integer, ForeignKey('Security.Users.UserID'), nullable=False)
    AccessDate = Column(DateTime, default=func.getutcdate())
    SessionDuration = Column(Integer)  # in seconds
    IPAddress = Column(String(45))
    UserAgent = Column(String(500))
    
    # Relationships
    dashboard = relationship("Dashboard", back_populates="analytics")

# =================================================================
# HR SCHEMA MODELS
# =================================================================

class Department(Base):
    __tablename__ = "Departments"
    __table_args__ = {'schema': 'HR'}
    
    DepartmentID = Column(Integer, primary_key=True, autoincrement=True)
    DepartmentName = Column(String(100), nullable=False)
    Description = Column(Text)
    ManagerID = Column(Integer)
    BudgetAllocation = Column(Numeric(15, 2))
    IsActive = Column(Boolean, default=True)
    CreatedDate = Column(DateTime, default=func.getutcdate())
    CreatedBy = Column(Integer)
    ModifiedBy = Column(Integer)
    ModifiedDate = Column(DateTime)
    
    # Relationships
    employees = relationship("Employee", back_populates="department")

class Position(Base):
    __tablename__ = "Positions"
    __table_args__ = {'schema': 'HR'}
    
    PositionID = Column(Integer, primary_key=True, autoincrement=True)
    PositionTitle = Column(String(100), nullable=False)
    Description = Column(Text)
    SalaryRangeMin = Column(Numeric(15, 2))
    SalaryRangeMax = Column(Numeric(15, 2))
    RequiredSkills = Column(Text)
    IsActive = Column(Boolean, default=True)
    CreatedDate = Column(DateTime, default=func.getutcdate())
    CreatedBy = Column(Integer)
    ModifiedBy = Column(Integer)
    ModifiedDate = Column(DateTime)
    
    # Relationships
    employees = relationship("Employee", back_populates="position")

class Employee(Base):
    __tablename__ = "Employees"
    __table_args__ = {'schema': 'HR'}
    
    EmployeeID = Column(Integer, primary_key=True, autoincrement=True)
    EmployeeNumber = Column(String(20), unique=True, nullable=False)
    FirstName = Column(String(100), nullable=False)
    LastName = Column(String(100), nullable=False)
    EmailAddress = Column(String(255), unique=True, nullable=False)
    PhoneNumber = Column(String(20))
    DepartmentID = Column(Integer, ForeignKey('HR.Departments.DepartmentID'))
    PositionID = Column(Integer, ForeignKey('HR.Positions.PositionID'))
    HireDate = Column(DateTime, nullable=False)
    Salary = Column(Numeric(15, 2))
    EmploymentStatus = Column(String(20), default='Active')  # Active, Inactive, Terminated
    ManagerID = Column(Integer)
    IsActive = Column(Boolean, default=True)
    CreatedDate = Column(DateTime, default=func.getutcdate())
    CreatedBy = Column(Integer, ForeignKey('Security.Users.UserID'))
    ModifiedBy = Column(Integer)
    ModifiedDate = Column(DateTime)
    
    # Relationships
    creator = relationship("User", foreign_keys=[CreatedBy], back_populates="created_employees")
    department = relationship("Department", back_populates="employees")
    position = relationship("Position", back_populates="employees")

# =================================================================
# AUDIT SCHEMA MODELS
# =================================================================

class AuditLog(Base):
    __tablename__ = "AuditLog"
    __table_args__ = {'schema': 'Audit'}
    
    AuditID = Column(Integer, primary_key=True, autoincrement=True)
    TableName = Column(String(100), nullable=False)
    RecordID = Column(Integer, nullable=False)
    Operation = Column(String(10), nullable=False)  # INSERT, UPDATE, DELETE
    OldValues = Column(Text)  # JSON format
    NewValues = Column(Text)  # JSON format
    ChangedBy = Column(Integer, nullable=False)
    ChangedDate = Column(DateTime, default=func.getutcdate())

class SystemEvent(Base):
    __tablename__ = "SystemEvents"
    __table_args__ = {'schema': 'Audit'}
    
    EventID = Column(Integer, primary_key=True, autoincrement=True)
    EventType = Column(String(50), nullable=False)
    EventDescription = Column(Text, nullable=False)
    Severity = Column(String(20), default='Info')  # Info, Warning, Error, Critical
    UserID = Column(Integer)
    IPAddress = Column(String(45))
    CreatedDate = Column(DateTime, default=func.getutcdate())
    AdditionalData = Column(Text)  # JSON format

# =================================================================
# CONFIG SCHEMA MODELS
# =================================================================

class AppSetting(Base):
    __tablename__ = "AppSettings"
    __table_args__ = {'schema': 'Config'}
    
    SettingID = Column(Integer, primary_key=True, autoincrement=True)
    SettingKey = Column(String(100), unique=True, nullable=False)
    SettingValue = Column(Text, nullable=False)
    Description = Column(Text)
    DataType = Column(String(20), default='String')  # String, Integer, Boolean, JSON
    IsEncrypted = Column(Boolean, default=False)
    CreatedDate = Column(DateTime, default=func.getutcdate())
    ModifiedDate = Column(DateTime)
    CreatedBy = Column(Integer)
    ModifiedBy = Column(Integer)

# =================================================================
# DATABASE CONNECTION FUNCTIONS
# =================================================================

def get_db() -> Generator[Session, None, None]:
    """
    Database dependency for FastAPI
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def test_connection() -> bool:
    """
    Test database connection
    """
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
        return True
    except Exception as e:
        print(f"Database connection failed: {e}")
        return False

def create_tables():
    """
    Create all tables (only if they don't exist)
    Note: In production, use the SQL scripts provided
    """
    try:
        Base.metadata.create_all(bind=engine)
        print("✅ All tables created successfully")
    except Exception as e:
        print(f"❌ Error creating tables: {e}")

if __name__ == "__main__":
    # Test connection
    print("🔄 Testing SQL Server connection...")
    if test_connection():
        print("✅ SQL Server connection successful!")
        print(f"📊 Connected to: {DB_SERVER}/{DB_NAME}")
        print(f"👤 User: {DB_USERNAME}")
    else:
        print("❌ SQL Server connection failed!")
        print("Make sure SQL Server is running and credentials are correct")