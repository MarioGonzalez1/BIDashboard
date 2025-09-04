from dataclasses import dataclass
from datetime import datetime
from typing import Optional
from enum import Enum
from decimal import Decimal


class EmploymentStatus(Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    TERMINATED = "terminated"
    ON_LEAVE = "on_leave"


@dataclass
class Employee:
    """Domain Employee entity representing a company employee"""
    
    id: Optional[int]
    first_name: str
    last_name: str
    email: str
    phone: Optional[str]
    department: str
    position: str
    salary: Decimal
    hire_date: datetime
    status: EmploymentStatus
    created_by: int
    created_date: Optional[datetime] = None
    
    def __post_init__(self):
        if self.created_date is None:
            self.created_date = datetime.utcnow()
        
        # Validate required fields
        if not self.first_name.strip():
            raise ValueError("Employee first name cannot be empty")
        
        if not self.last_name.strip():
            raise ValueError("Employee last name cannot be empty")
        
        if not self.email.strip() or '@' not in self.email:
            raise ValueError("Employee must have a valid email address")
        
        if not self.department.strip():
            raise ValueError("Employee department cannot be empty")
        
        if not self.position.strip():
            raise ValueError("Employee position cannot be empty")
        
        if self.salary <= 0:
            raise ValueError("Employee salary must be positive")
        
        # Convert string status to enum if needed
        if isinstance(self.status, str):
            self.status = EmploymentStatus(self.status.lower())
    
    @property
    def full_name(self) -> str:
        """Get employee's full name"""
        return f"{self.first_name} {self.last_name}".strip()
    
    @property
    def is_active(self) -> bool:
        """Check if employee is currently active"""
        return self.status == EmploymentStatus.ACTIVE
    
    @property
    def years_of_service(self) -> float:
        """Calculate years of service"""
        delta = datetime.utcnow() - self.hire_date
        return round(delta.days / 365.25, 1)
    
    def can_be_edited_by(self, user_id: int, is_admin: bool) -> bool:
        """Check if user can edit this employee record"""
        return is_admin
    
    def can_be_deleted_by(self, user_id: int, is_admin: bool) -> bool:
        """Check if user can delete this employee record"""
        return is_admin