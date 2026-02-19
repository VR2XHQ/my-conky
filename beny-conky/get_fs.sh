#!/bin/bash
# 檔案位置: ~/.config/conky/beny-conky/get_fs.sh
# 用法: get_fs.sh /mount/point

MOUNT="$1"
if [ -z "$MOUNT" ]; then
    echo "0|0|0"
    exit 0
fi

# 使用 df 並加上 timeout，避免卡死
LINE=$(timeout 0.5s df -P "$MOUNT" 2>/dev/null | tail -1)
if [ -z "$LINE" ]; then
    echo "0|0|0"
    exit 0
fi

TOTAL=$(echo "$LINE" | awk '{print $2}')
USED=$(echo "$LINE" | awk '{print $3}')
PERC=$(echo "$LINE" | awk '{print $5}' | tr -d '%')

echo "$USED|$TOTAL|$PERC"
