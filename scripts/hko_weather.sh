#!/bin/bash

# 建議加上超時控制，避免網路斷線時卡死 Conky
DATA=$(curl --max-time 5 -s "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=rhrread&lang=tc")

if [ -z "$DATA" ]; then
    echo "天氣數據更新失敗"
    exit 1
fi

# DATA=$(curl -s "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=rhrread&lang=tc")

TEMP=$(echo "$DATA" | jq -r '.temperature.data[] | select(.place=="香港天文台") | .value')
HUMID=$(echo "$DATA" | jq -r '.humidity.data[0].value')
#WIND_DIR=$(echo "$DATA" | jq -r '.wind.data[0].dir')
#WIND_SPEED=$(echo "$DATA" | jq -r '.wind.data[0].speed')

echo "氣溫: ${TEMP}°C   濕度: ${HUMID}%"
#echo "風向: ${WIND_DIR}"
#echo "風速: ${WIND_SPEED} km/h"
