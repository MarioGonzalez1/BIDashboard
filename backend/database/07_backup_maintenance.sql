-- =============================================
-- BIDashboard Backup and Maintenance Strategy
-- Version: 1.0
-- Author: Senior Database Architect
-- Date: 2025-09-03
-- Description: Comprehensive backup, recovery, and maintenance procedures
-- =============================================

USE BIDashboard;
GO

-- =============================================
-- SECTION 1: BACKUP PROCEDURES
-- =============================================

-- Create backup procedure for full database backup
CREATE OR ALTER PROCEDURE [dbo].[sp_BackupDatabase]
    @BackupPath NVARCHAR(500) = 'C:\SQLBackups\BIDashboard\',
    @BackupType NVARCHAR(20) = 'FULL', -- FULL, DIFFERENTIAL, LOG
    @Compression BIT = 1,
    @Verify BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BackupFileName NVARCHAR(500);
    DECLARE @DateString NVARCHAR(20) = FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');
    DECLARE @SQL NVARCHAR(MAX);
    
    -- Generate backup file name
    SET @BackupFileName = @BackupPath + 'BIDashboard_' + @BackupType + '_' + @DateString;
    
    BEGIN TRY
        IF @BackupType = 'FULL'
        BEGIN
            SET @BackupFileName = @BackupFileName + '.bak';
            SET @SQL = 'BACKUP DATABASE BIDashboard TO DISK = ''' + @BackupFileName + ''' WITH FORMAT, INIT, SKIP, NOREWIND, NOUNLOAD, STATS = 10';
            
            IF @Compression = 1
                SET @SQL = @SQL + ', COMPRESSION';
        END
        ELSE IF @BackupType = 'DIFFERENTIAL'
        BEGIN
            SET @BackupFileName = @BackupFileName + '.dif';
            SET @SQL = 'BACKUP DATABASE BIDashboard TO DISK = ''' + @BackupFileName + ''' WITH DIFFERENTIAL, FORMAT, INIT, SKIP, NOREWIND, NOUNLOAD, STATS = 10';
            
            IF @Compression = 1
                SET @SQL = @SQL + ', COMPRESSION';
        END
        ELSE IF @BackupType = 'LOG'
        BEGIN
            SET @BackupFileName = @BackupFileName + '.trn';
            SET @SQL = 'BACKUP LOG BIDashboard TO DISK = ''' + @BackupFileName + ''' WITH FORMAT, INIT, SKIP, NOREWIND, NOUNLOAD, STATS = 10';
            
            IF @Compression = 1
                SET @SQL = @SQL + ', COMPRESSION';
        END
        
        -- Execute backup
        EXEC sp_executesql @SQL;
        
        -- Verify backup if requested
        IF @Verify = 1
        BEGIN
            SET @SQL = 'RESTORE VERIFYONLY FROM DISK = ''' + @BackupFileName + '''';
            EXEC sp_executesql @SQL;
        END
        
        -- Log backup information
        INSERT INTO [Audit].[AuditLog] (TableName, RecordID, Operation, Username, NewValues)
        VALUES (
            'DATABASE',
            0,
            'BACKUP_' + @BackupType,
            SYSTEM_USER,
            JSON_QUERY('{"FileName":"' + @BackupFileName + '","Status":"Success"}')
        );
        
        SELECT 
            'Success' AS Status,
            @BackupFileName AS BackupFile,
            GETDATE() AS BackupDate;
            
    END TRY
    BEGIN CATCH
        -- Log error
        INSERT INTO [Audit].[AuditLog] (TableName, RecordID, Operation, Username, NewValues)
        VALUES (
            'DATABASE',
            0,
            'BACKUP_ERROR',
            SYSTEM_USER,
            JSON_QUERY('{"Error":"' + ERROR_MESSAGE() + '"}')
        );
        
        THROW;
    END CATCH
END;
GO

-- Create automated backup schedule procedure
CREATE OR ALTER PROCEDURE [dbo].[sp_CreateBackupSchedule]
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ReturnCode INT;
    
    -- Create SQL Server Agent Job for Full Backup (Weekly - Sunday 2 AM)
    IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'BIDashboard_FullBackup')
    BEGIN
        EXEC @ReturnCode = msdb.dbo.sp_add_job
            @job_name = N'BIDashboard_FullBackup',
            @enabled = 1,
            @description = N'Weekly full backup of BIDashboard database',
            @category_name = N'Database Maintenance',
            @owner_login_name = N'sa';
        
        EXEC @ReturnCode = msdb.dbo.sp_add_jobstep
            @job_name = N'BIDashboard_FullBackup',
            @step_name = N'Full Backup',
            @command = N'EXEC [dbo].[sp_BackupDatabase] @BackupType = ''FULL''',
            @database_name = N'BIDashboard';
        
        EXEC @ReturnCode = msdb.dbo.sp_add_schedule
            @schedule_name = N'Weekly_Sunday_2AM',
            @freq_type = 8,
            @freq_interval = 1,
            @freq_recurrence_factor = 1,
            @active_start_time = 020000;
        
        EXEC @ReturnCode = msdb.dbo.sp_attach_schedule
            @job_name = N'BIDashboard_FullBackup',
            @schedule_name = N'Weekly_Sunday_2AM';
    END
    
    -- Create SQL Server Agent Job for Differential Backup (Daily 2 AM except Sunday)
    IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'BIDashboard_DifferentialBackup')
    BEGIN
        EXEC @ReturnCode = msdb.dbo.sp_add_job
            @job_name = N'BIDashboard_DifferentialBackup',
            @enabled = 1,
            @description = N'Daily differential backup of BIDashboard database',
            @category_name = N'Database Maintenance',
            @owner_login_name = N'sa';
        
        EXEC @ReturnCode = msdb.dbo.sp_add_jobstep
            @job_name = N'BIDashboard_DifferentialBackup',
            @step_name = N'Differential Backup',
            @command = N'EXEC [dbo].[sp_BackupDatabase] @BackupType = ''DIFFERENTIAL''',
            @database_name = N'BIDashboard';
        
        EXEC @ReturnCode = msdb.dbo.sp_add_schedule
            @schedule_name = N'Daily_2AM_ExceptSunday',
            @freq_type = 8,
            @freq_interval = 126, -- Monday through Saturday
            @freq_recurrence_factor = 1,
            @active_start_time = 020000;
        
        EXEC @ReturnCode = msdb.dbo.sp_attach_schedule
            @job_name = N'BIDashboard_DifferentialBackup',
            @schedule_name = N'Daily_2AM_ExceptSunday';
    END
    
    -- Create SQL Server Agent Job for Transaction Log Backup (Every hour)
    IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'BIDashboard_LogBackup')
    BEGIN
        EXEC @ReturnCode = msdb.dbo.sp_add_job
            @job_name = N'BIDashboard_LogBackup',
            @enabled = 1,
            @description = N'Hourly transaction log backup of BIDashboard database',
            @category_name = N'Database Maintenance',
            @owner_login_name = N'sa';
        
        EXEC @ReturnCode = msdb.dbo.sp_add_jobstep
            @job_name = N'BIDashboard_LogBackup',
            @step_name = N'Log Backup',
            @command = N'EXEC [dbo].[sp_BackupDatabase] @BackupType = ''LOG''',
            @database_name = N'BIDashboard';
        
        EXEC @ReturnCode = msdb.dbo.sp_add_schedule
            @schedule_name = N'Hourly',
            @freq_type = 4,
            @freq_interval = 1,
            @freq_subday_type = 8,
            @freq_subday_interval = 1,
            @active_start_time = 000000;
        
        EXEC @ReturnCode = msdb.dbo.sp_attach_schedule
            @job_name = N'BIDashboard_LogBackup',
            @schedule_name = N'Hourly';
    END
    
    PRINT 'Backup schedules created successfully.';
END;
GO

-- =============================================
-- SECTION 2: MAINTENANCE PROCEDURES
-- =============================================

-- Comprehensive maintenance procedure
CREATE OR ALTER PROCEDURE [dbo].[sp_DatabaseMaintenance]
    @MaintenanceType NVARCHAR(50) = 'ALL' -- ALL, INDEXES, STATISTICS, CLEANUP
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME2 = SYSDATETIME();
    DECLARE @Message NVARCHAR(MAX) = '';
    
    BEGIN TRY
        -- Index Maintenance
        IF @MaintenanceType IN ('ALL', 'INDEXES')
        BEGIN
            EXEC [dbo].[sp_MaintenanceRebuildIndexes];
            SET @Message = @Message + 'Index maintenance completed. ';
        END
        
        -- Update Statistics
        IF @MaintenanceType IN ('ALL', 'STATISTICS')
        BEGIN
            EXEC sp_updatestats;
            SET @Message = @Message + 'Statistics updated. ';
        END
        
        -- Data Cleanup
        IF @MaintenanceType IN ('ALL', 'CLEANUP')
        BEGIN
            -- Clean up old audit logs (keep 180 days)
            DELETE FROM [Audit].[AuditLog]
            WHERE AuditDate < DATEADD(DAY, -180, SYSDATETIME());
            SET @Message = @Message + CONCAT('Deleted ', @@ROWCOUNT, ' old audit records. ');
            
            -- Clean up old access logs (keep 90 days)
            DELETE FROM [Dashboard].[AccessLog]
            WHERE AccessDate < DATEADD(DAY, -90, SYSDATETIME());
            SET @Message = @Message + CONCAT('Deleted ', @@ROWCOUNT, ' old access logs. ');
            
            -- Clean up expired refresh tokens
            DELETE FROM [Security].[RefreshTokens]
            WHERE ExpiryDate < DATEADD(DAY, -30, SYSDATETIME())
                OR (RevokedDate IS NOT NULL AND RevokedDate < DATEADD(DAY, -7, SYSDATETIME()));
            SET @Message = @Message + CONCAT('Deleted ', @@ROWCOUNT, ' expired tokens. ');
        END
        
        -- Check database integrity
        DBCC CHECKDB('BIDashboard') WITH NO_INFOMSGS;
        SET @Message = @Message + 'Database integrity check passed. ';
        
        -- Log maintenance completion
        INSERT INTO [Audit].[AuditLog] (TableName, RecordID, Operation, Username, NewValues)
        VALUES (
            'DATABASE',
            0,
            'MAINTENANCE',
            SYSTEM_USER,
            JSON_QUERY('{"Type":"' + @MaintenanceType + '","Duration":"' + 
                CAST(DATEDIFF(SECOND, @StartTime, SYSDATETIME()) AS NVARCHAR(10)) + 
                ' seconds","Message":"' + @Message + '"}')
        );
        
        SELECT 
            'Success' AS Status,
            @Message AS Details,
            DATEDIFF(SECOND, @StartTime, SYSDATETIME()) AS DurationSeconds;
            
    END TRY
    BEGIN CATCH
        INSERT INTO [Audit].[AuditLog] (TableName, RecordID, Operation, Username, NewValues)
        VALUES (
            'DATABASE',
            0,
            'MAINTENANCE_ERROR',
            SYSTEM_USER,
            JSON_QUERY('{"Error":"' + ERROR_MESSAGE() + '"}')
        );
        
        THROW;
    END CATCH
END;
GO

-- =============================================
-- SECTION 3: MONITORING AND ALERTS
-- =============================================

-- Create performance monitoring procedure
CREATE OR ALTER PROCEDURE [dbo].[sp_MonitorPerformance]
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Current connections
    SELECT 
        'Active Connections' AS Metric,
        COUNT(*) AS Value
    FROM sys.dm_exec_connections
    WHERE session_id > 50;
    
    -- Database size
    SELECT 
        'Database Size (MB)' AS Metric,
        SUM(size * 8 / 1024) AS Value
    FROM sys.database_files;
    
    -- Long running queries (over 10 seconds)
    SELECT TOP 5
        'Long Running Query' AS Metric,
        SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
            ((CASE qs.statement_end_offset
                WHEN -1 THEN DATALENGTH(qt.text)
                ELSE qs.statement_end_offset
            END - qs.statement_start_offset)/2) + 1) AS QueryText,
        qs.execution_count,
        qs.total_worker_time/1000000 AS TotalCPUSeconds,
        qs.total_elapsed_time/1000000 AS TotalElapsedSeconds,
        qs.last_execution_time
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
    WHERE qs.total_elapsed_time/1000000 > 10
    ORDER BY qs.total_elapsed_time DESC;
    
    -- Table sizes
    SELECT TOP 10
        s.name + '.' + t.name AS TableName,
        p.rows AS RowCount,
        SUM(a.total_pages) * 8 / 1024 AS TotalSpaceMB,
        SUM(a.used_pages) * 8 / 1024 AS UsedSpaceMB
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    INNER JOIN sys.indexes i ON t.object_id = i.object_id
    INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
    WHERE t.is_ms_shipped = 0
    GROUP BY s.name, t.name, p.rows
    ORDER BY SUM(a.total_pages) DESC;
    
    -- Index fragmentation
    SELECT TOP 10
        OBJECT_SCHEMA_NAME(i.object_id) + '.' + OBJECT_NAME(i.object_id) AS TableName,
        i.name AS IndexName,
        ps.avg_fragmentation_in_percent AS FragmentationPercent,
        ps.page_count AS PageCount
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
    INNER JOIN sys.indexes i ON ps.object_id = i.object_id AND ps.index_id = i.index_id
    WHERE ps.avg_fragmentation_in_percent > 10
        AND ps.index_id > 0
        AND ps.page_count > 100
    ORDER BY ps.avg_fragmentation_in_percent DESC;
END;
GO

-- =============================================
-- SECTION 4: DISASTER RECOVERY PROCEDURES
-- =============================================

-- Create disaster recovery test procedure
CREATE OR ALTER PROCEDURE [dbo].[sp_TestDisasterRecovery]
    @TestBackupPath NVARCHAR(500) = 'C:\SQLBackups\BIDashboard\DRTest\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TestDBName NVARCHAR(128) = 'BIDashboard_DRTest';
    DECLARE @BackupFile NVARCHAR(500);
    DECLARE @SQL NVARCHAR(MAX);
    
    BEGIN TRY
        -- Step 1: Create test backup
        EXEC [dbo].[sp_BackupDatabase] 
            @BackupPath = @TestBackupPath,
            @BackupType = 'FULL';
        
        -- Get the latest backup file
        SET @BackupFile = @TestBackupPath + 'BIDashboard_FULL_' + 
            FORMAT(GETDATE(), 'yyyyMMdd') + '*.bak';
        
        -- Step 2: Drop test database if exists
        IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @TestDBName)
        BEGIN
            SET @SQL = 'ALTER DATABASE ' + @TestDBName + ' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;';
            EXEC sp_executesql @SQL;
            
            SET @SQL = 'DROP DATABASE ' + @TestDBName + ';';
            EXEC sp_executesql @SQL;
        END
        
        -- Step 3: Restore to test database
        SET @SQL = 'RESTORE DATABASE ' + @TestDBName + ' FROM DISK = ''' + @BackupFile + ''' 
            WITH MOVE ''BIDashboard_Primary'' TO ''C:\SQLData\' + @TestDBName + '.mdf'',
            MOVE ''BIDashboard_Log'' TO ''C:\SQLData\' + @TestDBName + '_log.ldf'',
            REPLACE, STATS = 10;';
        EXEC sp_executesql @SQL;
        
        -- Step 4: Verify restore
        SET @SQL = 'DBCC CHECKDB(''' + @TestDBName + ''') WITH NO_INFOMSGS;';
        EXEC sp_executesql @SQL;
        
        -- Step 5: Clean up test database
        SET @SQL = 'DROP DATABASE ' + @TestDBName + ';';
        EXEC sp_executesql @SQL;
        
        -- Log success
        INSERT INTO [Audit].[AuditLog] (TableName, RecordID, Operation, Username, NewValues)
        VALUES (
            'DATABASE',
            0,
            'DR_TEST',
            SYSTEM_USER,
            JSON_QUERY('{"Status":"Success","TestDate":"' + CONVERT(NVARCHAR(30), GETDATE(), 120) + '"}')
        );
        
        SELECT 'Disaster Recovery Test Successful' AS Result;
        
    END TRY
    BEGIN CATCH
        -- Log failure
        INSERT INTO [Audit].[AuditLog] (TableName, RecordID, Operation, Username, NewValues)
        VALUES (
            'DATABASE',
            0,
            'DR_TEST_FAILED',
            SYSTEM_USER,
            JSON_QUERY('{"Error":"' + ERROR_MESSAGE() + '"}')
        );
        
        THROW;
    END CATCH
END;
GO

-- =============================================
-- SECTION 5: HEALTH CHECK PROCEDURES
-- =============================================

-- Comprehensive health check
CREATE OR ALTER PROCEDURE [dbo].[sp_DatabaseHealthCheck]
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Results TABLE (
        CheckName NVARCHAR(100),
        Status NVARCHAR(20),
        Details NVARCHAR(MAX)
    );
    
    -- Check 1: Database status
    INSERT INTO @Results (CheckName, Status, Details)
    SELECT 
        'Database Status',
        CASE WHEN state_desc = 'ONLINE' THEN 'PASS' ELSE 'FAIL' END,
        'Database is ' + state_desc
    FROM sys.databases
    WHERE name = 'BIDashboard';
    
    -- Check 2: Last backup
    INSERT INTO @Results (CheckName, Status, Details)
    SELECT 
        'Last Full Backup',
        CASE WHEN DATEDIFF(DAY, MAX(backup_finish_date), GETDATE()) <= 7 THEN 'PASS' 
             WHEN DATEDIFF(DAY, MAX(backup_finish_date), GETDATE()) <= 14 THEN 'WARNING'
             ELSE 'FAIL' END,
        'Last backup: ' + ISNULL(CONVERT(NVARCHAR(30), MAX(backup_finish_date), 120), 'Never')
    FROM msdb.dbo.backupset
    WHERE database_name = 'BIDashboard' AND type = 'D';
    
    -- Check 3: Database size
    INSERT INTO @Results (CheckName, Status, Details)
    SELECT 
        'Database Size',
        CASE WHEN SUM(size * 8 / 1024) < 10240 THEN 'PASS' 
             WHEN SUM(size * 8 / 1024) < 50000 THEN 'WARNING'
             ELSE 'FAIL' END,
        'Size: ' + CAST(SUM(size * 8 / 1024) AS NVARCHAR(20)) + ' MB'
    FROM sys.database_files;
    
    -- Check 4: Index fragmentation
    INSERT INTO @Results (CheckName, Status, Details)
    SELECT TOP 1
        'Index Fragmentation',
        CASE WHEN MAX(avg_fragmentation_in_percent) < 30 THEN 'PASS'
             WHEN MAX(avg_fragmentation_in_percent) < 50 THEN 'WARNING'
             ELSE 'FAIL' END,
        'Max fragmentation: ' + CAST(MAX(avg_fragmentation_in_percent) AS NVARCHAR(20)) + '%'
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED')
    WHERE index_id > 0 AND page_count > 100;
    
    -- Check 5: Failed logins
    INSERT INTO @Results (CheckName, Status, Details)
    SELECT 
        'Failed Login Attempts',
        CASE WHEN COUNT(*) = 0 THEN 'PASS'
             WHEN COUNT(*) < 10 THEN 'WARNING'
             ELSE 'FAIL' END,
        'Users with failed attempts: ' + CAST(COUNT(*) AS NVARCHAR(20))
    FROM [Security].[Users]
    WHERE FailedLoginAttempts > 0;
    
    -- Return results
    SELECT * FROM @Results
    ORDER BY 
        CASE Status 
            WHEN 'FAIL' THEN 1
            WHEN 'WARNING' THEN 2
            WHEN 'PASS' THEN 3
        END;
END;
GO

PRINT 'Backup and maintenance procedures created successfully.';
GO