from fastapi import HTTPException, status, Request, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional, Dict, Any
from ...infrastructure.di_container import container


class AuthMiddleware:
    """Enhanced authentication middleware with JWT validation"""
    
    def __init__(self):
        self._security = HTTPBearer(auto_error=False)
        self._jwt_service = container.get_singleton('jwt_service')
    
    async def verify_token(
        self, 
        credentials: Optional[HTTPAuthorizationCredentials] = Depends(HTTPBearer(auto_error=False))
    ) -> Dict[str, Any]:
        """Verify JWT token and return user info"""
        
        if not credentials:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authorization header required",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        token = credentials.credentials
        
        try:
            # Decode token with all security checks
            user_info = self._jwt_service.get_user_from_token(token)
            
            if not user_info:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid authentication token",
                    headers={"WWW-Authenticate": "Bearer"},
                )
            
            # Verify token type
            if user_info.get("token_type") != "access":
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid token type",
                    headers={"WWW-Authenticate": "Bearer"},
                )
            
            return user_info
            
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Token validation failed: {str(e)}",
                headers={"WWW-Authenticate": "Bearer"},
            )
    
    async def get_current_user(
        self, 
        user_info: Dict[str, Any] = Depends(verify_token)
    ) -> Dict[str, Any]:
        """Get current authenticated user"""
        return user_info
    
    async def get_current_admin_user(
        self, 
        current_user: Dict[str, Any] = Depends(get_current_user)
    ) -> Dict[str, Any]:
        """Get current user and verify admin privileges"""
        
        if not current_user.get("is_admin", False):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Administrator privileges required"
            )
        
        return current_user
    
    async def optional_auth(
        self,
        credentials: Optional[HTTPAuthorizationCredentials] = Depends(HTTPBearer(auto_error=False))
    ) -> Optional[Dict[str, Any]]:
        """Optional authentication - returns None if no token provided"""
        
        if not credentials:
            return None
        
        try:
            return await self.verify_token(credentials)
        except HTTPException:
            return None


# Global middleware instance
auth_middleware = AuthMiddleware()

# Export dependency functions for use in routes
verify_token = auth_middleware.verify_token
get_current_user = auth_middleware.get_current_user  
get_current_admin_user = auth_middleware.get_current_admin_user
optional_auth = auth_middleware.optional_auth