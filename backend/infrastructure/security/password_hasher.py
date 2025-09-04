import bcrypt
from ...domain.interfaces.security import IPasswordHasher


class BcryptPasswordHasher(IPasswordHasher):
    """Bcrypt implementation of password hasher"""
    
    def __init__(self, rounds: int = 12):
        """
        Initialize with specified rounds (default: 12)
        Higher rounds = more secure but slower
        """
        self._rounds = rounds
    
    def hash_password(self, password: str) -> str:
        """Hash a plain text password using bcrypt"""
        if not password:
            raise ValueError("Password cannot be empty")
        
        # Generate salt and hash password
        salt = bcrypt.gensalt(rounds=self._rounds)
        hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
        
        return hashed.decode('utf-8')
    
    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        """Verify a password against its hash"""
        if not plain_password or not hashed_password:
            return False
        
        try:
            return bcrypt.checkpw(
                plain_password.encode('utf-8'), 
                hashed_password.encode('utf-8')
            )
        except (ValueError, TypeError):
            return False