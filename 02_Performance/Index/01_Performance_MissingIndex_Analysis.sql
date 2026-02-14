/* =============================================================
   Script Name : 01_Performance_MissingIndex_Analysis.sql
   Category    : Performance Tuning - Index Analysis
   Version     : SQL Server 2012+
   Author      : Satria Pradnya
   Created     : 14 February 2026
   Last Update : -
   Description : 
       Identifies top missing index recommendations based on
       improvement_measure calculation from SQL Server DMVs.

       improvement_measure =
           avg_total_user_cost 
           * avg_user_impact 
           * (user_seeks + user_scans)

       Note:
       - Data is cumulative since last SQL Server restart.
       - Recommendations must be validated before implementation.
   
   ============================================================= */

SET NOCOUNT ON;

-- =============================================================
-- Configuration Section
-- =============================================================

DECLARE @DatabaseName SYSNAME = NULL;       -- Specify database name or NULL for all databases
DECLARE @MinimumScore DECIMAL(28,1) = 10;   -- Minimum improvement_measure threshold
DECLARE @TopResults INT = 50;               -- Number of top records to return

-- =============================================================
-- Missing Index Analysis
-- =============================================================

;WITH MissingIndexData AS
(
    SELECT
        runtime = SYSDATETIME(),
        database_name = DB_NAME(mid.database_id),
        mig.index_group_handle,
        mid.index_handle,
        mid.object_id,

        improvement_measure =
            CONVERT(DECIMAL(28,1),
                migs.avg_total_user_cost
                * migs.avg_user_impact
                * (migs.user_seeks + migs.user_scans)
            ),

        user_seeks  = migs.user_seeks,
        user_scans  = migs.user_scans,
        avg_user_impact = migs.avg_user_impact,
        avg_total_user_cost = migs.avg_total_user_cost,

        create_index_statement =
            'CREATE INDEX IX_Missing_'
            + CONVERT(VARCHAR(10), mig.index_group_handle)
            + '_'
            + CONVERT(VARCHAR(10), mid.index_handle)
            + ' ON ' + mid.statement
            + ' ('
            + ISNULL(mid.equality_columns, '')
            + CASE
                WHEN mid.equality_columns IS NOT NULL
                 AND mid.inequality_columns IS NOT NULL
                THEN ','
                ELSE ''
              END
            + ISNULL(mid.inequality_columns, '')
            + ')'
            + ISNULL(' INCLUDE (' + mid.included_columns + ')', '')
    FROM sys.dm_db_missing_index_groups mig
    INNER JOIN sys.dm_db_missing_index_group_stats migs
        ON mig.index_group_handle = migs.group_handle
    INNER JOIN sys.dm_db_missing_index_details mid
        ON mig.index_handle = mid.index_handle
    WHERE (@DatabaseName IS NULL 
           OR mid.database_id = DB_ID(@DatabaseName))
)

SELECT TOP (@TopResults) *
FROM MissingIndexData
WHERE improvement_measure >= @MinimumScore
ORDER BY improvement_measure DESC;

-- =============================================================
-- Important Considerations:
-- 1. Missing index DMVs are cleared on:
--      - SQL Server restart
--      - Database detach/attach
--      - Failover events
--
-- 2. Recommendations are based on query optimizer estimates.
--
-- 3. Always validate before creating indexes:
--      - Check for duplicate or overlapping indexes
--      - Evaluate write overhead impact
--      - Validate execution plans
--      - Consider storage and maintenance costs
-- =============================================================
