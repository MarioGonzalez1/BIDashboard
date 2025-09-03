-- =============================================
-- BIDashboard Table Creation Script
-- Version: 1.0
-- Author: Senior Database Architect
-- Date: 2025-09-03
-- Description: Complete table structure with proper normalization and constraints
-- =============================================

USE BIDashboard;
GO

-- =============================================
-- SECTION 1: SECURITY SCHEMA TABLES
-- =============================================

-- Roles table for RBAC (Role-Based Access Control)
CREATE TABLE [Security].[Roles]
(
    RoleID INT IDENTITY(1,1) NOT NULL,
    RoleName NVARCHAR(50) NOT NULL,
    RoleDescription NVARCHAR(255) NULL,
    IsSystemRole BIT NOT NULL DEFAULT 0,
    CreatedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    ModifiedDate DATETIME2(7) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_Roles PRIMARY KEY CLUSTERED (RoleID),
    CONSTRAINT UQ_Roles_RoleName UNIQUE (RoleName)
) ON [PRIMARY];
GO

-- Users table with enhanced security features
CREATE TABLE [Security].[Users]
(
    UserID INT IDENTITY(1,1) NOT NULL,
    Username NVARCHAR(50) NOT NULL,
    Email [dbo].[Email] NOT NULL,
    PasswordHash NVARCHAR(255) NOT NULL,
    PasswordSalt NVARCHAR(255) NOT NULL,
    FirstName NVARCHAR(100) NULL,
    LastName NVARCHAR(100) NULL,
    DisplayName NVARCHAR(100) NULL,
    ProfilePictureURL [dbo].[URL] NULL,
    IsEmailVerified BIT NOT NULL DEFAULT 0,
    EmailVerificationToken UNIQUEIDENTIFIER NULL,
    PasswordResetToken UNIQUEIDENTIFIER NULL,
    PasswordResetExpiry DATETIME2(7) NULL,
    LastLoginDate DATETIME2(7) NULL,
    LastPasswordChangeDate DATETIME2(7) NULL,
    FailedLoginAttempts INT NOT NULL DEFAULT 0,
    AccountLockedUntil DATETIME2(7) NULL,
    MustChangePassword BIT NOT NULL DEFAULT 0,
    TwoFactorEnabled BIT NOT NULL DEFAULT 0,
    TwoFactorSecret NVARCHAR(255) NULL,
    CreatedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    CreatedBy INT NULL,
    ModifiedDate DATETIME2(7) NULL,
    ModifiedBy INT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    IsDeleted BIT NOT NULL DEFAULT 0,
    DeletedDate DATETIME2(7) NULL,
    CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (UserID),
    CONSTRAINT UQ_Users_Username UNIQUE (Username),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT FK_Users_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT FK_Users_ModifiedBy FOREIGN KEY (ModifiedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT CHK_Users_Email CHECK ([dbo].[fn_ValidateEmail](Email) = 1)
) ON [PRIMARY];
GO

-- User Roles junction table (many-to-many relationship)
CREATE TABLE [Security].[UserRoles]
(
    UserRoleID INT IDENTITY(1,1) NOT NULL,
    UserID INT NOT NULL,
    RoleID INT NOT NULL,
    AssignedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    AssignedBy INT NOT NULL,
    ExpiryDate DATETIME2(7) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_UserRoles PRIMARY KEY CLUSTERED (UserRoleID),
    CONSTRAINT FK_UserRoles_UserID FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    CONSTRAINT FK_UserRoles_RoleID FOREIGN KEY (RoleID) REFERENCES [Security].[Roles](RoleID),
    CONSTRAINT FK_UserRoles_AssignedBy FOREIGN KEY (AssignedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT UQ_UserRoles_UserRole UNIQUE (UserID, RoleID)
) ON [PRIMARY];
GO

-- Permissions table for granular access control
CREATE TABLE [Security].[Permissions]
(
    PermissionID INT IDENTITY(1,1) NOT NULL,
    PermissionName NVARCHAR(100) NOT NULL,
    PermissionDescription NVARCHAR(255) NULL,
    ResourceType NVARCHAR(50) NOT NULL, -- 'Dashboard', 'Employee', 'Report', etc.
    OperationType NVARCHAR(50) NOT NULL, -- 'Create', 'Read', 'Update', 'Delete', 'Execute'
    CreatedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_Permissions PRIMARY KEY CLUSTERED (PermissionID),
    CONSTRAINT UQ_Permissions_Name UNIQUE (PermissionName)
) ON [PRIMARY];
GO

-- Role Permissions junction table
CREATE TABLE [Security].[RolePermissions]
(
    RolePermissionID INT IDENTITY(1,1) NOT NULL,
    RoleID INT NOT NULL,
    PermissionID INT NOT NULL,
    GrantedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    GrantedBy INT NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_RolePermissions PRIMARY KEY CLUSTERED (RolePermissionID),
    CONSTRAINT FK_RolePermissions_RoleID FOREIGN KEY (RoleID) REFERENCES [Security].[Roles](RoleID),
    CONSTRAINT FK_RolePermissions_PermissionID FOREIGN KEY (PermissionID) REFERENCES [Security].[Permissions](PermissionID),
    CONSTRAINT FK_RolePermissions_GrantedBy FOREIGN KEY (GrantedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT UQ_RolePermissions_RolePerm UNIQUE (RoleID, PermissionID)
) ON [PRIMARY];
GO

-- JWT Refresh Tokens for session management
CREATE TABLE [Security].[RefreshTokens]
(
    TokenID INT IDENTITY(1,1) NOT NULL,
    UserID INT NOT NULL,
    Token NVARCHAR(500) NOT NULL,
    ExpiryDate DATETIME2(7) NOT NULL,
    CreatedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    CreatedByIP NVARCHAR(45) NULL,
    RevokedDate DATETIME2(7) NULL,
    RevokedByIP NVARCHAR(45) NULL,
    ReplacedByToken NVARCHAR(500) NULL,
    IsActive AS (CASE WHEN RevokedDate IS NULL AND GETDATE() < ExpiryDate THEN 1 ELSE 0 END),
    CONSTRAINT PK_RefreshTokens PRIMARY KEY CLUSTERED (TokenID),
    CONSTRAINT FK_RefreshTokens_UserID FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    INDEX IX_RefreshTokens_Token NONCLUSTERED (Token),
    INDEX IX_RefreshTokens_UserID NONCLUSTERED (UserID)
) ON [PRIMARY];
GO

-- =============================================
-- SECTION 2: DASHBOARD SCHEMA TABLES
-- =============================================

-- Dashboard Categories
CREATE TABLE [Dashboard].[Categories]
(
    CategoryID INT IDENTITY(1,1) NOT NULL,
    CategoryName NVARCHAR(100) NOT NULL,
    CategorySlug NVARCHAR(100) NOT NULL,
    CategoryDescription NVARCHAR(500) NULL,
    CategoryIcon NVARCHAR(50) NULL,
    ParentCategoryID INT NULL,
    DisplayOrder INT NOT NULL DEFAULT 0,
    ColorHex NVARCHAR(7) NULL,
    CreatedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    CreatedBy INT NOT NULL,
    ModifiedDate DATETIME2(7) NULL,
    ModifiedBy INT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_Categories PRIMARY KEY CLUSTERED (CategoryID),
    CONSTRAINT FK_Categories_Parent FOREIGN KEY (ParentCategoryID) REFERENCES [Dashboard].[Categories](CategoryID),
    CONSTRAINT FK_Categories_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT FK_Categories_ModifiedBy FOREIGN KEY (ModifiedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT UQ_Categories_Name UNIQUE (CategoryName),
    CONSTRAINT UQ_Categories_Slug UNIQUE (CategorySlug)
) ON [PRIMARY];
GO

-- Main Dashboards table
CREATE TABLE [Dashboard].[Dashboards]
(
    DashboardID INT IDENTITY(1,1) NOT NULL,
    DashboardTitle NVARCHAR(200) NOT NULL,
    DashboardSlug NVARCHAR(200) NOT NULL,
    DashboardDescription NVARCHAR(MAX) NULL,
    CategoryID INT NOT NULL,
    SubcategoryID INT NULL,
    AccessURL [dbo].[URL] NOT NULL,
    EmbedURL [dbo].[URL] NULL,
    ThumbnailURL [dbo].[URL] NULL,
    PreviewImageBinary VARBINARY(MAX) NULL,
    PreviewImageFileName NVARCHAR(255) NULL,
    PreviewImageContentType NVARCHAR(50) NULL,
    DashboardType NVARCHAR(50) NOT NULL DEFAULT 'PowerBI', -- PowerBI, Tableau, Custom, etc.
    RefreshFrequency NVARCHAR(20) NULL, -- Daily, Weekly, Monthly, Real-time
    LastRefreshDate DATETIME2(7) NULL,
    DataSource NVARCHAR(255) NULL,
    Tags NVARCHAR(500) NULL, -- Comma-separated tags
    ViewCount INT NOT NULL DEFAULT 0,
    FavoriteCount INT NOT NULL DEFAULT 0,
    AverageRating DECIMAL(3,2) NULL,
    IsPublic BIT NOT NULL DEFAULT 0,
    RequiresAuthentication BIT NOT NULL DEFAULT 1,
    MinimumRole INT NULL,
    PublishedDate DATETIME2(7) NULL,
    PublishedBy INT NULL,
    CreatedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    CreatedBy INT NOT NULL,
    ModifiedDate DATETIME2(7) NULL,
    ModifiedBy INT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    IsDeleted BIT NOT NULL DEFAULT 0,
    DeletedDate DATETIME2(7) NULL,
    DeletedBy INT NULL,
    RowVersion ROWVERSION NOT NULL,
    CONSTRAINT PK_Dashboards PRIMARY KEY CLUSTERED (DashboardID),
    CONSTRAINT FK_Dashboards_Category FOREIGN KEY (CategoryID) REFERENCES [Dashboard].[Categories](CategoryID),
    CONSTRAINT FK_Dashboards_Subcategory FOREIGN KEY (SubcategoryID) REFERENCES [Dashboard].[Categories](CategoryID),
    CONSTRAINT FK_Dashboards_MinRole FOREIGN KEY (MinimumRole) REFERENCES [Security].[Roles](RoleID),
    CONSTRAINT FK_Dashboards_PublishedBy FOREIGN KEY (PublishedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT FK_Dashboards_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT FK_Dashboards_ModifiedBy FOREIGN KEY (ModifiedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT FK_Dashboards_DeletedBy FOREIGN KEY (DeletedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT UQ_Dashboards_Slug UNIQUE (DashboardSlug)
) ON [PRIMARY];
GO

-- Dashboard Access Log for analytics
CREATE TABLE [Dashboard].[AccessLog]
(
    LogID BIGINT IDENTITY(1,1) NOT NULL,
    DashboardID INT NOT NULL,
    UserID INT NULL,
    AccessDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    IPAddress NVARCHAR(45) NULL,
    UserAgent NVARCHAR(500) NULL,
    SessionID UNIQUEIDENTIFIER NULL,
    AccessDuration INT NULL, -- in seconds
    CONSTRAINT PK_AccessLog PRIMARY KEY CLUSTERED (LogID),
    CONSTRAINT FK_AccessLog_Dashboard FOREIGN KEY (DashboardID) REFERENCES [Dashboard].[Dashboards](DashboardID),
    CONSTRAINT FK_AccessLog_User FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
) ON [PRIMARY];
GO

-- User Favorites
CREATE TABLE [Dashboard].[UserFavorites]
(
    FavoriteID INT IDENTITY(1,1) NOT NULL,
    UserID INT NOT NULL,
    DashboardID INT NOT NULL,
    AddedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    DisplayOrder INT NULL,
    CONSTRAINT PK_UserFavorites PRIMARY KEY CLUSTERED (FavoriteID),
    CONSTRAINT FK_UserFavorites_User FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    CONSTRAINT FK_UserFavorites_Dashboard FOREIGN KEY (DashboardID) REFERENCES [Dashboard].[Dashboards](DashboardID),
    CONSTRAINT UQ_UserFavorites UNIQUE (UserID, DashboardID)
) ON [PRIMARY];
GO

-- Dashboard Ratings
CREATE TABLE [Dashboard].[Ratings]
(
    RatingID INT IDENTITY(1,1) NOT NULL,
    DashboardID INT NOT NULL,
    UserID INT NOT NULL,
    Rating TINYINT NOT NULL,
    Comment NVARCHAR(1000) NULL,
    RatingDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    ModifiedDate DATETIME2(7) NULL,
    CONSTRAINT PK_Ratings PRIMARY KEY CLUSTERED (RatingID),
    CONSTRAINT FK_Ratings_Dashboard FOREIGN KEY (DashboardID) REFERENCES [Dashboard].[Dashboards](DashboardID),
    CONSTRAINT FK_Ratings_User FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    CONSTRAINT CHK_Ratings_Value CHECK (Rating BETWEEN 1 AND 5),
    CONSTRAINT UQ_Ratings UNIQUE (DashboardID, UserID)
) ON [PRIMARY];
GO

-- =============================================
-- SECTION 3: HR SCHEMA TABLES
-- =============================================

-- Departments table
CREATE TABLE [HR].[Departments]
(
    DepartmentID INT IDENTITY(1,1) NOT NULL,
    DepartmentName NVARCHAR(100) NOT NULL,
    DepartmentCode NVARCHAR(20) NOT NULL,
    ParentDepartmentID INT NULL,
    ManagerEmployeeID INT NULL,
    Budget DECIMAL(19,4) NULL,
    CostCenter NVARCHAR(20) NULL,
    Location NVARCHAR(100) NULL,
    CreatedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    CreatedBy INT NOT NULL,
    ModifiedDate DATETIME2(7) NULL,
    ModifiedBy INT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_Departments PRIMARY KEY CLUSTERED (DepartmentID),
    CONSTRAINT FK_Departments_Parent FOREIGN KEY (ParentDepartmentID) REFERENCES [HR].[Departments](DepartmentID),
    CONSTRAINT FK_Departments_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT FK_Departments_ModifiedBy FOREIGN KEY (ModifiedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT UQ_Departments_Code UNIQUE (DepartmentCode)
) ON [PRIMARY];
GO

-- Job Positions/Titles
CREATE TABLE [HR].[Positions]
(
    PositionID INT IDENTITY(1,1) NOT NULL,
    PositionTitle NVARCHAR(100) NOT NULL,
    PositionCode NVARCHAR(20) NOT NULL,
    PositionLevel INT NOT NULL,
    MinSalary DECIMAL(19,4) NULL,
    MaxSalary DECIMAL(19,4) NULL,
    JobDescription NVARCHAR(MAX) NULL,
    Requirements NVARCHAR(MAX) NULL,
    CreatedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_Positions PRIMARY KEY CLUSTERED (PositionID),
    CONSTRAINT UQ_Positions_Code UNIQUE (PositionCode)
) ON [PRIMARY];
GO

-- Employees table with comprehensive HR data
CREATE TABLE [HR].[Employees]
(
    EmployeeID INT IDENTITY(1,1) NOT NULL,
    EmployeeCode NVARCHAR(20) NOT NULL,
    UserID INT NULL, -- Link to user account if they have system access
    FirstName NVARCHAR(100) NOT NULL,
    MiddleName NVARCHAR(100) NULL,
    LastName NVARCHAR(100) NOT NULL,
    DisplayName AS (FirstName + ' ' + LastName) PERSISTED,
    Email [dbo].[Email] NOT NULL,
    PersonalEmail [dbo].[Email] NULL,
    Phone [dbo].[Phone] NULL,
    MobilePhone [dbo].[Phone] NULL,
    DateOfBirth DATE NULL,
    Gender CHAR(1) NULL,
    MaritalStatus NVARCHAR(20) NULL,
    NationalID NVARCHAR(50) NULL,
    PassportNumber NVARCHAR(50) NULL,
    TaxID NVARCHAR(50) NULL,
    SocialSecurityNumber NVARCHAR(50) NULL,
    -- Employment Information
    DepartmentID INT NOT NULL,
    PositionID INT NOT NULL,
    ReportsToEmployeeID INT NULL,
    HireDate DATE NOT NULL,
    ProbationEndDate DATE NULL,
    EmploymentType NVARCHAR(20) NOT NULL, -- Full-time, Part-time, Contract, Intern
    EmploymentStatus NVARCHAR(20) NOT NULL DEFAULT 'Active', -- Active, Inactive, OnLeave, Terminated
    WorkLocation NVARCHAR(100) NULL,
    RemoteWorkAllowed BIT NOT NULL DEFAULT 0,
    -- Compensation
    BaseSalary DECIMAL(19,4) NOT NULL,
    Currency NVARCHAR(3) NOT NULL DEFAULT 'USD',
    PayFrequency NVARCHAR(20) NOT NULL DEFAULT 'Monthly',
    BankAccountNumber NVARCHAR(50) NULL,
    BankName NVARCHAR(100) NULL,
    -- Address Information
    AddressLine1 NVARCHAR(255) NULL,
    AddressLine2 NVARCHAR(255) NULL,
    City NVARCHAR(100) NULL,
    State NVARCHAR(100) NULL,
    PostalCode NVARCHAR(20) NULL,
    Country NVARCHAR(100) NULL,
    -- Emergency Contact
    EmergencyContactName NVARCHAR(200) NULL,
    EmergencyContactRelation NVARCHAR(50) NULL,
    EmergencyContactPhone [dbo].[Phone] NULL,
    -- System Fields
    ProfilePictureURL [dbo].[URL] NULL,
    Notes NVARCHAR(MAX) NULL,
    LastReviewDate DATE NULL,
    NextReviewDate DATE NULL,
    TerminationDate DATE NULL,
    TerminationReason NVARCHAR(500) NULL,
    CreatedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    CreatedBy INT NOT NULL,
    ModifiedDate DATETIME2(7) NULL,
    ModifiedBy INT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    IsDeleted BIT NOT NULL DEFAULT 0,
    DeletedDate DATETIME2(7) NULL,
    RowVersion ROWVERSION NOT NULL,
    CONSTRAINT PK_Employees PRIMARY KEY CLUSTERED (EmployeeID),
    CONSTRAINT FK_Employees_UserID FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID),
    CONSTRAINT FK_Employees_Department FOREIGN KEY (DepartmentID) REFERENCES [HR].[Departments](DepartmentID),
    CONSTRAINT FK_Employees_Position FOREIGN KEY (PositionID) REFERENCES [HR].[Positions](PositionID),
    CONSTRAINT FK_Employees_ReportsTo FOREIGN KEY (ReportsToEmployeeID) REFERENCES [HR].[Employees](EmployeeID),
    CONSTRAINT FK_Employees_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT FK_Employees_ModifiedBy FOREIGN KEY (ModifiedBy) REFERENCES [Security].[Users](UserID),
    CONSTRAINT UQ_Employees_Code UNIQUE (EmployeeCode),
    CONSTRAINT UQ_Employees_Email UNIQUE (Email),
    CONSTRAINT CHK_Employees_Gender CHECK (Gender IN ('M', 'F', 'O')),
    CONSTRAINT CHK_Employees_Email CHECK ([dbo].[fn_ValidateEmail](Email) = 1),
    CONSTRAINT CHK_Employees_Salary CHECK (BaseSalary >= 0)
) ON [PRIMARY];
GO

-- Update Departments with Manager relationship
ALTER TABLE [HR].[Departments]
ADD CONSTRAINT FK_Departments_Manager FOREIGN KEY (ManagerEmployeeID) 
    REFERENCES [HR].[Employees](EmployeeID);
GO

-- Employee History for tracking changes
CREATE TABLE [HR].[EmployeeHistory]
(
    HistoryID INT IDENTITY(1,1) NOT NULL,
    EmployeeID INT NOT NULL,
    ChangeType NVARCHAR(50) NOT NULL, -- Hire, Promotion, Transfer, SalaryChange, Termination
    OldDepartmentID INT NULL,
    NewDepartmentID INT NULL,
    OldPositionID INT NULL,
    NewPositionID INT NULL,
    OldSalary DECIMAL(19,4) NULL,
    NewSalary DECIMAL(19,4) NULL,
    EffectiveDate DATE NOT NULL,
    Reason NVARCHAR(500) NULL,
    ApprovedBy INT NOT NULL,
    CreatedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_EmployeeHistory PRIMARY KEY CLUSTERED (HistoryID),
    CONSTRAINT FK_EmployeeHistory_Employee FOREIGN KEY (EmployeeID) REFERENCES [HR].[Employees](EmployeeID),
    CONSTRAINT FK_EmployeeHistory_ApprovedBy FOREIGN KEY (ApprovedBy) REFERENCES [Security].[Users](UserID),
    INDEX IX_EmployeeHistory_EmployeeID NONCLUSTERED (EmployeeID, EffectiveDate DESC)
) ON [PRIMARY];
GO

-- =============================================
-- SECTION 4: AUDIT SCHEMA TABLES
-- =============================================

-- Comprehensive Audit Log
CREATE TABLE [Audit].[AuditLog]
(
    AuditID BIGINT IDENTITY(1,1) NOT NULL,
    TableName NVARCHAR(128) NOT NULL,
    RecordID INT NOT NULL,
    Operation NVARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    UserID INT NULL,
    Username NVARCHAR(50) NULL,
    AuditDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    IPAddress NVARCHAR(45) NULL,
    OldValues NVARCHAR(MAX) NULL, -- JSON format
    NewValues NVARCHAR(MAX) NULL, -- JSON format
    CONSTRAINT PK_AuditLog PRIMARY KEY CLUSTERED (AuditID),
    INDEX IX_AuditLog_TableRecord NONCLUSTERED (TableName, RecordID),
    INDEX IX_AuditLog_UserDate NONCLUSTERED (UserID, AuditDate DESC)
) ON [PRIMARY];
GO

-- =============================================
-- SECTION 5: CONFIG SCHEMA TABLES
-- =============================================

-- System Configuration
CREATE TABLE [Config].[SystemSettings]
(
    SettingID INT IDENTITY(1,1) NOT NULL,
    SettingKey NVARCHAR(100) NOT NULL,
    SettingValue NVARCHAR(MAX) NOT NULL,
    SettingType NVARCHAR(50) NOT NULL, -- String, Integer, Boolean, JSON
    SettingDescription NVARCHAR(500) NULL,
    IsEncrypted BIT NOT NULL DEFAULT 0,
    ModifiedDate DATETIME2(7) NULL,
    ModifiedBy INT NULL,
    CONSTRAINT PK_SystemSettings PRIMARY KEY CLUSTERED (SettingID),
    CONSTRAINT UQ_SystemSettings_Key UNIQUE (SettingKey)
) ON [PRIMARY];
GO

-- File Uploads tracking
CREATE TABLE [Config].[FileUploads]
(
    FileID INT IDENTITY(1,1) NOT NULL,
    FileName NVARCHAR(255) NOT NULL,
    FileSize BIGINT NOT NULL,
    ContentType NVARCHAR(100) NOT NULL,
    StoragePath NVARCHAR(500) NOT NULL,
    EntityType NVARCHAR(50) NOT NULL, -- Dashboard, Employee, etc.
    EntityID INT NOT NULL,
    UploadedDate DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    UploadedBy INT NOT NULL,
    IsDeleted BIT NOT NULL DEFAULT 0,
    DeletedDate DATETIME2(7) NULL,
    CONSTRAINT PK_FileUploads PRIMARY KEY CLUSTERED (FileID),
    CONSTRAINT FK_FileUploads_UploadedBy FOREIGN KEY (UploadedBy) REFERENCES [Security].[Users](UserID),
    INDEX IX_FileUploads_Entity NONCLUSTERED (EntityType, EntityID)
) ON [PRIMARY];
GO

PRINT 'All tables created successfully with proper relationships and constraints.';
GO