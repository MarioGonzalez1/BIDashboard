-- =============================================
-- BIDashboard Initial Data Population Script
-- Version: 1.0
-- Author: Senior Database Architect
-- Date: 2025-09-03
-- Description: Initial data setup including roles, permissions, and sample data
-- =============================================

USE BIDashboard;
GO

-- =============================================
-- SECTION 1: SECURITY INITIAL DATA
-- =============================================

-- Insert default roles
INSERT INTO [Security].[Roles] (RoleName, RoleDescription, IsSystemRole)
VALUES 
    ('SuperAdmin', 'Full system access with all privileges', 1),
    ('Admin', 'Administrative access to manage users and content', 1),
    ('Manager', 'Manager level access with department oversight', 1),
    ('User', 'Standard user with basic access', 1),
    ('Viewer', 'Read-only access to public dashboards', 1),
    ('HR_Admin', 'Human Resources administrator', 0),
    ('HR_Manager', 'Human Resources manager', 0),
    ('Finance_User', 'Finance department user', 0),
    ('Operations_User', 'Operations department user', 0),
    ('Guest', 'Guest user with minimal access', 1);
GO

-- Insert permissions
INSERT INTO [Security].[Permissions] (PermissionName, PermissionDescription, ResourceType, OperationType)
VALUES
    -- Dashboard permissions
    ('Dashboard.Create', 'Create new dashboards', 'Dashboard', 'Create'),
    ('Dashboard.Read', 'View dashboards', 'Dashboard', 'Read'),
    ('Dashboard.Update', 'Update existing dashboards', 'Dashboard', 'Update'),
    ('Dashboard.Delete', 'Delete dashboards', 'Dashboard', 'Delete'),
    ('Dashboard.Publish', 'Publish dashboards', 'Dashboard', 'Execute'),
    ('Dashboard.ManageAll', 'Manage all dashboards', 'Dashboard', 'Execute'),
    
    -- Category permissions
    ('Category.Create', 'Create dashboard categories', 'Category', 'Create'),
    ('Category.Update', 'Update categories', 'Category', 'Update'),
    ('Category.Delete', 'Delete categories', 'Category', 'Delete'),
    
    -- Employee permissions
    ('Employee.Create', 'Create employee records', 'Employee', 'Create'),
    ('Employee.Read', 'View employee records', 'Employee', 'Read'),
    ('Employee.Update', 'Update employee records', 'Employee', 'Update'),
    ('Employee.Delete', 'Delete employee records', 'Employee', 'Delete'),
    ('Employee.ViewSalary', 'View employee salary information', 'Employee', 'Read'),
    ('Employee.UpdateSalary', 'Update employee salary', 'Employee', 'Update'),
    
    -- User management permissions
    ('User.Create', 'Create user accounts', 'User', 'Create'),
    ('User.Read', 'View user accounts', 'User', 'Read'),
    ('User.Update', 'Update user accounts', 'User', 'Update'),
    ('User.Delete', 'Delete user accounts', 'User', 'Delete'),
    ('User.AssignRole', 'Assign roles to users', 'User', 'Execute'),
    ('User.ResetPassword', 'Reset user passwords', 'User', 'Execute'),
    
    -- Report permissions
    ('Report.View', 'View reports', 'Report', 'Read'),
    ('Report.Export', 'Export reports', 'Report', 'Execute'),
    ('Report.Schedule', 'Schedule reports', 'Report', 'Execute'),
    
    -- System permissions
    ('System.ViewAudit', 'View audit logs', 'System', 'Read'),
    ('System.ManageSettings', 'Manage system settings', 'System', 'Update'),
    ('System.Backup', 'Perform system backup', 'System', 'Execute'),
    ('System.ViewAnalytics', 'View system analytics', 'System', 'Read');
GO

-- Assign permissions to roles
DECLARE @SuperAdminRole INT, @AdminRole INT, @ManagerRole INT, @UserRole INT, @ViewerRole INT;
DECLARE @HRAdminRole INT, @HRManagerRole INT;

SELECT @SuperAdminRole = RoleID FROM [Security].[Roles] WHERE RoleName = 'SuperAdmin';
SELECT @AdminRole = RoleID FROM [Security].[Roles] WHERE RoleName = 'Admin';
SELECT @ManagerRole = RoleID FROM [Security].[Roles] WHERE RoleName = 'Manager';
SELECT @UserRole = RoleID FROM [Security].[Roles] WHERE RoleName = 'User';
SELECT @ViewerRole = RoleID FROM [Security].[Roles] WHERE RoleName = 'Viewer';
SELECT @HRAdminRole = RoleID FROM [Security].[Roles] WHERE RoleName = 'HR_Admin';
SELECT @HRManagerRole = RoleID FROM [Security].[Roles] WHERE RoleName = 'HR_Manager';

-- SuperAdmin gets all permissions
INSERT INTO [Security].[RolePermissions] (RoleID, PermissionID, GrantedBy)
SELECT @SuperAdminRole, PermissionID, 1
FROM [Security].[Permissions];

-- Admin permissions
INSERT INTO [Security].[RolePermissions] (RoleID, PermissionID, GrantedBy)
SELECT @AdminRole, PermissionID, 1
FROM [Security].[Permissions]
WHERE PermissionName IN (
    'Dashboard.Create', 'Dashboard.Read', 'Dashboard.Update', 'Dashboard.Delete', 'Dashboard.Publish',
    'Category.Create', 'Category.Update',
    'User.Create', 'User.Read', 'User.Update', 'User.AssignRole', 'User.ResetPassword',
    'Report.View', 'Report.Export',
    'System.ViewAudit', 'System.ViewAnalytics'
);

-- Manager permissions
INSERT INTO [Security].[RolePermissions] (RoleID, PermissionID, GrantedBy)
SELECT @ManagerRole, PermissionID, 1
FROM [Security].[Permissions]
WHERE PermissionName IN (
    'Dashboard.Create', 'Dashboard.Read', 'Dashboard.Update',
    'Employee.Read',
    'Report.View', 'Report.Export',
    'System.ViewAnalytics'
);

-- User permissions
INSERT INTO [Security].[RolePermissions] (RoleID, PermissionID, GrantedBy)
SELECT @UserRole, PermissionID, 1
FROM [Security].[Permissions]
WHERE PermissionName IN (
    'Dashboard.Read',
    'Report.View'
);

-- Viewer permissions
INSERT INTO [Security].[RolePermissions] (RoleID, PermissionID, GrantedBy)
SELECT @ViewerRole, PermissionID, 1
FROM [Security].[Permissions]
WHERE PermissionName = 'Dashboard.Read';

-- HR Admin permissions
INSERT INTO [Security].[RolePermissions] (RoleID, PermissionID, GrantedBy)
SELECT @HRAdminRole, PermissionID, 1
FROM [Security].[Permissions]
WHERE PermissionName IN (
    'Employee.Create', 'Employee.Read', 'Employee.Update', 'Employee.Delete',
    'Employee.ViewSalary', 'Employee.UpdateSalary',
    'Dashboard.Read',
    'Report.View', 'Report.Export'
);

GO

-- =============================================
-- SECTION 2: DASHBOARD INITIAL DATA
-- =============================================

-- Insert dashboard categories
INSERT INTO [Dashboard].[Categories] (CategoryName, CategorySlug, CategoryDescription, CategoryIcon, DisplayOrder, ColorHex, CreatedBy)
VALUES
    ('Operations', 'operations', 'Operational dashboards and KPIs', 'fa-cogs', 1, '#2E7D32', 1),
    ('Finance', 'finance', 'Financial reports and analytics', 'fa-dollar-sign', 2, '#1976D2', 1),
    ('Human Resources', 'human-resources', 'HR metrics and employee analytics', 'fa-users', 3, '#7B1FA2', 1),
    ('Sales', 'sales', 'Sales performance and customer analytics', 'fa-chart-line', 4, '#C62828', 1),
    ('Marketing', 'marketing', 'Marketing campaigns and ROI analysis', 'fa-bullhorn', 5, '#F57C00', 1),
    ('IT', 'it', 'IT infrastructure and service metrics', 'fa-server', 6, '#455A64', 1),
    ('Workshop', 'workshop', 'Workshop and maintenance analytics', 'fa-tools', 7, '#5D4037', 1),
    ('Logistics', 'logistics', 'Supply chain and logistics dashboards', 'fa-truck', 8, '#00796B', 1),
    ('Quality', 'quality', 'Quality control and assurance metrics', 'fa-check-circle', 9, '#616161', 1),
    ('Executive', 'executive', 'Executive level strategic dashboards', 'fa-chart-pie', 10, '#4A148C', 1);
GO

-- Insert subcategories
DECLARE @OpsCatID INT, @WorkshopCatID INT;
SELECT @OpsCatID = CategoryID FROM [Dashboard].[Categories] WHERE CategoryName = 'Operations';
SELECT @WorkshopCatID = CategoryID FROM [Dashboard].[Categories] WHERE CategoryName = 'Workshop';

INSERT INTO [Dashboard].[Categories] (CategoryName, CategorySlug, CategoryDescription, ParentCategoryID, DisplayOrder, CreatedBy)
VALUES
    ('Forza Transportation', 'forza-transportation', 'Forza Transportation specific dashboards', @WorkshopCatID, 1, 1),
    ('Force One Transport', 'force-one-transport', 'Force One Transport specific dashboards', @WorkshopCatID, 2, 1),
    ('Border Operations', 'border-operations', 'Border crossing operations', @OpsCatID, 1, 1),
    ('Fleet Management', 'fleet-management', 'Fleet management and tracking', @OpsCatID, 2, 1);
GO

-- =============================================
-- SECTION 3: HR INITIAL DATA
-- =============================================

-- Insert departments
INSERT INTO [HR].[Departments] (DepartmentName, DepartmentCode, Budget, CostCenter, Location, CreatedBy)
VALUES
    ('Executive', 'EXEC', 5000000.00, 'CC-001', 'Headquarters', 1),
    ('Operations', 'OPS', 10000000.00, 'CC-002', 'Main Office', 1),
    ('Finance', 'FIN', 3000000.00, 'CC-003', 'Main Office', 1),
    ('Human Resources', 'HR', 2000000.00, 'CC-004', 'Main Office', 1),
    ('Information Technology', 'IT', 4000000.00, 'CC-005', 'Tech Center', 1),
    ('Sales', 'SALES', 8000000.00, 'CC-006', 'Sales Office', 1),
    ('Marketing', 'MKT', 3500000.00, 'CC-007', 'Main Office', 1),
    ('Customer Service', 'CS', 2500000.00, 'CC-008', 'Call Center', 1),
    ('Logistics', 'LOG', 6000000.00, 'CC-009', 'Warehouse', 1),
    ('Quality Assurance', 'QA', 1500000.00, 'CC-010', 'Main Office', 1),
    ('Workshop', 'WS', 4500000.00, 'CC-011', 'Workshop Facility', 1),
    ('Fleet Management', 'FLEET', 7000000.00, 'CC-012', 'Fleet Center', 1);
GO

-- Insert positions
INSERT INTO [HR].[Positions] (PositionTitle, PositionCode, PositionLevel, MinSalary, MaxSalary)
VALUES
    ('Chief Executive Officer', 'CEO', 10, 250000.00, 500000.00),
    ('Chief Operating Officer', 'COO', 9, 200000.00, 400000.00),
    ('Chief Financial Officer', 'CFO', 9, 200000.00, 400000.00),
    ('Chief Technology Officer', 'CTO', 9, 200000.00, 400000.00),
    ('Vice President', 'VP', 8, 150000.00, 300000.00),
    ('Director', 'DIR', 7, 120000.00, 250000.00),
    ('Senior Manager', 'SR-MGR', 6, 90000.00, 180000.00),
    ('Manager', 'MGR', 5, 70000.00, 140000.00),
    ('Senior Analyst', 'SR-ANALYST', 4, 60000.00, 120000.00),
    ('Analyst', 'ANALYST', 3, 45000.00, 90000.00),
    ('Senior Developer', 'SR-DEV', 4, 80000.00, 160000.00),
    ('Developer', 'DEV', 3, 60000.00, 120000.00),
    ('Coordinator', 'COORD', 3, 40000.00, 80000.00),
    ('Specialist', 'SPEC', 3, 45000.00, 90000.00),
    ('Administrator', 'ADMIN', 2, 35000.00, 70000.00),
    ('Assistant', 'ASST', 1, 25000.00, 50000.00),
    ('Truck Driver', 'DRIVER', 2, 35000.00, 70000.00),
    ('Mechanic', 'MECH', 3, 40000.00, 80000.00),
    ('Senior Mechanic', 'SR-MECH', 4, 50000.00, 100000.00),
    ('Dispatcher', 'DISPATCH', 3, 35000.00, 70000.00);
GO

-- =============================================
-- SECTION 4: SYSTEM SETTINGS
-- =============================================

INSERT INTO [Config].[SystemSettings] (SettingKey, SettingValue, SettingType, SettingDescription)
VALUES
    ('System.Name', 'BIDashboard Enterprise', 'String', 'System name displayed in UI'),
    ('System.Version', '1.0.0', 'String', 'Current system version'),
    ('Session.Timeout', '30', 'Integer', 'Session timeout in minutes'),
    ('Password.MinLength', '8', 'Integer', 'Minimum password length'),
    ('Password.RequireUppercase', 'true', 'Boolean', 'Require uppercase letters in password'),
    ('Password.RequireLowercase', 'true', 'Boolean', 'Require lowercase letters in password'),
    ('Password.RequireNumbers', 'true', 'Boolean', 'Require numbers in password'),
    ('Password.RequireSpecialChars', 'true', 'Boolean', 'Require special characters in password'),
    ('Password.ExpiryDays', '90', 'Integer', 'Password expiry in days'),
    ('Login.MaxAttempts', '5', 'Integer', 'Maximum login attempts before lockout'),
    ('Login.LockoutMinutes', '30', 'Integer', 'Account lockout duration in minutes'),
    ('Email.SMTPServer', 'smtp.example.com', 'String', 'SMTP server address'),
    ('Email.SMTPPort', '587', 'Integer', 'SMTP server port'),
    ('Email.FromAddress', 'noreply@bidashboard.com', 'String', 'System email from address'),
    ('Dashboard.DefaultRefreshMinutes', '60', 'Integer', 'Default dashboard refresh interval'),
    ('Dashboard.MaxUploadSizeMB', '50', 'Integer', 'Maximum file upload size in MB'),
    ('Dashboard.AllowedImageFormats', 'jpg,jpeg,png,gif,webp', 'String', 'Allowed image formats'),
    ('Analytics.RetentionDays', '365', 'Integer', 'Analytics data retention in days'),
    ('Backup.Enabled', 'true', 'Boolean', 'Enable automatic backups'),
    ('Backup.Schedule', '0 2 * * *', 'String', 'Backup schedule in cron format'),
    ('Maintenance.Enabled', 'true', 'Boolean', 'Enable maintenance mode'),
    ('API.RateLimitPerMinute', '100', 'Integer', 'API rate limit per minute'),
    ('API.TokenExpiryMinutes', '60', 'Integer', 'API token expiry in minutes'),
    ('TwoFactor.Enabled', 'false', 'Boolean', 'Enable two-factor authentication'),
    ('AuditLog.Enabled', 'true', 'Boolean', 'Enable audit logging');
GO

-- =============================================
-- SECTION 5: SAMPLE USERS (FOR TESTING ONLY)
-- =============================================

-- NOTE: These are sample users with bcrypt hashed passwords
-- Password for all sample users is: "Password123!"
-- In production, remove this section

DECLARE @SamplePasswordHash NVARCHAR(255) = '$2b$12$P2vcrmhgkVBu4Nl3c9x0nOhmzSeDeWPfRwP.U8dt3l0veOP2AiKxi';
DECLARE @SamplePasswordSalt NVARCHAR(255) = '$2b$12$P2vcrmhgkVBu4Nl3c9x0nO';

-- Insert sample users
INSERT INTO [Security].[Users] (Username, Email, PasswordHash, PasswordSalt, FirstName, LastName, IsEmailVerified, CreatedBy)
VALUES
    ('admin', 'admin@bidashboard.com', @SamplePasswordHash, @SamplePasswordSalt, 'System', 'Administrator', 1, 1),
    ('john.doe', 'john.doe@company.com', @SamplePasswordHash, @SamplePasswordSalt, 'John', 'Doe', 1, 1),
    ('jane.smith', 'jane.smith@company.com', @SamplePasswordHash, @SamplePasswordSalt, 'Jane', 'Smith', 1, 1),
    ('mike.johnson', 'mike.johnson@company.com', @SamplePasswordHash, @SamplePasswordSalt, 'Mike', 'Johnson', 1, 1),
    ('sarah.williams', 'sarah.williams@company.com', @SamplePasswordHash, @SamplePasswordSalt, 'Sarah', 'Williams', 1, 1);
GO

-- Assign roles to sample users
DECLARE @AdminUserID INT, @JohnID INT, @JaneID INT, @MikeID INT, @SarahID INT;

SELECT @AdminUserID = UserID FROM [Security].[Users] WHERE Username = 'admin';
SELECT @JohnID = UserID FROM [Security].[Users] WHERE Username = 'john.doe';
SELECT @JaneID = UserID FROM [Security].[Users] WHERE Username = 'jane.smith';
SELECT @MikeID = UserID FROM [Security].[Users] WHERE Username = 'mike.johnson';
SELECT @SarahID = UserID FROM [Security].[Users] WHERE Username = 'sarah.williams';

-- Assign roles
INSERT INTO [Security].[UserRoles] (UserID, RoleID, AssignedBy)
VALUES
    (@AdminUserID, (SELECT RoleID FROM [Security].[Roles] WHERE RoleName = 'SuperAdmin'), 1),
    (@JohnID, (SELECT RoleID FROM [Security].[Roles] WHERE RoleName = 'Manager'), 1),
    (@JaneID, (SELECT RoleID FROM [Security].[Roles] WHERE RoleName = 'HR_Admin'), 1),
    (@MikeID, (SELECT RoleID FROM [Security].[Roles] WHERE RoleName = 'User'), 1),
    (@SarahID, (SELECT RoleID FROM [Security].[Roles] WHERE RoleName = 'Admin'), 1);
GO

PRINT 'Initial data populated successfully.';
GO