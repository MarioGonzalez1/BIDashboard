from abc import ABC, abstractmethod
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from ..entities.user import User


class IPasswordHasher(ABC):
    """Abstract interface for password hashing"""
    
    @abstractmethod
    def hash_password(self, password: str) -> str:
        """Hash a plain text password"""
        pass
    
    @abstractmethod
    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        """Verify a password against its hash"""
        pass


class IJwtTokenService(ABC):
    """Abstract interface for JWT token service"""
    
    @abstractmethod
    def generate_access_token(
        self, 
        user_id: int, 
        username: str, 
        is_admin: bool,
        expires_delta: Optional[timedelta] = None
    ) -> str:
        """Generate JWT access token"""
        pass
    
    @abstractmethod
    def generate_refresh_token(self, user_id: int, username: str) -> str:
        """Generate JWT refresh token"""
        pass
    
    @abstractmethod
    def decode_token(self, token: str) -> Dict[str, Any]:
        """Decode and validate JWT token"""
        pass
    
    @abstractmethod
    def is_token_expired(self, token: str) -> bool:
        """Check if token is expired"""
        pass
    
    @abstractmethod
    def get_user_from_token(self, token: str) -> Optional[Dict[str, Any]]:
        """Extract user information from token"""
        pass
    
    @abstractmethod
    def revoke_token(self, token: str) -> bool:
        """Revoke a token (add to blacklist)"""
        pass
    
    @abstractmethod
    def is_token_revoked(self, token: str) -> bool:
        """Check if token is revoked"""
        pass


class IAuthenticationService(ABC):
    """Abstract interface for authentication service"""
    
    @abstractmethod
    async def authenticate_user(self, username: str, password: str) -> Optional[User]:
        """Authenticate user with username and password"""
        pass
    
    @abstractmethod
    async def create_user(
        self, 
        username: str, 
        password: str, 
        email: str,
        first_name: str,
        last_name: str,
        is_admin: bool = False
    ) -> User:
        """Create a new user account"""
        pass
    
    @abstractmethod
    async def change_password(self, user_id: int, old_password: str, new_password: str) -> bool:
        """Change user password"""
        pass
    
    @abstractmethod
    async def reset_password(self, email: str) -> str:
        """Reset user password and return temporary password"""
        pass
    
    @abstractmethod
    async def update_last_login(self, user_id: int) -> None:
        """Update user's last login timestamp"""
        pass
    
    @abstractmethod
    async def deactivate_user(self, user_id: int) -> bool:
        """Deactivate user account"""
        pass
    
    @abstractmethod
    async def activate_user(self, user_id: int) -> bool:
        """Activate user account"""
        pass


class IFileStorageService(ABC):
    """Abstract interface for file storage service"""
    
    @abstractmethod
    async def save_file(self, file_content: bytes, filename: str, directory: str = "uploads") -> str:
        """Save file and return the file path"""
        pass
    
    @abstractmethod
    async def delete_file(self, file_path: str) -> bool:
        """Delete file from storage"""
        pass
    
    @abstractmethod
    async def get_file_url(self, file_path: str) -> str:
        """Get public URL for file"""
        pass
    
    @abstractmethod
    def validate_file(self, filename: str, file_size: int, allowed_extensions: list) -> bool:
        """Validate file based on name, size and allowed extensions"""
        pass