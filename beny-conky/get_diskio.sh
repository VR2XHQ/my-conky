# !/bin/bash
# 檔案位置: ~/.config/conky/beny-conky/get_diskio.sh
CACHE="/tmp/diskio_cache"
NOW=$(date +%s.%N)

# 取得目前總量 (讀+寫)
DATA=$(awk '{r+=$6; w+=$10} END {print r,w}' /proc/diskstats)
curr_r=$(echo $DATA | awk '{print $1}')
curr_w=$(echo $DATA | awk '{print $2}')

if [ -f "$CACHE" ]; then
  read last_r last_w last_t < "$CACHE"
  dt=$(echo "$NOW - $last_t" | bc)

  # 計算速度 (Byte/s)
  # (差值 * 512位元組 / 時間差)
  awk -v r1=$curr_r -v r0=$last_r -v w1=$curr_w -v w0=$last_w -v dt=$dt \
  'BEGIN { printf "%.0f|%.0f", (r1-r0)*512/dt, (w1-w0)*512/dt }'
else
    echo "0|0"
fi

echo "$curr_r $curr_w $NOW" > "$CACHE"

