/*
================================================================================
Script Name  : HC_02_Database_Health.sql
Author       : DBA Team
Created Date : 2026-02-14
SQL Version  : 2012+
Category     : HealthCheck
Purpose      : Database level health validation
Risk Level   : READ ONLY (SAFE)
================================================================================
*/


/******************************************************************************
SECTION 1 - DATABASE STATE CHECK
Purpose  : Identify suspect, offline, recovery pending databases
******************************************************************************/
SELECT
    name,
    state_desc,
    recovery_model_desc,
    log_reuse_wait_desc
FROM sys.databases
ORDER BY state_desc DESC;
GO


/******************************************************************************
SECTION 2 - DATABASE COMPATIBILITY LEVEL
Purpose  : Detect outdated compatibility settings
******************************************************************************/
SELECT
    name,
    compatibility_level
FROM sys.databases
ORDER BY compatibility_level;
GO


/******************************************************************************
SECTION 3 - AUTO SETTINGS CHECK
Purpose  : Validate Auto Close / Auto Shrink (should be OFF)
******************************************************************************/
SELECT
    name,
    is_auto_close_on,
    is_auto_shrink_on,
    is_auto_create_stats_on,
    is_auto_update_stats_on
FROM sys.databases;
GO


/******************************************************************************
SECTION 4 - LOG FILE USAGE
Purpose  : Check transaction log utilization percentage
******************************************************************************/
DBCC SQLPERF(LOGSPACE);
GO


/******************************************************************************
SECTION 5 - VLF COUNT CHECK
Purpose  : Detect excessive VLF (can cause slow recovery)
******************************************************************************/
DBCC LOGINFO;
GO


/******************************************************************************
SECTION 6 - DATABASE SIZE DETAIL (DATA vs LOG)
******************************************************************************/
SELECT
    DB_NAME(database_id) AS Database_Name,
    type_desc,
    SUM(size)/128 AS Size_MB
FROM sys.master_files
GROUP BY database_id, type_desc
ORDER BY Database_Name;
GO
