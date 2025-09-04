from typing import List, Optional
from ..dtos.dashboard_dtos import (
    CreateDashboardRequest, UpdateDashboardRequest, DashboardResponse,
    DashboardListResponse, DashboardStatsResponse, RecentDashboardResponse,
    FeaturedDashboardResponse
)
from ...domain.entities.dashboard import Dashboard
from ...domain.entities.user import User
from ...domain.interfaces.repositories import IDashboardRepository, IUserRepository
from ...domain.interfaces.security import IFileStorageService


class GetAllDashboardsUseCase:
    def __init__(
        self,
        dashboard_repository: IDashboardRepository,
        user_repository: IUserRepository
    ):
        self._dashboard_repository = dashboard_repository
        self._user_repository = user_repository
    
    async def execute(self, current_user_id: int) -> DashboardListResponse:
        """Get all dashboards with user permissions"""
        
        current_user = await self._user_repository.get_by_id(current_user_id)
        if not current_user:
            raise ValueError("User not found")
        
        dashboards = await self._dashboard_repository.get_all()
        total = await self._dashboard_repository.count_total()
        
        # Extract unique categories
        categories = list(set(d.categoria for d in dashboards))
        
        # Convert to response DTOs with permissions
        dashboard_responses = []
        for dashboard in dashboards:
            response = DashboardResponse(
                id=dashboard.id,
                titulo=dashboard.titulo,
                url_acceso=dashboard.url_acceso,
                categoria=dashboard.categoria,
                subcategoria=dashboard.subcategoria or "",
                descripcion=dashboard.descripcion or "",
                url_imagen_preview=dashboard.url_imagen_preview,
                created_by=dashboard.created_by,
                created_date=dashboard.created_date,
                can_edit=dashboard.can_be_edited_by(current_user.id, current_user.is_admin),
                can_delete=dashboard.can_be_deleted_by(current_user.id, current_user.is_admin)
            )
            dashboard_responses.append(response)
        
        return DashboardListResponse(
            dashboards=dashboard_responses,
            total=total,
            categories=sorted(categories)
        )


class CreateDashboardUseCase:
    def __init__(
        self,
        dashboard_repository: IDashboardRepository,
        file_storage_service: IFileStorageService
    ):
        self._dashboard_repository = dashboard_repository
        self._file_storage_service = file_storage_service
    
    async def execute(
        self, 
        request: CreateDashboardRequest, 
        screenshot_content: Optional[bytes],
        screenshot_filename: Optional[str],
        current_user_id: int
    ) -> DashboardResponse:
        """Create new dashboard"""
        
        # Handle file upload
        url_imagen_preview = None
        if screenshot_content and screenshot_filename:
            # Validate file
            if not self._file_storage_service.validate_file(
                screenshot_filename, 
                len(screenshot_content),
                ['png', 'jpg', 'jpeg', 'gif', 'webp']
            ):
                raise ValueError("Invalid image file")
            
            # Save file
            url_imagen_preview = await self._file_storage_service.save_file(
                screenshot_content, 
                screenshot_filename,
                "images"
            )
        
        # Create dashboard entity
        dashboard = Dashboard(
            id=None,
            titulo=request.titulo,
            url_acceso=request.url_acceso,
            categoria=request.categoria,
            subcategoria=request.subcategoria,
            descripcion=request.descripcion,
            url_imagen_preview=url_imagen_preview,
            created_by=current_user_id,
            created_date=None
        )
        
        # Save to repository
        created_dashboard = await self._dashboard_repository.create(dashboard)
        
        return DashboardResponse(
            id=created_dashboard.id,
            titulo=created_dashboard.titulo,
            url_acceso=created_dashboard.url_acceso,
            categoria=created_dashboard.categoria,
            subcategoria=created_dashboard.subcategoria or "",
            descripcion=created_dashboard.descripcion or "",
            url_imagen_preview=created_dashboard.url_imagen_preview,
            created_by=created_dashboard.created_by,
            created_date=created_dashboard.created_date,
            can_edit=True,
            can_delete=True
        )


class UpdateDashboardUseCase:
    def __init__(
        self,
        dashboard_repository: IDashboardRepository,
        user_repository: IUserRepository,
        file_storage_service: IFileStorageService
    ):
        self._dashboard_repository = dashboard_repository
        self._user_repository = user_repository
        self._file_storage_service = file_storage_service
    
    async def execute(
        self,
        dashboard_id: int,
        request: UpdateDashboardRequest,
        screenshot_content: Optional[bytes],
        screenshot_filename: Optional[str],
        current_user_id: int
    ) -> DashboardResponse:
        """Update existing dashboard"""
        
        # Get current user and dashboard
        current_user = await self._user_repository.get_by_id(current_user_id)
        if not current_user:
            raise ValueError("User not found")
        
        dashboard = await self._dashboard_repository.get_by_id(dashboard_id)
        if not dashboard:
            raise ValueError("Dashboard not found")
        
        # Check permissions
        if not dashboard.can_be_edited_by(current_user.id, current_user.is_admin):
            raise ValueError("Insufficient permissions to edit dashboard")
        
        # Update fields
        if request.titulo is not None:
            dashboard.titulo = request.titulo
        if request.url_acceso is not None:
            dashboard.url_acceso = request.url_acceso
        if request.categoria is not None:
            dashboard.categoria = request.categoria
        if request.subcategoria is not None:
            dashboard.subcategoria = request.subcategoria
        if request.descripcion is not None:
            dashboard.descripcion = request.descripcion
        
        # Handle file upload
        if screenshot_content and screenshot_filename:
            # Validate file
            if not self._file_storage_service.validate_file(
                screenshot_filename, 
                len(screenshot_content),
                ['png', 'jpg', 'jpeg', 'gif', 'webp']
            ):
                raise ValueError("Invalid image file")
            
            # Delete old image
            if dashboard.url_imagen_preview:
                await self._file_storage_service.delete_file(dashboard.url_imagen_preview)
            
            # Save new file
            dashboard.url_imagen_preview = await self._file_storage_service.save_file(
                screenshot_content, 
                screenshot_filename,
                "images"
            )
        
        # Save changes
        updated_dashboard = await self._dashboard_repository.update(dashboard)
        
        return DashboardResponse(
            id=updated_dashboard.id,
            titulo=updated_dashboard.titulo,
            url_acceso=updated_dashboard.url_acceso,
            categoria=updated_dashboard.categoria,
            subcategoria=updated_dashboard.subcategoria or "",
            descripcion=updated_dashboard.descripcion or "",
            url_imagen_preview=updated_dashboard.url_imagen_preview,
            created_by=updated_dashboard.created_by,
            created_date=updated_dashboard.created_date,
            can_edit=updated_dashboard.can_be_edited_by(current_user.id, current_user.is_admin),
            can_delete=updated_dashboard.can_be_deleted_by(current_user.id, current_user.is_admin)
        )


class DeleteDashboardUseCase:
    def __init__(
        self,
        dashboard_repository: IDashboardRepository,
        user_repository: IUserRepository,
        file_storage_service: IFileStorageService
    ):
        self._dashboard_repository = dashboard_repository
        self._user_repository = user_repository
        self._file_storage_service = file_storage_service
    
    async def execute(self, dashboard_id: int, current_user_id: int) -> bool:
        """Delete dashboard"""
        
        # Get current user and dashboard
        current_user = await self._user_repository.get_by_id(current_user_id)
        if not current_user:
            raise ValueError("User not found")
        
        dashboard = await self._dashboard_repository.get_by_id(dashboard_id)
        if not dashboard:
            raise ValueError("Dashboard not found")
        
        # Check permissions (admin only for deletion)
        if not current_user.is_admin:
            raise ValueError("Only administrators can delete dashboards")
        
        # Delete associated image
        if dashboard.url_imagen_preview:
            await self._file_storage_service.delete_file(dashboard.url_imagen_preview)
        
        # Delete dashboard
        return await self._dashboard_repository.delete(dashboard_id)


class GetDashboardStatsUseCase:
    def __init__(
        self,
        dashboard_repository: IDashboardRepository,
        user_repository: IUserRepository
    ):
        self._dashboard_repository = dashboard_repository
        self._user_repository = user_repository
    
    async def execute(self) -> DashboardStatsResponse:
        """Get dashboard system statistics"""
        
        total_dashboards = await self._dashboard_repository.count_total()
        active_users = await self._user_repository.count_active_users()
        
        # Get all dashboards to calculate category counts
        dashboards = await self._dashboard_repository.get_all()
        category_counts = {}
        categories = set()
        
        for dashboard in dashboards:
            category = dashboard.categoria
            categories.add(category)
            category_counts[category] = category_counts.get(category, 0) + 1
        
        return DashboardStatsResponse(
            total_dashboards=total_dashboards,
            active_users=active_users,
            departments=len(categories),
            category_counts=category_counts
        )


class GetRecentUpdatesUseCase:
    def __init__(self, dashboard_repository: IDashboardRepository):
        self._dashboard_repository = dashboard_repository
    
    async def execute(self, limit: int = 5) -> List[RecentDashboardResponse]:
        """Get recent dashboard updates"""
        
        dashboards = await self._dashboard_repository.get_recent_updates(limit)
        
        return [
            RecentDashboardResponse(
                titulo=dashboard.titulo,
                categoria=dashboard.categoria,
                created_date=dashboard.created_date
            )
            for dashboard in dashboards
        ]


class GetFeaturedDashboardsUseCase:
    def __init__(self, dashboard_repository: IDashboardRepository):
        self._dashboard_repository = dashboard_repository
    
    async def execute(self, limit: int = 3) -> List[FeaturedDashboardResponse]:
        """Get featured dashboards from different categories"""
        
        priority_categories = ['Operations', 'Finance', 'Workshop', 'Human Resources', 'Accounting']
        
        dashboards = await self._dashboard_repository.get_featured_by_categories(
            priority_categories, 
            limit
        )
        
        return [
            FeaturedDashboardResponse(
                id=dashboard.id,
                titulo=dashboard.titulo,
                descripcion=dashboard.descripcion or "",
                categoria=dashboard.categoria
            )
            for dashboard in dashboards
        ]