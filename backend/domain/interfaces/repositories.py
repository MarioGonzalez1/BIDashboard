from abc import ABC, abstractmethod
from typing import List, Optional
from ..entities.user import User
from ..entities.dashboard import Dashboard
from ..entities.employee import Employee


class IUserRepository(ABC):
    """Abstract interface for user repository"""
    
    @abstractmethod
    async def get_by_id(self, user_id: int) -> Optional[User]:
        """Get user by ID"""
        pass
    
    @abstractmethod
    async def get_by_username(self, username: str) -> Optional[User]:
        """Get user by username"""
        pass
    
    @abstractmethod
    async def get_by_email(self, email: str) -> Optional[User]:
        """Get user by email"""
        pass
    
    @abstractmethod
    async def create(self, user: User) -> User:
        """Create a new user"""
        pass
    
    @abstractmethod
    async def update(self, user: User) -> User:
        """Update existing user"""
        pass
    
    @abstractmethod
    async def delete(self, user_id: int) -> bool:
        """Delete user by ID"""
        pass
    
    @abstractmethod
    async def get_all_active(self) -> List[User]:
        """Get all active users"""
        pass
    
    @abstractmethod
    async def count_active_users(self) -> int:
        """Count active users"""
        pass


class IDashboardRepository(ABC):
    """Abstract interface for dashboard repository"""
    
    @abstractmethod
    async def get_by_id(self, dashboard_id: int) -> Optional[Dashboard]:
        """Get dashboard by ID"""
        pass
    
    @abstractmethod
    async def get_all(self) -> List[Dashboard]:
        """Get all dashboards"""
        pass
    
    @abstractmethod
    async def get_by_category(self, category: str) -> List[Dashboard]:
        """Get dashboards by category"""
        pass
    
    @abstractmethod
    async def get_by_user(self, user_id: int) -> List[Dashboard]:
        """Get dashboards created by user"""
        pass
    
    @abstractmethod
    async def create(self, dashboard: Dashboard) -> Dashboard:
        """Create a new dashboard"""
        pass
    
    @abstractmethod
    async def update(self, dashboard: Dashboard) -> Dashboard:
        """Update existing dashboard"""
        pass
    
    @abstractmethod
    async def delete(self, dashboard_id: int) -> bool:
        """Delete dashboard by ID"""
        pass
    
    @abstractmethod
    async def count_total(self) -> int:
        """Count total dashboards"""
        pass
    
    @abstractmethod
    async def get_recent_updates(self, limit: int = 5) -> List[Dashboard]:
        """Get recently updated dashboards"""
        pass
    
    @abstractmethod
    async def get_featured_by_categories(self, categories: List[str], limit: int = 3) -> List[Dashboard]:
        """Get featured dashboards from specific categories"""
        pass


class IEmployeeRepository(ABC):
    """Abstract interface for employee repository"""
    
    @abstractmethod
    async def get_by_id(self, employee_id: int) -> Optional[Employee]:
        """Get employee by ID"""
        pass
    
    @abstractmethod
    async def get_all(self) -> List[Employee]:
        """Get all employees"""
        pass
    
    @abstractmethod
    async def get_by_department(self, department: str) -> List[Employee]:
        """Get employees by department"""
        pass
    
    @abstractmethod
    async def get_active_employees(self) -> List[Employee]:
        """Get all active employees"""
        pass
    
    @abstractmethod
    async def create(self, employee: Employee) -> Employee:
        """Create a new employee"""
        pass
    
    @abstractmethod
    async def update(self, employee: Employee) -> Employee:
        """Update existing employee"""
        pass
    
    @abstractmethod
    async def delete(self, employee_id: int) -> bool:
        """Delete employee by ID"""
        pass
    
    @abstractmethod
    async def count_total(self) -> int:
        """Count total employees"""
        pass
    
    @abstractmethod
    async def count_by_department(self) -> dict:
        """Count employees by department"""
        pass