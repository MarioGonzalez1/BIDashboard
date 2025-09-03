"""
BIDashboard JSON to SQL Server Migration Script
Author: Senior Database Architect
Date: 2025-09-03
Description: Migrate data from JSON files to SQL Server database
"""

import json
import os
import sys
from datetime import datetime
from typing import Dict, List, Any
import pyodbc
from pathlib import Path
import logging
import argparse
from database_config import DatabaseConfig, get_pyodbc_connection, DatabaseUtils

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DataMigration:
    """Handle data migration from JSON to SQL Server"""
    
    def __init__(self, json_file_path: str = '../db.json'):
        self.json_file_path = json_file_path
        self.data = self._load_json_data()
        self.config = DatabaseConfig()
        
    def _load_json_data(self) -> Dict:
        """Load data from JSON file"""
        try:
            with open(self.json_file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                logger.info(f"Loaded JSON data from {self.json_file_path}")
                return data
        except FileNotFoundError:
            logger.error(f"JSON file not found: {self.json_file_path}")
            raise
        except json.JSONDecodeError as e:
            logger.error(f"Error decoding JSON: {e}")
            raise
    
    def migrate_users(self, conn: pyodbc.Connection):
        """Migrate users from JSON to database"""
        cursor = conn.cursor()
        users = self.data.get('users', [])
        
        logger.info(f"Migrating {len(users)} users...")
        
        for user in users:
            try:
                # Check if user exists
                cursor.execute("""
                    SELECT UserID FROM [Security].[Users] 
                    WHERE Username = ?
                """, user['username'])
                
                if cursor.fetchone():
                    logger.info(f"User {user['username']} already exists, skipping...")
                    continue
                
                # Insert user
                cursor.execute("""
                    INSERT INTO [Security].[Users] (
                        Username, Email, PasswordHash, PasswordSalt,
                        FirstName, LastName, DisplayName,
                        IsEmailVerified, IsActive, CreatedBy
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    user['username'],
                    user.get('email', f"{user['username']}@company.com"),
                    user['hashed_password'],
                    '$2b$12$salt',  # Default salt for bcrypt
                    user.get('first_name', user['username']),
                    user.get('last_name', ''),
                    user.get('display_name', user['username']),
                    1,  # IsEmailVerified
                    1,  # IsActive
                    1   # CreatedBy (system)
                ))
                
                user_id = cursor.execute("SELECT @@IDENTITY").fetchone()[0]
                
                # Assign role based on is_admin flag
                role_name = 'Admin' if user.get('is_admin', False) else 'User'
                cursor.execute("""
                    INSERT INTO [Security].[UserRoles] (UserID, RoleID, AssignedBy)
                    SELECT ?, RoleID, 1
                    FROM [Security].[Roles]
                    WHERE RoleName = ?
                """, (user_id, role_name))
                
                logger.info(f"Migrated user: {user['username']}")
                
            except Exception as e:
                logger.error(f"Error migrating user {user['username']}: {e}")
                raise
        
        conn.commit()
        logger.info("Users migration completed")
    
    def migrate_dashboards(self, conn: pyodbc.Connection):
        """Migrate dashboards (tableros) from JSON to database"""
        cursor = conn.cursor()
        dashboards = self.data.get('tableros', [])
        
        logger.info(f"Migrating {len(dashboards)} dashboards...")
        
        # Get or create category mappings
        category_map = self._get_or_create_categories(cursor)
        
        # Get default user for CreatedBy
        cursor.execute("SELECT TOP 1 UserID FROM [Security].[Users]")
        default_user_id = cursor.fetchone()[0]
        
        for dashboard in dashboards:
            try:
                # Check if dashboard exists
                cursor.execute("""
                    SELECT DashboardID FROM [Dashboard].[Dashboards]
                    WHERE DashboardTitle = ?
                """, dashboard['titulo'])
                
                if cursor.fetchone():
                    logger.info(f"Dashboard '{dashboard['titulo']}' already exists, skipping...")
                    continue
                
                # Get category ID
                category_id = category_map.get(
                    dashboard.get('categoria', 'General').lower(),
                    category_map.get('general', 1)
                )
                
                # Get subcategory ID if exists
                subcategory_id = None
                if dashboard.get('subcategoria'):
                    subcategory_id = category_map.get(
                        dashboard['subcategoria'].lower()
                    )
                
                # Generate slug from title
                slug = self._generate_slug(dashboard['titulo'])
                
                # Insert dashboard
                cursor.execute("""
                    INSERT INTO [Dashboard].[Dashboards] (
                        DashboardTitle, DashboardSlug, DashboardDescription,
                        CategoryID, SubcategoryID, AccessURL, ThumbnailURL,
                        DashboardType, IsPublic, RequiresAuthentication,
                        CreatedBy, PublishedDate, PublishedBy
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    dashboard['titulo'],
                    slug,
                    dashboard.get('descripcion', ''),
                    category_id,
                    subcategory_id,
                    dashboard['url_acceso'],
                    dashboard.get('url_imagen_preview', ''),
                    'PowerBI',  # Default type
                    1,  # IsPublic
                    1,  # RequiresAuthentication
                    default_user_id,
                    datetime.now(),
                    default_user_id
                ))
                
                logger.info(f"Migrated dashboard: {dashboard['titulo']}")
                
            except Exception as e:
                logger.error(f"Error migrating dashboard {dashboard['titulo']}: {e}")
                raise
        
        conn.commit()
        logger.info("Dashboards migration completed")
    
    def _get_or_create_categories(self, cursor) -> Dict[str, int]:
        """Get existing categories or create them if needed"""
        category_map = {}
        
        # Get existing categories
        cursor.execute("""
            SELECT CategoryID, LOWER(CategoryName) as CategoryName
            FROM [Dashboard].[Categories]
        """)
        
        for row in cursor.fetchall():
            category_map[row.CategoryName] = row.CategoryID
        
        # Categories from JSON data
        categories_in_data = set()
        for dashboard in self.data.get('tableros', []):
            if dashboard.get('categoria'):
                categories_in_data.add(dashboard['categoria'].lower())
            if dashboard.get('subcategoria'):
                categories_in_data.add(dashboard['subcategoria'].lower())
        
        # Create missing categories
        for category_name in categories_in_data:
            if category_name not in category_map:
                slug = self._generate_slug(category_name)
                
                # Check for parent category (for subcategories)
                parent_id = None
                if 'forza' in category_name.lower() or 'force one' in category_name.lower():
                    parent_id = category_map.get('workshop')
                
                cursor.execute("""
                    INSERT INTO [Dashboard].[Categories] (
                        CategoryName, CategorySlug, CategoryDescription,
                        ParentCategoryID, DisplayOrder, CreatedBy
                    ) VALUES (?, ?, ?, ?, ?, ?)
                """, (
                    category_name.title(),
                    slug,
                    f'{category_name.title()} dashboards',
                    parent_id,
                    99,  # Default order
                    1    # System user
                ))
                
                category_id = cursor.execute("SELECT @@IDENTITY").fetchone()[0]
                category_map[category_name] = category_id
                logger.info(f"Created category: {category_name.title()}")
        
        return category_map
    
    def _generate_slug(self, text: str) -> str:
        """Generate URL-friendly slug from text"""
        import re
        slug = text.lower()
        slug = re.sub(r'[^\w\s-]', '', slug)
        slug = re.sub(r'[-\s]+', '-', slug)
        return slug.strip('-')
    
    def migrate_sample_employees(self, conn: pyodbc.Connection):
        """Create sample employee data"""
        cursor = conn.cursor()
        
        logger.info("Creating sample employee data...")
        
        # Get department and position IDs
        cursor.execute("SELECT DepartmentID FROM [HR].[Departments] WHERE DepartmentCode = 'IT'")
        it_dept_id = cursor.fetchone()[0]
        
        cursor.execute("SELECT DepartmentID FROM [HR].[Departments] WHERE DepartmentCode = 'OPS'")
        ops_dept_id = cursor.fetchone()[0]
        
        cursor.execute("SELECT PositionID FROM [HR].[Positions] WHERE PositionCode = 'MGR'")
        mgr_position_id = cursor.fetchone()[0]
        
        cursor.execute("SELECT PositionID FROM [HR].[Positions] WHERE PositionCode = 'DEV'")
        dev_position_id = cursor.fetchone()[0]
        
        # Sample employees
        employees = [
            {
                'code': 'EMP001',
                'first': 'John',
                'last': 'Doe',
                'email': 'john.doe@company.com',
                'dept': it_dept_id,
                'position': mgr_position_id,
                'salary': 95000
            },
            {
                'code': 'EMP002',
                'first': 'Jane',
                'last': 'Smith',
                'email': 'jane.smith@company.com',
                'dept': ops_dept_id,
                'position': mgr_position_id,
                'salary': 92000
            },
            {
                'code': 'EMP003',
                'first': 'Mike',
                'last': 'Johnson',
                'email': 'mike.johnson@company.com',
                'dept': it_dept_id,
                'position': dev_position_id,
                'salary': 75000
            }
        ]
        
        for emp in employees:
            try:
                cursor.execute("""
                    IF NOT EXISTS (SELECT 1 FROM [HR].[Employees] WHERE EmployeeCode = ?)
                    INSERT INTO [HR].[Employees] (
                        EmployeeCode, FirstName, LastName, Email,
                        DepartmentID, PositionID, HireDate,
                        EmploymentType, EmploymentStatus, BaseSalary,
                        Currency, CreatedBy
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    emp['code'],  # Check parameter
                    emp['code'],
                    emp['first'],
                    emp['last'],
                    emp['email'],
                    emp['dept'],
                    emp['position'],
                    datetime.now().date(),
                    'Full-time',
                    'Active',
                    emp['salary'],
                    'USD',
                    1
                ))
                logger.info(f"Created employee: {emp['first']} {emp['last']}")
            except Exception as e:
                logger.warning(f"Employee {emp['code']} might already exist: {e}")
        
        conn.commit()
        logger.info("Sample employees created")
    
    def run_migration(self):
        """Run the complete migration process"""
        try:
            with get_pyodbc_connection() as conn:
                logger.info("Starting migration process...")
                
                # Check database connectivity
                cursor = conn.cursor()
                cursor.execute("SELECT DB_NAME()")
                db_name = cursor.fetchone()[0]
                logger.info(f"Connected to database: {db_name}")
                
                # Run migrations in order
                self.migrate_users(conn)
                self.migrate_dashboards(conn)
                self.migrate_sample_employees(conn)
                
                # Verify migration
                cursor.execute("SELECT COUNT(*) FROM [Security].[Users]")
                user_count = cursor.fetchone()[0]
                
                cursor.execute("SELECT COUNT(*) FROM [Dashboard].[Dashboards]")
                dashboard_count = cursor.fetchone()[0]
                
                cursor.execute("SELECT COUNT(*) FROM [HR].[Employees]")
                employee_count = cursor.fetchone()[0]
                
                logger.info(f"""
                Migration Summary:
                - Users: {user_count}
                - Dashboards: {dashboard_count}
                - Employees: {employee_count}
                """)
                
                logger.info("Migration completed successfully!")
                
        except Exception as e:
            logger.error(f"Migration failed: {e}")
            raise


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Migrate JSON data to SQL Server')
    parser.add_argument(
        '--json-file',
        default='../db.json',
        help='Path to JSON file (default: ../db.json)'
    )
    parser.add_argument(
        '--verify-only',
        action='store_true',
        help='Only verify database connection without migrating'
    )
    
    args = parser.parse_args()
    
    if args.verify_only:
        # Test connection only
        try:
            with get_pyodbc_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT DB_NAME()")
                db_name = cursor.fetchone()[0]
                print(f"Successfully connected to database: {db_name}")
                
                # Check if tables exist
                cursor.execute("""
                    SELECT COUNT(*) as count
                    FROM INFORMATION_SCHEMA.TABLES
                    WHERE TABLE_SCHEMA IN ('Security', 'Dashboard', 'HR')
                """)
                table_count = cursor.fetchone()[0]
                print(f"Found {table_count} tables in required schemas")
                
        except Exception as e:
            print(f"Connection failed: {e}")
            sys.exit(1)
    else:
        # Run migration
        migration = DataMigration(args.json_file)
        migration.run_migration()


if __name__ == "__main__":
    main()