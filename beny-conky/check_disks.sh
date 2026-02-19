#!/bin/bash
OUTPUT="/tmp/conky_disks.txt"
INCLUDE_NAME="MyCloud"
INCLUDE_PATH="/media/mycloud/benyuenkc"

# 1. 根目錄
echo "Root|/" > $OUTPUT

# 2. 自動抓取 /dev/ 設備並過濾排除名單
mount | grep -E '^/dev/' | while read -r line; do
    MNT=$(echo "$line" | awk '{print $3}')
    # 這裡加入你想排除的路徑 (用 | 分隔)
    if [[ "$MNT" =~ ^/(boot/efi|var/lib/docker|run/timeshift/.*/backup)$ ]]; then
        continue
    fi

    if [ "$MNT" != "/" ]; then
        NAME=$(basename "$MNT" | sed 's/[./_-]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')
        echo "$NAME|$MNT" >> $OUTPUT
    fi
done

# 3. 網絡磁碟探測
if timeout 0.5s stat -t "$INCLUDE_PATH" >/dev/null 2>&1; then
    echo "$INCLUDE_NAME|$INCLUDE_PATH" >> $OUTPUT
fi

