from pydantic import BaseModel, EmailStr, validator
from typing import Optional
from datetime import datetime


class LoginRequest(BaseModel):
    username: str
    password: str
    
    @validator('username')
    def validate_username(cls, v):
        if not v or not v.strip():
            raise ValueError('Username cannot be empty')
        return v.strip().lower()
    
    @validator('password')
    def validate_password(cls, v):
        if not v or len(v) < 6:
            raise ValueError('Password must be at least 6 characters long')
        return v


class RegisterRequest(BaseModel):
    username: str
    password: str
    email: EmailStr
    first_name: str
    last_name: str
    
    @validator('username')
    def validate_username(cls, v):
        if not v or not v.strip():
            raise ValueError('Username cannot be empty')
        if len(v.strip()) < 3:
            raise ValueError('Username must be at least 3 characters long')
        return v.strip().lower()
    
    @validator('password')
    def validate_password(cls, v):
        if not v or len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        return v
    
    @validator('first_name', 'last_name')
    def validate_names(cls, v):
        if not v or not v.strip():
            raise ValueError('Name cannot be empty')
        return v.strip().title()


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: Optional[str]
    token_type: str = "bearer"
    expires_in: int  # seconds


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str
    
    @validator('new_password')
    def validate_new_password(cls, v):
        if not v or len(v) < 8:
            raise ValueError('New password must be at least 8 characters long')
        if not any(c.isupper() for c in v):
            raise ValueError('New password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('New password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('New password must contain at least one number')
        return v


class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    first_name: str
    last_name: str
    full_name: str
    is_admin: bool
    is_active: bool
    role: str
    created_date: datetime
    last_login_date: Optional[datetime]
    
    class Config:
        from_attributes = True