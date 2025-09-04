"""
Database Configuration Manager for BIDashboard
Supports both PostgreSQL (development) and SQL Server (production)
"""

import os
from typing import Tuple, Generator
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.exc import SQLAlchemyError

# Database type selection
DATABASE_TYPE = os.getenv("DATABASE_TYPE", "sqlite").lower()  # sqlite, postgresql or mssql

class DatabaseConfig:
    def __init__(self):
        self.database_type = DATABASE_TYPE
        self.engine = None
        self.SessionLocal = None
        self.models = None
        self._setup_database()
    
    def _setup_database(self):
        """Setup database connection and models based on DATABASE_TYPE"""
        try:
            if self.database_type == "mssql":
                self._setup_mssql()
            elif self.database_type == "sqlite":
                self._setup_sqlite()
            else:
                self._setup_postgresql()
                
            print(f"✅ Database configured: {self.database_type.upper()}")
        except Exception as e:
            print(f"❌ Error setting up {self.database_type}: {e}")
            if self.database_type == "mssql":
                print("🔄 Falling back to PostgreSQL...")
                self.database_type = "postgresql"
                self._setup_postgresql()
            elif self.database_type == "postgresql":
                print("🔄 Falling back to SQLite...")
                self.database_type = "sqlite"
                self._setup_sqlite()
    
    def _setup_sqlite(self):
        """Setup SQLite connection and models"""
        try:
            from database_sqlite import engine, SessionLocal
            from database_sqlite import User, Dashboard, Employee
            
            self.engine = engine
            self.SessionLocal = SessionLocal
            self.models = {
                'User': User,
                'Dashboard': Dashboard, 
                'Employee': Employee
            }
            
            # Initialize database with tables and default users
            from database_sqlite import init_database
            init_database()
                
        except ImportError as e:
            raise Exception(f"SQLite modules not found: {e}")
        except Exception as e:
            raise Exception(f"SQLite setup failed: {e}")
    
    def _setup_postgresql(self):
        """Setup PostgreSQL connection and models"""
        try:
            from database_postgres import engine, SessionLocal
            from database_postgres import User, Dashboard, Employee
            
            self.engine = engine
            self.SessionLocal = SessionLocal
            self.models = {
                'User': User,
                'Dashboard': Dashboard, 
                'Employee': Employee
            }
            
            # Test connection
            with SessionLocal() as db:
                db.execute(text("SELECT 1"))
                
        except ImportError as e:
            raise Exception(f"PostgreSQL modules not found: {e}")
        except Exception as e:
            raise Exception(f"PostgreSQL connection failed: {e}")
    
    def _setup_mssql(self):
        """Setup SQL Server connection and models"""
        try:
            from database_mssql import engine, SessionLocal
            from database_mssql import User, Dashboard, Employee, Category, Department
            
            self.engine = engine
            self.SessionLocal = SessionLocal
            self.models = {
                'User': User,
                'Dashboard': Dashboard,
                'Employee': Employee,
                'Category': Category,
                'Department': Department
            }
            
            # Test connection
            with SessionLocal() as db:
                db.execute(text("SELECT 1"))
                
        except ImportError as e:
            raise Exception(f"SQL Server modules not found: {e}")
        except Exception as e:
            raise Exception(f"SQL Server connection failed: {e}")
    
    def get_db(self) -> Generator[Session, None, None]:
        """Database dependency for FastAPI"""
        if not self.SessionLocal:
            raise Exception("Database not properly configured")
            
        db = self.SessionLocal()
        try:
            yield db
        finally:
            db.close()
    
    def get_model(self, model_name: str):
        """Get model class by name"""
        if not self.models or model_name not in self.models:
            raise Exception(f"Model '{model_name}' not found for {self.database_type}")
        return self.models[model_name]
    
    def test_connection(self) -> bool:
        """Test current database connection"""
        try:
            if not self.SessionLocal:
                return False
                
            with self.SessionLocal() as db:
                db.execute(text("SELECT 1"))
            return True
        except Exception as e:
            print(f"Connection test failed: {e}")
            return False
    
    def get_connection_info(self) -> dict:
        """Get current database connection information"""
        info = {
            'database_type': self.database_type,
            'connected': self.test_connection()
        }
        
        if self.database_type == "mssql":
            info.update({
                'server': os.getenv("DB_SERVER", "localhost"),
                'database': os.getenv("DB_NAME", "BIDashboard"),
                'username': os.getenv("DB_USERNAME", "mario_gonzalez")
            })
        else:
            info.update({
                'host': os.getenv("POSTGRES_HOST", "localhost"),
                'database': os.getenv("POSTGRES_DB", "bidashboard"),
                'username': os.getenv("POSTGRES_USER", "mario_gonzalez")
            })
        
        return info

# Global database configuration instance
db_config = DatabaseConfig()

# Convenience functions for backward compatibility
def get_db() -> Generator[Session, None, None]:
    """Database dependency for FastAPI"""
    yield from db_config.get_db()

def get_user_model():
    """Get User model for current database"""
    return db_config.get_model('User')

def get_dashboard_model():
    """Get Dashboard model for current database"""
    return db_config.get_model('Dashboard')

def get_employee_model():
    """Get Employee model for current database"""
    return db_config.get_model('Employee')

# Export current database info
DATABASE_INFO = db_config.get_connection_info()

if __name__ == "__main__":
    print("🔄 Testing Database Configuration...")
    print(f"📊 Database Type: {DATABASE_INFO['database_type'].upper()}")
    print(f"🔌 Connection Status: {'✅ Connected' if DATABASE_INFO['connected'] else '❌ Disconnected'}")
    print(f"📋 Connection Details:")
    for key, value in DATABASE_INFO.items():
        if key not in ['database_type', 'connected']:
            print(f"   {key}: {value}")
    
    print(f"\n🎯 Available Models:")
    for model_name in db_config.models.keys():
        print(f"   - {model_name}")
        
    print(f"\n🚀 Ready for FastAPI integration!")