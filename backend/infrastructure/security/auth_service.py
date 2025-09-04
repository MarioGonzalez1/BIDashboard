from datetime import datetime, timezone
from typing import Optional
from ...domain.entities.user import User
from ...domain.interfaces.repositories import IUserRepository
from ...domain.interfaces.security import IAuthenticationService, IPasswordHasher


class AuthenticationService(IAuthenticationService):
    """Authentication service implementation"""
    
    def __init__(
        self,
        user_repository: IUserRepository,
        password_hasher: IPasswordHasher
    ):
        self._user_repository = user_repository
        self._password_hasher = password_hasher
    
    async def authenticate_user(self, username: str, password: str) -> Optional[User]:
        """Authenticate user with username and password"""
        
        if not username or not password:
            return None
        
        # Get user by username
        user = await self._user_repository.get_by_username(username.lower().strip())
        if not user:
            return None
        
        # Verify password
        if not self._password_hasher.verify_password(password, user.hashed_password):
            return None
        
        # Check if user is active
        if not user.is_active:
            return None
        
        return user
    
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
        
        # Validate inputs
        if not username or not password or not email:
            raise ValueError("Username, password, and email are required")
        
        if not first_name or not last_name:
            raise ValueError("First name and last name are required")
        
        # Check if username exists
        existing_user = await self._user_repository.get_by_username(username.lower().strip())
        if existing_user:
            raise ValueError("Username already exists")
        
        # Check if email exists
        existing_email = await self._user_repository.get_by_email(email.lower().strip())
        if existing_email:
            raise ValueError("Email already registered")
        
        # Hash password
        hashed_password = self._password_hasher.hash_password(password)
        
        # Create user entity
        user = User(
            id=None,
            username=username.lower().strip(),
            email=email.lower().strip(),
            first_name=first_name.strip().title(),
            last_name=last_name.strip().title(),
            hashed_password=hashed_password,
            is_admin=is_admin,
            is_active=True,
            created_date=datetime.now(timezone.utc),
            last_login_date=None
        )
        
        # Save to repository
        return await self._user_repository.create(user)
    
    async def change_password(self, user_id: int, old_password: str, new_password: str) -> bool:
        """Change user password"""
        
        if not old_password or not new_password:
            return False
        
        # Get user
        user = await self._user_repository.get_by_id(user_id)
        if not user:
            return False
        
        # Verify old password
        if not self._password_hasher.verify_password(old_password, user.hashed_password):
            return False
        
        # Hash new password
        new_hashed_password = self._password_hasher.hash_password(new_password)
        
        # Update user
        user.hashed_password = new_hashed_password
        await self._user_repository.update(user)
        
        return True
    
    async def reset_password(self, email: str) -> str:
        """Reset user password and return temporary password"""
        
        if not email:
            raise ValueError("Email is required")
        
        # Get user by email
        user = await self._user_repository.get_by_email(email.lower().strip())
        if not user:
            raise ValueError("User not found")
        
        # Generate temporary password
        import secrets
        import string
        
        # Generate secure temporary password
        alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
        temp_password = ''.join(secrets.choice(alphabet) for _ in range(12))
        
        # Hash temporary password
        hashed_temp_password = self._password_hasher.hash_password(temp_password)
        
        # Update user
        user.hashed_password = hashed_temp_password
        await self._user_repository.update(user)
        
        return temp_password
    
    async def update_last_login(self, user_id: int) -> None:
        """Update user's last login timestamp"""
        
        user = await self._user_repository.get_by_id(user_id)
        if user:
            user.last_login_date = datetime.now(timezone.utc)
            await self._user_repository.update(user)
    
    async def deactivate_user(self, user_id: int) -> bool:
        """Deactivate user account"""
        
        user = await self._user_repository.get_by_id(user_id)
        if not user:
            return False
        
        user.is_active = False
        await self._user_repository.update(user)
        return True
    
    async def activate_user(self, user_id: int) -> bool:
        """Activate user account"""
        
        user = await self._user_repository.get_by_id(user_id)
        if not user:
            return False
        
        user.is_active = True
        await self._user_repository.update(user)
        return True