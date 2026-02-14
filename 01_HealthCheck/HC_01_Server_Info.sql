/*
================================================================================
Script Name  : HC_01_Server_Info.sql
Author       : DBA Team
Created Date : 2026-02-14
SQL Version  : 2012+
Category     : HealthCheck
Purpose      : Collect general SQL Server instance information for assessment
Risk Level   : READ ONLY (SAFE)
================================================================================
Description:
This script collects high-level server and instance configuration details.
All queries are read-only and safe for production.
Each section can be executed independently.
================================================================================
*/


/******************************************************************************
SECTION 1 - BASIC SERVER INFORMATION
Purpose  : Identify SQL version, edition, patch level
******************************************************************************/
SELECT 
    @@SERVERNAME               AS Server_Name,
    SERVERPROPERTY('MachineName') AS Machine_Name,
    SERVERPROPERTY('InstanceName') AS Instance_Name,
    SERVERPROPERTY('Edition')  AS Edition,
    SERVERPROPERTY('ProductVersion') AS Product_Version,
    SERVERPROPERTY('ProductLevel')   AS Product_Level,
    SERVERPROPERTY('EngineEdition')  AS Engine_Edition,
    GETDATE() AS Collection_Time;
GO


/******************************************************************************
SECTION 2 - OS & HARDWARE INFORMATION
Purpose  : Check CPU count, memory and virtualization info
******************************************************************************/
SELECT 
    cpu_count,
    hyperthread_ratio,
    scheduler_count,
    physical_memory_kb/1024 AS Physical_Memory_MB,
    virtual_memory_kb/1024 AS Virtual_Memory_MB,
    committed_kb/1024 AS SQL_Committed_MB,
    committed_target_kb/1024 AS SQL_Target_MB,
    max_workers_count,
    affinity_type_desc
FROM sys.dm_os_sys_info;
GO


/******************************************************************************
SECTION 3 - CURRENT SQL MEMORY CONFIGURATION
Purpose  : Validate max server memory & min memory setting
******************************************************************************/
SELECT 
    name,
    value_in_use
FROM sys.configurations
WHERE name IN ('max server memory (MB)', 'min server memory (MB)');
GO


/******************************************************************************
SECTION 4 - MAXDOP & COST THRESHOLD
Purpose  : Review parallelism configuration
******************************************************************************/
SELECT 
    name,
    value_in_use
FROM sys.configurations
WHERE name IN ('max degree of parallelism', 'cost threshold for parallelism');
GO


/******************************************************************************
SECTION 5 - TEMPDB CONFIGURATION
Purpose  : Review tempdb file count & size
******************************************************************************/
SELECT 
    name,
    physical_name,
    size/128 AS Size_MB,
    max_size,
    growth/128 AS Growth_MB,
    is_percent_growth
FROM tempdb.sys.database_files;
GO


/******************************************************************************
SECTION 6 - DATABASE OVERVIEW
Purpose  : List all databases and their status
******************************************************************************/
SELECT 
    name,
    database_id,
    state_desc,
    recovery_model_desc,
    containment_desc,
    is_read_only,
    create_date
FROM sys.databases
ORDER BY name;
GO


/******************************************************************************
SECTION 7 - DATABASE SIZE SUMMARY
Purpose  : Identify total database size (Data + Log)
******************************************************************************/
SELECT 
    DB_NAME(database_id) AS Database_Name,
    SUM(size)/128 AS Total_Size_MB
FROM sys.master_files
GROUP BY database_id
ORDER BY Total_Size_MB DESC;
GO


/******************************************************************************
SECTION 8 - SQL SERVER STARTUP TIME
Purpose  : Check last restart time
******************************************************************************/
SELECT 
    sqlserver_start_time
FROM sys.dm_os_sys_info;
GO


/******************************************************************************
SECTION 9 - ACTIVE CONNECTION COUNT
Purpose  : Identify total current user connections
******************************************************************************/
SELECT 
    COUNT(*) AS Total_User_Sessions
FROM sys.dm_exec_sessions
WHERE is_user_process = 1;
GO


/******************************************************************************
SECTION 10 - WAIT STATISTICS SUMMARY (Top 10)
Purpose  : Identify dominant wait types (High-level indicator)
******************************************************************************/
SELECT TOP 10
    wait_type,
    waiting_tasks_count,
    wait_time_ms/1000.0 AS Wait_Time_Seconds
FROM sys.dm_os_wait_stats
WHERE wait_type NOT LIKE '%SLEEP%'
ORDER BY wait_time_ms DESC;
GO
