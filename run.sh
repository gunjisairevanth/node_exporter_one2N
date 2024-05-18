#!/bin/bash

function bytes_to_gib {
    bytes=$(echo "$1" | sed -e 's/\.//g' -e 's/e+09//g' -e 's/e+10//g' -e 's/e+08//g' -e 's/e+07//g')
    gib=$(echo "scale=3; $bytes / 1073741824" | bc)
    echo "$gib"
}

PROMETHEUS_URL="https://metrics.staytools.com/metrics"
file_name="$(date +%s).txt"



response=$(curl -s $PROMETHEUS_URL)
if [ $? -eq 0 ]; then
    # Use grep to find lines containing CPU core usage metrics and extract the relevant information
    cpu_lines=$(echo "$response" | grep "^node_cpu_seconds_total" | grep 'mode="user"')
    while IFS= read -r line; do
        # Extract CPU number and usage from the line
        cpu_number=$(echo "$line" | awk -F 'cpu=' '{print $2}' | awk '{print $1}' | awk -F '[,"]' '{print $2}')
        usage=$(echo "$line" | awk '{print $2}')
        echo "CPU $cpu_number Usage: $usage" >> $file_name
    done <<< "$cpu_lines"
else
    echo "Failed to retrieve metrics from Prometheus"
fi


TOTAL_MEMORY_QUERY="node_memory_MemTotal_bytes"
FREE_MEMORY_QUERY="node_memory_MemFree_bytes"

TOTAL_MEMORY_RESPONSE=$(curl -s -G --data-urlencode "query=$TOTAL_MEMORY_QUERY" "$PROMETHEUS_URL")
TOTAL_MEMORY_BYTES=$(echo "$TOTAL_MEMORY_RESPONSE" | grep -oP 'node_memory_MemTotal_bytes \K[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?')

FREE_MEMORY_RESPONSE=$(curl -s -G --data-urlencode "query=$FREE_MEMORY_QUERY" "$PROMETHEUS_URL")
FREE_MEMORY_BYTES=$(echo "$FREE_MEMORY_RESPONSE" | grep -oP 'node_memory_MemFree_bytes \K[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?')
echo $FREE_MEMORY_BYTES

TOTAL_MEMORY_GB=$(bytes_to_gib $TOTAL_MEMORY_BYTES)
FREE_MEMORY_GB=$(bytes_to_gib $FREE_MEMORY_BYTES)
USED_MEMORY_GB=$(echo "$TOTAL_MEMORY_GB - $FREE_MEMORY_GB" | bc)

multiline_string=$(cat <<EOF
=============
MEMORY (Gib)
TOTAL_MEMORY_GB : $TOTAL_MEMORY_GB
FREE_MEMORY_GB : $FREE_MEMORY_GB
USED_MEMORY_GB : $USED_MEMORY_GB
EOF
)
echo "$multiline_string" >>  $file_name


response=$(curl -s $PROMETHEUS_URL)
TOTAL_DISK_USAGE_BYTES=$(echo "$response" | grep '^node_filesystem_size_bytes{device="/dev/nvme0n1p1",device_error="",fstype="xfs",mountpoint="/"} ')
TOTAL_DISK_USAGE_BYTES=$(echo "$TOTAL_DISK_USAGE_BYTES" | awk '{print $2}' | tr -d '"')
TOTAL_DISK_USAGE_GB=$(bytes_to_gib $TOTAL_DISK_USAGE_BYTES)

response=$(curl -s $PROMETHEUS_URL)
FREE_DISK_BYTES=$(echo "$response" | grep '^node_filesystem_free_bytes{device="/dev/nvme0n1p1",device_error="",fstype="xfs",mountpoint="/"} ')
FREE_DISK_BYTES=$(echo "$FREE_DISK_BYTES" | awk '{print $2}' | tr -d '"')
FREE_DISK_BYTES_IN_GB=$(bytes_to_gib $FREE_DISK_BYTES)
USED_DISK_IN_GB=$(echo "$TOTAL_DISK_USAGE_GB - $FREE_DISK_BYTES_IN_GB" | bc)


multiline_string=$(cat <<EOF
=============
DISK (Gib)
TOTAL_DISK : $TOTAL_DISK_USAGE_GB
FREE_DISK : $FREE_DISK_BYTES_IN_GB
USED_DISK : $USED_DISK_IN_GB
EOF
)
echo "$multiline_string" >>  $file_name