/*
=================================================================
BIDashboard - SQL Server Backup and Maintenance Script
Author: Database Architect
Date: 2025-09-03
Description: Creates backup strategies and maintenance procedures
=================================================================
*/

USE BIDashboard;
GO

-- =================================================================
-- BACKUP PROCEDURES
-- =================================================================

-- Full Database Backup
CREATE PROCEDURE Maintenance.sp_FullBackup
    @BackupPath NVARCHAR(500) = 'C:\SQLBackups\BIDashboard\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BackupFileName NVARCHAR(500);
    DECLARE @BackupFullPath NVARCHAR(500);
    DECLARE @CurrentDateTime NVARCHAR(20) = CONVERT(NVARCHAR(20), GETDATE(), 112) + '_' + REPLACE(CONVERT(NVARCHAR(8), GETDATE(), 108), ':', '');
    
    -- Create backup filename with timestamp
    SET @BackupFileName = 'BIDashboard_Full_' + @CurrentDateTime + '.bak';
    SET @BackupFullPath = @BackupPath + @BackupFileName;
    
    -- Ensure backup directory exists (this would need to be created externally)
    PRINT 'Starting full backup to: ' + @BackupFullPath;
    
    -- Perform full backup
    BACKUP DATABASE BIDashboard 
    TO DISK = @BackupFullPath
    WITH 
        COMPRESSION,
        CHECKSUM,
        INIT,
        FORMAT,
        NAME = 'BIDashboard Full Database Backup',
        DESCRIPTION = 'Full backup of BIDashboard database';
    
    -- Verify backup
    RESTORE VERIFYONLY FROM DISK = @BackupFullPath;
    
    -- Log the backup
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, Severity)
    VALUES ('Database Backup', 'Full database backup completed: ' + @BackupFileName, 'Info');
    
    PRINT '✅ Full backup completed successfully: ' + @BackupFileName;
END
GO

-- Differential Backup
CREATE PROCEDURE Maintenance.sp_DifferentialBackup
    @BackupPath NVARCHAR(500) = 'C:\SQLBackups\BIDashboard\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BackupFileName NVARCHAR(500);
    DECLARE @BackupFullPath NVARCHAR(500);
    DECLARE @CurrentDateTime NVARCHAR(20) = CONVERT(NVARCHAR(20), GETDATE(), 112) + '_' + REPLACE(CONVERT(NVARCHAR(8), GETDATE(), 108), ':', '');
    
    SET @BackupFileName = 'BIDashboard_Diff_' + @CurrentDateTime + '.bak';
    SET @BackupFullPath = @BackupPath + @BackupFileName;
    
    PRINT 'Starting differential backup to: ' + @BackupFullPath;
    
    -- Perform differential backup
    BACKUP DATABASE BIDashboard 
    TO DISK = @BackupFullPath
    WITH 
        DIFFERENTIAL,
        COMPRESSION,
        CHECKSUM,
        INIT,
        FORMAT,
        NAME = 'BIDashboard Differential Database Backup',
        DESCRIPTION = 'Differential backup of BIDashboard database';
    
    -- Verify backup
    RESTORE VERIFYONLY FROM DISK = @BackupFullPath;
    
    -- Log the backup
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, Severity)
    VALUES ('Database Backup', 'Differential backup completed: ' + @BackupFileName, 'Info');
    
    PRINT '✅ Differential backup completed successfully: ' + @BackupFileName;
END
GO

-- Transaction Log Backup
CREATE PROCEDURE Maintenance.sp_TransactionLogBackup
    @BackupPath NVARCHAR(500) = 'C:\SQLBackups\BIDashboard\Logs\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BackupFileName NVARCHAR(500);
    DECLARE @BackupFullPath NVARCHAR(500);
    DECLARE @CurrentDateTime NVARCHAR(20) = CONVERT(NVARCHAR(20), GETDATE(), 112) + '_' + REPLACE(CONVERT(NVARCHAR(8), GETDATE(), 108), ':', '');
    
    SET @BackupFileName = 'BIDashboard_Log_' + @CurrentDateTime + '.trn';
    SET @BackupFullPath = @BackupPath + @BackupFileName;
    
    PRINT 'Starting transaction log backup to: ' + @BackupFullPath;
    
    -- Perform transaction log backup
    BACKUP LOG BIDashboard 
    TO DISK = @BackupFullPath
    WITH 
        COMPRESSION,
        CHECKSUM,
        INIT,
        FORMAT,
        NAME = 'BIDashboard Transaction Log Backup',
        DESCRIPTION = 'Transaction log backup of BIDashboard database';
    
    -- Log the backup
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, Severity)
    VALUES ('Database Backup', 'Transaction log backup completed: ' + @BackupFileName, 'Info');
    
    PRINT '✅ Transaction log backup completed successfully: ' + @BackupFileName;
END
GO

-- =================================================================
-- MAINTENANCE PROCEDURES
-- =================================================================

-- Index Maintenance (Rebuild/Reorganize)
CREATE PROCEDURE Maintenance.sp_IndexMaintenance
    @FragmentationThreshold FLOAT = 30.0,
    @ReorganizeThreshold FLOAT = 10.0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @SchemaName NVARCHAR(128);
    DECLARE @TableName NVARCHAR(128);
    DECLARE @IndexName NVARCHAR(128);
    DECLARE @FragmentationPercent FLOAT;
    DECLARE @PageCount BIGINT;
    
    -- Cursor to iterate through fragmented indexes
    DECLARE index_cursor CURSOR FOR
    SELECT 
        s.name AS SchemaName,
        t.name AS TableName,
        i.name AS IndexName,
        ps.avg_fragmentation_in_percent,
        ps.page_count
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
    INNER JOIN sys.indexes i ON ps.object_id = i.object_id AND ps.index_id = i.index_id
    INNER JOIN sys.tables t ON ps.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE ps.avg_fragmentation_in_percent > @ReorganizeThreshold
        AND ps.page_count > 1000 -- Only consider indexes with significant pages
        AND i.name IS NOT NULL; -- Exclude heaps
    
    OPEN index_cursor;
    FETCH NEXT FROM index_cursor INTO @SchemaName, @TableName, @IndexName, @FragmentationPercent, @PageCount;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @FragmentationPercent > @FragmentationThreshold
        BEGIN
            -- Rebuild index for high fragmentation
            SET @sql = 'ALTER INDEX [' + @IndexName + '] ON [' + @SchemaName + '].[' + @TableName + '] REBUILD WITH (ONLINE = OFF, FILLFACTOR = 85);';
            PRINT 'Rebuilding index: ' + @SchemaName + '.' + @TableName + '.' + @IndexName + ' (' + CAST(@FragmentationPercent AS VARCHAR(10)) + '% fragmentation)';
        END
        ELSE
        BEGIN
            -- Reorganize index for moderate fragmentation
            SET @sql = 'ALTER INDEX [' + @IndexName + '] ON [' + @SchemaName + '].[' + @TableName + '] REORGANIZE;';
            PRINT 'Reorganizing index: ' + @SchemaName + '.' + @TableName + '.' + @IndexName + ' (' + CAST(@FragmentationPercent AS VARCHAR(10)) + '% fragmentation)';
        END
        
        -- Execute the maintenance command
        EXEC sp_executesql @sql;
        
        FETCH NEXT FROM index_cursor INTO @SchemaName, @TableName, @IndexName, @FragmentationPercent, @PageCount;
    END
    
    CLOSE index_cursor;
    DEALLOCATE index_cursor;
    
    -- Update statistics after index maintenance
    EXEC sp_updatestats;
    
    -- Log maintenance completion
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, Severity)
    VALUES ('Index Maintenance', 'Index maintenance completed successfully', 'Info');
    
    PRINT '✅ Index maintenance completed successfully';
END
GO

-- Statistics Update
CREATE PROCEDURE Maintenance.sp_UpdateStatistics
    @SamplePercent INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @SchemaName NVARCHAR(128);
    DECLARE @TableName NVARCHAR(128);
    DECLARE @StatisticsUpdated INT = 0;
    
    -- Cursor to update statistics on all user tables
    DECLARE stats_cursor CURSOR FOR
    SELECT s.name, t.name
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.is_ms_shipped = 0;
    
    OPEN stats_cursor;
    FETCH NEXT FROM stats_cursor INTO @SchemaName, @TableName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = 'UPDATE STATISTICS [' + @SchemaName + '].[' + @TableName + '] WITH SAMPLE ' + CAST(@SamplePercent AS VARCHAR(3)) + ' PERCENT;';
        
        PRINT 'Updating statistics for: ' + @SchemaName + '.' + @TableName;
        EXEC sp_executesql @sql;
        
        SET @StatisticsUpdated = @StatisticsUpdated + 1;
        
        FETCH NEXT FROM stats_cursor INTO @SchemaName, @TableName;
    END
    
    CLOSE stats_cursor;
    DEALLOCATE stats_cursor;
    
    -- Log statistics update
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, Severity)
    VALUES ('Statistics Update', 'Updated statistics on ' + CAST(@StatisticsUpdated AS VARCHAR(10)) + ' tables', 'Info');
    
    PRINT '✅ Statistics updated on ' + CAST(@StatisticsUpdated AS VARCHAR(10)) + ' tables';
END
GO

-- Database Integrity Check
CREATE PROCEDURE Maintenance.sp_DatabaseIntegrityCheck
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ErrorCount INT = 0;
    
    -- Create temp table to capture DBCC results
    CREATE TABLE #DBCCResults (
        Error INT,
        Level INT,
        State INT,
        MessageText VARCHAR(7000),
        RepairLevel VARCHAR(200),
        Status INT,
        DbId INT,
        DbFragId INT,
        ObjectId INT,
        IndexId INT,
        PartitionId BIGINT,
        AllocUnitId BIGINT,
        RidDbId INT,
        RidPruId INT,
        File INT,
        Page INT,
        Slot INT,
        RefDbId INT,
        RefPruId INT,
        RefFile INT,
        RefPage INT,
        RefSlot INT,
        Allocation INT
    );
    
    PRINT 'Starting database integrity check...';
    
    -- Run DBCC CHECKDB
    INSERT INTO #DBCCResults
    EXEC ('DBCC CHECKDB(''BIDashboard'') WITH NO_INFOMSGS, ALL_ERRORMSGS');
    
    -- Count errors
    SELECT @ErrorCount = COUNT(*) FROM #DBCCResults WHERE Error <> 0;
    
    IF @ErrorCount = 0
    BEGIN
        PRINT '✅ Database integrity check passed - no errors found';
        INSERT INTO Audit.SystemEvents (EventType, EventDescription, Severity)
        VALUES ('Integrity Check', 'Database integrity check completed successfully - no errors', 'Info');
    END
    ELSE
    BEGIN
        PRINT '⚠️ Database integrity check found ' + CAST(@ErrorCount AS VARCHAR(10)) + ' errors';
        
        -- Log detailed errors
        DECLARE @ErrorDetails NVARCHAR(MAX) = '';
        SELECT @ErrorDetails = @ErrorDetails + MessageText + '; '
        FROM #DBCCResults 
        WHERE Error <> 0;
        
        INSERT INTO Audit.SystemEvents (EventType, EventDescription, Severity, AdditionalData)
        VALUES ('Integrity Check', 'Database integrity check found errors', 'Error', @ErrorDetails);
        
        -- Display error details
        SELECT Error, Level, State, MessageText
        FROM #DBCCResults
        WHERE Error <> 0;
    END
    
    DROP TABLE #DBCCResults;
END
GO

-- =================================================================
-- CLEANUP PROCEDURES
-- =================================================================

-- Archive Old Data
CREATE PROCEDURE Maintenance.sp_ArchiveOldData
    @ArchiveDays INT = 365
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@ArchiveDays, GETUTCDATE());
    DECLARE @ArchivedRecords INT = 0;
    
    -- Archive old dashboard analytics (older than specified days)
    DELETE FROM Dashboard.DashboardAnalytics 
    WHERE AccessDate < @CutoffDate;
    SET @ArchivedRecords = @ArchivedRecords + @@ROWCOUNT;
    
    -- Archive old system events (keep errors and warnings longer)
    DELETE FROM Audit.SystemEvents 
    WHERE CreatedDate < @CutoffDate 
        AND Severity = 'Info';
    SET @ArchivedRecords = @ArchivedRecords + @@ROWCOUNT;
    
    -- Archive expired user sessions
    DELETE FROM Security.UserSessions 
    WHERE ExpiryDate < GETUTCDATE();
    SET @ArchivedRecords = @ArchivedRecords + @@ROWCOUNT;
    
    -- Log archival activity
    INSERT INTO Audit.SystemEvents (EventType, EventDescription, Severity)
    VALUES ('Data Archival', 'Archived ' + CAST(@ArchivedRecords AS VARCHAR(10)) + ' old records', 'Info');
    
    PRINT '✅ Archived ' + CAST(@ArchivedRecords AS VARCHAR(10)) + ' old records';
END
GO

-- =================================================================
-- MASTER MAINTENANCE PROCEDURE
-- =================================================================

-- Complete Database Maintenance
CREATE PROCEDURE Maintenance.sp_CompleteMaintenance
    @PerformBackup BIT = 1,
    @PerformIndexMaintenance BIT = 1,
    @UpdateStatistics BIT = 1,
    @CheckIntegrity BIT = 1,
    @ArchiveOldData BIT = 1,
    @BackupPath NVARCHAR(500) = 'C:\SQLBackups\BIDashboard\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME2 = GETUTCDATE();
    DECLARE @EndTime DATETIME2;
    DECLARE @Duration INT;
    
    PRINT '🚀 Starting complete database maintenance...';
    PRINT 'Start time: ' + CONVERT(VARCHAR(25), @StartTime, 121);
    
    BEGIN TRY
        -- 1. Database Integrity Check (run first)
        IF @CheckIntegrity = 1
        BEGIN
            PRINT '1️⃣ Running database integrity check...';
            EXEC Maintenance.sp_DatabaseIntegrityCheck;
        END
        
        -- 2. Index Maintenance
        IF @PerformIndexMaintenance = 1
        BEGIN
            PRINT '2️⃣ Performing index maintenance...';
            EXEC Maintenance.sp_IndexMaintenance;
        END
        
        -- 3. Update Statistics
        IF @UpdateStatistics = 1
        BEGIN
            PRINT '3️⃣ Updating statistics...';
            EXEC Maintenance.sp_UpdateStatistics;
        END
        
        -- 4. Archive Old Data
        IF @ArchiveOldData = 1
        BEGIN
            PRINT '4️⃣ Archiving old data...';
            EXEC Maintenance.sp_ArchiveOldData;
        END
        
        -- 5. Backup Database (run last)
        IF @PerformBackup = 1
        BEGIN
            PRINT '5️⃣ Creating full database backup...';
            EXEC Maintenance.sp_FullBackup @BackupPath;
        END
        
        SET @EndTime = GETUTCDATE();
        SET @Duration = DATEDIFF(MINUTE, @StartTime, @EndTime);
        
        PRINT '✅ Complete maintenance finished successfully!';
        PRINT 'End time: ' + CONVERT(VARCHAR(25), @EndTime, 121);
        PRINT 'Total duration: ' + CAST(@Duration AS VARCHAR(10)) + ' minutes';
        
        -- Log successful completion
        INSERT INTO Audit.SystemEvents (EventType, EventDescription, Severity)
        VALUES ('Database Maintenance', 'Complete database maintenance completed successfully in ' + CAST(@Duration AS VARCHAR(10)) + ' minutes', 'Info');
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorNumber INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        PRINT '❌ Maintenance failed with error: ' + @ErrorMessage;
        
        -- Log error
        INSERT INTO Audit.SystemEvents (EventType, EventDescription, Severity, AdditionalData)
        VALUES ('Database Maintenance', 'Maintenance failed: ' + @ErrorMessage, 'Error', 
                '{"ErrorNumber":' + CAST(@ErrorNumber AS VARCHAR(10)) + ',"Severity":' + CAST(@ErrorSeverity AS VARCHAR(10)) + ',"State":' + CAST(@ErrorState AS VARCHAR(10)) + '}');
        
        -- Re-raise the error
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

-- =================================================================
-- SQL SERVER AGENT JOBS (Templates for scheduling)
-- =================================================================

-- Note: These are templates. Actual job creation requires SQL Server Agent
PRINT '📅 SQL Server Agent Job Templates:';
PRINT '';
PRINT '-- Weekly Full Backup (Sundays at 2:00 AM)';
PRINT 'EXEC msdb.dbo.sp_add_job @job_name = ''BIDashboard - Weekly Full Backup'';';
PRINT 'EXEC msdb.dbo.sp_add_jobstep @step_name = ''Full Backup'', @command = ''EXEC BIDashboard.Maintenance.sp_FullBackup'';';
PRINT 'EXEC msdb.dbo.sp_add_schedule @schedule_name = ''Weekly Sunday 2AM'', @freq_type = 8, @freq_interval = 1, @active_start_time = 020000;';
PRINT '';
PRINT '-- Daily Differential Backup (Monday-Saturday at 2:00 AM)';
PRINT 'EXEC msdb.dbo.sp_add_job @job_name = ''BIDashboard - Daily Differential Backup'';';
PRINT 'EXEC msdb.dbo.sp_add_jobstep @step_name = ''Diff Backup'', @command = ''EXEC BIDashboard.Maintenance.sp_DifferentialBackup'';';
PRINT 'EXEC msdb.dbo.sp_add_schedule @schedule_name = ''Daily Mon-Sat 2AM'', @freq_type = 8, @freq_interval = 126, @active_start_time = 020000;';
PRINT '';
PRINT '-- Hourly Transaction Log Backup';
PRINT 'EXEC msdb.dbo.sp_add_job @job_name = ''BIDashboard - Hourly Log Backup'';';
PRINT 'EXEC msdb.dbo.sp_add_jobstep @step_name = ''Log Backup'', @command = ''EXEC BIDashboard.Maintenance.sp_TransactionLogBackup'';';
PRINT 'EXEC msdb.dbo.sp_add_schedule @schedule_name = ''Hourly'', @freq_type = 4, @freq_interval = 1, @freq_subday_type = 8, @freq_subday_interval = 1;';
PRINT '';
PRINT '-- Weekly Maintenance (Sundays at 1:00 AM)';
PRINT 'EXEC msdb.dbo.sp_add_job @job_name = ''BIDashboard - Weekly Maintenance'';';
PRINT 'EXEC msdb.dbo.sp_add_jobstep @step_name = ''Complete Maintenance'', @command = ''EXEC BIDashboard.Maintenance.sp_CompleteMaintenance'';';
PRINT 'EXEC msdb.dbo.sp_add_schedule @schedule_name = ''Weekly Sunday 1AM'', @freq_type = 8, @freq_interval = 1, @active_start_time = 010000;';

GO

PRINT '✅ Backup and maintenance procedures created successfully!';
PRINT '📦 Backup Procedures:';
PRINT '   - sp_FullBackup: Complete database backup';
PRINT '   - sp_DifferentialBackup: Differential backup';  
PRINT '   - sp_TransactionLogBackup: Transaction log backup';
PRINT '🔧 Maintenance Procedures:';
PRINT '   - sp_IndexMaintenance: Rebuild/reorganize fragmented indexes';
PRINT '   - sp_UpdateStatistics: Update table statistics';
PRINT '   - sp_DatabaseIntegrityCheck: DBCC CHECKDB verification';
PRINT '   - sp_ArchiveOldData: Archive old audit and analytics data';
PRINT '   - sp_CompleteMaintenance: Master procedure for all maintenance';
PRINT '⏰ Schedule these procedures using SQL Server Agent jobs';
PRINT '💾 Recommended backup schedule:';
PRINT '   - Full: Weekly (Sundays 2:00 AM)';
PRINT '   - Differential: Daily (Mon-Sat 2:00 AM)';
PRINT '   - Transaction Log: Hourly';
PRINT '   - Maintenance: Weekly (Sundays 1:00 AM)';
GO