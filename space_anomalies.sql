-- Simple function to analyze column spaces without complex types
CREATE OR REPLACE FUNCTION analyze_column_spaces(
    p_table_name VARCHAR2,
    p_column_name VARCHAR2
) RETURN VARCHAR2 IS
    v_total_rows NUMBER;
    v_rows_with_leading NUMBER;
    v_rows_with_trailing NUMBER;
    v_avg_leading NUMBER;
    v_max_leading NUMBER;
    v_avg_trailing NUMBER;
    v_max_trailing NUMBER;
    v_result VARCHAR2(4000);
    v_sql VARCHAR2(4000);
BEGIN
    -- Get statistics using dynamic SQL
    v_sql := 'SELECT 
                COUNT(*) total_rows,
                COUNT(CASE WHEN LENGTH(' || p_column_name || ') > LENGTH(LTRIM(' || p_column_name || ')) THEN 1 END) rows_with_leading,
                COUNT(CASE WHEN LENGTH(' || p_column_name || ') > LENGTH(RTRIM(' || p_column_name || ')) THEN 1 END) rows_with_trailing,
                AVG(LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || '))) avg_leading,
                MAX(LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || '))) max_leading,
                AVG(LENGTH(' || p_column_name || ') - LENGTH(RTRIM(' || p_column_name || '))) avg_trailing,
                MAX(LENGTH(' || p_column_name || ') - LENGTH(RTRIM(' || p_column_name || '))) max_trailing
              FROM ' || p_table_name || '
              WHERE ' || p_column_name || ' IS NOT NULL';
    
    EXECUTE IMMEDIATE v_sql INTO 
        v_total_rows, v_rows_with_leading, v_rows_with_trailing,
        v_avg_leading, v_max_leading, v_avg_trailing, v_max_trailing;
    
    -- Build result string
    v_result := 'Space Analysis for ' || p_table_name || '.' || p_column_name || CHR(10) ||
                '=====================================' || CHR(10) ||
                'Total Rows: ' || v_total_rows || CHR(10) ||
                'Rows with Leading Spaces: ' || v_rows_with_leading || 
                ' (' || ROUND(v_rows_with_leading / v_total_rows * 100, 2) || '%)' || CHR(10) ||
                'Rows with Trailing Spaces: ' || v_rows_with_trailing || 
                ' (' || ROUND(v_rows_with_trailing / v_total_rows * 100, 2) || '%)' || CHR(10) ||
                'Average Leading Spaces: ' || ROUND(v_avg_leading, 2) || CHR(10) ||
                'Maximum Leading Spaces: ' || v_max_leading || CHR(10) ||
                'Average Trailing Spaces: ' || ROUND(v_avg_trailing, 2) || CHR(10) ||
                'Maximum Trailing Spaces: ' || v_max_trailing;
    
    RETURN v_result;
END analyze_column_spaces;
/

-- Create a view for easy anomaly detection
CREATE OR REPLACE VIEW space_anomalies_view AS
WITH space_analysis AS (
    SELECT 
        'YOUR_TABLE_NAME' as table_name,  -- Replace with your table
        'YOUR_COLUMN_NAME' as column_name, -- Replace with your column
        ROWID as row_id,
        YOUR_COLUMN_NAME as original_value,  -- Replace with your column
        LENGTH(YOUR_COLUMN_NAME) - LENGTH(LTRIM(YOUR_COLUMN_NAME)) as leading_spaces,
        LENGTH(YOUR_COLUMN_NAME) - LENGTH(RTRIM(YOUR_COLUMN_NAME)) as trailing_spaces,
        LENGTH(TRIM(YOUR_COLUMN_NAME)) as trimmed_length,
        CASE 
            WHEN LENGTH(YOUR_COLUMN_NAME) = 0 THEN 0
            ELSE ((LENGTH(YOUR_COLUMN_NAME) - LENGTH(TRIM(YOUR_COLUMN_NAME))) / LENGTH(YOUR_COLUMN_NAME)) * 100
        END as space_ratio
    FROM YOUR_TABLE_NAME  -- Replace with your table
    WHERE YOUR_COLUMN_NAME IS NOT NULL
),
stats AS (
    SELECT 
        AVG(leading_spaces) as avg_leading,
        STDDEV(leading_spaces) as stddev_leading
    FROM space_analysis
)
SELECT 
    sa.*,
    CASE 
        WHEN ABS(sa.leading_spaces - s.avg_leading) > 2.5 * s.stddev_leading THEN 'Y'
        ELSE 'N'
    END as is_anomaly,
    CASE 
        WHEN sa.space_ratio > 50 THEN 'High'
        WHEN sa.space_ratio > 20 THEN 'Medium'
        ELSE 'Low'
    END as space_severity
FROM space_analysis sa, stats s;

-- Simple procedure to show space patterns
CREATE OR REPLACE PROCEDURE show_space_patterns(
    p_table_name VARCHAR2,
    p_column_name VARCHAR2,
    p_top_n NUMBER DEFAULT 10
) IS
    v_sql VARCHAR2(4000);
    v_spaces NUMBER;
    v_count NUMBER;
    v_percentage NUMBER;
    v_total NUMBER;
BEGIN
    -- Get total count
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_table_name || ' WHERE ' || p_column_name || ' IS NOT NULL' 
    INTO v_total;
    
    DBMS_OUTPUT.PUT_LINE('Space Pattern Analysis for ' || p_table_name || '.' || p_column_name);
    DBMS_OUTPUT.PUT_LINE('=========================================');
    DBMS_OUTPUT.PUT_LINE('Total rows: ' || v_total);
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Leading Space Patterns:');
    DBMS_OUTPUT.PUT_LINE('Spaces | Count | Percentage');
    DBMS_OUTPUT.PUT_LINE('-------|-------|------------');
    
    -- Create dynamic SQL for pattern analysis
    v_sql := 'SELECT leading_spaces, COUNT(*) cnt
              FROM (
                SELECT LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')) as leading_spaces
                FROM ' || p_table_name || '
                WHERE ' || p_column_name || ' IS NOT NULL
              )
              GROUP BY leading_spaces
              ORDER BY cnt DESC';
    
    -- Use cursor to fetch results
    DECLARE
        TYPE t_cursor IS REF CURSOR;
        c_patterns t_cursor;
        v_row_count NUMBER := 0;
    BEGIN
        OPEN c_patterns FOR v_sql;
        LOOP
            FETCH c_patterns INTO v_spaces, v_count;
            EXIT WHEN c_patterns%NOTFOUND OR v_row_count >= p_top_n;
            
            v_percentage := ROUND(v_count / v_total * 100, 2);
            DBMS_OUTPUT.PUT_LINE(LPAD(v_spaces, 6) || ' | ' || 
                                LPAD(v_count, 5) || ' | ' || 
                                LPAD(v_percentage, 10) || '%');
            v_row_count := v_row_count + 1;
        END LOOP;
        CLOSE c_patterns;
    END;
END show_space_patterns;
/

-- Function to detect anomalies (returns cursor)
CREATE OR REPLACE FUNCTION find_space_anomalies(
    p_table_name VARCHAR2,
    p_column_name VARCHAR2,
    p_id_column VARCHAR2 DEFAULT 'ROWID',
    p_threshold NUMBER DEFAULT 2.5
) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
    v_sql VARCHAR2(4000);
    v_avg_spaces NUMBER;
    v_stddev_spaces NUMBER;
BEGIN
    -- Calculate statistics
    v_sql := 'SELECT 
                AVG(LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || '))),
                STDDEV(LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')))
              FROM ' || p_table_name || '
              WHERE ' || p_column_name || ' IS NOT NULL';
    
    EXECUTE IMMEDIATE v_sql INTO v_avg_spaces, v_stddev_spaces;
    
    -- Open cursor for anomalies
    v_sql := 'SELECT 
                ' || p_id_column || ' as row_id,
                ' || p_column_name || ' as original_value,
                LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')) as leading_spaces,
                LENGTH(' || p_column_name || ') - LENGTH(RTRIM(' || p_column_name || ')) as trailing_spaces,
                ABS((LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')) - ' || v_avg_spaces || ') / NULLIF(' || v_stddev_spaces || ', 0)) as z_score
              FROM ' || p_table_name || '
              WHERE ' || p_column_name || ' IS NOT NULL
              AND ABS((LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')) - ' || v_avg_spaces || ') / NULLIF(' || v_stddev_spaces || ', 0)) > ' || p_threshold || '
              ORDER BY 5 DESC';
    
    OPEN v_cursor FOR v_sql;
    RETURN v_cursor;
END find_space_anomalies;
/

-- Usage Examples:

-- 1. Get basic analysis (this will work)
SELECT analyze_column_spaces('EMPLOYEES', 'FIRST_NAME') FROM DUAL;

-- 2. Show space patterns (enable DBMS_OUTPUT first)
BEGIN
    DBMS_OUTPUT.ENABLE(1000000);
    show_space_patterns('EMPLOYEES', 'FIRST_NAME', 5);
END;
/

-- 3. Find anomalies using cursor
DECLARE
    v_cursor SYS_REFCURSOR;
    v_row_id VARCHAR2(100);
    v_value VARCHAR2(4000);
    v_leading NUMBER;
    v_trailing NUMBER;
    v_z_score NUMBER;
BEGIN
    v_cursor := find_space_anomalies('EMPLOYEES', 'FIRST_NAME', 'EMPLOYEE_ID');
    
    DBMS_OUTPUT.PUT_LINE('Space Anomalies Found:');
    DBMS_OUTPUT.PUT_LINE('======================');
    
    LOOP
        FETCH v_cursor INTO v_row_id, v_value, v_leading, v_trailing, v_z_score;
        EXIT WHEN v_cursor%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE('ID: ' || v_row_id || 
                           ' | Value: "' || v_value || '"' ||
                           ' | Leading: ' || v_leading || 
                           ' | Z-Score: ' || ROUND(v_z_score, 2));
    END LOOP;
    
    CLOSE v_cursor;
END;
/

-- 4. Create a simple summary table
CREATE OR REPLACE VIEW space_summary_view AS
SELECT 
    'EMPLOYEES' as table_name,
    'FIRST_NAME' as column_name,
    COUNT(*) as total_rows,
    COUNT(CASE WHEN LENGTH(FIRST_NAME) > LENGTH(LTRIM(FIRST_NAME)) THEN 1 END) as rows_with_leading,
    COUNT(CASE WHEN LENGTH(FIRST_NAME) > LENGTH(RTRIM(FIRST_NAME)) THEN 1 END) as rows_with_trailing,
    MIN(LENGTH(FIRST_NAME) - LENGTH(LTRIM(FIRST_NAME))) as min_leading_spaces,
    MAX(LENGTH(FIRST_NAME) - LENGTH(LTRIM(FIRST_NAME))) as max_leading_spaces,
    ROUND(AVG(LENGTH(FIRST_NAME) - LENGTH(LTRIM(FIRST_NAME))), 2) as avg_leading_spaces,
    MIN(LENGTH(FIRST_NAME) - LENGTH(RTRIM(FIRST_NAME))) as min_trailing_spaces,
    MAX(LENGTH(FIRST_NAME) - LENGTH(RTRIM(FIRST_NAME))) as max_trailing_spaces,
    ROUND(AVG(LENGTH(FIRST_NAME) - LENGTH(RTRIM(FIRST_NAME))), 2) as avg_trailing_spaces
FROM EMPLOYEES
WHERE FIRST_NAME IS NOT NULL;
