#!/bin/bash

# Sanity Org Multi-Report Merger
# Usage: ./merge_sanity_org.sh <output_name> <file1> <file2> [file3] [file4] ...

if [ $# -lt 3 ]; then
    echo "Usage: $0 <output_name> <csv_file1> <csv_file2> [csv_file3] ..."
    echo "Example: $0 weekly_trend dev_monday.csv dev_tuesday.csv dev_wednesday.csv"
    exit 1
fi

OUTPUT_NAME=$1
shift
FILES=("$@")

# Create output directory
OUTPUT_DIR="/tmp/sanity_org_merged"
mkdir -p $OUTPUT_DIR

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MERGED_FILE="${OUTPUT_DIR}/${OUTPUT_NAME}_merged_${TIMESTAMP}.csv"
TREND_FILE="${OUTPUT_DIR}/${OUTPUT_NAME}_trends_${TIMESTAMP}.csv"

echo "Merging sanity org reports..."
echo "Output: $MERGED_FILE"
echo "Files to merge: ${#FILES[@]}"
for file in "${FILES[@]}"; do
    echo "  - $file"
done
echo ""

# Create merged file header
echo "Report_Section,Organization,Status_Item,Count,Server_Type,Timestamp,Source_File" > $MERGED_FILE

# Merge all files
file_counter=1
for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Warning: File not found: $file"
        continue
    fi
    
    # Add source file identifier and merge (skip header)
    tail -n +2 "$file" | while read line; do
        if [[ $line != SERVER_INFO* ]]; then
            echo "${line},File_${file_counter}" >> $MERGED_FILE
        fi
    done
    
    ((file_counter++))
done

echo "Files merged successfully."

# Create trend analysis
echo "Creating trend analysis..."
echo "Report_Section,Organization,Status_Item,File1_Count,File2_Count,File3_Count,File4_Count,Trend" > $TREND_FILE

# Generate trend analysis using awk
awk -F',' '
BEGIN { OFS = "," }
NR == 1 { next }  # Skip header

{
    if ($1 != "SERVER_INFO") {
        key = $1 "_" $2 "_" $3  # Section_Org_Status
        file_num = substr($7, 6)  # Extract number from "File_X"
        
        counts[key][file_num] = $4
        sections[key] = $1
        orgs[key] = $2
        statuses[key] = $3
        
        if (file_num > max_files) max_files = file_num
    }
}

END {
    for (key in counts) {
        printf "%s,%s,%s", sections[key], orgs[key], statuses[key]
        
        # Print counts for each file (up to 4)
        trend_values[1] = trend_values[2] = trend_values[3] = trend_values[4] = 0
        
        for (i = 1; i <= max_files && i <= 4; i++) {
            count = (i in counts[key]) ? counts[key][i] : 0
            printf ",%d", count
            trend_values[i] = count
        }
        
        # Fill remaining columns if less than 4 files
        for (i = max_files + 1; i <= 4; i++) {
            printf ",0"
        }
        
        # Calculate trend
        trend = "STABLE"
        if (max_files >= 2) {
            first = trend_values[1]
            last = trend_values[max_files]
            
            if (last > first + (first * 0.1)) trend = "INCREASING"
            else if (last < first - (first * 0.1)) trend = "DECREASING"
            else if (first == 0 && last > 0) trend = "NEW"
            else if (first > 0 && last == 0) trend = "DISAPPEARED"
        }
        
        printf ",%s\n", trend
    }
}
' $MERGED_FILE >> $TREND_FILE

# Generate summary statistics
echo ""
echo "=== MERGE SUMMARY ==="
TOTAL_RECORDS=$(tail -n +2 $MERGED_FILE | wc -l)
echo "Total records merged: $TOTAL_RECORDS"

echo ""
echo "Records by Organization:"
for ORG in CF CP AD XX; do
    COUNT=$(grep ",$ORG," $MERGED_FILE | wc -l)
    echo "  $ORG: $COUNT records"
done

echo ""
echo "Records by File:"
for i in $(seq 1 ${#FILES[@]}); do
    COUNT=$(grep ",File_$i" $MERGED_FILE | wc -l)
    FILENAME=$(basename "${FILES[$((i-1))]}")
    echo "  File $i ($FILENAME): $COUNT records"
done

# Trend analysis summary
if [ -f "$TREND_FILE" ]; then
    echo ""
    echo "=== TREND ANALYSIS ==="
    
    INCREASING=$(grep ",INCREASING" $TREND_FILE | wc -l)
    DECREASING=$(grep ",DECREASING" $TREND_FILE | wc -l)
    STABLE=$(grep ",STABLE" $TREND_FILE | wc -l)
    NEW=$(grep ",NEW" $TREND_FILE | wc -l)
    DISAPPEARED=$(grep ",DISAPPEARED" $TREND_FILE | wc -l)
    
    echo "Increasing trends:    $INCREASING"
    echo "Decreasing trends:    $DECREASING"
    echo "Stable trends:        $STABLE"
    echo "New items:            $NEW"
    echo "Disappeared items:    $DISAPPEARED"
    
    echo ""
    echo "Top Increasing Items:"
    echo "ORG  SECTION         STATUS               FILE1  FILE2  FILE3  FILE4"
    echo "---  -------         ------               -----  -----  -----  -----"
    awk -F',' '$8 == "INCREASING" { 
        printf "%-4s %-15s %-20s %5s  %5s  %5s  %5s\n", $2, $1, $3, $4, $5, $6, $7 
    }' $TREND_FILE | head -10
    
    echo ""
    echo "Top Decreasing Items:"
    echo "ORG  SECTION         STATUS               FILE1  FILE2  FILE3  FILE4"
    echo "---  -------         ------               -----  -----  -----  -----"
    awk -F',' '$8 == "DECREASING" { 
        printf "%-4s %-15s %-20s %5s  %5s  %5s  %5s\n", $2, $1, $3, $4, $5, $6, $7 
    }' $TREND_FILE | head -10
fi

echo ""
echo "Files generated:"
echo "  Merged data: $MERGED_FILE"
echo "  Trend analysis: $TREND_FILE"
echo ""
echo "Use these files to:"
echo "1. Track changes over time by organization"
echo "2. Identify problematic trends early"
echo "3. Create dashboards showing data patterns"
echo "4. Generate executive reports on system health"