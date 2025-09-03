/*
=================================================================
BIDashboard - SQL Server Security and Permissions Script
Author: Database Architect  
Date: 2025-09-03
Description: Creates indexes, security policies, and permissions for BIDashboard
=================================================================
*/

USE BIDashboard;
GO

-- =================================================================
-- INDEXES FOR PERFORMANCE
-- =================================================================

-- Users table indexes
CREATE NONCLUSTERED INDEX IX_Users_Username ON Security.Users (Username);
CREATE NONCLUSTERED INDEX IX_Users_EmailAddress ON Security.Users (EmailAddress);
CREATE NONCLUSTERED INDEX IX_Users_IsActive ON Security.Users (IsActive);
CREATE NONCLUSTERED INDEX IX_Users_LastLoginDate ON Security.Users (LastLoginDate);
GO

-- UserSessions indexes
CREATE NONCLUSTERED INDEX IX_UserSessions_UserID ON Security.UserSessions (UserID);
CREATE NONCLUSTERED INDEX IX_UserSessions_ExpiryDate ON Security.UserSessions (ExpiryDate);
CREATE NONCLUSTERED INDEX IX_UserSessions_TokenHash ON Security.UserSessions (TokenHash);
GO

-- Dashboard indexes
CREATE NONCLUSTERED INDEX IX_Dashboards_CategoryID ON Dashboard.Dashboards (CategoryID);
CREATE NONCLUSTERED INDEX IX_Dashboards_CreatedBy ON Dashboard.Dashboards (CreatedBy);
CREATE NONCLUSTERED INDEX IX_Dashboards_IsActive ON Dashboard.Dashboards (IsActive);
CREATE NONCLUSTERED INDEX IX_Dashboards_IsPublic ON Dashboard.Dashboards (IsPublic);
CREATE NONCLUSTERED INDEX IX_Dashboards_Title ON Dashboard.Dashboards (Title);

-- Full-text search index for dashboards
IF NOT EXISTS (SELECT * FROM sys.fulltext_catalogs WHERE name = 'BIDashboard_Catalog')
    CREATE FULLTEXT CATALOG BIDashboard_Catalog;
GO

IF NOT EXISTS (SELECT * FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID('Dashboard.Dashboards'))
BEGIN
    CREATE FULLTEXT INDEX ON Dashboard.Dashboards (Title, Description) 
    KEY INDEX PK__Dashboar__C05A6AD5B8A7D970 ON BIDashboard_Catalog;
END
GO

-- Employee indexes
CREATE NONCLUSTERED INDEX IX_Employees_DepartmentID ON HR.Employees (DepartmentID);
CREATE NONCLUSTERED INDEX IX_Employees_PositionID ON HR.Employees (PositionID);
CREATE NONCLUSTERED INDEX IX_Employees_EmploymentStatus ON HR.Employees (EmploymentStatus);
CREATE NONCLUSTERED INDEX IX_Employees_EmailAddress ON HR.Employees (EmailAddress);
CREATE NONCLUSTERED INDEX IX_Employees_EmployeeNumber ON HR.Employees (EmployeeNumber);
GO

-- Audit indexes
CREATE NONCLUSTERED INDEX IX_AuditLog_TableName ON Audit.AuditLog (TableName);
CREATE NONCLUSTERED INDEX IX_AuditLog_ChangedDate ON Audit.AuditLog (ChangedDate);
CREATE NONCLUSTERED INDEX IX_AuditLog_ChangedBy ON Audit.AuditLog (ChangedBy);

CREATE NONCLUSTERED INDEX IX_SystemEvents_EventType ON Audit.SystemEvents (EventType);
CREATE NONCLUSTERED INDEX IX_SystemEvents_CreatedDate ON Audit.SystemEvents (CreatedDate);
CREATE NONCLUSTERED INDEX IX_SystemEvents_Severity ON Audit.SystemEvents (Severity);
GO

-- Analytics indexes
CREATE NONCLUSTERED INDEX IX_DashboardAnalytics_DashboardID ON Dashboard.DashboardAnalytics (DashboardID);
CREATE NONCLUSTERED INDEX IX_DashboardAnalytics_AccessDate ON Dashboard.DashboardAnalytics (AccessDate);
CREATE NONCLUSTERED INDEX IX_DashboardAnalytics_UserID ON Dashboard.DashboardAnalytics (UserID);
GO

-- =================================================================
-- SECURITY POLICIES AND ROW-LEVEL SECURITY
-- =================================================================

-- Enable Row-Level Security for Dashboards (Users can only see their own or public dashboards)
ALTER TABLE Dashboard.Dashboards ENABLE ROW_LEVEL_SECURITY;
GO

-- Create security policy function for dashboards
CREATE FUNCTION Security.fn_DashboardSecurityPredicate(@CreatedBy INT, @IsPublic BIT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS SecurityPredicate
WHERE @IsPublic = 1 
   OR @CreatedBy = USER_ID()
   OR IS_MEMBER('db_owner') = 1
   OR EXISTS (
       SELECT 1 FROM Dashboard.DashboardPermissions dp
       WHERE dp.UserID = USER_ID()
   );
GO

-- Apply security policy to dashboards
CREATE SECURITY POLICY Security.DashboardSecurityPolicy
ADD FILTER PREDICATE Security.fn_DashboardSecurityPredicate(CreatedBy, IsPublic) ON Dashboard.Dashboards
WITH (STATE = ON);
GO

-- =================================================================
-- TRIGGERS FOR AUDIT LOGGING
-- =================================================================

-- Audit trigger for Users table
CREATE TRIGGER Security.tr_Users_Audit
ON Security.Users
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Operation NVARCHAR(10);
    
    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
        SET @Operation = 'UPDATE';
    ELSE IF EXISTS(SELECT * FROM inserted)
        SET @Operation = 'INSERT';
    ELSE
        SET @Operation = 'DELETE';
    
    -- Insert audit record for each affected row
    INSERT INTO Audit.AuditLog (TableName, RecordID, Operation, OldValues, NewValues, ChangedBy)
    SELECT 
        'Security.Users',
        COALESCE(i.UserID, d.UserID),
        @Operation,
        CASE WHEN d.UserID IS NOT NULL THEN 
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) 
        END,
        CASE WHEN i.UserID IS NOT NULL THEN 
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) 
        END,
        COALESCE(i.ModifiedBy, i.CreatedBy, USER_ID())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.UserID = d.UserID;
END
GO

-- Audit trigger for Dashboards table
CREATE TRIGGER Dashboard.tr_Dashboards_Audit
ON Dashboard.Dashboards
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Operation NVARCHAR(10);
    
    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
        SET @Operation = 'UPDATE';
    ELSE IF EXISTS(SELECT * FROM inserted)
        SET @Operation = 'INSERT';
    ELSE
        SET @Operation = 'DELETE';
    
    -- Insert audit record
    INSERT INTO Audit.AuditLog (TableName, RecordID, Operation, OldValues, NewValues, ChangedBy)
    SELECT 
        'Dashboard.Dashboards',
        COALESCE(i.DashboardID, d.DashboardID),
        @Operation,
        CASE WHEN d.DashboardID IS NOT NULL THEN 
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) 
        END,
        CASE WHEN i.DashboardID IS NOT NULL THEN 
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) 
        END,
        COALESCE(i.ModifiedBy, i.CreatedBy, USER_ID())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.DashboardID = d.DashboardID;
END
GO

-- Audit trigger for Employees table  
CREATE TRIGGER HR.tr_Employees_Audit
ON HR.Employees
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Operation NVARCHAR(10);
    
    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
        SET @Operation = 'UPDATE';
    ELSE IF EXISTS(SELECT * FROM inserted)
        SET @Operation = 'INSERT';
    ELSE
        SET @Operation = 'DELETE';
    
    -- Insert audit record
    INSERT INTO Audit.AuditLog (TableName, RecordID, Operation, OldValues, NewValues, ChangedBy)
    SELECT 
        'HR.Employees',
        COALESCE(i.EmployeeID, d.EmployeeID),
        @Operation,
        CASE WHEN d.EmployeeID IS NOT NULL THEN 
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) 
        END,
        CASE WHEN i.EmployeeID IS NOT NULL THEN 
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) 
        END,
        COALESCE(i.ModifiedBy, i.CreatedBy, USER_ID())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.EmployeeID = d.EmployeeID;
END
GO

-- =================================================================
-- DATA MASKING FOR SENSITIVE DATA
-- =================================================================

-- Mask sensitive employee data
ALTER TABLE HR.Employees 
ALTER COLUMN PhoneNumber ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XXX-",4)');

ALTER TABLE HR.Employees 
ALTER COLUMN Salary ADD MASKED WITH (FUNCTION = 'random(10000,99999)');

ALTER TABLE Security.Users 
ALTER COLUMN EmailAddress ADD MASKED WITH (FUNCTION = 'email()');
GO

-- =================================================================
-- CREATE ROLES AND PERMISSIONS
-- =================================================================

-- Create custom database roles
CREATE ROLE db_dashboard_admin;
CREATE ROLE db_dashboard_editor;
CREATE ROLE db_dashboard_viewer;
CREATE ROLE db_hr_admin;
CREATE ROLE db_hr_manager;
CREATE ROLE db_hr_employee;
GO

-- Grant permissions to roles

-- Dashboard Admin Role
GRANT SELECT, INSERT, UPDATE, DELETE ON Dashboard.Dashboards TO db_dashboard_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dashboard.Categories TO db_dashboard_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dashboard.Subcategories TO db_dashboard_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dashboard.DashboardPermissions TO db_dashboard_admin;
GRANT SELECT ON Dashboard.DashboardAnalytics TO db_dashboard_admin;
GRANT EXECUTE ON Dashboard.sp_GetDashboardsForUser TO db_dashboard_admin;
GRANT EXECUTE ON Dashboard.sp_CreateDashboard TO db_dashboard_admin;
GRANT EXECUTE ON Dashboard.sp_UpdateDashboard TO db_dashboard_admin;
GRANT EXECUTE ON Dashboard.sp_DeleteDashboard TO db_dashboard_admin;
GRANT EXECUTE ON Dashboard.sp_GetDashboardAnalytics TO db_dashboard_admin;

-- Dashboard Editor Role  
GRANT SELECT, INSERT, UPDATE ON Dashboard.Dashboards TO db_dashboard_editor;
GRANT SELECT ON Dashboard.Categories TO db_dashboard_editor;
GRANT SELECT ON Dashboard.Subcategories TO db_dashboard_editor;
GRANT EXECUTE ON Dashboard.sp_GetDashboardsForUser TO db_dashboard_editor;
GRANT EXECUTE ON Dashboard.sp_CreateDashboard TO db_dashboard_editor;
GRANT EXECUTE ON Dashboard.sp_UpdateDashboard TO db_dashboard_editor;

-- Dashboard Viewer Role
GRANT SELECT ON Dashboard.Dashboards TO db_dashboard_viewer;
GRANT SELECT ON Dashboard.Categories TO db_dashboard_viewer;
GRANT SELECT ON Dashboard.Subcategories TO db_dashboard_viewer;
GRANT EXECUTE ON Dashboard.sp_GetDashboardsForUser TO db_dashboard_viewer;

-- HR Admin Role
GRANT SELECT, INSERT, UPDATE, DELETE ON HR.Employees TO db_hr_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON HR.Departments TO db_hr_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON HR.Positions TO db_hr_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON HR.PerformanceReviews TO db_hr_admin;
GRANT EXECUTE ON HR.sp_GetEmployees TO db_hr_admin;
GRANT EXECUTE ON HR.sp_CreateEmployee TO db_hr_admin;
GRANT UNMASK ON HR.Employees TO db_hr_admin;

-- HR Manager Role
GRANT SELECT, INSERT, UPDATE ON HR.Employees TO db_hr_manager;
GRANT SELECT ON HR.Departments TO db_hr_manager;
GRANT SELECT ON HR.Positions TO db_hr_manager;
GRANT SELECT, INSERT, UPDATE ON HR.PerformanceReviews TO db_hr_manager;
GRANT EXECUTE ON HR.sp_GetEmployees TO db_hr_manager;
GRANT EXECUTE ON HR.sp_CreateEmployee TO db_hr_manager;

-- HR Employee Role (limited access)
GRANT SELECT ON HR.Employees TO db_hr_employee;
GRANT SELECT ON HR.Departments TO db_hr_employee;
GRANT SELECT ON HR.Positions TO db_hr_employee;
GRANT EXECUTE ON HR.sp_GetEmployees TO db_hr_employee;
GO

-- Assign Mario Gonzalez to admin roles
ALTER ROLE db_dashboard_admin ADD MEMBER mario_gonzalez;
ALTER ROLE db_hr_admin ADD MEMBER mario_gonzalez;
GO

-- =================================================================
-- ENCRYPTION SETUP (TDE - Transparent Data Encryption)
-- =================================================================

-- Create Database Master Key (required for TDE)
-- Note: In production, store the password securely
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE symmetric_key_id = 101)
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'BIDashboard2024!MasterKey@Mario';
    PRINT '🔐 Database Master Key created for encryption';
END
GO

-- Create certificate for TDE
IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'BIDashboard_TDE_Cert')
BEGIN
    CREATE CERTIFICATE BIDashboard_TDE_Cert WITH SUBJECT = 'BIDashboard TDE Certificate';
    PRINT '📜 TDE Certificate created';
END
GO

-- Create Database Encryption Key
IF NOT EXISTS (SELECT * FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID())
BEGIN
    CREATE DATABASE ENCRYPTION KEY
    WITH ALGORITHM = AES_256
    ENCRYPTION BY SERVER CERTIFICATE BIDashboard_TDE_Cert;
    
    -- Enable TDE
    ALTER DATABASE BIDashboard SET ENCRYPTION ON;
    PRINT '🔒 Transparent Data Encryption (TDE) enabled';
END
GO

-- =================================================================
-- CLEANUP PROCEDURES
-- =================================================================

-- Procedure to clean up old audit logs
CREATE PROCEDURE Audit.sp_CleanupOldAuditLogs
    @RetentionDays INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@RetentionDays, GETUTCDATE());
    DECLARE @DeletedCount INT;
    
    -- Delete old audit logs
    DELETE FROM Audit.AuditLog WHERE ChangedDate < @CutoffDate;
    SET @DeletedCount = @@ROWCOUNT;
    
    -- Delete old system events
    DELETE FROM Audit.SystemEvents WHERE CreatedDate < @CutoffDate AND Severity = 'Info';
    SET @DeletedCount = @DeletedCount + @@ROWCOUNT;
    
    -- Log cleanup activity
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, Severity)
    VALUES ('Audit Cleanup', 'Cleaned up ' + CAST(@DeletedCount AS NVARCHAR(10)) + ' old audit records', 'Info');
    
    SELECT @DeletedCount AS DeletedRecords;
END
GO

-- Procedure to cleanup expired user sessions
CREATE PROCEDURE Security.sp_CleanupExpiredSessions
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @DeletedCount INT;
    
    DELETE FROM Security.UserSessions WHERE ExpiryDate < GETUTCDATE();
    SET @DeletedCount = @@ROWCOUNT;
    
    -- Log cleanup activity
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, Severity)
    VALUES ('Session Cleanup', 'Cleaned up ' + CAST(@DeletedCount AS NVARCHAR(10)) + ' expired sessions', 'Info');
    
    SELECT @DeletedCount AS DeletedSessions;
END
GO

PRINT '✅ Security configuration completed successfully!';
PRINT '🔐 Security features enabled:';
PRINT '   - Row-Level Security for dashboards';
PRINT '   - Audit triggers for all major tables';
PRINT '   - Data masking for sensitive fields';
PRINT '   - Custom roles with granular permissions';
PRINT '   - Transparent Data Encryption (TDE)';
PRINT '   - Cleanup procedures for maintenance';
PRINT '📊 Performance optimizations:';
PRINT '   - Strategic indexes created';
PRINT '   - Full-text search enabled';
PRINT '🔑 Mario Gonzalez assigned to admin roles';
GO