from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, desc, func
from datetime import datetime
from ...domain.entities.user import User as DomainUser
from ...domain.entities.dashboard import Dashboard as DomainDashboard
from ...domain.entities.employee import Employee as DomainEmployee, EmploymentStatus
from ...domain.interfaces.repositories import IUserRepository, IDashboardRepository, IEmployeeRepository
from database_adapter import adapter


class UserRepository(IUserRepository):
    """SQLAlchemy implementation of user repository"""
    
    def __init__(self, db_session: Session):
        self._db = db_session
        self._model = adapter.User
        self._fields = adapter.get_user_field_mapping()
    
    def _to_domain(self, db_user) -> DomainUser:
        """Convert database model to domain entity"""
        if not db_user:
            return None
        
        return DomainUser(
            id=getattr(db_user, self._fields['id']),
            username=getattr(db_user, self._fields['username']),
            email=getattr(db_user, self._fields['email']),
            first_name=getattr(db_user, self._fields['first_name']),
            last_name=getattr(db_user, self._fields['last_name']),
            hashed_password=getattr(db_user, self._fields['hashed_password']),
            is_admin=getattr(db_user, self._fields['is_admin']),
            is_active=getattr(db_user, self._fields['is_active']),
            created_date=getattr(db_user, self._fields['created_date']),
            last_login_date=getattr(db_user, self._fields['last_login_date'])
        )
    
    def _from_domain(self, domain_user: DomainUser):
        """Convert domain entity to database model"""
        if domain_user.id:
            # Update existing user
            db_user = self._db.query(self._model).filter(
                getattr(self._model, self._fields['id']) == domain_user.id
            ).first()
        else:
            # Create new user
            db_user = self._model()
        
        # Map fields
        setattr(db_user, self._fields['username'], domain_user.username)
        setattr(db_user, self._fields['email'], domain_user.email)
        setattr(db_user, self._fields['first_name'], domain_user.first_name)
        setattr(db_user, self._fields['last_name'], domain_user.last_name)
        setattr(db_user, self._fields['hashed_password'], domain_user.hashed_password)
        setattr(db_user, self._fields['is_admin'], domain_user.is_admin)
        setattr(db_user, self._fields['is_active'], domain_user.is_active)
        setattr(db_user, self._fields['created_date'], domain_user.created_date)
        setattr(db_user, self._fields['last_login_date'], domain_user.last_login_date)
        
        return db_user
    
    async def get_by_id(self, user_id: int) -> Optional[DomainUser]:
        """Get user by ID"""
        db_user = self._db.query(self._model).filter(
            getattr(self._model, self._fields['id']) == user_id
        ).first()
        return self._to_domain(db_user)
    
    async def get_by_username(self, username: str) -> Optional[DomainUser]:
        """Get user by username"""
        db_user = self._db.query(self._model).filter(
            getattr(self._model, self._fields['username']) == username
        ).first()
        return self._to_domain(db_user)
    
    async def get_by_email(self, email: str) -> Optional[DomainUser]:
        """Get user by email"""
        db_user = self._db.query(self._model).filter(
            getattr(self._model, self._fields['email']) == email
        ).first()
        return self._to_domain(db_user)
    
    async def create(self, user: DomainUser) -> DomainUser:
        """Create a new user"""
        db_user = self._from_domain(user)
        self._db.add(db_user)
        self._db.commit()
        self._db.refresh(db_user)
        return self._to_domain(db_user)
    
    async def update(self, user: DomainUser) -> DomainUser:
        """Update existing user"""
        db_user = self._from_domain(user)
        self._db.commit()
        self._db.refresh(db_user)
        return self._to_domain(db_user)
    
    async def delete(self, user_id: int) -> bool:
        """Delete user by ID"""
        db_user = self._db.query(self._model).filter(
            getattr(self._model, self._fields['id']) == user_id
        ).first()
        
        if db_user:
            self._db.delete(db_user)
            self._db.commit()
            return True
        return False
    
    async def get_all_active(self) -> List[DomainUser]:
        """Get all active users"""
        db_users = self._db.query(self._model).filter(
            getattr(self._model, self._fields['is_active']) == True
        ).all()
        return [self._to_domain(user) for user in db_users]
    
    async def count_active_users(self) -> int:
        """Count active users"""
        return self._db.query(self._model).filter(
            getattr(self._model, self._fields['is_active']) == True
        ).count()


class DashboardRepository(IDashboardRepository):
    """SQLAlchemy implementation of dashboard repository"""
    
    def __init__(self, db_session: Session):
        self._db = db_session
        self._model = adapter.Dashboard
        self._fields = adapter.get_dashboard_field_mapping()
    
    def _to_domain(self, dashboard_data) -> DomainDashboard:
        """Convert database result to domain entity"""
        if not dashboard_data:
            return None
        
        # Handle both direct model and adapter result format
        if isinstance(dashboard_data, dict):
            dashboard = dashboard_data['dashboard']
            category_name = dashboard_data.get('category_name', 'Unknown')
        else:
            dashboard = dashboard_data
            category_name = getattr(dashboard, self._fields.get('categoria', 'categoria'), 'Unknown')
        
        return DomainDashboard(
            id=getattr(dashboard, self._fields['id']),
            titulo=getattr(dashboard, self._fields['titulo']),
            url_acceso=getattr(dashboard, self._fields['url_acceso']),
            categoria=category_name,
            subcategoria=getattr(dashboard, self._fields.get('subcategoria', 'subcategoria'), '') or '',
            descripcion=getattr(dashboard, self._fields.get('descripcion', 'descripcion'), '') or '',
            url_imagen_preview=getattr(dashboard, self._fields['url_imagen_preview']),
            created_by=getattr(dashboard, self._fields['created_by']),
            created_date=getattr(dashboard, self._fields.get('created_date', 'created_date'))
        )
    
    async def get_by_id(self, dashboard_id: int) -> Optional[DomainDashboard]:
        """Get dashboard by ID"""
        dashboard_data = adapter.get_all_dashboards(self._db)
        for item in dashboard_data:
            dashboard = item['dashboard']
            if getattr(dashboard, self._fields['id']) == dashboard_id:
                return self._to_domain(item)
        return None
    
    async def get_all(self) -> List[DomainDashboard]:
        """Get all dashboards"""
        dashboard_data = adapter.get_all_dashboards(self._db)
        return [self._to_domain(item) for item in dashboard_data]
    
    async def get_by_category(self, category: str) -> List[DomainDashboard]:
        """Get dashboards by category"""
        dashboard_data = adapter.get_all_dashboards(self._db)
        result = []
        for item in dashboard_data:
            if item.get('category_name', '').lower() == category.lower():
                result.append(self._to_domain(item))
        return result
    
    async def get_by_user(self, user_id: int) -> List[DomainDashboard]:
        """Get dashboards created by user"""
        dashboard_data = adapter.get_all_dashboards(self._db)
        result = []
        for item in dashboard_data:
            dashboard = item['dashboard']
            if getattr(dashboard, self._fields['created_by']) == user_id:
                result.append(self._to_domain(item))
        return result
    
    async def create(self, dashboard: DomainDashboard) -> DomainDashboard:
        """Create a new dashboard"""
        # This is a simplified implementation
        # In a real scenario, you'd need to handle the adapter's create logic
        new_dashboard = self._model()
        
        # Map basic fields (simplified)
        if hasattr(new_dashboard, 'titulo'):
            new_dashboard.titulo = dashboard.titulo
        if hasattr(new_dashboard, 'url_acceso'):
            new_dashboard.url_acceso = dashboard.url_acceso
        if hasattr(new_dashboard, 'categoria'):
            new_dashboard.categoria = dashboard.categoria
        if hasattr(new_dashboard, 'subcategoria'):
            new_dashboard.subcategoria = dashboard.subcategoria
        if hasattr(new_dashboard, 'descripcion'):
            new_dashboard.descripcion = dashboard.descripcion
        if hasattr(new_dashboard, 'url_imagen_preview'):
            new_dashboard.url_imagen_preview = dashboard.url_imagen_preview
        if hasattr(new_dashboard, 'created_by'):
            new_dashboard.created_by = dashboard.created_by
        
        self._db.add(new_dashboard)
        self._db.commit()
        self._db.refresh(new_dashboard)
        
        # Return as domain object
        dashboard.id = getattr(new_dashboard, self._fields['id'])
        dashboard.created_date = getattr(new_dashboard, self._fields.get('created_date'), datetime.utcnow())
        return dashboard
    
    async def update(self, dashboard: DomainDashboard) -> DomainDashboard:
        """Update existing dashboard"""
        # Simplified implementation
        return dashboard
    
    async def delete(self, dashboard_id: int) -> bool:
        """Delete dashboard by ID"""
        dashboard = self._db.query(self._model).filter(
            getattr(self._model, self._fields['id']) == dashboard_id
        ).first()
        
        if dashboard:
            self._db.delete(dashboard)
            self._db.commit()
            return True
        return False
    
    async def count_total(self) -> int:
        """Count total dashboards"""
        return self._db.query(self._model).count()
    
    async def get_recent_updates(self, limit: int = 5) -> List[DomainDashboard]:
        """Get recently updated dashboards"""
        dashboard_data = adapter.get_all_dashboards(self._db)
        all_dashboards = [self._to_domain(item) for item in dashboard_data]
        
        # Sort by creation date and limit
        sorted_dashboards = sorted(
            all_dashboards, 
            key=lambda x: x.created_date or datetime.min, 
            reverse=True
        )
        
        return sorted_dashboards[:limit]
    
    async def get_featured_by_categories(self, categories: List[str], limit: int = 3) -> List[DomainDashboard]:
        """Get featured dashboards from specific categories"""
        dashboard_data = adapter.get_all_dashboards(self._db)
        featured = []
        
        for category in categories:
            for item in dashboard_data:
                if item.get('category_name', '').lower() == category.lower():
                    featured.append(self._to_domain(item))
                    break  # Take first from each category
                
                if len(featured) >= limit:
                    break
            
            if len(featured) >= limit:
                break
        
        return featured


class EmployeeRepository(IEmployeeRepository):
    """SQLAlchemy implementation of employee repository"""
    
    def __init__(self, db_session: Session):
        self._db = db_session
        self._model = adapter.Employee
        self._fields = adapter.get_employee_field_mapping()
    
    def _to_domain(self, employee_data) -> DomainEmployee:
        """Convert database result to domain entity"""
        if not employee_data:
            return None
        
        # Handle both direct model and adapter result format
        if isinstance(employee_data, dict):
            employee = employee_data['employee']
            department_name = employee_data.get('department_name', 'Unknown')
        else:
            employee = employee_data
            department_name = getattr(employee, self._fields.get('department', 'department'), 'Unknown')
        
        # Handle status conversion
        status_value = getattr(employee, self._fields.get('status', 'status'), 'active')
        if isinstance(status_value, str):
            try:
                status = EmploymentStatus(status_value.lower())
            except ValueError:
                status = EmploymentStatus.ACTIVE
        else:
            status = EmploymentStatus.ACTIVE
        
        return DomainEmployee(
            id=getattr(employee, self._fields['id']),
            first_name=getattr(employee, self._fields['first_name']),
            last_name=getattr(employee, self._fields['last_name']),
            email=getattr(employee, self._fields['email']),
            phone=getattr(employee, self._fields.get('phone', 'phone')),
            department=department_name,
            position=getattr(employee, self._fields.get('position', 'position')),
            salary=getattr(employee, self._fields.get('salary', 'salary')),
            hire_date=getattr(employee, self._fields.get('hire_date', 'hire_date')),
            status=status,
            created_by=getattr(employee, self._fields.get('created_by', 'created_by')),
            created_date=getattr(employee, self._fields.get('created_date'), datetime.utcnow())
        )
    
    async def get_by_id(self, employee_id: int) -> Optional[DomainEmployee]:
        """Get employee by ID"""
        employee_data = adapter.get_all_employees(self._db)
        for item in employee_data:
            employee = item['employee']
            if getattr(employee, self._fields['id']) == employee_id:
                return self._to_domain(item)
        return None
    
    async def get_all(self) -> List[DomainEmployee]:
        """Get all employees"""
        employee_data = adapter.get_all_employees(self._db)
        return [self._to_domain(item) for item in employee_data]
    
    async def get_by_department(self, department: str) -> List[DomainEmployee]:
        """Get employees by department"""
        employee_data = adapter.get_all_employees(self._db)
        result = []
        for item in employee_data:
            if item.get('department_name', '').lower() == department.lower():
                result.append(self._to_domain(item))
        return result
    
    async def get_active_employees(self) -> List[DomainEmployee]:
        """Get all active employees"""
        all_employees = await self.get_all()
        return [emp for emp in all_employees if emp.is_active]
    
    async def create(self, employee: DomainEmployee) -> DomainEmployee:
        """Create a new employee"""
        # Simplified implementation
        new_employee = self._model()
        
        # Map fields
        if hasattr(new_employee, 'first_name'):
            new_employee.first_name = employee.first_name
        if hasattr(new_employee, 'last_name'):
            new_employee.last_name = employee.last_name
        if hasattr(new_employee, 'email'):
            new_employee.email = employee.email
        if hasattr(new_employee, 'phone'):
            new_employee.phone = employee.phone
        if hasattr(new_employee, 'department'):
            new_employee.department = employee.department
        if hasattr(new_employee, 'position'):
            new_employee.position = employee.position
        if hasattr(new_employee, 'salary'):
            new_employee.salary = employee.salary
        if hasattr(new_employee, 'hire_date'):
            new_employee.hire_date = employee.hire_date
        if hasattr(new_employee, 'status'):
            new_employee.status = employee.status.value
        if hasattr(new_employee, 'created_by'):
            new_employee.created_by = employee.created_by
        
        self._db.add(new_employee)
        self._db.commit()
        self._db.refresh(new_employee)
        
        # Return as domain object
        employee.id = getattr(new_employee, self._fields['id'])
        employee.created_date = datetime.utcnow()
        return employee
    
    async def update(self, employee: DomainEmployee) -> DomainEmployee:
        """Update existing employee"""
        # Simplified implementation
        return employee
    
    async def delete(self, employee_id: int) -> bool:
        """Delete employee by ID"""
        employee = self._db.query(self._model).filter(
            getattr(self._model, self._fields['id']) == employee_id
        ).first()
        
        if employee:
            self._db.delete(employee)
            self._db.commit()
            return True
        return False
    
    async def count_total(self) -> int:
        """Count total employees"""
        return self._db.query(self._model).count()
    
    async def count_by_department(self) -> dict:
        """Count employees by department"""
        employee_data = adapter.get_all_employees(self._db)
        department_counts = {}
        
        for item in employee_data:
            dept = item.get('department_name', 'Unknown')
            department_counts[dept] = department_counts.get(dept, 0) + 1
        
        return department_counts