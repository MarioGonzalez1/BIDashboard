from dataclasses import dataclass
from datetime import datetime
from typing import Optional
from enum import Enum


class UserRole(Enum):
    ADMIN = "admin"
    USER = "user"


@dataclass
class User:
    """Domain User entity representing a system user"""
    
    id: Optional[int]
    username: str
    email: str
    first_name: str
    last_name: str
    hashed_password: str
    is_admin: bool
    is_active: bool
    created_date: Optional[datetime]
    last_login_date: Optional[datetime]
    
    def __post_init__(self):
        if self.created_date is None:
            self.created_date = datetime.utcnow()
    
    @property
    def full_name(self) -> str:
        """Get user's full name"""
        return f"{self.first_name} {self.last_name}".strip()
    
    @property
    def role(self) -> UserRole:
        """Get user role based on admin status"""
        return UserRole.ADMIN if self.is_admin else UserRole.USER
    
    def can_delete_dashboard(self, dashboard_owner_id: int) -> bool:
        """Check if user can delete a dashboard"""
        return self.is_admin or self.id == dashboard_owner_id
    
    def can_manage_employees(self) -> bool:
        """Check if user can manage employees"""
        return self.is_admin
    
    def is_authenticated(self) -> bool:
        """Check if user is authenticated and active"""
        return self.is_active