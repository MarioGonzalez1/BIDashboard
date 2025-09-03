-- =============================================
-- BIDashboard Stored Procedures
-- Version: 1.0
-- Author: Senior Database Architect
-- Date: 2025-09-03
-- Description: Core stored procedures for application operations
-- =============================================

USE BIDashboard;
GO

-- =============================================
-- SECTION 1: USER AUTHENTICATION PROCEDURES
-- =============================================

-- Procedure to authenticate user
CREATE PROCEDURE [Security].[sp_AuthenticateUser]
    @Username NVARCHAR(50) = NULL,
    @Email NVARCHAR(255) = NULL,
    @PasswordHash NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @UserID INT;
    DECLARE @StoredHash NVARCHAR(255);
    DECLARE @IsActive BIT;
    DECLARE @AccountLockedUntil DATETIME2(7);
    DECLARE @FailedAttempts INT;
    
    -- Get user information
    SELECT 
        @UserID = UserID,
        @StoredHash = PasswordHash,
        @IsActive = IsActive,
        @AccountLockedUntil = AccountLockedUntil,
        @FailedAttempts = FailedLoginAttempts
    FROM [Security].[Users]
    WHERE (Username = @Username OR Email = @Email)
        AND IsDeleted = 0;
    
    -- Check if user exists
    IF @UserID IS NULL
    BEGIN
        SELECT 
            0 AS Success,
            'Invalid username or password' AS Message,
            NULL AS UserID;
        RETURN;
    END
    
    -- Check if account is locked
    IF @AccountLockedUntil IS NOT NULL AND @AccountLockedUntil > SYSDATETIME()
    BEGIN
        SELECT 
            0 AS Success,
            'Account is locked. Please try again later.' AS Message,
            NULL AS UserID;
        RETURN;
    END
    
    -- Check if account is active
    IF @IsActive = 0
    BEGIN
        SELECT 
            0 AS Success,
            'Account is inactive. Please contact administrator.' AS Message,
            NULL AS UserID;
        RETURN;
    END
    
    -- Verify password
    IF @StoredHash = @PasswordHash
    BEGIN
        -- Reset failed attempts and update last login
        UPDATE [Security].[Users]
        SET 
            FailedLoginAttempts = 0,
            AccountLockedUntil = NULL,
            LastLoginDate = SYSDATETIME()
        WHERE UserID = @UserID;
        
        -- Return user details with roles
        SELECT 
            1 AS Success,
            'Authentication successful' AS Message,
            u.UserID,
            u.Username,
            u.Email,
            u.FirstName,
            u.LastName,
            u.DisplayName,
            u.ProfilePictureURL,
            u.MustChangePassword,
            u.TwoFactorEnabled,
            STRING_AGG(r.RoleName, ',') AS Roles
        FROM [Security].[Users] u
        LEFT JOIN [Security].[UserRoles] ur ON u.UserID = ur.UserID AND ur.IsActive = 1
        LEFT JOIN [Security].[Roles] r ON ur.RoleID = r.RoleID
        WHERE u.UserID = @UserID
        GROUP BY u.UserID, u.Username, u.Email, u.FirstName, u.LastName, 
                 u.DisplayName, u.ProfilePictureURL, u.MustChangePassword, u.TwoFactorEnabled;
    END
    ELSE
    BEGIN
        -- Increment failed attempts
        SET @FailedAttempts = @FailedAttempts + 1;
        
        -- Lock account after 5 failed attempts
        IF @FailedAttempts >= 5
        BEGIN
            UPDATE [Security].[Users]
            SET 
                FailedLoginAttempts = @FailedAttempts,
                AccountLockedUntil = DATEADD(MINUTE, 30, SYSDATETIME())
            WHERE UserID = @UserID;
            
            SELECT 
                0 AS Success,
                'Too many failed attempts. Account locked for 30 minutes.' AS Message,
                NULL AS UserID;
        END
        ELSE
        BEGIN
            UPDATE [Security].[Users]
            SET FailedLoginAttempts = @FailedAttempts
            WHERE UserID = @UserID;
            
            SELECT 
                0 AS Success,
                'Invalid username or password' AS Message,
                NULL AS UserID;
        END
    END
END;
GO

-- Procedure to register new user
CREATE PROCEDURE [Security].[sp_RegisterUser]
    @Username NVARCHAR(50),
    @Email NVARCHAR(255),
    @PasswordHash NVARCHAR(255),
    @PasswordSalt NVARCHAR(255),
    @FirstName NVARCHAR(100) = NULL,
    @LastName NVARCHAR(100) = NULL,
    @CreatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Check if username already exists
        IF EXISTS (SELECT 1 FROM [Security].[Users] WHERE Username = @Username)
        BEGIN
            SELECT 
                0 AS Success,
                'Username already exists' AS Message,
                NULL AS UserID;
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Check if email already exists
        IF EXISTS (SELECT 1 FROM [Security].[Users] WHERE Email = @Email)
        BEGIN
            SELECT 
                0 AS Success,
                'Email already exists' AS Message,
                NULL AS UserID;
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Insert new user
        DECLARE @UserID INT;
        DECLARE @EmailToken UNIQUEIDENTIFIER = NEWID();
        
        INSERT INTO [Security].[Users] (
            Username, Email, PasswordHash, PasswordSalt,
            FirstName, LastName, DisplayName,
            EmailVerificationToken, CreatedBy
        )
        VALUES (
            @Username, @Email, @PasswordHash, @PasswordSalt,
            @FirstName, @LastName, 
            ISNULL(@FirstName + ' ' + @LastName, @Username),
            @EmailToken, @CreatedBy
        );
        
        SET @UserID = SCOPE_IDENTITY();
        
        -- Assign default role (User)
        DECLARE @DefaultRoleID INT;
        SELECT @DefaultRoleID = RoleID FROM [Security].[Roles] WHERE RoleName = 'User';
        
        IF @DefaultRoleID IS NOT NULL
        BEGIN
            INSERT INTO [Security].[UserRoles] (UserID, RoleID, AssignedBy)
            VALUES (@UserID, @DefaultRoleID, ISNULL(@CreatedBy, @UserID));
        END
        
        COMMIT TRANSACTION;
        
        SELECT 
            1 AS Success,
            'User registered successfully' AS Message,
            @UserID AS UserID,
            @EmailToken AS EmailVerificationToken;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SELECT 
            0 AS Success,
            ERROR_MESSAGE() AS Message,
            NULL AS UserID;
    END CATCH
END;
GO

-- =============================================
-- SECTION 2: DASHBOARD PROCEDURES
-- =============================================

-- Procedure to get dashboards with filtering and pagination
CREATE PROCEDURE [Dashboard].[sp_GetDashboards]
    @UserID INT = NULL,
    @CategoryID INT = NULL,
    @SearchTerm NVARCHAR(200) = NULL,
    @IsPublic BIT = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 20,
    @SortBy NVARCHAR(50) = 'CreatedDate',
    @SortOrder NVARCHAR(4) = 'DESC'
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Calculate offset
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Build dynamic query for flexibility
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @WhereClause NVARCHAR(MAX) = ' WHERE d.IsActive = 1 AND d.IsDeleted = 0';
    DECLARE @OrderClause NVARCHAR(MAX);
    
    -- Add filters
    IF @CategoryID IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND (d.CategoryID = @CategoryID OR d.SubcategoryID = @CategoryID)';
    
    IF @IsPublic IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND d.IsPublic = @IsPublic';
    
    IF @SearchTerm IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND (d.DashboardTitle LIKE ''%'' + @SearchTerm + ''%'' 
            OR d.DashboardDescription LIKE ''%'' + @SearchTerm + ''%'' 
            OR d.Tags LIKE ''%'' + @SearchTerm + ''%'')';
    
    -- Check user permissions if not public
    IF @UserID IS NOT NULL AND @IsPublic != 1
    BEGIN
        SET @WhereClause = @WhereClause + ' AND (
            d.IsPublic = 1 
            OR d.CreatedBy = @UserID
            OR EXISTS (
                SELECT 1 FROM [Security].[UserRoles] ur
                WHERE ur.UserID = @UserID 
                AND ur.IsActive = 1
                AND (d.MinimumRole IS NULL OR ur.RoleID >= d.MinimumRole)
            )
        )';
    END
    
    -- Build order clause
    SET @OrderClause = ' ORDER BY ' +
        CASE @SortBy
            WHEN 'Title' THEN 'd.DashboardTitle'
            WHEN 'ViewCount' THEN 'd.ViewCount'
            WHEN 'Rating' THEN 'd.AverageRating'
            WHEN 'CreatedDate' THEN 'd.CreatedDate'
            ELSE 'd.CreatedDate'
        END + ' ' + @SortOrder;
    
    -- Get total count
    DECLARE @TotalCount INT;
    SET @SQL = 'SELECT @TotalCount = COUNT(*) 
                FROM [Dashboard].[Dashboards] d' + @WhereClause;
    
    EXEC sp_executesql @SQL, 
        N'@TotalCount INT OUTPUT, @CategoryID INT, @IsPublic BIT, @SearchTerm NVARCHAR(200), @UserID INT',
        @TotalCount OUTPUT, @CategoryID, @IsPublic, @SearchTerm, @UserID;
    
    -- Get paginated results with category information
    SELECT 
        d.DashboardID,
        d.DashboardTitle,
        d.DashboardSlug,
        d.DashboardDescription,
        d.CategoryID,
        c.CategoryName,
        d.SubcategoryID,
        sc.CategoryName AS SubcategoryName,
        d.AccessURL,
        d.ThumbnailURL,
        d.DashboardType,
        d.RefreshFrequency,
        d.LastRefreshDate,
        d.ViewCount,
        d.FavoriteCount,
        d.AverageRating,
        d.Tags,
        d.IsPublic,
        d.CreatedDate,
        d.CreatedBy,
        u.DisplayName AS CreatedByName,
        d.ModifiedDate,
        CASE WHEN uf.FavoriteID IS NOT NULL THEN 1 ELSE 0 END AS IsFavorite,
        @TotalCount AS TotalCount,
        CEILING(CAST(@TotalCount AS FLOAT) / @PageSize) AS TotalPages
    FROM [Dashboard].[Dashboards] d
    INNER JOIN [Dashboard].[Categories] c ON d.CategoryID = c.CategoryID
    LEFT JOIN [Dashboard].[Categories] sc ON d.SubcategoryID = sc.CategoryID
    INNER JOIN [Security].[Users] u ON d.CreatedBy = u.UserID
    LEFT JOIN [Dashboard].[UserFavorites] uf ON d.DashboardID = uf.DashboardID AND uf.UserID = @UserID
    WHERE d.IsActive = 1 AND d.IsDeleted = 0
        AND (@CategoryID IS NULL OR d.CategoryID = @CategoryID OR d.SubcategoryID = @CategoryID)
        AND (@IsPublic IS NULL OR d.IsPublic = @IsPublic)
        AND (@SearchTerm IS NULL OR 
            d.DashboardTitle LIKE '%' + @SearchTerm + '%' OR
            d.DashboardDescription LIKE '%' + @SearchTerm + '%' OR
            d.Tags LIKE '%' + @SearchTerm + '%')
    ORDER BY 
        CASE WHEN @SortBy = 'Title' AND @SortOrder = 'ASC' THEN d.DashboardTitle END ASC,
        CASE WHEN @SortBy = 'Title' AND @SortOrder = 'DESC' THEN d.DashboardTitle END DESC,
        CASE WHEN @SortBy = 'ViewCount' AND @SortOrder = 'ASC' THEN d.ViewCount END ASC,
        CASE WHEN @SortBy = 'ViewCount' AND @SortOrder = 'DESC' THEN d.ViewCount END DESC,
        CASE WHEN @SortBy = 'Rating' AND @SortOrder = 'ASC' THEN d.AverageRating END ASC,
        CASE WHEN @SortBy = 'Rating' AND @SortOrder = 'DESC' THEN d.AverageRating END DESC,
        CASE WHEN @SortBy = 'CreatedDate' AND @SortOrder = 'ASC' THEN d.CreatedDate END ASC,
        CASE WHEN @SortBy = 'CreatedDate' AND @SortOrder = 'DESC' THEN d.CreatedDate END DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- Procedure to log dashboard access
CREATE PROCEDURE [Dashboard].[sp_LogDashboardAccess]
    @DashboardID INT,
    @UserID INT = NULL,
    @IPAddress NVARCHAR(45) = NULL,
    @UserAgent NVARCHAR(500) = NULL,
    @SessionID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Insert access log
        INSERT INTO [Dashboard].[AccessLog] (
            DashboardID, UserID, IPAddress, UserAgent, SessionID
        )
        VALUES (
            @DashboardID, @UserID, @IPAddress, @UserAgent, @SessionID
        );
        
        -- Update view count (using atomic operation)
        UPDATE [Dashboard].[Dashboards]
        SET ViewCount = ViewCount + 1
        WHERE DashboardID = @DashboardID;
        
        SELECT 1 AS Success;
    END TRY
    BEGIN CATCH
        SELECT 0 AS Success, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

-- =============================================
-- SECTION 3: EMPLOYEE PROCEDURES
-- =============================================

-- Procedure to get employees with filtering
CREATE PROCEDURE [HR].[sp_GetEmployees]
    @DepartmentID INT = NULL,
    @PositionID INT = NULL,
    @EmploymentStatus NVARCHAR(20) = NULL,
    @SearchTerm NVARCHAR(200) = NULL,
    @IncludeInactive BIT = 0,
    @PageNumber INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Get total count
    DECLARE @TotalCount INT;
    SELECT @TotalCount = COUNT(*)
    FROM [HR].[Employees] e
    WHERE e.IsDeleted = 0
        AND (@IncludeInactive = 1 OR e.IsActive = 1)
        AND (@DepartmentID IS NULL OR e.DepartmentID = @DepartmentID)
        AND (@PositionID IS NULL OR e.PositionID = @PositionID)
        AND (@EmploymentStatus IS NULL OR e.EmploymentStatus = @EmploymentStatus)
        AND (@SearchTerm IS NULL OR 
            e.FirstName LIKE '%' + @SearchTerm + '%' OR
            e.LastName LIKE '%' + @SearchTerm + '%' OR
            e.Email LIKE '%' + @SearchTerm + '%' OR
            e.EmployeeCode LIKE '%' + @SearchTerm + '%');
    
    -- Get employees with related information
    SELECT 
        e.EmployeeID,
        e.EmployeeCode,
        e.FirstName,
        e.MiddleName,
        e.LastName,
        e.DisplayName,
        e.Email,
        e.Phone,
        e.MobilePhone,
        e.DepartmentID,
        d.DepartmentName,
        e.PositionID,
        p.PositionTitle,
        e.ReportsToEmployeeID,
        m.DisplayName AS ManagerName,
        e.HireDate,
        e.EmploymentType,
        e.EmploymentStatus,
        e.BaseSalary,
        e.Currency,
        e.WorkLocation,
        e.RemoteWorkAllowed,
        e.ProfilePictureURL,
        e.LastReviewDate,
        e.NextReviewDate,
        e.IsActive,
        @TotalCount AS TotalCount,
        CEILING(CAST(@TotalCount AS FLOAT) / @PageSize) AS TotalPages
    FROM [HR].[Employees] e
    INNER JOIN [HR].[Departments] d ON e.DepartmentID = d.DepartmentID
    INNER JOIN [HR].[Positions] p ON e.PositionID = p.PositionID
    LEFT JOIN [HR].[Employees] m ON e.ReportsToEmployeeID = m.EmployeeID
    WHERE e.IsDeleted = 0
        AND (@IncludeInactive = 1 OR e.IsActive = 1)
        AND (@DepartmentID IS NULL OR e.DepartmentID = @DepartmentID)
        AND (@PositionID IS NULL OR e.PositionID = @PositionID)
        AND (@EmploymentStatus IS NULL OR e.EmploymentStatus = @EmploymentStatus)
        AND (@SearchTerm IS NULL OR 
            e.FirstName LIKE '%' + @SearchTerm + '%' OR
            e.LastName LIKE '%' + @SearchTerm + '%' OR
            e.Email LIKE '%' + @SearchTerm + '%' OR
            e.EmployeeCode LIKE '%' + @SearchTerm + '%')
    ORDER BY e.LastName, e.FirstName
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- Procedure to update employee with history tracking
CREATE PROCEDURE [HR].[sp_UpdateEmployee]
    @EmployeeID INT,
    @DepartmentID INT = NULL,
    @PositionID INT = NULL,
    @BaseSalary DECIMAL(19,4) = NULL,
    @EmploymentStatus NVARCHAR(20) = NULL,
    @ModifiedBy INT,
    @ChangeReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Get current values for history
        DECLARE @OldDepartmentID INT, @OldPositionID INT, @OldSalary DECIMAL(19,4), @OldStatus NVARCHAR(20);
        
        SELECT 
            @OldDepartmentID = DepartmentID,
            @OldPositionID = PositionID,
            @OldSalary = BaseSalary,
            @OldStatus = EmploymentStatus
        FROM [HR].[Employees]
        WHERE EmployeeID = @EmployeeID;
        
        -- Update employee
        UPDATE [HR].[Employees]
        SET 
            DepartmentID = ISNULL(@DepartmentID, DepartmentID),
            PositionID = ISNULL(@PositionID, PositionID),
            BaseSalary = ISNULL(@BaseSalary, BaseSalary),
            EmploymentStatus = ISNULL(@EmploymentStatus, EmploymentStatus),
            ModifiedDate = SYSDATETIME(),
            ModifiedBy = @ModifiedBy
        WHERE EmployeeID = @EmployeeID;
        
        -- Determine change type
        DECLARE @ChangeType NVARCHAR(50);
        
        IF @DepartmentID IS NOT NULL AND @DepartmentID != @OldDepartmentID
            SET @ChangeType = 'Transfer';
        ELSE IF @PositionID IS NOT NULL AND @PositionID != @OldPositionID
            SET @ChangeType = 'Promotion';
        ELSE IF @BaseSalary IS NOT NULL AND @BaseSalary != @OldSalary
            SET @ChangeType = 'SalaryChange';
        ELSE IF @EmploymentStatus IS NOT NULL AND @EmploymentStatus != @OldStatus
            SET @ChangeType = 'StatusChange';
        ELSE
            SET @ChangeType = 'Update';
        
        -- Insert history record
        INSERT INTO [HR].[EmployeeHistory] (
            EmployeeID, ChangeType, 
            OldDepartmentID, NewDepartmentID,
            OldPositionID, NewPositionID,
            OldSalary, NewSalary,
            EffectiveDate, Reason, ApprovedBy
        )
        VALUES (
            @EmployeeID, @ChangeType,
            @OldDepartmentID, ISNULL(@DepartmentID, @OldDepartmentID),
            @OldPositionID, ISNULL(@PositionID, @OldPositionID),
            @OldSalary, ISNULL(@BaseSalary, @OldSalary),
            CAST(SYSDATETIME() AS DATE), @ChangeReason, @ModifiedBy
        );
        
        COMMIT TRANSACTION;
        
        SELECT 1 AS Success, 'Employee updated successfully' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SELECT 0 AS Success, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

-- =============================================
-- SECTION 4: ANALYTICS PROCEDURES
-- =============================================

-- Procedure to get dashboard analytics
CREATE PROCEDURE [Dashboard].[sp_GetDashboardAnalytics]
    @DashboardID INT = NULL,
    @StartDate DATETIME2(7) = NULL,
    @EndDate DATETIME2(7) = NULL,
    @GroupBy NVARCHAR(20) = 'Day' -- Day, Week, Month
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Set default date range if not provided (last 30 days)
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
    
    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    
    -- Get aggregated analytics
    SELECT 
        CASE @GroupBy
            WHEN 'Day' THEN CAST(AccessDate AS DATE)
            WHEN 'Week' THEN DATEADD(WEEK, DATEDIFF(WEEK, 0, AccessDate), 0)
            WHEN 'Month' THEN DATEADD(MONTH, DATEDIFF(MONTH, 0, AccessDate), 0)
        END AS Period,
        COUNT(DISTINCT CASE WHEN UserID IS NOT NULL THEN UserID END) AS UniqueUsers,
        COUNT(DISTINCT CASE WHEN UserID IS NULL THEN IPAddress END) AS AnonymousUsers,
        COUNT(*) AS TotalViews,
        AVG(AccessDuration) AS AvgDurationSeconds
    FROM [Dashboard].[AccessLog]
    WHERE AccessDate BETWEEN @StartDate AND @EndDate
        AND (@DashboardID IS NULL OR DashboardID = @DashboardID)
    GROUP BY 
        CASE @GroupBy
            WHEN 'Day' THEN CAST(AccessDate AS DATE)
            WHEN 'Week' THEN DATEADD(WEEK, DATEDIFF(WEEK, 0, AccessDate), 0)
            WHEN 'Month' THEN DATEADD(MONTH, DATEDIFF(MONTH, 0, AccessDate), 0)
        END
    ORDER BY Period DESC;
    
    -- Get top dashboards if no specific dashboard
    IF @DashboardID IS NULL
    BEGIN
        SELECT TOP 10
            d.DashboardID,
            d.DashboardTitle,
            COUNT(*) AS ViewCount,
            COUNT(DISTINCT al.UserID) AS UniqueUsers,
            AVG(al.AccessDuration) AS AvgDurationSeconds
        FROM [Dashboard].[AccessLog] al
        INNER JOIN [Dashboard].[Dashboards] d ON al.DashboardID = d.DashboardID
        WHERE al.AccessDate BETWEEN @StartDate AND @EndDate
        GROUP BY d.DashboardID, d.DashboardTitle
        ORDER BY ViewCount DESC;
    END
END;
GO

-- =============================================
-- SECTION 5: MAINTENANCE PROCEDURES
-- =============================================

-- Procedure to clean up old data
CREATE PROCEDURE [dbo].[sp_DataCleanup]
    @DaysToKeep INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CutoffDate DATETIME2(7) = DATEADD(DAY, -@DaysToKeep, SYSDATETIME());
    DECLARE @DeletedCount INT = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Delete old refresh tokens
        DELETE FROM [Security].[RefreshTokens]
        WHERE ExpiryDate < @CutoffDate OR RevokedDate < @CutoffDate;
        SET @DeletedCount = @DeletedCount + @@ROWCOUNT;
        
        -- Delete old access logs (keep summary data)
        DELETE FROM [Dashboard].[AccessLog]
        WHERE AccessDate < @CutoffDate;
        SET @DeletedCount = @DeletedCount + @@ROWCOUNT;
        
        -- Archive old audit logs (move to archive table if exists)
        IF OBJECT_ID('[Audit].[AuditLogArchive]') IS NOT NULL
        BEGIN
            INSERT INTO [Audit].[AuditLogArchive]
            SELECT * FROM [Audit].[AuditLog]
            WHERE AuditDate < @CutoffDate;
            
            DELETE FROM [Audit].[AuditLog]
            WHERE AuditDate < @CutoffDate;
            SET @DeletedCount = @DeletedCount + @@ROWCOUNT;
        END
        
        COMMIT TRANSACTION;
        
        SELECT 
            1 AS Success,
            CONCAT('Cleanup completed. ', @DeletedCount, ' records deleted.') AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SELECT 
            0 AS Success,
            ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

PRINT 'All stored procedures created successfully.';
GO