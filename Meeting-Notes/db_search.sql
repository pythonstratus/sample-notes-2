Yes, absolutely! Oracle provides several ways to search through stored procedures and functions for specific text patterns. Here are the most effective approaches:

## Method 1: Using USER_SOURCE (Current Schema)

```sql
SELECT name, type, line, text
FROM user_source
WHERE UPPER(text) LIKE '%ALS.LA%'
   OR REGEXP_LIKE(text, 'ALS\..*', 'i')
ORDER BY name, type, line;
```

## Method 2: Using ALL_SOURCE (All Accessible Schemas)

```sql
SELECT owner, name, type, line, text
FROM all_source
WHERE UPPER(text) LIKE '%ALS.LA%'
   OR REGEXP_LIKE(text, 'ALS\..*', 'i')
ORDER BY owner, name, type, line;
```

## Method 3: Using DBA_SOURCE (All Schemas - Requires DBA Privileges)

```sql
SELECT owner, name, type, line, text
FROM dba_source
WHERE UPPER(text) LIKE '%ALS.LA%'
   OR REGEXP_LIKE(text, 'ALS\..*', 'i')
ORDER BY owner, name, type, line;
```

## Method 4: Create a Custom Function

Here's a more sophisticated approach using a function:

```sql
CREATE OR REPLACE FUNCTION search_code(
    p_search_pattern VARCHAR2,
    p_owner VARCHAR2 DEFAULT USER
) RETURN SYS_REFCURSOR
IS
    v_cursor SYS_REFCURSOR;
    v_sql VARCHAR2(4000);
BEGIN
    v_sql := '
        SELECT owner, name, type, line, text
        FROM all_source
        WHERE owner = :owner
        AND (UPPER(text) LIKE UPPER(:pattern1)
             OR REGEXP_LIKE(text, :pattern2, ''i''))
        ORDER BY name, type, line';
    
    OPEN v_cursor FOR v_sql 
        USING p_owner, 
              '%' || p_search_pattern || '%',
              p_search_pattern;
    
    RETURN v_cursor;
END;
/
```

Usage:
```sql
-- Search for ALS.LA
DECLARE
    v_cursor SYS_REFCURSOR;
BEGIN
    v_cursor := search_code('ALS\.LA');
    -- Process cursor results
END;
/
```

## Method 5: Comprehensive Search Procedure

```sql
CREATE OR REPLACE PROCEDURE search_all_code(
    p_search_pattern VARCHAR2,
    p_use_regex BOOLEAN DEFAULT TRUE
)
IS
    CURSOR c_search IS
        SELECT owner, name, type, line, text
        FROM all_source
        WHERE (p_use_regex = TRUE AND REGEXP_LIKE(text, p_search_pattern, 'i'))
           OR (p_use_regex = FALSE AND UPPER(text) LIKE '%' || UPPER(p_search_pattern) || '%')
        ORDER BY owner, name, type, line;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Searching for pattern: ' || p_search_pattern);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    FOR rec IN c_search LOOP
        DBMS_OUTPUT.PUT_LINE(rec.owner || '.' || rec.name || ' (' || rec.type || ') Line ' || rec.line);
        DBMS_OUTPUT.PUT_LINE('  ' || TRIM(rec.text));
        DBMS_OUTPUT.PUT_LINE('');
    END LOOP;
END;
/
```

Usage:
```sql
-- Search for ALS.LA (exact)
EXEC search_all_code('ALS\.LA', TRUE);

-- Search for ALS.* pattern
EXEC search_all_code('ALS\..*', TRUE);

-- Simple text search
EXEC search_all_code('ALS', FALSE);
```

## Key Points:

1. **Regular Expressions**: Use `REGEXP_LIKE` for pattern matching with `ALS\..*` (the backslash escapes the dot)
2. **Case Sensitivity**: Use the 'i' flag for case-insensitive regex, or `UPPER()` for LIKE
3. **Scope**: Choose USER_SOURCE, ALL_SOURCE, or DBA_SOURCE based on your access needs
4. **Performance**: Add WHERE clauses to filter by object type if needed (`type IN ('FUNCTION', 'PROCEDURE')`)

The regex pattern `ALS\..*` will match "ALS." followed by any characters, while `ALS\.LA` will match exactly "ALS.LA".
