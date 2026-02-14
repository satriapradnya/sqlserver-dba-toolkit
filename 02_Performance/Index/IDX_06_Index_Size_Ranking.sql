/* =============================================================
   Script Name   : IDX_06_Index_Size_Ranking.sql
   Category      : Performance Tuning - Index Analysis
   Version       : 1.0
   Author        : Satria Pradnya
   Created       : 14 February 2026
   Last Update   : -

   Description   :
       Ranks indexes by total size (MB) to identify
       storage-heavy structures.

       Useful for:
           - Capacity planning
           - Storage optimization
           - Large index review

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
    size_mb = 
        CAST(SUM(ps.used_page_count) * 8.0 / 1024 AS DECIMAL(18,2))
FROM sys.indexes i
JOIN sys.dm_db_partition_stats ps
    ON i.object_id = ps.object_id
   AND i.index_id  = ps.index_id
WHERE i.index_id > 0
GROUP BY i.object_id, i.name, i.type_desc
ORDER BY size_mb DESC;
