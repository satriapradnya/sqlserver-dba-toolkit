/* =============================================================
   Script Name : 02_Performance_UnusedIndex_Analysis.sql
   Category    : Performance Tuning - Index Analysis
   Version     : 1.0
   Author      : Satria Pradnya 
   Created     : 14 February 2026 
   Last Update : - 
   Description :
       Identifies non-clustered indexes that are not being used
       (no seeks, scans, or lookups) but incur write overhead.
       Excludes primary keys and unique constraints.
   ============================================================= */

SET NOCOUNT ON;

DECLARE @DatabaseName SYSNAME = NULL;  -- NULL = current database
DECLARE @MinWrites BIGINT = 100;       -- Minimum write activity threshold

SELECT
    DB_NAME() AS database_name,
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    i.type_desc,
    us.user_seeks,
    us.user_scans,
    us.user_lookups,
    us.user_updates,
    total_reads = ISNULL(us.user_seeks,0)
                + ISNULL(us.user_scans,0)
                + ISNULL(us.user_lookups,0),
    drop_statement =
        'DROP INDEX [' + i.name + '] ON '
        + OBJECT_SCHEMA_NAME(i.object_id)
        + '.[' + OBJECT_NAME(i.object_id) + ']'
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us
    ON i.object_id = us.object_id
   AND i.index_id = us.index_id
   AND us.database_id = DB_ID()
WHERE i.type_desc = 'NONCLUSTERED'
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND (
        ISNULL(us.user_seeks,0) = 0
    AND ISNULL(us.user_scans,0) = 0
    AND ISNULL(us.user_lookups,0) = 0
      )
  AND ISNULL(us.user_updates,0) >= @MinWrites
ORDER BY us.user_updates DESC;
