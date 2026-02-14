/* =============================================================
   Script Name   : IDX_07_Index_Recommendation_Report.sql
   Category      : Performance Tuning - Index Governance
   Version       : 2.1
   Author        : Satria Pradnya
   Created       : 14 February 2026
   Last Update   : 14 February 2026

   Description   :
       Comprehensive index governance dashboard including:
           - Unused Index Detection
           - Write-Heavy Index Identification
           - Fragmentation Assessment
           - Large Index Detection

       Provides severity classification and action guidance.

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
DECLARE @LargeIndexMB INT = 500;

;WITH IndexBase AS
(
    SELECT
        OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
        OBJECT_NAME(i.object_id) AS table_name,
        i.name AS index_name,
        i.type_desc,
        i.object_id,
        i.index_id,

        ISNULL(us.user_seeks,0)   AS user_seeks,
        ISNULL(us.user_scans,0)   AS user_scans,
        ISNULL(us.user_lookups,0) AS user_lookups,
        ISNULL(us.user_updates,0) AS user_updates,

        (ISNULL(us.user_seeks,0)
        +ISNULL(us.user_scans,0)
        +ISNULL(us.user_lookups,0)) AS total_reads,

        CAST(SUM(ps.used_page_count)*8.0/1024 AS DECIMAL(18,2)) AS size_mb
    FROM sys.indexes i
    LEFT JOIN sys.dm_db_index_usage_stats us
        ON i.object_id = us.object_id
       AND i.index_id  = us.index_id
       AND us.database_id = DB_ID()
    JOIN sys.dm_db_partition_stats ps
        ON i.object_id = ps.object_id
       AND i.index_id  = ps.index_id
    WHERE i.index_id > 0
    GROUP BY
        i.object_id, i.index_id, i.name, i.type_desc,
        us.user_seeks, us.user_scans, us.user_lookups, us.user_updates
),
FragmentationData AS
(
    SELECT
        object_id,
        index_id,
        avg_fragmentation_in_percent,
        page_count
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED')
),
FinalReport AS
(
    SELECT
        ib.schema_name,
        ib.table_name,
        ib.index_name,
        ib.type_desc,
        ib.total_reads,
        ib.user_updates,
        ib.size_mb,
        fd.avg_fragmentation_in_percent,
        fd.page_count,

        category =
            CASE
                WHEN ib.total_reads = 0 AND ib.user_updates > 0
                    THEN 'Unused Index (Write Overhead)'
                WHEN ib.total_reads < ib.user_updates
                    THEN 'Write-Heavy Index'
                WHEN fd.avg_fragmentation_in_percent > 30
                     AND fd.page_count > @MinPageCount
                    THEN 'High Fragmentation'
                WHEN ib.size_mb > @LargeIndexMB
                    THEN 'Large Index'
                ELSE 'Review'
            END,

        severity =
            CASE
                WHEN ib.total_reads = 0 AND ib.user_updates > 0
                    THEN 'High'
                WHEN ib.total_reads < ib.user_updates
                    THEN 'Medium'
                WHEN fd.avg_fragmentation_in_percent > 50
                    THEN 'High'
                WHEN fd.avg_fragmentation_in_percent BETWEEN 30 AND 50
                    THEN 'Medium'
                WHEN ib.size_mb > 1024
                    THEN 'High'
                WHEN ib.size_mb > @LargeIndexMB
                    THEN 'Medium'
                ELSE 'Low'
            END,

        recommended_action =
            CASE
                WHEN ib.total_reads = 0 AND ib.user_updates > 0
                    THEN 'Consider DROP after validation'
                WHEN ib.total_reads < ib.user_updates
                    THEN 'Review necessity / Evaluate workload'
                WHEN fd.avg_fragmentation_in_percent BETWEEN 5 AND 30
                    THEN 'REORGANIZE'
                WHEN fd.avg_fragmentation_in_percent > 30
                    THEN 'REBUILD'
                WHEN ib.size_mb > @LargeIndexMB
                    THEN 'Evaluate storage & access pattern'
                ELSE 'Monitor'
            END
    FROM IndexBase ib
    LEFT JOIN FragmentationData fd
        ON ib.object_id = fd.object_id
       AND ib.index_id  = fd.index_id
)

SELECT *
FROM FinalReport
ORDER BY
    CASE severity
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    size_mb DESC;
