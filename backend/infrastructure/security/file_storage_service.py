import os
import aiofiles
from datetime import datetime
from typing import List
from pathlib import Path
from ...domain.interfaces.security import IFileStorageService


class LocalFileStorageService(IFileStorageService):
    """Local file storage implementation"""
    
    def __init__(self, base_path: str = "static", max_file_size: int = 10 * 1024 * 1024):  # 10MB
        self._base_path = Path(base_path)
        self._max_file_size = max_file_size
        
        # Create base directory if it doesn't exist
        self._base_path.mkdir(parents=True, exist_ok=True)
    
    async def save_file(self, file_content: bytes, filename: str, directory: str = "uploads") -> str:
        """Save file and return the file path"""
        
        if not file_content:
            raise ValueError("File content cannot be empty")
        
        if len(file_content) > self._max_file_size:
            raise ValueError(f"File size exceeds maximum allowed size of {self._max_file_size} bytes")
        
        # Sanitize filename
        safe_filename = self._sanitize_filename(filename)
        
        # Create timestamp prefix to avoid conflicts
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        final_filename = f"{timestamp}_{safe_filename}"
        
        # Create directory path
        dir_path = self._base_path / directory
        dir_path.mkdir(parents=True, exist_ok=True)
        
        # Full file path
        file_path = dir_path / final_filename
        
        # Save file asynchronously
        async with aiofiles.open(file_path, "wb") as f:
            await f.write(file_content)
        
        # Return relative path
        return f"/{directory}/{final_filename}"
    
    async def delete_file(self, file_path: str) -> bool:
        """Delete file from storage"""
        
        try:
            # Remove leading slash and construct full path
            clean_path = file_path.lstrip("/")
            full_path = self._base_path / clean_path
            
            if full_path.exists() and full_path.is_file():
                # Security check: ensure file is within base directory
                if not str(full_path.resolve()).startswith(str(self._base_path.resolve())):
                    raise ValueError("File path is outside allowed directory")
                
                full_path.unlink()
                return True
            
            return False
            
        except Exception:
            return False
    
    async def get_file_url(self, file_path: str) -> str:
        """Get public URL for file"""
        
        # For local storage, this would typically be the base URL + file path
        # In a real application, you might have a different base URL
        base_url = os.getenv("BASE_URL", "http://127.0.0.1:8000")
        
        # Ensure file_path starts with /
        if not file_path.startswith("/"):
            file_path = "/" + file_path
        
        return f"{base_url}{file_path}"
    
    def validate_file(self, filename: str, file_size: int, allowed_extensions: List[str]) -> bool:
        """Validate file based on name, size and allowed extensions"""
        
        if not filename:
            return False
        
        # Check file size
        if file_size <= 0 or file_size > self._max_file_size:
            return False
        
        # Check file extension
        file_ext = Path(filename).suffix.lower().lstrip('.')
        if file_ext not in [ext.lower().lstrip('.') for ext in allowed_extensions]:
            return False
        
        # Additional security checks
        if self._has_dangerous_patterns(filename):
            return False
        
        return True
    
    def _sanitize_filename(self, filename: str) -> str:
        """Sanitize filename to prevent path traversal and other issues"""
        
        if not filename:
            return "unknown_file"
        
        # Get just the filename, no path components
        safe_name = Path(filename).name
        
        # Remove or replace dangerous characters
        dangerous_chars = ['<', '>', ':', '"', '|', '?', '*', '\x00']
        for char in dangerous_chars:
            safe_name = safe_name.replace(char, '_')
        
        # Replace spaces with underscores
        safe_name = safe_name.replace(' ', '_')
        
        # Ensure filename is not empty after sanitization
        if not safe_name or safe_name == '.' or safe_name == '..':
            safe_name = f"file_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        return safe_name
    
    def _has_dangerous_patterns(self, filename: str) -> bool:
        """Check for dangerous patterns in filename"""
        
        dangerous_patterns = [
            '..',  # Path traversal
            '/',   # Path separator
            '\\',  # Windows path separator
            '\x00', # Null byte
        ]
        
        filename_lower = filename.lower()
        
        # Check for dangerous patterns
        for pattern in dangerous_patterns:
            if pattern in filename_lower:
                return True
        
        # Check for executable extensions (extra security)
        executable_extensions = [
            '.exe', '.bat', '.cmd', '.com', '.pif', '.scr', '.vbs', 
            '.js', '.jar', '.sh', '.py', '.pl', '.php', '.asp'
        ]
        
        file_ext = Path(filename).suffix.lower()
        if file_ext in executable_extensions:
            return True
        
        return False