from pydantic import BaseModel, HttpUrl, validator
from typing import Optional
from datetime import datetime


class CreateDashboardRequest(BaseModel):
    titulo: str
    url_acceso: str
    categoria: str
    subcategoria: Optional[str] = ""
    descripcion: Optional[str] = ""
    
    @validator('titulo')
    def validate_titulo(cls, v):
        if not v or not v.strip():
            raise ValueError('Dashboard title cannot be empty')
        if len(v.strip()) > 200:
            raise ValueError('Dashboard title cannot exceed 200 characters')
        return v.strip()
    
    @validator('url_acceso')
    def validate_url_acceso(cls, v):
        if not v or not v.strip():
            raise ValueError('Dashboard URL cannot be empty')
        if not v.startswith(('http://', 'https://')):
            raise ValueError('Dashboard URL must start with http:// or https://')
        return v.strip()
    
    @validator('categoria')
    def validate_categoria(cls, v):
        if not v or not v.strip():
            raise ValueError('Dashboard category cannot be empty')
        return v.strip()
    
    @validator('subcategoria', 'descripcion')
    def validate_optional_fields(cls, v):
        return v.strip() if v else ""


class UpdateDashboardRequest(BaseModel):
    titulo: Optional[str]
    url_acceso: Optional[str]
    categoria: Optional[str]
    subcategoria: Optional[str]
    descripcion: Optional[str]
    
    @validator('titulo')
    def validate_titulo(cls, v):
        if v is not None:
            if not v.strip():
                raise ValueError('Dashboard title cannot be empty')
            if len(v.strip()) > 200:
                raise ValueError('Dashboard title cannot exceed 200 characters')
            return v.strip()
        return v
    
    @validator('url_acceso')
    def validate_url_acceso(cls, v):
        if v is not None:
            if not v.strip():
                raise ValueError('Dashboard URL cannot be empty')
            if not v.startswith(('http://', 'https://')):
                raise ValueError('Dashboard URL must start with http:// or https://')
            return v.strip()
        return v
    
    @validator('categoria')
    def validate_categoria(cls, v):
        if v is not None:
            if not v.strip():
                raise ValueError('Dashboard category cannot be empty')
            return v.strip()
        return v


class DashboardResponse(BaseModel):
    id: int
    titulo: str
    url_acceso: str
    categoria: str
    subcategoria: str
    descripcion: str
    url_imagen_preview: Optional[str]
    created_by: int
    created_date: datetime
    can_edit: bool = False
    can_delete: bool = False
    
    class Config:
        from_attributes = True


class DashboardListResponse(BaseModel):
    dashboards: list[DashboardResponse]
    total: int
    categories: list[str]


class DashboardStatsResponse(BaseModel):
    total_dashboards: int
    active_users: int
    departments: int
    category_counts: dict[str, int]


class RecentDashboardResponse(BaseModel):
    titulo: str
    categoria: str
    created_date: datetime
    
    class Config:
        from_attributes = True


class FeaturedDashboardResponse(BaseModel):
    id: int
    titulo: str
    descripcion: str
    categoria: str
    
    class Config:
        from_attributes = True