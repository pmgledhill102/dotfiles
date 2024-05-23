#!/bin/bash

final_usage=$(df -k | grep -E '/dev/root|/dev/disk3s1s1' | awk '{print $3}')
echo "Final disk usage: $final_usage kbytes"
usage_change_kb=$((final_usage - initial_usage))
usage_change_mb=$(echo "scale=2; $usage_change_kb / 1024" | bc)
echo "Disk usage change: $usage_change_mb MB"

if (( $(echo "$usage_change_mb > ${max_allowed_usage}" | bc -l) )); then
    echo "Error: Disk usage change exceeds ${max_allowed_usage}MB. It is $usage_change_mb MB."
    exit 1
fi
