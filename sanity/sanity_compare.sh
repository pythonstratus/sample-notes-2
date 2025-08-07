#!/bin/bash

# Simple Sanity Comparison Script
# Usage: ./simple_compare.sh <dev_csv> <prod_csv>

DEV_FILE=$1
PROD_FILE=$2

if [ $# -ne 2 ]; then
    echo "Usage: $0 <dev_csv_file> <prod_csv_file>"
    exit 1
fi

OUTPUT_FILE="/tmp/sanity_comparison_$(date +%Y%m%d_%H%M%S).csv"

echo "Section,Item,Dev_Count,Prod_Count,Difference,Status" > $OUTPUT_FILE

# Join the files on Section+Item and compare counts
join -t',' -1 1 -2 1 -o 1.1,1.2,1.3,2.3 \
    <(tail -n +2 $DEV_FILE | cut -d',' -f1,2,3 | sort) \
    <(tail -n +2 $PROD_FILE | cut -d',' -f1,2,3 | sort) | \
awk -F',' '{
    diff = $4 - $3
    if (diff == 0) status = "SAME"
    else if (diff > 0) status = "PROD_HIGHER" 
    else status = "DEV_HIGHER"
    
    printf "%s,%s,%s,%s,%d,%s\n", $1, $2, $3, $4, diff, status
}' >> $OUTPUT_FILE

echo "Comparison complete: $OUTPUT_FILE"

# Quick summary
echo ""
echo "Summary:"
grep ",SAME," $OUTPUT_FILE | wc -l | xargs echo "Same counts:"
grep ",PROD_HIGHER," $OUTPUT_FILE | wc -l | xargs echo "Prod higher:"  
grep ",DEV_HIGHER," $OUTPUT_FILE | wc -l | xargs echo "Dev higher:"