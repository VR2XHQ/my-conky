#!/bin/bash
# find-desktop.sh
# 用來找出某個應用程式的 .desktop 檔位置（支援多關鍵字，僅比對檔名）

if [ $# -eq 0 ]; then
  echo "用法: $0 <應用程式名稱...>"
  exit 1
fi

# 對每個關鍵字跑一次搜尋
for KEY in "$@"; do
  echo "🔍 搜尋檔名包含 $KEY 的 .desktop 檔..."
  for DIR in /usr/share/applications /usr/local/share/applications \
             ~/.local/share/applications ~/.config/autostart; do
    if [ -d "$DIR" ]; then
      ls "$DIR"/*.desktop 2>/dev/null | grep --color=auto -i "$KEY"
    fi
  done
done

# 詢問是否要全域搜尋
read -p "要進行全域搜尋嗎？(y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  echo "📂 全系統搜尋中，可能需要一些時間..."
  for KEY in "$@"; do
    echo "🔍 全域搜尋檔名包含 $KEY 的 .desktop 檔..."
    sudo find / -type f -iname "*$KEY*.desktop" 2>/dev/null
  done
else
  echo "⏩ 已跳過全域搜尋。"
fi
