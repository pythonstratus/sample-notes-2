# Oracle Table Comparison Functions

A comprehensive suite of Oracle PL/SQL functions for comparing tables, table structures, and specific columns between datasets. These functions are designed to help database administrators and developers quickly identify differences between tables for data validation, ETL verification, and schema comparison purposes.

## 📋 Table of Contents

- [Functions Overview](#functions-overview)
- [Installation](#installation)
- [Function Descriptions](#function-descriptions)
- [Usage Examples](#usage-examples)
- [Common Use Cases](#common-use-cases)
- [Output Formats](#output-formats)
- [Error Handling](#error-handling)
- [Troubleshooting](#troubleshooting)

## 🔧 Functions Overview

| Function Name | Purpose | Key Features |
|---------------|---------|--------------|
| `compare_tables_fn` | Compare data between two tables | Full table comparison, optional column filtering |
| `compare_table_structure` | Compare table schemas | Column definitions, data types, constraints |
| `compare_tables_exclude_columns` | Compare tables excluding specific columns | Ignore audit/timestamp columns |
| `compare_columns_only` | Compare only specific columns | Focus on particular fields like EXTRDT |

## 🚀 Installation

### Prerequisites
- Oracle Database 11g or higher
- CREATE FUNCTION privileges
- Access to ALL_TABLES, ALL_TAB_COLUMNS, and related data dictionary views

### Installation Steps

1. **Connect to your Oracle database** using SQL*Plus, Toad, SQL Developer, or any Oracle client
2. **Execute each function** by copying and pasting the function code into your SQL client
3. **Compile the functions** - they will be created in your current schema
4. **Grant permissions** if needed for other users to access these functions

```sql
-- Example: Grant execute permission to other users
GRANT EXECUTE ON compare_tables_fn TO other_user;
```

## 📖 Function Descriptions

### 1. compare_tables_fn

**Purpose**: Compare data between two tables to identify records that exist only in source, only in target, or have different values.

**Parameters**:
- `p_source_table` (VARCHAR2) - Source table name **[Required]**
- `p_target_table` (VARCHAR2) - Target table name **[Required]**
- `p_compare_field` (VARCHAR2) - Specific field to compare [Optional - compares all if NULL]
- `p_key_field` (VARCHAR2) - Key field for joining [Optional - auto-detects primary key]

**Returns**: SYS_REFCURSOR with comparison results

### 2. compare_table_structure

**Purpose**: Compare the structural differences between two tables including column names, data types, lengths, and constraints.

**Parameters**:
- `p_source_table` (VARCHAR2) - Source table name **[Required]**
- `p_target_table` (VARCHAR2) - Target table name **[Required]**

**Returns**: SYS_REFCURSOR with structural comparison results

### 3. compare_tables_exclude_columns

**Purpose**: Compare tables while excluding specific columns from the comparison (useful for ignoring audit columns).

**Parameters**:
- `p_source_table` (VARCHAR2) - Source table name **[Required]**
- `p_target_table` (VARCHAR2) - Target table name **[Required]**
- `p_exclude_columns` (VARCHAR2) - Comma-separated list of columns to exclude [Optional]
- `p_compare_field` (VARCHAR2) - Specific field to compare [Optional]
- `p_key_field` (VARCHAR2) - Key field for joining [Optional]

**Returns**: SYS_REFCURSOR with comparison results

### 4. compare_columns_only

**Purpose**: Compare only specific columns between two tables, ignoring all other columns.

**Parameters**:
- `p_source_table` (VARCHAR2) - Source table name **[Required]**
- `p_target_table` (VARCHAR2) - Target table name **[Required]**
- `p_include_columns` (VARCHAR2) - Comma-separated list of columns to compare **[Required]**
- `p_key_field` (VARCHAR2) - Key field for joining [Optional]

**Returns**: SYS_REFCURSOR with comparison results

## 💡 Usage Examples

### Basic Table Comparison

```sql
-- Compare all columns between two tables
DECLARE
    v_cursor SYS_REFCURSOR;
BEGIN
    v_cursor := compare_tables_fn('EMPLOYEES_SOURCE', 'EMPLOYEES_TARGET');
    DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/
```

### Compare Specific Column

```sql
-- Compare only the SALARY column
DECLARE
    v_cursor SYS_REFCURSOR;
BEGIN
    v_cursor := compare_tables_fn(
        'EMPLOYEES_SOURCE', 
        'EMPLOYEES_TARGET', 
        'SALARY'
    );
    DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/
```

### Exclude Audit Columns

```sql
-- Compare tables but ignore audit columns
DECLARE
    v_cursor SYS_REFCURSOR;
BEGIN
    v_cursor := compare_tables_exclude_columns(
        'EMPLOYEES_SOURCE', 
        'EMPLOYEES_TARGET', 
        'CREATED_DATE,MODIFIED_DATE,CREATED_BY,MODIFIED_BY'
    );
    DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/
```

### Compare Table Structure

```sql
-- Compare table schemas
DECLARE
    v_cursor SYS_REFCURSOR;
BEGIN
    v_cursor := compare_table_structure('EMPLOYEES_V1', 'EMPLOYEES_V2');
    DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/
```

### Compare Only EXTRDT Columns

```sql
-- Compare only extraction date columns
DECLARE
    v_cursor SYS_REFCURSOR;
BEGIN
    v_cursor := compare_columns_only(
        'SOURCE_TABLE', 
        'TARGET_TABLE', 
        'EXTRDT'
    );
    DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/
```

### Compare Multiple Specific Columns

```sql
-- Compare only specific business-critical columns
DECLARE
    v_cursor SYS_REFCURSOR;
BEGIN
    v_cursor := compare_columns_only(
        'ORDERS_SOURCE', 
        'ORDERS_TARGET', 
        'ORDER_AMOUNT,ORDER_STATUS,CUSTOMER_ID'
    );
    DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/
```

## 🎯 Common Use Cases

### ETL Validation
Use these functions to verify that your ETL processes have correctly transformed and loaded data:

```sql
-- Verify ETL results
DECLARE
    v_cursor SYS_REFCURSOR;
BEGIN
    v_cursor := compare_tables_exclude_columns(
        'SOURCE_CUSTOMERS', 
        'WAREHOUSE_CUSTOMERS', 
        'ETL_LOAD_DATE,ETL_BATCH_ID'
    );
    DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/
```

### Data Migration Verification
Ensure data migration completed successfully:

```sql
-- Check migration results
DECLARE
    v_cursor SYS_REFCURSOR;
BEGIN
    v_cursor := compare_tables_fn('OLD_SYSTEM.PRODUCTS', 'NEW_SYSTEM.PRODUCTS');
    DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/
```

### Schema Evolution Tracking
Monitor changes between different versions of table structures:

```sql
-- Compare table schemas between environments
DECLARE
    v_cursor SYS_REFCURSOR;
BEGIN
    v_cursor := compare_table_structure('DEV.USERS', 'PROD.USERS');
    DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/
```

## 📊 Output Formats

### Data Comparison Results

| Column | Description |
|--------|-------------|
| `STATUS` | ONLY_IN_SOURCE, ONLY_IN_TARGET, or DIFFERENT |
| `KEY_VALUE` | The key field value for the record |
| `[COLUMN]_SOURCE` | Value from source table |
| `[COLUMN]_TARGET` | Value from target table |
| `[COLUMN]_DIFF` | Difference indicator (when using marker functions) |

### Structure Comparison Results

| Column | Description |
|--------|-------------|
| `COLUMN_NAME` | Name of the column |
| `STATUS` | ONLY_IN_SOURCE, ONLY_IN_TARGET, DIFFERENT, or IDENTICAL |
| `DESCRIPTION` | Human-readable description of the difference |
| `SOURCE_DETAILS` | Column definition in source table |
| `TARGET_DETAILS` | Column definition in target table |
| `DIFFERENCE_DETAILS` | Specific details about the difference |

## ⚠️ Error Handling

### Common Error Codes

| Error Code | Description | Solution |
|------------|-------------|----------|
| ORA-20001 | Source/target table must be specified | Ensure both table parameters are provided |
| ORA-20002 | Source table does not exist | Verify source table name and schema access |
| ORA-20003 | Target table does not exist | Verify target table name and schema access |
| ORA-20006 | Key field does not exist in both tables | Specify a valid key field that exists in both tables |
| ORA-20007 | No common columns found | Tables must have at least one common column |
| ORA-20008 | Compare field does not exist in both tables | Verify the comparison field exists in both tables |

### Error Examples and Solutions

```sql
-- Error: Table not found
-- Solution: Check table name and schema
SELECT COUNT(*) FROM all_tables 
WHERE table_name = 'YOUR_TABLE_NAME' 
AND owner = 'YOUR_SCHEMA';

-- Error: No common columns
-- Solution: Check column names match between tables
SELECT column_name FROM all_tab_columns 
WHERE table_name = 'TABLE1'
INTERSECT
SELECT column_name FROM all_tab_columns 
WHERE table_name = 'TABLE2';
```

## 🛠️ Troubleshooting

### Performance Issues

**Problem**: Function runs slowly on large tables  
**Solution**: 
- Add indexes on key fields
- Use specific column comparison instead of full table comparison
- Consider filtering data with WHERE clauses

**Problem**: Out of memory errors  
**Solution**: 
- Process data in smaller batches
- Exclude unnecessary columns
- Use specific column comparison functions

### Permission Issues

**Problem**: Cannot access tables  
**Solution**:
```sql
-- Grant necessary permissions
GRANT SELECT ON source_table TO your_user;
GRANT SELECT ON target_table TO your_user;
```

### Compilation Issues

**Problem**: Function won't compile  
**Solution**:
- Check Oracle version compatibility
- Verify all semicolons and syntax
- Ensure proper privileges for creating functions

## 📝 Best Practices

1. **Index Key Fields**: Ensure proper indexing on key fields for better performance
2. **Use Specific Comparisons**: When possible, compare specific columns rather than entire tables
3. **Handle Large Tables**: For very large tables, consider adding WHERE clauses or pagination
4. **Test with Small Data**: Always test functions with small datasets first
5. **Monitor Performance**: Use EXPLAIN PLAN to understand query execution
6. **Schema Qualification**: Use schema-qualified table names when comparing across schemas

## 🔄 Version History

- **v1.0**: Initial release with basic table comparison
- **v1.1**: Added structure comparison function
- **v1.2**: Added column exclusion capability
- **v1.3**: Added specific column comparison
- **v1.4**: Enhanced error handling and visual markers

## 📞 Support

For issues, questions, or contributions:
- Check the troubleshooting section above
- Review Oracle documentation for PL/SQL functions
- Ensure proper privileges and table access
- Test with simplified datasets to isolate issues

---

**Note**: These functions are designed for Oracle databases and have been tested on Oracle 11g and higher versions. Always test in a development environment before using in production.
