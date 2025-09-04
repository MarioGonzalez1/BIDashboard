# BIDashboard - Clean Architecture Implementation

## Overview

This is a complete refactor of the BIDashboard backend using **Clean Architecture** principles with enhanced **JWT security**. The application maintains backward compatibility while providing a much more robust, scalable, and secure foundation.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Controllers │  │ Middleware  │  │   Error Handlers    │ │
│  │   FastAPI   │  │    Auth     │  │   Validation       │ │
│  │   Routes    │  │   CORS      │  │   Logging          │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   APPLICATION LAYER                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Use Cases   │  │    DTOs     │  │    Services         │ │
│  │  Business   │  │ Validation  │  │   Orchestration     │ │
│  │   Logic     │  │  Models     │  │     Layer          │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                     DOMAIN LAYER                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  Entities   │  │ Interfaces  │  │  Business Rules     │ │
│  │   Models    │  │ Contracts   │  │     Logic          │ │
│  │   Domain    │  │  Abstract   │  │   Validation       │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                 INFRASTRUCTURE LAYER                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Repositories│  │  Security   │  │   External APIs     │ │
│  │  Database   │  │     JWT     │  │   File Storage     │ │
│  │   Access    │  │  Password   │  │      Email         │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

### 🔐 Enhanced Security
- **JWT Authentication** with access and refresh tokens
- **Token Blacklisting** for secure logout
- **Bcrypt Password Hashing** (12 rounds)
- **Role-based Authorization** (Admin/User)
- **File Upload Security** with validation and sanitization
- **CORS Protection** with configurable origins
- **Security Headers** middleware
- **SQL Injection Protection** through ORM

### 🏗️ Clean Architecture
- **Domain-Driven Design** with clear boundaries
- **Dependency Injection** container
- **Repository Pattern** for data access
- **Use Cases** for business logic
- **DTOs** for data transfer
- **Interface Segregation** principle

### 🛡️ Robust Error Handling
- **Centralized Error Handler** with detailed logging
- **Validation Errors** with field-specific messages
- **Business Logic Errors** with meaningful responses
- **Security Errors** without information leakage
- **Health Check** endpoint for monitoring

## Project Structure

```
backend/
├── domain/                          # Domain layer (core business logic)
│   ├── entities/                    # Business entities
│   │   ├── user.py                  # User domain model
│   │   ├── dashboard.py             # Dashboard domain model
│   │   └── employee.py              # Employee domain model
│   └── interfaces/                  # Abstract interfaces
│       ├── repositories.py          # Repository contracts
│       └── security.py              # Security service contracts
│
├── application/                     # Application layer (use cases)
│   ├── dtos/                        # Data Transfer Objects
│   │   ├── auth_dtos.py            # Authentication DTOs
│   │   ├── dashboard_dtos.py       # Dashboard DTOs
│   │   └── employee_dtos.py        # Employee DTOs
│   └── use_cases/                   # Business use cases
│       ├── auth_use_cases.py       # Authentication use cases
│       └── dashboard_use_cases.py  # Dashboard use cases
│
├── infrastructure/                  # Infrastructure layer (implementation)
│   ├── database/                    # Data access implementation
│   │   └── repositories.py         # Repository implementations
│   ├── security/                    # Security implementations
│   │   ├── password_hasher.py      # Password hashing
│   │   ├── jwt_service.py          # JWT token management
│   │   ├── auth_service.py         # Authentication service
│   │   └── file_storage_service.py # File storage service
│   └── di_container.py             # Dependency injection container
│
├── presentation/                    # Presentation layer (API)
│   ├── controllers/                 # API controllers
│   │   ├── auth_controller.py      # Authentication endpoints
│   │   └── dashboard_controller.py # Dashboard endpoints
│   └── middleware/                  # HTTP middleware
│       ├── auth_middleware.py      # Authentication middleware
│       └── error_handler.py        # Error handling middleware
│
├── main_clean_architecture.py      # Main application (Clean Architecture)
├── main.py                         # Original application (backward compatibility)
├── requirements_clean.txt          # Dependencies for Clean Architecture
└── CLEAN_ARCHITECTURE_README.md   # This documentation
```

## Getting Started

### 1. Install Dependencies

```bash
pip install -r requirements_clean.txt
```

### 2. Environment Configuration

Create a `.env` file with the following variables:

```bash
# Database Configuration
DATABASE_TYPE=sqlite  # or 'postgres' or 'mssql'
DATABASE_URL=sqlite:///./bidashboard.db

# Security Configuration
SECRET_KEY=your-super-secret-key-change-in-production
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# CORS Configuration
ALLOWED_ORIGINS=http://localhost:4200,http://localhost:4201

# File Upload Configuration
MAX_FILE_SIZE=10485760  # 10MB in bytes
UPLOAD_DIRECTORY=static

# Development Configuration
DEBUG=true
```

### 3. Run the Application

#### Clean Architecture Version (Recommended)
```bash
python main_clean_architecture.py
```

#### Original Version (Backward Compatibility)
```bash
python main.py
```

### 4. Access the API

- **API Documentation**: http://127.0.0.1:8000/docs
- **Health Check**: http://127.0.0.1:8000/health
- **Database Info**: http://127.0.0.1:8000/api/database/info

## API Endpoints

### Authentication (`/api/auth`)
- `POST /api/auth/login` - User login
- `POST /api/auth/register` - User registration  
- `GET /api/auth/me` - Current user information
- `POST /api/auth/refresh` - Refresh access token
- `POST /api/auth/logout` - Logout and revoke tokens
- `POST /api/auth/change-password` - Change password

### Dashboards (`/api/dashboards`)
- `GET /api/dashboards` - List all dashboards
- `POST /api/dashboards` - Create new dashboard
- `PUT /api/dashboards/{id}` - Update dashboard
- `DELETE /api/dashboards/{id}` - Delete dashboard (admin only)
- `GET /api/dashboards/stats` - System statistics
- `GET /api/dashboards/recent` - Recent updates
- `GET /api/dashboards/featured` - Featured dashboards

### System (`/api/system`)
- `GET /health` - Health check
- `GET /api/database/info` - Database information

## Security Implementation

### JWT Token Structure

**Access Token Payload:**
```json
{
  "sub": "123",           // User ID
  "username": "john_doe", // Username
  "is_admin": false,      // Admin flag
  "type": "access",       // Token type
  "iat": 1699123456,      // Issued at
  "exp": 1699125256,      // Expires at (30 min)
  "nbf": 1699123456,      // Not before
  "jti": "access_123_1699123456"  // JWT ID for revocation
}
```

**Refresh Token Payload:**
```json
{
  "sub": "123",           // User ID
  "username": "john_doe", // Username
  "type": "refresh",      // Token type
  "iat": 1699123456,      // Issued at
  "exp": 1699728256,      // Expires at (7 days)
  "nbf": 1699123456,      // Not before
  "jti": "refresh_123_1699123456"  // JWT ID for revocation
}
```

### Password Security
- **Algorithm**: bcrypt with 12 salt rounds
- **Validation**: Minimum 8 characters, uppercase, lowercase, number
- **Storage**: Only hashed passwords stored in database

### File Upload Security
- **Size Limit**: 10MB maximum
- **Type Validation**: Only allowed image formats (png, jpg, jpeg, gif, webp)
- **Path Traversal Protection**: Filename sanitization
- **Virus Scanning**: Ready for integration (implement as needed)

## Default Credentials

The system comes with a default admin user:

- **Username**: `mario.gonzalez`
- **Password**: `ChangeMe2024!`
- **Role**: Administrator

**⚠️ IMPORTANT**: Change the default password after first login!

## Migration from Original Architecture

The Clean Architecture implementation is fully backward compatible. You can:

1. **Run both versions** simultaneously on different ports
2. **Migrate gradually** by updating frontend endpoints
3. **Use legacy endpoints** (they redirect to new endpoints)

### Legacy Endpoint Mappings

| Original Endpoint | New Endpoint |
|---|---|
| `POST /api/login` | `POST /api/auth/login` |
| `POST /api/register` | `POST /api/auth/register` |
| `GET /api/me` | `GET /api/auth/me` |
| `GET /api/tableros` | `GET /api/dashboards` |
| `GET /api/system/stats` | `GET /api/dashboards/stats` |

## Testing

### Manual Testing
```bash
# Health check
curl http://127.0.0.1:8000/health

# Login
curl -X POST "http://127.0.0.1:8000/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "mario.gonzalez", "password": "ChangeMe2024!"}'

# Get dashboards (with token)
curl "http://127.0.0.1:8000/api/dashboards" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Automated Testing
```bash
# Run tests (when test files are created)
pytest tests/

# With coverage
pytest --cov=. tests/
```

## Monitoring and Maintenance

### Health Monitoring
- Monitor `/health` endpoint for system status
- Check database connectivity and static file availability
- Set up alerts for unhealthy status

### Security Maintenance
- **Rotate JWT secret keys** regularly
- **Monitor failed login attempts** for brute force attacks
- **Update dependencies** regularly for security patches
- **Review access logs** for suspicious activity

### Performance Optimization
- **Database Indexing**: Ensure proper indexes on frequently queried columns
- **Connection Pooling**: Configure database connection pooling
- **Caching**: Implement Redis for token blacklisting in production
- **File Storage**: Consider cloud storage (S3, Azure Blob) for production

## Production Deployment

### Environment Variables
```bash
# Production configuration
DEBUG=false
SECRET_KEY=generate-a-strong-secret-key-32-chars-min
DATABASE_URL=postgresql://user:pass@host:port/db
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com

# Security headers (optional)
HSTS_MAX_AGE=31536000
CSP_POLICY="default-src 'self'"
```

### Deployment Checklist
- [ ] Generate strong SECRET_KEY (32+ characters)
- [ ] Configure production database
- [ ] Set up HTTPS/TLS
- [ ] Configure CORS for production domains
- [ ] Set up monitoring and logging
- [ ] Configure backup strategy
- [ ] Set up CI/CD pipeline
- [ ] Implement rate limiting
- [ ] Configure reverse proxy (nginx/apache)
- [ ] Set up SSL certificates

### Docker Deployment (Optional)

Create `Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements_clean.txt .
RUN pip install -r requirements_clean.txt

COPY . .
EXPOSE 8000

CMD ["uvicorn", "main_clean_architecture:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Contributing

When contributing to this codebase, please follow these principles:

1. **Maintain Clean Architecture** boundaries
2. **Write tests** for new functionality
3. **Update documentation** for API changes
4. **Follow security best practices**
5. **Use proper error handling**
6. **Validate all inputs** with Pydantic models

## Support

For questions or issues:

1. Check the API documentation at `/docs`
2. Review this README
3. Check the health endpoint `/health`
4. Enable debug mode for detailed error messages

## License

MIT License - see LICENSE file for details.