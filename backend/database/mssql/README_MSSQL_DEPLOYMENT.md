# BIDashboard - SQL Server Database Deployment Guide

## 🎯 **Complete SQL Server Database Scripts for BIDashboard**

This directory contains enterprise-grade SQL Server scripts for deploying your BIDashboard application with a fully-featured Microsoft SQL Server database backend.

---

## 📋 **Script Overview**

### **1. Database Creation (`01_database_creation.sql`)**
- Creates BIDashboard database with optimized settings
- Configures file groups for performance
- Enables Query Store for monitoring
- Creates Mario Gonzalez login and user
- Sets up recovery and performance options

### **2. Tables and Schema (`02_tables_schema.sql`)**
- Creates 5 organized schemas: Security, Dashboard, HR, Audit, Config
- Defines 17 normalized tables with relationships
- Implements proper constraints and foreign keys
- Sets up audit trail infrastructure

### **3. Stored Procedures (`03_stored_procedures.sql`)**
- Authentication procedures (login, registration)
- Dashboard management procedures (CRUD operations)
- Employee management procedures
- Analytics and reporting procedures
- System health monitoring

### **4. Security and Permissions (`04_security_permissions.sql`)**
- Strategic indexes for optimal performance
- Row-Level Security (RLS) for data isolation
- Audit triggers for complete change tracking
- Data masking for sensitive information
- Custom roles with granular permissions
- Transparent Data Encryption (TDE)

### **5. Data Migration (`05_data_migration.sql`)**
- Migrates all existing JSON data to SQL Server
- Creates initial users including Mario Gonzalez
- Sets up default categories and departments
- Populates sample employee data
- Configures application settings

### **6. Backup and Maintenance (`06_backup_maintenance.sql`)**
- Automated backup procedures (Full, Differential, Log)
- Index maintenance and optimization
- Database integrity checking
- Statistics updates
- Data archival procedures
- SQL Server Agent job templates

---

## 🚀 **Deployment Instructions**

### **Prerequisites**
1. **SQL Server 2019+** (Express, Standard, or Enterprise)
2. **SQL Server Management Studio (SSMS)** or **Azure Data Studio**
3. **Administrative privileges** on SQL Server instance
4. **Backup directory**: `C:\SQLBackups\BIDashboard\` (or modify paths in scripts)

### **Step 1: Database Setup**
```sql
-- Execute scripts in this exact order:
-- 1. Database Creation
sqlcmd -S localhost -U sa -i "01_database_creation.sql"

-- 2. Tables and Schema  
sqlcmd -S localhost -U sa -d BIDashboard -i "02_tables_schema.sql"

-- 3. Stored Procedures
sqlcmd -S localhost -U sa -d BIDashboard -i "03_stored_procedures.sql"

-- 4. Security and Permissions
sqlcmd -S localhost -U sa -d BIDashboard -i "04_security_permissions.sql"

-- 5. Data Migration
sqlcmd -S localhost -U sa -d BIDashboard -i "05_data_migration.sql"

-- 6. Backup and Maintenance
sqlcmd -S localhost -U sa -d BIDashboard -i "06_backup_maintenance.sql"
```

### **Step 2: Verify Installation**
```sql
USE BIDashboard;

-- Check users
SELECT Username, IsAdmin, FirstName, LastName FROM Security.Users;

-- Check dashboards  
SELECT Title, CategoryName FROM Dashboard.Dashboards d
INNER JOIN Dashboard.Categories c ON d.CategoryID = c.CategoryID;

-- Check employees
SELECT FirstName, LastName, DepartmentName FROM HR.Employees e
INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID;

-- Run system health check
EXEC Config.sp_SystemHealthCheck;
```

---

## 🔐 **Login Credentials**

### **Database Access**
- **Server**: localhost (or your SQL Server instance)
- **Database**: BIDashboard
- **Login**: mario_gonzalez
- **Password**: Mario2024!BIDashboard@MSSQL

### **Application Access** 
- **Username**: mario_gonzalez
- **Password**: Mario2024!
- **Role**: SuperAdmin (full access)

### **Additional Users**
- **admin** / (original admin password)
- **testuser** / (original test password)

---

## 📊 **Database Architecture**

### **Schemas and Tables**

#### **Security Schema**
- `Users` - User accounts and authentication
- `UserSessions` - JWT session tracking
- `UserRoles` - Role definitions
- `UserRoleAssignments` - User-role mappings

#### **Dashboard Schema**
- `Categories` - Dashboard categories
- `Subcategories` - Dashboard subcategories
- `Dashboards` - Main dashboard records
- `DashboardPermissions` - Access control
- `DashboardAnalytics` - Usage tracking

#### **HR Schema**
- `Departments` - Organizational departments
- `Positions` - Job positions
- `Employees` - Employee records
- `PerformanceReviews` - Employee evaluations

#### **Audit Schema**
- `AuditLog` - Complete change tracking
- `SystemEvents` - System activity logs

#### **Config Schema**
- `AppSettings` - Application configuration

---

## ⚡ **Performance Features**

### **Indexing Strategy**
- Clustered indexes on primary keys
- Non-clustered indexes on frequently queried columns
- Full-text search on dashboard content
- Covering indexes for complex queries

### **Security Features**
- **Row-Level Security** - Users see only authorized data
- **Data Masking** - Sensitive data protection
- **Audit Triggers** - Complete change tracking
- **TDE Encryption** - Data-at-rest protection
- **Role-Based Access** - Granular permissions

### **Monitoring**
- Query Store enabled for performance analysis
- System health check procedures
- Automated maintenance procedures
- Comprehensive audit logging

---

## 🔧 **Maintenance Schedule**

### **Recommended Schedule**
- **Full Backup**: Weekly (Sundays 2:00 AM)
- **Differential Backup**: Daily (Mon-Sat 2:00 AM)  
- **Transaction Log Backup**: Hourly
- **Index Maintenance**: Weekly (Sundays 1:00 AM)
- **Statistics Update**: Weekly
- **Integrity Check**: Weekly
- **Data Archival**: Monthly

### **Manual Maintenance Commands**
```sql
-- Complete maintenance (all procedures)
EXEC Maintenance.sp_CompleteMaintenance;

-- Individual procedures
EXEC Maintenance.sp_FullBackup;
EXEC Maintenance.sp_IndexMaintenance;
EXEC Maintenance.sp_UpdateStatistics;
EXEC Maintenance.sp_DatabaseIntegrityCheck;
EXEC Maintenance.sp_ArchiveOldData;
```

---

## 🔄 **Integration with FastAPI**

### **Python Dependencies**
```bash
pip install pymssql sqlalchemy pyodbc
```

### **Connection String**
```python
DATABASE_URL = "mssql+pymssql://mario_gonzalez:Mario2024!BIDashboard@MSSQL@localhost:1433/BIDashboard"
```

### **Environment Variables**
```env
DB_SERVER=localhost
DB_NAME=BIDashboard
DB_USERNAME=mario_gonzalez
DB_PASSWORD=Mario2024!BIDashboard@MSSQL
DB_DRIVER=ODBC Driver 17 for SQL Server
DB_PORT=1433
```

---

## 📈 **Capacity Planning**

### **Initial Size**
- **Database**: 100 MB (grows by 10 MB)
- **Log**: 10 MB (grows by 5 MB)
- **Indexes**: 50 MB (separate filegroup)

### **Expected Growth**
- **Users**: 1-10K users
- **Dashboards**: 100-1K dashboards
- **Employees**: 10-1K employees
- **Analytics**: 1M+ records annually
- **Audit**: 100K+ records annually

---

## 🆘 **Troubleshooting**

### **Common Issues**

1. **Login Failed**
   ```sql
   -- Reset password
   ALTER LOGIN mario_gonzalez WITH PASSWORD = 'NewPassword123!';
   ```

2. **Permission Denied**
   ```sql
   -- Grant additional permissions
   ALTER ROLE db_owner ADD MEMBER mario_gonzalez;
   ```

3. **Performance Issues**
   ```sql
   -- Check fragmentation
   SELECT * FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED');
   
   -- Run maintenance
   EXEC Maintenance.sp_IndexMaintenance;
   ```

4. **Disk Space Issues**
   ```sql
   -- Check database size
   EXEC sp_spaceused;
   
   -- Archive old data
   EXEC Maintenance.sp_ArchiveOldData;
   ```

---

## ✅ **Verification Checklist**

- [ ] Database created successfully
- [ ] All tables and schemas exist
- [ ] Stored procedures created
- [ ] Indexes and security configured
- [ ] Data migrated successfully
- [ ] Backup procedures working
- [ ] Mario Gonzalez can login
- [ ] Application connects successfully
- [ ] Dashboard data visible
- [ ] Employee data accessible
- [ ] Audit logging functional

---

## 📞 **Support**

For issues with this database deployment:

1. **Check SQL Server Error Log**
2. **Review Audit.SystemEvents table**
3. **Run system health check**: `EXEC Config.sp_SystemHealthCheck`
4. **Verify permissions**: Check role assignments
5. **Monitor performance**: Use Query Store reports

---

## 🎉 **Congratulations!**

Your BIDashboard now has an enterprise-grade SQL Server database with:
- ✅ **17 normalized tables** with full relationships
- ✅ **Row-Level Security** and audit trails
- ✅ **Automated backup strategy**
- ✅ **Performance optimization**
- ✅ **Complete data migration** from JSON
- ✅ **Mario Gonzalez as SuperAdmin**

**Your application is ready for production deployment!**