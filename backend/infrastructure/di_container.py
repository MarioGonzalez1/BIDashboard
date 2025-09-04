from typing import Dict, Any, Callable
from sqlalchemy.orm import Session
import os

# Domain interfaces
from ..domain.interfaces.repositories import IUserRepository, IDashboardRepository, IEmployeeRepository
from ..domain.interfaces.security import IPasswordHasher, IJwtTokenService, IAuthenticationService, IFileStorageService

# Infrastructure implementations
from .database.repositories import UserRepository, DashboardRepository, EmployeeRepository
from .security.password_hasher import BcryptPasswordHasher
from .security.jwt_service import JwtTokenService
from .security.auth_service import AuthenticationService
from .security.file_storage_service import LocalFileStorageService

# Application use cases
from ..application.use_cases.auth_use_cases import (
    LoginUseCase, RegisterUseCase, GetCurrentUserUseCase, 
    ChangePasswordUseCase, RefreshTokenUseCase, LogoutUseCase
)
from ..application.use_cases.dashboard_use_cases import (
    GetAllDashboardsUseCase, CreateDashboardUseCase, UpdateDashboardUseCase,
    DeleteDashboardUseCase, GetDashboardStatsUseCase, GetRecentUpdatesUseCase,
    GetFeaturedDashboardsUseCase
)


class DIContainer:
    """Dependency Injection Container for Clean Architecture"""
    
    def __init__(self):
        self._services: Dict[str, Any] = {}
        self._singletons: Dict[str, Any] = {}
        self._factories: Dict[str, Callable] = {}
        self._setup_services()
    
    def _setup_services(self):
        """Setup all service registrations"""
        
        # Infrastructure Services (Singletons)
        self.register_singleton('password_hasher', lambda: BcryptPasswordHasher(rounds=12))
        
        self.register_singleton('jwt_service', lambda: JwtTokenService(
            secret_key=os.getenv("SECRET_KEY", "your-secret-key-here-change-in-production"),
            algorithm="HS256",
            access_token_expire_minutes=30,
            refresh_token_expire_days=7
        ))
        
        self.register_singleton('file_storage_service', lambda: LocalFileStorageService(
            base_path="static",
            max_file_size=10 * 1024 * 1024  # 10MB
        ))
        
        # Repository Factories (require DB session)
        self.register_factory('user_repository', lambda db: UserRepository(db))
        self.register_factory('dashboard_repository', lambda db: DashboardRepository(db))
        self.register_factory('employee_repository', lambda db: EmployeeRepository(db))
        
        # Service Factories
        self.register_factory('auth_service', lambda db: AuthenticationService(
            user_repository=self.get_factory('user_repository')(db),
            password_hasher=self.get_singleton('password_hasher')
        ))
        
        # Use Case Factories
        self._setup_use_cases()
    
    def _setup_use_cases(self):
        """Setup use case factories"""
        
        # Authentication Use Cases
        self.register_factory('login_use_case', lambda db: LoginUseCase(
            user_repository=self.get_factory('user_repository')(db),
            auth_service=self.get_factory('auth_service')(db),
            jwt_service=self.get_singleton('jwt_service')
        ))
        
        self.register_factory('register_use_case', lambda db: RegisterUseCase(
            user_repository=self.get_factory('user_repository')(db),
            auth_service=self.get_factory('auth_service')(db)
        ))
        
        self.register_factory('get_current_user_use_case', lambda db: GetCurrentUserUseCase(
            user_repository=self.get_factory('user_repository')(db)
        ))
        
        self.register_factory('change_password_use_case', lambda db: ChangePasswordUseCase(
            user_repository=self.get_factory('user_repository')(db),
            auth_service=self.get_factory('auth_service')(db)
        ))
        
        self.register_factory('refresh_token_use_case', lambda db: RefreshTokenUseCase(
            user_repository=self.get_factory('user_repository')(db),
            jwt_service=self.get_singleton('jwt_service')
        ))
        
        self.register_singleton('logout_use_case', lambda: LogoutUseCase(
            jwt_service=self.get_singleton('jwt_service')
        ))
        
        # Dashboard Use Cases
        self.register_factory('get_all_dashboards_use_case', lambda db: GetAllDashboardsUseCase(
            dashboard_repository=self.get_factory('dashboard_repository')(db),
            user_repository=self.get_factory('user_repository')(db)
        ))
        
        self.register_factory('create_dashboard_use_case', lambda db: CreateDashboardUseCase(
            dashboard_repository=self.get_factory('dashboard_repository')(db),
            file_storage_service=self.get_singleton('file_storage_service')
        ))
        
        self.register_factory('update_dashboard_use_case', lambda db: UpdateDashboardUseCase(
            dashboard_repository=self.get_factory('dashboard_repository')(db),
            user_repository=self.get_factory('user_repository')(db),
            file_storage_service=self.get_singleton('file_storage_service')
        ))
        
        self.register_factory('delete_dashboard_use_case', lambda db: DeleteDashboardUseCase(
            dashboard_repository=self.get_factory('dashboard_repository')(db),
            user_repository=self.get_factory('user_repository')(db),
            file_storage_service=self.get_singleton('file_storage_service')
        ))
        
        self.register_factory('get_dashboard_stats_use_case', lambda db: GetDashboardStatsUseCase(
            dashboard_repository=self.get_factory('dashboard_repository')(db),
            user_repository=self.get_factory('user_repository')(db)
        ))
        
        self.register_factory('get_recent_updates_use_case', lambda db: GetRecentUpdatesUseCase(
            dashboard_repository=self.get_factory('dashboard_repository')(db)
        ))
        
        self.register_factory('get_featured_dashboards_use_case', lambda db: GetFeaturedDashboardsUseCase(
            dashboard_repository=self.get_factory('dashboard_repository')(db)
        ))
    
    def register_singleton(self, name: str, factory: Callable):
        """Register a singleton service"""
        self._factories[name] = factory
    
    def register_factory(self, name: str, factory: Callable):
        """Register a factory service"""
        self._factories[name] = factory
    
    def get_singleton(self, name: str):
        """Get singleton instance"""
        if name not in self._singletons:
            if name not in self._factories:
                raise ValueError(f"Service '{name}' not registered")
            self._singletons[name] = self._factories[name]()
        return self._singletons[name]
    
    def get_factory(self, name: str):
        """Get factory function"""
        if name not in self._factories:
            raise ValueError(f"Factory '{name}' not registered")
        return self._factories[name]
    
    def get_service(self, name: str, *args, **kwargs):
        """Get service by name (singleton or factory)"""
        if name not in self._factories:
            raise ValueError(f"Service '{name}' not registered")
        
        # If no args provided, treat as singleton
        if not args and not kwargs:
            return self.get_singleton(name)
        else:
            return self._factories[name](*args, **kwargs)


# Global container instance
container = DIContainer()