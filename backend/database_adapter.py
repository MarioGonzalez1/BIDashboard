"""
Database Adapter for BIDashboard
Provides unified interface between PostgreSQL and SQL Server models
"""

from database_config import db_config, DATABASE_INFO

class DatabaseAdapter:
    def __init__(self):
        self.db_type = DATABASE_INFO['database_type']
        self.User = db_config.get_model('User')
        self.Dashboard = db_config.get_model('Dashboard')
        self.Employee = db_config.get_model('Employee')
    
    # User model field mapping
    def get_user_field_mapping(self):
        if self.db_type == 'mssql':
            return {
                'id': 'UserID',
                'username': 'Username',
                'email': 'EmailAddress',
                'first_name': 'FirstName',
                'last_name': 'LastName',
                'position': 'Position',
                'department': 'Department',
                'hashed_password': 'PasswordHash',
                'is_admin': 'IsAdmin',
                'is_active': 'IsActive',
                'created_date': 'CreatedDate',
                'last_login_date': 'LastLoginDate'
            }
        else:  # postgresql and sqlite
            return {
                'id': 'id',
                'username': 'username',
                'email': 'email',
                'first_name': 'first_name',
                'last_name': 'last_name',
                'position': 'position',
                'department': 'department',
                'hashed_password': 'hashed_password',
                'is_admin': 'is_admin',
                'is_active': 'is_active',
                'created_date': 'created_date',
                'last_login_date': 'last_login_date'
            }
    
    # Dashboard model field mapping
    def get_dashboard_field_mapping(self):
        if self.db_type == 'mssql':
            return {
                'id': 'DashboardID',
                'titulo': 'Title',
                'url_acceso': 'AccessURL',
                'categoria': 'CategoryID',  # Need to resolve category name
                'subcategoria': 'SubcategoryID',
                'descripcion': 'Description',
                'url_imagen_preview': 'PreviewImagePath',
                'created_by': 'CreatedBy',
                'created_date': 'CreatedDate'
            }
        else:  # postgresql
            return {
                'id': 'id',
                'titulo': 'titulo',
                'url_acceso': 'url_acceso',
                'categoria': 'categoria',
                'subcategoria': 'subcategoria',
                'descripcion': 'descripcion',
                'url_imagen_preview': 'url_imagen_preview',
                'created_by': 'created_by',
                'created_date': 'created_date'
            }
    
    # Employee model field mapping
    def get_employee_field_mapping(self):
        if self.db_type == 'mssql':
            return {
                'id': 'EmployeeID',
                'first_name': 'FirstName',
                'last_name': 'LastName',
                'email': 'EmailAddress',
                'phone': 'PhoneNumber',
                'department': 'DepartmentID',  # Need to resolve department name
                'position': 'PositionID',
                'salary': 'Salary',
                'hire_date': 'HireDate',
                'status': 'EmploymentStatus',
                'created_by': 'CreatedBy'
            }
        else:  # postgresql
            return {
                'id': 'id',
                'first_name': 'first_name',
                'last_name': 'last_name',
                'email': 'email',
                'phone': 'phone',
                'department': 'department',
                'position': 'position',
                'salary': 'salary',
                'hire_date': 'hire_date',
                'status': 'status',
                'created_by': 'created_by'
            }
    
    def get_user_by_username(self, db, username: str):
        """Get user by username - handles both database types"""
        fields = self.get_user_field_mapping()
        username_field = getattr(self.User, fields['username'])
        return db.query(self.User).filter(username_field == username).first()
    
    def verify_user_password(self, user, password: str, pwd_context) -> bool:
        """Verify user password - handles both database types"""
        fields = self.get_user_field_mapping()
        password_field = fields['hashed_password']
        hashed_password = getattr(user, password_field)
        return pwd_context.verify(password, hashed_password)
    
    def create_user(self, db, username: str, hashed_password: str, is_admin: bool = False):
        """Create new user - handles both database types"""
        if self.db_type == 'mssql':
            new_user = self.User(
                Username=username,
                EmailAddress=f"{username}@bidashboard.com",  # Default email
                FirstName=username.replace('_', ' ').title(),
                LastName="User",
                PasswordHash=hashed_password,
                IsAdmin=is_admin,
                IsActive=True
            )
        else:  # postgresql
            new_user = self.User(
                username=username,
                email=f"{username}@bidashboard.com",
                first_name=username.replace('_', ' ').title(),
                last_name="User",
                hashed_password=hashed_password,
                is_admin=is_admin,
                is_active=True
            )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return new_user
    
    def get_all_dashboards(self, db):
        """Get all dashboards - handles both database types"""
        if self.db_type == 'mssql':
            # For SQL Server, we need to join with categories
            try:
                Category = db_config.get_model('Category')
                dashboards = db.query(self.Dashboard, Category.CategoryName).join(
                    Category, self.Dashboard.CategoryID == Category.CategoryID, isouter=True
                ).all()
                
                result = []
                for dashboard, category_name in dashboards:
                    result.append({
                        'dashboard': dashboard,
                        'category_name': category_name or 'Uncategorized'
                    })
                return result
            except:
                # Fallback if joins fail
                return [{'dashboard': d, 'category_name': 'Unknown'} for d in db.query(self.Dashboard).all()]
        else:  # postgresql
            dashboards = db.query(self.Dashboard).all()
            return [{'dashboard': d, 'category_name': d.categoria} for d in dashboards]
    
    def get_all_employees(self, db):
        """Get all employees - handles both database types"""
        if self.db_type == 'mssql':
            # For SQL Server, we need to join with departments and positions
            try:
                Department = db_config.get_model('Department')
                employees = db.query(self.Employee, Department.DepartmentName).join(
                    Department, self.Employee.DepartmentID == Department.DepartmentID, isouter=True
                ).all()
                
                result = []
                for employee, dept_name in employees:
                    result.append({
                        'employee': employee,
                        'department_name': dept_name or 'Unknown'
                    })
                return result
            except:
                # Fallback if joins fail
                return [{'employee': e, 'department_name': 'Unknown'} for e in db.query(self.Employee).all()]
        else:  # postgresql
            employees = db.query(self.Employee).all()
            return [{'employee': e, 'department_name': e.department} for e in employees]

# Global adapter instance
adapter = DatabaseAdapter()

if __name__ == "__main__":
    print(f"🔧 Database Adapter initialized for {adapter.db_type.upper()}")
    print(f"👤 User fields: {list(adapter.get_user_field_mapping().keys())}")
    print(f"📊 Dashboard fields: {list(adapter.get_dashboard_field_mapping().keys())}")
    print(f"👥 Employee fields: {list(adapter.get_employee_field_mapping().keys())}")