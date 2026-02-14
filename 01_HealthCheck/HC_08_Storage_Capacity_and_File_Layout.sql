/*
================================================================================
Script Name  : HC_08_Storage_Capacity_and_File_Layout.sql
Author       : DBA Team
Created Date : 2026-02-14
SQL Version  : 2012+
Category     : HealthCheck
Purpose      : Storage capacity validation, database file layout review,
               growth configuration & risk assessment
Risk Level   : READ ONLY (SAFE)
================================================================================
Description:
This script validates:
- Disk capacity & free space
- Database file & log file path
- File size & growth configuration
- Autogrowth risk
- Volume usage risk
================================================================================
*/

USE master;
GO


/******************************************************************************
SECTION 1 - SERVER INFO (IP & Collection Time)
******************************************************************************/
SELECT 
    SYSDATETIMEOFFSET() AS Collection_Time,
    CONNECTIONPROPERTY('local_net_address') AS IP_Address,
    @@SERVERNAME AS Server_Name;
GO


/******************************************************************************
SECTION 2 - DISK CAPACITY & FREE SPACE (ALL VOLUMES)
Purpose  : Identify disk space risk
******************************************************************************/
SELECT  
    CONNECTIONPROPERTY('local_net_address') AS IP_Address,
    vs.volume_mount_point AS Drive,
    vs.logical_volume_name,
    CAST(vs.total_bytes/1024.0/1024/1024 AS DECIMAL(18,2)) AS Capacity_GB,
    CAST(vs.available_bytes/1024.0/1024/1024 AS DECIMAL(18,2)) AS Free_GB,
    CAST((vs.total_bytes - vs.available_bytes)/1024.0/1024/1024 AS DECIMAL(18,2)) AS Used_GB,
    CAST((vs.available_bytes * 100.0 / vs.total_bytes) AS DECIMAL(5,2)) AS Percent_Free,
    CAST((100 - (vs.available_bytes * 100.0 / vs.total_bytes)) AS DECIMAL(5,2)) AS Percent_Used
FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
GROUP BY vs.volume_mount_point, vs.logical_volume_name, vs.total_bytes, vs.available_bytes
ORDER BY Percent_Free ASC;
GO


/******************************************************************************
SECTION 3 - DATABASE FILE, LOG PATH & SEPARATION VALIDATION
Purpose  :
- Display Data & Log file path
- Show file size
- Validate whether Data & Log are on same drive (Best Practice Check)
- Include Database_ID for mapping & auditing
******************************************************************************/

WITH FileDetails AS
(
    SELECT
        d.database_id,
        d.name AS Database_Name,
        mf.type_desc,
        mf.physical_name,
        LEFT(mf.physical_name, 3) AS Drive_Letter,
        CAST(mf.size * 8.0 / 1024 / 1024 AS DECIMAL(18,2)) AS Size_GB
    FROM sys.databases d
    JOIN sys.master_files mf 
        ON d.database_id = mf.database_id
)
SELECT
    database_id,
    Database_Name,

    MAX(CASE WHEN type_desc = 'ROWS' THEN physical_name END) AS Data_File_Path,
    MAX(CASE WHEN type_desc = 'LOG' THEN physical_name END) AS Log_File_Path,

    MAX(CASE WHEN type_desc = 'ROWS' THEN Size_GB END) AS Data_Size_GB,
    MAX(CASE WHEN type_desc = 'LOG' THEN Size_GB END) AS Log_Size_GB,

    MAX(CASE WHEN type_desc = 'ROWS' THEN Drive_Letter END) AS Data_Drive,
    MAX(CASE WHEN type_desc = 'LOG' THEN Drive_Letter END) AS Log_Drive,

    CASE 
        WHEN MAX(CASE WHEN type_desc = 'ROWS' THEN Drive_Letter END) =
             MAX(CASE WHEN type_desc = 'LOG' THEN Drive_Letter END)
        THEN 'RISK - SAME DRIVE'
        ELSE 'OK - SEPARATED'
    END AS Data_Log_Separation_Status

FROM FileDetails
GROUP BY database_id, Database_Name
ORDER BY database_id;
GO


/******************************************************************************
SECTION 4 - FILE AUTOGROWTH CONFIGURATION
Purpose  : Detect percentage growth (Risk for large DB)
******************************************************************************/
SELECT
    DB_NAME(database_id) AS Database_Name,
    name AS Logical_File_Name,
    type_desc,
    growth,
    is_percent_growth,
    CASE 
        WHEN is_percent_growth = 1 THEN 'PERCENT_GROWTH'
        ELSE 'FIXED_MB_GROWTH'
    END AS Growth_Type
FROM sys.master_files
ORDER BY Database_Name;
GO


/******************************************************************************
SECTION 5 - DATABASE SIZE SUMMARY (DATA vs LOG)
******************************************************************************/
SELECT
    DB_NAME(database_id) AS Database_Name,
    type_desc,
    SUM(size) * 8.0 / 1024 AS Size_MB
FROM sys.master_files
GROUP BY database_id, type_desc
ORDER BY Database_Name;
GO


/******************************************************************************
SECTION 6 - LOG SPACE USAGE PERCENTAGE
Purpose  : Detect log almost full
******************************************************************************/
DBCC SQLPERF(LOGSPACE);
GO


/******************************************************************************
SECTION 7 - FILES WITH LARGE UNUSED SPACE (Internal Free Space)
Purpose  : Identify over-allocated files
******************************************************************************/
SELECT
    DB_NAME(database_id) AS Database_Name,
    name AS File_Name,
    size * 8.0 / 1024 AS Allocated_MB,
    FILEPROPERTY(name,'SpaceUsed') * 8.0 / 1024 AS Used_MB,
    (size - FILEPROPERTY(name,'SpaceUsed')) * 8.0 / 1024 AS Free_Inside_File_MB
FROM sys.database_files;
GO


/******************************************************************************
SECTION 8 - TOP LARGEST DATABASES
Purpose  : Quick ranking for capacity planning
******************************************************************************/
SELECT TOP 10
    DB_NAME(database_id) AS Database_Name,
    SUM(size) * 8.0 / 1024 AS Size_MB
FROM sys.master_files
GROUP BY database_id
ORDER BY Size_MB DESC;
GO
