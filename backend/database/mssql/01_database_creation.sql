/*
=================================================================
BIDashboard - SQL Server Database Creation Script
Author: Database Architect
Date: 2025-09-03
Description: Creates BIDashboard database with optimized configuration
=================================================================
*/

USE master;
GO

-- Drop database if exists (for development)
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'BIDashboard')
BEGIN
    ALTER DATABASE BIDashboard SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BIDashboard;
END
GO

-- Create database with optimized settings
CREATE DATABASE BIDashboard
ON 
(
    NAME = 'BIDashboard_Data',
    FILENAME = 'C:\SQLData\BIDashboard_Data.mdf',
    SIZE = 100MB,
    MAXSIZE = 10GB,
    FILEGROWTH = 10MB
)
LOG ON 
(
    NAME = 'BIDashboard_Log',
    FILENAME = 'C:\SQLData\BIDashboard_Log.ldf',
    SIZE = 10MB,
    MAXSIZE = 1GB,
    FILEGROWTH = 5MB
);
GO

-- Switch to the new database
USE BIDashboard;
GO

-- Set database options for optimal performance
ALTER DATABASE BIDashboard SET RECOVERY FULL;
ALTER DATABASE BIDashboard SET AUTO_CREATE_STATISTICS ON;
ALTER DATABASE BIDashboard SET AUTO_UPDATE_STATISTICS ON;
ALTER DATABASE BIDashboard SET AUTO_UPDATE_STATISTICS_ASYNC ON;
ALTER DATABASE BIDashboard SET AUTO_SHRINK OFF;
ALTER DATABASE BIDashboard SET AUTO_CLOSE OFF;
ALTER DATABASE BIDashboard SET PAGE_VERIFY CHECKSUM;
ALTER DATABASE BIDashboard SET READ_COMMITTED_SNAPSHOT ON;
GO

-- Enable Query Store for performance monitoring
ALTER DATABASE BIDashboard SET QUERY_STORE = ON
(
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    INTERVAL_LENGTH_MINUTES = 60,
    MAX_STORAGE_SIZE_MB = 1000,
    QUERY_CAPTURE_MODE = AUTO,
    SIZE_BASED_CLEANUP_MODE = AUTO
);
GO

-- Create file groups for data organization
ALTER DATABASE BIDashboard ADD FILEGROUP BIDashboard_Indexes;
GO

ALTER DATABASE BIDashboard 
ADD FILE 
(
    NAME = 'BIDashboard_Indexes',
    FILENAME = 'C:\SQLData\BIDashboard_Indexes.ndf',
    SIZE = 50MB,
    MAXSIZE = 5GB,
    FILEGROWTH = 10MB
) TO FILEGROUP BIDashboard_Indexes;
GO

-- Create login for Mario Gonzalez
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'mario_gonzalez')
BEGIN
    CREATE LOGIN mario_gonzalez WITH PASSWORD = 'Mario2024!BIDashboard@MSSQL', 
    DEFAULT_DATABASE = BIDashboard,
    CHECK_EXPIRATION = OFF,
    CHECK_POLICY = OFF;
END
GO

-- Create database user
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'mario_gonzalez')
BEGIN
    CREATE USER mario_gonzalez FOR LOGIN mario_gonzalez;
    ALTER ROLE db_owner ADD MEMBER mario_gonzalez;
END
GO

PRINT '✅ Database BIDashboard created successfully!';
PRINT '🔐 Login created: mario_gonzalez / Mario2024!BIDashboard@MSSQL';
PRINT '📊 Query Store enabled for performance monitoring';
PRINT '💾 File groups configured for optimal storage';
GO