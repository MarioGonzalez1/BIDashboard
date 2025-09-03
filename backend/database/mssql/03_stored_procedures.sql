/*
=================================================================
BIDashboard - SQL Server Stored Procedures Script
Author: Database Architect
Date: 2025-09-03
Description: Creates stored procedures for BIDashboard operations
=================================================================
*/

USE BIDashboard;
GO

-- =================================================================
-- USER AUTHENTICATION PROCEDURES
-- =================================================================

-- Authenticate User
CREATE PROCEDURE Security.sp_AuthenticateUser
    @Username NVARCHAR(50),
    @HashedPassword NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @UserID INT, @IsLocked BIT, @FailedAttempts INT;
    
    -- Check if user exists and get details
    SELECT @UserID = UserID, @IsLocked = IsLockedOut, @FailedAttempts = FailedLoginAttempts
    FROM Security.Users 
    WHERE Username = @Username AND IsActive = 1;
    
    -- If user doesn't exist
    IF @UserID IS NULL
    BEGIN
        SELECT 0 AS Success, 'Invalid username or password' AS Message;
        RETURN;
    END
    
    -- Check if account is locked
    IF @IsLocked = 1
    BEGIN
        SELECT 0 AS Success, 'Account is locked due to multiple failed login attempts' AS Message;
        RETURN;
    END
    
    -- Verify password
    IF EXISTS (SELECT 1 FROM Security.Users WHERE UserID = @UserID AND HashedPassword = @HashedPassword)
    BEGIN
        -- Successful login
        UPDATE Security.Users 
        SET LastLoginDate = GETUTCDATE(), 
            FailedLoginAttempts = 0
        WHERE UserID = @UserID;
        
        -- Return user details
        SELECT 1 AS Success, 'Login successful' AS Message, 
               UserID, Username, IsAdmin, EmailAddress, FirstName, LastName
        FROM Security.Users 
        WHERE UserID = @UserID;
        
        -- Log event
        INSERT INTO Audit.SystemEvents (EventType, EventDescription, UserID)
        VALUES ('User Login', 'User logged in successfully', @UserID);
    END
    ELSE
    BEGIN
        -- Failed login
        SET @FailedAttempts = @FailedAttempts + 1;
        
        UPDATE Security.Users 
        SET FailedLoginAttempts = @FailedAttempts,
            IsLockedOut = CASE WHEN @FailedAttempts >= 5 THEN 1 ELSE 0 END,
            LockoutEndTime = CASE WHEN @FailedAttempts >= 5 THEN DATEADD(MINUTE, 30, GETUTCDATE()) ELSE NULL END
        WHERE UserID = @UserID;
        
        SELECT 0 AS Success, 'Invalid username or password' AS Message;
        
        -- Log failed attempt
        INSERT INTO Audit.SystemEvents (EventType, EventDescription, UserID, Severity)
        VALUES ('Failed Login', 'Invalid password attempt', @UserID, 'Warning');
    END
END
GO

-- Register New User
CREATE PROCEDURE Security.sp_RegisterUser
    @Username NVARCHAR(50),
    @HashedPassword NVARCHAR(255),
    @EmailAddress NVARCHAR(255) = NULL,
    @FirstName NVARCHAR(100) = NULL,
    @LastName NVARCHAR(100) = NULL,
    @IsAdmin BIT = 0,
    @CreatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if username already exists
    IF EXISTS (SELECT 1 FROM Security.Users WHERE Username = @Username)
    BEGIN
        SELECT 0 AS Success, 'Username already exists' AS Message;
        RETURN;
    END
    
    -- Check if email already exists
    IF @EmailAddress IS NOT NULL AND EXISTS (SELECT 1 FROM Security.Users WHERE EmailAddress = @EmailAddress)
    BEGIN
        SELECT 0 AS Success, 'Email address already registered' AS Message;
        RETURN;
    END
    
    DECLARE @NewUserID INT;
    
    -- Insert new user
    INSERT INTO Security.Users (Username, HashedPassword, EmailAddress, FirstName, LastName, IsAdmin, CreatedBy)
    VALUES (@Username, @HashedPassword, @EmailAddress, @FirstName, @LastName, @IsAdmin, @CreatedBy);
    
    SET @NewUserID = SCOPE_IDENTITY();
    
    -- Assign default role
    DECLARE @DefaultRoleID INT;
    SELECT @DefaultRoleID = RoleID FROM Security.UserRoles WHERE RoleName = 'User';
    
    IF @DefaultRoleID IS NOT NULL
    BEGIN
        INSERT INTO Security.UserRoleAssignments (UserID, RoleID, AssignedBy)
        VALUES (@NewUserID, @DefaultRoleID, COALESCE(@CreatedBy, @NewUserID));
    END
    
    SELECT 1 AS Success, 'User registered successfully' AS Message, @NewUserID AS UserID;
    
    -- Log event
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, UserID)
    VALUES ('User Registration', 'New user registered: ' + @Username, @NewUserID);
END
GO

-- =================================================================
-- DASHBOARD PROCEDURES
-- =================================================================

-- Get All Dashboards for User
CREATE PROCEDURE Dashboard.sp_GetDashboardsForUser
    @UserID INT,
    @CategoryID INT = NULL,
    @SearchTerm NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        d.DashboardID,
        d.Title,
        d.AccessURL,
        c.CategoryName,
        sc.SubcategoryName,
        d.Description,
        d.PreviewImageURL,
        d.Tags,
        d.ViewCount,
        d.LastAccessedDate,
        d.CreatedDate,
        u.Username AS CreatedByUsername
    FROM Dashboard.Dashboards d
    INNER JOIN Dashboard.Categories c ON d.CategoryID = c.CategoryID
    LEFT JOIN Dashboard.Subcategories sc ON d.SubcategoryID = sc.SubcategoryID
    INNER JOIN Security.Users u ON d.CreatedBy = u.UserID
    WHERE d.IsActive = 1 
        AND (d.IsPublic = 1 OR EXISTS (
            SELECT 1 FROM Dashboard.DashboardPermissions dp 
            WHERE dp.DashboardID = d.DashboardID 
                AND (dp.UserID = @UserID OR dp.RoleID IN (
                    SELECT RoleID FROM Security.UserRoleAssignments WHERE UserID = @UserID
                ))
        ))
        AND (@CategoryID IS NULL OR d.CategoryID = @CategoryID)
        AND (@SearchTerm IS NULL OR d.Title LIKE '%' + @SearchTerm + '%' OR d.Description LIKE '%' + @SearchTerm + '%')
    ORDER BY d.Title;
END
GO

-- Create New Dashboard
CREATE PROCEDURE Dashboard.sp_CreateDashboard
    @Title NVARCHAR(200),
    @AccessURL NVARCHAR(MAX),
    @CategoryID INT,
    @SubcategoryID INT = NULL,
    @Description NVARCHAR(MAX) = NULL,
    @PreviewImageURL NVARCHAR(500) = NULL,
    @Tags NVARCHAR(500) = NULL,
    @IsPublic BIT = 1,
    @CreatedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @NewDashboardID INT;
    
    INSERT INTO Dashboard.Dashboards (
        Title, AccessURL, CategoryID, SubcategoryID, Description, 
        PreviewImageURL, Tags, IsPublic, CreatedBy
    )
    VALUES (
        @Title, @AccessURL, @CategoryID, @SubcategoryID, @Description,
        @PreviewImageURL, @Tags, @IsPublic, @CreatedBy
    );
    
    SET @NewDashboardID = SCOPE_IDENTITY();
    
    -- Grant creator full permissions
    INSERT INTO Dashboard.DashboardPermissions (DashboardID, UserID, PermissionType, GrantedBy)
    VALUES (@NewDashboardID, @CreatedBy, 'Admin', @CreatedBy);
    
    SELECT 1 AS Success, 'Dashboard created successfully' AS Message, @NewDashboardID AS DashboardID;
    
    -- Log event
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, UserID)
    VALUES ('Dashboard Created', 'New dashboard created: ' + @Title, @CreatedBy);
END
GO

-- Update Dashboard
CREATE PROCEDURE Dashboard.sp_UpdateDashboard
    @DashboardID INT,
    @Title NVARCHAR(200),
    @AccessURL NVARCHAR(MAX),
    @CategoryID INT,
    @SubcategoryID INT = NULL,
    @Description NVARCHAR(MAX) = NULL,
    @PreviewImageURL NVARCHAR(500) = NULL,
    @Tags NVARCHAR(500) = NULL,
    @IsPublic BIT = 1,
    @ModifiedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if user has permission to edit
    IF NOT EXISTS (
        SELECT 1 FROM Dashboard.DashboardPermissions dp
        WHERE dp.DashboardID = @DashboardID 
            AND (dp.UserID = @ModifiedBy OR dp.RoleID IN (
                SELECT RoleID FROM Security.UserRoleAssignments WHERE UserID = @ModifiedBy
            ))
            AND dp.PermissionType IN ('Edit', 'Admin')
    ) AND NOT EXISTS (
        SELECT 1 FROM Security.Users WHERE UserID = @ModifiedBy AND IsAdmin = 1
    )
    BEGIN
        SELECT 0 AS Success, 'Insufficient permissions to edit dashboard' AS Message;
        RETURN;
    END
    
    UPDATE Dashboard.Dashboards
    SET Title = @Title,
        AccessURL = @AccessURL,
        CategoryID = @CategoryID,
        SubcategoryID = @SubcategoryID,
        Description = @Description,
        PreviewImageURL = @PreviewImageURL,
        Tags = @Tags,
        IsPublic = @IsPublic,
        ModifiedDate = GETUTCDATE(),
        ModifiedBy = @ModifiedBy
    WHERE DashboardID = @DashboardID AND IsActive = 1;
    
    IF @@ROWCOUNT = 0
    BEGIN
        SELECT 0 AS Success, 'Dashboard not found or inactive' AS Message;
        RETURN;
    END
    
    SELECT 1 AS Success, 'Dashboard updated successfully' AS Message;
    
    -- Log event
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, UserID)
    VALUES ('Dashboard Updated', 'Dashboard updated: ' + @Title, @ModifiedBy);
END
GO

-- Delete Dashboard
CREATE PROCEDURE Dashboard.sp_DeleteDashboard
    @DashboardID INT,
    @DeletedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if user is admin or has admin permission on dashboard
    IF NOT EXISTS (
        SELECT 1 FROM Dashboard.DashboardPermissions dp
        WHERE dp.DashboardID = @DashboardID 
            AND (dp.UserID = @DeletedBy OR dp.RoleID IN (
                SELECT RoleID FROM Security.UserRoleAssignments WHERE UserID = @DeletedBy
            ))
            AND dp.PermissionType = 'Admin'
    ) AND NOT EXISTS (
        SELECT 1 FROM Security.Users WHERE UserID = @DeletedBy AND IsAdmin = 1
    )
    BEGIN
        SELECT 0 AS Success, 'Insufficient permissions to delete dashboard' AS Message;
        RETURN;
    END
    
    DECLARE @DashboardTitle NVARCHAR(200);
    SELECT @DashboardTitle = Title FROM Dashboard.Dashboards WHERE DashboardID = @DashboardID;
    
    -- Soft delete (set IsActive = 0)
    UPDATE Dashboard.Dashboards
    SET IsActive = 0, 
        ModifiedDate = GETUTCDATE(),
        ModifiedBy = @DeletedBy
    WHERE DashboardID = @DashboardID;
    
    IF @@ROWCOUNT = 0
    BEGIN
        SELECT 0 AS Success, 'Dashboard not found' AS Message;
        RETURN;
    END
    
    SELECT 1 AS Success, 'Dashboard deleted successfully' AS Message;
    
    -- Log event
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, UserID)
    VALUES ('Dashboard Deleted', 'Dashboard deleted: ' + @DashboardTitle, @DeletedBy);
END
GO

-- =================================================================
-- EMPLOYEE PROCEDURES
-- =================================================================

-- Get All Employees
CREATE PROCEDURE HR.sp_GetEmployees
    @DepartmentID INT = NULL,
    @EmploymentStatus NVARCHAR(20) = NULL,
    @SearchTerm NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        e.EmployeeID,
        e.EmployeeNumber,
        e.FirstName,
        e.LastName,
        e.EmailAddress,
        e.PhoneNumber,
        d.DepartmentName,
        p.PositionName,
        e.Salary,
        e.HireDate,
        e.TerminationDate,
        e.EmploymentStatus,
        m.FirstName + ' ' + m.LastName AS ManagerName,
        e.CreatedDate
    FROM HR.Employees e
    INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    INNER JOIN HR.Positions p ON e.PositionID = p.PositionID
    LEFT JOIN HR.Employees m ON e.ManagerEmployeeID = m.EmployeeID
    WHERE (@DepartmentID IS NULL OR e.DepartmentID = @DepartmentID)
        AND (@EmploymentStatus IS NULL OR e.EmploymentStatus = @EmploymentStatus)
        AND (@SearchTerm IS NULL OR 
             e.FirstName LIKE '%' + @SearchTerm + '%' OR 
             e.LastName LIKE '%' + @SearchTerm + '%' OR
             e.EmailAddress LIKE '%' + @SearchTerm + '%' OR
             e.EmployeeNumber LIKE '%' + @SearchTerm + '%')
    ORDER BY e.LastName, e.FirstName;
END
GO

-- Create New Employee
CREATE PROCEDURE HR.sp_CreateEmployee
    @EmployeeNumber NVARCHAR(20),
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @EmailAddress NVARCHAR(255),
    @PhoneNumber NVARCHAR(20) = NULL,
    @DepartmentID INT,
    @PositionID INT,
    @ManagerEmployeeID INT = NULL,
    @Salary DECIMAL(10,2),
    @HireDate DATE,
    @Address NVARCHAR(500) = NULL,
    @DateOfBirth DATE = NULL,
    @EmergencyContact NVARCHAR(MAX) = NULL,
    @CreatedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if employee number already exists
    IF EXISTS (SELECT 1 FROM HR.Employees WHERE EmployeeNumber = @EmployeeNumber)
    BEGIN
        SELECT 0 AS Success, 'Employee number already exists' AS Message;
        RETURN;
    END
    
    -- Check if email already exists
    IF EXISTS (SELECT 1 FROM HR.Employees WHERE EmailAddress = @EmailAddress)
    BEGIN
        SELECT 0 AS Success, 'Email address already exists' AS Message;
        RETURN;
    END
    
    DECLARE @NewEmployeeID INT;
    
    INSERT INTO HR.Employees (
        EmployeeNumber, FirstName, LastName, EmailAddress, PhoneNumber,
        DepartmentID, PositionID, ManagerEmployeeID, Salary, HireDate,
        Address, DateOfBirth, EmergencyContact, CreatedBy
    )
    VALUES (
        @EmployeeNumber, @FirstName, @LastName, @EmailAddress, @PhoneNumber,
        @DepartmentID, @PositionID, @ManagerEmployeeID, @Salary, @HireDate,
        @Address, @DateOfBirth, @EmergencyContact, @CreatedBy
    );
    
    SET @NewEmployeeID = SCOPE_IDENTITY();
    
    SELECT 1 AS Success, 'Employee created successfully' AS Message, @NewEmployeeID AS EmployeeID;
    
    -- Log event
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, UserID)
    VALUES ('Employee Created', 'New employee created: ' + @FirstName + ' ' + @LastName, @CreatedBy);
END
GO

-- =================================================================
-- ANALYTICS PROCEDURES
-- =================================================================

-- Dashboard Usage Analytics
CREATE PROCEDURE Dashboard.sp_GetDashboardAnalytics
    @DashboardID INT = NULL,
    @StartDate DATETIME2 = NULL,
    @EndDate DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @StartDate IS NULL SET @StartDate = DATEADD(DAY, -30, GETUTCDATE());
    IF @EndDate IS NULL SET @EndDate = GETUTCDATE();
    
    SELECT 
        d.DashboardID,
        d.Title,
        COUNT(da.AnalyticsID) AS TotalAccesses,
        COUNT(DISTINCT da.UserID) AS UniqueUsers,
        AVG(CAST(da.SessionDurationMinutes AS FLOAT)) AS AvgSessionMinutes,
        MAX(da.AccessDate) AS LastAccessed
    FROM Dashboard.Dashboards d
    LEFT JOIN Dashboard.DashboardAnalytics da ON d.DashboardID = da.DashboardID
        AND da.AccessDate BETWEEN @StartDate AND @EndDate
    WHERE (@DashboardID IS NULL OR d.DashboardID = @DashboardID)
        AND d.IsActive = 1
    GROUP BY d.DashboardID, d.Title
    ORDER BY TotalAccesses DESC;
END
GO

-- System Health Check
CREATE PROCEDURE Config.sp_SystemHealthCheck
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        'Users' AS TableName,
        COUNT(*) AS TotalRecords,
        SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS ActiveRecords,
        MAX(CreatedDate) AS LastCreated
    FROM Security.Users
    
    UNION ALL
    
    SELECT 
        'Dashboards' AS TableName,
        COUNT(*) AS TotalRecords,
        SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS ActiveRecords,
        MAX(CreatedDate) AS LastCreated
    FROM Dashboard.Dashboards
    
    UNION ALL
    
    SELECT 
        'Employees' AS TableName,
        COUNT(*) AS TotalRecords,
        SUM(CASE WHEN EmploymentStatus = 'Active' THEN 1 ELSE 0 END) AS ActiveRecords,
        MAX(CreatedDate) AS LastCreated
    FROM HR.Employees;
    
    -- Recent system events
    SELECT TOP 10 
        EventType,
        EventDescription,
        Severity,
        CreatedDate
    FROM Audit.SystemEvents
    ORDER BY CreatedDate DESC;
END
GO

PRINT '✅ All stored procedures created successfully!';
PRINT '🔧 Procedures created:';
PRINT '   - Authentication: sp_AuthenticateUser, sp_RegisterUser';
PRINT '   - Dashboards: sp_GetDashboardsForUser, sp_CreateDashboard, sp_UpdateDashboard, sp_DeleteDashboard';
PRINT '   - Employees: sp_GetEmployees, sp_CreateEmployee';
PRINT '   - Analytics: sp_GetDashboardAnalytics, sp_SystemHealthCheck';
GO