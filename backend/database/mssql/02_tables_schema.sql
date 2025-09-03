/*
=================================================================
BIDashboard - SQL Server Tables and Schema Creation Script
Author: Database Architect  
Date: 2025-09-03
Description: Creates all tables, schemas, and relationships for BIDashboard
=================================================================
*/

USE BIDashboard;
GO

-- Create schemas for organization
CREATE SCHEMA Security AUTHORIZATION dbo;
CREATE SCHEMA Dashboard AUTHORIZATION dbo;
CREATE SCHEMA HR AUTHORIZATION dbo;
CREATE SCHEMA Audit AUTHORIZATION dbo;
CREATE SCHEMA Config AUTHORIZATION dbo;
GO

-- =================================================================
-- SECURITY SCHEMA TABLES
-- =================================================================

-- Users table
CREATE TABLE Security.Users (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(50) NOT NULL UNIQUE,
    HashedPassword NVARCHAR(255) NOT NULL,
    IsAdmin BIT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    EmailAddress NVARCHAR(255) NULL,
    FirstName NVARCHAR(100) NULL,
    LastName NVARCHAR(100) NULL,
    LastLoginDate DATETIME2 NULL,
    FailedLoginAttempts INT NOT NULL DEFAULT 0,
    IsLockedOut BIT NOT NULL DEFAULT 0,
    LockoutEndTime DATETIME2 NULL,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 NULL,
    CreatedBy INT NULL,
    ModifiedBy INT NULL
);
GO

-- User Sessions table for JWT tracking
CREATE TABLE Security.UserSessions (
    SessionID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    TokenHash NVARCHAR(255) NOT NULL,
    ExpiryDate DATETIME2 NOT NULL,
    IsRevoked BIT NOT NULL DEFAULT 0,
    IPAddress NVARCHAR(45) NULL,
    UserAgent NVARCHAR(500) NULL,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    FOREIGN KEY (UserID) REFERENCES Security.Users(UserID) ON DELETE CASCADE
);
GO

-- User Roles table
CREATE TABLE Security.UserRoles (
    RoleID INT IDENTITY(1,1) PRIMARY KEY,
    RoleName NVARCHAR(50) NOT NULL UNIQUE,
    Description NVARCHAR(255) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);
GO

-- User Role Assignments
CREATE TABLE Security.UserRoleAssignments (
    UserRoleID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    RoleID INT NOT NULL,
    AssignedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    AssignedBy INT NOT NULL,
    FOREIGN KEY (UserID) REFERENCES Security.Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (RoleID) REFERENCES Security.UserRoles(RoleID),
    FOREIGN KEY (AssignedBy) REFERENCES Security.Users(UserID),
    UNIQUE (UserID, RoleID)
);
GO

-- =================================================================
-- DASHBOARD SCHEMA TABLES
-- =================================================================

-- Dashboard Categories
CREATE TABLE Dashboard.Categories (
    CategoryID INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(255) NULL,
    IconClass NVARCHAR(50) NULL,
    SortOrder INT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CreatedBy INT NOT NULL,
    FOREIGN KEY (CreatedBy) REFERENCES Security.Users(UserID)
);
GO

-- Dashboard Subcategories
CREATE TABLE Dashboard.Subcategories (
    SubcategoryID INT IDENTITY(1,1) PRIMARY KEY,
    CategoryID INT NOT NULL,
    SubcategoryName NVARCHAR(100) NOT NULL,
    Description NVARCHAR(255) NULL,
    SortOrder INT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CreatedBy INT NOT NULL,
    FOREIGN KEY (CategoryID) REFERENCES Dashboard.Categories(CategoryID),
    FOREIGN KEY (CreatedBy) REFERENCES Security.Users(UserID),
    UNIQUE (CategoryID, SubcategoryName)
);
GO

-- Main Dashboards table
CREATE TABLE Dashboard.Dashboards (
    DashboardID INT IDENTITY(1,1) PRIMARY KEY,
    Title NVARCHAR(200) NOT NULL,
    AccessURL NVARCHAR(MAX) NOT NULL,
    CategoryID INT NOT NULL,
    SubcategoryID INT NULL,
    Description NVARCHAR(MAX) NULL,
    PreviewImageURL NVARCHAR(500) NULL,
    Tags NVARCHAR(500) NULL, -- JSON array of tags
    IsActive BIT NOT NULL DEFAULT 1,
    IsPublic BIT NOT NULL DEFAULT 1,
    ViewCount INT NOT NULL DEFAULT 0,
    LastAccessedDate DATETIME2 NULL,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 NULL,
    CreatedBy INT NOT NULL,
    ModifiedBy INT NULL,
    FOREIGN KEY (CategoryID) REFERENCES Dashboard.Categories(CategoryID),
    FOREIGN KEY (SubcategoryID) REFERENCES Dashboard.Subcategories(SubcategoryID),
    FOREIGN KEY (CreatedBy) REFERENCES Security.Users(UserID),
    FOREIGN KEY (ModifiedBy) REFERENCES Security.Users(UserID)
);
GO

-- Dashboard Access Permissions
CREATE TABLE Dashboard.DashboardPermissions (
    PermissionID INT IDENTITY(1,1) PRIMARY KEY,
    DashboardID INT NOT NULL,
    UserID INT NULL,
    RoleID INT NULL,
    PermissionType NVARCHAR(20) NOT NULL CHECK (PermissionType IN ('View', 'Edit', 'Admin')),
    GrantedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    GrantedBy INT NOT NULL,
    FOREIGN KEY (DashboardID) REFERENCES Dashboard.Dashboards(DashboardID) ON DELETE CASCADE,
    FOREIGN KEY (UserID) REFERENCES Security.Users(UserID),
    FOREIGN KEY (RoleID) REFERENCES Security.UserRoles(RoleID),
    FOREIGN KEY (GrantedBy) REFERENCES Security.Users(UserID),
    CHECK ((UserID IS NOT NULL AND RoleID IS NULL) OR (UserID IS NULL AND RoleID IS NOT NULL))
);
GO

-- Dashboard Usage Analytics
CREATE TABLE Dashboard.DashboardAnalytics (
    AnalyticsID INT IDENTITY(1,1) PRIMARY KEY,
    DashboardID INT NOT NULL,
    UserID INT NOT NULL,
    AccessDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    SessionDurationMinutes INT NULL,
    IPAddress NVARCHAR(45) NULL,
    UserAgent NVARCHAR(500) NULL,
    FOREIGN KEY (DashboardID) REFERENCES Dashboard.Dashboards(DashboardID),
    FOREIGN KEY (UserID) REFERENCES Security.Users(UserID)
);
GO

-- =================================================================
-- HR SCHEMA TABLES
-- =================================================================

-- Departments table
CREATE TABLE HR.Departments (
    DepartmentID INT IDENTITY(1,1) PRIMARY KEY,
    DepartmentName NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(255) NULL,
    ManagerUserID INT NULL,
    Budget DECIMAL(15,2) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    FOREIGN KEY (ManagerUserID) REFERENCES Security.Users(UserID)
);
GO

-- Positions table
CREATE TABLE HR.Positions (
    PositionID INT IDENTITY(1,1) PRIMARY KEY,
    DepartmentID INT NOT NULL,
    PositionName NVARCHAR(100) NOT NULL,
    Description NVARCHAR(500) NULL,
    MinSalary DECIMAL(10,2) NULL,
    MaxSalary DECIMAL(10,2) NULL,
    RequiredSkills NVARCHAR(MAX) NULL, -- JSON array
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    FOREIGN KEY (DepartmentID) REFERENCES HR.Departments(DepartmentID),
    UNIQUE (DepartmentID, PositionName)
);
GO

-- Employees table
CREATE TABLE HR.Employees (
    EmployeeID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeNumber NVARCHAR(20) NOT NULL UNIQUE,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    EmailAddress NVARCHAR(255) NOT NULL UNIQUE,
    PhoneNumber NVARCHAR(20) NULL,
    DepartmentID INT NOT NULL,
    PositionID INT NOT NULL,
    ManagerEmployeeID INT NULL,
    Salary DECIMAL(10,2) NOT NULL,
    HireDate DATE NOT NULL,
    TerminationDate DATE NULL,
    EmploymentStatus NVARCHAR(20) NOT NULL DEFAULT 'Active' CHECK (EmploymentStatus IN ('Active', 'Inactive', 'Terminated', 'OnLeave')),
    Address NVARCHAR(500) NULL,
    DateOfBirth DATE NULL,
    EmergencyContact NVARCHAR(MAX) NULL, -- JSON object
    Notes NVARCHAR(MAX) NULL,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 NULL,
    CreatedBy INT NOT NULL,
    ModifiedBy INT NULL,
    FOREIGN KEY (DepartmentID) REFERENCES HR.Departments(DepartmentID),
    FOREIGN KEY (PositionID) REFERENCES HR.Positions(PositionID),
    FOREIGN KEY (ManagerEmployeeID) REFERENCES HR.Employees(EmployeeID),
    FOREIGN KEY (CreatedBy) REFERENCES Security.Users(UserID),
    FOREIGN KEY (ModifiedBy) REFERENCES Security.Users(UserID)
);
GO

-- Employee Performance Reviews
CREATE TABLE HR.PerformanceReviews (
    ReviewID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    ReviewerID INT NOT NULL,
    ReviewPeriodStart DATE NOT NULL,
    ReviewPeriodEnd DATE NOT NULL,
    OverallRating DECIMAL(3,2) CHECK (OverallRating BETWEEN 1.00 AND 5.00),
    Goals NVARCHAR(MAX) NULL,
    Achievements NVARCHAR(MAX) NULL,
    AreasForImprovement NVARCHAR(MAX) NULL,
    Comments NVARCHAR(MAX) NULL,
    ReviewDate DATE NOT NULL,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    FOREIGN KEY (EmployeeID) REFERENCES HR.Employees(EmployeeID),
    FOREIGN KEY (ReviewerID) REFERENCES HR.Employees(EmployeeID)
);
GO

-- =================================================================
-- AUDIT SCHEMA TABLES  
-- =================================================================

-- Audit Log for all table changes
CREATE TABLE Audit.AuditLog (
    AuditID INT IDENTITY(1,1) PRIMARY KEY,
    TableName NVARCHAR(128) NOT NULL,
    RecordID INT NOT NULL,
    Operation NVARCHAR(10) NOT NULL CHECK (Operation IN ('INSERT', 'UPDATE', 'DELETE')),
    OldValues NVARCHAR(MAX) NULL, -- JSON
    NewValues NVARCHAR(MAX) NULL, -- JSON
    ChangedBy INT NOT NULL,
    ChangedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IPAddress NVARCHAR(45) NULL,
    UserAgent NVARCHAR(500) NULL,
    FOREIGN KEY (ChangedBy) REFERENCES Security.Users(UserID)
);
GO

-- System Events Log
CREATE TABLE Audit.SystemEvents (
    EventID INT IDENTITY(1,1) PRIMARY KEY,
    EventType NVARCHAR(50) NOT NULL,
    EventDescription NVARCHAR(500) NOT NULL,
    Severity NVARCHAR(20) NOT NULL DEFAULT 'Info' CHECK (Severity IN ('Info', 'Warning', 'Error', 'Critical')),
    UserID INT NULL,
    AdditionalData NVARCHAR(MAX) NULL, -- JSON
    CreatedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    FOREIGN KEY (UserID) REFERENCES Security.Users(UserID)
);
GO

-- =================================================================
-- CONFIG SCHEMA TABLES
-- =================================================================

-- Application Configuration
CREATE TABLE Config.AppSettings (
    SettingID INT IDENTITY(1,1) PRIMARY KEY,
    SettingCategory NVARCHAR(50) NOT NULL,
    SettingKey NVARCHAR(100) NOT NULL,
    SettingValue NVARCHAR(MAX) NOT NULL,
    DataType NVARCHAR(20) NOT NULL DEFAULT 'String' CHECK (DataType IN ('String', 'Integer', 'Boolean', 'JSON')),
    Description NVARCHAR(255) NULL,
    IsEncrypted BIT NOT NULL DEFAULT 0,
    ModifiedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    ModifiedBy INT NOT NULL,
    FOREIGN KEY (ModifiedBy) REFERENCES Security.Users(UserID),
    UNIQUE (SettingCategory, SettingKey)
);
GO

PRINT '✅ All tables created successfully!';
PRINT '📊 Tables created:';
PRINT '   - Security: Users, UserSessions, UserRoles, UserRoleAssignments';
PRINT '   - Dashboard: Categories, Subcategories, Dashboards, DashboardPermissions, DashboardAnalytics';
PRINT '   - HR: Departments, Positions, Employees, PerformanceReviews';  
PRINT '   - Audit: AuditLog, SystemEvents';
PRINT '   - Config: AppSettings';
GO