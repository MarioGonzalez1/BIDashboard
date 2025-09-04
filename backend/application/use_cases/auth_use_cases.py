from typing import Optional, Tuple
from datetime import datetime, timedelta
from ..dtos.auth_dtos import (
    LoginRequest, RegisterRequest, TokenResponse, 
    ChangePasswordRequest, UserResponse
)
from ...domain.entities.user import User
from ...domain.interfaces.repositories import IUserRepository
from ...domain.interfaces.security import (
    IAuthenticationService, IJwtTokenService, IPasswordHasher
)


class LoginUseCase:
    def __init__(
        self,
        user_repository: IUserRepository,
        auth_service: IAuthenticationService,
        jwt_service: IJwtTokenService
    ):
        self._user_repository = user_repository
        self._auth_service = auth_service
        self._jwt_service = jwt_service
    
    async def execute(self, request: LoginRequest) -> TokenResponse:
        """Login user and return tokens"""
        
        # Authenticate user
        user = await self._auth_service.authenticate_user(
            request.username, 
            request.password
        )
        
        if not user:
            raise ValueError("Invalid username or password")
        
        if not user.is_active:
            raise ValueError("Account is deactivated")
        
        # Update last login
        await self._auth_service.update_last_login(user.id)
        
        # Generate tokens
        access_token = self._jwt_service.generate_access_token(
            user_id=user.id,
            username=user.username,
            is_admin=user.is_admin,
            expires_delta=timedelta(minutes=30)
        )
        
        refresh_token = self._jwt_service.generate_refresh_token(
            user_id=user.id,
            username=user.username
        )
        
        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=30 * 60  # 30 minutes in seconds
        )


class RegisterUseCase:
    def __init__(
        self,
        user_repository: IUserRepository,
        auth_service: IAuthenticationService
    ):
        self._user_repository = user_repository
        self._auth_service = auth_service
    
    async def execute(self, request: RegisterRequest) -> UserResponse:
        """Register new user"""
        
        # Check if username already exists
        existing_user = await self._user_repository.get_by_username(request.username)
        if existing_user:
            raise ValueError("Username already exists")
        
        # Check if email already exists
        existing_email = await self._user_repository.get_by_email(request.email)
        if existing_email:
            raise ValueError("Email already registered")
        
        # Create user (auto-admin for specific usernames)
        is_admin = request.username in ["admin", "mario_gonzalez"]
        
        user = await self._auth_service.create_user(
            username=request.username,
            password=request.password,
            email=request.email,
            first_name=request.first_name,
            last_name=request.last_name,
            is_admin=is_admin
        )
        
        return UserResponse(
            id=user.id,
            username=user.username,
            email=user.email,
            first_name=user.first_name,
            last_name=user.last_name,
            full_name=user.full_name,
            is_admin=user.is_admin,
            is_active=user.is_active,
            role=user.role.value,
            created_date=user.created_date,
            last_login_date=user.last_login_date
        )


class GetCurrentUserUseCase:
    def __init__(self, user_repository: IUserRepository):
        self._user_repository = user_repository
    
    async def execute(self, user_id: int) -> UserResponse:
        """Get current user information"""
        
        user = await self._user_repository.get_by_id(user_id)
        if not user:
            raise ValueError("User not found")
        
        return UserResponse(
            id=user.id,
            username=user.username,
            email=user.email,
            first_name=user.first_name,
            last_name=user.last_name,
            full_name=user.full_name,
            is_admin=user.is_admin,
            is_active=user.is_active,
            role=user.role.value,
            created_date=user.created_date,
            last_login_date=user.last_login_date
        )


class ChangePasswordUseCase:
    def __init__(
        self,
        user_repository: IUserRepository,
        auth_service: IAuthenticationService
    ):
        self._user_repository = user_repository
        self._auth_service = auth_service
    
    async def execute(self, user_id: int, request: ChangePasswordRequest) -> bool:
        """Change user password"""
        
        success = await self._auth_service.change_password(
            user_id=user_id,
            old_password=request.old_password,
            new_password=request.new_password
        )
        
        if not success:
            raise ValueError("Invalid current password")
        
        return True


class RefreshTokenUseCase:
    def __init__(
        self,
        user_repository: IUserRepository,
        jwt_service: IJwtTokenService
    ):
        self._user_repository = user_repository
        self._jwt_service = jwt_service
    
    async def execute(self, refresh_token: str) -> TokenResponse:
        """Refresh access token using refresh token"""
        
        try:
            # Decode refresh token
            payload = self._jwt_service.decode_token(refresh_token)
            user_id = payload.get("sub")
            
            if not user_id:
                raise ValueError("Invalid token")
            
            # Check if token is revoked
            if self._jwt_service.is_token_revoked(refresh_token):
                raise ValueError("Token has been revoked")
            
            # Get user
            user = await self._user_repository.get_by_id(int(user_id))
            if not user or not user.is_active:
                raise ValueError("User not found or inactive")
            
            # Generate new access token
            access_token = self._jwt_service.generate_access_token(
                user_id=user.id,
                username=user.username,
                is_admin=user.is_admin,
                expires_delta=timedelta(minutes=30)
            )
            
            return TokenResponse(
                access_token=access_token,
                token_type="bearer",
                expires_in=30 * 60
            )
            
        except Exception as e:
            raise ValueError(f"Invalid refresh token: {str(e)}")


class LogoutUseCase:
    def __init__(self, jwt_service: IJwtTokenService):
        self._jwt_service = jwt_service
    
    async def execute(self, access_token: str, refresh_token: Optional[str] = None) -> bool:
        """Logout user by revoking tokens"""
        
        # Revoke access token
        self._jwt_service.revoke_token(access_token)
        
        # Revoke refresh token if provided
        if refresh_token:
            self._jwt_service.revoke_token(refresh_token)
        
        return True