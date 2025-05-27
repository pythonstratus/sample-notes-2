-- Create a custom type for returning multiple statistics
CREATE OR REPLACE TYPE space_stats_type AS OBJECT (
    total_rows NUMBER,
    rows_with_leading_spaces NUMBER,
    rows_with_trailing_spaces NUMBER,
    rows_with_both_spaces NUMBER,
    avg_leading_spaces NUMBER,
    avg_trailing_spaces NUMBER,
    max_leading_spaces NUMBER,
    max_trailing_spaces NUMBER,
    most_common_leading_pattern VARCHAR2(50),
    most_common_trailing_pattern VARCHAR2(50),
    space_pattern_entropy NUMBER,
    anomaly_score NUMBER
);
/

-- Create a table type for the stats (needed for TABLE function)
CREATE OR REPLACE TYPE space_stats_table AS TABLE OF space_stats_type;
/

-- Create a table type for detailed row analysis
CREATE OR REPLACE TYPE space_detail_type AS OBJECT (
    row_id VARCHAR2(100),
    original_value VARCHAR2(4000),
    leading_spaces NUMBER,
    trailing_spaces NUMBER,
    trimmed_length NUMBER,
    space_ratio NUMBER,
    is_anomaly VARCHAR2(1)
);
/

CREATE OR REPLACE TYPE space_detail_table AS TABLE OF space_detail_type;
/

-- Main package for space analysis
CREATE OR REPLACE PACKAGE space_analysis_pkg AS
    
    -- Function to get comprehensive statistics for a column
    FUNCTION get_column_space_stats(
        p_table_name VARCHAR2,
        p_column_name VARCHAR2,
        p_where_clause VARCHAR2 DEFAULT NULL
    ) RETURN space_stats_table PIPELINED;
    
    -- Function to get detailed row-by-row analysis
    FUNCTION get_detailed_space_analysis(
        p_table_name VARCHAR2,
        p_column_name VARCHAR2,
        p_id_column VARCHAR2 DEFAULT 'ROWID',
        p_limit NUMBER DEFAULT 100
    ) RETURN space_detail_table PIPELINED;
    
    -- Function to detect space pattern anomalies using statistical methods
    FUNCTION detect_space_anomalies(
        p_table_name VARCHAR2,
        p_column_name VARCHAR2,
        p_threshold NUMBER DEFAULT 2.5  -- Z-score threshold
    ) RETURN space_detail_table PIPELINED;
    
    -- Function to calculate entropy of space patterns
    FUNCTION calculate_space_entropy(
        p_table_name VARCHAR2,
        p_column_name VARCHAR2
    ) RETURN NUMBER;
    
    -- Function to find clusters of similar space patterns
    FUNCTION find_space_pattern_clusters(
        p_table_name VARCHAR2,
        p_column_name VARCHAR2,
        p_num_clusters NUMBER DEFAULT 5
    ) RETURN SYS_REFCURSOR;
    
END space_analysis_pkg;
/

CREATE OR REPLACE PACKAGE BODY space_analysis_pkg AS

    -- Helper function to count leading spaces
    FUNCTION count_leading_spaces(p_value VARCHAR2) RETURN NUMBER IS
    BEGIN
        IF p_value IS NULL THEN
            RETURN 0;
        END IF;
        RETURN LENGTH(p_value) - LENGTH(LTRIM(p_value));
    END count_leading_spaces;
    
    -- Helper function to count trailing spaces
    FUNCTION count_trailing_spaces(p_value VARCHAR2) RETURN NUMBER IS
    BEGIN
        IF p_value IS NULL THEN
            RETURN 0;
        END IF;
        RETURN LENGTH(p_value) - LENGTH(RTRIM(p_value));
    END count_trailing_spaces;
    
    -- Main statistics function
    FUNCTION get_column_space_stats(
        p_table_name VARCHAR2,
        p_column_name VARCHAR2,
        p_where_clause VARCHAR2 DEFAULT NULL
    ) RETURN space_stats_table PIPELINED IS
        
        v_stats space_stats_type := space_stats_type(0,0,0,0,0,0,0,0,NULL,NULL,0,0);
        v_sql VARCHAR2(4000);
        v_where VARCHAR2(4000) := '';
        
    BEGIN
        -- Add WHERE clause if provided
        IF p_where_clause IS NOT NULL THEN
            v_where := ' WHERE ' || p_where_clause;
        END IF;
        
        -- Get basic counts and averages
        v_sql := 'SELECT 
                    COUNT(*) total_rows,
                    COUNT(CASE WHEN LENGTH(' || p_column_name || ') > LENGTH(LTRIM(' || p_column_name || ')) THEN 1 END) rows_with_leading,
                    COUNT(CASE WHEN LENGTH(' || p_column_name || ') > LENGTH(RTRIM(' || p_column_name || ')) THEN 1 END) rows_with_trailing,
                    COUNT(CASE WHEN LENGTH(' || p_column_name || ') > LENGTH(LTRIM(' || p_column_name || ')) 
                               AND LENGTH(' || p_column_name || ') > LENGTH(RTRIM(' || p_column_name || ')) THEN 1 END) rows_with_both,
                    AVG(LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || '))) avg_leading,
                    AVG(LENGTH(' || p_column_name || ') - LENGTH(RTRIM(' || p_column_name || '))) avg_trailing,
                    MAX(LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || '))) max_leading,
                    MAX(LENGTH(' || p_column_name || ') - LENGTH(RTRIM(' || p_column_name || '))) max_trailing
                  FROM ' || p_table_name || v_where;
        
        EXECUTE IMMEDIATE v_sql INTO 
            v_stats.total_rows,
            v_stats.rows_with_leading_spaces,
            v_stats.rows_with_trailing_spaces,
            v_stats.rows_with_both_spaces,
            v_stats.avg_leading_spaces,
            v_stats.avg_trailing_spaces,
            v_stats.max_leading_spaces,
            v_stats.max_trailing_spaces;
        
        -- Get most common leading space pattern
        v_sql := 'SELECT pattern FROM (
                    SELECT LPAD(''*'', LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')), '' '') || ''spaces'' pattern,
                           COUNT(*) cnt
                    FROM ' || p_table_name || v_where || '
                    WHERE LENGTH(' || p_column_name || ') > LENGTH(LTRIM(' || p_column_name || '))
                    GROUP BY LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || '))
                    ORDER BY cnt DESC
                  ) WHERE ROWNUM = 1';
        
        BEGIN
            EXECUTE IMMEDIATE v_sql INTO v_stats.most_common_leading_pattern;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_stats.most_common_leading_pattern := 'No pattern';
        END;
        
        -- Calculate entropy
        v_stats.space_pattern_entropy := calculate_space_entropy(p_table_name, p_column_name);
        
        -- Calculate anomaly score (simplified - ratio of max to average)
        IF v_stats.avg_leading_spaces > 0 THEN
            v_stats.anomaly_score := v_stats.max_leading_spaces / v_stats.avg_leading_spaces;
        ELSE
            v_stats.anomaly_score := 0;
        END IF;
        
        PIPE ROW(v_stats);
        RETURN;
        
    END get_column_space_stats;
    
    -- Detailed row analysis function
    FUNCTION get_detailed_space_analysis(
        p_table_name VARCHAR2,
        p_column_name VARCHAR2,
        p_id_column VARCHAR2 DEFAULT 'ROWID',
        p_limit NUMBER DEFAULT 100
    ) RETURN space_detail_table PIPELINED IS
        
        TYPE cur_type IS REF CURSOR;
        v_cursor cur_type;
        v_sql VARCHAR2(4000);
        v_detail space_detail_type;
        
    BEGIN
        v_sql := 'SELECT 
                    ' || p_id_column || ' row_id,
                    ' || p_column_name || ' original_value,
                    LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')) leading_spaces,
                    LENGTH(' || p_column_name || ') - LENGTH(RTRIM(' || p_column_name || ')) trailing_spaces,
                    LENGTH(TRIM(' || p_column_name || ')) trimmed_length,
                    CASE 
                        WHEN LENGTH(' || p_column_name || ') = 0 THEN 0
                        ELSE ((LENGTH(' || p_column_name || ') - LENGTH(TRIM(' || p_column_name || '))) / LENGTH(' || p_column_name || ')) * 100
                    END space_ratio,
                    ''N'' is_anomaly
                  FROM ' || p_table_name || '
                  WHERE ' || p_column_name || ' IS NOT NULL
                  AND ROWNUM <= ' || p_limit;
        
        OPEN v_cursor FOR v_sql;
        
        LOOP
            FETCH v_cursor INTO v_detail;
            EXIT WHEN v_cursor%NOTFOUND;
            
            PIPE ROW(v_detail);
        END LOOP;
        
        CLOSE v_cursor;
        RETURN;
        
    END get_detailed_space_analysis;
    
    -- Anomaly detection using Z-score
    FUNCTION detect_space_anomalies(
        p_table_name VARCHAR2,
        p_column_name VARCHAR2,
        p_threshold NUMBER DEFAULT 2.5
    ) RETURN space_detail_table PIPELINED IS
        
        TYPE cur_type IS REF CURSOR;
        v_cursor cur_type;
        v_sql VARCHAR2(4000);
        v_detail space_detail_type;
        v_avg_spaces NUMBER;
        v_stddev_spaces NUMBER;
        
    BEGIN
        -- Calculate mean and standard deviation
        v_sql := 'SELECT 
                    AVG(LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || '))),
                    STDDEV(LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')))
                  FROM ' || p_table_name || '
                  WHERE ' || p_column_name || ' IS NOT NULL';
        
        EXECUTE IMMEDIATE v_sql INTO v_avg_spaces, v_stddev_spaces;
        
        -- Find anomalies using Z-score
        v_sql := 'SELECT 
                    ROWIDTOCHAR(ROWID) row_id,
                    ' || p_column_name || ' original_value,
                    LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')) leading_spaces,
                    LENGTH(' || p_column_name || ') - LENGTH(RTRIM(' || p_column_name || ')) trailing_spaces,
                    LENGTH(TRIM(' || p_column_name || ')) trimmed_length,
                    CASE 
                        WHEN LENGTH(' || p_column_name || ') = 0 THEN 0
                        ELSE ((LENGTH(' || p_column_name || ') - LENGTH(TRIM(' || p_column_name || '))) / LENGTH(' || p_column_name || ')) * 100
                    END space_ratio,
                    ''Y'' is_anomaly
                  FROM ' || p_table_name || '
                  WHERE ' || p_column_name || ' IS NOT NULL
                  AND ABS((LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')) - ' || v_avg_spaces || ') / NULLIF(' || v_stddev_spaces || ', 0)) > ' || p_threshold;
        
        OPEN v_cursor FOR v_sql;
        
        LOOP
            FETCH v_cursor INTO v_detail;
            EXIT WHEN v_cursor%NOTFOUND;
            
            PIPE ROW(v_detail);
        END LOOP;
        
        CLOSE v_cursor;
        RETURN;
        
    END detect_space_anomalies;
    
    -- Calculate entropy of space patterns
    FUNCTION calculate_space_entropy(
        p_table_name VARCHAR2,
        p_column_name VARCHAR2
    ) RETURN NUMBER IS
        
        v_entropy NUMBER := 0;
        v_total NUMBER;
        v_sql VARCHAR2(4000);
        
        TYPE pattern_rec IS RECORD (
            pattern_count NUMBER,
            total_count NUMBER
        );
        TYPE pattern_cur IS REF CURSOR;
        v_cursor pattern_cur;
        v_rec pattern_rec;
        
    BEGIN
        -- Get total count
        v_sql := 'SELECT COUNT(*) FROM ' || p_table_name || ' WHERE ' || p_column_name || ' IS NOT NULL';
        EXECUTE IMMEDIATE v_sql INTO v_total;
        
        IF v_total = 0 THEN
            RETURN 0;
        END IF;
        
        -- Calculate entropy based on space pattern distribution
        v_sql := 'SELECT COUNT(*) pattern_count, ' || v_total || ' total_count
                  FROM ' || p_table_name || '
                  WHERE ' || p_column_name || ' IS NOT NULL
                  GROUP BY LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || '))';
        
        OPEN v_cursor FOR v_sql;
        
        LOOP
            FETCH v_cursor INTO v_rec;
            EXIT WHEN v_cursor%NOTFOUND;
            
            IF v_rec.pattern_count > 0 THEN
                v_entropy := v_entropy - (v_rec.pattern_count / v_rec.total_count) * 
                            LOG(2, v_rec.pattern_count / v_rec.total_count);
            END IF;
        END LOOP;
        
        CLOSE v_cursor;
        
        RETURN v_entropy;
        
    END calculate_space_entropy;
    
    -- Find space pattern clusters using K-means-like approach
    FUNCTION find_space_pattern_clusters(
        p_table_name VARCHAR2,
        p_column_name VARCHAR2,
        p_num_clusters NUMBER DEFAULT 5
    ) RETURN SYS_REFCURSOR IS
        
        v_cursor SYS_REFCURSOR;
        v_sql VARCHAR2(4000);
        
    BEGIN
        -- Group by space patterns and assign clusters
        v_sql := 'WITH space_patterns AS (
                    SELECT 
                        LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')) leading_spaces,
                        LENGTH(' || p_column_name || ') - LENGTH(RTRIM(' || p_column_name || ')) trailing_spaces,
                        COUNT(*) pattern_count
                    FROM ' || p_table_name || '
                    WHERE ' || p_column_name || ' IS NOT NULL
                    GROUP BY 
                        LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')),
                        LENGTH(' || p_column_name || ') - LENGTH(RTRIM(' || p_column_name || '))
                  ),
                  ranked_patterns AS (
                    SELECT 
                        leading_spaces,
                        trailing_spaces,
                        pattern_count,
                        NTILE(' || p_num_clusters || ') OVER (ORDER BY leading_spaces + trailing_spaces) cluster_id
                    FROM space_patterns
                  )
                  SELECT 
                    cluster_id,
                    MIN(leading_spaces) min_leading,
                    MAX(leading_spaces) max_leading,
                    AVG(leading_spaces) avg_leading,
                    MIN(trailing_spaces) min_trailing,
                    MAX(trailing_spaces) max_trailing,
                    AVG(trailing_spaces) avg_trailing,
                    SUM(pattern_count) total_rows
                  FROM ranked_patterns
                  GROUP BY cluster_id
                  ORDER BY cluster_id';
        
        OPEN v_cursor FOR v_sql;
        RETURN v_cursor;
        
    END find_space_pattern_clusters;
    
END space_analysis_pkg;
/

-- Example usage functions

-- 1. Get comprehensive statistics for a column
CREATE OR REPLACE FUNCTION analyze_column_spaces(
    p_table_name VARCHAR2,
    p_column_name VARCHAR2
) RETURN VARCHAR2 IS
    v_stats space_stats_type;
    v_result VARCHAR2(4000);
BEGIN
    v_stats := space_analysis_pkg.get_column_space_stats(p_table_name, p_column_name);
    
    v_result := 'Space Analysis Results for ' || p_table_name || '.' || p_column_name || CHR(10) ||
                '======================================' || CHR(10) ||
                'Total Rows: ' || v_stats.total_rows || CHR(10) ||
                'Rows with Leading Spaces: ' || v_stats.rows_with_leading_spaces || 
                ' (' || ROUND(v_stats.rows_with_leading_spaces / v_stats.total_rows * 100, 2) || '%)' || CHR(10) ||
                'Rows with Trailing Spaces: ' || v_stats.rows_with_trailing_spaces || 
                ' (' || ROUND(v_stats.rows_with_trailing_spaces / v_stats.total_rows * 100, 2) || '%)' || CHR(10) ||
                'Average Leading Spaces: ' || ROUND(v_stats.avg_leading_spaces, 2) || CHR(10) ||
                'Maximum Leading Spaces: ' || v_stats.max_leading_spaces || CHR(10) ||
                'Space Pattern Entropy: ' || ROUND(v_stats.space_pattern_entropy, 4) || CHR(10) ||
                'Anomaly Score: ' || ROUND(v_stats.anomaly_score, 2);
    
    RETURN v_result;
END;
/

-- 2. Create a view for easy anomaly detection
CREATE OR REPLACE VIEW space_anomalies_view AS
SELECT 
    table_name,
    column_name,
    row_id,
    original_value,
    leading_spaces,
    trailing_spaces,
    space_ratio,
    CASE 
        WHEN space_ratio > 50 THEN 'High'
        WHEN space_ratio > 20 THEN 'Medium'
        ELSE 'Low'
    END space_severity
FROM (
    SELECT 
        'YOUR_TABLE' table_name,
        'YOUR_COLUMN' column_name,
        t.*
    FROM TABLE(space_analysis_pkg.detect_space_anomalies('YOUR_TABLE', 'YOUR_COLUMN')) t
);

-- Example queries to use the functions:

/*
-- Get basic statistics
SELECT * FROM TABLE(
    space_analysis_pkg.get_column_space_stats('EMPLOYEES', 'FIRST_NAME')
);

-- Get detailed analysis for first 50 rows
SELECT * FROM TABLE(
    space_analysis_pkg.get_detailed_space_analysis('EMPLOYEES', 'FIRST_NAME', 'EMPLOYEE_ID', 50)
);

-- Find anomalies
SELECT * FROM TABLE(
    space_analysis_pkg.detect_space_anomalies('EMPLOYEES', 'FIRST_NAME', 2.0)
);

-- Get space pattern clusters
DECLARE
    v_cursor SYS_REFCURSOR;
    v_cluster_id NUMBER;
    v_min_leading NUMBER;
    v_max_leading NUMBER;
    v_avg_leading NUMBER;
    v_min_trailing NUMBER;
    v_max_trailing NUMBER;
    v_avg_trailing NUMBER;
    v_total_rows NUMBER;
BEGIN
    v_cursor := space_analysis_pkg.find_space_pattern_clusters('EMPLOYEES', 'FIRST_NAME', 3);
    
    DBMS_OUTPUT.PUT_LINE('Cluster Analysis Results:');
    DBMS_OUTPUT.PUT_LINE('========================');
    
    LOOP
        FETCH v_cursor INTO v_cluster_id, v_min_leading, v_max_leading, v_avg_leading,
                           v_min_trailing, v_max_trailing, v_avg_trailing, v_total_rows;
        EXIT WHEN v_cursor%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE('Cluster ' || v_cluster_id || ': ' || v_total_rows || ' rows');
        DBMS_OUTPUT.PUT_LINE('  Leading spaces: ' || v_min_leading || '-' || v_max_leading || ' (avg: ' || ROUND(v_avg_leading, 2) || ')');
        DBMS_OUTPUT.PUT_LINE('  Trailing spaces: ' || v_min_trailing || '-' || v_max_trailing || ' (avg: ' || ROUND(v_avg_trailing, 2) || ')');
    END LOOP;
    
    CLOSE v_cursor;
END;
/

-- Simple usage example
SELECT analyze_column_spaces('EMPLOYEES', 'FIRST_NAME') FROM DUAL;
*/
