#!/bin/bash

# Sanity Org Report Comparison Script
# Usage: ./compare_sanity_org.sh <dev_csv_file> <prod_csv_file>

# Check if both files are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <dev_org_csv_file> <prod_org_csv_file>"
    echo "Example: $0 /tmp/sanity_org_reports/sanity_org_report_dev_20241201.csv /tmp/sanity_org_reports/sanity_org_report_prod_20241201.csv"
    exit 1
fi

DEV_FILE=$1
PROD_FILE=$2

# Check if files exist
if [ ! -f "$DEV_FILE" ]; then
    echo "Error: Dev org file not found: $DEV_FILE"
    exit 1
fi

if [ ! -f "$PROD_FILE" ]; then
    echo "Error: Prod org file not found: $PROD_FILE"
    exit 1
fi

# Create output directory
OUTPUT_DIR="/tmp/sanity_org_comparisons"
mkdir -p $OUTPUT_DIR

# Generate timestamp for output file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
COMPARISON_FILE="${OUTPUT_DIR}/sanity_org_comparison_${TIMESTAMP}.csv"

echo "Comparing sanity org reports..."
echo "Dev file:  $DEV_FILE"
echo "Prod file: $PROD_FILE"
echo "Output:    $COMPARISON_FILE"
echo ""

# Create comparison CSV with headers
echo "Report_Section,Organization,Status_Item,Dev_Count,Prod_Count,Difference,Status,Dev_Server,Prod_Server,Comparison_Date" > $COMPARISON_FILE

# Process the files using awk
awk -F',' '
BEGIN {
    OFS = ","
}

# Skip header lines
NR == 1 && FNR == 1 { next }
FILENAME == ARGV[1] && FNR == 1 { next }

# Read DEV file (first file)
FNR == NR {
    if (NF >= 4 && $1 != "SERVER_INFO") {
        key = $1 "_" $2 "_" $3  # Report_Section_Organization_Status
        dev_data[key] = $4      # Count
        dev_server[key] = $5    # Server name
        dev_sections[key] = $1  # Report section
        dev_orgs[key] = $2      # Organization
        dev_status[key] = $3    # Status
    }
    next
}

# Read PROD file (second file) and compare
{
    if (NF >= 4 && $1 != "SERVER_INFO") {
        key = $1 "_" $2 "_" $3
        prod_count = $4
        prod_server_name = $5
        
        dev_count = (key in dev_data) ? dev_data[key] : 0
        dev_server_name = (key in dev_server) ? dev_server[key] : "N/A"
        
        # Calculate difference
        diff = prod_count - dev_count
        
        # Determine status
        status = ""
        if (dev_count == 0 && prod_count > 0) {
            status = "PROD_ONLY"
        } else if (dev_count > 0 && prod_count == 0) {
            status = "DEV_ONLY" 
        } else if (diff == 0) {
            status = "SAME"
        } else if (diff > 0) {
            status = "PROD_HIGHER"
        } else {
            status = "DEV_HIGHER"
        }
        
        # Output comparison line
        printf "%s,%s,%s,%d,%d,%d,%s,%s,%s,%s\n", 
               $1, $2, $3, dev_count, prod_count, diff, status, 
               dev_server_name, prod_server_name, strftime("%Y-%m-%d %H:%M:%S")
        
        # Mark this key as processed
        processed[key] = 1
    }
}

END {
    # Handle items that exist only in DEV
    for (key in dev_data) {
        if (!(key in processed)) {
            split(key, parts, "_")
            section = parts[1]
            org = parts[2]
            status_part = ""
            for (i = 3; i <= length(parts); i++) {
                status_part = status_part (i > 3 ? "_" : "") parts[i]
            }
            
            printf "%s,%s,%s,%d,%d,%d,%s,%s,%s,%s\n", 
                   section, org, status_part, dev_data[key], 0, 
                   -dev_data[key], "DEV_ONLY", dev_server[key], "N/A", 
                   strftime("%Y-%m-%d %H:%M:%S")
        }
    }
}
' "$DEV_FILE" "$PROD_FILE" >> $COMPARISON_FILE

# Generate summary statistics
echo ""
echo "=== SANITY ORG COMPARISON SUMMARY ==="

# Count different status types
SAME_COUNT=$(grep ",SAME," $COMPARISON_FILE | wc -l)
PROD_HIGHER_COUNT=$(grep ",PROD_HIGHER," $COMPARISON_FILE | wc -l) 
DEV_HIGHER_COUNT=$(grep ",DEV_HIGHER," $COMPARISON_FILE | wc -l)
PROD_ONLY_COUNT=$(grep ",PROD_ONLY," $COMPARISON_FILE | wc -l)
DEV_ONLY_COUNT=$(grep ",DEV_ONLY," $COMPARISON_FILE | wc -l)

echo "Items with same counts:     $SAME_COUNT"
echo "Items higher in PROD:       $PROD_HIGHER_COUNT"
echo "Items higher in DEV:        $DEV_HIGHER_COUNT"
echo "Items only in PROD:         $PROD_ONLY_COUNT"
echo "Items only in DEV:          $DEV_ONLY_COUNT"

echo ""
echo "=== ORGANIZATION BREAKDOWN ==="
for ORG in CF CP AD XX; do
    ORG_TOTAL=$(grep ",$ORG," $COMPARISON_FILE | wc -l)
    ORG_SAME=$(grep ",$ORG,.*,SAME," $COMPARISON_FILE | wc -l)
    ORG_DIFF=$(($ORG_TOTAL - $ORG_SAME))
    echo "Organization $ORG: $ORG_TOTAL items ($ORG_SAME same, $ORG_DIFF different)"
done

# Show significant differences by organization
echo ""
echo "=== SIGNIFICANT DIFFERENCES BY ORGANIZATION (Count difference > 10) ==="
printf "%-12s %-15s %-20s %8s %8s %8s %s\n" "ORG" "SECTION" "STATUS" "DEV" "PROD" "DIFF" "STATUS"
printf "%-12s %-15s %-20s %8s %8s %8s %s\n" "---" "-------" "------" "---" "----" "----" "------"

awk -F',' 'NR > 1 && ($6 > 10 || $6 < -10) { 
    printf "%-12s %-15s %-20s %8s %8s %8s %s\n", $2, $1, $3, $4, $5, $6, $7 
}' $COMPARISON_FILE | head -20

echo ""
echo "=== ITEMS ONLY IN ONE ENVIRONMENT ==="
printf "%-12s %-15s %-20s %8s %8s %12s\n" "ORG" "SECTION" "STATUS" "DEV" "PROD" "ENVIRONMENT"
printf "%-12s %-15s %-20s %8s %8s %12s\n" "---" "-------" "------" "---" "----" "-----------"

awk -F',' 'NR > 1 && ($7 == "DEV_ONLY" || $7 == "PROD_ONLY") { 
    printf "%-12s %-15s %-20s %8s %8s %12s\n", $2, $1, $3, $4, $5, $7 
}' $COMPARISON_FILE | head -15

echo ""
echo "Full org comparison report saved to: $COMPARISON_FILE"

# Create organization-specific summary
ORG_SUMMARY_FILE="${OUTPUT_DIR}/sanity_org_summary_${TIMESTAMP}.csv"
echo "Organization,Total_Items,Same_Count,Different_Count,Prod_Higher,Dev_Higher,Prod_Only,Dev_Only" > $ORG_SUMMARY_FILE

for ORG in CF CP AD XX; do
    TOTAL=$(grep ",$ORG," $COMPARISON_FILE | wc -l)
    SAME=$(grep ",$ORG,.*,SAME," $COMPARISON_FILE | wc -l)
    PROD_HIGH=$(grep ",$ORG,.*,PROD_HIGHER," $COMPARISON_FILE | wc -l)
    DEV_HIGH=$(grep ",$ORG,.*,DEV_HIGHER," $COMPARISON_FILE | wc -l)
    PROD_ONLY=$(grep ",$ORG,.*,PROD_ONLY," $COMPARISON_FILE | wc -l)
    DEV_ONLY=$(grep ",$ORG,.*,DEV_ONLY," $COMPARISON_FILE | wc -l)
    DIFFERENT=$((TOTAL - SAME))
    
    echo "$ORG,$TOTAL,$SAME,$DIFFERENT,$PROD_HIGH,$DEV_HIGH,$PROD_ONLY,$DEV_ONLY" >> $ORG_SUMMARY_FILE
done

echo ""
echo "Organization summary saved to: $ORG_SUMMARY_FILE"
echo ""
echo "To analyze in spreadsheet:"
echo "1. Import $COMPARISON_FILE into Excel/Google Sheets"
echo "2. Create pivot tables by Organization to see patterns"
echo "3. Filter by 'Status' column to focus on specific differences"
echo "4. Use conditional formatting to highlight significant differences"
echo "5. Chart organization differences for visual analysis"