-- =============================================
-- BIDashboard Security and Audit Configuration
-- Version: 1.0
-- Author: Senior Database Architect
-- Date: 2025-09-03
-- Description: Security hardening, audit triggers, and data protection
-- =============================================

USE BIDashboard;
GO

-- =============================================
-- SECTION 1: ROW-LEVEL SECURITY (RLS)
-- =============================================

-- Create security predicate function for dashboard access
CREATE FUNCTION [Security].[fn_DashboardSecurityPredicate]
(
    @CreatedBy INT,
    @IsPublic BIT,
    @MinimumRole INT
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN 
    SELECT 1 AS AccessGranted
    WHERE 
        @IsPublic = 1  -- Public dashboards
        OR @CreatedBy = USER_ID()  -- Owner access
        OR EXISTS (  -- Role-based access
            SELECT 1 
            FROM [Security].[UserRoles] ur
            INNER JOIN [Security].[Roles] r ON ur.RoleID = r.RoleID
            WHERE ur.UserID = USER_ID()
                AND ur.IsActive = 1
                AND (r.RoleName = 'SuperAdmin' 
                    OR r.RoleName = 'Admin'
                    OR (@MinimumRole IS NOT NULL AND ur.RoleID >= @MinimumRole))
        );
GO

-- Create security policy for dashboards
CREATE SECURITY POLICY [Security].[DashboardAccessPolicy]
    ADD FILTER PREDICATE [Security].[fn_DashboardSecurityPredicate](
        CreatedBy, IsPublic, MinimumRole
    ) ON [Dashboard].[Dashboards]
WITH (STATE = ON);
GO

-- Create security predicate for employee data
CREATE FUNCTION [Security].[fn_EmployeeSecurityPredicate]
(
    @DepartmentID INT,
    @EmployeeID INT
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN 
    SELECT 1 AS AccessGranted
    WHERE EXISTS (
        SELECT 1 
        FROM [Security].[UserRoles] ur
        INNER JOIN [Security].[Roles] r ON ur.RoleID = r.RoleID
        WHERE ur.UserID = USER_ID()
            AND ur.IsActive = 1
            AND (
                r.RoleName IN ('SuperAdmin', 'Admin', 'HR_Admin', 'HR_Manager')
                OR (r.RoleName = 'Manager' AND EXISTS (
                    SELECT 1 FROM [HR].[Departments] d
                    WHERE d.DepartmentID = @DepartmentID
                        AND d.ManagerEmployeeID IN (
                            SELECT EmployeeID FROM [HR].[Employees] 
                            WHERE UserID = USER_ID()
                        )
                ))
                OR @EmployeeID IN (
                    SELECT EmployeeID FROM [HR].[Employees] 
                    WHERE UserID = USER_ID()
                )
            )
    );
GO

-- Create security policy for employees
CREATE SECURITY POLICY [Security].[EmployeeAccessPolicy]
    ADD FILTER PREDICATE [Security].[fn_EmployeeSecurityPredicate](
        DepartmentID, EmployeeID
    ) ON [HR].[Employees]
WITH (STATE = ON);
GO

-- =============================================
-- SECTION 2: AUDIT TRIGGERS
-- =============================================

-- Audit trigger for Users table
CREATE TRIGGER [Security].[trg_Users_Audit]
ON [Security].[Users]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Operation NVARCHAR(10);
    DECLARE @UserID INT = SYSTEM_USER;
    DECLARE @Username NVARCHAR(50) = SYSTEM_USER;
    
    -- Determine operation type
    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
        SET @Operation = 'UPDATE';
    ELSE IF EXISTS(SELECT * FROM inserted)
        SET @Operation = 'INSERT';
    ELSE
        SET @Operation = 'DELETE';
    
    -- Insert audit records
    IF @Operation IN ('INSERT', 'UPDATE')
    BEGIN
        INSERT INTO [Audit].[AuditLog] (
            TableName, RecordID, Operation, Username, 
            IPAddress, NewValues
        )
        SELECT 
            'Security.Users',
            i.UserID,
            @Operation,
            @Username,
            CAST(CONNECTIONPROPERTY('client_net_address') AS NVARCHAR(45)),
            (SELECT * FROM inserted i2 WHERE i2.UserID = i.UserID FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM inserted i;
    END
    
    IF @Operation IN ('UPDATE', 'DELETE')
    BEGIN
        -- Store old values for updates and deletes
        UPDATE [Audit].[AuditLog]
        SET OldValues = (
            SELECT * FROM deleted d 
            WHERE d.UserID = [Audit].[AuditLog].RecordID 
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
        WHERE TableName = 'Security.Users'
            AND RecordID IN (SELECT UserID FROM deleted)
            AND Operation = @Operation
            AND AuditDate >= DATEADD(SECOND, -1, SYSDATETIME());
    END
END;
GO

-- Audit trigger for Dashboards table
CREATE TRIGGER [Dashboard].[trg_Dashboards_Audit]
ON [Dashboard].[Dashboards]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Operation NVARCHAR(10);
    DECLARE @Username NVARCHAR(50) = SYSTEM_USER;
    
    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
        SET @Operation = 'UPDATE';
    ELSE IF EXISTS(SELECT * FROM inserted)
        SET @Operation = 'INSERT';
    ELSE
        SET @Operation = 'DELETE';
    
    -- Insert audit records
    INSERT INTO [Audit].[AuditLog] (
        TableName, RecordID, Operation, Username,
        IPAddress, OldValues, NewValues
    )
    SELECT 
        'Dashboard.Dashboards',
        ISNULL(i.DashboardID, d.DashboardID),
        @Operation,
        @Username,
        CAST(CONNECTIONPROPERTY('client_net_address') AS NVARCHAR(45)),
        CASE WHEN d.DashboardID IS NOT NULL 
            THEN (SELECT * FROM deleted d2 WHERE d2.DashboardID = d.DashboardID 
                  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) 
            ELSE NULL END,
        CASE WHEN i.DashboardID IS NOT NULL 
            THEN (SELECT * FROM inserted i2 WHERE i2.DashboardID = i.DashboardID 
                  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) 
            ELSE NULL END
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.DashboardID = d.DashboardID;
END;
GO

-- Audit trigger for Employees table
CREATE TRIGGER [HR].[trg_Employees_Audit]
ON [HR].[Employees]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Operation NVARCHAR(10);
    DECLARE @Username NVARCHAR(50) = SYSTEM_USER;
    
    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
        SET @Operation = 'UPDATE';
    ELSE IF EXISTS(SELECT * FROM inserted)
        SET @Operation = 'INSERT';
    ELSE
        SET @Operation = 'DELETE';
    
    -- Special handling for salary changes
    IF @Operation = 'UPDATE'
    BEGIN
        INSERT INTO [Audit].[AuditLog] (
            TableName, RecordID, Operation, Username,
            IPAddress, OldValues, NewValues
        )
        SELECT 
            'HR.Employees',
            i.EmployeeID,
            CASE WHEN i.BaseSalary != d.BaseSalary 
                THEN 'SALARY_CHG' 
                ELSE 'UPDATE' END,
            @Username,
            CAST(CONNECTIONPROPERTY('client_net_address') AS NVARCHAR(45)),
            (SELECT 
                d.EmployeeID, d.FirstName, d.LastName, 
                d.DepartmentID, d.PositionID, d.BaseSalary
             FROM deleted d WHERE d.EmployeeID = i.EmployeeID 
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT 
                i.EmployeeID, i.FirstName, i.LastName,
                i.DepartmentID, i.PositionID, i.BaseSalary
             FROM inserted i WHERE i.EmployeeID = d.EmployeeID 
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM inserted i
        INNER JOIN deleted d ON i.EmployeeID = d.EmployeeID;
    END
    ELSE
    BEGIN
        INSERT INTO [Audit].[AuditLog] (
            TableName, RecordID, Operation, Username,
            IPAddress, OldValues, NewValues
        )
        SELECT 
            'HR.Employees',
            ISNULL(i.EmployeeID, d.EmployeeID),
            @Operation,
            @Username,
            CAST(CONNECTIONPROPERTY('client_net_address') AS NVARCHAR(45)),
            CASE WHEN d.EmployeeID IS NOT NULL 
                THEN (SELECT * FROM deleted d2 WHERE d2.EmployeeID = d.EmployeeID 
                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) 
                ELSE NULL END,
            CASE WHEN i.EmployeeID IS NOT NULL 
                THEN (SELECT * FROM inserted i2 WHERE i2.EmployeeID = i.EmployeeID 
                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) 
                ELSE NULL END
        FROM inserted i
        FULL OUTER JOIN deleted d ON i.EmployeeID = d.EmployeeID;
    END
END;
GO

-- =============================================
-- SECTION 3: DATA MASKING FOR SENSITIVE DATA
-- =============================================

-- Add dynamic data masking to sensitive columns
ALTER TABLE [HR].[Employees]
    ALTER COLUMN SocialSecurityNumber ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XX-",4)');

ALTER TABLE [HR].[Employees]
    ALTER COLUMN TaxID ADD MASKED WITH (FUNCTION = 'default()');

ALTER TABLE [HR].[Employees]
    ALTER COLUMN BankAccountNumber ADD MASKED WITH (FUNCTION = 'partial(0,"****",4)');

ALTER TABLE [HR].[Employees]
    ALTER COLUMN BaseSalary ADD MASKED WITH (FUNCTION = 'default()');

ALTER TABLE [Security].[Users]
    ALTER COLUMN PasswordHash ADD MASKED WITH (FUNCTION = 'default()');

ALTER TABLE [Security].[Users]
    ALTER COLUMN PasswordSalt ADD MASKED WITH (FUNCTION = 'default()');

ALTER TABLE [Security].[Users]
    ALTER COLUMN TwoFactorSecret ADD MASKED WITH (FUNCTION = 'default()');

GO

-- =============================================
-- SECTION 4: ENCRYPTION
-- =============================================

-- Create Database Master Key
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'BIDashboard$MasterKey$2025!';
END
GO

-- Create Certificate for Transparent Data Encryption
IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'BIDashboard_TDE_Certificate')
BEGIN
    CREATE CERTIFICATE BIDashboard_TDE_Certificate
    WITH SUBJECT = 'TDE Certificate for BIDashboard Database';
END
GO

-- Create Symmetric Key for Column Encryption
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'BIDashboard_ColumnKey')
BEGIN
    CREATE SYMMETRIC KEY BIDashboard_ColumnKey
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE BIDashboard_TDE_Certificate;
END
GO

-- =============================================
-- SECTION 5: SECURITY VIEWS
-- =============================================

-- Create view for user permissions
CREATE OR ALTER VIEW [Security].[vw_UserPermissions]
AS
SELECT 
    u.UserID,
    u.Username,
    u.Email,
    r.RoleName,
    p.PermissionName,
    p.ResourceType,
    p.OperationType,
    ur.IsActive AS RoleActive,
    rp.IsActive AS PermissionActive
FROM [Security].[Users] u
INNER JOIN [Security].[UserRoles] ur ON u.UserID = ur.UserID
INNER JOIN [Security].[Roles] r ON ur.RoleID = r.RoleID
INNER JOIN [Security].[RolePermissions] rp ON r.RoleID = rp.RoleID
INNER JOIN [Security].[Permissions] p ON rp.PermissionID = p.PermissionID
WHERE u.IsActive = 1 AND u.IsDeleted = 0;
GO

-- Create view for active sessions
CREATE OR ALTER VIEW [Security].[vw_ActiveSessions]
AS
SELECT 
    u.UserID,
    u.Username,
    u.LastLoginDate,
    rt.Token,
    rt.ExpiryDate,
    rt.CreatedDate,
    rt.CreatedByIP,
    CASE 
        WHEN rt.RevokedDate IS NULL AND GETDATE() < rt.ExpiryDate THEN 'Active'
        WHEN rt.RevokedDate IS NOT NULL THEN 'Revoked'
        ELSE 'Expired'
    END AS SessionStatus
FROM [Security].[Users] u
INNER JOIN [Security].[RefreshTokens] rt ON u.UserID = rt.UserID
WHERE rt.ExpiryDate > DATEADD(DAY, -7, GETDATE());
GO

-- =============================================
-- SECTION 6: SECURITY PROCEDURES
-- =============================================

-- Procedure to check user permissions
CREATE OR ALTER PROCEDURE [Security].[sp_CheckUserPermission]
    @UserID INT,
    @PermissionName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT CASE WHEN EXISTS (
        SELECT 1
        FROM [Security].[vw_UserPermissions]
        WHERE UserID = @UserID
            AND PermissionName = @PermissionName
            AND RoleActive = 1
            AND PermissionActive = 1
    ) THEN 1 ELSE 0 END AS HasPermission;
END;
GO

-- Procedure to revoke all user sessions
CREATE OR ALTER PROCEDURE [Security].[sp_RevokeUserSessions]
    @UserID INT,
    @RevokedByIP NVARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE [Security].[RefreshTokens]
    SET RevokedDate = SYSDATETIME(),
        RevokedByIP = @RevokedByIP
    WHERE UserID = @UserID
        AND RevokedDate IS NULL;
    
    SELECT @@ROWCOUNT AS SessionsRevoked;
END;
GO

-- Procedure for security audit report
CREATE OR ALTER PROCEDURE [Security].[sp_SecurityAuditReport]
    @StartDate DATETIME2(7) = NULL,
    @EndDate DATETIME2(7) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(DAY, -30, SYSDATETIME());
    
    IF @EndDate IS NULL
        SET @EndDate = SYSDATETIME();
    
    -- Failed login attempts
    SELECT 
        'Failed Login Attempts' AS AuditCategory,
        COUNT(*) AS Count,
        STRING_AGG(Username, ', ') AS Details
    FROM [Security].[Users]
    WHERE FailedLoginAttempts > 0
        AND LastLoginDate BETWEEN @StartDate AND @EndDate;
    
    -- Account lockouts
    SELECT 
        'Account Lockouts' AS AuditCategory,
        COUNT(*) AS Count,
        STRING_AGG(Username, ', ') AS Details
    FROM [Security].[Users]
    WHERE AccountLockedUntil IS NOT NULL
        AND AccountLockedUntil > @StartDate;
    
    -- Privilege changes
    SELECT 
        'Role Changes' AS AuditCategory,
        COUNT(*) AS Count,
        COUNT(DISTINCT UserID) AS AffectedUsers
    FROM [Security].[UserRoles]
    WHERE AssignedDate BETWEEN @StartDate AND @EndDate;
    
    -- Data modifications
    SELECT 
        TableName,
        Operation,
        COUNT(*) AS OperationCount,
        COUNT(DISTINCT Username) AS UniqueUsers
    FROM [Audit].[AuditLog]
    WHERE AuditDate BETWEEN @StartDate AND @EndDate
    GROUP BY TableName, Operation
    ORDER BY OperationCount DESC;
END;
GO

-- =============================================
-- SECTION 7: COMPLIANCE AND GDPR
-- =============================================

-- Procedure for data anonymization (GDPR compliance)
CREATE OR ALTER PROCEDURE [Security].[sp_AnonymizeUserData]
    @UserID INT,
    @ConfirmAnonymize BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ConfirmAnonymize = 0
    BEGIN
        SELECT 'This will permanently anonymize user data. Set @ConfirmAnonymize = 1 to proceed.' AS Warning;
        RETURN;
    END
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Anonymize user data
        UPDATE [Security].[Users]
        SET 
            Username = CONCAT('ANON_USER_', UserID),
            Email = CONCAT('anonymized_', UserID, '@example.com'),
            FirstName = 'Anonymized',
            LastName = 'User',
            DisplayName = 'Anonymized User',
            ProfilePictureURL = NULL,
            PasswordHash = NEWID(),
            PasswordSalt = NEWID(),
            TwoFactorSecret = NULL,
            IsActive = 0,
            IsDeleted = 1,
            DeletedDate = SYSDATETIME()
        WHERE UserID = @UserID;
        
        -- Anonymize employee data if linked
        UPDATE [HR].[Employees]
        SET 
            FirstName = 'Anonymized',
            MiddleName = NULL,
            LastName = 'Employee',
            Email = CONCAT('anon_emp_', EmployeeID, '@example.com'),
            PersonalEmail = NULL,
            Phone = NULL,
            MobilePhone = NULL,
            DateOfBirth = NULL,
            NationalID = NULL,
            PassportNumber = NULL,
            TaxID = NULL,
            SocialSecurityNumber = NULL,
            BankAccountNumber = NULL,
            AddressLine1 = NULL,
            AddressLine2 = NULL,
            EmergencyContactName = NULL,
            EmergencyContactPhone = NULL,
            Notes = 'Data anonymized for privacy compliance',
            IsActive = 0,
            IsDeleted = 1
        WHERE UserID = @UserID;
        
        -- Log the anonymization
        INSERT INTO [Audit].[AuditLog] (
            TableName, RecordID, Operation, Username, NewValues
        )
        VALUES (
            'Security.Users', 
            @UserID, 
            'ANONYMIZE', 
            SYSTEM_USER,
            'User data anonymized for GDPR compliance'
        );
        
        COMMIT TRANSACTION;
        
        SELECT 'User data successfully anonymized' AS Result;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'Security and audit configuration completed successfully.';
GO