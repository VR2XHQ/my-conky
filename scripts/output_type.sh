#!/bin/bash

SINK=$(pactl get-default-sink)
DESC=$(pactl list sinks | awk "/Name: $SINK/{f=1} f && /Description:/{sub(/^.*Description: /,\"\"); print; exit}")

if echo "$DESC" | grep -qi "HDMI\|DisplayPort\|DP"; then
    echo "HDMI / DP"
elif echo "$DESC" | grep -qi "USB\|DAC"; then
    echo "USB DAC"
else
    echo "Speaker"
fi
