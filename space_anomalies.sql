-- ============================================
-- ORACLE FUNCTIONS FOR SPACE ANALYSIS
-- ============================================

-- 1. BASIC SPACE ANALYSIS FUNCTION
CREATE OR REPLACE FUNCTION analyze_spaces(
    p_text VARCHAR2
) RETURN VARCHAR2
IS
    v_original_length NUMBER;
    v_trimmed_length NUMBER;
    v_leading_spaces NUMBER;
    v_trailing_spaces NUMBER;
    v_total_spaces NUMBER;
    v_result VARCHAR2(4000);
BEGIN
    v_original_length := LENGTH(p_text);
    v_trimmed_length := LENGTH(TRIM(p_text));
    
    -- Calculate leading spaces
    v_leading_spaces := LENGTH(p_text) - LENGTH(LTRIM(p_text));
    
    -- Calculate trailing spaces
    v_trailing_spaces := LENGTH(p_text) - LENGTH(RTRIM(p_text));
    
    -- Total spaces
    v_total_spaces := v_leading_spaces + v_trailing_spaces;
    
    v_result := 'Original_Length:' || v_original_length ||
                '|Trimmed_Length:' || v_trimmed_length ||
                '|Leading_Spaces:' || v_leading_spaces ||
                '|Trailing_Spaces:' || v_trailing_spaces ||
                '|Total_Spaces:' || v_total_spaces;
    
    RETURN v_result;
END analyze_spaces;
/

-- 2. ADVANCED STATISTICS TYPE
CREATE OR REPLACE TYPE space_stats_type AS OBJECT (
    column_name VARCHAR2(128),
    total_rows NUMBER,
    rows_with_leading_spaces NUMBER,
    rows_with_trailing_spaces NUMBER,
    avg_leading_spaces NUMBER,
    avg_trailing_spaces NUMBER,
    max_leading_spaces NUMBER,
    max_trailing_spaces NUMBER,
    std_dev_leading NUMBER,
    std_dev_trailing NUMBER,
    z_score_threshold_rows NUMBER,
    entropy_value NUMBER
);
/

-- 3. TABLE TYPE FOR RETURNING MULTIPLE STATS
CREATE OR REPLACE TYPE space_stats_table AS TABLE OF space_stats_type;
/

-- 4. COMPREHENSIVE SPACE STATISTICS FUNCTION
CREATE OR REPLACE FUNCTION get_space_statistics(
    p_table_name VARCHAR2,
    p_column_name VARCHAR2,
    p_z_score_threshold NUMBER DEFAULT 2
) RETURN space_stats_table PIPELINED
IS
    v_sql VARCHAR2(4000);
    v_stats space_stats_type;
    v_cursor SYS_REFCURSOR;
    
    -- Variables for entropy calculation
    v_entropy NUMBER := 0;
    v_probability NUMBER;
    v_space_count NUMBER;
    v_total_chars NUMBER;
BEGIN
    -- Main statistics query
    v_sql := '
    WITH space_analysis AS (
        SELECT 
            LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')) AS leading_spaces,
            LENGTH(' || p_column_name || ') - LENGTH(RTRIM(' || p_column_name || ')) AS trailing_spaces,
            LENGTH(' || p_column_name || ') AS total_length
        FROM ' || p_table_name || '
        WHERE ' || p_column_name || ' IS NOT NULL
    ),
    stats AS (
        SELECT 
            COUNT(*) AS total_rows,
            SUM(CASE WHEN leading_spaces > 0 THEN 1 ELSE 0 END) AS rows_with_leading,
            SUM(CASE WHEN trailing_spaces > 0 THEN 1 ELSE 0 END) AS rows_with_trailing,
            AVG(leading_spaces) AS avg_leading,
            AVG(trailing_spaces) AS avg_trailing,
            MAX(leading_spaces) AS max_leading,
            MAX(trailing_spaces) AS max_trailing,
            STDDEV(leading_spaces) AS std_dev_leading,
            STDDEV(trailing_spaces) AS std_dev_trailing
        FROM space_analysis
    ),
    z_scores AS (
        SELECT 
            COUNT(*) AS z_score_outliers
        FROM space_analysis, stats
        WHERE ABS(leading_spaces - stats.avg_leading) / NULLIF(stats.std_dev_leading, 0) > ' || p_z_score_threshold || '
           OR ABS(trailing_spaces - stats.avg_trailing) / NULLIF(stats.std_dev_trailing, 0) > ' || p_z_score_threshold || '
    )
    SELECT 
        s.total_rows,
        s.rows_with_leading,
        s.rows_with_trailing,
        s.avg_leading,
        s.avg_trailing,
        s.max_leading,
        s.max_trailing,
        s.std_dev_leading,
        s.std_dev_trailing,
        z.z_score_outliers
    FROM stats s, z_scores z';
    
    OPEN v_cursor FOR v_sql;
    FETCH v_cursor INTO 
        v_stats.total_rows,
        v_stats.rows_with_leading_spaces,
        v_stats.rows_with_trailing_spaces,
        v_stats.avg_leading_spaces,
        v_stats.avg_trailing_spaces,
        v_stats.max_leading_spaces,
        v_stats.max_trailing_spaces,
        v_stats.std_dev_leading,
        v_stats.std_dev_trailing,
        v_stats.z_score_threshold_rows;
    CLOSE v_cursor;
    
    -- Calculate entropy for space distribution
    v_sql := '
    SELECT 
        SUM(space_count) AS total_chars,
        SUM(-1 * (space_count/total_chars) * LN(space_count/total_chars) / LN(2)) AS entropy
    FROM (
        SELECT 
            COUNT(*) AS space_count,
            SUM(COUNT(*)) OVER () AS total_chars
        FROM (
            SELECT 
                LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')) AS leading_spaces
            FROM ' || p_table_name || '
            WHERE ' || p_column_name || ' IS NOT NULL
        )
        GROUP BY leading_spaces
    )
    WHERE space_count > 0';
    
    BEGIN
        EXECUTE IMMEDIATE v_sql INTO v_total_chars, v_entropy;
        v_stats.entropy_value := NVL(v_entropy, 0);
    EXCEPTION
        WHEN OTHERS THEN
            v_stats.entropy_value := 0;
    END;
    
    v_stats.column_name := p_column_name;
    
    PIPE ROW(v_stats);
    RETURN;
END get_space_statistics;
/

-- 5. Z-SCORE CALCULATION FUNCTION
CREATE OR REPLACE FUNCTION calculate_z_score(
    p_value NUMBER,
    p_mean NUMBER,
    p_std_dev NUMBER
) RETURN NUMBER
IS
BEGIN
    IF p_std_dev = 0 OR p_std_dev IS NULL THEN
        RETURN 0;
    END IF;
    
    RETURN (p_value - p_mean) / p_std_dev;
END calculate_z_score;
/

-- 6. ENTROPY CALCULATION FUNCTION
CREATE OR REPLACE FUNCTION calculate_entropy(
    p_table_name VARCHAR2,
    p_column_name VARCHAR2,
    p_analyze_type VARCHAR2 DEFAULT 'LEADING' -- 'LEADING', 'TRAILING', 'BOTH'
) RETURN NUMBER
IS
    v_entropy NUMBER := 0;
    v_sql VARCHAR2(4000);
BEGIN
    IF p_analyze_type = 'LEADING' THEN
        v_sql := '
        SELECT 
            SUM(-1 * probability * LN(probability) / LN(2))
        FROM (
            SELECT 
                COUNT(*) / SUM(COUNT(*)) OVER () AS probability
            FROM (
                SELECT 
                    LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || ')) AS space_count
                FROM ' || p_table_name || '
                WHERE ' || p_column_name || ' IS NOT NULL
            )
            GROUP BY space_count
        )
        WHERE probability > 0';
    ELSIF p_analyze_type = 'TRAILING' THEN
        v_sql := '
        SELECT 
            SUM(-1 * probability * LN(probability) / LN(2))
        FROM (
            SELECT 
                COUNT(*) / SUM(COUNT(*)) OVER () AS probability
            FROM (
                SELECT 
                    LENGTH(' || p_column_name || ') - LENGTH(RTRIM(' || p_column_name || ')) AS space_count
                FROM ' || p_table_name || '
                WHERE ' || p_column_name || ' IS NOT NULL
            )
            GROUP BY space_count
        )
        WHERE probability > 0';
    ELSE -- BOTH
        v_sql := '
        SELECT 
            SUM(-1 * probability * LN(probability) / LN(2))
        FROM (
            SELECT 
                COUNT(*) / SUM(COUNT(*)) OVER () AS probability
            FROM (
                SELECT 
                    (LENGTH(' || p_column_name || ') - LENGTH(LTRIM(' || p_column_name || '))) +
                    (LENGTH(' || p_column_name || ') - LENGTH(RTRIM(' || p_column_name || '))) AS space_count
                FROM ' || p_table_name || '
                WHERE ' || p_column_name || ' IS NOT NULL
            )
            GROUP BY space_count
        )
        WHERE probability > 0';
    END IF;
    
    EXECUTE IMMEDIATE v_sql INTO v_entropy;
    
    RETURN NVL(v_entropy, 0);
END calculate_entropy;
/

-- ============================================
-- TESTING QUERIES
-- ============================================

-- Test 1: Basic space analysis for a single column
SELECT 
    column_value,
    analyze_spaces(column_value) AS space_analysis
FROM TABLE(
    -- Sample data with various space patterns
    SYS.ODCIVARCHAR2LIST(
        '  Leading spaces',
        'Trailing spaces  ',
        '  Both sides  ',
        'No spaces',
        '    Many leading',
        'Many trailing    '
    )
);

-- Test 2: Comprehensive statistics for a table column
-- Replace 'YOUR_TABLE' and 'YOUR_COLUMN' with actual names
SELECT * FROM TABLE(get_space_statistics('YOUR_TABLE', 'YOUR_COLUMN', 2));

-- Test 3: Z-Score analysis for identifying outliers
WITH space_data AS (
    SELECT 
        YOUR_COLUMN,
        LENGTH(YOUR_COLUMN) - LENGTH(LTRIM(YOUR_COLUMN)) AS leading_spaces,
        LENGTH(YOUR_COLUMN) - LENGTH(RTRIM(YOUR_COLUMN)) AS trailing_spaces
    FROM YOUR_TABLE
    WHERE YOUR_COLUMN IS NOT NULL
),
stats AS (
    SELECT 
        AVG(leading_spaces) AS avg_leading,
        STDDEV(leading_spaces) AS std_leading,
        AVG(trailing_spaces) AS avg_trailing,
        STDDEV(trailing_spaces) AS std_trailing
    FROM space_data
)
SELECT 
    sd.YOUR_COLUMN,
    sd.leading_spaces,
    sd.trailing_spaces,
    calculate_z_score(sd.leading_spaces, s.avg_leading, s.std_leading) AS z_score_leading,
    calculate_z_score(sd.trailing_spaces, s.avg_trailing, s.std_trailing) AS z_score_trailing,
    CASE 
        WHEN ABS(calculate_z_score(sd.leading_spaces, s.avg_leading, s.std_leading)) > 2 THEN 'Outlier'
        ELSE 'Normal'
    END AS leading_status,
    CASE 
        WHEN ABS(calculate_z_score(sd.trailing_spaces, s.avg_trailing, s.std_trailing)) > 2 THEN 'Outlier'
        ELSE 'Normal'
    END AS trailing_status
FROM space_data sd, stats s
ORDER BY ABS(calculate_z_score(sd.leading_spaces, s.avg_leading, s.std_leading)) DESC;

-- Test 4: Entropy calculation for different space types
SELECT 
    'Leading Spaces' AS analysis_type,
    calculate_entropy('YOUR_TABLE', 'YOUR_COLUMN', 'LEADING') AS entropy_value
FROM DUAL
UNION ALL
SELECT 
    'Trailing Spaces' AS analysis_type,
    calculate_entropy('YOUR_TABLE', 'YOUR_COLUMN', 'TRAILING') AS entropy_value
FROM DUAL
UNION ALL
SELECT 
    'Total Spaces' AS analysis_type,
    calculate_entropy('YOUR_TABLE', 'YOUR_COLUMN', 'BOTH') AS entropy_value
FROM DUAL;

-- Test 5: Distribution analysis
WITH space_distribution AS (
    SELECT 
        LENGTH(YOUR_COLUMN) - LENGTH(LTRIM(YOUR_COLUMN)) AS space_count,
        COUNT(*) AS frequency,
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS percentage
    FROM YOUR_TABLE
    WHERE YOUR_COLUMN IS NOT NULL
    GROUP BY LENGTH(YOUR_COLUMN) - LENGTH(LTRIM(YOUR_COLUMN))
)
SELECT 
    space_count AS leading_spaces,
    frequency,
    ROUND(percentage, 2) AS percentage,
    RPAD('*', LEAST(50, ROUND(percentage)), '*') AS histogram
FROM space_distribution
ORDER BY space_count;

-- Test 6: Pattern detection query
SELECT 
    pattern_type,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM (
    SELECT 
        CASE 
            WHEN LENGTH(YOUR_COLUMN) - LENGTH(LTRIM(YOUR_COLUMN)) > 0 
                 AND LENGTH(YOUR_COLUMN) - LENGTH(RTRIM(YOUR_COLUMN)) > 0 THEN 'Both Sides'
            WHEN LENGTH(YOUR_COLUMN) - LENGTH(LTRIM(YOUR_COLUMN)) > 0 THEN 'Leading Only'
            WHEN LENGTH(YOUR_COLUMN) - LENGTH(RTRIM(YOUR_COLUMN)) > 0 THEN 'Trailing Only'
            ELSE 'No Extra Spaces'
        END AS pattern_type
    FROM YOUR_TABLE
    WHERE YOUR_COLUMN IS NOT NULL
)
GROUP BY pattern_type
ORDER BY count DESC;

-- Test 7: Advanced metrics summary
SELECT 
    'Space Analysis Summary' AS report_type,
    (SELECT COUNT(*) FROM YOUR_TABLE WHERE YOUR_COLUMN IS NOT NULL) AS total_records,
    (SELECT COUNT(*) FROM YOUR_TABLE 
     WHERE LENGTH(YOUR_COLUMN) - LENGTH(LTRIM(YOUR_COLUMN)) > 0) AS records_with_leading_spaces,
    (SELECT COUNT(*) FROM YOUR_TABLE 
     WHERE LENGTH(YOUR_COLUMN) - LENGTH(RTRIM(YOUR_COLUMN)) > 0) AS records_with_trailing_spaces,
    ROUND((SELECT AVG(LENGTH(YOUR_COLUMN) - LENGTH(LTRIM(YOUR_COLUMN))) 
           FROM YOUR_TABLE WHERE YOUR_COLUMN IS NOT NULL), 2) AS avg_leading_spaces,
    ROUND((SELECT STDDEV(LENGTH(YOUR_COLUMN) - LENGTH(LTRIM(YOUR_COLUMN))) 
           FROM YOUR_TABLE WHERE YOUR_COLUMN IS NOT NULL), 2) AS stddev_leading_spaces,
    calculate_entropy('YOUR_TABLE', 'YOUR_COLUMN', 'LEADING') AS entropy_leading,
    calculate_entropy('YOUR_TABLE', 'YOUR_COLUMN', 'TRAILING') AS entropy_trailing
FROM DUAL;
