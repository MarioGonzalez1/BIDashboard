from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Dict, Any

from ...application.dtos.auth_dtos import (
    LoginRequest, RegisterRequest, TokenResponse, 
    ChangePasswordRequest, UserResponse, RefreshTokenRequest
)
from ...infrastructure.di_container import container
from ..middleware.auth_middleware import get_current_user, optional_auth
from ...database_config import get_db


router = APIRouter(prefix="/api/auth", tags=["Authentication"])


@router.post("/login", response_model=TokenResponse)
async def login(
    login_request: LoginRequest,
    db: Session = Depends(get_db)
):
    """User login endpoint"""
    
    try:
        login_use_case = container.get_factory('login_use_case')(db)
        token_response = await login_use_case.execute(login_request)
        return token_response
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )


@router.post("/register", response_model=UserResponse)
async def register(
    register_request: RegisterRequest,
    db: Session = Depends(get_db)
):
    """User registration endpoint"""
    
    try:
        register_use_case = container.get_factory('register_use_case')(db)
        user_response = await register_use_case.execute(register_request)
        return user_response
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current logged-in user information"""
    
    try:
        get_user_use_case = container.get_factory('get_current_user_use_case')(db)
        user_response = await get_user_use_case.execute(current_user["user_id"])
        return user_response
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )


@router.post("/change-password")
async def change_password(
    password_request: ChangePasswordRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Change user password"""
    
    try:
        change_password_use_case = container.get_factory('change_password_use_case')(db)
        success = await change_password_use_case.execute(
            current_user["user_id"], 
            password_request
        )
        
        if success:
            return {"message": "Password changed successfully"}
        else:
            raise ValueError("Failed to change password")
            
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    refresh_request: RefreshTokenRequest,
    db: Session = Depends(get_db)
):
    """Refresh access token using refresh token"""
    
    try:
        refresh_use_case = container.get_factory('refresh_token_use_case')(db)
        token_response = await refresh_use_case.execute(refresh_request.refresh_token)
        return token_response
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )


@router.post("/logout")
async def logout(
    refresh_token: RefreshTokenRequest = None,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Logout user by revoking tokens"""
    
    try:
        logout_use_case = container.get_singleton('logout_use_case')
        
        # In a real implementation, you'd get the current access token from the request
        # For now, we'll just revoke the refresh token if provided
        refresh_token_str = refresh_token.refresh_token if refresh_token else None
        
        success = await logout_use_case.execute(
            access_token="current_token",  # Would be extracted from Authorization header
            refresh_token=refresh_token_str
        )
        
        if success:
            return {"message": "Logged out successfully"}
        else:
            return {"message": "Logout completed with warnings"}
            
    except Exception as e:
        # Don't fail logout even if there are issues
        return {"message": "Logout completed with warnings"}