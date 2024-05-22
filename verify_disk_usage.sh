#!/bin/bash

final_usage=$(df -h -B 1 | grep '/dev/root' | awk '{print $3}')
echo "Final disk usage: $final_usage bytes"
initial_usage=${{ env.initial_usage }}
usage_change_bytes=$((final_usage - initial_usage))
usage_change_mb=$(echo "scale=2; $usage_change_bytes / (1024 * 1024)" | bc)
echo "Disk usage change: $usage_change_mb MB"

if (( $(echo "$usage_change_mb > 100" | bc -l) )); then
    echo "Error: Disk usage change exceeds 100MB. It is $usage_change_mb MB."
    exit 1
fi
