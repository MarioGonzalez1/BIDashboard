from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError
import traceback
import logging
from typing import Dict, Any


# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ErrorHandler:
    """Centralized error handling middleware"""
    
    @staticmethod
    async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
        """Handle HTTP exceptions"""
        
        logger.warning(
            f"HTTP {exc.status_code} error on {request.method} {request.url}: {exc.detail}"
        )
        
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": {
                    "type": "HTTPException",
                    "message": exc.detail,
                    "status_code": exc.status_code
                }
            }
        )
    
    @staticmethod
    async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
        """Handle request validation errors"""
        
        error_details = []
        for error in exc.errors():
            error_details.append({
                "field": " -> ".join(str(x) for x in error["loc"]),
                "message": error["msg"],
                "type": error["type"]
            })
        
        logger.warning(
            f"Validation error on {request.method} {request.url}: {error_details}"
        )
        
        return JSONResponse(
            status_code=422,
            content={
                "error": {
                    "type": "ValidationError",
                    "message": "Request validation failed",
                    "details": error_details
                }
            }
        )
    
    @staticmethod
    async def pydantic_validation_exception_handler(request: Request, exc: ValidationError) -> JSONResponse:
        """Handle Pydantic validation errors"""
        
        error_details = []
        for error in exc.errors():
            error_details.append({
                "field": " -> ".join(str(x) for x in error["loc"]),
                "message": error["msg"],
                "type": error["type"]
            })
        
        logger.warning(
            f"Pydantic validation error on {request.method} {request.url}: {error_details}"
        )
        
        return JSONResponse(
            status_code=422,
            content={
                "error": {
                    "type": "ValidationError",
                    "message": "Data validation failed",
                    "details": error_details
                }
            }
        )
    
    @staticmethod
    async def value_error_handler(request: Request, exc: ValueError) -> JSONResponse:
        """Handle ValueError exceptions (business logic errors)"""
        
        logger.warning(
            f"Business logic error on {request.method} {request.url}: {str(exc)}"
        )
        
        return JSONResponse(
            status_code=400,
            content={
                "error": {
                    "type": "BusinessError",
                    "message": str(exc)
                }
            }
        )
    
    @staticmethod
    async def permission_error_handler(request: Request, exc: PermissionError) -> JSONResponse:
        """Handle PermissionError exceptions"""
        
        logger.warning(
            f"Permission error on {request.method} {request.url}: {str(exc)}"
        )
        
        return JSONResponse(
            status_code=403,
            content={
                "error": {
                    "type": "PermissionError",
                    "message": str(exc) or "Insufficient permissions"
                }
            }
        )
    
    @staticmethod
    async def general_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        """Handle all other exceptions"""
        
        error_id = f"error_{request.method}_{hash(str(request.url))}"
        
        logger.error(
            f"Unexpected error {error_id} on {request.method} {request.url}: {str(exc)}"
        )
        logger.error(f"Traceback: {traceback.format_exc()}")
        
        # Don't expose internal errors in production
        import os
        is_debug = os.getenv("DEBUG", "false").lower() == "true"
        
        if is_debug:
            return JSONResponse(
                status_code=500,
                content={
                    "error": {
                        "type": "InternalServerError",
                        "message": str(exc),
                        "error_id": error_id,
                        "traceback": traceback.format_exc().split('\n')
                    }
                }
            )
        else:
            return JSONResponse(
                status_code=500,
                content={
                    "error": {
                        "type": "InternalServerError",
                        "message": "An internal server error occurred",
                        "error_id": error_id
                    }
                }
            )
    
    @staticmethod
    def get_error_handlers() -> Dict[Any, Any]:
        """Get all error handlers for FastAPI app registration"""
        
        return {
            HTTPException: ErrorHandler.http_exception_handler,
            RequestValidationError: ErrorHandler.validation_exception_handler,
            ValidationError: ErrorHandler.pydantic_validation_exception_handler,
            ValueError: ErrorHandler.value_error_handler,
            PermissionError: ErrorHandler.permission_error_handler,
            Exception: ErrorHandler.general_exception_handler
        }