/*
================================================================================
Script Name  : HC_03_IO_Health.sql
Category     : HealthCheck
Purpose      : Storage & I/O performance validation
Risk Level   : READ ONLY
================================================================================
*/


/******************************************************************************
SECTION 1 - FILE LEVEL IO STATS
Purpose  : Identify high latency data/log files
******************************************************************************/
SELECT
    DB_NAME(vfs.database_id) AS Database_Name,
    mf.physical_name,
    vfs.num_of_reads,
    vfs.num_of_writes,
    vfs.io_stall_read_ms,
    vfs.io_stall_write_ms,
    (vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads,0)) AS Avg_Read_Latency_ms,
    (vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes,0)) AS Avg_Write_Latency_ms
FROM sys.dm_io_virtual_file_stats(NULL,NULL) vfs
JOIN sys.master_files mf 
    ON vfs.database_id = mf.database_id 
    AND vfs.file_id = mf.file_id
ORDER BY Avg_Read_Latency_ms DESC;
GO


/******************************************************************************
SECTION 2 - DRIVE FREE SPACE
******************************************************************************/
SELECT
    vs.volume_mount_point,
    vs.total_bytes/1024/1024/1024 AS Total_GB,
    vs.available_bytes/1024/1024/1024 AS Free_GB,
    (vs.available_bytes * 100.0 / vs.total_bytes) AS Free_Percent
FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
GROUP BY vs.volume_mount_point, vs.total_bytes, vs.available_bytes
ORDER BY Free_Percent ASC;
GO


/******************************************************************************
SECTION 3 - PENDING IO REQUESTS
******************************************************************************/
SELECT *
FROM sys.dm_io_pending_io_requests;
GO
