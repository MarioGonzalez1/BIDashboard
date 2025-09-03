-- =============================================
-- BIDashboard Indexes and Performance Optimization Script
-- Version: 1.0
-- Author: Senior Database Architect
-- Date: 2025-09-03
-- Description: Comprehensive indexing strategy for optimal performance
-- =============================================

USE BIDashboard;
GO

-- =============================================
-- SECTION 1: CLUSTERED INDEXES (Already created with PRIMARY KEYs)
-- =============================================
-- Note: Primary keys already create clustered indexes

-- =============================================
-- SECTION 2: NON-CLUSTERED INDEXES FOR SECURITY SCHEMA
-- =============================================

-- Users table indexes
CREATE NONCLUSTERED INDEX IX_Users_Username 
    ON [Security].[Users](Username) 
    INCLUDE (UserID, PasswordHash, IsActive, AccountLockedUntil)
    WHERE IsDeleted = 0
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_Users_Email 
    ON [Security].[Users](Email) 
    INCLUDE (UserID, Username, IsEmailVerified)
    WHERE IsDeleted = 0
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_Users_Active 
    ON [Security].[Users](IsActive, IsDeleted) 
    INCLUDE (UserID, Username, Email, DisplayName)
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_Users_PasswordReset 
    ON [Security].[Users](PasswordResetToken, PasswordResetExpiry)
    WHERE PasswordResetToken IS NOT NULL
    ON [INDEXES];
GO

-- UserRoles indexes
CREATE NONCLUSTERED INDEX IX_UserRoles_UserID 
    ON [Security].[UserRoles](UserID, IsActive) 
    INCLUDE (RoleID, AssignedDate, ExpiryDate)
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_UserRoles_RoleID 
    ON [Security].[UserRoles](RoleID, IsActive) 
    INCLUDE (UserID)
    ON [INDEXES];
GO

-- RefreshTokens indexes
CREATE NONCLUSTERED INDEX IX_RefreshTokens_ExpiryCleanup 
    ON [Security].[RefreshTokens](ExpiryDate, RevokedDate)
    WHERE RevokedDate IS NULL
    ON [INDEXES];
GO

-- RolePermissions indexes
CREATE NONCLUSTERED INDEX IX_RolePermissions_RoleID 
    ON [Security].[RolePermissions](RoleID, IsActive) 
    INCLUDE (PermissionID)
    ON [INDEXES];
GO

-- =============================================
-- SECTION 3: NON-CLUSTERED INDEXES FOR DASHBOARD SCHEMA
-- =============================================

-- Dashboards table indexes
CREATE NONCLUSTERED INDEX IX_Dashboards_Category 
    ON [Dashboard].[Dashboards](CategoryID, IsActive, IsDeleted) 
    INCLUDE (DashboardTitle, AccessURL, ThumbnailURL, ViewCount)
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_Dashboards_Slug 
    ON [Dashboard].[Dashboards](DashboardSlug) 
    INCLUDE (DashboardID, DashboardTitle, CategoryID)
    WHERE IsDeleted = 0
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_Dashboards_Public 
    ON [Dashboard].[Dashboards](IsPublic, IsActive) 
    INCLUDE (DashboardID, DashboardTitle, CategoryID, ViewCount, AverageRating)
    WHERE IsDeleted = 0
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_Dashboards_CreatedBy 
    ON [Dashboard].[Dashboards](CreatedBy, IsDeleted) 
    INCLUDE (DashboardID, DashboardTitle, CreatedDate)
    ON [INDEXES];
GO

-- Filtered index for active dashboards (most common query)
CREATE NONCLUSTERED INDEX IX_Dashboards_ActiveOnly 
    ON [Dashboard].[Dashboards](IsActive, IsDeleted, PublishedDate DESC) 
    INCLUDE (DashboardID, DashboardTitle, CategoryID, AccessURL, ViewCount, AverageRating)
    WHERE IsActive = 1 AND IsDeleted = 0
    ON [INDEXES];
GO

-- Categories indexes
CREATE NONCLUSTERED INDEX IX_Categories_Parent 
    ON [Dashboard].[Categories](ParentCategoryID, IsActive) 
    INCLUDE (CategoryID, CategoryName, DisplayOrder)
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_Categories_Slug 
    ON [Dashboard].[Categories](CategorySlug) 
    INCLUDE (CategoryID, CategoryName)
    WHERE IsActive = 1
    ON [INDEXES];
GO

-- AccessLog indexes (partitioned by date for better performance)
CREATE NONCLUSTERED INDEX IX_AccessLog_Dashboard 
    ON [Dashboard].[AccessLog](DashboardID, AccessDate DESC) 
    INCLUDE (UserID, IPAddress)
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_AccessLog_User 
    ON [Dashboard].[AccessLog](UserID, AccessDate DESC) 
    INCLUDE (DashboardID)
    WHERE UserID IS NOT NULL
    ON [INDEXES];
GO

-- Create columnstore index for analytics on AccessLog (if large volume)
CREATE NONCLUSTERED COLUMNSTORE INDEX IX_AccessLog_Analytics
    ON [Dashboard].[AccessLog] (DashboardID, UserID, AccessDate, AccessDuration)
    ON [INDEXES];
GO

-- UserFavorites indexes
CREATE NONCLUSTERED INDEX IX_UserFavorites_User 
    ON [Dashboard].[UserFavorites](UserID) 
    INCLUDE (DashboardID, AddedDate, DisplayOrder)
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_UserFavorites_Dashboard 
    ON [Dashboard].[UserFavorites](DashboardID) 
    INCLUDE (UserID)
    ON [INDEXES];
GO

-- Ratings indexes
CREATE NONCLUSTERED INDEX IX_Ratings_Dashboard 
    ON [Dashboard].[Ratings](DashboardID) 
    INCLUDE (Rating, UserID, RatingDate)
    ON [INDEXES];
GO

-- =============================================
-- SECTION 4: NON-CLUSTERED INDEXES FOR HR SCHEMA
-- =============================================

-- Employees table indexes
CREATE NONCLUSTERED INDEX IX_Employees_Department 
    ON [HR].[Employees](DepartmentID, IsActive) 
    INCLUDE (EmployeeID, FirstName, LastName, PositionID, Email)
    WHERE IsDeleted = 0
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_Employees_Position 
    ON [HR].[Employees](PositionID, IsActive) 
    INCLUDE (EmployeeID, DepartmentID, BaseSalary)
    WHERE IsDeleted = 0
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_Employees_ReportsTo 
    ON [HR].[Employees](ReportsToEmployeeID) 
    INCLUDE (EmployeeID, FirstName, LastName, DepartmentID)
    WHERE IsActive = 1 AND IsDeleted = 0
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_Employees_UserID 
    ON [HR].[Employees](UserID) 
    INCLUDE (EmployeeID, Email)
    WHERE UserID IS NOT NULL AND IsDeleted = 0
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_Employees_Status 
    ON [HR].[Employees](EmploymentStatus, IsActive) 
    INCLUDE (EmployeeID, DepartmentID, PositionID)
    WHERE IsDeleted = 0
    ON [INDEXES];
GO

-- Filtered index for active employees (most common query)
CREATE NONCLUSTERED INDEX IX_Employees_ActiveOnly 
    ON [HR].[Employees](EmploymentStatus) 
    INCLUDE (EmployeeID, FirstName, LastName, Email, DepartmentID, PositionID)
    WHERE EmploymentStatus = 'Active' AND IsActive = 1 AND IsDeleted = 0
    ON [INDEXES];
GO

-- Departments indexes
CREATE NONCLUSTERED INDEX IX_Departments_Manager 
    ON [HR].[Departments](ManagerEmployeeID) 
    INCLUDE (DepartmentID, DepartmentName)
    WHERE ManagerEmployeeID IS NOT NULL AND IsActive = 1
    ON [INDEXES];
GO

-- EmployeeHistory indexes
CREATE NONCLUSTERED INDEX IX_EmployeeHistory_Employee 
    ON [HR].[EmployeeHistory](EmployeeID, EffectiveDate DESC) 
    INCLUDE (ChangeType, NewDepartmentID, NewPositionID, NewSalary)
    ON [INDEXES];
GO

CREATE NONCLUSTERED INDEX IX_EmployeeHistory_ChangeType 
    ON [HR].[EmployeeHistory](ChangeType, EffectiveDate DESC) 
    INCLUDE (EmployeeID)
    ON [INDEXES];
GO

-- =============================================
-- SECTION 5: INDEXES FOR AUDIT SCHEMA
-- =============================================

CREATE NONCLUSTERED INDEX IX_AuditLog_TableOperation 
    ON [Audit].[AuditLog](TableName, Operation, AuditDate DESC) 
    INCLUDE (RecordID, UserID)
    ON [INDEXES];
GO

-- =============================================
-- SECTION 6: FULL-TEXT INDEXES FOR SEARCH
-- =============================================

-- Enable Full-Text Search
IF NOT EXISTS (SELECT 1 FROM sys.fulltext_catalogs WHERE name = 'FT_BIDashboard')
BEGIN
    CREATE FULLTEXT CATALOG FT_BIDashboard AS DEFAULT;
END
GO

-- Full-text index on Dashboards
CREATE FULLTEXT INDEX ON [Dashboard].[Dashboards]
(
    DashboardTitle LANGUAGE 1033,
    DashboardDescription LANGUAGE 1033,
    Tags LANGUAGE 1033
)
KEY INDEX PK_Dashboards
ON FT_BIDashboard
WITH (
    CHANGE_TRACKING = AUTO,
    STOPLIST = SYSTEM
);
GO

-- Full-text index on Employees
CREATE FULLTEXT INDEX ON [HR].[Employees]
(
    FirstName LANGUAGE 1033,
    LastName LANGUAGE 1033,
    Notes LANGUAGE 1033
)
KEY INDEX PK_Employees
ON FT_BIDashboard
WITH (
    CHANGE_TRACKING = AUTO,
    STOPLIST = SYSTEM
);
GO

-- =============================================
-- SECTION 7: STATISTICS UPDATES
-- =============================================

-- Update all statistics with fullscan for optimal query plans
UPDATE STATISTICS [Security].[Users] WITH FULLSCAN;
UPDATE STATISTICS [Security].[UserRoles] WITH FULLSCAN;
UPDATE STATISTICS [Dashboard].[Dashboards] WITH FULLSCAN;
UPDATE STATISTICS [Dashboard].[Categories] WITH FULLSCAN;
UPDATE STATISTICS [HR].[Employees] WITH FULLSCAN;
UPDATE STATISTICS [HR].[Departments] WITH FULLSCAN;
GO

-- =============================================
-- SECTION 8: INDEX MAINTENANCE JOBS
-- =============================================

-- Create maintenance procedure for index rebuilding
CREATE PROCEDURE [dbo].[sp_MaintenanceRebuildIndexes]
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TableName NVARCHAR(256);
    DECLARE @IndexName NVARCHAR(256);
    DECLARE @FragPercent FLOAT;
    DECLARE @SQL NVARCHAR(MAX);
    
    DECLARE index_cursor CURSOR FOR
    SELECT 
        SCHEMA_NAME(t.schema_id) + '.' + t.name AS TableName,
        i.name AS IndexName,
        ps.avg_fragmentation_in_percent
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
    INNER JOIN sys.indexes i ON ps.object_id = i.object_id AND ps.index_id = i.index_id
    INNER JOIN sys.tables t ON i.object_id = t.object_id
    WHERE ps.avg_fragmentation_in_percent > 10
        AND ps.index_id > 0
        AND ps.page_count > 100;
    
    OPEN index_cursor;
    FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @FragPercent;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @FragPercent > 30
        BEGIN
            -- Rebuild if fragmentation > 30%
            SET @SQL = 'ALTER INDEX [' + @IndexName + '] ON ' + @TableName + ' REBUILD WITH (ONLINE = ON, FILLFACTOR = 90)';
        END
        ELSE
        BEGIN
            -- Reorganize if fragmentation between 10% and 30%
            SET @SQL = 'ALTER INDEX [' + @IndexName + '] ON ' + @TableName + ' REORGANIZE';
        END
        
        EXEC sp_executesql @SQL;
        
        FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @FragPercent;
    END
    
    CLOSE index_cursor;
    DEALLOCATE index_cursor;
    
    -- Update statistics
    EXEC sp_updatestats;
END;
GO

-- =============================================
-- SECTION 9: MISSING INDEX RECOMMENDATIONS VIEW
-- =============================================

CREATE VIEW [dbo].[vw_MissingIndexes]
AS
SELECT 
    migs.avg_user_impact * (migs.user_seeks + migs.user_scans) AS Impact,
    migs.avg_total_user_cost,
    migs.avg_user_impact,
    migs.user_seeks,
    migs.user_scans,
    OBJECT_SCHEMA_NAME(mid.object_id) + '.' + OBJECT_NAME(mid.object_id) AS TableName,
    'CREATE INDEX IX_' + REPLACE(REPLACE(REPLACE(
        ISNULL(mid.equality_columns, '') + ISNULL(mid.inequality_columns, ''), 
        '[', ''), ']', ''), ', ', '_') 
        + ' ON ' + OBJECT_SCHEMA_NAME(mid.object_id) + '.' + OBJECT_NAME(mid.object_id)
        + ' (' + ISNULL(mid.equality_columns, '')
        + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL 
            THEN ',' ELSE '' END + ISNULL(mid.inequality_columns, '') + ')'
        + CASE WHEN mid.included_columns IS NOT NULL 
            THEN ' INCLUDE (' + mid.included_columns + ')' ELSE '' END AS CreateStatement
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID();
GO

PRINT 'All indexes created successfully. Performance optimization complete.';
GO