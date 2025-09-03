-- =============================================
-- BIDashboard SQL Server Database Creation Script
-- Version: 1.0
-- Author: Senior Database Architect
-- Date: 2025-09-03
-- Description: Complete database creation script for Business Intelligence Dashboard System
-- =============================================

-- =============================================
-- SECTION 1: DATABASE CREATION
-- =============================================

USE master;
GO

-- Drop database if exists (for development - remove in production)
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'BIDashboard')
BEGIN
    ALTER DATABASE BIDashboard SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BIDashboard;
END
GO

-- Create database with appropriate settings for BI workload
CREATE DATABASE BIDashboard
ON PRIMARY 
(
    NAME = N'BIDashboard_Primary',
    FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\BIDashboard.mdf',
    SIZE = 100MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = 64MB
),
-- Add filegroup for large objects (images, documents)
FILEGROUP [LOB_DATA]
(
    NAME = N'BIDashboard_LOB',
    FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\BIDashboard_LOB.ndf',
    SIZE = 500MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = 128MB
),
-- Add filegroup for indexes to improve performance
FILEGROUP [INDEXES]
(
    NAME = N'BIDashboard_Indexes',
    FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\BIDashboard_IDX.ndf',
    SIZE = 50MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = 32MB
)
LOG ON 
(
    NAME = N'BIDashboard_Log',
    FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\BIDashboard_log.ldf',
    SIZE = 50MB,
    MAXSIZE = 2048GB,
    FILEGROWTH = 10%
)
COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

-- Configure database options for BI workload
ALTER DATABASE BIDashboard SET COMPATIBILITY_LEVEL = 160; -- SQL Server 2022
ALTER DATABASE BIDashboard SET ANSI_NULL_DEFAULT OFF;
ALTER DATABASE BIDashboard SET ANSI_NULLS OFF;
ALTER DATABASE BIDashboard SET ANSI_PADDING OFF;
ALTER DATABASE BIDashboard SET ANSI_WARNINGS OFF;
ALTER DATABASE BIDashboard SET ARITHABORT OFF;
ALTER DATABASE BIDashboard SET AUTO_CLOSE OFF;
ALTER DATABASE BIDashboard SET AUTO_SHRINK OFF;
ALTER DATABASE BIDashboard SET AUTO_UPDATE_STATISTICS ON;
ALTER DATABASE BIDashboard SET CURSOR_CLOSE_ON_COMMIT OFF;
ALTER DATABASE BIDashboard SET CURSOR_DEFAULT GLOBAL;
ALTER DATABASE BIDashboard SET CONCAT_NULL_YIELDS_NULL OFF;
ALTER DATABASE BIDashboard SET NUMERIC_ROUNDABORT OFF;
ALTER DATABASE BIDashboard SET QUOTED_IDENTIFIER OFF;
ALTER DATABASE BIDashboard SET RECURSIVE_TRIGGERS OFF;
ALTER DATABASE BIDashboard SET DISABLE_BROKER;
ALTER DATABASE BIDashboard SET AUTO_UPDATE_STATISTICS_ASYNC ON;
ALTER DATABASE BIDashboard SET DATE_CORRELATION_OPTIMIZATION OFF;
ALTER DATABASE BIDashboard SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE BIDashboard SET READ_COMMITTED_SNAPSHOT ON;
ALTER DATABASE BIDashboard SET PARAMETERIZATION SIMPLE;
ALTER DATABASE BIDashboard SET RECOVERY FULL;
ALTER DATABASE BIDashboard SET PAGE_VERIFY CHECKSUM;
ALTER DATABASE BIDashboard SET TARGET_RECOVERY_TIME = 60 SECONDS;
ALTER DATABASE BIDashboard SET DELAYED_DURABILITY = DISABLED;
ALTER DATABASE BIDashboard SET ACCELERATED_DATABASE_RECOVERY = ON;
ALTER DATABASE BIDashboard SET QUERY_STORE = ON;
GO

-- Configure Query Store for performance monitoring
ALTER DATABASE BIDashboard SET QUERY_STORE 
(
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    INTERVAL_LENGTH_MINUTES = 60,
    MAX_STORAGE_SIZE_MB = 1024,
    QUERY_CAPTURE_MODE = AUTO,
    SIZE_BASED_CLEANUP_MODE = AUTO
);
GO

USE BIDashboard;
GO

-- =============================================
-- SECTION 2: SCHEMA CREATION
-- =============================================

-- Create schemas for logical separation
CREATE SCHEMA [Security] AUTHORIZATION [dbo];
GO
CREATE SCHEMA [Dashboard] AUTHORIZATION [dbo];
GO
CREATE SCHEMA [HR] AUTHORIZATION [dbo];
GO
CREATE SCHEMA [Audit] AUTHORIZATION [dbo];
GO
CREATE SCHEMA [Config] AUTHORIZATION [dbo];
GO

-- =============================================
-- SECTION 3: USER-DEFINED DATA TYPES
-- =============================================

-- Create custom data types for consistency
CREATE TYPE [dbo].[Email] FROM NVARCHAR(255) NOT NULL;
GO
CREATE TYPE [dbo].[URL] FROM NVARCHAR(2048) NOT NULL;
GO
CREATE TYPE [dbo].[Phone] FROM NVARCHAR(30) NULL;
GO
CREATE TYPE [dbo].[Money_Positive] FROM DECIMAL(19,4) NOT NULL;
GO

-- =============================================
-- SECTION 4: FUNCTIONS FOR BUSINESS LOGIC
-- =============================================

-- Function to validate email format
CREATE FUNCTION [dbo].[fn_ValidateEmail]
(
    @Email NVARCHAR(255)
)
RETURNS BIT
AS
BEGIN
    DECLARE @IsValid BIT = 0;
    
    IF @Email LIKE '%_@_%_.__%' 
        AND CHARINDEX(' ', @Email) = 0
        AND CHARINDEX('..', @Email) = 0
        AND @Email NOT LIKE '%@%@%'
        AND LEFT(@Email, 1) NOT IN ('@', '.')
        AND RIGHT(@Email, 1) NOT IN ('@', '.')
        SET @IsValid = 1;
    
    RETURN @IsValid;
END;
GO

-- Function to generate slugs for URLs
CREATE FUNCTION [dbo].[fn_GenerateSlug]
(
    @Input NVARCHAR(500)
)
RETURNS NVARCHAR(500)
AS
BEGIN
    DECLARE @Output NVARCHAR(500);
    SET @Output = LOWER(@Input);
    SET @Output = REPLACE(@Output, ' ', '-');
    SET @Output = REPLACE(@Output, '_', '-');
    -- Remove special characters
    WHILE PATINDEX('%[^a-z0-9-]%', @Output) > 0
        SET @Output = STUFF(@Output, PATINDEX('%[^a-z0-9-]%', @Output), 1, '');
    -- Remove duplicate hyphens
    WHILE CHARINDEX('--', @Output) > 0
        SET @Output = REPLACE(@Output, '--', '-');
    
    RETURN @Output;
END;
GO

PRINT 'Database BIDashboard created successfully with all configurations.';
GO