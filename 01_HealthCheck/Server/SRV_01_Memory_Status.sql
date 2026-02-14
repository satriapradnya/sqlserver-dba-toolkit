/* =============================================================
   Script Name   : SRV_01_Memory_Status.sql
   Category      : Health Check - Server
   Version       : 2.0
   Author        : Satria Pradnya
   Created       : 14 February 2026
   Last Update   : -
   Description   :
       Evaluates SQL Server memory configuration,
       detects buffer pool pressure, and provides
       actionable recommendations.

   Execution Type : Read-Only
   Risk Level     : Low

   Compatibility :
       Minimum Version : SQL Server 2012
       Tested Version  : SQL Server 2016, 2017, 2019, 2022
       Azure Support   : Partial
       Edition         : All Editions
   ============================================================= */

SET NOCOUNT ON;

DECLARE 
    @TotalPhysicalMemoryGB DECIMAL(10,2),
    @AvailableOSMemoryGB   DECIMAL(10,2),
    @MaxServerMemoryGB     DECIMAL(10,2),
    @SQLMemoryUsedGB       DECIMAL(10,2),
    @TargetServerMemoryGB  DECIMAL(10,2),
    @BufferUtilizationPct  DECIMAL(5,2),
    @PLE                   BIGINT,
    @MemoryGrantsPending   INT;

-------------------------------------------------------------
-- OS MEMORY
-------------------------------------------------------------
SELECT 
    @TotalPhysicalMemoryGB = total_physical_memory_kb / 1024.0 / 1024,
    @AvailableOSMemoryGB   = available_physical_memory_kb / 1024.0 / 1024
FROM sys.dm_os_sys_memory;

-------------------------------------------------------------
-- MAX SERVER MEMORY
-------------------------------------------------------------
SELECT 
    @MaxServerMemoryGB = CAST(value_in_use AS BIGINT) / 1024.0
FROM sys.configurations
WHERE name = 'max server memory (MB)';

-------------------------------------------------------------
-- SQL MEMORY USAGE
-------------------------------------------------------------
SELECT 
    @SQLMemoryUsedGB = physical_memory_in_use_kb / 1024.0 / 1024
FROM sys.dm_os_process_memory;

-------------------------------------------------------------
-- TARGET MEMORY
-------------------------------------------------------------
SELECT 
    @TargetServerMemoryGB = committed_target_kb / 1024.0 / 1024
FROM sys.dm_os_sys_info;

-------------------------------------------------------------
-- BUFFER UTILIZATION %
-------------------------------------------------------------
SET @BufferUtilizationPct =
    CASE 
        WHEN @MaxServerMemoryGB = 0 THEN 0
        ELSE (@SQLMemoryUsedGB / @MaxServerMemoryGB) * 100
    END;

-------------------------------------------------------------
-- PAGE LIFE EXPECTANCY (NUMA Safe)
-------------------------------------------------------------
SELECT 
    @PLE = MIN(cntr_value)
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Page life expectancy'
AND object_name LIKE '%Buffer Manager%';

-------------------------------------------------------------
-- MEMORY GRANTS PENDING
-------------------------------------------------------------
SELECT 
    @MemoryGrantsPending = cntr_value
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Memory Grants Pending';

-------------------------------------------------------------
-- RISK CLASSIFICATION
-------------------------------------------------------------
DECLARE 
    @OSMemoryRisk VARCHAR(10),
    @PLERisk VARCHAR(10),
    @GrantRisk VARCHAR(10),
    @ConfigRisk VARCHAR(10);

-- OS Memory Risk
SET @OSMemoryRisk =
    CASE 
        WHEN @AvailableOSMemoryGB < 1 THEN 'High'
        WHEN @AvailableOSMemoryGB < 4 THEN 'Medium'
        ELSE 'Low'
    END;

-- Modern PLE Threshold
SET @PLERisk =
    CASE 
        WHEN @PLE IS NULL THEN 'Unknown'
        WHEN @PLE <= 10 THEN 'High'
        WHEN @PLE <= 100 THEN 'Medium'
        ELSE 'Low'
    END;

-- Memory Grant Risk
SET @GrantRisk =
    CASE 
        WHEN @MemoryGrantsPending > 5 THEN 'High'
        WHEN @MemoryGrantsPending > 0 THEN 'Medium'
        ELSE 'Low'
    END;

-- Configuration Risk (OS aware)
SET @ConfigRisk =
    CASE 
        WHEN @AvailableOSMemoryGB < 2 
             AND @MaxServerMemoryGB > (@TotalPhysicalMemoryGB * 0.85)
        THEN 'High'
        WHEN @MaxServerMemoryGB > (@TotalPhysicalMemoryGB * 0.9)
        THEN 'Medium'
        ELSE 'Low'
    END;

-------------------------------------------------------------
-- FINAL OUTPUT
-------------------------------------------------------------
SELECT
    GETDATE()                    AS snapshot_time,
    @@SERVERNAME                 AS server_name,

    @TotalPhysicalMemoryGB       AS total_physical_memory_gb,
    @AvailableOSMemoryGB         AS available_os_memory_gb,
    @MaxServerMemoryGB           AS max_server_memory_gb,
    @SQLMemoryUsedGB             AS sql_memory_used_gb,
    @TargetServerMemoryGB        AS sql_target_memory_gb,
    @BufferUtilizationPct        AS buffer_utilization_percent,
    @PLE                         AS page_life_expectancy,
    @MemoryGrantsPending         AS memory_grants_pending,

    @OSMemoryRisk                AS os_memory_risk,
    @PLERisk                     AS ple_risk,
    @GrantRisk                   AS memory_grant_risk,
    @ConfigRisk                  AS config_risk,

    CASE 
        WHEN @PLERisk = 'High' 
             AND @BufferUtilizationPct >= 95
        THEN 'High'

        WHEN @GrantRisk = 'High'
        THEN 'High'

        WHEN @OSMemoryRisk = 'High'
        THEN 'High'

        ELSE 'Low'
    END AS overall_memory_health,

    CASE 
        WHEN @PLERisk = 'High'
             AND @BufferUtilizationPct >= 95
        THEN 'Severe buffer pool pressure detected. Working set exceeds allocated memory. Action: analyze top logical read queries, review missing indexes, and consider RAM upgrade if sustained.'

        WHEN @GrantRisk = 'High'
        THEN 'Memory grant contention detected. Investigate large sort/hash queries and tempdb workload.'

        WHEN @OSMemoryRisk = 'High'
        THEN 'Critical OS memory pressure detected. Reduce max server memory or increase physical RAM.'

        WHEN @ConfigRisk = 'High'
        THEN 'Max server memory configured too aggressively relative to OS memory. Leave sufficient headroom.'

        ELSE 'Memory configuration appears stable.'
    END AS recommended_action;
