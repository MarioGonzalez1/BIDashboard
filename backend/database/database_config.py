"""
BIDashboard Database Configuration and Connection Manager
Author: Senior Database Architect
Date: 2025-09-03
Description: SQL Server database connection management for FastAPI
"""

import os
import pyodbc
from typing import Optional, Dict, Any, List
from contextlib import contextmanager
from sqlalchemy import create_engine, MetaData, text
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import NullPool
from dotenv import load_dotenv
import logging

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DatabaseConfig:
    """Database configuration management"""
    
    def __init__(self):
        # SQL Server connection parameters from environment
        self.server = os.getenv('DB_SERVER', 'localhost')
        self.database = os.getenv('DB_NAME', 'BIDashboard')
        self.username = os.getenv('DB_USERNAME', 'sa')
        self.password = os.getenv('DB_PASSWORD', '')
        self.driver = os.getenv('DB_DRIVER', 'ODBC Driver 17 for SQL Server')
        self.port = os.getenv('DB_PORT', '1433')
        
        # Connection pool settings
        self.pool_size = int(os.getenv('DB_POOL_SIZE', '10'))
        self.max_overflow = int(os.getenv('DB_MAX_OVERFLOW', '20'))
        self.pool_timeout = int(os.getenv('DB_POOL_TIMEOUT', '30'))
        self.pool_recycle = int(os.getenv('DB_POOL_RECYCLE', '3600'))
        
        # Application settings
        self.echo_sql = os.getenv('DB_ECHO_SQL', 'False').lower() == 'true'
        self.autocommit = os.getenv('DB_AUTOCOMMIT', 'False').lower() == 'true'
        
    @property
    def connection_string(self) -> str:
        """Generate SQL Server connection string"""
        return (
            f"mssql+pyodbc://{self.username}:{self.password}@"
            f"{self.server}:{self.port}/{self.database}"
            f"?driver={self.driver.replace(' ', '+')}"
            "&TrustServerCertificate=yes"
            "&Encrypt=yes"
            "&Connection+Timeout=30"
        )
    
    @property
    def pyodbc_connection_string(self) -> str:
        """Generate pyodbc connection string for direct connections"""
        return (
            f"DRIVER={{{self.driver}}};"
            f"SERVER={self.server},{self.port};"
            f"DATABASE={self.database};"
            f"UID={self.username};"
            f"PWD={self.password};"
            f"TrustServerCertificate=yes;"
            f"Encrypt=yes;"
        )


class DatabaseManager:
    """Database connection and session management"""
    
    def __init__(self, config: DatabaseConfig = None):
        self.config = config or DatabaseConfig()
        self._engine = None
        self._session_factory = None
        self.metadata = MetaData()
        
    @property
    def engine(self):
        """Lazy initialization of database engine"""
        if self._engine is None:
            self._engine = create_engine(
                self.config.connection_string,
                echo=self.config.echo_sql,
                pool_size=self.config.pool_size,
                max_overflow=self.config.max_overflow,
                pool_timeout=self.config.pool_timeout,
                pool_recycle=self.config.pool_recycle,
                pool_pre_ping=True,  # Verify connections before using
                connect_args={
                    "check_same_thread": False,  # For SQLite compatibility
                    "connect_timeout": 30,
                }
            )
            logger.info("Database engine created successfully")
        return self._engine
    
    @property
    def session_factory(self):
        """Lazy initialization of session factory"""
        if self._session_factory is None:
            self._session_factory = sessionmaker(
                bind=self.engine,
                autocommit=self.config.autocommit,
                autoflush=False,
                expire_on_commit=False
            )
            logger.info("Session factory created successfully")
        return self._session_factory
    
    def get_session(self) -> Session:
        """Get a new database session"""
        return self.session_factory()
    
    @contextmanager
    def session_scope(self):
        """Provide a transactional scope for database operations"""
        session = self.get_session()
        try:
            yield session
            session.commit()
        except Exception as e:
            session.rollback()
            logger.error(f"Database session error: {str(e)}")
            raise
        finally:
            session.close()
    
    def execute_query(self, query: str, params: Dict[str, Any] = None) -> List[Dict]:
        """Execute a raw SQL query and return results"""
        with self.session_scope() as session:
            result = session.execute(text(query), params or {})
            if result.returns_rows:
                return [dict(row) for row in result]
            return []
    
    def execute_stored_procedure(self, proc_name: str, params: Dict[str, Any] = None) -> List[Dict]:
        """Execute a stored procedure"""
        params_str = ', '.join([f"@{k}=:{k}" for k in (params or {}).keys()])
        query = f"EXEC {proc_name} {params_str}"
        return self.execute_query(query, params)
    
    def test_connection(self) -> bool:
        """Test database connection"""
        try:
            with self.engine.connect() as conn:
                result = conn.execute(text("SELECT 1"))
                logger.info("Database connection test successful")
                return True
        except Exception as e:
            logger.error(f"Database connection test failed: {str(e)}")
            return False
    
    def dispose(self):
        """Dispose of the engine and close all connections"""
        if self._engine:
            self._engine.dispose()
            logger.info("Database engine disposed")


# Global database manager instance
db_manager = DatabaseManager()


# Dependency for FastAPI
def get_db() -> Session:
    """FastAPI dependency for database sessions"""
    db = db_manager.get_session()
    try:
        yield db
    finally:
        db.close()


# Direct pyodbc connection for complex operations
@contextmanager
def get_pyodbc_connection():
    """Get a direct pyodbc connection for complex operations"""
    config = DatabaseConfig()
    conn = None
    try:
        conn = pyodbc.connect(config.pyodbc_connection_string)
        yield conn
    except Exception as e:
        logger.error(f"PyODBC connection error: {str(e)}")
        raise
    finally:
        if conn:
            conn.close()


# Utility functions for common database operations
class DatabaseUtils:
    """Utility functions for database operations"""
    
    @staticmethod
    def bulk_insert(table_name: str, data: List[Dict], schema: str = 'dbo'):
        """Perform bulk insert operation"""
        if not data:
            return
        
        columns = list(data[0].keys())
        placeholders = ', '.join(['?' for _ in columns])
        columns_str = ', '.join(columns)
        
        query = f"""
            INSERT INTO [{schema}].[{table_name}] ({columns_str})
            VALUES ({placeholders})
        """
        
        with get_pyodbc_connection() as conn:
            cursor = conn.cursor()
            cursor.fast_executemany = True
            values = [[row.get(col) for col in columns] for row in data]
            cursor.executemany(query, values)
            conn.commit()
            logger.info(f"Bulk inserted {len(data)} rows into {schema}.{table_name}")
    
    @staticmethod
    def check_table_exists(table_name: str, schema: str = 'dbo') -> bool:
        """Check if a table exists in the database"""
        query = """
            SELECT COUNT(*) as count
            FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = :schema AND TABLE_NAME = :table_name
        """
        result = db_manager.execute_query(query, {'schema': schema, 'table_name': table_name})
        return result[0]['count'] > 0 if result else False
    
    @staticmethod
    def get_table_row_count(table_name: str, schema: str = 'dbo') -> int:
        """Get the row count of a table"""
        query = f"SELECT COUNT(*) as count FROM [{schema}].[{table_name}]"
        result = db_manager.execute_query(query)
        return result[0]['count'] if result else 0
    
    @staticmethod
    def truncate_table(table_name: str, schema: str = 'dbo'):
        """Truncate a table (delete all rows)"""
        query = f"TRUNCATE TABLE [{schema}].[{table_name}]"
        with db_manager.session_scope() as session:
            session.execute(text(query))
            logger.info(f"Truncated table {schema}.{table_name}")


# Connection pool monitoring
class ConnectionPoolMonitor:
    """Monitor database connection pool status"""
    
    @staticmethod
    def get_pool_status() -> Dict[str, Any]:
        """Get current connection pool status"""
        if db_manager._engine:
            pool = db_manager.engine.pool
            return {
                'size': pool.size(),
                'checked_in': pool.checkedin(),
                'checked_out': pool.checkedout(),
                'overflow': pool.overflow(),
                'total': pool.checkedin() + pool.checkedout()
            }
        return {}
    
    @staticmethod
    def log_pool_status():
        """Log current connection pool status"""
        status = ConnectionPoolMonitor.get_pool_status()
        if status:
            logger.info(f"Connection Pool Status: {status}")


# Error handling
class DatabaseError(Exception):
    """Custom database error class"""
    pass


class ConnectionError(DatabaseError):
    """Database connection error"""
    pass


class QueryError(DatabaseError):
    """Query execution error"""
    pass


# Health check
def health_check() -> Dict[str, Any]:
    """Perform database health check"""
    health_status = {
        'database': 'unknown',
        'connection': False,
        'pool_status': {},
        'tables_count': 0,
        'error': None
    }
    
    try:
        # Test connection
        if db_manager.test_connection():
            health_status['connection'] = True
            health_status['database'] = 'healthy'
            
            # Get pool status
            health_status['pool_status'] = ConnectionPoolMonitor.get_pool_status()
            
            # Count tables
            query = """
                SELECT COUNT(*) as count
                FROM INFORMATION_SCHEMA.TABLES
                WHERE TABLE_TYPE = 'BASE TABLE'
            """
            result = db_manager.execute_query(query)
            health_status['tables_count'] = result[0]['count'] if result else 0
        else:
            health_status['database'] = 'unhealthy'
            health_status['error'] = 'Connection test failed'
    except Exception as e:
        health_status['database'] = 'error'
        health_status['error'] = str(e)
    
    return health_status


if __name__ == "__main__":
    # Test database connection
    print("Testing database connection...")
    print(f"Health Check: {health_check()}")