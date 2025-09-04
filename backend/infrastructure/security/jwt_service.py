import os
import jwt
from datetime import datetime, timedelta, timezone
from typing import Dict, Any, Optional, Set
from ...domain.interfaces.security import IJwtTokenService


class JwtTokenService(IJwtTokenService):
    """Enhanced JWT token service with security features"""
    
    def __init__(
        self,
        secret_key: Optional[str] = None,
        algorithm: str = "HS256",
        access_token_expire_minutes: int = 30,
        refresh_token_expire_days: int = 7
    ):
        self._secret_key = secret_key or self._generate_secure_key()
        self._algorithm = algorithm
        self._access_token_expire_minutes = access_token_expire_minutes
        self._refresh_token_expire_days = refresh_token_expire_days
        
        # In-memory token blacklist (in production, use Redis)
        self._revoked_tokens: Set[str] = set()
        
        # Validate algorithm
        if algorithm not in ["HS256", "HS384", "HS512", "RS256", "RS384", "RS512"]:
            raise ValueError(f"Unsupported JWT algorithm: {algorithm}")
    
    def _generate_secure_key(self) -> str:
        """Generate a secure random key if none provided"""
        import secrets
        return secrets.token_urlsafe(32)
    
    def generate_access_token(
        self, 
        user_id: int, 
        username: str, 
        is_admin: bool,
        expires_delta: Optional[timedelta] = None
    ) -> str:
        """Generate JWT access token with enhanced claims"""
        
        if expires_delta is None:
            expires_delta = timedelta(minutes=self._access_token_expire_minutes)
        
        now = datetime.now(timezone.utc)
        expire = now + expires_delta
        
        # Enhanced payload with security claims
        payload = {
            "sub": str(user_id),  # Subject (user ID)
            "username": username,
            "is_admin": is_admin,
            "type": "access",
            "iat": now.timestamp(),  # Issued at
            "exp": expire.timestamp(),  # Expiration
            "nbf": now.timestamp(),  # Not before
            "jti": f"access_{user_id}_{int(now.timestamp())}"  # JWT ID for revocation
        }
        
        return jwt.encode(payload, self._secret_key, algorithm=self._algorithm)
    
    def generate_refresh_token(self, user_id: int, username: str) -> str:
        """Generate JWT refresh token"""
        
        now = datetime.now(timezone.utc)
        expire = now + timedelta(days=self._refresh_token_expire_days)
        
        payload = {
            "sub": str(user_id),
            "username": username,
            "type": "refresh",
            "iat": now.timestamp(),
            "exp": expire.timestamp(),
            "nbf": now.timestamp(),
            "jti": f"refresh_{user_id}_{int(now.timestamp())}"
        }
        
        return jwt.encode(payload, self._secret_key, algorithm=self._algorithm)
    
    def decode_token(self, token: str) -> Dict[str, Any]:
        """Decode and validate JWT token with comprehensive checks"""
        
        if not token:
            raise jwt.InvalidTokenError("Token cannot be empty")
        
        try:
            # Decode with all validations
            payload = jwt.decode(
                token, 
                self._secret_key, 
                algorithms=[self._algorithm],
                options={
                    "verify_signature": True,
                    "verify_exp": True,
                    "verify_nbf": True,
                    "verify_iat": True,
                    "require": ["sub", "exp", "iat", "type", "jti"]
                }
            )
            
            # Additional security checks
            if not payload.get("sub"):
                raise jwt.InvalidTokenError("Token missing subject")
            
            if not payload.get("type") in ["access", "refresh"]:
                raise jwt.InvalidTokenError("Invalid token type")
            
            # Check if token is revoked
            if self.is_token_revoked(token):
                raise jwt.InvalidTokenError("Token has been revoked")
            
            return payload
            
        except jwt.ExpiredSignatureError:
            raise jwt.InvalidTokenError("Token has expired")
        except jwt.InvalidSignatureError:
            raise jwt.InvalidTokenError("Invalid token signature")
        except jwt.InvalidTokenError:
            raise
        except Exception as e:
            raise jwt.InvalidTokenError(f"Token validation failed: {str(e)}")
    
    def is_token_expired(self, token: str) -> bool:
        """Check if token is expired"""
        try:
            payload = jwt.decode(
                token, 
                self._secret_key, 
                algorithms=[self._algorithm],
                options={"verify_exp": False}  # Don't raise on expiry, just check
            )
            
            exp = payload.get("exp")
            if not exp:
                return True
            
            return datetime.fromtimestamp(exp, timezone.utc) < datetime.now(timezone.utc)
            
        except Exception:
            return True
    
    def get_user_from_token(self, token: str) -> Optional[Dict[str, Any]]:
        """Extract user information from valid token"""
        try:
            payload = self.decode_token(token)
            
            return {
                "user_id": int(payload["sub"]),
                "username": payload.get("username"),
                "is_admin": payload.get("is_admin", False),
                "token_type": payload.get("type")
            }
            
        except Exception:
            return None
    
    def revoke_token(self, token: str) -> bool:
        """Add token to blacklist"""
        try:
            # Extract JWT ID for efficient storage
            payload = jwt.decode(
                token, 
                self._secret_key, 
                algorithms=[self._algorithm],
                options={"verify_exp": False}
            )
            
            jti = payload.get("jti")
            if jti:
                self._revoked_tokens.add(jti)
                return True
            
            # Fallback: store full token hash
            import hashlib
            token_hash = hashlib.sha256(token.encode()).hexdigest()
            self._revoked_tokens.add(token_hash)
            return True
            
        except Exception:
            return False
    
    def is_token_revoked(self, token: str) -> bool:
        """Check if token is in blacklist"""
        try:
            # Check by JWT ID first
            payload = jwt.decode(
                token, 
                self._secret_key, 
                algorithms=[self._algorithm],
                options={"verify_exp": False}
            )
            
            jti = payload.get("jti")
            if jti and jti in self._revoked_tokens:
                return True
            
            # Check by token hash
            import hashlib
            token_hash = hashlib.sha256(token.encode()).hexdigest()
            return token_hash in self._revoked_tokens
            
        except Exception:
            return False
    
    def cleanup_expired_tokens(self) -> int:
        """Clean up expired tokens from blacklist (call periodically)"""
        # This is a simplified implementation
        # In production, implement proper cleanup with expiration tracking
        before_count = len(self._revoked_tokens)
        
        # For now, we can't easily clean up without storing expiration times
        # In production, use Redis with TTL or database with expiration tracking
        
        return before_count - len(self._revoked_tokens)