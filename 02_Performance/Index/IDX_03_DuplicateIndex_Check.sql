/* =============================================================
   Script Name   : IDX_03_DuplicateIndex_Check.sql
   Category      : Performance Tuning - Index Analysis
   Version       : 1.0
   Author        : Satria Pradnya
   Created       : 14 February 2026
   Last Update   : -
   Description   :
       Detects duplicate or overlapping non-clustered indexes
       based on key column similarity.

       Note:
           - Comparison is based on key columns only.
           - Included columns are not evaluated.
           - Does not consider filtered indexes or index options.
           - Results require manual validation before removal.

   Execution Type : Read-Only
   Risk Level     : Low

   Compatibility :
       Minimum Version : SQL Server 2017
       Tested Version  : SQL Server 2019, 2022
       Azure Support   : Yes
       Edition         : All Editions
   ============================================================= */


SET NOCOUNT ON;

WITH IndexColumns AS
(
    SELECT
        i.object_id,
        i.index_id,
        i.name AS index_name,
        key_columns = STRING_AGG(c.name, ',')
                      WITHIN GROUP (ORDER BY ic.key_ordinal)
    FROM sys.indexes i
    INNER JOIN sys.index_columns ic
        ON i.object_id = ic.object_id
       AND i.index_id = ic.index_id
    INNER JOIN sys.columns c
        ON ic.object_id = c.object_id
       AND ic.column_id = c.column_id
    WHERE i.type_desc = 'NONCLUSTERED'
      AND ic.key_ordinal > 0
    GROUP BY i.object_id, i.index_id, i.name
)
SELECT
    OBJECT_SCHEMA_NAME(a.object_id) AS schema_name,
    OBJECT_NAME(a.object_id) AS table_name,
    a.index_name AS index_1,
    b.index_name AS index_2,
    a.key_columns
FROM IndexColumns a
JOIN IndexColumns b
    ON a.object_id = b.object_id
   AND a.index_id < b.index_id
   AND a.key_columns = b.key_columns
ORDER BY table_name;
