-- =============================================
-- Create User: Mario Gonzalez
-- Email: mario.gonzalez@forzatrans.com
-- Role: Administrator
-- Date: 2025-09-03
-- =============================================

USE BIDashboard;
GO

-- Variables for the user creation
DECLARE @Username NVARCHAR(50) = 'mario.gonzalez';
DECLARE @Email NVARCHAR(255) = 'mario.gonzalez@forzatrans.com';
DECLARE @FirstName NVARCHAR(100) = 'Mario';
DECLARE @LastName NVARCHAR(100) = 'Gonzalez';
DECLARE @DisplayName NVARCHAR(100) = 'Mario Gonzalez';
DECLARE @PasswordHash NVARCHAR(255);
DECLARE @PasswordSalt NVARCHAR(255);
DECLARE @NewUserID INT;
DECLARE @AdminRoleID INT;

-- Generate a temporary password hash (you should change this after first login)
-- This is a bcrypt hash for the password 'ChangeMe2024!'
SET @PasswordHash = '$2b$12$LQv3c1yqBWVHxkd0LQ4F0.g1WvUIe5TZwn.5z8F4tQJ.K9.X8sGHu';
SET @PasswordSalt = NEWID();

PRINT 'Creating user: Mario Gonzalez';

-- Check if user already exists
IF NOT EXISTS (SELECT 1 FROM [Security].[Users] WHERE Email = @Email OR Username = @Username)
BEGIN
    -- Insert the user
    INSERT INTO [Security].[Users] 
    (
        Username, 
        Email, 
        PasswordHash, 
        PasswordSalt, 
        FirstName, 
        LastName, 
        DisplayName,
        IsEmailVerified,
        MustChangePassword,
        CreatedDate,
        IsActive
    )
    VALUES 
    (
        @Username,
        @Email,
        @PasswordHash,
        @PasswordSalt,
        @FirstName,
        @LastName,
        @DisplayName,
        1, -- Email verified
        1, -- Must change password on first login
        SYSDATETIME(),
        1  -- Active
    );

    SET @NewUserID = SCOPE_IDENTITY();
    PRINT 'User created with ID: ' + CAST(@NewUserID AS NVARCHAR(10));

    -- Check if Administrator role exists, if not create it
    IF NOT EXISTS (SELECT 1 FROM [Security].[Roles] WHERE RoleName = 'Administrator')
    BEGIN
        INSERT INTO [Security].[Roles] (RoleName, RoleDescription, IsSystemRole, CreatedDate, IsActive)
        VALUES ('Administrator', 'System Administrator with full access', 1, SYSDATETIME(), 1);
        
        SET @AdminRoleID = SCOPE_IDENTITY();
        PRINT 'Administrator role created with ID: ' + CAST(@AdminRoleID AS NVARCHAR(10));
    END
    ELSE
    BEGIN
        SELECT @AdminRoleID = RoleID FROM [Security].[Roles] WHERE RoleName = 'Administrator';
        PRINT 'Using existing Administrator role with ID: ' + CAST(@AdminRoleID AS NVARCHAR(10));
    END

    -- Assign Administrator role to the user
    IF NOT EXISTS (SELECT 1 FROM [Security].[UserRoles] WHERE UserID = @NewUserID AND RoleID = @AdminRoleID)
    BEGIN
        INSERT INTO [Security].[UserRoles] (UserID, RoleID, AssignedDate, AssignedBy, IsActive)
        VALUES (@NewUserID, @AdminRoleID, SYSDATETIME(), @NewUserID, 1);
        
        PRINT 'Administrator role assigned to user';
    END

    -- Create basic permissions if they don't exist
    DECLARE @Permissions TABLE (PermName NVARCHAR(100), PermDesc NVARCHAR(255), ResourceType NVARCHAR(50), OperationType NVARCHAR(50));
    
    INSERT INTO @Permissions VALUES
    ('Dashboard.Create', 'Create new dashboards', 'Dashboard', 'Create'),
    ('Dashboard.Read', 'View dashboards', 'Dashboard', 'Read'),
    ('Dashboard.Update', 'Modify dashboards', 'Dashboard', 'Update'),
    ('Dashboard.Delete', 'Delete dashboards', 'Dashboard', 'Delete'),
    ('User.Create', 'Create new users', 'User', 'Create'),
    ('User.Read', 'View user information', 'User', 'Read'),
    ('User.Update', 'Modify user information', 'User', 'Update'),
    ('User.Delete', 'Delete users', 'User', 'Delete'),
    ('System.Admin', 'Full system administration', 'System', 'All');

    -- Insert permissions if they don't exist
    DECLARE @PermissionID INT;
    DECLARE permission_cursor CURSOR FOR
        SELECT PermName, PermDesc, ResourceType, OperationType FROM @Permissions;

    OPEN permission_cursor;
    FETCH NEXT FROM permission_cursor INTO @Username, @Email, @FirstName, @LastName; -- Reusing variables

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [Security].[Permissions] WHERE PermissionName = @Username)
        BEGIN
            INSERT INTO [Security].[Permissions] (PermissionName, PermissionDescription, ResourceType, OperationType, CreatedDate, IsActive)
            VALUES (@Username, @Email, @FirstName, @LastName, SYSDATETIME(), 1);
            
            SET @PermissionID = SCOPE_IDENTITY();
            
            -- Assign permission to Administrator role
            IF NOT EXISTS (SELECT 1 FROM [Security].[RolePermissions] WHERE RoleID = @AdminRoleID AND PermissionID = @PermissionID)
            BEGIN
                INSERT INTO [Security].[RolePermissions] (RoleID, PermissionID, GrantedDate, GrantedBy, IsActive)
                VALUES (@AdminRoleID, @PermissionID, SYSDATETIME(), @NewUserID, 1);
            END
        END
        
        FETCH NEXT FROM permission_cursor INTO @Username, @Email, @FirstName, @LastName;
    END

    CLOSE permission_cursor;
    DEALLOCATE permission_cursor;

    -- Create some default categories if they don't exist
    DECLARE @Categories TABLE (CatName NVARCHAR(100), CatDesc NVARCHAR(500), CatSlug NVARCHAR(100));
    
    INSERT INTO @Categories VALUES
    ('Operations', 'Operations and logistics dashboards', 'operations'),
    ('Finance', 'Financial reporting and analysis dashboards', 'finance'),
    ('Accounting', 'Accounting and bookkeeping dashboards', 'accounting'),
    ('Workshop', 'Workshop and maintenance dashboards', 'workshop'),
    ('Human Resources', 'HR and employee management dashboards', 'human-resources'),
    ('Executive & Management', 'Executive and management reporting dashboards', 'executive-management');

    DECLARE category_cursor CURSOR FOR
        SELECT CatName, CatDesc, CatSlug FROM @Categories;

    OPEN category_cursor;
    FETCH NEXT FROM category_cursor INTO @Username, @Email, @FirstName; -- Reusing variables

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [Dashboard].[Categories] WHERE CategoryName = @Username)
        BEGIN
            INSERT INTO [Dashboard].[Categories] (CategoryName, CategoryDescription, CategorySlug, CreatedDate, CreatedBy, IsActive)
            VALUES (@Username, @Email, @FirstName, SYSDATETIME(), @NewUserID, 1);
            
            PRINT 'Created category: ' + @Username;
        END
        
        FETCH NEXT FROM category_cursor INTO @Username, @Email, @FirstName;
    END

    CLOSE category_cursor;
    DEALLOCATE category_cursor;

    PRINT '';
    PRINT '=== USER CREATION SUMMARY ===';
    PRINT 'Username: mario.gonzalez';
    PRINT 'Email: mario.gonzalez@forzatrans.com';
    PRINT 'Full Name: Mario Gonzalez';
    PRINT 'Role: Administrator';
    PRINT 'Temporary Password: ChangeMe2024!';
    PRINT '';
    PRINT 'IMPORTANT: Please change your password after first login!';
    PRINT '=== USER CREATION COMPLETE ===';

END
ELSE
BEGIN
    PRINT 'User with email mario.gonzalez@forzatrans.com or username mario.gonzalez already exists.';
    
    -- Show existing user info
    SELECT 
        UserID,
        Username,
        Email,
        FirstName + ' ' + LastName AS FullName,
        CreatedDate,
        IsActive
    FROM [Security].[Users] 
    WHERE Email = @Email OR Username = @Username;
END

GO