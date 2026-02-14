/* =============================================================
   Script Name   : IDX_04_Fragmentation_Assessment.sql
   Category      : Performance Tuning - Index Analysis
   Version       : 1.0
   Author        : Satria Pradnya
   Created       : 14 February 2026
   Last Update   : -

   Description   :
       Analyzes index fragmentation levels and recommends
       REORGANIZE or REBUILD actions based on best practice thresholds.

       Default Thresholds:
           - Fragmentation 5–30%   → REORGANIZE
           - Fragmentation > 30%   → REBUILD
           - Page count < 1000     → Ignored (low impact)

       Note:
           - Uses LIMITED mode for performance.
           - No changes are performed by this script.

   Execution Type : Read-Only
   Risk Level     : Low

   Compatibility :
       Minimum Version : SQL Server 2012
       Tested Version  : SQL Server 2019, 2022
       Azure Support   : Yes
       Edition         : All Editions
   ============================================================= */

SET NOCOUNT ON;

DECLARE @MinPageCount INT = 1000;

SELECT
    database_name = DB_NAME(),
    schema_name   = OBJECT_SCHEMA_NAME(ps.object_id),
    table_name    = OBJECT_NAME(ps.object_id),
    index_name    = i.name,
    ps.index_type_desc,
    ps.avg_fragmentation_in_percent,
    ps.page_count,
    recommendation =
        CASE
            WHEN ps.page_count < @MinPageCount THEN 'IGNORE'
            WHEN ps.avg_fragmentation_in_percent BETWEEN 5 AND 30 THEN 'REORGANIZE'
            WHEN ps.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
            ELSE 'OK'
        END
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
JOIN sys.indexes i
    ON ps.object_id = i.object_id
   AND ps.index_id  = i.index_id
WHERE i.index_id > 0
ORDER BY ps.avg_fragmentation_in_percent DESC;
