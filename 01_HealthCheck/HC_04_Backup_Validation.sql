/*
================================================================================
Script Name  : HC_04_Backup_Validation.sql
Category     : HealthCheck
Purpose      : Validate backup history & recovery readiness
Risk Level   : READ ONLY
================================================================================
*/


/******************************************************************************
SECTION 1 - LAST FULL BACKUP
******************************************************************************/
SELECT
    d.name AS Database_Name,
    MAX(b.backup_finish_date) AS Last_Full_Backup
FROM sys.databases d
LEFT JOIN msdb.dbo.backupset b
    ON d.name = b.database_name
    AND b.type = 'D'
GROUP BY d.name
ORDER BY Last_Full_Backup;
GO


/******************************************************************************
SECTION 2 - LAST DIFFERENTIAL BACKUP
******************************************************************************/
SELECT
    d.name AS Database_Name,
    MAX(b.backup_finish_date) AS Last_Diff_Backup
FROM sys.databases d
LEFT JOIN msdb.dbo.backupset b
    ON d.name = b.database_name
    AND b.type = 'I'
GROUP BY d.name
ORDER BY Last_Diff_Backup;
GO


/******************************************************************************
SECTION 3 - LAST LOG BACKUP
******************************************************************************/
SELECT
    d.name AS Database_Name,
    MAX(b.backup_finish_date) AS Last_Log_Backup
FROM sys.databases d
LEFT JOIN msdb.dbo.backupset b
    ON d.name = b.database_name
    AND b.type = 'L'
GROUP BY d.name
ORDER BY Last_Log_Backup;
GO


/******************************************************************************
SECTION 4 - DATABASE WITHOUT BACKUP (CRITICAL)
******************************************************************************/
SELECT
    d.name
FROM sys.databases d
LEFT JOIN msdb.dbo.backupset b
    ON d.name = b.database_name
WHERE b.database_name IS NULL
AND d.database_id > 4;
GO


/******************************************************************************
SECTION 5 - RECOVERY MODEL VALIDATION
******************************************************************************/
SELECT
    name,
    recovery_model_desc
FROM sys.databases
ORDER BY recovery_model_desc;
GO
