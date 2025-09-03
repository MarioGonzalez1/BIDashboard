# BIDashboard SQL Server Database Documentation

## Table of Contents
1. [Overview](#overview)
2. [Database Architecture](#database-architecture)
3. [Installation Guide](#installation-guide)
4. [Schema Design](#schema-design)
5. [Security Implementation](#security-implementation)
6. [Performance Optimization](#performance-optimization)
7. [Backup & Recovery Strategy](#backup--recovery-strategy)
8. [Migration Guide](#migration-guide)
9. [API Integration](#api-integration)
10. [Maintenance Procedures](#maintenance-procedures)

## Overview

The BIDashboard database is a enterprise-grade SQL Server solution designed for a Business Intelligence Dashboard system. It provides robust data management for dashboards, user authentication, HR management, and comprehensive audit trails.

### Key Features
- **Normalized relational design** (3NF/BCNF)
- **Row-level security** (RLS) implementation
- **Complete audit trail** system
- **Optimized indexing** strategy
- **Automated backup** procedures
- **GDPR compliance** features

## Database Architecture

### Physical Architecture
```
BIDashboard Database
├── Primary Filegroup (100MB initial, 64MB growth)
│   └── Core tables and data
├── LOB_DATA Filegroup (500MB initial, 128MB growth)
│   └── Large objects (images, documents)
├── INDEXES Filegroup (50MB initial, 32MB growth)
│   └── Non-clustered indexes
└── Transaction Log (50MB initial, 10% growth)
```

### Logical Schemas
- **Security**: User authentication, roles, permissions
- **Dashboard**: BI dashboards, categories, access logs
- **HR**: Employee management, departments, positions
- **Audit**: Comprehensive audit logging
- **Config**: System configuration settings

## Installation Guide

### Prerequisites
- SQL Server 2019 or later (2022 recommended)
- Python 3.8+ with pip
- ODBC Driver 17 for SQL Server
- Minimum 2GB RAM, 10GB disk space

### Step 1: Create Database
```sql
-- Execute scripts in order:
1. 01_database_creation.sql
2. 02_tables_creation.sql
3. 03_indexes_performance.sql
4. 04_stored_procedures.sql
5. 05_initial_data.sql
6. 06_security_audit.sql
7. 07_backup_maintenance.sql
```

### Step 2: Configure Python Environment
```bash
# Install required packages
pip install pyodbc==5.0.0
pip install sqlalchemy==2.0.0
pip install python-dotenv==1.0.0

# Create .env file
cp .env.example .env
# Edit .env with your database credentials
```

### Step 3: Environment Variables (.env)
```env
# Database Configuration
DB_SERVER=localhost
DB_NAME=BIDashboard
DB_USERNAME=sa
DB_PASSWORD=YourStrongPassword!
DB_DRIVER=ODBC Driver 17 for SQL Server
DB_PORT=1433

# Connection Pool Settings
DB_POOL_SIZE=10
DB_MAX_OVERFLOW=20
DB_POOL_TIMEOUT=30
DB_POOL_RECYCLE=3600

# Application Settings
DB_ECHO_SQL=False
DB_AUTOCOMMIT=False
```

### Step 4: Run Migration
```bash
cd backend/database
python migration_script.py --json-file ../db.json
```

## Schema Design

### Core Tables

#### Security Schema
| Table | Purpose | Key Features |
|-------|---------|--------------|
| Users | User accounts | Bcrypt passwords, 2FA support, account lockout |
| Roles | System roles | Hierarchical, system vs custom roles |
| Permissions | Granular permissions | Resource-based access control |
| UserRoles | User-role mapping | Time-based role assignment |
| RefreshTokens | JWT session management | Token rotation, IP tracking |

#### Dashboard Schema
| Table | Purpose | Key Features |
|-------|---------|--------------|
| Dashboards | BI dashboard metadata | Versioning, categorization, access control |
| Categories | Hierarchical categorization | Parent-child relationships |
| AccessLog | Usage analytics | Session tracking, duration metrics |
| UserFavorites | User preferences | Personalization |
| Ratings | Dashboard feedback | 5-star rating system |

#### HR Schema
| Table | Purpose | Key Features |
|-------|---------|--------------|
| Employees | Employee records | Comprehensive HR data, reporting structure |
| Departments | Organizational structure | Budget tracking, hierarchical |
| Positions | Job titles/roles | Salary ranges, job descriptions |
| EmployeeHistory | Change tracking | Promotions, transfers, salary changes |

### Relationships
```
Users (1) ─── (N) UserRoles (N) ─── (1) Roles
  │                                        │
  │                                        └─── (N) RolePermissions (N) ─── (1) Permissions
  │
  ├─── (1) ─── (N) Dashboards
  │                    │
  │                    ├─── (N) ─── (1) Categories
  │                    ├─── (N) AccessLog
  │                    ├─── (N) UserFavorites
  │                    └─── (N) Ratings
  │
  └─── (1) ─── (0..1) Employees
                          │
                          ├─── (N) ─── (1) Departments
                          ├─── (N) ─── (1) Positions
                          └─── (1) ─── (N) EmployeeHistory
```

## Security Implementation

### Authentication & Authorization
- **Password Policy**: Bcrypt hashing with salt
- **Account Lockout**: After 5 failed attempts (30 min)
- **Session Management**: JWT with refresh tokens
- **Role-Based Access Control**: Hierarchical roles with granular permissions

### Data Protection
```sql
-- Row-Level Security enabled for:
- Dashboard.Dashboards (user/role based)
- HR.Employees (department/manager based)

-- Dynamic Data Masking for:
- SSN: XXX-XX-####
- Bank Account: ****####
- Salary: Hidden from non-authorized users

-- Encryption:
- TDE for data at rest
- Always Encrypted for sensitive columns
```

### Audit Trail
- All CRUD operations logged
- User authentication events tracked
- Sensitive data changes specially marked
- JSON format for flexible querying

## Performance Optimization

### Indexing Strategy
```sql
-- Clustered Indexes: On primary keys
-- Non-clustered Indexes: 
  - Foreign key columns
  - Frequently queried columns
  - Filtered indexes for active records
  
-- Columnstore Index: AccessLog for analytics
-- Full-text Indexes: Dashboard search
```

### Query Optimization
- Stored procedures for complex operations
- Parameterized queries to prevent SQL injection
- Query Store enabled for performance monitoring
- Statistics auto-update enabled

### Connection Pooling
```python
# Configured in database_config.py
Pool Size: 10 connections
Max Overflow: 20 connections
Timeout: 30 seconds
Recycle: 3600 seconds
```

## Backup & Recovery Strategy

### Backup Schedule
| Type | Frequency | Retention | Time |
|------|-----------|-----------|------|
| Full | Weekly (Sunday) | 4 weeks | 2:00 AM |
| Differential | Daily (Mon-Sat) | 7 days | 2:00 AM |
| Transaction Log | Hourly | 24 hours | Every hour |

### Recovery Procedures
```sql
-- Point-in-time recovery supported
-- RTO: 4 hours
-- RPO: 1 hour

-- Test recovery procedure:
EXEC sp_TestDisasterRecovery;
```

### Automated Maintenance
```sql
-- Weekly maintenance window: Sunday 3-5 AM
EXEC sp_DatabaseMaintenance @MaintenanceType = 'ALL';
-- Includes: Index rebuild, statistics update, cleanup
```

## Migration Guide

### From JSON to SQL Server
```python
# Use provided migration script
python migration_script.py --json-file ../db.json

# Verify migration
python migration_script.py --verify-only
```

### Data Mapping
| JSON Field | SQL Table.Column | Data Type |
|------------|------------------|-----------|
| users.username | Security.Users.Username | NVARCHAR(50) |
| users.hashed_password | Security.Users.PasswordHash | NVARCHAR(255) |
| tableros.titulo | Dashboard.Dashboards.DashboardTitle | NVARCHAR(200) |
| tableros.url_acceso | Dashboard.Dashboards.AccessURL | NVARCHAR(2048) |

## API Integration

### FastAPI Connection Setup
```python
# In main.py
from database.database_config import db_manager, get_db
from fastapi import Depends
from sqlalchemy.orm import Session

@app.get("/api/data")
async def get_data(db: Session = Depends(get_db)):
    # Use db session for queries
    pass
```

### Stored Procedure Calls
```python
# Example: Authenticate user
result = db_manager.execute_stored_procedure(
    'Security.sp_AuthenticateUser',
    {'Username': username, 'PasswordHash': password_hash}
)
```

### Transaction Management
```python
# Using context manager
with db_manager.session_scope() as session:
    # Perform operations
    session.add(new_record)
    # Auto-commit on success, rollback on error
```

## Maintenance Procedures

### Daily Tasks
```sql
-- Check database health
EXEC sp_DatabaseHealthCheck;

-- Monitor performance
EXEC sp_MonitorPerformance;
```

### Weekly Tasks
```sql
-- Full maintenance
EXEC sp_DatabaseMaintenance @MaintenanceType = 'ALL';

-- Security audit
EXEC Security.sp_SecurityAuditReport;
```

### Monthly Tasks
```sql
-- Capacity planning review
-- Security policy review
-- Backup restoration test
EXEC sp_TestDisasterRecovery;
```

## Performance Metrics

### Key Performance Indicators
- **Query Response Time**: < 100ms for simple queries
- **Dashboard Load Time**: < 2 seconds
- **Concurrent Users**: Support for 500+ concurrent users
- **Database Growth**: ~10% monthly estimated

### Monitoring Queries
```sql
-- Active connections
SELECT COUNT(*) FROM sys.dm_exec_connections;

-- Long running queries
EXEC sp_MonitorPerformance;

-- Index fragmentation
SELECT * FROM vw_MissingIndexes;
```

## Troubleshooting

### Common Issues

#### Connection Issues
```python
# Test connection
from database_config import db_manager
print(db_manager.test_connection())
```

#### Performance Issues
```sql
-- Check index fragmentation
EXEC sp_MaintenanceRebuildIndexes;

-- Update statistics
UPDATE STATISTICS [table_name] WITH FULLSCAN;
```

#### Security Issues
```sql
-- Check user permissions
EXEC Security.sp_CheckUserPermission @UserID = 1, @PermissionName = 'Dashboard.Read';

-- Revoke sessions
EXEC Security.sp_RevokeUserSessions @UserID = 1;
```

## Best Practices

### Development
1. Always use parameterized queries
2. Implement proper error handling
3. Use transactions for multi-step operations
4. Follow naming conventions

### Security
1. Regular password rotation
2. Principle of least privilege
3. Audit sensitive operations
4. Regular security reviews

### Performance
1. Monitor query performance regularly
2. Maintain indexes weekly
3. Archive old data quarterly
4. Review execution plans for slow queries

## Support & Contact

For database-related issues or questions:
- Review error logs in Audit.AuditLog table
- Check SQL Server error logs
- Monitor application logs

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-09-03 | Initial release |

## License

This database design is proprietary to BIDashboard Enterprise.

---

Generated by: Senior Database Architect
Date: 2025-09-03