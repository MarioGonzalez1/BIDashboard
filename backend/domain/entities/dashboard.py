from dataclasses import dataclass
from datetime import datetime
from typing import Optional


@dataclass
class Dashboard:
    """Domain Dashboard entity representing a business intelligence dashboard"""
    
    id: Optional[int]
    titulo: str
    url_acceso: str
    categoria: str
    subcategoria: Optional[str]
    descripcion: Optional[str]
    url_imagen_preview: Optional[str]
    created_by: int
    created_date: Optional[datetime]
    
    def __post_init__(self):
        if self.created_date is None:
            self.created_date = datetime.utcnow()
        
        # Validate URL format
        if not self.url_acceso.startswith(('http://', 'https://')):
            raise ValueError("Dashboard URL must start with http:// or https://")
        
        # Validate required fields
        if not self.titulo.strip():
            raise ValueError("Dashboard title cannot be empty")
        
        if not self.categoria.strip():
            raise ValueError("Dashboard category cannot be empty")
    
    @property
    def display_title(self) -> str:
        """Get formatted display title"""
        return self.titulo.title()
    
    @property
    def has_preview_image(self) -> bool:
        """Check if dashboard has a preview image"""
        return bool(self.url_imagen_preview and self.url_imagen_preview.strip())
    
    def can_be_accessed_by(self, user_id: int, is_admin: bool) -> bool:
        """Check if user can access this dashboard"""
        # For now, all authenticated users can access all dashboards
        # This can be extended with role-based access control
        return True
    
    def can_be_edited_by(self, user_id: int, is_admin: bool) -> bool:
        """Check if user can edit this dashboard"""
        return is_admin or self.created_by == user_id
    
    def can_be_deleted_by(self, user_id: int, is_admin: bool) -> bool:
        """Check if user can delete this dashboard"""
        return is_admin or self.created_by == user_id