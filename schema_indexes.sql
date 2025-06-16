-- Stored Procedure to generate comprehensive index report for a schema
-- This SP provides detailed information about all indexes across all tables

CREATE PROCEDURE sp_GenerateIndexReport
    @SchemaName NVARCHAR(128) = NULL,  -- Optional: specify schema, defaults to current user's default schema
    @TableName NVARCHAR(128) = NULL,   -- Optional: specify specific table, NULL for all tables
    @IndexType NVARCHAR(50) = NULL,    -- Optional: filter by index type (CLUSTERED, NONCLUSTERED, etc.)
    @IncludeSystemTables BIT = 0,      -- Optional: include system tables (default: 0)
    @OutputFormat VARCHAR(20) = 'DETAILED' -- Options: 'DETAILED', 'SUMMARY', 'DROP_RECREATE'
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Set default schema if not provided
    IF @SchemaName IS NULL
        SET @SchemaName = SCHEMA_NAME();
    
    -- Detailed report with all index information
    IF @OutputFormat = 'DETAILED'
    BEGIN
        SELECT 
            s.name AS SchemaName,
            t.name AS TableName,
            i.name AS IndexName,
            i.type_desc AS IndexType,
            i.is_unique AS IsUnique,
            i.is_primary_key AS IsPrimaryKey,
            i.is_unique_constraint AS IsUniqueConstraint,
            i.fill_factor AS FillFactor,
            i.is_padded AS IsPadded,
            i.is_disabled AS IsDisabled,
            i.allow_row_locks AS AllowRowLocks,
            i.allow_page_locks AS AllowPageLocks,
            -- Get index columns
            STUFF((
                SELECT ', ' + c.name + 
                       CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
                FROM sys.index_columns ic
                INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
                ORDER BY ic.key_ordinal
                FOR XML PATH('')
            ), 1, 2, '') AS KeyColumns,
            -- Get included columns
            STUFF((
                SELECT ', ' + c.name
                FROM sys.index_columns ic
                INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
                ORDER BY ic.key_ordinal
                FOR XML PATH('')
            ), 1, 2, '') AS IncludedColumns,
            -- Get index size information
            ps.used_page_count * 8 AS IndexSizeKB,
            ps.row_count AS RowCount,
            -- Get partition information
            p.partition_number AS PartitionNumber,
            fg.name AS FileGroupName
        FROM sys.schemas s
        INNER JOIN sys.tables t ON s.schema_id = t.schema_id
        INNER JOIN sys.indexes i ON t.object_id = i.object_id
        LEFT JOIN sys.dm_db_partition_stats ps ON i.object_id = ps.object_id AND i.index_id = ps.index_id
        LEFT JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
        LEFT JOIN sys.filegroups fg ON i.data_space_id = fg.data_space_id
        WHERE s.name = @SchemaName
            AND (@TableName IS NULL OR t.name = @TableName)
            AND (@IndexType IS NULL OR i.type_desc = @IndexType)
            AND (@IncludeSystemTables = 1 OR t.is_ms_shipped = 0)
            AND i.type > 0  -- Exclude heap (type = 0)
        ORDER BY s.name, t.name, i.name;
    END
    
    -- Summary report with counts and totals
    ELSE IF @OutputFormat = 'SUMMARY'
    BEGIN
        SELECT 
            s.name AS SchemaName,
            t.name AS TableName,
            COUNT(i.index_id) AS TotalIndexes,
            SUM(CASE WHEN i.type_desc = 'CLUSTERED' THEN 1 ELSE 0 END) AS ClusteredIndexes,
            SUM(CASE WHEN i.type_desc = 'NONCLUSTERED' THEN 1 ELSE 0 END) AS NonClusteredIndexes,
            SUM(CASE WHEN i.is_unique = 1 THEN 1 ELSE 0 END) AS UniqueIndexes,
            SUM(CASE WHEN i.is_primary_key = 1 THEN 1 ELSE 0 END) AS PrimaryKeyIndexes,
            SUM(CASE WHEN i.is_disabled = 1 THEN 1 ELSE 0 END) AS DisabledIndexes,
            SUM(ps.used_page_count * 8) AS TotalIndexSizeKB
        FROM sys.schemas s
        INNER JOIN sys.tables t ON s.schema_id = t.schema_id
        INNER JOIN sys.indexes i ON t.object_id = i.object_id
        LEFT JOIN sys.dm_db_partition_stats ps ON i.object_id = ps.object_id AND i.index_id = ps.index_id
        WHERE s.name = @SchemaName
            AND (@TableName IS NULL OR t.name = @TableName)
            AND (@IndexType IS NULL OR i.type_desc = @IndexType)
            AND (@IncludeSystemTables = 1 OR t.is_ms_shipped = 0)
            AND i.type > 0  -- Exclude heap (type = 0)
        GROUP BY s.name, t.name
        ORDER BY s.name, t.name;
    END
    
    -- Generate DROP and CREATE scripts for indexes
    ELSE IF @OutputFormat = 'DROP_RECREATE'
    BEGIN
        -- DROP statements
        SELECT 
            'DROP INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + ';' AS DropStatement,
            s.name AS SchemaName,
            t.name AS TableName,
            i.name AS IndexName,
            i.type_desc AS IndexType,
            1 AS StatementOrder
        FROM sys.schemas s
        INNER JOIN sys.tables t ON s.schema_id = t.schema_id
        INNER JOIN sys.indexes i ON t.object_id = i.object_id
        WHERE s.name = @SchemaName
            AND (@TableName IS NULL OR t.name = @TableName)
            AND (@IndexType IS NULL OR i.type_desc = @IndexType)
            AND (@IncludeSystemTables = 1 OR t.is_ms_shipped = 0)
            AND i.type > 0  -- Exclude heap (type = 0)
            AND i.is_primary_key = 0  -- Don't drop primary key indexes
            AND i.is_unique_constraint = 0  -- Don't drop unique constraint indexes
        
        UNION ALL
        
        -- CREATE statements
        SELECT 
            'CREATE ' + 
            CASE WHEN i.is_unique = 1 THEN 'UNIQUE ' ELSE '' END +
            i.type_desc + ' INDEX ' + QUOTENAME(i.name) + 
            ' ON ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + ' (' +
            STUFF((
                SELECT ', ' + QUOTENAME(c.name) + 
                       CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
                FROM sys.index_columns ic
                INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
                ORDER BY ic.key_ordinal
                FOR XML PATH('')
            ), 1, 2, '') + ')' +
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM sys.index_columns ic2 
                    WHERE ic2.object_id = i.object_id AND ic2.index_id = i.index_id AND ic2.is_included_column = 1
                ) THEN 
                    ' INCLUDE (' + 
                    STUFF((
                        SELECT ', ' + QUOTENAME(c.name)
                        FROM sys.index_columns ic
                        INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
                        ORDER BY ic.key_ordinal
                        FOR XML PATH('')
                    ), 1, 2, '') + ')'
                ELSE ''
            END +
            CASE WHEN i.fill_factor > 0 THEN ' WITH (FILLFACTOR = ' + CAST(i.fill_factor AS VARCHAR(3)) + ')' ELSE '' END +
            ';' AS CreateStatement,
            s.name AS SchemaName,
            t.name AS TableName,
            i.name AS IndexName,
            i.type_desc AS IndexType,
            2 AS StatementOrder
        FROM sys.schemas s
        INNER JOIN sys.tables t ON s.schema_id = t.schema_id
        INNER JOIN sys.indexes i ON t.object_id = i.object_id
        WHERE s.name = @SchemaName
            AND (@TableName IS NULL OR t.name = @TableName)
            AND (@IndexType IS NULL OR i.type_desc = @IndexType)
            AND (@IncludeSystemTables = 1 OR t.is_ms_shipped = 0)
            AND i.type > 0  -- Exclude heap (type = 0)
            AND i.is_primary_key = 0  -- Don't recreate primary key indexes
            AND i.is_unique_constraint = 0  -- Don't recreate unique constraint indexes
        
        ORDER BY SchemaName, TableName, IndexName, StatementOrder;
    END
END;

-- Example usage:
/*
-- Get detailed report for all indexes in 'dbo' schema
EXEC sp_GenerateIndexReport @SchemaName = 'dbo', @OutputFormat = 'DETAILED';

-- Get summary report for all indexes
EXEC sp_GenerateIndexReport @SchemaName = 'dbo', @OutputFormat = 'SUMMARY';

-- Get DROP and CREATE scripts for all non-clustered indexes
EXEC sp_GenerateIndexReport @SchemaName = 'dbo', @IndexType = 'NONCLUSTERED', @OutputFormat = 'DROP_RECREATE';

-- Get report for specific table
EXEC sp_GenerateIndexReport @SchemaName = 'dbo', @TableName = 'YourTableName', @OutputFormat = 'DETAILED';
*/
