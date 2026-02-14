/* =============================================================
   Script Name   : IDX_05_Index_Usage_Summary.sql
   Category      : Performance Tuning - Index Analysis
   Version       : 1.0
   Author        : Satria Pradnya
   Created       : 14 February 2026
   Last Update   : -

   Description   :
       Provides comprehensive index usage statistics including
       seeks, scans, lookups, and updates.

       Useful for identifying:
           - Frequently used indexes
           - Write-heavy indexes
           - Rarely used indexes

       Note:
           - Data resets on SQL Server restart.

   Execution Type : Read-Only
   Risk Level     : Low

   Compatibility :
       Minimum Version : SQL Server 2012
       Tested Version  : SQL Server 2019, 2022
       Azure Support   : Yes
       Edition         : All Editions
   ============================================================= */

SET NOCOUNT ON;

SELECT
    database_name = DB_NAME(),
    schema_name   = OBJECT_SCHEMA_NAME(i.object_id),
    table_name    = OBJECT_NAME(i.object_id),
    index_name    = i.name,
    i.type_desc,
    user_seeks,
    user_scans,
    user_lookups,
    user_updates,
    total_reads = user_seeks + user_scans + user_lookups,
    read_write_ratio =
        CASE WHEN user_updates = 0 THEN NULL
             ELSE CAST((user_seeks + user_scans + user_lookups) AS DECIMAL(18,2)) 
                  / NULLIF(user_updates,0)
        END
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us
    ON i.object_id = us.object_id
   AND i.index_id  = us.index_id
   AND us.database_id = DB_ID()
WHERE i.index_id > 0
ORDER BY total_reads DESC;
