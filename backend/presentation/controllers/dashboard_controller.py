from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile, Form
from sqlalchemy.orm import Session
from typing import Dict, Any, Optional, List

from ...application.dtos.dashboard_dtos import (
    CreateDashboardRequest, UpdateDashboardRequest, DashboardResponse,
    DashboardListResponse, DashboardStatsResponse, RecentDashboardResponse,
    FeaturedDashboardResponse
)
from ...infrastructure.di_container import container
from ..middleware.auth_middleware import get_current_user, get_current_admin_user
from ...database_config import get_db


router = APIRouter(prefix="/api/dashboards", tags=["Dashboards"])


@router.get("", response_model=DashboardListResponse)
async def get_all_dashboards(
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all dashboards with user permissions"""
    
    try:
        get_dashboards_use_case = container.get_factory('get_all_dashboards_use_case')(db)
        dashboard_response = await get_dashboards_use_case.execute(current_user["user_id"])
        return dashboard_response
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve dashboards: {str(e)}"
        )


@router.post("", response_model=DashboardResponse)
async def create_dashboard(
    titulo: str = Form(...),
    url_acceso: str = Form(...),
    categoria: str = Form(...),
    subcategoria: str = Form(""),
    descripcion: str = Form(""),
    screenshot: UploadFile = File(...),
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create new dashboard"""
    
    try:
        # Create request DTO
        create_request = CreateDashboardRequest(
            titulo=titulo,
            url_acceso=url_acceso,
            categoria=categoria,
            subcategoria=subcategoria,
            descripcion=descripcion
        )
        
        # Read file content
        screenshot_content = None
        screenshot_filename = None
        
        if screenshot and screenshot.filename:
            screenshot_content = await screenshot.read()
            screenshot_filename = screenshot.filename
        
        # Execute use case
        create_dashboard_use_case = container.get_factory('create_dashboard_use_case')(db)
        dashboard_response = await create_dashboard_use_case.execute(
            request=create_request,
            screenshot_content=screenshot_content,
            screenshot_filename=screenshot_filename,
            current_user_id=current_user["user_id"]
        )
        
        return dashboard_response
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create dashboard: {str(e)}"
        )


@router.put("/{dashboard_id}", response_model=DashboardResponse)
async def update_dashboard(
    dashboard_id: int,
    titulo: Optional[str] = Form(None),
    url_acceso: Optional[str] = Form(None),
    categoria: Optional[str] = Form(None),
    subcategoria: Optional[str] = Form(None),
    descripcion: Optional[str] = Form(None),
    screenshot: Optional[UploadFile] = File(None),
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update existing dashboard"""
    
    try:
        # Create request DTO
        update_request = UpdateDashboardRequest(
            titulo=titulo,
            url_acceso=url_acceso,
            categoria=categoria,
            subcategoria=subcategoria,
            descripcion=descripcion
        )
        
        # Read file content
        screenshot_content = None
        screenshot_filename = None
        
        if screenshot and screenshot.filename:
            screenshot_content = await screenshot.read()
            screenshot_filename = screenshot.filename
        
        # Execute use case
        update_dashboard_use_case = container.get_factory('update_dashboard_use_case')(db)
        dashboard_response = await update_dashboard_use_case.execute(
            dashboard_id=dashboard_id,
            request=update_request,
            screenshot_content=screenshot_content,
            screenshot_filename=screenshot_filename,
            current_user_id=current_user["user_id"]
        )
        
        return dashboard_response
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update dashboard: {str(e)}"
        )


@router.delete("/{dashboard_id}")
async def delete_dashboard(
    dashboard_id: int,
    current_admin: Dict[str, Any] = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Delete dashboard (admin only)"""
    
    try:
        delete_dashboard_use_case = container.get_factory('delete_dashboard_use_case')(db)
        success = await delete_dashboard_use_case.execute(
            dashboard_id=dashboard_id,
            current_user_id=current_admin["user_id"]
        )
        
        if success:
            return {"message": "Dashboard deleted successfully"}
        else:
            raise ValueError("Failed to delete dashboard")
            
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete dashboard: {str(e)}"
        )


@router.get("/stats", response_model=DashboardStatsResponse)
async def get_dashboard_stats(
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get dashboard system statistics"""
    
    try:
        get_stats_use_case = container.get_factory('get_dashboard_stats_use_case')(db)
        stats_response = await get_stats_use_case.execute()
        return stats_response
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve statistics: {str(e)}"
        )


@router.get("/recent", response_model=List[RecentDashboardResponse])
async def get_recent_updates(
    limit: int = 5,
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get recent dashboard updates"""
    
    try:
        get_recent_use_case = container.get_factory('get_recent_updates_use_case')(db)
        recent_response = await get_recent_use_case.execute(limit)
        return recent_response
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve recent updates: {str(e)}"
        )


@router.get("/featured", response_model=List[FeaturedDashboardResponse])
async def get_featured_dashboards(
    limit: int = 3,
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get featured dashboards from different categories"""
    
    try:
        get_featured_use_case = container.get_factory('get_featured_dashboards_use_case')(db)
        featured_response = await get_featured_use_case.execute(limit)
        return featured_response
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve featured dashboards: {str(e)}"
        )