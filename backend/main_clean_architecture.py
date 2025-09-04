"""
BIDashboard - Clean Architecture Implementation
Enhanced FastAPI application with JWT security and Clean Architecture principles
"""

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from pydantic import ValidationError

# Import controllers
from presentation.controllers.auth_controller import router as auth_router
from presentation.controllers.dashboard_controller import router as dashboard_router

# Import middleware and error handlers
from presentation.middleware.error_handler import ErrorHandler

# Import configuration
from database_config import DATABASE_INFO

# Configuration
STATIC_DIR = "static"
IMAGES_DIR = os.path.join(STATIC_DIR, "images")

# Create directories if they don't exist
os.makedirs(IMAGES_DIR, exist_ok=True)

# Create FastAPI app with enhanced metadata
app = FastAPI(
    title=f"BI Dashboard Portal API - Clean Architecture - {DATABASE_INFO['database_type'].upper()} Edition",
    description=f"""
    ## Business Intelligence Dashboard Portal
    
    **Clean Architecture Implementation with Enhanced Security**
    
    ### Features:
    - **JWT Authentication** with refresh tokens and blacklisting
    - **Role-based Authorization** (Admin/User)
    - **Multi-database Support** (SQLite, PostgreSQL, SQL Server)
    - **File Upload Security** with validation and sanitization
    - **Comprehensive Error Handling** with detailed logging
    - **Clean Architecture** with proper separation of concerns
    - **Input Validation** with Pydantic models
    - **CORS Security** with configurable origins
    
    ### Database:
    Currently connected to: **{DATABASE_INFO['database_type'].upper()}** database
    Status: {'✅ Connected' if DATABASE_INFO['connected'] else '❌ Disconnected'}
    
    ### Security:
    - Passwords hashed with bcrypt (12 rounds)
    - JWT tokens with HS256 algorithm
    - Token expiration: 30 minutes (access), 7 days (refresh)
    - File upload validation and path traversal protection
    - SQL injection protection through ORM
    - XSS prevention through proper serialization
    
    ### Default Admin Credentials:
    - Username: `mario.gonzalez`
    - Password: `ChangeMe2024!`
    """,
    version="2.0.0",
    contact={
        "name": "Mario Gonzalez",
        "email": "mario.gonzalez@forzatrans.com"
    },
    license_info={
        "name": "MIT License",
        "url": "https://opensource.org/licenses/MIT"
    }
)

# Security Headers Middleware
@app.middleware("http")
async def add_security_headers(request, call_next):
    """Add security headers to all responses"""
    response = await call_next(request)
    
    # Security headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
    
    # Remove server information
    response.headers.pop("server", None)
    
    return response

# CORS Middleware with enhanced security
allowed_origins = [
    "http://localhost:4200",  # Angular dev server
    "http://localhost:4201",  # Alternative port
    "http://127.0.0.1:4200",  # Local dev
    "http://127.0.0.1:4201",  # Alternative local
]

# Add production URLs from environment
production_urls = os.getenv("ALLOWED_ORIGINS", "").split(",")
for url in production_urls:
    if url.strip():
        allowed_origins.append(url.strip())

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=[
        "Authorization", 
        "Content-Type", 
        "Accept", 
        "Origin", 
        "X-Requested-With"
    ],
    expose_headers=["X-Total-Count", "X-Page-Count"]
)

# Register Error Handlers
error_handlers = ErrorHandler.get_error_handlers()
for exception_type, handler in error_handlers.items():
    app.add_exception_handler(exception_type, handler)

# Mount Static Files (with security considerations)
if os.path.exists(STATIC_DIR):
    app.mount(f"/{STATIC_DIR}", StaticFiles(directory=STATIC_DIR), name=STATIC_DIR)

# Register API Routes
app.include_router(auth_router)
app.include_router(dashboard_router)

# Legacy routes for backward compatibility (redirect to new endpoints)
@app.post("/api/login")
async def legacy_login_redirect():
    """Redirect to new auth endpoint"""
    return JSONResponse(
        status_code=301,
        content={"message": "Endpoint moved", "new_endpoint": "/api/auth/login"},
        headers={"Location": "/api/auth/login"}
    )

@app.post("/api/register")
async def legacy_register_redirect():
    """Redirect to new auth endpoint"""
    return JSONResponse(
        status_code=301,
        content={"message": "Endpoint moved", "new_endpoint": "/api/auth/register"},
        headers={"Location": "/api/auth/register"}
    )

@app.get("/api/me")
async def legacy_me_redirect():
    """Redirect to new auth endpoint"""
    return JSONResponse(
        status_code=301,
        content={"message": "Endpoint moved", "new_endpoint": "/api/auth/me"},
        headers={"Location": "/api/auth/me"}
    )

@app.get("/api/tableros")
async def legacy_dashboards_redirect():
    """Redirect to new dashboards endpoint"""
    return JSONResponse(
        status_code=301,
        content={"message": "Endpoint moved", "new_endpoint": "/api/dashboards"},
        headers={"Location": "/api/dashboards"}
    )

# Root endpoint with API information
@app.get("/", tags=["Root"])
async def root():
    """API root endpoint with system information"""
    return {
        "message": "BI Dashboard Portal API - Clean Architecture",
        "version": "2.0.0",
        "database": {
            "type": DATABASE_INFO['database_type'].upper(),
            "status": "Connected" if DATABASE_INFO['connected'] else "Disconnected"
        },
        "architecture": "Clean Architecture with Domain-Driven Design",
        "security": {
            "authentication": "JWT with refresh tokens",
            "authorization": "Role-based (Admin/User)",
            "password_hashing": "bcrypt (12 rounds)",
            "token_algorithm": "HS256"
        },
        "documentation": {
            "swagger_ui": "/docs",
            "redoc": "/redoc",
            "openapi_json": "/openapi.json"
        },
        "endpoints": {
            "auth": "/api/auth",
            "dashboards": "/api/dashboards",
            "static_files": "/static"
        }
    }

# Health check endpoint
@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint for monitoring"""
    
    # Check database connection
    db_status = "healthy" if DATABASE_INFO['connected'] else "unhealthy"
    
    # Check static files directory
    static_status = "healthy" if os.path.exists(STATIC_DIR) else "unhealthy"
    
    overall_status = "healthy" if db_status == "healthy" and static_status == "healthy" else "unhealthy"
    
    return {
        "status": overall_status,
        "timestamp": __import__('datetime').datetime.utcnow().isoformat(),
        "version": "2.0.0",
        "components": {
            "database": {
                "status": db_status,
                "type": DATABASE_INFO['database_type']
            },
            "static_files": {
                "status": static_status,
                "path": STATIC_DIR
            }
        }
    }

# Database info endpoint  
@app.get("/api/database/info", tags=["System"])
async def get_database_info():
    """Get current database configuration information"""
    return {
        "database_type": DATABASE_INFO['database_type'],
        "connected": DATABASE_INFO['connected'],
        "message": f"Connected to {DATABASE_INFO['database_type'].upper()} database",
        "architecture": "Clean Architecture with Repository Pattern"
    }

# System statistics endpoint (for backward compatibility)
@app.get("/api/system/stats", tags=["System"])
async def get_system_stats_legacy():
    """Legacy system stats endpoint - redirects to new endpoint"""
    return JSONResponse(
        status_code=301,
        content={"message": "Endpoint moved", "new_endpoint": "/api/dashboards/stats"},
        headers={"Location": "/api/dashboards/stats"}
    )

@app.get("/api/system/recent-updates", tags=["System"])
async def get_recent_updates_legacy():
    """Legacy recent updates endpoint - redirects to new endpoint"""
    return JSONResponse(
        status_code=301,
        content={"message": "Endpoint moved", "new_endpoint": "/api/dashboards/recent"},
        headers={"Location": "/api/dashboards/recent"}
    )

@app.get("/api/system/featured-dashboards", tags=["System"])
async def get_featured_dashboards_legacy():
    """Legacy featured dashboards endpoint - redirects to new endpoint"""
    return JSONResponse(
        status_code=301,
        content={"message": "Endpoint moved", "new_endpoint": "/api/dashboards/featured"},
        headers={"Location": "/api/dashboards/featured"}
    )

if __name__ == "__main__":
    import uvicorn
    
    # Development server configuration
    uvicorn.run(
        "main_clean_architecture:app",
        host="127.0.0.1",
        port=8000,
        reload=True,
        log_level="info",
        reload_dirs=["./"],
        reload_excludes=["venv/", "*.db", "static/"]
    )